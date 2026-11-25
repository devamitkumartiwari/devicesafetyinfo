import '../../../core/result/risk_signal.dart';

/// Source of raw debugger reports.
abstract interface class DebuggerRepository {
  /// What the debugger checks found, before policy.
  Future<CheckReport> debuggerReport();
}
