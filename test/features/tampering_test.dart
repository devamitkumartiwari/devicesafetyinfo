import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/src/features/tampering/domain/tampering_signals.dart';
import 'package:device_safety_info/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  final ours = 'ab' * 32;

  group('tamperingReport (Android)', () {
    test('unconfigured is unsupported', () {
      final r = tamperingReport(
        SigningInfo(certificateSha256: [ours]),
        android: true,
      );
      expect(r.supported, isFalse);
    });

    test('matching certificate is clean in any format', () {
      final colons = [for (var i = 0; i < 32; i++) 'AB'].join(':');
      final r = tamperingReport(
        SigningInfo(certificateSha256: [ours]),
        android: true,
        expectedCertificates: {colons},
      );
      expect(r.signals, isEmpty);
      expect(r.supported, isTrue);
    });

    test('any matching certificate in a rotation lineage is enough', () {
      final r = tamperingReport(
        SigningInfo(certificateSha256: ['cd' * 32, ours]),
        android: true,
        expectedCertificates: {ours},
      );
      expect(r.signals, isEmpty);
    });

    test('foreign certificate is high risk', () {
      final r = tamperingReport(
        SigningInfo(certificateSha256: ['cd' * 32]),
        android: true,
        expectedCertificates: {ours},
      );
      expect(r.signals.single.id, 'tampering.signature_mismatch:${'cd' * 32}');
      expect(r.signals.single.level, RiskLevel.high);
    });

    test('no readable certificate is high risk', () {
      final r = tamperingReport(
        const SigningInfo(),
        android: true,
        expectedCertificates: {ours},
      );
      expect(r.signals.single.id, 'tampering.signature_unreadable');
    });
  });

  group('tamperingReport (iOS)', () {
    test('App Store build (no profile) is clean', () {
      expect(
        tamperingReport(
          const SigningInfo(),
          android: false,
          expectedTeamId: 'TEAM',
        ).signals,
        isEmpty,
      );
    });

    test('profile from our team is low, from another team is high', () {
      expect(
        tamperingReport(
          const SigningInfo(hasProvisioningProfile: true, teamId: 'TEAM'),
          android: false,
          expectedTeamId: 'TEAM',
        ).signals.single.id,
        'tampering.provisioning_profile',
      );
      final r = tamperingReport(
        const SigningInfo(hasProvisioningProfile: true, teamId: 'OTHER'),
        android: false,
        expectedTeamId: 'TEAM',
      );
      expect(r.signals.single.id, 'tampering.team_id_mismatch:OTHER');
      expect(r.signals.single.level, RiskLevel.high);
    });
  });

  group('DeviceSafety.tampering', () {
    late Fakes f;
    late DeviceSafetyClient client;

    setUp(() {
      f = Fakes();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await client.dispose();
      DeviceSafety.resetForTesting();
    });

    DeviceSafetyClient make(DeviceSafetyConfig config) => client =
        DeviceSafety.forTesting(platform: f.platform(), config: config);

    test('single check and batch agree', () async {
      make(DeviceSafetyConfig(expectedSigningCertificates: {'00' * 32}));
      expect(await DeviceSafety.tampering.isDetected(), isTrue);

      f.batch.result = BatchResultMsg(
        reports: {},
        accessibilityServices: [],
        notificationListeners: [],
        installedPackages: [],
        failedLists: [],
        signing: SigningInfoMsg(
          certificateSha256: [ours],
          hasProvisioningProfile: false,
        ),
      );
      make(DeviceSafetyConfig(expectedSigningCertificates: {ours}));
      final a = await DeviceSafety.assess(checks: [CheckType.tampering]);
      expect(a.results[CheckType.tampering]!.status, CheckStatus.completed);
      expect(a.detected, isFalse);
    });

    test(
      'batch without signing info is an error, unconfigured is unsupported',
      () async {
        make(DeviceSafetyConfig(expectedSigningCertificates: {ours}));
        var a = await DeviceSafety.assess(checks: [CheckType.tampering]);
        expect(a.results[CheckType.tampering]!.status, CheckStatus.error);

        make(DeviceSafetyConfig());
        a = await DeviceSafety.assess(checks: [CheckType.tampering]);
        expect(a.results[CheckType.tampering]!.status, CheckStatus.unsupported);
        expect(
          (await DeviceSafety.tampering.check()).status,
          CheckStatus.unsupported,
        );
      },
    );

    test('signingInfo exposes the digest to configure', () async {
      make(DeviceSafetyConfig());
      expect((await DeviceSafety.tampering.signingInfo()).certificateSha256, [
        ours,
      ]);
    });
  });

  group('assess: unreadable lists', () {
    late Fakes f;
    late DeviceSafetyClient client;

    setUp(() {
      f = Fakes();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      client = DeviceSafety.forTesting(
        platform: f.platform(),
        config: DeviceSafetyConfig(malwarePackages: {'com.evil'}),
      );
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await client.dispose();
      DeviceSafety.resetForTesting();
    });

    test('a list the platform failed to read is an error, not clean', () async {
      f.batch.result = BatchResultMsg(
        reports: {},
        accessibilityServices: [],
        notificationListeners: [],
        installedPackages: [],
        failedLists: ['malware', 'accessibility'],
      );
      final a = await DeviceSafety.assess(
        checks: [
          CheckType.malware,
          CheckType.accessibility,
          CheckType.notificationListener,
        ],
      );
      expect(a.results[CheckType.malware]!.status, CheckStatus.error);
      expect(a.results[CheckType.accessibility]!.status, CheckStatus.error);
      expect(
        a.results[CheckType.notificationListener]!.status,
        CheckStatus.completed,
      );
    });
  });
}
