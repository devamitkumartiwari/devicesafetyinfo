// Patrol tests for the action APIs against the real platform.
import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info_example/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('block and unblock screenshots from the Protection page', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const DemoApp());
    await $(#menu_Protection).tap();
    await $.pumpAndSettle();
    await $(#block_screenshots).tap();
    await $.pumpAndSettle();
    expect(await DeviceSafety.screen.isScreenshotBlocked(), isTrue);
    await $(#block_screenshots).tap();
    await $.pumpAndSettle();
    expect(await DeviceSafety.screen.isScreenshotBlocked(), isFalse);
  });

  patrolTest('capture overlay can be set and cleared', ($) async {
    await $.pumpWidgetAndSettle(const DemoApp());
    await DeviceSafety.screen.setOverlayMode(
      ScreenshotOverlayMode.color,
      argbColor: 0xFF000000,
    );
    await DeviceSafety.screen.clearOverlayMode();
  });

  patrolTest('SecureScreen blocks while mounted', ($) async {
    await $.pumpWidgetAndSettle(const SecureScreen(child: DemoApp()));
    expect(await DeviceSafety.screen.isScreenshotBlocked(), isTrue);
    await $.pumpWidgetAndSettle(const DemoApp());
    await $.pump(const Duration(milliseconds: 200));
    expect(await DeviceSafety.screen.isScreenshotBlocked(), isFalse);
  });

  patrolTest('secure copy shows a confirmation', ($) async {
    await $.pumpWidgetAndSettle(const DemoApp());
    await $(#menu_Protection).tap();
    await $.pumpAndSettle();
    await $(#copy_secure).scrollTo().tap();
    await $.pumpAndSettle();
    expect($(#protection_message), findsOneWidget);
    await DeviceSafety.clipboard.clear();
  });

  patrolTest('app switcher overlay and tapjacking protection', ($) async {
    await $.pumpWidgetAndSettle(const DemoApp());
    await DeviceSafety.appSwitcher.setOverlay();
    await DeviceSafety.appSwitcher.clearOverlay();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await DeviceSafety.overlayAttack.blockTouchesWhenObscured();
      await DeviceSafety.overlayAttack.blockTouchesWhenObscured(block: false);
      await DeviceSafety.appSwitcher.hideFromRecents(hide: false);
    } else {
      await expectLater(
        DeviceSafety.appSwitcher.hideFromRecents(),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    }
  });

  patrolTest('IOC host check from the Tools page', ($) async {
    await $.pumpWidgetAndSettle(const DemoApp());
    await $(#menu_Tools).tap();
    await $.pumpAndSettle();
    await $(#ioc_check).tap();
    await $.pumpAndSettle();
    expect($(#ioc_result).text, 'BLOCKED');
  });
}
