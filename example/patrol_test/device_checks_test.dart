// Patrol integration tests for all boolean-returning detection methods and
// the two synchronous FFI methods. These run against real native implementations
// on device/emulator — no mocked channels.
//
// Expected environment: non-rooted device or standard Android emulator,
// no Frida/Xposed attached, no VPN active, no external display connected.

import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:device_safety_info_example/main.dart';

void main() {
  // ── Synchronous FFI checks ──────────────────────────────────────────────

  group('FFI sync methods', () {
    test('checkFridaByMaps returns false on clean device', () {
      // Scans /proc/self/maps + port 27042/27043 (Android). Always false on iOS.
      expect(DeviceSafetyInfo.checkFridaByMaps(), isFalse);
    });

    test('checkRootFilesNative returns false on clean device', () {
      // Native stat() check for su/magisk paths (Android). Always false on iOS.
      expect(DeviceSafetyInfo.checkRootFilesNative(), isFalse);
    });
  });

  // ── Async detection checks ──────────────────────────────────────────────

  patrolTest('isRealDevice returns a bool', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    final result = await DeviceSafetyInfo.isRealDevice;
    // false on emulator, true on physical device — assert type only
    expect(result, isA<bool>());
  });

  patrolTest('isRootedDevice is false on standard device', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    final result = await DeviceSafetyInfo.isRootedDevice;
    expect(result, isA<bool>());
    expect(result, isFalse,
        reason: 'Should be false on a non-rooted device/emulator');
  });

  patrolTest('isHooked is false on standard device', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    final result = await DeviceSafetyInfo.isHooked;
    expect(result, isA<bool>());
    expect(result, isFalse,
        reason: 'Should be false when no hooking framework is attached');
  });

  patrolTest('checkHooked() with default params returns false', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    // Calls the same logic as isHooked but via explicit method
    final result = await DeviceSafetyInfo.checkHooked();
    expect(result, isA<bool>());
    expect(result, isFalse);
  });

  patrolTest('isDebuggerAttached returns a bool', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    // Will be true when Patrol runs with a debugger attached — type check only
    final result = await DeviceSafetyInfo.isDebuggerAttached;
    expect(result, isA<bool>());
  });

  patrolTest('isScreenCaptured is false with no external display', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    final result = await DeviceSafetyInfo.isScreenCaptured;
    expect(result, isA<bool>());
    expect(result, isFalse,
        reason: 'No external display should be connected during test');
  });

  patrolTest('isVPNCheck is false when no VPN is active', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    final result = await DeviceSafetyInfo.isVPNCheck;
    expect(result, isA<bool>());
    expect(result, isFalse,
        reason: 'No VPN should be active on the test device');
  });

  patrolTest('isInstalledFromStore is false for sideloaded test APK', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    final result = await DeviceSafetyInfo.isInstalledFromStore;
    expect(result, isA<bool>());
    expect(result, isFalse,
        reason: 'Test APKs are sideloaded, not installed from Play/App Store');
  });

  patrolTest('isScreenLock returns a bool', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    // Result depends on whether the test device has a screen lock configured
    final result = await DeviceSafetyInfo.isScreenLock;
    expect(result, isA<bool>());
  });

  patrolTest('isExternalStorage returns false on standard install (Android)', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    if (defaultTargetPlatform == TargetPlatform.android) {
      final result = await DeviceSafetyInfo.isExternalStorage;
      expect(result, isA<bool>());
      expect(result, isFalse,
          reason: 'Example app is installed on internal storage');
    } else {
      // iOS: always returns false (not applicable)
      final result = await DeviceSafetyInfo.isExternalStorage;
      expect(result, isFalse);
    }
  });

  patrolTest('isDeveloperMode returns a bool (Android)', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Returns true on physical devices with USB debugging, false on locked devices
      final result = await DeviceSafetyInfo.isDeveloperMode;
      expect(result, isA<bool>());
    } else {
      // iOS: always returns false (not accessible via public iOS API)
      final result = await DeviceSafetyInfo.isDeveloperMode;
      expect(result, isFalse);
    }
  });

  // ── ScreenCapture wrapper ───────────────────────────────────────────────

  patrolTest('ScreenCapture.isScreenCaptured() matches DeviceSafetyInfo.isScreenCaptured', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    final fromWrapper = await ScreenCapture.isScreenCaptured();
    final fromPlugin  = await DeviceSafetyInfo.isScreenCaptured;
    expect(fromWrapper, equals(fromPlugin),
        reason: 'ScreenCapture.isScreenCaptured() is a thin delegate');
    expect(fromWrapper, isFalse,
        reason: 'No external display connected during test');
  });

  // ── VPNCheck static helper ──────────────────────────────────────────────

  patrolTest('VPNCheck.isVpnActive matches DeviceSafetyInfo.isVPNCheck', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    final fromPlugin = await DeviceSafetyInfo.isVPNCheck;
    final fromVpnCheck = await VPNCheck.isVpnActive;
    expect(fromVpnCheck, equals(fromPlugin),
        reason: 'Both APIs read from the same platform channel');
  });

  // ── Parallel all-checks smoke test ──────────────────────────────────────

  patrolTest('all detection checks complete without throwing', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    // Runs all checks in parallel — verifies none throw a PlatformException
    await expectLater(
      Future.wait([
        DeviceSafetyInfo.isRealDevice,
        DeviceSafetyInfo.isRootedDevice,
        DeviceSafetyInfo.isHooked,
        DeviceSafetyInfo.isDebuggerAttached,
        DeviceSafetyInfo.isScreenCaptured,
        DeviceSafetyInfo.isVPNCheck,
        DeviceSafetyInfo.isInstalledFromStore,
        DeviceSafetyInfo.isScreenLock,
        DeviceSafetyInfo.isExternalStorage,
        DeviceSafetyInfo.isDeveloperMode,
      ]),
      completes,
    );
  });
}
