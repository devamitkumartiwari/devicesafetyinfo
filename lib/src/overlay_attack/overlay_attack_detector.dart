import 'dart:async';

import '../core/device_safety_channels.dart';

/// Tapjacking / overlay-phishing detection and protection. Internal implementation detail —
/// reached only through DeviceSafetyInfo's forwarding members, which carry the full docs.
class OverlayAttackDetector {
  OverlayAttackDetector._();

  static Stream<void>? _onOverlayAttackDetected;

  static Stream<void> get onOverlayAttackDetected {
    _onOverlayAttackDetected ??= DeviceSafetyChannels.overlay
        .receiveBroadcastStream()
        .map<void>((_) {});
    return _onOverlayAttackDetected!;
  }

  static Future<void> blockTouchesWhenObscured({bool block = true}) async {
    await DeviceSafetyChannels.method.invokeMethod('blockTouchesWhenObscured', {
      'block': block,
    });
  }
}
