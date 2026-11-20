import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/src/core/platform/generated/dsi_bindings.g.dart'
    as dsi;
import 'package:device_safety_info/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late Fakes f;
  late DeviceSafetyClient client;

  DeviceSafetyClient make([DeviceSafetyConfig? config]) =>
      client = DeviceSafety.forTesting(platform: f.platform(), config: config);

  setUp(() {
    f = Fakes();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    make();
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await client.dispose();
    DeviceSafety.resetForTesting();
  });

  group('assess', () {
    test('one batch call, FFI merged, flags in plain language', () async {
      f.ffi = const FakeNativeChecks(dsi.DSI_FRIDA_MAPS);
      f.batch.result = BatchResultMsg(
        reports: {
          'root': report([high('root.su_executable:/sbin/su')]),
          'emulator': report([]),
          'hooking': report([]),
          'debugger': report([]),
          'vpn': report([low('vpn.active')]),
        },
        accessibilityServices: [
          AccessibilityServiceMsg(
            id: 'com.x/.S',
            canRetrieveWindowContent: true,
          ),
        ],
        notificationListeners: [],
        installedPackages: ['com.evil'],
      );
      make(DeviceSafetyConfig(malwarePackages: {'com.evil'}));

      final a = await DeviceSafety.assess(
        checks: [
          CheckType.root,
          CheckType.emulator,
          CheckType.hooking,
          CheckType.debugger,
          CheckType.vpn,
          CheckType.accessibility,
          CheckType.notificationListener,
          CheckType.malware,
          CheckType.overlayAttack,
        ],
      );

      expect(f.batch.requests, hasLength(1));
      expect(f.batch.requests.single.malwarePackages, ['com.evil']);
      expect(
        a.results.keys,
        isNot(contains(CheckType.overlayAttack)),
        reason: 'event-only checks are not polled',
      );
      expect(a.results[CheckType.root]!.detected, isTrue);
      expect(
        a.results[CheckType.hooking]!.signals.single.id,
        'hooking.frida_maps',
      );
      expect(a.results[CheckType.vpn]!.detected, isFalse);
      expect(a.results[CheckType.accessibility]!.detected, isTrue);
      expect(a.results[CheckType.malware]!.detected, isTrue);
      expect(a.results[CheckType.notificationListener]!.detected, isFalse);
      expect(a.detected, isTrue);
      expect(a.level, RiskLevel.high);
      expect(a.flags.map((x) => x.type), [
        CheckType.root,
        CheckType.hooking,
        CheckType.accessibility,
        CheckType.malware,
      ]);
      expect(a.flags.first.title, isNotEmpty);
      expect(a.failed, isEmpty);
      expect(a.toString(), contains('root'));
    });

    test('checks the platform failed are errors, not clean', () async {
      f.batch.result = BatchResultMsg(
        reports: {'emulator': report([])},
        accessibilityServices: [],
        notificationListeners: [],
        installedPackages: [],
      );
      make(DeviceSafetyConfig(failModes: {CheckType.root: FailMode.closed}));
      final a = await DeviceSafety.assess(
        checks: [CheckType.root, CheckType.emulator],
      );
      expect(a.results[CheckType.root]!.status, CheckStatus.error);
      expect(a.results[CheckType.root]!.detected, isTrue);
      expect(a.failed.single.type, CheckType.root);
    });

    test('batch failure: every check is an error', () async {
      f.batch.error = StateError('channel down');
      final a = await DeviceSafety.assess(
        checks: [CheckType.root, CheckType.vpn],
      );
      expect(a.results.values.map((r) => r.status).toSet(), {
        CheckStatus.error,
      });
      expect(a.detected, isFalse);
    });

    test('a failed platform root check keeps high native evidence', () async {
      f.batch.result = BatchResultMsg(
        reports: {'emulator': report([])},
        accessibilityServices: [],
        notificationListeners: [],
        installedPackages: [],
      );
      f.ffi = const FakeNativeChecks(dsi.DSI_ROOT_FILES_HIGH);
      make();
      final a = await DeviceSafety.assess(
        checks: [CheckType.root, CheckType.emulator],
      );
      final root = a.results[CheckType.root]!;
      expect(root.status, CheckStatus.completed);
      expect(root.detected, isTrue);
      expect(
        root.signals.map((s) => s.id),
        contains('integrity.platform_check_failed'),
      );
    });

    test(
      'batch failure keeps high native evidence, others are errors',
      () async {
        f.batch.error = StateError('channel down');
        f.ffi = const FakeNativeChecks(dsi.DSI_FRIDA_PORT);
        make();
        final a = await DeviceSafety.assess(
          checks: [CheckType.hooking, CheckType.vpn],
        );
        expect(a.results[CheckType.hooking]!.detected, isTrue);
        expect(a.results[CheckType.hooking]!.status, CheckStatus.completed);
        expect(a.results[CheckType.vpn]!.status, CheckStatus.error);
      },
    );

    test('policy off and cached checks are not requested', () async {
      make(DeviceSafetyConfig(policies: {CheckType.vpn: RiskPolicy.off}));
      await DeviceSafety.root.check();
      await DeviceSafety.assess(
        checks: [CheckType.root, CheckType.vpn, CheckType.emulator],
      );
      expect(f.batch.requests.single.checkIds, ['emulator']);
    });

    test('iOS: allowlist-based checks are unsupported', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final a = await DeviceSafety.assess(
        checks: [
          CheckType.accessibility,
          CheckType.notificationListener,
          CheckType.malware,
        ],
      );
      expect(a.results.values.map((r) => r.status).toSet(), {
        CheckStatus.unsupported,
      });
    });

    test('every CheckType has a flag', () {
      for (final t in CheckType.values) {
        expect(RiskFlag.forType(t).title, isNotEmpty);
        expect(RiskFlag.forType(t).toString(), contains(t.name));
      }
    });
  });

  group('threats', () {
    test('detection flip emits once', () async {
      final events = <ThreatEvent>[];
      final sub = DeviceSafety.threats.listen(events.add);
      f.root.root = report([high('root.su_executable')]);
      await DeviceSafety.root.check();
      await DeviceSafety.root.check(refresh: true);
      await pumpEventQueue();
      expect(events.where((e) => e.type == CheckType.root), hasLength(1));
      expect(events.first.result!.detected, isTrue);
      await sub.cancel();
    });

    test('live events are forwarded while listened', () async {
      final events = <ThreatEvent>[];
      final sub = DeviceSafety.threats.listen(events.add);
      await pumpEventQueue();
      f.events.screenshotsCtl.add(1);
      f.events.overlayCtl.add(2);
      f.events.captureCtl.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(events.map((e) => e.detail), [
        'screenshot',
        'obscured_touch',
        'capture_started',
      ]);
      await sub.cancel();

      // After cancelling, platform streams are no longer observed.
      f.events.screenshotsCtl.add(3);
      await pumpEventQueue();
      expect(events, hasLength(3));
    });
  });

  test('initialize replaces config and clears the cache', () async {
    DeviceSafety.resetForTesting();
    make();
    await DeviceSafety.root.check();
    await DeviceSafety.initialize(
      DeviceSafetyConfig(defaultPolicy: RiskPolicy.strict),
    );
    expect(DeviceSafety.config.defaultPolicy, RiskPolicy.strict);
    await DeviceSafety.root.check();
    expect(f.root.rootCalls, 2);
  });
}
