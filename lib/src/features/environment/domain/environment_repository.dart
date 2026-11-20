import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';

/// The fraud-environment checks, keyed by their [CheckType].
const Set<CheckType> environmentChecks = {
  CheckType.remoteAccess,
  CheckType.locationSpoofing,
  CheckType.appCloning,
  CheckType.mitm,
  CheckType.keyboard,
};

/// Source of raw fraud-environment reports (remote access, GPS spoofing, app cloning, MITM,
/// keyboard).
abstract interface class EnvironmentRepository {
  /// The raw report for one of [environmentChecks].
  Future<CheckReport> report(CheckType type);

  /// (iOS) Refuse third-party keyboards.
  Future<void> setBlockCustomKeyboards(bool block);
}

/// Drops signals whose detail (`<id>:<package>`) is a package on [allowlist], such as the MDM
/// tool or keyboard your company uses.
CheckReport withoutAllowlistedPackages(
  CheckReport report,
  Set<String> allowlist,
) {
  if (allowlist.isEmpty) return report;
  return CheckReport([
    for (final s in report.signals)
      if (!allowlist.contains(s.id.split(':').skip(1).join(':'))) s,
  ], supported: report.supported);
}
