library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/ffi/device_safety_ffi.dart';

export 'new_version_check.dart';
export 'screen_capture_check.dart';
export 'vpn_check.dart';
export 'vpn_state.dart';

class DeviceSafetyInfo {
  static const MethodChannel channel = MethodChannel('device_safety_info');
  static const EventChannel _screenCaptureChannel =
      EventChannel('device_safety_info/screen_capture_events');
  static const EventChannel _screenshotChannel =
      EventChannel('device_safety_info/screenshot_events');

  static Stream<bool>? _onScreenCapturedChanged;
  static Stream<void>? _onScreenshotTaken;

  // Returns true if the application is running on external storage, false otherwise.
  // Android only.
  static Future<bool> get isExternalStorage async {
    final bool? isExternalStorage =
        await channel.invokeMethod<bool>('isExternalStorage');
    return isExternalStorage ?? false;
  }

  // Returns true if the device is a real device, false if it's an emulator.
  static Future<bool> get isRealDevice async {
    final bool? isRealDevice = await channel.invokeMethod<bool>('isRealDevice');
    return isRealDevice ?? false;
  }

  // Returns true if the device is rooted or jailbroken, false otherwise.
  // Combines native C stat() check (Android) with the platform-level check.
  static Future<bool> get isRootedDevice async {
    // FFI root file check runs first via native stat() — harder to hook than
    // the JVM-level File.exists() calls inside the MethodChannel implementation.
    try {
      if (DeviceSafetyFfi.checkRootFilesNative()) return true;
    } catch (_) {}
    final bool? isRootedDevice =
        await channel.invokeMethod<bool>('isRootedDevice');
    return isRootedDevice ?? false;
  }

  // Returns true if developer mode is enabled on the device, false otherwise.
  // Android only.
  static Future<bool> get isDeveloperMode async {
    bool? isDeveloperMode = await channel.invokeMethod<bool>('isDeveloperMode');
    return isDeveloperMode ?? false;
  }

  // Returns true if a screen lock is set on the device, false otherwise.
  static Future<bool> get isScreenLock async {
    final bool? isScreenLock = await channel.invokeMethod<bool>('isScreenLock');
    return isScreenLock ?? false;
  }

  // Returns true if a VPN connection is active on the device, false otherwise.
  static Future<bool> get isVPNCheck async {
    final bool? isVPNCheck = await channel.invokeMethod<bool>('isVPNCheck');
    return isVPNCheck ?? false;
  }

  // Returns true if the app was installed from an official app store, false otherwise.
  static Future<bool> get isInstalledFromStore async {
    final bool? isInstalledFromStore =
        await channel.invokeMethod<bool>('isInstalledFromStore');
    return isInstalledFromStore ?? false;
  }

  static Future<bool> get isScreenCaptured async {
    final bool? isScreenCaptured =
        await channel.invokeMethod<bool>('isScreenCaptured');
    return isScreenCaptured ?? false;
  }

  static Stream<bool> get onScreenCapturedChanged {
    _onScreenCapturedChanged ??= _screenCaptureChannel
        .receiveBroadcastStream()
        .map<bool>((event) => event as bool);
    return _onScreenCapturedChanged!;
  }

  // Returns true if hooking frameworks are detected, false otherwise.
  // Combines FFI-level /proc/self/maps scan with native platform check.
  static Future<bool> get isHooked async => checkHooked();

  // Checks for hooking frameworks.
  // Optionally exits the app or triggers uninstallation if hooked.
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
      channelHooked = await channel.invokeMethod('isHooked', {
            'exitProcessIfTrue': exitProcessIfTrue,
            'uninstallIfTrue': uninstallIfTrue,
          }) ??
          false;
    } on PlatformException catch (e) {
      debugPrint("Failed to check hooked: '${e.message}'.");
    }

    return ffiHooked || channelHooked;
  }

  // Returns true if a debugger is attached to the process.
  // Uses native FFI (TracerPid / sysctl P_TRACED) first, then platform channel fallback.
  static Future<bool> get isDebuggerAttached async {
    try {
      if (DeviceSafetyFfi.isDebuggerAttached()) return true;
    } catch (_) {}
    try {
      final bool? result =
          await channel.invokeMethod<bool>('isDebuggerAttached');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // Scans /proc/self/maps for Frida signatures using native C (Android only).
  // More tamper-resistant than the MethodChannel isHooked check alone.
  // Always returns false on iOS — IOSSecuritySuite covers this via isHooked.
  static bool checkFridaByMaps() => DeviceSafetyFfi.checkFridaByMaps();

  // Checks common root indicator file paths via native C stat() (Android only).
  // More tamper-resistant than the MethodChannel isRootedDevice check alone.
  // Always returns false on iOS — IOSSecuritySuite covers this via isRootedDevice.
  static bool checkRootFilesNative() => DeviceSafetyFfi.checkRootFilesNative();

  // Fires whenever the user takes a screenshot.
  // Android: API 34+ requires no permission; API 24–33 requires READ_MEDIA_IMAGES
  // (declared by the host app at runtime). iOS: no permission needed.
  static Stream<void> get onScreenshotTaken {
    _onScreenshotTaken ??=
        _screenshotChannel.receiveBroadcastStream().map<void>((_) {});
    return _onScreenshotTaken!;
  }

  // Shows a solid-color overlay over the app when it enters the background
  // (visible in the recent-apps switcher). Automatically hides on foreground.
  // [argbColor] is an ARGB integer, e.g. 0xFF000000 for opaque black.
  // Android + iOS.
  static Future<void> setRecentsOverlay({int argbColor = 0xFF000000}) async {
    try {
      await channel.invokeMethod('setRecentsOverlay', {'color': argbColor});
    } on PlatformException catch (e) {
      debugPrint("Failed to set recents overlay: '${e.message}'");
    }
  }

  // Removes the recents overlay set by [setRecentsOverlay].
  static Future<void> clearRecentsOverlay() async {
    try {
      await channel.invokeMethod('clearRecentsOverlay');
    } on PlatformException catch (e) {
      debugPrint("Failed to clear recents overlay: '${e.message}'");
    }
  }

  // Blocks or unblocks screenshots for the app.
  // Android: FLAG_SECURE. iOS: UITextField isSecureTextEntry layer trick.
  static Future<void> blockScreenshots({bool block = true}) async {
    try {
      await channel.invokeMethod('blockScreenShots', {'block': block});
    } on PlatformException catch (e) {
      debugPrint("Failed to set screenshot blocking: '${e.message}'");
    }
  }

  // Hides or shows the app in the recent apps list. Android only.
  static Future<void> hideMenu({bool hide = true}) async {
    try {
      await channel.invokeMethod('hideMenu', {'hide': hide});
    } on PlatformException catch (e) {
      debugPrint("Failed to set app recents visibility: '${e.message}'");
    }
  }
}
