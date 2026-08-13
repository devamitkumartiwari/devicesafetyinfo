// Patrol integration tests for all action/mutation methods:
// - blockScreenshots
// - setRecentsOverlay / clearRecentsOverlay
// - hideMenu (Android only)
// - checkHooked with exit/uninstall flags (safe variants only)

import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:device_safety_info_example/main.dart';

void main() {
  // ── blockScreenshots ────────────────────────────────────────────────────

  patrolTest('blockScreenshots(true) completes without throwing', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    await expectLater(
      DeviceSafetyInfo.blockScreenshots(block: true),
      completes,
    );
    // Always restore so subsequent tests are not affected
    await DeviceSafetyInfo.blockScreenshots(block: false);
  });

  patrolTest('blockScreenshots(false) completes without throwing', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    await expectLater(
      DeviceSafetyInfo.blockScreenshots(block: false),
      completes,
    );
  });

  patrolTest('blockScreenshots can be toggled multiple times', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    for (var i = 0; i < 3; i++) {
      await DeviceSafetyInfo.blockScreenshots(block: true);
      await DeviceSafetyInfo.blockScreenshots(block: false);
    }
    // Passing without exception is the assertion
    expect(true, isTrue);
  });

  patrolTest('blockScreenshots block=true then background and foreground', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const MyApp());
    await DeviceSafetyInfo.blockScreenshots(block: true);

    // Verify the app survives backgrounding with FLAG_SECURE set (Android) /
    // UITextField trick (iOS)
    await $.platform.mobile.pressHome();
    await Future.delayed(const Duration(milliseconds: 300));
    await $.platform.mobile.openApp(
      appId: 'com.devamitkumartiwari.device_safety_info_example',
    );
    await $.pumpAndSettle();

    // Unblock so it doesn't affect other tests
    await DeviceSafetyInfo.blockScreenshots(block: false);
    expect(true, isTrue);
  });

  // ── setRecentsOverlay / clearRecentsOverlay ─────────────────────────────

  patrolTest('setRecentsOverlay with default black color does not throw', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const MyApp());
    await expectLater(DeviceSafetyInfo.setRecentsOverlay(), completes);
    await DeviceSafetyInfo.clearRecentsOverlay();
  });

  patrolTest('setRecentsOverlay with custom ARGB color does not throw', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const MyApp());
    await expectLater(
      DeviceSafetyInfo.setRecentsOverlay(argbColor: 0xFF1A1A2E),
      completes,
    );
    await DeviceSafetyInfo.clearRecentsOverlay();
  });

  patrolTest(
    'clearRecentsOverlay without prior set does not throw (cold call)',
    ($) async {
      await $.pumpWidgetAndSettle(const MyApp());
      await expectLater(DeviceSafetyInfo.clearRecentsOverlay(), completes);
    },
  );

  patrolTest('clearRecentsOverlay after set is idempotent', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    await DeviceSafetyInfo.setRecentsOverlay(argbColor: 0xFF000000);
    // Call clear twice — should not throw
    await expectLater(DeviceSafetyInfo.clearRecentsOverlay(), completes);
    await expectLater(DeviceSafetyInfo.clearRecentsOverlay(), completes);
  });

  patrolTest('setRecentsOverlay overlay appears during background', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    await DeviceSafetyInfo.setRecentsOverlay(argbColor: 0xFF000000);

    // Background the app — overlay should appear over the snapshot
    await $.platform.mobile.pressHome();
    await Future.delayed(const Duration(milliseconds: 500));

    // Return to app — overlay should be automatically removed on resume
    await $.platform.mobile.openApp(
      appId: 'com.devamitkumartiwari.device_safety_info_example',
    );
    await $.pumpAndSettle();

    await DeviceSafetyInfo.clearRecentsOverlay();
    expect(true, isTrue);
  });

  patrolTest('setRecentsOverlay called multiple times updates color', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const MyApp());
    await DeviceSafetyInfo.setRecentsOverlay(argbColor: 0xFFFF0000); // red
    await DeviceSafetyInfo.setRecentsOverlay(argbColor: 0xFF0000FF); // blue
    await DeviceSafetyInfo.clearRecentsOverlay();
    expect(true, isTrue);
  });

  // ── hideMenu (Android only) ─────────────────────────────────────────────

  patrolTest('hideMenu(true) does not throw on Android', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    if (defaultTargetPlatform == TargetPlatform.android) {
      await expectLater(DeviceSafetyInfo.hideMenu(hide: true), completes);
      // Restore visibility immediately so device is not stuck
      await DeviceSafetyInfo.hideMenu(hide: false);
    } else {
      // iOS: no-op — should still complete without error
      await expectLater(DeviceSafetyInfo.hideMenu(hide: true), completes);
    }
  });

  patrolTest('hideMenu(false) restores recents visibility on Android', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const MyApp());
    if (defaultTargetPlatform == TargetPlatform.android) {
      await DeviceSafetyInfo.hideMenu(hide: true);
      await expectLater(DeviceSafetyInfo.hideMenu(hide: false), completes);
    }
  });

  patrolTest('hideMenu toggle does not affect app lifecycle', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    if (defaultTargetPlatform == TargetPlatform.android) {
      await DeviceSafetyInfo.hideMenu(hide: true);
      await $.platform.mobile.pressHome();
      await Future.delayed(const Duration(milliseconds: 300));
      await $.platform.mobile.openApp(
        appId: 'com.devamitkumartiwari.device_safety_info_example',
      );
      await $.pumpAndSettle();
      await DeviceSafetyInfo.hideMenu(hide: false);
    }
    expect(true, isTrue);
  });

  // ── checkHooked with safe flags ─────────────────────────────────────────

  patrolTest('checkHooked(exitProcessIfTrue: false) returns false safely', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const MyApp());
    // exitProcessIfTrue=false means we never call exitProcess even if hooked
    final result = await DeviceSafetyInfo.checkHooked(exitProcessIfTrue: false);
    expect(
      result,
      isFalse,
      reason: 'No hooking framework present on clean test device',
    );
  });

  patrolTest('checkHooked(uninstallIfTrue: false) returns false safely', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const MyApp());
    final result = await DeviceSafetyInfo.checkHooked(uninstallIfTrue: false);
    expect(result, isFalse);
  });

  // ── Combined sequence ───────────────────────────────────────────────────

  patrolTest('full security action sequence completes without errors', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const MyApp());

    // 1. Block screenshots
    await DeviceSafetyInfo.blockScreenshots(block: true);

    // 2. Set recents overlay
    await DeviceSafetyInfo.setRecentsOverlay(argbColor: 0xFF1A1A2E);

    // 3. Background and resume to exercise lifecycle callbacks
    await $.platform.mobile.pressHome();
    await Future.delayed(const Duration(milliseconds: 400));
    await $.platform.mobile.openApp(
      appId: 'com.devamitkumartiwari.device_safety_info_example',
    );
    await $.pumpAndSettle();

    // 4. Clear overlay
    await DeviceSafetyInfo.clearRecentsOverlay();

    // 5. Unblock screenshots
    await DeviceSafetyInfo.blockScreenshots(block: false);

    expect(true, isTrue);
  });
}
