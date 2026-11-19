import '../../../core/config/device_safety_config.dart';
import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../../../core/utils/platform_guard.dart';
import '../domain/notification_listener_signals.dart';

/// Detects notification listeners that could read one-time passwords (Android). Allowlist
/// trusted apps with `DeviceSafetyConfig.notificationListenerAllowlist`.
final class NotificationListenerApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.notificationListeners`.
  NotificationListenerApi(
    CheckRunner runner,
    this._repository,
    DeviceSafetyConfig Function() config,
  ) : super(
        CheckType.notificationListener,
        runner,
        () async => !PlatformGuard.isAndroid
            ? CheckReport.unsupported
            : CheckReport(
                notificationListenerSignals(
                  await _repository.enabledListeners(),
                  config().notificationListenerAllowlist,
                ),
              ),
      );

  final NotificationListenerRepository _repository;

  /// Every enabled listener, including allowlisted ones.
  Future<List<String>> enabledListeners() => _repository.enabledListeners();
}
