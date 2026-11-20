import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/src/core/result/risk_signal.dart';
import 'package:device_safety_info/src/features/environment/data/environment_repository_impl.dart';
import 'package:device_safety_info/src/features/environment/domain/environment_repository.dart';
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

  group('remote access', () {
    setUp(() {
      f.environment.remote = report([
        high('remote_access.control_service:com.anydesk.anydeskandroid'),
        low('remote_access.app_installed:com.teamviewer.quicksupport.market'),
      ]);
    });

    test('a controlling remote app is detected under standard', () async {
      final r = await DeviceSafety.remoteAccess.check();
      expect(r.detected, isTrue);
      expect(r.high.single.key, 'remote_access.control_service');
      expect(r.low, hasLength(1));
    });

    test('allowlisted packages are dropped', () async {
      make(
        DeviceSafetyConfig(
          remoteAccessAllowlist: {'com.anydesk.anydeskandroid'},
        ),
      );
      final r = await DeviceSafety.remoteAccess.check();
      expect(r.detected, isFalse);
      expect(r.signals.single.id, contains('teamviewer'));
    });

    test('allowlist helper keeps support state and other signals', () {
      const report = CheckReport([
        RiskSignal('remote_access.app_installed:a', RiskLevel.low),
        RiskSignal('remote_access.app_installed:b', RiskLevel.low),
      ], supported: false);
      final out = withoutAllowlistedPackages(report, {'a'});
      expect(out.signals.map((s) => s.id), ['remote_access.app_installed:b']);
      expect(out.supported, isFalse);
      expect(identical(withoutAllowlistedPackages(report, {}), report), isTrue);
    });
  });

  test(
    'location spoofing: selected mock app is high, installed is low',
    () async {
      f.environment.location = report([
        low('location.mock_app_installed:com.lexa.fakegps'),
      ]);
      expect(await DeviceSafety.locationSpoofing.isDetected(), isFalse);
      f.environment.location = report([
        high('location.mock_app_selected:com.lexa.fakegps'),
      ]);
      expect(
        await DeviceSafety.locationSpoofing.isDetected(refresh: true),
        isTrue,
      );
    },
  );

  test('app cloning and mitm map their signals', () async {
    f.environment.cloning = report([
      high('clone.virtual_container:com.lbe.parallel.intl'),
    ]);
    f.environment.mitmReport = report([low('mitm.user_ca:Charles Proxy CA')]);
    expect(await DeviceSafety.appCloning.isDetected(), isTrue);
    final mitm = await DeviceSafety.mitm.check();
    expect(mitm.detected, isFalse);
    expect(mitm.signals.single.id, 'mitm.user_ca:Charles Proxy CA');
    make(DeviceSafetyConfig(policies: {CheckType.mitm: RiskPolicy.strict}));
    expect(await DeviceSafety.mitm.isDetected(), isTrue);
  });

  test('every environment check is unsupported on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    for (final api in <DetectionApi>[
      DeviceSafety.remoteAccess,
      DeviceSafety.locationSpoofing,
      DeviceSafety.appCloning,
      DeviceSafety.mitm,
    ]) {
      expect((await api.check()).status, CheckStatus.unsupported);
    }
  });

  test('repository rejects other check types', () {
    expect(
      () => EnvironmentRepositoryImpl(f.environment).report(CheckType.root),
      throwsArgumentError,
    );
    expect(environmentChecks, hasLength(5));
  });

  test(
    'assess() applies the remote-access allowlist to the batch result',
    () async {
      f.batch.result = BatchResultMsg(
        reports: {
          'remoteAccess': report([
            high('remote_access.control_service:com.anydesk.anydeskandroid'),
          ]),
          'appCloning': report([low('clone.secondary_user')]),
        },
        accessibilityServices: [],
        notificationListeners: [],
        installedPackages: [],
        failedLists: [],
      );
      make(
        DeviceSafetyConfig(
          remoteAccessAllowlist: {'com.anydesk.anydeskandroid'},
        ),
      );
      final a = await DeviceSafety.assess(
        checks: [CheckType.remoteAccess, CheckType.appCloning],
      );
      expect(f.batch.requests.single.checkIds, ['remoteAccess', 'appCloning']);
      expect(a.results[CheckType.remoteAccess]!.signals, isEmpty);
      expect(
        a.results[CheckType.appCloning]!.low.single.id,
        'clone.secondary_user',
      );
      expect(a.detected, isFalse);
    },
  );

  test('new check types have plain-language flags', () {
    for (final t in [
      CheckType.remoteAccess,
      CheckType.locationSpoofing,
      CheckType.appCloning,
      CheckType.mitm,
      CheckType.keyboard,
    ]) {
      expect(RiskFlag.forType(t).title, isNotEmpty);
    }
  });

  group('keyboard', () {
    test('third-party keyboard is low; with accessibility, high', () async {
      f.environment.keyboardReport = report([
        low('keyboard.third_party:com.example.kb'),
      ]);
      expect(await DeviceSafety.keyboard.isDetected(), isFalse);
      f.environment.keyboardReport = report([
        high('keyboard.third_party:com.example.kb'),
      ]);
      expect(await DeviceSafety.keyboard.isDetected(refresh: true), isTrue);
    });

    test('keyboardAllowlist drops the package, also in assess()', () async {
      f.environment.keyboardReport = report([
        high('keyboard.third_party:com.corp.kb'),
      ]);
      f.batch.result = BatchResultMsg(
        reports: {
          'keyboard': report([high('keyboard.third_party:com.corp.kb')]),
        },
        accessibilityServices: [],
        notificationListeners: [],
        installedPackages: [],
        failedLists: [],
      );
      make(DeviceSafetyConfig(keyboardAllowlist: {'com.corp.kb'}));
      expect((await DeviceSafety.keyboard.check()).signals, isEmpty);
      final a = await DeviceSafety.assess(checks: [CheckType.keyboard]);
      expect(a.results[CheckType.keyboard]!.signals, isEmpty);
    });

    test('blockCustomKeyboards reaches the platform only on iOS', () async {
      await DeviceSafety.keyboard.blockCustomKeyboards(true);
      expect(f.environment.blockedKeyboards, isNull);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await DeviceSafety.keyboard.blockCustomKeyboards(true);
      expect(f.environment.blockedKeyboards, isTrue);
      expect(
        (await DeviceSafety.keyboard.check(refresh: true)).status,
        CheckStatus.unsupported,
      );
    });
  });
}
