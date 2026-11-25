import '../../../core/result/risk_signal.dart';

/// How the running app was signed, as reported by the platform.
final class SigningInfo {
  /// Creates the info.
  const SigningInfo({
    this.certificateSha256 = const [],
    this.hasProvisioningProfile = false,
    this.teamId,
  });

  /// (Android) Lowercase hex SHA-256 digests of the signing certificates.
  final List<String> certificateSha256;

  /// (iOS) Whether the bundle carries `embedded.mobileprovision` (not App Store / TestFlight).
  final bool hasProvisioningProfile;

  /// (iOS) The provisioning profile's team identifier.
  final String? teamId;
}

/// Normalizes a certificate digest as people paste it: `AB:CD:...`, spaces, any case.
String normalizeCertificateDigest(String digest) =>
    digest.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toLowerCase();

/// Evaluates [info] against the expected signer.
///
/// Android: a signing certificate outside [expectedCertificates] means the APK was re-signed
/// (repackaged) — high risk. Without any expected certificate the check can't decide and is
/// unsupported.
///
/// iOS: no provisioning profile means an App Store or TestFlight build — clean. With a profile
/// (development, ad-hoc, enterprise or re-signed builds) the team id is compared against
/// [expectedTeamId] when given (mismatch: high); otherwise the profile itself is a low signal.
CheckReport tamperingReport(
  SigningInfo info, {
  required bool android,
  Set<String> expectedCertificates = const {},
  String? expectedTeamId,
}) {
  if (android) {
    final expected = {
      for (final c in expectedCertificates) normalizeCertificateDigest(c),
    }..remove('');
    if (expected.isEmpty) return CheckReport.unsupported;
    final actual = [
      for (final c in info.certificateSha256) normalizeCertificateDigest(c),
    ];
    if (actual.isEmpty) {
      return const CheckReport([
        RiskSignal('tampering.signature_unreadable', RiskLevel.high),
      ]);
    }
    if (actual.any(expected.contains)) return CheckReport.clean;
    return CheckReport([
      RiskSignal(
        'tampering.signature_mismatch:${actual.first}',
        RiskLevel.high,
      ),
    ]);
  }

  if (!info.hasProvisioningProfile) return CheckReport.clean;
  if (expectedTeamId != null && info.teamId != expectedTeamId) {
    return CheckReport([
      RiskSignal(
        'tampering.team_id_mismatch:${info.teamId ?? 'unknown'}',
        RiskLevel.high,
      ),
    ]);
  }
  return const CheckReport([
    RiskSignal('tampering.provisioning_profile', RiskLevel.low),
  ]);
}

/// Source of the app's signing information.
abstract interface class TamperingRepository {
  /// How the running app was signed.
  Future<SigningInfo> signingInfo();
}
