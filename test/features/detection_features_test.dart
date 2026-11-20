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

  group('root', () {
    test('platform high signal is detected under standard', () async {
      f.root.root = report([high('root.su_executable:/system/bin/su')]);
      final r = await DeviceSafety.root.check();
      expect(r.status, CheckStatus.completed);
      expect(r.detected, isTrue);
      expect(r.signals.single.key, 'root.su_executable');
    });

    test('low signal only counts under strict', () async {
      f.root.root = report([low('root.busybox:/system/xbin/busybox')]);
      expect(await DeviceSafety.root.isDetected(), isFalse);
      DeviceSafety.instance.configure(
        DeviceSafetyConfig(policies: {CheckType.root: RiskPolicy.strict}),
      );
      expect(await DeviceSafety.root.isDetected(), isTrue);
    });

    test('native C signals are merged', () async {
      f.ffi = const FakeNativeChecks(dsi.DSI_ROOT_FILES_HIGH);
      make();
      final r = await DeviceSafety.root.check();
      expect(r.detected, isTrue);
      expect(r.signals.single.id, 'root.native_files');
      expect(r.signals.single.source, SignalSource.ffi);
    });

    test('native library unavailable keeps platform support', () async {
      f.ffi = const FakeNativeChecks(0, false);
      make();
      final r = await DeviceSafety.root.check();
      expect(r.status, CheckStatus.completed);
      // On Android the library always ships, so its absence is a (low) signal.
      expect(r.signals.single.id, 'integrity.native_unavailable');
      expect(r.signals.single.level, RiskLevel.low);
      expect(r.detected, isFalse);
    });

    test('native library unavailable is not a signal off mobile', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      f.ffi = const FakeNativeChecks(0, false);
      make();
      expect((await DeviceSafety.root.check()).signals, isEmpty);
    });

    test('platform error keeps high native evidence (fail-open)', () async {
      f.root.error = StateError('hooked');
      f.ffi = const FakeNativeChecks(dsi.DSI_ROOT_FILES_HIGH);
      make();
      final r = await DeviceSafety.root.check();
      expect(r.status, CheckStatus.completed);
      expect(r.detected, isTrue);
      expect(r.signals.map((s) => s.id), [
        'root.native_files',
        'integrity.platform_check_failed',
      ]);
    });

    test('platform error with only low native evidence is an error', () async {
      f.root.error = StateError('hooked');
      f.ffi = const FakeNativeChecks(dsi.DSI_ROOT_FILES_LOW);
      make();
      final r = await DeviceSafety.root.check();
      expect(r.status, CheckStatus.error);
      expect(r.detected, isFalse);
    });

    test(
      'platform error becomes CheckStatus.error, fail-closed detects',
      () async {
        f.root.error = StateError('boom');
        make(DeviceSafetyConfig(failModes: {CheckType.root: FailMode.closed}));
        final r = await DeviceSafety.root.check();
        expect(r.status, CheckStatus.error);
        expect(r.detected, isTrue);
      },
    );

    test('results are cached and concurrent calls deduped', () async {
      await Future.wait([DeviceSafety.root.check(), DeviceSafety.root.check()]);
      await DeviceSafety.root.check();
      expect(f.root.rootCalls, 1);
      await DeviceSafety.root.check(refresh: true);
      expect(f.root.rootCalls, 2);
    });

    test('override can silence a signal', () async {
      f.root.root = report([high('root.manager_file:/data/adb/magisk')]);
      make(
        DeviceSafetyConfig(
          signalOverrides: {'root.manager_file': RiskLevel.none},
        ),
      );
      expect(await DeviceSafety.root.isDetected(), isFalse);
    });
  });

  test('emulator', () async {
    f.root.emulator = report([high('emulator.hardware:ranchu')]);
    expect(await DeviceSafety.emulator.isDetected(), isTrue);
  });

  test('hooking results are never cached', () async {
    await DeviceSafety.hooking.check();
    await DeviceSafety.hooking.check();
    expect(f.hooking.hookCalls, 2);
  });

  test(
    'hooking keeps native Frida evidence when the platform call fails',
    () async {
      f.hooking.error = StateError('hooked');
      f.ffi = const FakeNativeChecks(dsi.DSI_FRIDA_MAPS);
      make();
      final r = await DeviceSafety.hooking.check();
      expect(r.detected, isTrue);
      expect(r.signals.first.id, 'hooking.frida_maps');
    },
  );

  test('hooking merges Frida from C', () async {
    f.ffi = const FakeNativeChecks(dsi.DSI_FRIDA_PORT);
    make();
    final r = await DeviceSafety.hooking.check();
    expect(r.signals.map((s) => s.id), ['hooking.frida_port']);
    expect(r.detected, isTrue);
  });

  test('debugger: debuggable build is low risk', () async {
    f.hooking.debugger = report([low('debugger.debuggable_build')]);
    expect(await DeviceSafety.debugger.isDetected(), isFalse);
    f.ffi = const FakeNativeChecks(dsi.DSI_DEBUGGER);
    make();
    expect(await DeviceSafety.debugger.isDetected(), isTrue);
  });

  group('posture', () {
    test('each check reads its own report', () async {
      f.posture.reports['screenLock'] = report([high('screen_lock.none')]);
      f.posture.reports['playProtect'] = report([low('play_protect.unknown')]);
      final p = DeviceSafety.posture;
      expect(await p.screenLock.isDetected(), isTrue);
      expect(await p.playProtect.isDetected(), isFalse);
      expect(p.playProtect.type, CheckType.playProtect);
      for (final api in [
        p.developerMode,
        p.storeInstall,
        p.externalStorage,
        p.unknownSources,
      ]) {
        expect((await api.check()).status, CheckStatus.completed);
      }
    });

    test('unsupported platform report', () async {
      f.posture.reports['developerMode'] = report([], supported: false);
      final r = await DeviceSafety.posture.developerMode.check();
      expect(r.status, CheckStatus.unsupported);
      expect(r.detected, isFalse);
    });
  });

  group('accessibility', () {
    setUp(() {
      f.posture.accessibility = [
        AccessibilityServiceMsg(
          id: 'com.google.android.marvin.talkback/.TalkBackService',
          canRetrieveWindowContent: true,
        ),
        AccessibilityServiceMsg(
          id: 'com.bad/.Reader',
          canRetrieveWindowContent: true,
        ),
        AccessibilityServiceMsg(
          id: 'com.meh/.Clicker',
          canRetrieveWindowContent: false,
        ),
      ];
    });

    test('allowlist by package; window readers are high', () async {
      make(
        DeviceSafetyConfig(
          accessibilityAllowlist: {'com.google.android.marvin.talkback'},
        ),
      );
      final r = await DeviceSafety.accessibility.check();
      expect(r.high.single.id, 'accessibility.window_reader:com.bad/.Reader');
      expect(r.low.single.id, 'accessibility.service:com.meh/.Clicker');
      expect(r.detected, isTrue);
      expect(await DeviceSafety.accessibility.enabledServices(), hasLength(3));
    });

    test('unsupported on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        (await DeviceSafety.accessibility.check()).status,
        CheckStatus.unsupported,
      );
    });
  });

  test('notification listeners honor the allowlist', () async {
    f.posture.listeners = ['com.good/.L', 'com.evil/.L'];
    make(DeviceSafetyConfig(notificationListenerAllowlist: {'com.good'}));
    final r = await DeviceSafety.notificationListeners.check();
    expect(r.signals.single.id, 'notification_listener.untrusted:com.evil/.L');
    expect(
      await DeviceSafety.notificationListeners.enabledListeners(),
      hasLength(2),
    );
  });

  group('malware', () {
    test('configured packages that are installed are high risk', () async {
      f.malware.installed = {'com.evil'};
      make(DeviceSafetyConfig(malwarePackages: {'com.evil', 'com.other'}));
      final r = await DeviceSafety.malware.check();
      expect(r.signals.single.id, 'malware.installed:com.evil');
      expect(r.detected, isTrue);
      expect(await DeviceSafety.malware.installedOf(['com.evil', 'x']), [
        'com.evil',
      ]);
    });

    test('empty list is clean; iOS unsupported', () async {
      expect((await DeviceSafety.malware.check()).signals, isEmpty);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        (await DeviceSafety.malware.check(refresh: true)).status,
        CheckStatus.unsupported,
      );
    });
  });

  group('vpn', () {
    test('vpn is low by default, high with an override', () async {
      f.vpn.vpn = report([low('vpn.active')]);
      expect(await DeviceSafety.vpn.isDetected(), isFalse);
      make(DeviceSafetyConfig(signalOverrides: {'vpn.active': RiskLevel.high}));
      expect(await DeviceSafety.vpn.isDetected(), isTrue);
    });

    test('changes settle, dedupe and invalidate the cache', () async {
      await DeviceSafety.vpn.check();
      expect(f.vpn.calls, 1);
      final seen = <bool>[];
      final sub = DeviceSafety.vpn.changes.listen(seen.add);
      f.events.vpnCtl
        ..add(false)
        ..add(true);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      f.events.vpnCtl.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(seen, [true]);
      await DeviceSafety.vpn.check();
      expect(f.vpn.calls, 2);
      await sub.cancel();
    });
  });

  test('screen capture check', () async {
    f.screen.capture = report([high('screen_capture.recording')]);
    expect(await DeviceSafety.screen.isDetected(), isTrue);
  });
}
