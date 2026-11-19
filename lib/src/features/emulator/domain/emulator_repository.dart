import '../../../core/result/risk_signal.dart';

/// Source of raw emulator / simulator reports.
abstract interface class EmulatorRepository {
  /// What the emulator / simulator checks found, before policy.
  Future<CheckReport> emulatorReport();
}
