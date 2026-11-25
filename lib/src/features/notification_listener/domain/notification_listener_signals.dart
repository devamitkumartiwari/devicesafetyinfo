import '../../../core/result/risk_signal.dart';

/// An enabled notification listener.
final class NotificationListenerInfo {
  /// Creates the entity.
  const NotificationListenerInfo(this.id, {this.isSystemApp = false});

  /// Component name, e.g. `com.example/.MyListener`.
  final String id;

  /// Whether the listener belongs to a preinstalled system app (or an update to one).
  final bool isSystemApp;

  /// The package part of [id].
  String get packageName => id.split('/').first;

  @override
  String toString() => isSystemApp ? '$id (system)' : id;
}

/// Source of the enabled notification listeners.
abstract interface class NotificationListenerRepository {
  /// Every enabled notification listener (empty on iOS).
  Future<List<NotificationListenerInfo>> enabledListeners();
}

/// Every enabled listener not on [allowlist] (matched by component or package name), and not a
/// system app when [trustSystemApps] is set, is high risk: a notification listener can read
/// one-time passwords from incoming messages.
List<RiskSignal> notificationListenerSignals(
  List<NotificationListenerInfo> listeners,
  Set<String> allowlist, {
  bool trustSystemApps = true,
}) => [
  for (final l in listeners)
    if (!allowlist.contains(l.id) &&
        !allowlist.contains(l.packageName) &&
        !(trustSystemApps && l.isSystemApp))
      RiskSignal('notification_listener.untrusted:${l.id}', RiskLevel.high),
];
