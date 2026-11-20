// End-to-end checks against the real native implementations (no fakes): every Pigeon channel
// answers, the native C library is bundled and loads, and nothing reports an error.
//
//   cd example && flutter test integration_test/plugin_test.dart -d <device>
//
// Expected environment: a normal (not rooted, no Frida) device or emulator.
import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/src/core/platform/native_checks_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => DeviceSafety.initialize());

  const ok = {CheckStatus.completed, CheckStatus.unsupported};

  test('native C library is bundled and its ABI matches', () async {
    final native = await const NativeChecksFfi().collect();
    expect(native.supported, isTrue, reason: 'libdsi was not loaded');
    expect(native.rootSignals, isEmpty);
    expect(native.hookingSignals, isEmpty);
  });

  final detections = <String, DetectionApi Function()>{
    'root': () => DeviceSafety.root,
    'emulator': () => DeviceSafety.emulator,
    'hooking': () => DeviceSafety.hooking,
    'debugger': () => DeviceSafety.debugger,
    'developerMode': () => DeviceSafety.posture.developerMode,
    'screenLock': () => DeviceSafety.posture.screenLock,
    'storeInstall': () => DeviceSafety.posture.storeInstall,
    'externalStorage': () => DeviceSafety.posture.externalStorage,
    'unknownSources': () => DeviceSafety.posture.unknownSources,
    'playProtect': () => DeviceSafety.posture.playProtect,
    'accessibility': () => DeviceSafety.accessibility,
    'notificationListeners': () => DeviceSafety.notificationListeners,
    'vpn': () => DeviceSafety.vpn,
    'screenCapture': () => DeviceSafety.screen,
    'malware': () => DeviceSafety.malware,
    'remoteAccess': () => DeviceSafety.remoteAccess,
    'locationSpoofing': () => DeviceSafety.locationSpoofing,
    'appCloning': () => DeviceSafety.appCloning,
    'mitm': () => DeviceSafety.mitm,
    'tampering': () => DeviceSafety.tampering,
  };

  for (final MapEntry(:key, :value) in detections.entries) {
    test('$key check answers without error', () async {
      final r = await value().check(refresh: true);
      expect(ok, contains(r.status), reason: '$r');
    });
  }

  test(
    'a clean device is not rooted, hooked or debugged (release/profile)',
    () async {
      expect((await DeviceSafety.root.check()).detected, isFalse);
      expect((await DeviceSafety.hooking.check()).detected, isFalse);
      if (!kDebugMode) {
        expect((await DeviceSafety.debugger.check()).detected, isFalse);
      }
    },
  );

  test('signals on this device (diagnostic)', () async {
    for (final api in [
      DeviceSafety.root,
      DeviceSafety.emulator,
      DeviceSafety.hooking,
    ]) {
      final r = await api.check(refresh: true);
      debugPrint('${api.type.id}: ${r.status.name} ${r.signals}');
      if (api.type != CheckType.emulator) {
        expect(
          r.signals.where((s) => s.level == RiskLevel.high),
          isEmpty,
          reason: 'high-risk signal on a clean device: ${r.signals}',
        );
      }
    }
  });

  test(
    'tampering: the real signing certificate passes, another fails',
    () async {
      final info = await DeviceSafety.tampering.signingInfo();
      if (defaultTargetPlatform != TargetPlatform.android) {
        debugPrint('iOS provisioning profile: ${info.hasProvisioningProfile}');
        return;
      }
      expect(info.certificateSha256, isNotEmpty);
      expect(info.certificateSha256.first, matches(RegExp(r'^[0-9a-f]{64}$')));
      debugPrint('signing certificate: ${info.certificateSha256.first}');

      // Unconfigured: can't decide.
      expect(
        (await DeviceSafety.tampering.check(refresh: true)).status,
        CheckStatus.unsupported,
      );
      await DeviceSafety.initialize(
        DeviceSafetyConfig(
          expectedSigningCertificates: {
            info.certificateSha256.first.toUpperCase(),
          },
        ),
      );
      expect(await DeviceSafety.tampering.isDetected(refresh: true), isFalse);
      await DeviceSafety.initialize(
        DeviceSafetyConfig(expectedSigningCertificates: {'00' * 32}),
      );
      final r = await DeviceSafety.tampering.check(refresh: true);
      expect(r.detected, isTrue);
      expect(r.signals.single.key, 'tampering.signature_mismatch');
      // The batch path agrees.
      final a = await DeviceSafety.assess(
        checks: [CheckType.tampering],
        refresh: true,
      );
      expect(a.results[CheckType.tampering]!.detected, isTrue);
      await DeviceSafety.initialize();
    },
  );

  test('assess() answers every check in one call', () async {
    final a = await DeviceSafety.assess(refresh: true);
    expect(a.failed, isEmpty, reason: '${a.failed}');
    expect(a.results.length, CheckType.values.length - 1);
    for (final r in a.results.values) {
      expect(ok, contains(r.status), reason: '$r');
    }
  });

  test('screenshot blocking round-trips', () async {
    await DeviceSafety.screen.blockScreenshots();
    expect(await DeviceSafety.screen.isScreenshotBlocked(), isTrue);
    await DeviceSafety.screen.blockScreenshots(block: false);
    expect(await DeviceSafety.screen.isScreenshotBlocked(), isFalse);
  });

  test(
    'overlay mode, app switcher, clipboard and tapjacking actions',
    () async {
      await DeviceSafety.screen.setOverlayMode(ScreenshotOverlayMode.blur);
      await DeviceSafety.screen.clearOverlayMode();
      await DeviceSafety.appSwitcher.setOverlay();
      await DeviceSafety.appSwitcher.clearOverlay();
      await DeviceSafety.clipboard.copySecure('123456', clearAfter: null);
      await DeviceSafety.clipboard.clear();
      if (defaultTargetPlatform == TargetPlatform.android) {
        await DeviceSafety.overlayAttack.blockTouchesWhenObscured();
        await DeviceSafety.overlayAttack.blockTouchesWhenObscured(block: false);
      }
    },
  );

  test('capture stream sends the current state first', () async {
    final first = await DeviceSafety.screen.captureChanges.first.timeout(
      const Duration(seconds: 5),
    );
    expect(first, isFalse);
  });

  test('app info and call APIs answer', () async {
    final info = await DeviceSafety.versionCheck.appInfo();
    expect(
      info.packageName,
      contains('device_safety_info_example'.split('_').first),
    );
    expect(info.version, isNotEmpty);
    expect(await DeviceSafety.calls.isCallActive(), isFalse);
    await DeviceSafety.callScreening.isRoleAvailable();
  });

  test('integrity availability answers', () async {
    await DeviceSafety.integrity.isPlayIntegrityAvailable();
    await DeviceSafety.integrity.isAppAttestSupported();
    await DeviceSafety.integrity.isDeviceCheckSupported();
  });

  test(
    'system notification listeners and accessibility services are not reported',
    () async {
      if (defaultTargetPlatform != TargetPlatform.android) return;
      final listeners = await DeviceSafety.notificationListeners
          .enabledListeners();
      final flagged = (await DeviceSafety.notificationListeners.check(
        refresh: true,
      )).signals.map((s) => s.id.split(':').skip(1).join(':')).toSet();
      for (final l in listeners.where((l) => l.isSystemApp)) {
        expect(flagged, isNot(contains(l.id)), reason: '$l is a system app');
      }
      final services = await DeviceSafety.accessibility.enabledServices();
      final flaggedServices = (await DeviceSafety.accessibility.check(
        refresh: true,
      )).signals.map((s) => s.id.split(':').skip(1).join(':')).toSet();
      for (final s in services.where((s) => s.isSystemApp)) {
        expect(flaggedServices, isNot(contains(s.id)));
      }
      // ignore: avoid_print
      print('listeners: $listeners; flagged: $flagged');
    },
  );

  test('fraud-environment checks report what they find', () async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final clone = await DeviceSafety.appCloning.check(refresh: true);
    expect(
      clone.signals.where((s) => s.key == 'clone.virtual_container'),
      isEmpty,
      reason: 'the test app runs as a normal install',
    );
    for (final api in <DetectionApi>[
      DeviceSafety.remoteAccess,
      DeviceSafety.locationSpoofing,
      DeviceSafety.appCloning,
      DeviceSafety.mitm,
    ]) {
      final r = await api.check(refresh: true);
      // ignore: avoid_print
      print('${api.type.name}: ${r.status.name} ${r.signals}');
    }
  });

  test('device key: hardware-backed, attested, signs DER ECDSA', () async {
    const alias = 'it.device_key';
    final key = await DeviceSafety.deviceKey.create(
      alias,
      challenge: Uint8List.fromList(List.generate(16, (i) => i)),
    );
    try {
      expect(key.publicKey.first, 0x30, reason: 'SPKI is a DER SEQUENCE');
      expect(key.publicKey.length, 91, reason: 'P-256 SPKI');
      expect(key.securityLevel.isHardwareBacked, isTrue);
      if (defaultTargetPlatform == TargetPlatform.android) {
        expect(key.attestationChain, isNotEmpty);
        for (final cert in key.attestationChain) {
          expect(cert.first, 0x30);
        }
      }
      expect(await DeviceSafety.deviceKey.exists(alias), isTrue);
      final info = await DeviceSafety.deviceKey.info(alias);
      expect(info?.publicKey, key.publicKey);
      final sig = await DeviceSafety.deviceKey.sign(
        alias,
        Uint8List.fromList('hello'.codeUnits),
      );
      expect(sig.first, 0x30, reason: 'DER ECDSA signature');
      expect(sig.length, inInclusiveRange(8, 72));
      // ignore: avoid_print
      print(
        'deviceKey: ${key.securityLevel.name}, '
        'chain ${key.attestationChain.length}, sig ${sig.length} bytes',
      );
    } finally {
      await DeviceSafety.deviceKey.delete(alias);
    }
    expect(await DeviceSafety.deviceKey.exists(alias), isFalse);
    await expectLater(
      DeviceSafety.deviceKey.sign(alias, Uint8List(1)),
      throwsA(isA<NativeFailureException>()),
    );
  });

  test('biometric: availability and key lifecycle (no prompt)', () async {
    const alias = 'it.biometric';
    final available = await DeviceSafety.biometric.isAvailable();
    // ignore: avoid_print
    print('biometric available: $available');
    expect(
      await DeviceSafety.biometric.keyState(alias),
      BiometricKeyState.missing,
    );
    if (!available) return;
    final key = await DeviceSafety.biometric.enroll(alias);
    try {
      expect(key.publicKey.first, 0x30);
      expect(key.securityLevel.isHardwareBacked, isTrue);
      expect(
        await DeviceSafety.biometric.keyState(alias),
        BiometricKeyState.valid,
      );
    } finally {
      await DeviceSafety.biometric.delete(alias);
    }
    expect(
      await DeviceSafety.biometric.keyState(alias),
      BiometricKeyState.missing,
    );
  });
}
