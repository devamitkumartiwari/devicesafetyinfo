import 'generated/device_safety_api.g.dart' as api;
import 'native_checks_ffi.dart';

/// Every platform entry point the package uses: the Pigeon host APIs, the live event streams
/// and the native FFI checks. The default constructor uses the real ones; tests pass fakes
/// (implement the generated API classes, or [PlatformEvents] / [NativeChecksSource]).
final class DeviceSafetyPlatform {
  /// Creates the bundle, using the real implementation for anything not given.
  DeviceSafetyPlatform({
    api.RootHostApi? root,
    api.HookingHostApi? hooking,
    api.PostureHostApi? posture,
    api.BatchHostApi? batch,
    api.VpnHostApi? vpn,
    api.MalwareHostApi? malware,
    api.ScreenProtectionHostApi? screen,
    api.AppSwitcherHostApi? appSwitcher,
    api.ClipboardHostApi? clipboard,
    api.OverlayAttackHostApi? overlayAttack,
    api.CallHostApi? call,
    api.AppInfoHostApi? appInfo,
    api.IntegrityHostApi? integrity,
    api.EnvironmentHostApi? environment,
    PlatformEvents? events,
    NativeChecksSource? ffi,
  }) : root = root ?? api.RootHostApi(),
       hooking = hooking ?? api.HookingHostApi(),
       posture = posture ?? api.PostureHostApi(),
       batch = batch ?? api.BatchHostApi(),
       vpn = vpn ?? api.VpnHostApi(),
       malware = malware ?? api.MalwareHostApi(),
       screen = screen ?? api.ScreenProtectionHostApi(),
       appSwitcher = appSwitcher ?? api.AppSwitcherHostApi(),
       clipboard = clipboard ?? api.ClipboardHostApi(),
       overlayAttack = overlayAttack ?? api.OverlayAttackHostApi(),
       call = call ?? api.CallHostApi(),
       appInfo = appInfo ?? api.AppInfoHostApi(),
       integrity = integrity ?? api.IntegrityHostApi(),
       environment = environment ?? api.EnvironmentHostApi(),
       events = events ?? const PlatformEvents(),
       ffi = ffi ?? const NativeChecksFfi();

  final api.RootHostApi root;
  final api.HookingHostApi hooking;
  final api.PostureHostApi posture;
  final api.BatchHostApi batch;
  final api.VpnHostApi vpn;
  final api.MalwareHostApi malware;
  final api.ScreenProtectionHostApi screen;
  final api.AppSwitcherHostApi appSwitcher;
  final api.ClipboardHostApi clipboard;
  final api.OverlayAttackHostApi overlayAttack;
  final api.CallHostApi call;
  final api.AppInfoHostApi appInfo;
  final api.IntegrityHostApi integrity;
  final api.EnvironmentHostApi environment;
  final PlatformEvents events;
  final NativeChecksSource ffi;
}

/// The live platform event streams. Each getter returns a new single-subscription stream
/// backed by a platform event channel.
class PlatformEvents {
  /// Uses the generated event channels.
  const PlatformEvents();

  /// Epoch milliseconds of each screenshot.
  Stream<int> get screenshots => api.screenshotTaken();

  /// Screen capture (recording or mirroring) state; the current state comes first.
  Stream<bool> get captureChanges => api.screenCaptureChanged();

  /// Screen recording state; the current state comes first where supported.
  Stream<bool> get recordingChanges => api.screenRecordingChanged();

  /// Epoch milliseconds of each obscured touch.
  Stream<int> get overlayAttacks => api.overlayAttack();

  /// Epoch milliseconds of each clipboard change.
  Stream<int> get clipboardChanges => api.clipboardChanged();

  /// Whether a VPN is active, on each connectivity change.
  Stream<bool> get vpnChanges => api.vpnChanged();

  /// Call start/end events.
  Stream<api.CallEventMsg> get callActivity => api.callActivity();
}
