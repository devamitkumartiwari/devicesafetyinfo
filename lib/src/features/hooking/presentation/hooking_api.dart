import '../../../core/result/check_type.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../domain/hooking_repository.dart';

/// Hooking and instrumentation framework detection (Frida, Xposed/LSPosed, Substrate).
///
/// Combines platform checks with native C checks (Frida in process memory, Frida's server
/// port, injected dylibs on iOS), which are harder to hide from.
final class HookingApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.hooking`.
  HookingApi(CheckRunner runner, HookingRepository repository)
    : super(CheckType.hooking, runner, repository.hookReport);
}
