import '../../../core/platform/action_guard.dart';
import '../domain/clipboard_repository.dart';

/// Copies sensitive text (one-time passwords, account numbers) safely.
final class ClipboardApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.clipboard`.
  ClipboardApi(this._repository);

  final ClipboardRepository _repository;

  /// Copies [text]. With [sensitive] the item is marked sensitive (hidden from the Android 13+
  /// clipboard preview, kept off Universal Clipboard on iOS). With [clearAfter] the clipboard is
  /// cleared after that time.
  Future<void> copySecure(
    String text, {
    bool sensitive = true,
    Duration? clearAfter = const Duration(seconds: 30),
  }) => guardAction(
    'copySecure',
    () => _repository.copySecure(
      text,
      sensitive: sensitive,
      clearAfter: clearAfter,
    ),
  );

  /// Clears the clipboard.
  Future<void> clear() => guardAction('clearClipboard', _repository.clear);

  /// Fires whenever the clipboard changes (any app).
  Stream<DateTime> get changes => _repository.changes();
}
