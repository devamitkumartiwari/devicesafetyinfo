import 'dart:async';
import 'dart:io' show exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'core/config/device_safety_config.dart';
import 'core/platform/device_safety_platform.dart';
import 'core/result/check_type.dart';
import 'core/runner/check_runner.dart';
import 'core/threats/threat_bus.dart';
import 'features/accessibility_abuse/data/accessibility_repository_impl.dart';
import 'features/accessibility_abuse/presentation/accessibility_api.dart';
import 'features/app_integrity/data/integrity_repository_impl.dart';
import 'features/app_integrity/presentation/integrity_api.dart';
import 'features/app_switcher/data/app_switcher_repository_impl.dart';
import 'features/app_switcher/presentation/app_switcher_api.dart';
import 'features/call_activity/data/call_repository_impl.dart';
import 'features/call_activity/presentation/call_activity_api.dart';
import 'features/call_screening/data/call_screening_repository_impl.dart';
import 'features/call_screening/presentation/call_screening_api.dart';
import 'features/clipboard/data/clipboard_repository_impl.dart';
import 'features/clipboard/presentation/clipboard_api.dart';
import 'features/debugger/data/debugger_repository_impl.dart';
import 'features/debugger/presentation/debugger_api.dart';
import 'features/device_posture/data/posture_repository_impl.dart';
import 'features/device_posture/presentation/posture_api.dart';
import 'features/emulator/data/emulator_repository_impl.dart';
import 'features/emulator/presentation/emulator_api.dart';
import 'features/hooking/data/hooking_repository_impl.dart';
import 'features/hooking/presentation/hooking_api.dart';
import 'features/ioc_domain/presentation/ioc_domain_api.dart';
import 'features/malware/data/malware_repository_impl.dart';
import 'features/malware/presentation/malware_api.dart';
import 'features/notification_listener/data/notification_listener_repository_impl.dart';
import 'features/notification_listener/presentation/notification_listener_api.dart';
import 'features/overlay_attack/data/overlay_attack_repository_impl.dart';
import 'features/overlay_attack/presentation/overlay_attack_api.dart';
import 'features/risk_assessment/data/assessment_repository_impl.dart';
import 'features/risk_assessment/domain/assessment_repository.dart';
import 'features/risk_assessment/presentation/risk_assessment.dart';
import 'features/root/data/root_repository_impl.dart';
import 'features/root/presentation/root_api.dart';
import 'features/screen_protection/data/screen_protection_repository_impl.dart';
import 'features/screen_protection/presentation/screen_protection_api.dart';
import 'features/screen_protection/presentation/widgets/secure_screen.dart';
import 'features/tampering/data/tampering_repository_impl.dart';
import 'features/tampering/presentation/tampering_api.dart';
import 'features/version_check/data/version_repository_impl.dart';
import 'features/version_check/presentation/version_check_api.dart';
import 'features/vpn/data/vpn_repository_impl.dart';
import 'features/vpn/presentation/vpn_api.dart';

/// Every feature, built lazily on first use. Most apps use the static [DeviceSafety] facade,
/// which forwards to one instance of this class.
final class DeviceSafetyClient {
  /// Creates a client. [platform] defaults to the real platform implementation.
  DeviceSafetyClient({
    DeviceSafetyPlatform? platform,
    DeviceSafetyConfig? config,
  }) : _platform = platform ?? DeviceSafetyPlatform(),
       _config = config ?? DeviceSafetyConfig() {
    if (_config.iocBlocklist.isNotEmpty) {
      ioc.updateBlocklist(_config.iocBlocklist);
    }
  }

  final DeviceSafetyPlatform _platform;
  DeviceSafetyConfig _config;

  final ThreatBus _bus = ThreatBus();
  late final CheckRunner _runner = CheckRunner(
    config: () => _config,
    threats: _bus,
  );

  /// The active configuration.
  DeviceSafetyConfig get config => _config;

  /// Replaces the configuration and clears cached results.
  void configure(DeviceSafetyConfig config) {
    _config = config;
    _runner.reset();
    if (config.iocBlocklist.isNotEmpty) {
      ioc.updateBlocklist(config.iocBlocklist);
    }
  }

  /// Root (Android) / jailbreak (iOS) detection.
  late final RootApi root = RootApi(
    _runner,
    RootRepositoryImpl(_platform.root, _platform.ffi),
  );

  /// Emulator / simulator detection.
  late final EmulatorApi emulator = EmulatorApi(
    _runner,
    EmulatorRepositoryImpl(_platform.root),
  );

  /// Hooking framework detection.
  late final HookingApi hooking = HookingApi(
    _runner,
    HookingRepositoryImpl(_platform.hooking, _platform.ffi),
  );

  /// Debugger detection.
  late final DebuggerApi debugger = DebuggerApi(
    _runner,
    DebuggerRepositoryImpl(_platform.hooking, _platform.ffi),
  );

  /// Device posture checks (developer mode, screen lock, store install, ...).
  late final PostureApi posture = PostureApi(
    _runner,
    PostureRepositoryImpl(_platform.posture),
  );

  /// Accessibility service abuse detection.
  late final AccessibilityApi accessibility = AccessibilityApi(
    _runner,
    AccessibilityRepositoryImpl(_platform.posture),
    () => _config,
  );

  /// Notification listener abuse detection.
  late final NotificationListenerApi notificationListeners =
      NotificationListenerApi(
        _runner,
        NotificationListenerRepositoryImpl(_platform.posture),
        () => _config,
      );

  /// Screenshot / recording protection and capture detection.
  late final ScreenProtectionApi screen = ScreenProtectionApi(
    _runner,
    ScreenProtectionRepositoryImpl(_platform.screen, _platform.events),
    _bus,
  );

  /// App switcher (recents) privacy.
  late final AppSwitcherApi appSwitcher = AppSwitcherApi(
    AppSwitcherRepositoryImpl(_platform.appSwitcher),
  );

  /// Secure clipboard.
  late final ClipboardApi clipboard = ClipboardApi(
    ClipboardRepositoryImpl(_platform.clipboard, _platform.events),
  );

  /// Tapjacking protection.
  late final OverlayAttackApi overlayAttack = OverlayAttackApi(
    OverlayAttackRepositoryImpl(_platform.overlayAttack, _platform.events),
    _bus,
  );

  /// VPN / proxy detection.
  late final VpnApi vpn = VpnApi(
    _runner,
    VpnRepositoryImpl(_platform.vpn, _platform.events),
    _bus,
  );

  /// IOC domain blocklist.
  late final IocDomainApi ioc = IocDomainApi();

  /// Known-malware package detection.
  late final MalwareApi malware = MalwareApi(
    _runner,
    MalwareRepositoryImpl(_platform.malware),
    () => _config,
  );

  /// Repackaged / re-signed app detection.
  late final TamperingApi tampering = TamperingApi(
    _runner,
    TamperingRepositoryImpl(_platform.appInfo),
    () => _config,
  );

  /// Live call detection.
  late final CallActivityApi calls = CallActivityApi(
    CallRepositoryImpl(_platform.call, _platform.events),
  );

  /// The Android call screening role.
  late final CallScreeningApi callScreening = CallScreeningApi(
    CallScreeningRepositoryImpl(_platform.call),
  );

  /// App info and store update checks.
  late final VersionCheckApi versionCheck = VersionCheckApi(
    VersionRepositoryImpl(_platform.appInfo),
  );

  /// Play Integrity, App Attest and DeviceCheck tokens.
  late final IntegrityApi integrity = IntegrityApi(
    IntegrityRepositoryImpl(_platform.integrity),
  );

  late final AssessmentRepository _assessment = AssessmentRepositoryImpl(
    _platform.batch,
    _platform.ffi,
  );

  /// Runs [checks] (default: every detection check) in one platform round trip, in parallel
  /// with the native checks, and applies the configured policies. Cached results are reused
  /// unless [refresh] is set.
  Future<RiskAssessment> assess({
    Iterable<CheckType>? checks,
    bool refresh = false,
  }) async {
    final types = (checks ?? CheckType.values)
        .where((t) => t != CheckType.overlayAttack)
        .toList();
    final results = await _runner.runBatch(
      types,
      (needed) => _assessment.collect(needed, _config),
      refresh: refresh,
    );
    return RiskAssessment(results);
  }

  StreamController<ThreatEvent>? _threats;
  final List<StreamSubscription<Object?>> _live = [];

  /// Threat events: a check becoming detected, or a live event (screenshot, capture starting,
  /// overlay attack, VPN connecting). While listened to, the live platform streams are
  /// observed automatically.
  ///
  /// The package never terminates the app. Decide here what to do (log, warn, sign out, or
  /// call [DeviceSafety.terminateApp]).
  Stream<ThreatEvent> get threats {
    return (_threats ??= StreamController<ThreatEvent>.broadcast(
      onListen: _startThreats,
      onCancel: _stopThreats,
    )).stream;
  }

  void _startThreats() {
    void ignore(Object _) {}
    _live
      ..add(_bus.events.listen(_threats!.add))
      ..add(screen.onScreenshot.listen(null, onError: ignore))
      ..add(screen.captureChanges.listen(null, onError: ignore))
      ..add(overlayAttack.obscuredTouches.listen(null, onError: ignore))
      ..add(vpn.changes.listen(null, onError: ignore));
  }

  Future<void> _stopThreats() async {
    final subs = List.of(_live);
    _live.clear();
    await Future.wait(subs.map((s) => s.cancel()));
  }

  /// Releases streams. Only needed for clients created for tests.
  Future<void> dispose() async {
    await _stopThreats();
    await _threats?.close();
    await _bus.close();
  }
}

/// The package entry point.
///
/// ```dart
/// await DeviceSafety.initialize(DeviceSafetyConfig(defaultPolicy: .standard));
/// final root = await DeviceSafety.root.check();
/// final report = await DeviceSafety.assess();
/// DeviceSafety.threats.listen((e) => log('threat: $e'));
/// ```
abstract final class DeviceSafety {
  static DeviceSafetyClient? _instance;

  /// The client behind the static members, created on first use.
  static DeviceSafetyClient get instance =>
      _instance ??= _install(DeviceSafetyClient());

  static DeviceSafetyClient _install(DeviceSafetyClient client) {
    SecureScreen.blocker = (block) =>
        client.screen.blockScreenshots(block: block);
    return client;
  }

  /// Applies [config] (or the defaults: standard policy, fail open, 30 s cache, 5 s timeout).
  /// Optional; can be called again at any time, which clears cached results.
  static Future<void> initialize([DeviceSafetyConfig? config]) async {
    instance.configure(config ?? DeviceSafetyConfig());
  }

  /// Replaces the client, typically with one built on fake platform APIs (see
  /// `package:device_safety_info/testing.dart`). Returns the new client.
  @visibleForTesting
  static DeviceSafetyClient forTesting({
    DeviceSafetyPlatform? platform,
    DeviceSafetyConfig? config,
  }) => _instance = _install(
    DeviceSafetyClient(platform: platform, config: config),
  );

  /// Drops the client so the next use creates a fresh one.
  @visibleForTesting
  static void resetForTesting() => _instance = null;

  /// The active configuration.
  static DeviceSafetyConfig get config => instance.config;

  /// Root (Android) / jailbreak (iOS) detection.
  static RootApi get root => instance.root;

  /// Emulator / simulator detection.
  static EmulatorApi get emulator => instance.emulator;

  /// Hooking framework detection.
  static HookingApi get hooking => instance.hooking;

  /// Debugger detection.
  static DebuggerApi get debugger => instance.debugger;

  /// Device posture checks.
  static PostureApi get posture => instance.posture;

  /// Accessibility service abuse detection.
  static AccessibilityApi get accessibility => instance.accessibility;

  /// Notification listener abuse detection.
  static NotificationListenerApi get notificationListeners =>
      instance.notificationListeners;

  /// Screenshot / recording protection and capture detection.
  static ScreenProtectionApi get screen => instance.screen;

  /// App switcher (recents) privacy.
  static AppSwitcherApi get appSwitcher => instance.appSwitcher;

  /// Secure clipboard.
  static ClipboardApi get clipboard => instance.clipboard;

  /// Tapjacking protection.
  static OverlayAttackApi get overlayAttack => instance.overlayAttack;

  /// VPN / proxy detection.
  static VpnApi get vpn => instance.vpn;

  /// IOC domain blocklist.
  static IocDomainApi get ioc => instance.ioc;

  /// Known-malware package detection.
  static MalwareApi get malware => instance.malware;

  /// Repackaged / re-signed app detection.
  static TamperingApi get tampering => instance.tampering;

  /// Live call detection.
  static CallActivityApi get calls => instance.calls;

  /// The Android call screening role.
  static CallScreeningApi get callScreening => instance.callScreening;

  /// App info and store update checks.
  static VersionCheckApi get versionCheck => instance.versionCheck;

  /// Play Integrity, App Attest and DeviceCheck tokens.
  static IntegrityApi get integrity => instance.integrity;

  /// Runs many checks in one round trip. See [DeviceSafetyClient.assess].
  static Future<RiskAssessment> assess({
    Iterable<CheckType>? checks,
    bool refresh = false,
  }) => instance.assess(checks: checks, refresh: refresh);

  /// Threat events. See [DeviceSafetyClient.threats].
  static Stream<ThreatEvent> get threats => instance.threats;

  /// Closes the app. Opt-in: the package never does this by itself.
  ///
  /// Android finishes the activity task; iOS has no supported way to quit, so the process
  /// exits (Apple discourages this; prefer blocking the sensitive screen instead).
  static Future<Never> terminateApp() async {
    await SystemNavigator.pop();
    exit(0);
  }
}
