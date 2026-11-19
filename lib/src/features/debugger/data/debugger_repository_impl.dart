import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/platform/native_checks_ffi.dart';
import '../../../core/result/risk_signal.dart';
import '../domain/debugger_repository.dart';

/// Merges the platform checks with the native C checks (run in parallel).
final class DebuggerRepositoryImpl implements DebuggerRepository {
  /// Creates the repository.
  DebuggerRepositoryImpl(this._platform, this._ffi);

  final HookingHostApi _platform;
  final NativeChecksSource _ffi;

  @override
  Future<CheckReport> debuggerReport() async {
    final (platform, native) = await (
      _platform.debuggerCheck(),
      _ffi.collect(mask: NativeChecksFfi.debuggerMask),
    ).wait;
    return platform.toDomain().merge(
      CheckReport(native.debuggerSignals, supported: native.supported),
    );
  }
}
