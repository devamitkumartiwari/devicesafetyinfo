import '../../../core/platform/generated/device_safety_api.g.dart';
import '../domain/call_screening_repository.dart';

/// The call screening role through the platform API.
final class CallScreeningRepositoryImpl implements CallScreeningRepository {
  /// Creates the repository.
  CallScreeningRepositoryImpl(this._platform);

  final CallHostApi _platform;

  @override
  Future<bool> isRoleAvailable() => _platform.isScreeningRoleAvailable();

  @override
  Future<bool> isRoleHeld() => _platform.isScreeningRoleHeld();

  @override
  Future<void> requestRole() => _platform.openScreeningRoleSettings();
}
