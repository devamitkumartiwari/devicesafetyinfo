import 'dart:async';

import '../core/device_safety_channels.dart';

/// Screen-capture/recording/mirroring detection. Internal implementation detail — reached only
/// through DeviceSafetyInfo's forwarding members, which carry the full docs.
class ScreenCaptureDetector {
  ScreenCaptureDetector._();

  static Stream<bool>? _onScreenCapturedChanged;

  static Future<bool> get isScreenCaptured async {
    final bool? isScreenCaptured = await DeviceSafetyChannels.method
        .invokeMethod<bool>('isScreenCaptured');
    return isScreenCaptured ?? false;
  }

  static Stream<bool> get onScreenCapturedChanged {
    _onScreenCapturedChanged ??= DeviceSafetyChannels.screenCapture
        .receiveBroadcastStream()
        .map<bool>((event) => event as bool);
    return _onScreenCapturedChanged!;
  }
}
