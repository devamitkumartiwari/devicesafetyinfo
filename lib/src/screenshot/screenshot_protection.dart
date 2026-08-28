import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/device_safety_channels.dart';
import 'screenshot_overlay_mode.dart';

/// Screenshot blocking, detection, and overlay modes. Internal implementation detail — reached
/// only through DeviceSafetyInfo's forwarding members and the standalone overlay-mode/SecureScreen
/// additions, which carry the full docs.
class ScreenshotProtection {
  ScreenshotProtection._();

  static Stream<void>? _onScreenshotTaken;

  static Future<void> block({bool block = true}) async {
    try {
      await DeviceSafetyChannels.method.invokeMethod('blockScreenShots', {
        'block': block,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to set screenshot blocking: '${e.message}'");
    }
  }

  static Future<void> on() => block(block: true);

  static Future<void> off() => block(block: false);

  static Future<bool> get isBlocked async {
    try {
      final result = await DeviceSafetyChannels.method.invokeMethod<bool>(
        'isScreenshotBlocked',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> toggle() async {
    final blocked = await isBlocked;
    await block(block: !blocked);
  }

  static Stream<void> get onScreenshotTaken {
    _onScreenshotTaken ??= DeviceSafetyChannels.screenshot
        .receiveBroadcastStream()
        .map<void>((_) {});
    return _onScreenshotTaken!;
  }

  static Future<void> setOverlayMode({
    required ScreenshotOverlayMode mode,
    double blurRadius = 10,
    int? argbColor,
    Uint8List? imageBytes,
  }) async {
    try {
      await DeviceSafetyChannels.method.invokeMethod(
        'setScreenshotOverlayMode',
        {
          'mode': mode.name,
          'blurRadius': blurRadius,
          'argbColor': argbColor,
          'imageBytes': imageBytes,
        },
      );
    } on PlatformException catch (e) {
      debugPrint("Failed to set screenshot overlay mode: '${e.message}'");
    }
  }

  static Future<void> clearOverlayMode() async {
    try {
      await DeviceSafetyChannels.method.invokeMethod(
        'clearScreenshotOverlayMode',
      );
    } on PlatformException catch (e) {
      debugPrint("Failed to clear screenshot overlay mode: '${e.message}'");
    }
  }
}
