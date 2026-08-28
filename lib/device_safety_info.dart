/// Device and app security checks for Flutter: root/jailbreak, hooking, and debugger detection;
/// screenshot and screen-recording protection; clipboard, overlay-attack, and malware defenses;
/// VPN and app-update checks. See the package README for the full feature list and examples.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'src/app_switcher_privacy/app_switcher_privacy.dart';
import 'src/call_activity/call_activity.dart';
import 'src/clipboard/clipboard_protection.dart';
import 'src/core/device_safety_channels.dart';
import 'src/device_checks/device_checks.dart';
import 'src/overlay_attack/overlay_attack_detector.dart';
import 'src/root_detection/root_detection.dart';
import 'src/screen_capture/screen_capture_detector.dart';
import 'src/screenshot/screenshot_overlay_mode.dart';
import 'src/screenshot/screenshot_protection.dart';
import 'src/vpn/vpn_check.dart';

export 'idle_timeout_guard.dart';
export 'ioc_domain_blocker.dart';
export 'malware_package_detector.dart';
export 'new_version_check.dart';
export 'risk_summary.dart';
export 'screen_capture_check.dart';
export 'vpn_check.dart';
export 'vpn_state.dart';
export 'src/call_activity/call_activity.dart'
    show CallActivitySource, CallActivityState, CallActivityEvent;
export 'src/device_checks/device_checks.dart' show PlayProtectStatus;
export 'src/screen_recording/screen_recording_detector.dart';
export 'src/screenshot/screenshot_overlay_mode.dart';
export 'src/screenshot/secure_screen.dart';

/// Device and app security checks: root/jailbreak, hooking, debugger, screen capture, clipboard,
/// overlay-attack, and call-activity detection. See the package README for the full feature list
/// and usage examples for each member below.
class DeviceSafetyInfo {
  DeviceSafetyInfo._();

  /// The underlying platform channel. Exposed for advanced use only — prefer the typed methods
  /// and streams below over calling this directly.
  static const MethodChannel channel = DeviceSafetyChannels.method;

  /// Returns true if the application is running on external storage, false otherwise.
  /// Android only.
  static Future<bool> get isExternalStorage => DeviceChecks.isExternalStorage;

  /// Returns true if the device is a real device, false if it's an emulator.
  static Future<bool> get isRealDevice => DeviceChecks.isRealDevice;

  /// Returns true if the device is rooted or jailbroken, false otherwise.
  /// Combines native C stat() check (Android) with the platform-level check.
  static Future<bool> get isRootedDevice => RootDetection.isRootedDevice;

  /// Returns true if developer mode is enabled on the device, false otherwise.
  /// Android only.
  static Future<bool> get isDeveloperMode => DeviceChecks.isDeveloperMode;

  /// Returns true if a screen lock is set on the device, false otherwise.
  static Future<bool> get isScreenLock => DeviceChecks.isScreenLock;

  /// Returns true if a VPN connection is active on the device, false otherwise.
  static Future<bool> get isVPNCheck => VPNCheck.isVpnActive;

  /// Returns true if the app was installed from an official app store, false otherwise.
  static Future<bool> get isInstalledFromStore =>
      DeviceChecks.isInstalledFromStore;

  /// Returns true if the screen is currently being captured, recorded, or mirrored.
  static Future<bool> get isScreenCaptured =>
      ScreenCaptureDetector.isScreenCaptured;

  /// Fires whenever the screen-capture/recording/mirroring state changes.
  static Stream<bool> get onScreenCapturedChanged =>
      ScreenCaptureDetector.onScreenCapturedChanged;

  /// Returns true if hooking frameworks are detected, false otherwise.
  /// Combines FFI-level /proc/self/maps scan with native platform check.
  static Future<bool> get isHooked => RootDetection.isHooked;

  /// Checks for hooking frameworks.
  /// Optionally exits the app or triggers uninstallation if hooked.
  static Future<bool> checkHooked({
    bool exitProcessIfTrue = false,
    bool uninstallIfTrue = false,
  }) => RootDetection.checkHooked(
    exitProcessIfTrue: exitProcessIfTrue,
    uninstallIfTrue: uninstallIfTrue,
  );

  /// Returns true if a debugger is attached to the process.
  /// Uses native FFI (TracerPid / sysctl P_TRACED) first, then platform channel fallback.
  static Future<bool> get isDebuggerAttached =>
      RootDetection.isDebuggerAttached;

  /// Scans /proc/self/maps for Frida signatures using native C (Android only).
  /// More tamper-resistant than the MethodChannel isHooked check alone.
  /// Always returns false on iOS — IOSSecuritySuite covers this via isHooked.
  static bool checkFridaByMaps() => RootDetection.checkFridaByMaps();

  /// Checks common root indicator file paths via native C stat() (Android only).
  /// More tamper-resistant than the MethodChannel isRootedDevice check alone.
  /// Always returns false on iOS — IOSSecuritySuite covers this via isRootedDevice.
  static bool checkRootFilesNative() => RootDetection.checkRootFilesNative();

  /// Fires whenever the user takes a screenshot.
  /// Android: API 34+ requires no permission; API 24–33 requires READ_MEDIA_IMAGES
  /// (declared by the host app at runtime). iOS: no permission needed.
  static Stream<void> get onScreenshotTaken =>
      ScreenshotProtection.onScreenshotTaken;

  /// Shows a solid-color overlay over the app when it enters the background
  /// (visible in the recent-apps switcher). Automatically hides on foreground.
  /// [argbColor] is an ARGB integer, e.g. 0xFF000000 for opaque black.
  /// Android + iOS.
  static Future<void> setRecentsOverlay({int argbColor = 0xFF000000}) =>
      AppSwitcherPrivacy.setRecentsOverlay(argbColor: argbColor);

  /// Removes the recents overlay set by [setRecentsOverlay].
  static Future<void> clearRecentsOverlay() =>
      AppSwitcherPrivacy.clearRecentsOverlay();

  /// Blocks or unblocks screenshots for the app.
  /// Android: FLAG_SECURE. iOS: UITextField isSecureTextEntry layer trick.
  static Future<void> blockScreenshots({bool block = true}) =>
      ScreenshotProtection.block(block: block);

  /// Returns true if screenshot blocking is currently engaged.
  static Future<bool> get isScreenshotBlocked => ScreenshotProtection.isBlocked;

  /// Flips screenshot blocking to the opposite of its current state.
  static Future<void> toggleScreenshotBlocking() =>
      ScreenshotProtection.toggle();

  /// Shows a live overlay (blur, solid color, or image) over the active screen whenever a
  /// screenshot/recording is detected — a branded "content hidden" placeholder instead of the
  /// plain black rectangle [blockScreenshots] alone produces (FLAG_SECURE/the iOS secure-layer
  /// trick prevent the OS from rendering anything at all into a capture, so no overlay content can
  /// ever appear inside the capture itself — this is a visible, on-screen effect only).
  /// [blurRadius] applies to [ScreenshotOverlayMode.blur] (Android needs API 31+ for a true blur;
  /// below that it degrades to a translucent scrim). [argbColor] applies to
  /// [ScreenshotOverlayMode.color]. [imageBytes] applies to [ScreenshotOverlayMode.image].
  /// Android + iOS.
  static Future<void> setScreenshotOverlayMode({
    required ScreenshotOverlayMode mode,
    double blurRadius = 10,
    int? argbColor,
    Uint8List? imageBytes,
  }) => ScreenshotProtection.setOverlayMode(
    mode: mode,
    blurRadius: blurRadius,
    argbColor: argbColor,
    imageBytes: imageBytes,
  );

  /// Removes the overlay set by [setScreenshotOverlayMode].
  static Future<void> clearScreenshotOverlayMode() =>
      ScreenshotProtection.clearOverlayMode();

  /// Hides or shows the app in the recent apps list. Android only.
  static Future<void> hideMenu({bool hide = true}) =>
      AppSwitcherPrivacy.hideMenu(hide: hide);

  /// Fires whenever a touch is delivered while this app's window is obscured (or partially
  /// obscured) by another app's overlay — tapjacking / overlay-phishing detection.
  /// Android only. iOS app sandboxing makes cross-app overlays structurally impossible, so
  /// listening on iOS throws a PlatformException('UNSUPPORTED_PLATFORM', ...) instead of
  /// silently staying quiet — a silent stream here would look identical to "checked, no attack
  /// found", which would be misleading for a feature that can't actually run on that platform.
  static Stream<void> get onOverlayAttackDetected =>
      OverlayAttackDetector.onOverlayAttackDetected;

  /// Drops touches delivered while the window is obscured by another app's overlay — the
  /// OS-level protect counterpart to [onOverlayAttackDetected], same detect+protect pairing as
  /// [blockScreenshots] for screenshots. Android only; throws on iOS for the same reason as
  /// [onOverlayAttackDetected].
  static Future<void> blockTouchesWhenObscured({bool block = true}) =>
      OverlayAttackDetector.blockTouchesWhenObscured(block: block);

  /// Copies [text] to the system clipboard. When [sensitive] is true (the default), the OS is
  /// asked to treat the content as sensitive: Android hides it from the system clipboard preview
  /// UI (API 33+; a documented no-op below that) and iOS marks the pasteboard item local-only.
  /// When [autoClear] is set, the clipboard is automatically overwritten with empty content
  /// after that duration. Android + iOS.
  static Future<void> copyToClipboard(
    String text, {
    bool sensitive = true,
    Duration? autoClear,
  }) => ClipboardProtection.copyToClipboard(
    text,
    sensitive: sensitive,
    autoClear: autoClear,
  );

  /// Immediately clears the system clipboard. Android + iOS.
  static Future<void> clearClipboard() => ClipboardProtection.clearClipboard();

  /// Fires whenever the system clipboard's contents change, from any app (not just this one).
  /// Android + iOS.
  static Stream<void> get onClipboardChanged =>
      ClipboardProtection.onClipboardChanged;

  /// Returns the raw component names of currently-enabled Accessibility services. Malware that
  /// abuses the Accessibility API (to read screen content or auto-click for the user) shows up
  /// here the same way a legitimate screen reader would — distinguishing malicious from
  /// legitimate services against your own known-good/known-bad list is left to the caller.
  /// Android only; always empty on iOS (no public API to enumerate this there).
  static Future<List<String>> get enabledAccessibilityServices =>
      DeviceChecks.enabledAccessibilityServices;

  /// Returns true if at least one Accessibility service is currently enabled. Android only.
  static Future<bool> get isAnyAccessibilityServiceEnabled =>
      DeviceChecks.isAnyAccessibilityServiceEnabled;

  /// Returns the current Google Play Protect status. Android only; always [PlayProtectStatus.unknown]
  /// on iOS. See [PlayProtectStatus] doc comment for the caveat on how this is read.
  static Future<PlayProtectStatus> get playProtectStatus =>
      DeviceChecks.playProtectStatus;

  /// Returns the raw component names of currently-enabled Notification Listener services. Malware
  /// that abuses this API (to read/intercept OTP and SMS notifications) shows up here the same way
  /// a legitimate notification-reading app would — distinguishing malicious from legitimate
  /// listeners against your own known-good/known-bad list is left to the caller.
  /// Android only; always empty on iOS (no OS-wide grant list exists there to enumerate).
  static Future<List<String>> get enabledNotificationListeners =>
      DeviceChecks.enabledNotificationListeners;

  /// Returns true if at least one Notification Listener service is currently enabled. Android only.
  static Future<bool> get isAnyNotificationListenerEnabled =>
      DeviceChecks.isAnyNotificationListenerEnabled;

  /// Returns whether this app currently has install-unknown-apps ("sideloading") rights.
  /// IMPORTANT: on Android 8.0+ (the OS behind the vast majority of active devices), this can only
  /// answer "has THIS app been granted install rights" — it cannot detect whether some OTHER
  /// (potentially malicious) app on the device has sideloading rights, because that per-app grant
  /// isn't readable across app boundaries. A `false` result here is NOT evidence the device is safe
  /// from sideloaded malware; most apps (including yours) will read `false` simply because they
  /// never request that grant for themselves. Only on Android 7.x does this reflect the old
  /// device-wide toggle. Android only; always false on iOS.
  static Future<bool> get isUnknownSourcesEnabled =>
      DeviceChecks.isUnknownSourcesEnabled;

  /// Returns whether this device supports the Call Screening role (Android 10+ / API 29+). Device
  /// capability only — says nothing about which app currently holds the role.
  /// Android only; always false on iOS.
  static Future<bool> get isCallScreeningRoleAvailable =>
      DeviceChecks.isCallScreeningRoleAvailable;

  /// Returns whether THIS app currently holds the Call Screening role — only meaningful if your own
  /// app screens calls itself. There is no public Android API for a third-party app to detect
  /// whether a malicious app holds this role instead (RoleManager.getRoleHolders is a privileged
  /// system API); see [openCallScreeningRoleSettings] for the practical mitigation.
  /// Android only, API 29+; always false elsewhere.
  static Future<bool> get isCallScreeningRoleHeldByThisApp =>
      DeviceChecks.isCallScreeningRoleHeldByThisApp;

  /// Opens the OS role picker so the user can review/change the current Call Screening app — the
  /// practical mitigation for malware silently blocking a bank's fraud-team calls, since this
  /// plugin cannot read the current role holder programmatically (see
  /// [isCallScreeningRoleHeldByThisApp]). Android only, API 29+; no-op elsewhere.
  static Future<void> openCallScreeningRoleSettings() =>
      DeviceChecks.openCallScreeningRoleSettings();

  /// Fires whenever any phone call — native SIM call or a VoIP call from any app (WhatsApp/Skype/
  /// Teams/Meet/imo/etc.) — starts or ends. Cannot identify which app is calling; see
  /// [CallActivitySource] for exactly what each platform can and cannot distinguish. Native
  /// listeners only run while this stream has an active subscriber. Android's SIM-call signal
  /// requires READ_PHONE_STATE, which this plugin cannot request itself (no permission-request
  /// dependency) — the host app must request runtime grant; without it, detection degrades to
  /// VoIP-only, silently, no error.
  static Stream<CallActivityEvent> get onCallActivityChanged =>
      CallActivity.onCallActivityChanged;

  /// Point-in-time check — does not require an active subscription to [onCallActivityChanged].
  static Future<bool> get isCallActive => CallActivity.isCallActive;
}
