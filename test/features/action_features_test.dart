import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/src/core/utils/http_get.dart';
import 'package:device_safety_info/src/features/ioc_domain/domain/ioc_domain_matcher.dart';
import 'package:device_safety_info/src/features/version_check/data/version_repository_impl.dart';
import 'package:device_safety_info/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late Fakes f;
  late DeviceSafetyClient client;

  setUp(() {
    f = Fakes();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    client = DeviceSafety.forTesting(platform: f.platform());
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await client.dispose();
    DeviceSafety.resetForTesting();
  });

  group('screen protection', () {
    test('block, overlay, recording support', () async {
      await DeviceSafety.screen.blockScreenshots();
      expect(await DeviceSafety.screen.isScreenshotBlocked(), isTrue);
      await DeviceSafety.screen.setOverlayMode(
        ScreenshotOverlayMode.image,
        imageBytes: Uint8List.fromList([1, 2]),
      );
      expect(f.screen.overlay!.mode, OverlayModeMsg.image);
      expect(f.screen.overlay!.blurRadius, 10);
      await DeviceSafety.screen.clearOverlayMode();
      expect(f.screen.overlay, isNull);
      expect(await DeviceSafety.screen.isRecordingDetectionSupported(), isTrue);
    });

    test('platform errors become typed exceptions', () async {
      f.screen.error = PlatformException(code: 'NO_ACTIVITY', message: 'x');
      await expectLater(
        DeviceSafety.screen.blockScreenshots(),
        throwsA(
          isA<NativeFailureException>().having(
            (e) => e.code,
            'code',
            'NO_ACTIVITY',
          ),
        ),
      );
      f.screen.error = PlatformException(code: 'permission_denied');
      await expectLater(
        DeviceSafety.screen.blockScreenshots(),
        throwsA(isA<PermissionMissingException>()),
      );
    });

    test('screenshot and capture streams', () async {
      final shots = <DateTime>[];
      final s1 = DeviceSafety.screen.onScreenshot.listen(shots.add);
      final captures = <bool>[];
      final s2 = DeviceSafety.screen.captureChanges.listen(captures.add);
      final recordings = <bool>[];
      final s3 = DeviceSafety.screen.recordingChanges.listen(recordings.add);
      f.events.screenshotsCtl.add(1000);
      f.events.captureCtl
        ..add(true)
        ..add(false)
        ..add(true);
      f.events.recordingCtl.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(shots.single.millisecondsSinceEpoch, 1000);
      expect(captures, [true]);
      expect(recordings, [true]);
      await Future.wait([s1.cancel(), s2.cancel(), s3.cancel()]);
    });

    testWidgets('SecureScreen blocks while any instance is mounted', (
      tester,
    ) async {
      Widget tree(int n) => Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            for (var i = 0; i < n; i++) SecureScreen(child: Text('$i')),
          ],
        ),
      );
      DeviceSafety.instance; // installs the blocker
      await tester.pumpWidget(tree(2));
      await tester.pump();
      expect(f.screen.blocked, isTrue);
      await tester.pumpWidget(tree(1));
      expect(f.screen.blocked, isTrue);
      await tester.pumpWidget(tree(0));
      await tester.pump();
      expect(f.screen.blocked, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  test('app switcher', () async {
    await DeviceSafety.appSwitcher.setOverlay(argbColor: 0xFF112233);
    expect(f.appSwitcher.argb, 0xFF112233);
    await DeviceSafety.appSwitcher.clearOverlay();
    expect(f.appSwitcher.argb, isNull);
    await expectLater(
      DeviceSafety.appSwitcher.hideFromRecents(),
      throwsA(isA<UnsupportedPlatformException>()),
    );
  });

  test('clipboard', () async {
    await DeviceSafety.clipboard.copySecure('123456');
    expect(f.clipboard.text, '123456');
    expect(f.clipboard.sensitive, isTrue);
    expect(f.clipboard.clearAfterMs, 30000);
    await DeviceSafety.clipboard.copySecure(
      'x',
      clearAfter: null,
      sensitive: false,
    );
    expect(f.clipboard.clearAfterMs, isNull);
    await DeviceSafety.clipboard.clear();
    expect(f.clipboard.text, isNull);
    final changes = <DateTime>[];
    final sub = DeviceSafety.clipboard.changes.listen(changes.add);
    f.events.clipboardCtl.add(5);
    await pumpEventQueue();
    expect(changes, hasLength(1));
    await sub.cancel();
  });

  test('overlay attack', () async {
    await DeviceSafety.overlayAttack.blockTouchesWhenObscured();
    expect(f.overlay.block, isTrue);
    final touches = <DateTime>[];
    final sub = DeviceSafety.overlayAttack.obscuredTouches.listen(touches.add);
    f.events.overlayCtl.add(7);
    await pumpEventQueue();
    expect(touches, hasLength(1));
    await sub.cancel();
  });

  group('calls', () {
    test('activity and stream mapping', () async {
      expect(await DeviceSafety.calls.isCallActive(), isTrue);
      final events = <CallActivityEvent>[];
      final sub = DeviceSafety.calls.changes.listen(events.add);
      for (final s in CallSourceMsg.values) {
        f.events.callCtl.add(
          CallEventMsg(source: s, started: true, timestampMs: 9),
        );
      }
      await pumpEventQueue();
      expect(events.map((e) => e.source), CallActivitySource.values);
      expect(events.first.toString(), contains('started'));
      await sub.cancel();
    });

    test('screening role', () async {
      expect(await DeviceSafety.callScreening.isRoleAvailable(), isTrue);
      expect(await DeviceSafety.callScreening.isRoleHeld(), isFalse);
      await expectLater(
        DeviceSafety.callScreening.requestRole(),
        throwsA(isA<NativeFailureException>()),
      );
    });
  });

  group('ioc', () {
    test('exact and wildcard matching', () {
      final ioc = DeviceSafety.ioc
        ..updateBlocklist(['Evil.COM ', '*.bad.net', '']);
      expect(ioc.length, 2);
      expect(ioc.isBlocked('evil.com'), isTrue);
      expect(ioc.isBlocked('a.b.bad.net'), isTrue);
      expect(ioc.isBlocked('bad.net'), isFalse);
      expect(ioc.isBlocked('good.com'), isFalse);
    });

    test('feed parsing skips comments and blanks', () {
      expect(IocDomainMatcher.parseFeed('# c\n a.com \n\nb.com\n'), [
        'a.com',
        'b.com',
      ]);
    });

    test('config blocklist is applied', () async {
      final c = DeviceSafety.forTesting(
        platform: f.platform(),
        config: DeviceSafetyConfig(iocBlocklist: {'x.com'}),
      );
      expect(DeviceSafety.ioc.isBlocked('x.com'), isTrue);
      c.configure(DeviceSafetyConfig(iocBlocklist: {'y.com'}));
      expect(DeviceSafety.ioc.isBlocked('y.com'), isTrue);
      await c.dispose();
    });
  });

  group('version check', () {
    test('compareVersions and urgency', () {
      expect(compareVersions('1.10.0', '1.9.3'), 1);
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('1.0.0-beta', '1.0.1'), -1);
      const s = VersionStatus(
        localVersion: '1.0.0',
        storeVersion: '1.1.0',
        minAppVersion: '1.0.5',
      );
      expect(s.canUpdate, isTrue);
      expect(s.urgency, UpdateUrgency.required);
      const t = VersionStatus(localVersion: '2.0.0', storeVersion: '2.0.0');
      expect(t.urgency, UpdateUrgency.none);
    });

    test('app info and local version', () async {
      final info = await DeviceSafety.versionCheck.appInfo();
      expect(info.packageName, 'com.example.app');
      expect(await DeviceSafety.versionCheck.localVersion(), '1.2.3');
    });

    test('store lookups parse and fail soft', () async {
      final repo = VersionRepositoryImpl(
        FakeAppInfoApi(),
        httpGet: (uri) async => switch (uri.host) {
          'itunes.apple.com' when uri.queryParameters.containsKey('id') =>
            const SimpleHttpResponse(
              200,
              '{"results":[{"version":"3.1.0","trackViewUrl":"https://apps.apple.com/x"}]}',
            ),
          'itunes.apple.com' => const SimpleHttpResponse(200, '{"results":[]}'),
          _ => const SimpleHttpResponse(200, 'x [[["4.2.0"]] y'),
        },
      );
      final ios = await repo.appStoreVersion('com.x', appStoreId: '123');
      expect(ios!.version, '3.1.0');
      expect(await repo.appStoreVersion('com.x'), isNull);
      final play = await repo.playStoreVersion('com.x');
      expect(play!.version, '4.2.0');

      final broken = VersionRepositoryImpl(
        FakeAppInfoApi(),
        httpGet: (_) async => const SimpleHttpResponse(500, ''),
      );
      expect(await broken.playStoreVersion('com.x'), isNull);
      expect(await broken.appStoreVersion('com.x'), isNull);
    });
  });

  group('integrity', () {
    test('Android: Play Integrity maps errors', () async {
      expect(await DeviceSafety.integrity.isPlayIntegrityAvailable(), isTrue);
      await DeviceSafety.integrity.preparePlayIntegrity(cloudProjectNumber: 1);
      await expectLater(
        DeviceSafety.integrity.requestPlayIntegrityToken(requestHash: 'h'),
        throwsA(
          isA<AttestationException>().having(
            (e) => e.code,
            'code',
            AttestationErrorCode.notPrepared,
          ),
        ),
      );
      expect(await DeviceSafety.integrity.isAppAttestSupported(), isFalse);
      await expectLater(
        DeviceSafety.integrity.generateAppAttestKey(),
        throwsA(isA<AttestationException>()),
      );
    });

    test('iOS: App Attest and DeviceCheck', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final i = DeviceSafety.integrity;
      expect(await i.isAppAttestSupported(), isTrue);
      expect(await i.generateAppAttestKey(), 'key-1');
      expect(await i.attestAppAttestKey(keyId: 'k', challenge: 'c'), 'att:k:c');
      await expectLater(
        i.generateAppAttestAssertion(keyId: 'k', clientData: 'd'),
        throwsA(
          isA<AttestationException>().having(
            (e) => e.code,
            'code',
            AttestationErrorCode.invalidKey,
          ),
        ),
      );
      expect(await i.isDeviceCheckSupported(), isFalse);
      expect(await i.generateDeviceCheckToken(), 'dc');
      expect(await i.isPlayIntegrityAvailable(), isFalse);
      await expectLater(
        i.preparePlayIntegrity(cloudProjectNumber: 1),
        throwsA(isA<AttestationException>()),
      );
    });
  });

  testWidgets('IdleTimeoutGuard fires after inactivity and resets on touch', (
    tester,
  ) async {
    var fired = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: IdleTimeoutGuard(
          timeout: const Duration(seconds: 5),
          onTimeout: () => fired++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(seconds: 4));
    expect(fired, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(fired, 1);
    debugDefaultTargetPlatformOverride = null;
  });
}
