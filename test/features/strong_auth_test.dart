
import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  group('device key', () {
    test('create returns decoded public key, level and attestation', () async {
      final key = await DeviceSafety.deviceKey.create(
        'login',
        challenge: Uint8List.fromList([9, 9]),
      );
      expect(key.publicKey, [1, 2, 3]);
      expect(key.securityLevel, KeySecurityLevel.strongBox);
      expect(key.securityLevel.isHardwareBacked, isTrue);
      expect(key.attestationChain, [
        [4, 5, 6],
        [7, 8, 9],
      ]);
      expect(f.deviceKey.lastChallenge, [9, 9]);
      expect(f.deviceKey.lastPreferStrongBox, isTrue);
    });

    test('preferStrongBox false and no challenge', () async {
      final key = await DeviceSafety.deviceKey.create(
        'login',
        preferStrongBox: false,
      );
      expect(key.securityLevel, KeySecurityLevel.tee);
      expect(key.attestationChain, isEmpty);
    });

    test('sign, exists, info and delete', () async {
      await DeviceSafety.deviceKey.create('k');
      expect(await DeviceSafety.deviceKey.exists('k'), isTrue);
      expect(await DeviceSafety.deviceKey.info('k'), isNotNull);
      final sig = await DeviceSafety.deviceKey.sign(
        'k',
        Uint8List.fromList([5]),
      );
      expect(sig, [...'k'.codeUnits, 5]);
      await DeviceSafety.deviceKey.delete('k');
      expect(await DeviceSafety.deviceKey.exists('k'), isFalse);
      expect(await DeviceSafety.deviceKey.info('k'), isNull);
    });

    test('signing with a missing key is a typed error', () async {
      await expectLater(
        DeviceSafety.deviceKey.sign('nope', Uint8List(1)),
        throwsA(
          isA<NativeFailureException>().having(
            (e) => e.code,
            'code',
            'KEY_MISSING',
          ),
        ),
      );
    });

    test('unsupported off mobile', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await expectLater(
        DeviceSafety.deviceKey.create('k'),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    });

    test('hardware-backed levels', () {
      expect(KeySecurityLevel.software.isHardwareBacked, isFalse);
      expect(KeySecurityLevel.secureEnclave.isHardwareBacked, isTrue);
    });
  });

  group('biometric', () {
    test('enroll then approve returns the signature', () async {
      expect(await DeviceSafety.biometric.isAvailable(), isTrue);
      expect(
        await DeviceSafety.biometric.keyState('pay'),
        BiometricKeyState.missing,
      );
      final key = await DeviceSafety.biometric.enroll('pay');
      expect(key.publicKey, [1, 2, 3]);
      expect(
        await DeviceSafety.biometric.keyState('pay'),
        BiometricKeyState.valid,
      );
      final sig = await DeviceSafety.biometric.approve(
        'pay',
        Uint8List.fromList([1, 2, 3]),
        title: 'Confirm',
        reason: 'Pay',
      );
      expect(sig, [3, 2, 1]);
    });

    test('an enrollment change is reported and blocks approval', () async {
      await DeviceSafety.biometric.enroll('pay');
      f.biometric.states['pay'] = BiometricKeyStateMsg.invalidated;
      expect(
        await DeviceSafety.biometric.keyState('pay'),
        BiometricKeyState.invalidated,
      );
      await expectLater(
        DeviceSafety.biometric.approve(
          'pay',
          Uint8List(1),
          title: 't',
          reason: 'r',
        ),
        throwsA(
          isA<BiometricException>().having(
            (e) => e.code,
            'code',
            BiometricErrorCode.enrollmentChanged,
          ),
        ),
      );
    });

    test('platform error codes map to BiometricErrorCode', () async {
      const codes = {
        'UNSUPPORTED': BiometricErrorCode.unavailable,
        'NOT_ENROLLED': BiometricErrorCode.notEnrolled,
        'CANCELLED': BiometricErrorCode.cancelled,
        'LOCKED_OUT': BiometricErrorCode.lockedOut,
        'ENROLLMENT_CHANGED': BiometricErrorCode.enrollmentChanged,
        'KEY_MISSING': BiometricErrorCode.keyMissing,
        'WEIRD': BiometricErrorCode.failed,
      };
      for (final MapEntry(:key, :value) in codes.entries) {
        f.biometric.approveError = PlatformException(code: key, message: 'm');
        await expectLater(
          DeviceSafety.biometric.approve(
            'pay',
            Uint8List(1),
            title: 't',
            reason: 'r',
          ),
          throwsA(
            isA<BiometricException>()
                .having((e) => e.code, 'code', value)
                .having((e) => e.platformCode, 'platformCode', key)
                .having((e) => e.toString(), 'toString', contains(value.name)),
          ),
          reason: key,
        );
      }
    });

    test('not available, and unsupported off mobile', () async {
      f.biometric.available = false;
      expect(await DeviceSafety.biometric.isAvailable(), isFalse);
      await expectLater(
        DeviceSafety.biometric.enroll('pay'),
        throwsA(isA<BiometricException>()),
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(await DeviceSafety.biometric.isAvailable(), isFalse);
      await expectLater(
        DeviceSafety.biometric.keyState('pay'),
        throwsA(
          isA<BiometricException>().having(
            (e) => e.code,
            'code',
            BiometricErrorCode.unavailable,
          ),
        ),
      );
    });

    test('delete removes the key', () async {
      await DeviceSafety.biometric.enroll('pay');
      await DeviceSafety.biometric.delete('pay');
      expect(
        await DeviceSafety.biometric.keyState('pay'),
        BiometricKeyState.missing,
      );
    });
  });
}
