import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/platform/native_checks_ffi.dart';
import '../../../core/result/risk_signal.dart';
import '../domain/hooking_repository.dart';

/// Merges the platform checks with the native C checks (run in parallel).
final class HookingRepositoryImpl implements HookingRepository {
  /// Creates the repository.
  HookingRepositoryImpl(this._platform, this._ffi);

  final HookingHostApi _platform;
  final NativeChecksSource _ffi;

  @override
  Future<CheckReport> hookReport() async {
    final (platform, native) = await (
      _platform.hookCheck(),
      _ffi.collect(mask: NativeChecksFfi.hookingMask),
    ).wait;
    return platform.toDomain().merge(
      CheckReport(native.hookingSignals, supported: native.supported),
    );
  }
}
