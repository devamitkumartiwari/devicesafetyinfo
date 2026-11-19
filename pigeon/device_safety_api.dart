// Platform interface for device_safety_info. After editing, regenerate with:
//   dart run pigeon --input pigeon/device_safety_api.dart
// and commit the generated files (CI fails if they're out of date).
//
// One input file because Pigeon can't share data classes across files; one @HostApi per feature.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'device_safety_info',
    dartOut: 'lib/src/core/platform/generated/device_safety_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/com/devamitkumartiwari/device_safety_info/generated/DeviceSafetyApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.devamitkumartiwari.device_safety_info.generated',
    ),
    swiftOut: 'ios/device_safety_info/Sources/device_safety_info/Generated/DeviceSafetyApi.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
// ---------------------------------------------------------------------------
// Shared messages
// ---------------------------------------------------------------------------
enum SignalLevelMsg { low, high }

/// One indicator. `id` is `<check>.<signal>` optionally followed by `:<detail>`, e.g.
/// `root.su_executable:/system/xbin/su`.
class SignalMsg {
  SignalMsg(this.id, this.level);
  String id;
  SignalLevelMsg level;
}

class CheckReportMsg {
  CheckReportMsg(this.signals, this.supported);
  List<SignalMsg> signals;

  /// False when the check can't run on this platform or OS version.
  bool supported;
}

class AccessibilityServiceMsg {
  AccessibilityServiceMsg(this.id, this.canRetrieveWindowContent);

  /// Component name, e.g. `com.example/.MyService`.
  String id;
  bool canRetrieveWindowContent;
}

class BatchRequestMsg {
  BatchRequestMsg(this.checkIds, this.malwarePackages);

  /// `CheckType.id` values.
  List<String> checkIds;

  /// Packages to look for when `malware` is requested.
  List<String> malwarePackages;
}

class BatchResultMsg {
  BatchResultMsg(
    this.reports,
    this.accessibilityServices,
    this.notificationListeners,
    this.installedPackages,
  );

  /// Keyed by `CheckType.id`, for every requested check the platform evaluates itself.
  Map<String, CheckReportMsg> reports;

  /// Raw lists for the checks whose allowlists live in Dart.
  List<AccessibilityServiceMsg> accessibilityServices;
  List<String> notificationListeners;
  List<String> installedPackages;
}

enum OverlayModeMsg { none, blur, color, image }

class OverlayConfigMsg {
  OverlayConfigMsg(this.mode, this.blurRadius, this.argbColor, this.imageBytes);
  OverlayModeMsg mode;
  double blurRadius;
  int? argbColor;
  Uint8List? imageBytes;
}

class AppInfoMsg {
  AppInfoMsg(this.packageName, this.version, this.buildNumber);
  String packageName;
  String version;
  String buildNumber;
}

enum CallSourceMsg {
  simCall,
  voipCall,
  callKitObserved,
  audioInterrupted,
  unknown,
}

class CallEventMsg {
  CallEventMsg(this.source, this.started, this.timestampMs);
  CallSourceMsg source;
  bool started;
  int timestampMs;
}

// ---------------------------------------------------------------------------
// Detection
// ---------------------------------------------------------------------------

@HostApi()
abstract class RootHostApi {
  @async
  CheckReportMsg rootCheck();

  @async
  CheckReportMsg emulatorCheck();
}

@HostApi()
abstract class HookingHostApi {
  @async
  CheckReportMsg hookCheck();

  CheckReportMsg debuggerCheck();
}

@HostApi()
abstract class PostureHostApi {
  @async
  CheckReportMsg developerMode();

  @async
  CheckReportMsg screenLock();

  @async
  CheckReportMsg storeInstall();

  @async
  CheckReportMsg externalStorage();

  @async
  CheckReportMsg unknownSources();

  @async
  CheckReportMsg playProtect();

  @async
  List<AccessibilityServiceMsg> enabledAccessibilityServices();

  @async
  List<String> enabledNotificationListeners();
}

/// Runs many checks in one round trip, in parallel on the platform side.
@HostApi()
abstract class BatchHostApi {
  @async
  BatchResultMsg runChecks(BatchRequestMsg request);
}

@HostApi()
abstract class VpnHostApi {
  @async
  CheckReportMsg vpnCheck();
}

@HostApi()
abstract class MalwareHostApi {
  /// The subset of [packages] that is installed.
  @async
  List<String> installedOf(List<String> packages);
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

@HostApi()
abstract class ScreenProtectionHostApi {
  void blockScreenshots(bool block);
  bool isScreenshotBlocked();
  void setOverlayMode(OverlayConfigMsg config);
  void clearOverlayMode();
  CheckReportMsg screenCaptureCheck();
  bool isRecordingDetectionSupported();
}

@HostApi()
abstract class AppSwitcherHostApi {
  void setRecentsOverlay(int argb);
  void clearRecentsOverlay();
  void hideFromRecents(bool hide);
}

@HostApi()
abstract class ClipboardHostApi {
  /// [clearAfterMs] null or <= 0 means never clear.
  void copySecure(String text, bool sensitive, int? clearAfterMs);
  void clear();
}

@HostApi()
abstract class OverlayAttackHostApi {
  void blockTouchesWhenObscured(bool block);
}

@HostApi()
abstract class CallHostApi {
  bool isCallActive();
  bool isScreeningRoleAvailable();
  bool isScreeningRoleHeld();
  void openScreeningRoleSettings();
}

@HostApi()
abstract class AppInfoHostApi {
  AppInfoMsg packageInfo();
}

@HostApi()
abstract class IntegrityHostApi {
  bool isPlayIntegrityAvailable();

  @async
  void preparePlayIntegrity(int cloudProjectNumber);

  @async
  String requestPlayIntegrityToken(String requestHash);

  bool isAppAttestSupported();

  @async
  String generateAppAttestKey();

  @async
  String attestAppAttestKey(String keyId, String challenge);

  @async
  String generateAppAttestAssertion(String keyId, String clientData);

  bool isDeviceCheckSupported();

  @async
  String generateDeviceCheckToken();
}

// ---------------------------------------------------------------------------
// Live events
// ---------------------------------------------------------------------------

@EventChannelApi()
abstract class DeviceSafetyEvents {
  /// Epoch milliseconds of each screenshot.
  int screenshotTaken();

  /// Capture/mirroring state; the current state is sent first.
  bool screenCaptureChanged();

  /// Recording state (Android 15+, iOS); the current state is sent first.
  bool screenRecordingChanged();

  /// Epoch milliseconds of each obscured touch (Android).
  int overlayAttack();

  /// Epoch milliseconds of each clipboard change.
  int clipboardChanged();

  /// Whether a VPN is active, sent on every connectivity change.
  bool vpnChanged();

  CallEventMsg callActivity();
}
