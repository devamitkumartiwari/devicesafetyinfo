import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';
import '../domain/posture_repository.dart';

/// Reads posture checks from the platform.
final class PostureRepositoryImpl implements PostureRepository {
  /// Creates the repository.
  PostureRepositoryImpl(this._platform);

  final PostureHostApi _platform;

  @override
  Future<CheckReport> report(CheckType type) async {
    final msg = await switch (type) {
      CheckType.developerMode => _platform.developerMode(),
      CheckType.screenLock => _platform.screenLock(),
      CheckType.storeInstall => _platform.storeInstall(),
      CheckType.externalStorage => _platform.externalStorage(),
      CheckType.unknownSources => _platform.unknownSources(),
      CheckType.playProtect => _platform.playProtect(),
      _ => throw ArgumentError.value(type, 'type', 'not a posture check'),
    };
    return msg.toDomain();
  }
}
