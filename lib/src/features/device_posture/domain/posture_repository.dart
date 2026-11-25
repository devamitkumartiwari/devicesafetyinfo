import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';

/// The posture checks, keyed by their [CheckType].
const Set<CheckType> postureChecks = {
  CheckType.developerMode,
  CheckType.screenLock,
  CheckType.storeInstall,
  CheckType.externalStorage,
  CheckType.unknownSources,
  CheckType.playProtect,
};

/// Source of raw device posture reports.
abstract interface class PostureRepository {
  /// The raw report for one of [postureChecks].
  Future<CheckReport> report(CheckType type);
}
