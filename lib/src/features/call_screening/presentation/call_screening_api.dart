import '../../../core/platform/action_guard.dart';
import '../domain/call_screening_repository.dart';

/// The Android call screening role, which lets the app screen incoming calls (e.g. flag
/// spoofed bank numbers). Always unavailable on iOS.
final class CallScreeningApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.callScreening`.
  CallScreeningApi(this._repository);

  final CallScreeningRepository _repository;

  /// Whether the device supports the role (Android 10+).
  Future<bool> isRoleAvailable() =>
      guardAction('isScreeningRoleAvailable', _repository.isRoleAvailable);

  /// Whether this app holds the role.
  Future<bool> isRoleHeld() =>
      guardAction('isScreeningRoleHeld', _repository.isRoleHeld);

  /// Opens the system dialog that asks the user to grant the role.
  Future<void> requestRole() =>
      guardAction('openScreeningRoleSettings', _repository.requestRole);
}
