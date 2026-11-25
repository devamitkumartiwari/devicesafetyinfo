import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';
import '../domain/environment_repository.dart';

/// Reads the fraud-environment checks from the platform.
final class EnvironmentRepositoryImpl implements EnvironmentRepository {
  /// Creates the repository.
  EnvironmentRepositoryImpl(this._platform);

  final EnvironmentHostApi _platform;

  @override
  Future<CheckReport> report(CheckType type) async {
    final msg = await switch (type) {
      CheckType.remoteAccess => _platform.remoteAccess(),
      CheckType.locationSpoofing => _platform.locationSpoofing(),
      CheckType.appCloning => _platform.appCloning(),
      CheckType.mitm => _platform.mitm(),
      CheckType.keyboard => _platform.keyboard(),
      _ => throw ArgumentError.value(type, 'type', 'not an environment check'),
    };
    return msg.toDomain();
  }

  @override
  Future<void> setBlockCustomKeyboards(bool block) =>
      _platform.setBlockCustomKeyboards(block);
}
