library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/ffi/device_safety_ffi.dart';

export 'idle_timeout_guard.dart';
export 'ioc_domain_blocker.dart';
export 'malware_package_detector.dart';
export 'new_version_check.dart';
export 'risk_summary.dart';
export 'screen_capture_check.dart';
export 'vpn_check.dart';
export 'vpn_state.dart';

/// The state of Google Play Protect, read from the OS setting its toggle controls. There is no
/// public "Play Protect API" — SafetyNet's Verify Apps API, which used to expose this, was fully
/// retired in January 2025. Android only; always [unknown] on iOS.
enum PlayProtectStatus { enabled, disabled, unknown }

/// What kind of call activity was detected. This can NEVER identify which specific app is
/// calling — that's not achievable on either platform; only that a call-like state exists.
enum CallActivitySource {
  /// Android only — confirmed native/cellular call via TelephonyManager.
  simCall,

  /// Android only — inferred from system-wide audio routing state (AudioManager mode / active
  /// recording & playback configurations). Generic across any VoIP app; app identity unavailable.
  voipCall,

  /// iOS only — CXCallObserver (CallKit) fired. Could be the native Phone app or any
  /// CallKit-integrated VoIP app; iOS's API cannot distinguish the two. Does NOT mean "confirmed
  /// VoIP" the way [voipCall] does on Android — some VoIP apps never route calls through CallKit
  /// at all and are invisible to this signal (a confirmed real gap, not a hypothetical one).
  callKitObserved,

  /// iOS only — the audio session lost focus to something else. Likely a call, but could also be
  /// Siri, an alarm, or another app taking audio focus — lower confidence than [callKitObserved].
  audioInterrupted,

  /// The native event payload didn't match any known source string.
  unknown,
}

/// Whether a [CallActivityEvent] represents a call starting or ending.
enum CallActivityState { started, ended }

/// An event from [DeviceSafetyInfo.onCallActivityChanged]. See [CallActivitySource] for exactly
/// what each value can and cannot prove.
class CallActivityEvent {
  /// What kind of call activity this is, and how confidently it can be attributed.
  final CallActivitySource source;

  /// Whether the call started or ended.
  final CallActivityState state;

  /// When this event occurred, as reported by the native platform.
  final DateTime timestamp;

  const CallActivityEvent({
    required this.source,
    required this.state,
    required this.timestamp,
  });

  /// Builds a [CallActivityEvent] from the raw map delivered over the platform channel.
  factory CallActivityEvent.fromMap(Map<Object?, Object?> map) {
    final rawSource = map['source'] as String?;
    final source = CallActivitySource.values.firstWhere(
      (s) => s.name == rawSource,
      orElse: () => CallActivitySource.unknown,
    );
    final state = map['state'] == 'started'
        ? CallActivityState.started
        : CallActivityState.ended;
    final millis = map['timestamp'] as int?;
    return CallActivityEvent(
      source: source,
      state: state,
      timestamp: millis != null
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now(),
    );
  }
}

/// Device and app security checks: root/jailbreak, hooking, debugger, screen capture, clipboard,
/// overlay-attack, and call-activity detection. See the package README for the full feature list
/// and usage examples for each member below.
class DeviceSafetyInfo {
  /// The underlying platform channel. Exposed for advanced use only — prefer the typed methods
  /// and streams below over calling this directly.
  static const MethodChannel channel = MethodChannel('device_safety_info');
  static const EventChannel _screenCaptureChannel = EventChannel(
    'device_safety_info/screen_capture_events',
  );
  static const EventChannel _screenshotChannel = EventChannel(
    'device_safety_info/screenshot_events',
  );
  static const EventChannel _overlayChannel = EventChannel(
    'device_safety_info/overlay_events',
  );
  static const EventChannel _clipboardChannel = EventChannel(
    'device_safety_info/clipboard_events',
  );
  static const EventChannel _callActivityChannel = EventChannel(
    'device_safety_info/call_activity_events',
  );

  static Stream<bool>? _onScreenCapturedChanged;
  static Stream<void>? _onScreenshotTaken;
  static Stream<void>? _onOverlayAttackDetected;
  static Stream<void>? _onClipboardChanged;
  static Stream<CallActivityEvent>? _onCallActivityChanged;

  /// Returns true if the application is running on external storage, false otherwise.
  /// Android only.
  static Future<bool> get isExternalStorage async {
    if (!kIsWeb && Platform.isAndroid) {
      final bool? isExternalStorage = await channel.invokeMethod<bool>(
        'isExternalStorage',
      );
      return isExternalStorage ?? false;
    }
    return false;
  }

  /// Returns true if the device is a real device, false if it's an emulator.
  static Future<bool> get isRealDevice async {
    final bool? isRealDevice = await channel.invokeMethod<bool>('isRealDevice');
    return isRealDevice ?? false;
  }

  /// Returns true if the device is rooted or jailbroken, false otherwise.
  /// Combines native C stat() check (Android) with the platform-level check.
  static Future<bool> get isRootedDevice async {
    // FFI root file check runs first via native stat() — harder to hook than
    // the JVM-level File.exists() calls inside the MethodChannel implementation.
    try {
      if (!kIsWeb && Platform.isAndroid) {
        if (DeviceSafetyFfi.checkRootFilesNative()) return true;
      }
    } catch (_) {}
    final bool? isRootedDevice = await channel.invokeMethod<bool>(
      'isRootedDevice',
    );
    return isRootedDevice ?? false;
  }

  /// Returns true if developer mode is enabled on the device, false otherwise.
  /// Android only.
  static Future<bool> get isDeveloperMode async {
    if (!kIsWeb && Platform.isAndroid) {
      bool? isDeveloperMode = await channel.invokeMethod<bool>(
        'isDeveloperMode',
      );
      return isDeveloperMode ?? false;
    }
    return false;
  }

  /// Returns true if a screen lock is set on the device, false otherwise.
  static Future<bool> get isScreenLock async {
    final bool? isScreenLock = await channel.invokeMethod<bool>('isScreenLock');
    return isScreenLock ?? false;
  }

  /// Returns true if a VPN connection is active on the device, false otherwise.
  static Future<bool> get isVPNCheck async {
    final bool? isVPNCheck = await channel.invokeMethod<bool>('isVPNCheck');
    return isVPNCheck ?? false;
  }

  /// Returns true if the app was installed from an official app store, false otherwise.
  static Future<bool> get isInstalledFromStore async {
    final bool? isInstalledFromStore = await channel.invokeMethod<bool>(
      'isInstalledFromStore',
    );
    return isInstalledFromStore ?? false;
  }

  /// Returns true if the screen is currently being captured, recorded, or mirrored.
  static Future<bool> get isScreenCaptured async {
    final bool? isScreenCaptured = await channel.invokeMethod<bool>(
      'isScreenCaptured',
    );
    return isScreenCaptured ?? false;
  }

  /// Fires whenever the screen-capture/recording/mirroring state changes.
  static Stream<bool> get onScreenCapturedChanged {
    _onScreenCapturedChanged ??= _screenCaptureChannel
        .receiveBroadcastStream()
        .map<bool>((event) => event as bool);
    return _onScreenCapturedChanged!;
  }

  /// Returns true if hooking frameworks are detected, false otherwise.
  /// Combines FFI-level /proc/self/maps scan with native platform check.
  static Future<bool> get isHooked async => checkHooked();

  /// Checks for hooking frameworks.
  /// Optionally exits the app or triggers uninstallation if hooked.
  static Future<bool> checkHooked({
    bool exitProcessIfTrue = false,
    bool uninstallIfTrue = false,
  }) async {
    // FFI maps scan runs first — reads /proc/self/maps in native C,
    // much harder to intercept than a JVM-level check.
    bool ffiHooked = false;
    try {
      ffiHooked = DeviceSafetyFfi.checkFridaByMaps();
    } catch (_) {}

    bool channelHooked = false;
    try {
      channelHooked =
          await channel.invokeMethod('isHooked', {
            'exitProcessIfTrue': exitProcessIfTrue,
            'uninstallIfTrue': uninstallIfTrue,
          }) ??
          false;
    } on PlatformException catch (e) {
      debugPrint("Failed to check hooked: '${e.message}'.");
    }

    return ffiHooked || channelHooked;
  }

  /// Returns true if a debugger is attached to the process.
  /// Uses native FFI (TracerPid / sysctl P_TRACED) first, then platform channel fallback.
  static Future<bool> get isDebuggerAttached async {
    try {
      if (DeviceSafetyFfi.isDebuggerAttached()) return true;
    } catch (_) {}
    try {
      final bool? result = await channel.invokeMethod<bool>(
        'isDebuggerAttached',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Scans /proc/self/maps for Frida signatures using native C (Android only).
  /// More tamper-resistant than the MethodChannel isHooked check alone.
  /// Always returns false on iOS — IOSSecuritySuite covers this via isHooked.
  static bool checkFridaByMaps() => DeviceSafetyFfi.checkFridaByMaps();

  /// Checks common root indicator file paths via native C stat() (Android only).
  /// More tamper-resistant than the MethodChannel isRootedDevice check alone.
  /// Always returns false on iOS — IOSSecuritySuite covers this via isRootedDevice.
  static bool checkRootFilesNative() => DeviceSafetyFfi.checkRootFilesNative();

  /// Fires whenever the user takes a screenshot.
  /// Android: API 34+ requires no permission; API 24–33 requires READ_MEDIA_IMAGES
  /// (declared by the host app at runtime). iOS: no permission needed.
  static Stream<void> get onScreenshotTaken {
    _onScreenshotTaken ??= _screenshotChannel
        .receiveBroadcastStream()
        .map<void>((_) {});
    return _onScreenshotTaken!;
  }

  /// Shows a solid-color overlay over the app when it enters the background
  /// (visible in the recent-apps switcher). Automatically hides on foreground.
  /// [argbColor] is an ARGB integer, e.g. 0xFF000000 for opaque black.
  /// Android + iOS.
  static Future<void> setRecentsOverlay({int argbColor = 0xFF000000}) async {
    try {
      await channel.invokeMethod('setRecentsOverlay', {'color': argbColor});
    } on PlatformException catch (e) {
      debugPrint("Failed to set recents overlay: '${e.message}'");
    }
  }

  /// Removes the recents overlay set by [setRecentsOverlay].
  static Future<void> clearRecentsOverlay() async {
    try {
      await channel.invokeMethod('clearRecentsOverlay');
    } on PlatformException catch (e) {
      debugPrint("Failed to clear recents overlay: '${e.message}'");
    }
  }

  /// Blocks or unblocks screenshots for the app.
  /// Android: FLAG_SECURE. iOS: UITextField isSecureTextEntry layer trick.
  static Future<void> blockScreenshots({bool block = true}) async {
    try {
      await channel.invokeMethod('blockScreenShots', {'block': block});
    } on PlatformException catch (e) {
      debugPrint("Failed to set screenshot blocking: '${e.message}'");
    }
  }

  /// Hides or shows the app in the recent apps list. Android only.
  static Future<void> hideMenu({bool hide = true}) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await channel.invokeMethod('hideMenu', {'hide': hide});
      } on PlatformException catch (e) {
        debugPrint("Failed to set app recents visibility: '${e.message}'");
      }
    }
  }

  /// Fires whenever a touch is delivered while this app's window is obscured (or partially
  /// obscured) by another app's overlay — tapjacking / overlay-phishing detection.
  /// Android only. iOS app sandboxing makes cross-app overlays structurally impossible, so
  /// listening on iOS throws a PlatformException('UNSUPPORTED_PLATFORM', ...) instead of
  /// silently staying quiet — a silent stream here would look identical to "checked, no attack
  /// found", which would be misleading for a feature that can't actually run on that platform.
  static Stream<void> get onOverlayAttackDetected {
    _onOverlayAttackDetected ??= _overlayChannel
        .receiveBroadcastStream()
        .map<void>((_) {});
    return _onOverlayAttackDetected!;
  }

  /// Drops touches delivered while the window is obscured by another app's overlay — the
  /// OS-level protect counterpart to [onOverlayAttackDetected], same detect+protect pairing as
  /// [blockScreenshots] for screenshots. Android only; throws on iOS for the same reason as
  /// [onOverlayAttackDetected].
  static Future<void> blockTouchesWhenObscured({bool block = true}) async {
    await channel.invokeMethod('blockTouchesWhenObscured', {'block': block});
  }

  /// Copies [text] to the system clipboard. When [sensitive] is true (the default), the OS is
  /// asked to treat the content as sensitive: Android hides it from the system clipboard preview
  /// UI (API 33+; a documented no-op below that) and iOS marks the pasteboard item local-only.
  /// When [autoClear] is set, the clipboard is automatically overwritten with empty content
  /// after that duration. Android + iOS.
  static Future<void> copyToClipboard(
    String text, {
    bool sensitive = true,
    Duration? autoClear,
  }) async {
    try {
      await channel.invokeMethod('copyToClipboard', {
        'text': text,
        'sensitive': sensitive,
        'autoClearMillis': autoClear?.inMilliseconds,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to copy to clipboard: '${e.message}'");
    }
  }

  /// Immediately clears the system clipboard. Android + iOS.
  static Future<void> clearClipboard() async {
    try {
      await channel.invokeMethod('clearClipboard');
    } on PlatformException catch (e) {
      debugPrint("Failed to clear clipboard: '${e.message}'");
    }
  }

  /// Fires whenever the system clipboard's contents change, from any app (not just this one).
  /// Android + iOS.
  static Stream<void> get onClipboardChanged {
    _onClipboardChanged ??= _clipboardChannel
        .receiveBroadcastStream()
        .map<void>((_) {});
    return _onClipboardChanged!;
  }

  /// Returns the raw component names of currently-enabled Accessibility services. Malware that
  /// abuses the Accessibility API (to read screen content or auto-click for the user) shows up
  /// here the same way a legitimate screen reader would — distinguishing malicious from
  /// legitimate services against your own known-good/known-bad list is left to the caller.
  /// Android only; always empty on iOS (no public API to enumerate this there).
  static Future<List<String>> get enabledAccessibilityServices async {
    if (!kIsWeb && Platform.isAndroid) {
      final result = await channel.invokeMethod<List<Object?>>(
        'getEnabledAccessibilityServices',
      );
      return result?.cast<String>() ?? const [];
    }
    return const [];
  }

  /// Returns true if at least one Accessibility service is currently enabled. Android only.
  static Future<bool> get isAnyAccessibilityServiceEnabled async =>
      (await enabledAccessibilityServices).isNotEmpty;

  /// Returns the current Google Play Protect status. Android only; always [PlayProtectStatus.unknown]
  /// on iOS. See [PlayProtectStatus] doc comment for the caveat on how this is read.
  static Future<PlayProtectStatus> get playProtectStatus async {
    if (!kIsWeb && Platform.isAndroid) {
      final raw = await channel.invokeMethod<int>('getPlayProtectStatus');
      switch (raw) {
        case 1:
          return PlayProtectStatus.enabled;
        case -1:
          return PlayProtectStatus.disabled;
        default:
          return PlayProtectStatus.unknown;
      }
    }
    return PlayProtectStatus.unknown;
  }

  /// Returns the raw component names of currently-enabled Notification Listener services. Malware
  /// that abuses this API (to read/intercept OTP and SMS notifications) shows up here the same way
  /// a legitimate notification-reading app would — distinguishing malicious from legitimate
  /// listeners against your own known-good/known-bad list is left to the caller.
  /// Android only; always empty on iOS (no OS-wide grant list exists there to enumerate).
  static Future<List<String>> get enabledNotificationListeners async {
    if (!kIsWeb && Platform.isAndroid) {
      final result = await channel.invokeMethod<List<Object?>>(
        'getEnabledNotificationListeners',
      );
      return result?.cast<String>() ?? const [];
    }
    return const [];
  }

  /// Returns true if at least one Notification Listener service is currently enabled. Android only.
  static Future<bool> get isAnyNotificationListenerEnabled async =>
      (await enabledNotificationListeners).isNotEmpty;

  /// Returns whether this app currently has install-unknown-apps ("sideloading") rights.
  /// IMPORTANT: on Android 8.0+ (the OS behind the vast majority of active devices), this can only
  /// answer "has THIS app been granted install rights" — it cannot detect whether some OTHER
  /// (potentially malicious) app on the device has sideloading rights, because that per-app grant
  /// isn't readable across app boundaries. A `false` result here is NOT evidence the device is safe
  /// from sideloaded malware; most apps (including yours) will read `false` simply because they
  /// never request that grant for themselves. Only on Android 7.x does this reflect the old
  /// device-wide toggle. Android only; always false on iOS.
  static Future<bool> get isUnknownSourcesEnabled async {
    if (!kIsWeb && Platform.isAndroid) {
      final result = await channel.invokeMethod<bool>(
        'isUnknownSourcesEnabled',
      );
      return result ?? false;
    }
    return false;
  }

  /// Returns whether this device supports the Call Screening role (Android 10+ / API 29+). Device
  /// capability only — says nothing about which app currently holds the role.
  /// Android only; always false on iOS.
  static Future<bool> get isCallScreeningRoleAvailable async {
    if (!kIsWeb && Platform.isAndroid) {
      final result = await channel.invokeMethod<bool>(
        'isCallScreeningRoleAvailable',
      );
      return result ?? false;
    }
    return false;
  }

  /// Returns whether THIS app currently holds the Call Screening role — only meaningful if your own
  /// app screens calls itself. There is no public Android API for a third-party app to detect
  /// whether a malicious app holds this role instead (RoleManager.getRoleHolders is a privileged
  /// system API); see [openCallScreeningRoleSettings] for the practical mitigation.
  /// Android only, API 29+; always false elsewhere.
  static Future<bool> get isCallScreeningRoleHeldByThisApp async {
    if (!kIsWeb && Platform.isAndroid) {
      final result = await channel.invokeMethod<bool>(
        'isCallScreeningRoleHeldByThisApp',
      );
      return result ?? false;
    }
    return false;
  }

  /// Opens the OS role picker so the user can review/change the current Call Screening app — the
  /// practical mitigation for malware silently blocking a bank's fraud-team calls, since this
  /// plugin cannot read the current role holder programmatically (see
  /// [isCallScreeningRoleHeldByThisApp]). Android only, API 29+; no-op elsewhere.
  static Future<void> openCallScreeningRoleSettings() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await channel.invokeMethod('openCallScreeningRoleSettings');
      } on PlatformException catch (e) {
        debugPrint(
          "Failed to open call screening role settings: '${e.message}'",
        );
      }
    }
  }

  /// Fires whenever any phone call — native SIM call or a VoIP call from any app (WhatsApp/Skype/
  /// Teams/Meet/imo/etc.) — starts or ends. Cannot identify which app is calling; see
  /// [CallActivitySource] for exactly what each platform can and cannot distinguish. Native
  /// listeners only run while this stream has an active subscriber. Android's SIM-call signal
  /// requires READ_PHONE_STATE, which this plugin cannot request itself (no permission-request
  /// dependency) — the host app must request runtime grant; without it, detection degrades to
  /// VoIP-only, silently, no error.
  static Stream<CallActivityEvent> get onCallActivityChanged {
    _onCallActivityChanged ??= _callActivityChannel
        .receiveBroadcastStream()
        .map(
          (event) => CallActivityEvent.fromMap(event as Map<Object?, Object?>),
        );
    return _onCallActivityChanged!;
  }

  /// Point-in-time check — does not require an active subscription to [onCallActivityChanged].
  static Future<bool> get isCallActive async {
    final result = await channel.invokeMethod<bool>('isCallActive');
    return result ?? false;
  }
}
