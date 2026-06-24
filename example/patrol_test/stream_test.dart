// Patrol integration tests for all stream-based APIs:
// - DeviceSafetyInfo.onScreenCapturedChanged (EventChannel)
// - DeviceSafetyInfo.onScreenshotTaken (EventChannel)
// - VPNCheck.vpnState (connectivity_plus backed stream)

import 'dart:async';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

// Stream tests must NOT pump MyApp — MyApp.initState subscribes to every stream
// and the singleton VPNCheck emits its initial state exactly once.  By the time
// the test body subscribes, the event has already been delivered to MyApp's
// listener and the broadcast stream won't replay it.
Widget _minimalApp() =>
    const MaterialApp(home: Scaffold(body: SizedBox.shrink()));

void main() {
  // ── Screen capture stream ───────────────────────────────────────────────

  patrolTest('onScreenCapturedChanged emits initial bool event within 5s', ($) async {
    await $.pumpWidgetAndSettle(_minimalApp());

    final completer = Completer<bool>();
    final sub = DeviceSafetyInfo.onScreenCapturedChanged.listen(
      (value) {
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    final value = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException(
        'onScreenCapturedChanged did not emit within 5 seconds',
      ),
    );

    expect(value, isA<bool>());
    expect(value, isFalse,
        reason: 'No external display connected during test');
    await sub.cancel();
  });

  patrolTest('onScreenCapturedChanged supports multiple concurrent listeners', ($) async {
    await $.pumpWidgetAndSettle(_minimalApp());

    final c1 = Completer<bool>();
    final c2 = Completer<bool>();

    final sub1 = DeviceSafetyInfo.onScreenCapturedChanged.listen(
      (v) { if (!c1.isCompleted) c1.complete(v); },
    );
    final sub2 = DeviceSafetyInfo.onScreenCapturedChanged.listen(
      (v) { if (!c2.isCompleted) c2.complete(v); },
    );

    final results = await Future.wait([
      c1.future.timeout(const Duration(seconds: 5)),
      c2.future.timeout(const Duration(seconds: 5)),
    ]);

    expect(results[0], isA<bool>());
    expect(results[1], isA<bool>());
    expect(results[0], equals(results[1]),
        reason: 'Both listeners should see the same capture state');

    await sub1.cancel();
    await sub2.cancel();
  });

  patrolTest('onScreenCapturedChanged can subscribe and cancel repeatedly', ($) async {
    await $.pumpWidgetAndSettle(_minimalApp());

    for (var i = 0; i < 3; i++) {
      final c = Completer<bool>();
      final sub = DeviceSafetyInfo.onScreenCapturedChanged.listen(
        (v) { if (!c.isCompleted) c.complete(v); },
      );
      await c.future.timeout(const Duration(seconds: 5));
      await sub.cancel();
    }
    // Reaching here means no crash after repeated subscribe/cancel cycles
    expect(true, isTrue);
  });

  // ── Screenshot detection stream ─────────────────────────────────────────

  patrolTest('onScreenshotTaken can subscribe without throwing', ($) async {
    await $.pumpWidgetAndSettle(_minimalApp());

    // On Android API 24-33 the first listen will trigger a READ_MEDIA_IMAGES
    // permission request — Patrol grants it automatically via $.platform.
    // On API 34+ and iOS no permission is needed.
    StreamSubscription<void>? sub;
    await expectLater(
      Future(() async {
        sub = DeviceSafetyInfo.onScreenshotTaken.listen((_) {});
      }),
      completes,
    );
    await sub?.cancel();
  });

  patrolTest('onScreenshotTaken cancel does not throw', ($) async {
    await $.pumpWidgetAndSettle(_minimalApp());
    final sub = DeviceSafetyInfo.onScreenshotTaken.listen((_) {});
    await expectLater(sub.cancel(), completes);
  });

  // ── VPN stream ──────────────────────────────────────────────────────────

  patrolTest('VPNCheck.vpnState emits initial state within 5s', ($) async {
    await $.pumpWidgetAndSettle(_minimalApp());

    final vpn = VPNCheck();
    final completer = Completer<VPNState>();

    final sub = vpn.vpnState.listen(
      (state) {
        if (!completer.isCompleted) completer.complete(state);
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    final state = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException(
        'VPNCheck.vpnState did not emit within 5 seconds',
      ),
    );

    expect(state, isA<VPNState>());
    // No VPN connected on test device
    expect(state, equals(VPNState.disconnectedState));

    await sub.cancel();
    vpn.dispose();
  });

  patrolTest('VPNCheck.vpnState emits VPNState enum values only', ($) async {
    await $.pumpWidgetAndSettle(_minimalApp());

    final vpn = VPNCheck();
    final states = <VPNState>[];
    final completer = Completer<void>();

    final sub = vpn.vpnState.listen((state) {
      states.add(state);
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future.timeout(const Duration(seconds: 5));

    expect(states, isNotEmpty);
    for (final s in states) {
      expect(
        s,
        anyOf(VPNState.connectedState, VPNState.disconnectedState),
        reason: 'VPNState must be one of the two enum values',
      );
    }

    await sub.cancel();
    vpn.dispose();
  });

  patrolTest('VPNCheck.dispose can be called multiple times safely', ($) async {
    await $.pumpWidgetAndSettle(_minimalApp());
    final vpn = VPNCheck();

    // Subscribe briefly so the stream is active, then dispose
    final sub = vpn.vpnState.listen((_) {});
    await Future.delayed(const Duration(milliseconds: 100));
    await sub.cancel();

    expect(() => vpn.dispose(), returnsNormally);
    expect(() => vpn.dispose(), returnsNormally,
        reason: 'dispose() should be idempotent');
  });

  patrolTest('Multiple VPNCheck instances can coexist', ($) async {
    await $.pumpWidgetAndSettle(_minimalApp());

    final vpn1 = VPNCheck();
    final vpn2 = VPNCheck();

    final c1 = Completer<VPNState>();
    final c2 = Completer<VPNState>();

    final s1 = vpn1.vpnState.listen((v) { if (!c1.isCompleted) c1.complete(v); });
    final s2 = vpn2.vpnState.listen((v) { if (!c2.isCompleted) c2.complete(v); });

    final results = await Future.wait([
      c1.future.timeout(const Duration(seconds: 5)),
      c2.future.timeout(const Duration(seconds: 5)),
    ]);

    expect(results[0], equals(results[1]),
        reason: 'Both instances should report the same VPN state');

    await s1.cancel();
    await s2.cancel();
    vpn1.dispose();
    vpn2.dispose();
  });
}
