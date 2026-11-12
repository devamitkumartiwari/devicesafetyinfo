import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/device_safety_channels.dart';
import '../ffi/device_safety_ffi.dart';
import '../core/risk_check_result.dart';

/// Root/jailbreak, hooking-framework, and debugger detection. Internal implementation detail —
/// reached only through DeviceSafetyInfo's forwarding members, which carry the full docs.
class RootDetection {
  RootDetection._();

  /// `true` only for high-risk indicators — see [RiskLevel.high].
  static Future<bool> get isRootedDevice async {
    // FFI root file check runs first via native stat() — harder to hook than
    // the JVM-level File.exists() calls inside the MethodChannel implementation.
    // checkRootFilesNative() only reports high-risk files (executable su, Magisk, ...).
    try {
      if (!kIsWeb && Platform.isAndroid) {
        if (DeviceSafetyFfi.checkRootFilesNative()) return true;
      }
    } catch (_) {}
    final bool? isRootedDevice = await DeviceSafetyChannels.method
        .invokeMethod<bool>('isRootedDevice');
    return isRootedDevice ?? false;
  }

  static Future<RiskCheckResult> get rootCheck async {
    RiskCheckResult result;
    try {
      final map = await DeviceSafetyChannels.method
          .invokeMethod<Map<Object?, Object?>>('rootCheck');
      result = map == null
          ? RiskCheckResult.clean
          : RiskCheckResult.fromMap(map);
    } on MissingPluginException {
      // Platform without a rootCheck implementation: fall back to the boolean check.
      final rooted =
          await DeviceSafetyChannels.method.invokeMethod<bool>(
            'isRootedDevice',
          ) ??
          false;
      result = rooted
          ? const RiskCheckResult(
              level: RiskLevel.high,
              highRiskSignals: ['platform:isRootedDevice'],
            )
          : RiskCheckResult.clean;
    } on PlatformException catch (e) {
      debugPrint("Failed to run rootCheck: '${e.message}'.");
      result = RiskCheckResult.clean;
    }

    // Merge in the native stat()/access() check, which is harder to hook than the JVM one.
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final level = DeviceSafetyFfi.rootFilesLevel();
        if (level == 2) {
          result = result.withSignal('native:root_files', RiskLevel.high);
        } else if (level == 1) {
          result = result.withSignal('native:su_not_executable', RiskLevel.low);
        }
      }
    } catch (_) {}
    return result;
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

  static int rootFilesLevel() => DeviceSafetyFfi.rootFilesLevel();
}
