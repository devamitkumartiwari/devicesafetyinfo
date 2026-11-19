import '../../../core/result/check_type.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../domain/debugger_repository.dart';

/// Debugger detection.
///
/// High-risk: a debugger attached (TracerPid / P_TRACED from C, plus the platform APIs).
/// Low-risk (strict only): the app was built debuggable.
final class DebuggerApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.debugger`.
  DebuggerApi(CheckRunner runner, DebuggerRepository repository)
    : super(CheckType.debugger, runner, repository.debuggerReport);
}
