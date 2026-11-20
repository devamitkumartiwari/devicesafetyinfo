import '../../../core/result/check_result.dart';
import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';

/// A detected check, in plain language, suitable for showing to the user before a sensitive
/// action.
final class RiskFlag {
  /// Creates a flag.
  const RiskFlag({
    required this.type,
    required this.title,
    required this.description,
  });

  /// The check that raised it.
  final CheckType type;

  /// Short summary, e.g. "Device is rooted or jailbroken".
  final String title;

  /// Why it matters.
  final String description;

  /// The standard flag for [type].
  factory RiskFlag.forType(CheckType type) {
    final (title, description) = switch (type) {
      CheckType.root => (
        'Device is rooted or jailbroken',
        'Rooted devices can bypass normal app sandboxing protections.',
      ),
      CheckType.emulator => (
        'Running on an emulator',
        'Emulators are commonly used to automate fraud and analyze apps.',
      ),
      CheckType.hooking => (
        'Hooking framework detected',
        'Tools like Frida or Xposed can intercept or change app behavior while it runs.',
      ),
      CheckType.debugger => (
        'Debugger attached',
        'A debugger can inspect or modify the app while it runs.',
      ),
      CheckType.developerMode => (
        'Developer options enabled',
        'Developer options make it easier to inspect and control apps.',
      ),
      CheckType.screenLock => (
        'No screen lock configured',
        'Anyone with physical access to the device can use it.',
      ),
      CheckType.storeInstall => (
        'Not installed from an official store',
        'The app may have been modified before it was installed.',
      ),
      CheckType.externalStorage => (
        'Installed on external storage',
        'Apps on external storage are easier to tamper with.',
      ),
      CheckType.unknownSources => (
        'Can install apps from unknown sources',
        'Malware is usually installed from outside the official store.',
      ),
      CheckType.playProtect => (
        'Google Play Protect is off',
        'Play Protect scans the device for harmful apps.',
      ),
      CheckType.accessibility => (
        'Untrusted accessibility service',
        'Accessibility services can read the screen and act on your behalf.',
      ),
      CheckType.notificationListener => (
        'Untrusted notification access',
        'Apps with notification access can read one-time passwords.',
      ),
      CheckType.vpn => (
        'VPN or proxy active',
        'Network traffic is routed through a third party.',
      ),
      CheckType.screenCapture => (
        'Screen is being recorded or mirrored',
        'Sensitive content may be visible to another device or app.',
      ),
      CheckType.overlayAttack => (
        'Screen overlay detected',
        'Another app tried to draw over this one to capture taps.',
      ),
      CheckType.malware => (
        'Known harmful app installed',
        'An app on the configured malware list is installed.',
      ),
      CheckType.tampering => (
        'App has been modified',
        'This copy of the app was re-signed, possibly after being altered.',
      ),
      CheckType.remoteAccess => (
        'Remote-control app on this device',
        'Scammers use remote-control apps to operate a victim\'s phone during a "support" call.',
      ),
      CheckType.locationSpoofing => (
        'Location is being faked',
        'A mock-location app can make the device report a location it isn\'t at.',
      ),
      CheckType.appCloning => (
        'App is running in a cloned space',
        'Cloned or dual-app spaces are often used to run several accounts for fraud.',
      ),
      CheckType.mitm => (
        'Network traffic can be intercepted',
        'A user-installed certificate lets another party read encrypted traffic.',
      ),
    };
    return RiskFlag(type: type, title: title, description: description);
  }

  @override
  String toString() => 'RiskFlag(${type.name}: $title)';
}

/// The result of `DeviceSafety.assess`: every requested check, evaluated under the current
/// policy.
final class RiskAssessment {
  /// Creates the assessment.
  RiskAssessment(Map<CheckType, CheckResult> results)
    : results = Map.unmodifiable(results);

  /// Every check, in the requested order.
  final Map<CheckType, CheckResult> results;

  /// Whether any check is detected.
  bool get detected => results.values.any((r) => r.detected);

  /// The detected checks.
  List<CheckResult> get detectedResults => [
    for (final r in results.values)
      if (r.detected) r,
  ];

  /// The highest signal level across all checks.
  RiskLevel get level =>
      results.values.fold(RiskLevel.none, (m, r) => m.max(r.level));

  /// Plain-language flags for the detected checks.
  List<RiskFlag> get flags => [
    for (final r in detectedResults) RiskFlag.forType(r.type),
  ];

  /// Checks that failed or timed out (their `detected` follows the fail mode).
  List<CheckResult> get failed => [
    for (final r in results.values)
      if (r.status == CheckStatus.error || r.status == CheckStatus.timedOut) r,
  ];

  @override
  String toString() =>
      'RiskAssessment(detected: $detected, flags: ${flags.map((f) => f.type.name).toList()})';
}
