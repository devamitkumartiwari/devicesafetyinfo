import '../../../core/result/risk_signal.dart';

/// Source of raw root (Android) / jailbreak (iOS) reports.
abstract interface class RootRepository {
  /// What the root (Android) / jailbreak (iOS) checks found, before policy.
  Future<CheckReport> rootReport();
}
