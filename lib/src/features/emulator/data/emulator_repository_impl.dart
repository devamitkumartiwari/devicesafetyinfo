import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/result/risk_signal.dart';
import '../domain/emulator_repository.dart';

/// Reads the platform check.
final class EmulatorRepositoryImpl implements EmulatorRepository {
  /// Creates the repository.
  EmulatorRepositoryImpl(this._platform);

  final RootHostApi _platform;

  @override
  Future<CheckReport> emulatorReport() async {
    return (await _platform.emulatorCheck()).toDomain();
  }
}
