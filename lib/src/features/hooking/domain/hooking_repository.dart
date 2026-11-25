import '../../../core/result/risk_signal.dart';

/// Source of raw hooking framework reports.
abstract interface class HookingRepository {
  /// What the hooking framework checks found, before policy.
  Future<CheckReport> hookReport();
}
