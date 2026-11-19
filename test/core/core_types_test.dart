import 'package:device_safety_info/src/core/config/risk_policy.dart';
import 'package:device_safety_info/src/core/result/check_result.dart';
import 'package:device_safety_info/src/core/result/check_type.dart';
import 'package:device_safety_info/src/core/result/device_safety_exception.dart';
import 'package:device_safety_info/src/core/result/risk_signal.dart';
import 'package:device_safety_info/src/core/threats/threat_bus.dart';
import 'package:device_safety_info/src/core/utils/platform_guard.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiskSignal', () {
    test('equality, hashCode, key and toString', () {
      const a = RiskSignal('vpn.active', RiskLevel.low);
      const b = RiskSignal('vpn.active', RiskLevel.low);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.withLevel(RiskLevel.high), isFalse);
      expect(identical(a.withLevel(RiskLevel.low), a), isTrue);
      expect(a.key, 'vpn.active');
      expect(const RiskSignal('m.i:pkg', RiskLevel.high).key, 'm.i');
      expect(a.toString(), 'vpn.active(low)');
    });

    test('RiskLevel.max', () {
      expect(RiskLevel.low.max(RiskLevel.high), RiskLevel.high);
      expect(RiskLevel.high.max(RiskLevel.none), RiskLevel.high);
    });
  });

  test('CheckResult toString and isCompleted', () {
    const r = CheckResult(
      type: CheckType.vpn,
      status: CheckStatus.error,
      policy: RiskPolicy.standard,
      error: 'boom',
    );
    expect(r.isCompleted, isFalse);
    expect(r.toString(), contains('vpn'));
    expect(r.toString(), contains('boom'));
    expect(
      const CheckResult.skipped(CheckType.root).toString(),
      contains('skipped'),
    );
  });

  test('ThreatEvent toString', () {
    final e = ThreatEvent(CheckType.screenCapture, detail: 'screenshot');
    expect(e.toString(), contains('screenshot'));
    expect(ThreatEvent(CheckType.root).toString(), contains('root'));
  });

  group('exceptions', () {
    test('toString includes the key detail', () {
      expect(
        const UnsupportedPlatformException('op', 'iOS only').toString(),
        contains('op'),
      );
      expect(
        const UnsupportedPlatformException('op').toString(),
        'UnsupportedPlatformException(op)',
      );
      expect(
        const PermissionMissingException('P', 'm').toString(),
        contains('P'),
      );
      expect(
        const PermissionMissingException('P').toString(),
        'PermissionMissingException(P)',
      );
      expect(const NativeFailureException('C', 'm').toString(), contains('C'));
      expect(
        const NativeFailureException('C').toString(),
        'NativeFailureException(C)',
      );
    });

    test('NativeFailureException.fromPlatform', () {
      final e = NativeFailureException.fromPlatform(
        PlatformException(code: 'X', message: 'm', details: 1),
      );
      expect(e.code, 'X');
      expect(e.message, 'm');
      expect(e.details, 1);
    });

    test('AttestationException.fromPlatform maps every code', () {
      const map = {
        'UNSUPPORTED': AttestationErrorCode.unsupported,
        'NOT_PREPARED': AttestationErrorCode.notPrepared,
        'PROVIDER_INVALID': AttestationErrorCode.providerInvalid,
        'PLAY_SERVICES_UNAVAILABLE':
            AttestationErrorCode.playServicesUnavailable,
        'NETWORK': AttestationErrorCode.network,
        'TOO_MANY_REQUESTS': AttestationErrorCode.tooManyRequests,
        'INVALID_KEY': AttestationErrorCode.invalidKey,
        'INVALID_INPUT': AttestationErrorCode.invalidInput,
        'SERVER_UNAVAILABLE': AttestationErrorCode.serverUnavailable,
        'PLAY_INTEGRITY_-12': AttestationErrorCode.unknown,
      };
      for (final MapEntry(:key, :value) in map.entries) {
        final e = AttestationException.fromPlatform(
          PlatformException(code: key, message: 'msg'),
        );
        expect(e.code, value, reason: key);
        expect(e.platformCode, key);
        expect(e.toString(), contains(value.name));
      }
      expect(
        const AttestationException(AttestationErrorCode.network).toString(),
        'AttestationException(network)',
      );
    });

    test('is a sealed DeviceSafetyException hierarchy', () {
      String describe(DeviceSafetyException e) => switch (e) {
        UnsupportedPlatformException() => 'platform',
        PermissionMissingException() => 'permission',
        NativeFailureException() => 'native',
        AttestationException() => 'attestation',
      };
      expect(describe(const NativeFailureException('x')), 'native');
    });
  });

  group('PlatformGuard', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PlatformGuard.isAndroid, isTrue);
      expect(PlatformGuard.isSupported, isTrue);
      PlatformGuard.requireAndroid('op');
      PlatformGuard.requireMobile('op');
      expect(
        () => PlatformGuard.requireIOS('op'),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    });

    test('ios', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PlatformGuard.isIOS, isTrue);
      PlatformGuard.requireIOS('op');
      expect(
        () => PlatformGuard.requireAndroid('op'),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    });

    test('desktop is unsupported', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlatformGuard.isSupported, isFalse);
      expect(
        () => PlatformGuard.requireMobile('op'),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    });
  });
}
