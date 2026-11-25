import 'dart:async';

import 'package:device_safety_info/src/core/config/device_safety_config.dart';
import 'package:device_safety_info/src/core/config/fail_mode.dart';
import 'package:device_safety_info/src/core/config/risk_policy.dart';
import 'package:device_safety_info/src/core/result/check_result.dart';
import 'package:device_safety_info/src/core/result/check_type.dart';
import 'package:device_safety_info/src/core/result/risk_signal.dart';
import 'package:device_safety_info/src/core/runner/check_runner.dart';
import 'package:device_safety_info/src/core/threats/threat_bus.dart';
import 'package:flutter_test/flutter_test.dart';

const _su = RiskSignal('root.su_executable', RiskLevel.high);
const _vpn = RiskSignal('vpn.active', RiskLevel.low);

void main() {
  late DeviceSafetyConfig config;
  late ThreatBus bus;
  late CheckRunner runner;
  late List<ThreatEvent> events;
  late List<String> logs;

  setUp(() {
    logs = [];
    config = DeviceSafetyConfig(
      timeout: const Duration(milliseconds: 50),
      logger: (m, {error, stackTrace}) => logs.add(m),
    );
    bus = ThreatBus();
    events = [];
    bus.events.listen(events.add);
    runner = CheckRunner(config: () => config, threats: bus);
  });

  tearDown(() => bus.close());

  group('run', () {
    test('completed result with policy applied', () async {
      final r = await runner.run(
        CheckType.root,
        () async => const CheckReport([_su]),
      );
      expect(r.status, CheckStatus.completed);
      expect(r.detected, isTrue);
      expect(r.signals, [_su]);
    });

    test('unsupported report', () async {
      final r = await runner.run(
        CheckType.root,
        () async => CheckReport.unsupported,
      );
      expect(r.status, CheckStatus.unsupported);
      expect(r.detected, isFalse);
    });

    test('policy off never calls the loader', () async {
      config = config.copyWith(policies: {CheckType.root: RiskPolicy.off});
      var called = false;
      final r = await runner.run(CheckType.root, () async {
        called = true;
        return CheckReport.clean;
      });
      expect(called, isFalse);
      expect(r.status, CheckStatus.skipped);
    });

    test(
      'errors become CheckStatus.error and are logged, never thrown',
      () async {
        final r = await runner.run(CheckType.root, () => throw StateError('x'));
        expect(r.status, CheckStatus.error);
        expect(r.error, isA<StateError>());
        expect(r.detected, isFalse);
        expect(logs.single, contains('root'));
      },
    );

    test('fail closed: error counts as detected', () async {
      config = config.copyWith(failModes: {CheckType.root: FailMode.closed});
      final r = await runner.run(
        CheckType.root,
        () async => throw StateError('x'),
      );
      expect(r.detected, isTrue);
    });

    test('timeout becomes CheckStatus.timedOut; fail closed detects', () async {
      config = config.copyWith(failMode: FailMode.closed);
      final r = await runner.run(
        CheckType.root,
        () => Completer<CheckReport>().future,
      );
      expect(r.status, CheckStatus.timedOut);
      expect(r.detected, isTrue);
    });

    test('completed results are cached; refresh bypasses', () async {
      var calls = 0;
      Future<CheckReport> load() async {
        calls++;
        return CheckReport.clean;
      }

      await runner.run(CheckType.vpn, load);
      await runner.run(CheckType.vpn, load);
      expect(calls, 1);
      await runner.run(CheckType.vpn, load, refresh: true);
      expect(calls, 2);
    });

    test('errors are not cached', () async {
      var calls = 0;
      Future<CheckReport> load() async {
        calls++;
        throw StateError('x');
      }

      await runner.run(CheckType.vpn, load);
      await runner.run(CheckType.vpn, load);
      expect(calls, 2);
    });

    test('concurrent runs share one load', () async {
      final gate = Completer<CheckReport>();
      var calls = 0;
      Future<CheckReport> load() {
        calls++;
        return gate.future;
      }

      final a = runner.run(CheckType.vpn, load);
      final b = runner.run(CheckType.vpn, load);
      gate.complete(CheckReport.clean);
      await Future.wait([a, b]);
      expect(calls, 1);
    });

    test('invalidate and reset drop cached results', () async {
      var calls = 0;
      Future<CheckReport> load() async {
        calls++;
        return CheckReport.clean;
      }

      await runner.run(CheckType.vpn, load);
      runner.invalidate(CheckType.vpn);
      await runner.run(CheckType.vpn, load);
      runner.reset();
      await runner.run(CheckType.vpn, load);
      expect(calls, 3);
    });

    test('strict policy picks up low signals', () async {
      config = config.copyWith(policies: {CheckType.vpn: RiskPolicy.strict});
      final r = await runner.run(
        CheckType.vpn,
        () async => const CheckReport([_vpn]),
      );
      expect(r.detected, isTrue);
    });
  });

  group('runBatch', () {
    test('one load for all uncached, enabled checks', () async {
      config = config.copyWith(policies: {CheckType.vpn: RiskPolicy.off});
      await runner.run(CheckType.emulator, () async => CheckReport.clean);

      final requested = <Set<CheckType>>[];
      final results = await runner.runBatch(
        [CheckType.root, CheckType.vpn, CheckType.emulator, CheckType.hooking],
        (types) async {
          requested.add(types);
          return {
            CheckType.root: const CheckReport([_su]),
            CheckType.hooking: CheckReport.clean,
          };
        },
      );
      expect(requested, [
        {CheckType.root, CheckType.hooking},
      ]);
      expect(results.keys, [
        CheckType.root,
        CheckType.vpn,
        CheckType.emulator,
        CheckType.hooking,
      ]);
      expect(results[CheckType.root]!.detected, isTrue);
      expect(results[CheckType.vpn]!.status, CheckStatus.skipped);
      expect(results[CheckType.emulator]!.status, CheckStatus.completed);
    });

    test('refresh reloads cached checks', () async {
      await runner.run(CheckType.root, () async => CheckReport.clean);
      final requested = <Set<CheckType>>[];
      await runner.runBatch([CheckType.root], (types) async {
        requested.add(types);
        return {CheckType.root: CheckReport.clean};
      }, refresh: true);
      expect(requested, [
        {CheckType.root},
      ]);
    });

    test('nothing to load: loader not called', () async {
      config = config.copyWith(defaultPolicy: RiskPolicy.off);
      var called = false;
      await runner.runBatch([CheckType.root], (_) async {
        called = true;
        return {};
      });
      expect(called, isFalse);
    });

    test('batch results are cached for single runs', () async {
      await runner.runBatch([
        CheckType.root,
      ], (_) async => {CheckType.root: CheckReport.clean});
      var called = false;
      await runner.run(CheckType.root, () async {
        called = true;
        return CheckReport.clean;
      });
      expect(called, isFalse);
    });

    test('missing report becomes an error', () async {
      final r = await runner.runBatch([CheckType.root], (_) async => {});
      expect(r[CheckType.root]!.status, CheckStatus.error);
    });

    test('loader failure marks every needed check as error', () async {
      final r = await runner.runBatch([
        CheckType.root,
        CheckType.vpn,
      ], (_) => throw StateError('x'));
      expect(r.values.map((e) => e.status), [
        CheckStatus.error,
        CheckStatus.error,
      ]);
      expect(logs, isNotEmpty);
    });

    test('loader timeout marks every needed check as timedOut', () async {
      final r = await runner.runBatch([
        CheckType.root,
      ], (_) => Completer<Map<CheckType, CheckReport>>().future);
      expect(r[CheckType.root]!.status, CheckStatus.timedOut);
    });
  });

  group('threats', () {
    test('emits once when a check flips to detected', () async {
      Future<CheckReport> dirty() async => const CheckReport([_su]);
      Future<CheckReport> clean() async => CheckReport.clean;

      await runner.run(CheckType.root, dirty);
      await runner.run(CheckType.root, dirty, refresh: true);
      await runner.run(CheckType.root, clean, refresh: true);
      await runner.run(CheckType.root, dirty, refresh: true);
      await pumpEventQueue();
      expect(events.length, 2);
      expect(events.first.type, CheckType.root);
      expect(events.first.result!.detected, isTrue);
    });

    test('live events pass through', () async {
      bus.emit(CheckType.screenCapture, 'screenshot');
      await pumpEventQueue();
      expect(events.single.detail, 'screenshot');
    });

    test('reset re-arms emission', () async {
      Future<CheckReport> dirty() async => const CheckReport([_su]);
      await runner.run(CheckType.root, dirty);
      runner.reset();
      await runner.run(CheckType.root, dirty);
      await pumpEventQueue();
      expect(events.length, 2);
    });
  });
}
