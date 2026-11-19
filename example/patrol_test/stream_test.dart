// Patrol tests for the live event streams.
import 'dart:async';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('capture stream sends the current state first', ($) async {
    await $.pumpWidgetAndSettle(const DemoApp());
    final first = await DeviceSafety.screen.captureChanges.first.timeout(
      const Duration(seconds: 5),
    );
    expect(first, isFalse);
  });

  patrolTest('streams can be listened to and cancelled', ($) async {
    await $.pumpWidgetAndSettle(const DemoApp());
    void ignore(Object _) {}
    final subs = <StreamSubscription<Object?>>[
      DeviceSafety.screen.onScreenshot.listen(null, onError: ignore),
      DeviceSafety.screen.recordingChanges.listen(null, onError: ignore),
      DeviceSafety.vpn.changes.listen(null, onError: ignore),
      DeviceSafety.clipboard.changes.listen(null, onError: ignore),
      DeviceSafety.calls.changes.listen(null, onError: ignore),
      DeviceSafety.overlayAttack.obscuredTouches.listen(null, onError: ignore),
      DeviceSafety.threats.listen(null),
    ];
    await $.pump(const Duration(seconds: 1));
    for (final s in subs) {
      await s.cancel();
    }
  });

  patrolTest('clipboard change reaches the stream', ($) async {
    await $.pumpWidgetAndSettle(const DemoApp());
    final changed = DeviceSafety.clipboard.changes.first.timeout(
      const Duration(seconds: 5),
    );
    await DeviceSafety.clipboard.copySecure('stream-test', clearAfter: null);
    expect(await changed, isA<DateTime>());
    await DeviceSafety.clipboard.clear();
  });

  patrolTest('the Live events page renders', ($) async {
    await $.pumpWidgetAndSettle(const DemoApp());
    await $(#menu_Live_events).tap();
    await $.pumpAndSettle();
    expect($('Screen captured'), findsOneWidget);
  });
}
