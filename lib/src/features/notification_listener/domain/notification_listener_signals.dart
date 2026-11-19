import '../../../core/result/risk_signal.dart';

/// Source of the enabled notification listeners.
abstract interface class NotificationListenerRepository {
  /// Component names of every enabled notification listener (empty on iOS).
  Future<List<String>> enabledListeners();
}

/// Every enabled listener not on [allowlist] (matched by component or package name) is high
/// risk: a notification listener can read one-time passwords from incoming messages.
List<RiskSignal> notificationListenerSignals(
  List<String> listeners,
  Set<String> allowlist,
) => [
  for (final l in listeners)
    if (!allowlist.contains(l) && !allowlist.contains(l.split('/').first))
      RiskSignal('notification_listener.untrusted:$l', RiskLevel.high),
];
