import '../../../core/config/device_safety_config.dart';
import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';

/// Collects raw reports for many checks at once (one platform round trip).
abstract interface class AssessmentRepository {
  /// Raw reports for [types]. Checks missing from the result are reported as errors.
  Future<Map<CheckType, CheckReport>> collect(
    Set<CheckType> types,
    DeviceSafetyConfig config,
  );
}
