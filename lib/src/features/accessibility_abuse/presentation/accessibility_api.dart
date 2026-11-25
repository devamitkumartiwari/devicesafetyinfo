import '../../../core/config/device_safety_config.dart';
import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../../../core/utils/platform_guard.dart';
import '../domain/accessibility_signals.dart';

/// Detects accessibility services that could be abused to read or control the screen
/// (Android). Allowlist trusted services with `DeviceSafetyConfig.accessibilityAllowlist`,
/// e.g. `com.google.android.marvin.talkback`. Preinstalled system apps are trusted unless
/// `DeviceSafetyConfig.trustSystemApps` is `false`.
final class AccessibilityApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.accessibility`.
  AccessibilityApi(
    CheckRunner runner,
    this._repository,
    DeviceSafetyConfig Function() config,
  ) : super(
        CheckType.accessibility,
        runner,
        () async => !PlatformGuard.isAndroid
            ? CheckReport.unsupported
            : CheckReport(
                accessibilitySignals(
                  await _repository.enabledServices(),
                  config().accessibilityAllowlist,
                  trustSystemApps: config().trustSystemApps,
                ),
              ),
      );

  final AccessibilityRepository _repository;

  /// Every enabled service, including allowlisted ones.
  Future<List<AccessibilityService>> enabledServices() =>
      _repository.enabledServices();
}
