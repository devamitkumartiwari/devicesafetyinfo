import '../result/check_type.dart';
import '../result/risk_signal.dart';
import 'fail_mode.dart';
import 'risk_policy.dart';

/// Receives diagnostic messages, such as a native check failing. Wire it to your logger.
typedef DeviceSafetyLogger = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

/// How the package evaluates checks. Pass it to `DeviceSafety.initialize`; it can be replaced
/// at any time, which also clears cached results.
final class DeviceSafetyConfig {
  /// Creates a configuration. Every argument is optional; the defaults are
  /// [RiskPolicy.standard], [FailMode.open], a 30-second cache and a 5-second timeout.
  DeviceSafetyConfig({
    this.defaultPolicy = RiskPolicy.standard,
    Map<CheckType, RiskPolicy> policies = const {},
    Map<String, RiskLevel> signalOverrides = const {},
    this.failMode = FailMode.open,
    Map<CheckType, FailMode> failModes = const {},
    this.cacheTtl = const Duration(seconds: 30),
    this.timeout = const Duration(seconds: 5),
    Set<String> accessibilityAllowlist = const {},
    Set<String> notificationListenerAllowlist = const {},
    Set<String> malwarePackages = const {},
    this.trustSystemApps = true,
    Set<String> iocBlocklist = const {},
    Set<String> expectedSigningCertificates = const {},
    this.expectedIosTeamId,
    Set<String> remoteAccessAllowlist = const {},
    this.logger,
  }) : policies = Map.unmodifiable(policies),
       signalOverrides = Map.unmodifiable(signalOverrides),
       failModes = Map.unmodifiable(failModes),
       accessibilityAllowlist = Set.unmodifiable(accessibilityAllowlist),
       notificationListenerAllowlist = Set.unmodifiable(
         notificationListenerAllowlist,
       ),
       malwarePackages = Set.unmodifiable(malwarePackages),
       iocBlocklist = Set.unmodifiable(iocBlocklist),
       remoteAccessAllowlist = Set.unmodifiable(remoteAccessAllowlist),
       expectedSigningCertificates = Set.unmodifiable(
         expectedSigningCertificates,
       );

  /// Policy for every check not listed in [policies].
  final RiskPolicy defaultPolicy;

  /// Per-check policies, e.g. `{CheckType.vpn: .strict, CheckType.developerMode: .off}`.
  final Map<CheckType, RiskPolicy> policies;

  /// Changes the level of specific signals, keyed by signal id (the part before any `:`).
  /// For example `{'vpn.active': .high}` makes an active VPN count under the standard policy,
  /// and `{'emulator.generic_build': .none}` ignores that signal entirely.
  final Map<String, RiskLevel> signalOverrides;

  /// Fail mode for every check not listed in [failModes].
  final FailMode failMode;

  /// Per-check fail modes, e.g. `{CheckType.root: .closed}`.
  final Map<CheckType, FailMode> failModes;

  /// How long a completed result is reused. [Duration.zero] disables caching (concurrent
  /// callers still share one in-flight check).
  final Duration cacheTtl;

  /// How long a check may run before it's reported as `CheckStatus.timedOut`.
  final Duration timeout;

  /// Accessibility services (Android component or package names) that are never reported,
  /// e.g. `com.google.android.marvin.talkback`.
  final Set<String> accessibilityAllowlist;

  /// Notification listeners (package names) that are never reported.
  final Set<String> notificationListenerAllowlist;

  /// Whether preinstalled system apps (and updates to them) are trusted by the accessibility
  /// and notification-listener checks. Default `true`: OEM and Google components such as
  /// Android Auto's notification listener aren't reported. Set `false` to report everything
  /// not on the allowlists.
  final bool trustSystemApps;

  /// Package names whose presence the malware check reports.
  final Set<String> malwarePackages;

  /// Initial IOC domain blocklist (exact hosts and `*.suffix` wildcards). It can be replaced
  /// or loaded from a feed later through `DeviceSafety.ioc`.
  final Set<String> iocBlocklist;

  /// (Android) SHA-256 digests of the certificates your app is legitimately signed with, for
  /// the tampering check. Any common format works (`AB:CD:...`, plain hex). Include both your
  /// upload key and Play's app signing key if you test sideloaded builds. Empty disables the
  /// Android tampering check.
  final Set<String> expectedSigningCertificates;

  /// (iOS) Your Apple Developer team id, for the tampering check. A provisioning profile from
  /// another team is reported as high risk.
  final String? expectedIosTeamId;

  /// Remote-control apps (package names) the remote-access check doesn't report, e.g. the
  /// support or MDM tool your organization uses.
  final Set<String> remoteAccessAllowlist;

  /// Receives diagnostic messages. `null` discards them.
  final DeviceSafetyLogger? logger;

  /// The policy that applies to [type].
  RiskPolicy policyFor(CheckType type) => policies[type] ?? defaultPolicy;

  /// The fail mode that applies to [type].
  FailMode failModeFor(CheckType type) => failModes[type] ?? failMode;

  /// A copy with the given fields replaced.
  DeviceSafetyConfig copyWith({
    RiskPolicy? defaultPolicy,
    Map<CheckType, RiskPolicy>? policies,
    Map<String, RiskLevel>? signalOverrides,
    FailMode? failMode,
    Map<CheckType, FailMode>? failModes,
    Duration? cacheTtl,
    Duration? timeout,
    Set<String>? accessibilityAllowlist,
    Set<String>? notificationListenerAllowlist,
    Set<String>? malwarePackages,
    bool? trustSystemApps,
    Set<String>? iocBlocklist,
    Set<String>? expectedSigningCertificates,
    String? expectedIosTeamId,
    Set<String>? remoteAccessAllowlist,
    DeviceSafetyLogger? logger,
  }) => DeviceSafetyConfig(
    defaultPolicy: defaultPolicy ?? this.defaultPolicy,
    policies: policies ?? this.policies,
    signalOverrides: signalOverrides ?? this.signalOverrides,
    failMode: failMode ?? this.failMode,
    failModes: failModes ?? this.failModes,
    cacheTtl: cacheTtl ?? this.cacheTtl,
    timeout: timeout ?? this.timeout,
    accessibilityAllowlist:
        accessibilityAllowlist ?? this.accessibilityAllowlist,
    notificationListenerAllowlist:
        notificationListenerAllowlist ?? this.notificationListenerAllowlist,
    malwarePackages: malwarePackages ?? this.malwarePackages,
    trustSystemApps: trustSystemApps ?? this.trustSystemApps,
    iocBlocklist: iocBlocklist ?? this.iocBlocklist,
    expectedSigningCertificates:
        expectedSigningCertificates ?? this.expectedSigningCertificates,
    expectedIosTeamId: expectedIosTeamId ?? this.expectedIosTeamId,
    remoteAccessAllowlist: remoteAccessAllowlist ?? this.remoteAccessAllowlist,
    logger: logger ?? this.logger,
  );
}
