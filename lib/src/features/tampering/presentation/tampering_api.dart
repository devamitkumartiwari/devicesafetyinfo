import '../../../core/config/device_safety_config.dart';
import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../../../core/utils/platform_guard.dart';
import '../domain/tampering_signals.dart';

/// Detects a repackaged or re-signed app.
///
/// Android: compares the APK's signing certificate with
/// `DeviceSafetyConfig.expectedSigningCertificates` (the SHA-256 shown by
/// `keytool -list -v`, `./gradlew signingReport`, or Play Console › App integrity › App signing).
/// Without it the check is unsupported. High-risk signals: `tampering.signature_mismatch`,
/// `tampering.signature_unreadable`.
///
/// iOS: App Store and TestFlight builds carry no provisioning profile. A profile from another
/// team than `DeviceSafetyConfig.expectedIosTeamId` is high risk
/// (`tampering.team_id_mismatch`); any other profile is low risk
/// (`tampering.provisioning_profile`), which development builds also show.
final class TamperingApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.tampering`.
  TamperingApi(
    CheckRunner runner,
    this._repository,
    DeviceSafetyConfig Function() config,
  ) : super(CheckType.tampering, runner, () async {
        if (!PlatformGuard.isSupported) return CheckReport.unsupported;
        final c = config();
        final android = PlatformGuard.isAndroid;
        if (android && c.expectedSigningCertificates.isEmpty) {
          return CheckReport.unsupported;
        }
        return tamperingReport(
          await _repository.signingInfo(),
          android: android,
          expectedCertificates: c.expectedSigningCertificates,
          expectedTeamId: c.expectedIosTeamId,
        );
      });

  final TamperingRepository _repository;

  /// The raw signing information (certificate digests on Android, provisioning profile on
  /// iOS). Useful to find the value for `expectedSigningCertificates`.
  Future<SigningInfo> signingInfo() => _repository.signingInfo();
}
