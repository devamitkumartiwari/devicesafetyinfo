import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/device_safety_channels.dart';
import '../ffi/device_safety_ffi.dart';

/// Root/jailbreak, hooking-framework, and debugger detection. Internal implementation detail —
/// reached only through DeviceSafetyInfo's forwarding members, which carry the full docs.
class RootDetection {
  RootDetection._();

  static Future<bool> get isRootedDevice async {
    // FFI root file check runs first via native stat() — harder to hook than
    // the JVM-level File.exists() calls inside the MethodChannel implementation.
    try {
      if (!kIsWeb && Platform.isAndroid) {
        if (DeviceSafetyFfi.checkRootFilesNative()) return true;
      }
    } catch (_) {}
    final bool? isRootedDevice = await DeviceSafetyChannels.method
        .invokeMethod<bool>('isRootedDevice');
    return isRootedDevice ?? false;
  }

  static Future<bool> get isHooked async => checkHooked();

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
          await DeviceSafetyChannels.method.invokeMethod('isHooked', {
            'exitProcessIfTrue': exitProcessIfTrue,
            'uninstallIfTrue': uninstallIfTrue,
          }) ??
          false;
    } on PlatformException catch (e) {
      debugPrint("Failed to check hooked: '${e.message}'.");
    }

    return ffiHooked || channelHooked;
  }

  static Future<bool> get isDebuggerAttached async {
    try {
      if (DeviceSafetyFfi.isDebuggerAttached()) return true;
    } catch (_) {}
    try {
      final bool? result = await DeviceSafetyChannels.method.invokeMethod<bool>(
        'isDebuggerAttached',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static bool checkFridaByMaps() => DeviceSafetyFfi.checkFridaByMaps();

  static bool checkRootFilesNative() => DeviceSafetyFfi.checkRootFilesNative();
}
