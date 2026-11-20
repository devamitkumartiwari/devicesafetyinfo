import 'package:device_safety_info/src/core/config/device_safety_config.dart';
import 'package:device_safety_info/src/core/config/fail_mode.dart';
import 'package:device_safety_info/src/core/config/risk_policy.dart';
import 'package:device_safety_info/src/core/policy/policy_evaluator.dart';
import 'package:device_safety_info/src/core/result/check_result.dart';
import 'package:device_safety_info/src/core/result/check_type.dart';
import 'package:device_safety_info/src/core/result/risk_signal.dart';
import 'package:flutter_test/flutter_test.dart';

const _evaluator = PolicyEvaluator();
const _high = RiskSignal('root.su_executable', RiskLevel.high);
const _low = RiskSignal('root.busybox', RiskLevel.low);

CheckResult _eval(
  CheckStatus status,
  List<RiskSignal> signals, {
  RiskPolicy policy = RiskPolicy.standard,
  FailMode failMode = FailMode.open,
  Map<String, RiskLevel> overrides = const {},
}) => _evaluator.evaluate(
  CheckType.root,
  status,
  signals,
  DeviceSafetyConfig(
    policies: {CheckType.root: policy},
    failModes: {CheckType.root: failMode},
    signalOverrides: overrides,
  ),
);

void main() {
  group('detected matrix', () {
    // (policy, status, signals, failMode) -> detected
    final cases =
        <(RiskPolicy, CheckStatus, List<RiskSignal>, FailMode, bool)>[];
    for (final failMode in FailMode.values) {
      for (final signals in [
        <RiskSignal>[],
        [_low],
        [_high],
        [_low, _high],
      ]) {
        final level = signals.fold(RiskLevel.none, (m, s) => m.max(s.level));
        for (final status in CheckStatus.values) {
          for (final policy in RiskPolicy.values) {
            final bool expected;
            if (policy == RiskPolicy.off || status == CheckStatus.skipped) {
              expected = false;
            } else {
              expected = switch (status) {
                CheckStatus.completed =>
                  policy == RiskPolicy.strict
                      ? level != RiskLevel.none
                      : level == RiskLevel.high,
                CheckStatus.error ||
                CheckStatus.timedOut => failMode == FailMode.closed,
                _ => false,
              };
            }
            cases.add((policy, status, signals, failMode, expected));
          }
        }
      }
    }

    for (final (policy, status, signals, failMode, expected) in cases) {
      test(
        '${policy.name} / ${status.name} / $signals / ${failMode.name} -> $expected',
        () {
          final r = _eval(status, signals, policy: policy, failMode: failMode);
          expect(r.detected, expected);
          if (policy == RiskPolicy.off || status == CheckStatus.skipped) {
            expect(r.status, CheckStatus.skipped);
            expect(r.policy, RiskPolicy.off);
            expect(r.signals, isEmpty);
          } else {
            expect(r.status, status);
            expect(r.policy, policy);
          }
        },
      );
    }
  });

  group('signals and level', () {
    test('level is the max signal level', () {
      expect(_eval(CheckStatus.completed, []).level, RiskLevel.none);
      expect(_eval(CheckStatus.completed, [_low]).level, RiskLevel.low);
      expect(_eval(CheckStatus.completed, [_low, _high]).level, RiskLevel.high);
    });

    test('high and low getters split signals', () {
      final r = _eval(CheckStatus.completed, [_low, _high]);
      expect(r.high, [_high]);
      expect(r.low, [_low]);
    });

    test('override raises a low signal to high (standard detects)', () {
      final r = _eval(
        CheckStatus.completed,
        [_low],
        overrides: {'root.busybox': RiskLevel.high},
      );
      expect(r.detected, isTrue);
      expect(r.level, RiskLevel.high);
      expect(r.signals.single.level, RiskLevel.high);
    });

    test('override lowers a high signal to low (standard ignores)', () {
      final r = _eval(
        CheckStatus.completed,
        [_high],
        overrides: {'root.su_executable': RiskLevel.low},
      );
      expect(r.detected, isFalse);
      expect(r.level, RiskLevel.low);
    });

    test('override to none removes the signal (strict ignores)', () {
      final r = _eval(
        CheckStatus.completed,
        [_low],
        policy: RiskPolicy.strict,
        overrides: {'root.busybox': RiskLevel.none},
      );
      expect(r.detected, isFalse);
      expect(r.signals, isEmpty);
      expect(r.level, RiskLevel.none);
    });

    test('override matches the part of the id before ":"', () {
      final r = _eval(
        CheckStatus.completed,
        [const RiskSignal('malware.installed:com.bad', RiskLevel.high)],
        overrides: {'malware.installed': RiskLevel.low},
      );
      expect(r.signals.single.id, 'malware.installed:com.bad');
      expect(r.signals.single.level, RiskLevel.low);
    });

    test('override does not change fail-mode decisions', () {
      final r = _eval(
        CheckStatus.error,
        [],
        failMode: FailMode.closed,
        overrides: {'root.su_executable': RiskLevel.none},
      );
      expect(r.detected, isTrue);
    });

    test('duplicate ids keep the highest level, first position', () {
      final r = _eval(CheckStatus.completed, [
        const RiskSignal('x', RiskLevel.low),
        _high,
        const RiskSignal('x', RiskLevel.high, source: SignalSource.ffi),
      ]);
      expect(r.signals.map((s) => s.id), ['x', 'root.su_executable']);
      expect(r.signals.first.level, RiskLevel.high);
    });

    test('signals list is unmodifiable', () {
      final r = _eval(CheckStatus.completed, [_high]);
      expect(() => r.signals.add(_low), throwsUnsupportedError);
    });

    test('error and elapsed are carried through', () {
      final err = StateError('x');
      final r = _evaluator.evaluate(
        CheckType.vpn,
        CheckStatus.error,
        const [],
        DeviceSafetyConfig(),
        error: err,
        elapsed: const Duration(milliseconds: 7),
      );
      expect(r.error, same(err));
      expect(r.elapsed, const Duration(milliseconds: 7));
    });
  });

  group('config lookup', () {
    test('default policy and fail mode apply to unlisted checks', () {
      final c = DeviceSafetyConfig(
        defaultPolicy: RiskPolicy.strict,
        failMode: FailMode.closed,
        policies: {CheckType.vpn: RiskPolicy.off},
        failModes: {CheckType.vpn: FailMode.open},
      );
      expect(c.policyFor(CheckType.root), RiskPolicy.strict);
      expect(c.policyFor(CheckType.vpn), RiskPolicy.off);
      expect(c.failModeFor(CheckType.root), FailMode.closed);
      expect(c.failModeFor(CheckType.vpn), FailMode.open);
    });

    test('system apps are trusted by default and it can be turned off', () {
      expect(DeviceSafetyConfig().trustSystemApps, isTrue);
      expect(
        DeviceSafetyConfig().copyWith(trustSystemApps: false).trustSystemApps,
        isFalse,
      );
    });

    test('copyWith replaces only the given fields', () {
      final c = DeviceSafetyConfig(timeout: const Duration(seconds: 1));
      final d = c.copyWith(defaultPolicy: RiskPolicy.strict);
      expect(d.defaultPolicy, RiskPolicy.strict);
      expect(d.timeout, const Duration(seconds: 1));
    });

    test('collections are unmodifiable', () {
      final c = DeviceSafetyConfig(malwarePackages: {'a'});
      expect(() => c.malwarePackages.add('b'), throwsUnsupportedError);
      expect(
        () => c.policies[CheckType.root] = RiskPolicy.off,
        throwsUnsupportedError,
      );
    });
  });

  test('CheckType.fromId round-trips and rejects unknown ids', () {
    for (final t in CheckType.values) {
      expect(CheckType.fromId(t.id), t);
    }
    expect(CheckType.fromId('nope'), isNull);
  });

  test('CheckReport.merge combines signals and support', () {
    const a = CheckReport([_high], supported: false);
    const b = CheckReport([_low]);
    final m = a.merge(b);
    expect(m.signals, [_high, _low]);
    expect(m.supported, isTrue);
    expect(a.merge(CheckReport.unsupported).supported, isFalse);
  });
}
