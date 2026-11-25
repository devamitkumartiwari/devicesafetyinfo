/// The Android call screening role.
abstract interface class CallScreeningRepository {
  Future<bool> isRoleAvailable();
  Future<bool> isRoleHeld();
  Future<void> requestRole();
}
