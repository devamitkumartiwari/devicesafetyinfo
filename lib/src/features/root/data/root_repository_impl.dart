import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/native_checks_ffi.dart';
import '../../../core/platform/native_merge.dart';
import '../../../core/result/risk_signal.dart';
import '../domain/root_repository.dart';

/// Merges the platform checks with the native C checks (run in parallel). High-risk native
/// evidence survives a failed platform call; see [mergePlatformWithNative].
final class RootRepositoryImpl implements RootRepository {
  /// Creates the repository.
  RootRepositoryImpl(this._platform, this._ffi);

  final RootHostApi _platform;
  final NativeChecksSource _ffi;

  @override
  Future<CheckReport> rootReport() => mergePlatformWithNative(
    _platform.rootCheck(),
    _ffi.collect(mask: NativeChecksFfi.rootMask),
    (n) => n.rootSignals,
  );
}
