/// Clipboard protection.
abstract interface class ClipboardRepository {
  Future<void> copySecure(
    String text, {
    required bool sensitive,
    Duration? clearAfter,
  });
  Future<void> clear();

  /// Times the clipboard changed.
  Stream<DateTime> changes();
}
