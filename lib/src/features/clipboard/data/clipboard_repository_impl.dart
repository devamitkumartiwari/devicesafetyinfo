import '../../../core/platform/device_safety_platform.dart';
import '../../../core/platform/generated/device_safety_api.g.dart';
import '../domain/clipboard_repository.dart';

/// Clipboard protection through the platform API.
final class ClipboardRepositoryImpl implements ClipboardRepository {
  /// Creates the repository.
  ClipboardRepositoryImpl(this._platform, this._events);

  final ClipboardHostApi _platform;
  final PlatformEvents _events;

  @override
  Future<void> copySecure(
    String text, {
    required bool sensitive,
    Duration? clearAfter,
  }) => _platform.copySecure(text, sensitive, clearAfter?.inMilliseconds);

  @override
  Future<void> clear() => _platform.clear();

  @override
  Stream<DateTime> changes() =>
      _events.clipboardChanges.map(DateTime.fromMillisecondsSinceEpoch);
}
