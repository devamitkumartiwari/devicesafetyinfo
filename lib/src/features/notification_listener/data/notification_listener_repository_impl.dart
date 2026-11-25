import '../../../core/platform/generated/device_safety_api.g.dart';
import '../domain/notification_listener_signals.dart';

/// Reads enabled notification listeners from the platform.
final class NotificationListenerRepositoryImpl
    implements NotificationListenerRepository {
  /// Creates the repository.
  NotificationListenerRepositoryImpl(this._platform);

  final PostureHostApi _platform;

  @override
  Future<List<NotificationListenerInfo>> enabledListeners() async => [
    for (final l in await _platform.enabledNotificationListeners())
      l.toDomain(),
  ];
}

/// Converts the platform message.
extension NotificationListenerMsgMapping on NotificationListenerMsg {
  /// The domain entity.
  NotificationListenerInfo toDomain() =>
      NotificationListenerInfo(id, isSystemApp: isSystemApp);
}
