import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/platform/native_checks_ffi.dart';
import '../../../core/result/risk_signal.dart';
import '../domain/root_repository.dart';

/// Merges the platform checks with the native C checks (run in parallel).
final class RootRepositoryImpl implements RootRepository {
  /// Creates the repository.
  RootRepositoryImpl(this._platform, this._ffi);

  final RootHostApi _platform;
  final NativeChecksSource _ffi;

  @override
  Future<CheckReport> rootReport() async {
    final (platform, native) = await (
      _platform.rootCheck(),
      _ffi.collect(mask: NativeChecksFfi.rootMask),
    ).wait;
    return platform.toDomain().merge(
      CheckReport(native.rootSignals, supported: native.supported),
    );
  }
}
