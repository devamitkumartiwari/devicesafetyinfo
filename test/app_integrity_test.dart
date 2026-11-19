import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('device_safety_info');
  final calls = <MethodCall>[];

  /// Native handler used by the mock channel; replaced per test when needed.
  late Future<Object?> Function(MethodCall call) native;

  void setNative(Future<Object?> Function(MethodCall call) handler) =>
      native = handler;

  setUp(() {
    calls.clear();
    native = (call) async => switch (call.method) {
      'isPlayIntegrityAvailable' => true,
      'preparePlayIntegrity' => null,
      'requestPlayIntegrityToken' => 'play-token',
      'isAppAttestSupported' => true,
      'generateAppAttestKey' => 'key-1',
      'attestAppAttestKey' => 'YXR0ZXN0',
      'generateAppAttestAssertion' => 'YXNzZXJ0',
      'isDeviceCheckSupported' => true,
      'generateDeviceCheckToken' => 'ZGM=',
      _ => throw MissingPluginException(),
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return native(call);
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Android — Play Integrity', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('isPlayIntegrityAvailable reads the native flag', () async {
      expect(await AppIntegrity.isPlayIntegrityAvailable, isTrue);
      expect(calls.single.method, 'isPlayIntegrityAvailable');
    });

    test('preparePlayIntegrity sends the cloud project number', () async {
      await AppIntegrity.preparePlayIntegrity(cloudProjectNumber: 123456789012);
      expect(calls.single.method, 'preparePlayIntegrity');
      expect(calls.single.arguments, {'cloudProjectNumber': 123456789012});
    });

    test('requestPlayIntegrityToken returns the token', () async {
      final token = await AppIntegrity.requestPlayIntegrityToken(
        requestHash: 'challenge-1',
      );
      expect(token, 'play-token');
      expect(calls.single.arguments, {'requestHash': 'challenge-1'});
    });

    test('null token is reported as unknown, not a null crash', () async {
      setNative((_) async => null);
      expect(
        () => AppIntegrity.requestPlayIntegrityToken(requestHash: 'x'),
        throwsA(
          isA<AttestationException>().having(
            (e) => e.code,
            'code',
            AttestationErrorCode.unknown,
          ),
        ),
      );
    });

    test('iOS-only methods throw unsupported without a channel call', () async {
      for (final call in <Future<Object?> Function()>[
        AppIntegrity.generateAppAttestKey,
        () => AppIntegrity.attestAppAttestKey(keyId: 'k', challenge: 'c'),
        () => AppIntegrity.generateAppAttestAssertion(
          keyId: 'k',
          clientData: 'd',
        ),
        AppIntegrity.generateDeviceCheckToken,
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<AttestationException>().having(
              (e) => e.code,
              'code',
              AttestationErrorCode.unsupported,
            ),
          ),
        );
      }
      expect(await AppIntegrity.isAppAttestSupported, isFalse);
      expect(await AppIntegrity.isDeviceCheckSupported, isFalse);
      expect(calls, isEmpty);
    });
  });

  group('iOS — App Attest / DeviceCheck', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('support flags read the native values', () async {
      expect(await AppIntegrity.isAppAttestSupported, isTrue);
      expect(await AppIntegrity.isDeviceCheckSupported, isTrue);
    });

    test('generate → attest → assert pass arguments through', () async {
      final keyId = await AppIntegrity.generateAppAttestKey();
      final attestation = await AppIntegrity.attestAppAttestKey(
        keyId: keyId,
        challenge: 'server-challenge',
      );
      final assertion = await AppIntegrity.generateAppAttestAssertion(
        keyId: keyId,
        clientData: '{"nonce":"n1"}',
      );

      expect(keyId, 'key-1');
      expect(attestation, 'YXR0ZXN0');
      expect(assertion, 'YXNzZXJ0');
      expect(calls.map((c) => c.method), [
        'generateAppAttestKey',
        'attestAppAttestKey',
        'generateAppAttestAssertion',
      ]);
      expect(calls[1].arguments, {
        'keyId': 'key-1',
        'challenge': 'server-challenge',
      });
      expect(calls[2].arguments, {
        'keyId': 'key-1',
        'clientData': '{"nonce":"n1"}',
      });
    });

    test('generateDeviceCheckToken returns the token', () async {
      expect(await AppIntegrity.generateDeviceCheckToken(), 'ZGM=');
    });

    test('Android-only methods throw unsupported without a channel call', () async {
      await expectLater(
        AppIntegrity.preparePlayIntegrity(cloudProjectNumber: 1),
        throwsA(isA<AttestationException>()),
      );
      await expectLater(
        AppIntegrity.requestPlayIntegrityToken(requestHash: 'x'),
        throwsA(isA<AttestationException>()),
      );
      expect(await AppIntegrity.isPlayIntegrityAvailable, isFalse);
      expect(calls, isEmpty);
    });
  });

  group('error mapping', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    const expected = {
      'UNSUPPORTED': AttestationErrorCode.unsupported,
      'NOT_PREPARED': AttestationErrorCode.notPrepared,
      'PROVIDER_INVALID': AttestationErrorCode.providerInvalid,
      'PLAY_SERVICES_UNAVAILABLE': AttestationErrorCode.playServicesUnavailable,
      'NETWORK': AttestationErrorCode.network,
      'TOO_MANY_REQUESTS': AttestationErrorCode.tooManyRequests,
      'INVALID_KEY': AttestationErrorCode.invalidKey,
      'INVALID_INPUT': AttestationErrorCode.invalidInput,
      'SERVER_UNAVAILABLE': AttestationErrorCode.serverUnavailable,
      'PLAY_INTEGRITY_-12': AttestationErrorCode.unknown,
    };

    for (final entry in expected.entries) {
      test('${entry.key} → ${entry.value.name}', () async {
        setNative(
          (_) async =>
              throw PlatformException(code: entry.key, message: 'boom'),
        );
        await expectLater(
          AppIntegrity.requestPlayIntegrityToken(requestHash: 'x'),
          throwsA(
            isA<AttestationException>()
                .having((e) => e.code, 'code', entry.value)
                .having((e) => e.platformCode, 'platformCode', entry.key)
                .having((e) => e.message, 'message', 'boom'),
          ),
        );
      });
    }

    test('MissingPluginException → unsupported', () async {
      setNative((_) async => throw MissingPluginException());
      await expectLater(
        AppIntegrity.preparePlayIntegrity(cloudProjectNumber: 1),
        throwsA(
          isA<AttestationException>().having(
            (e) => e.code,
            'code',
            AttestationErrorCode.unsupported,
          ),
        ),
      );
    });

    test('availability getter swallows errors and returns false', () async {
      setNative((_) async => throw PlatformException(code: 'UNKNOWN'));
      expect(await AppIntegrity.isPlayIntegrityAvailable, isFalse);
    });
  });
}
