import 'dart:async';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/src/core/platform/action_guard.dart';
import 'package:device_safety_info/src/core/utils/http_get.dart';
import 'package:device_safety_info/src/core/utils/stream_utils.dart';
import 'package:device_safety_info/src/features/device_posture/data/posture_repository_impl.dart';
import 'package:device_safety_info/src/features/risk_assessment/data/assessment_repository_impl.dart';
import 'package:device_safety_info/src/features/version_check/data/version_repository_impl.dart';
import 'package:device_safety_info/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('posture repository rejects non-posture checks', () {
    expect(
      () => PostureRepositoryImpl(FakePostureApi()).report(CheckType.root),
      throwsArgumentError,
    );
  });

  test(
    'assessment repository answers event-only checks as unsupported',
    () async {
      final repo = AssessmentRepositoryImpl(
        FakeBatchApi(),
        const FakeNativeChecks(),
      );
      final out = await repo.collect({
        CheckType.overlayAttack,
      }, DeviceSafetyConfig());
      expect(out[CheckType.overlayAttack]!.supported, isFalse);
    },
  );

  group('VersionCheckApi.status', () {
    VersionCheckApi api({int status = 200}) => VersionCheckApi(
      VersionRepositoryImpl(
        FakeAppInfoApi(),
        httpGet: (uri) async => uri.host == 'itunes.apple.com'
            ? SimpleHttpResponse(
                status,
                '{"results":[{"version":"1.3.0","trackViewUrl":"https://a/x"}]}',
              )
            : SimpleHttpResponse(status, '[[["1.2.9"]]'),
      ),
    );

    test('Android compares with the Play Store', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final s = await api().status(minAppVersion: '1.0.0');
      expect(s!.localVersion, '1.2.3');
      expect(s.storeVersion, '1.2.9');
      expect(s.storeLink, contains('play.google.com'));
      expect(s.urgency, UpdateUrgency.optional);
    });

    test('iOS compares with the App Store', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final s = await api().status(iOSAppStoreCountry: 'us');
      expect(s!.storeVersion, '1.3.0');
      expect(s.storeLink, 'https://a/x');
    });

    test('forceAppVersion, store failure and unsupported platform', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        (await api(status: 500).status(forceAppVersion: '5.0.0'))!.storeVersion,
        '5.0.0',
      );
      expect(await api(status: 500).status(), isNull);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(await api().status(), isNull);
    });
  });

  group('IOC feed', () {
    test('loads a remote feed', () async {
      final ioc = IocDomainApi(
        httpGet: (_) async =>
            const SimpleHttpResponse(200, '# feed\nbad.com\n*.evil.net\n'),
      );
      await ioc.loadRemoteBlocklist(Uri.parse('https://feed.example/ioc.txt'));
      expect(ioc.isBlocked('bad.com'), isTrue);
      expect(ioc.isBlocked('x.evil.net'), isTrue);
    });

    test('a failed download keeps the current list', () async {
      final ioc = IocDomainApi(
        httpGet: (_) async => const SimpleHttpResponse(503, ''),
      )..updateBlocklist(['keep.com']);
      await expectLater(
        ioc.loadRemoteBlocklist(Uri.parse('https://feed.example')),
        throwsA(
          isA<NativeFailureException>().having(
            (e) => e.code,
            'code',
            'HTTP_503',
          ),
        ),
      );
      expect(ioc.isBlocked('keep.com'), isTrue);
    });
  });

  test(
    'guardAction maps a missing plugin to UnsupportedPlatformException',
    () async {
      await expectLater(
        guardAction('op', () async => throw MissingPluginException('none')),
        throwsA(isA<UnsupportedPlatformException>()),
      );
      await expectLater(
        guardAction(
          'op',
          () async => throw PlatformException(code: 'UNSUPPORTED_PLATFORM'),
        ),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    },
  );

  group('settled', () {
    test('forwards errors and closes when the source closes', () async {
      final ctl = StreamController<int>();
      final values = <int>[];
      final errors = <Object>[];
      final done = Completer<void>();
      ctl.stream
          .settled(const Duration(milliseconds: 10))
          .listen(values.add, onError: errors.add, onDone: done.complete);
      ctl
        ..add(1)
        ..addError('e');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await ctl.close();
      await done.future;
      expect(values, [1]);
      expect(errors, ['e']);
    });

    test('pause and resume pass through', () async {
      final ctl = StreamController<int>();
      final values = <int>[];
      final sub = ctl.stream.settled(Duration.zero).listen(values.add);
      sub.pause();
      expect(ctl.isPaused, isTrue);
      sub.resume();
      ctl.add(3);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(values, [3]);
      await sub.cancel();
      await ctl.close();
    });
  });
}
