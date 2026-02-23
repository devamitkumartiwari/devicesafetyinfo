library device_safety_info;

import 'dart:async';

import 'package:flutter/services.dart';

export 'screen_capture_check.dart';

class DeviceSafetyInfo {
  static const MethodChannel channel = MethodChannel('device_safety_info');
  static const EventChannel _screenCaptureChannel = EventChannel('device_safety_info/screen_capture_events');

  static Stream<bool>? _onScreenCapturedChanged;

  // Returns true if the application is running on external storage, false otherwise.
  // Android only.
  static Future<bool> get isExternalStorage async {
    final bool? isExternalStorage = await channel.invokeMethod<bool>('isExternalStorage');
    return isExternalStorage ?? false;
  }

  // Returns true if the device is a real device, false if it's an emulator.
  static Future<bool> get isRealDevice async {
    final bool? isRealDevice = await channel.invokeMethod<bool>('isRealDevice');
    return isRealDevice ?? false;
  }

  // Returns true if the device is rooted or jailbroken, false otherwise.
  static Future<bool> get isRootedDevice async {
    final bool? isRootedDevice = await channel.invokeMethod<bool>('isRootedDevice');
    return isRootedDevice ?? true;
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
    return isVPNCheck ?? true;
  }

  // Returns true if the app was installed from an official app store, false otherwise.
  static Future<bool> get isInstalledFromStore async {
    final bool? isInstalledFromStore = await channel.invokeMethod<bool>('isInstalledFromStore');
    return isInstalledFromStore ?? false;
  }

  static Future<bool> get isScreenCaptured async {
    final bool? isScreenCaptured = await channel.invokeMethod<bool>('isScreenCaptured');
    return isScreenCaptured ?? false;
  }
  
  static Stream<bool> get onScreenCapturedChanged {
    _onScreenCapturedChanged ??= _screenCaptureChannel.receiveBroadcastStream().map<bool>((event) => event as bool);
    return _onScreenCapturedChanged!;
  }

  // Returns true if hooking frameworks are detected, false otherwise.
  static Future<bool> get isHooked async => checkHooked();

  // Checks for hooking frameworks.
  // Optionally exits the app or triggers uninstallation if hooked.
  static Future<bool> checkHooked({
    bool exitProcessIfTrue = false,
    bool uninstallIfTrue = false,
  }) async {
    try {
      return await channel.invokeMethod('isHooked', {
            'exitProcessIfTrue': exitProcessIfTrue,
            'uninstallIfTrue': uninstallIfTrue,
          }) ??
          false;
    } on PlatformException catch (e) {
      print("Failed to check hooked: '${e.message}'.");
      return false;
    }
  }

  // Blocks or unblocks screenshots for the app. Android only.
  static Future<void> blockScreenshots({bool block = true}) async {
    try {
      await channel.invokeMethod('blockScreenShots', {'block': block});
    } on PlatformException catch (e) {
      print("Failed to set screenshot blocking: '${e.message}'");
    }
  }

  // Hides or shows the app in the recent apps list. Android only.
  static Future<void> hideMenu({bool hide = true}) async {
    try {
      await channel.invokeMethod('hideMenu', {'hide': hide});
    } on PlatformException catch (e) {
      print("Failed to set app recents visibility: '${e.message}'");
    }
  }
}
