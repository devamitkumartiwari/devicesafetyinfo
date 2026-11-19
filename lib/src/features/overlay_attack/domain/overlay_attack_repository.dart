/// Tapjacking (overlay attack) protection.
abstract interface class OverlayAttackRepository {
  Future<void> blockTouchesWhenObscured(bool block);

  /// Times a touch arrived while another app's window covered this one.
  Stream<DateTime> obscuredTouches();
}
