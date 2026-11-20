import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';

/// The fraud-environment checks, keyed by their [CheckType].
const Set<CheckType> environmentChecks = {
  CheckType.remoteAccess,
  CheckType.locationSpoofing,
  CheckType.appCloning,
  CheckType.mitm,
};

/// Source of raw fraud-environment reports (remote access, GPS spoofing, app cloning, MITM).
abstract interface class EnvironmentRepository {
  /// The raw report for one of [environmentChecks].
  Future<CheckReport> report(CheckType type);
}

/// Drops remote-access signals for packages on [allowlist] (e.g. the MDM or support tool your
/// company uses). Other reports pass through unchanged.
CheckReport withoutAllowlistedRemoteAccess(
  CheckReport report,
  Set<String> allowlist,
) {
  if (allowlist.isEmpty) return report;
  return CheckReport([
    for (final s in report.signals)
      if (!allowlist.contains(s.id.split(':').skip(1).join(':'))) s,
  ], supported: report.supported);
}
