import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/device_safety_channels.dart';

/// Clipboard actions and change monitoring. Internal implementation detail — reached only through
/// DeviceSafetyInfo's forwarding members, which carry the full docs.
class ClipboardProtection {
  ClipboardProtection._();

  static Stream<void>? _onClipboardChanged;

  static Future<void> copyToClipboard(
    String text, {
    bool sensitive = true,
    Duration? autoClear,
  }) async {
    try {
      await DeviceSafetyChannels.method.invokeMethod('copyToClipboard', {
        'text': text,
        'sensitive': sensitive,
        'autoClearMillis': autoClear?.inMilliseconds,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to copy to clipboard: '${e.message}'");
    }
  }

  static Future<void> clearClipboard() async {
    try {
      await DeviceSafetyChannels.method.invokeMethod('clearClipboard');
    } on PlatformException catch (e) {
      debugPrint("Failed to clear clipboard: '${e.message}'");
    }
  }

  static Stream<void> get onClipboardChanged {
    _onClipboardChanged ??= DeviceSafetyChannels.clipboard
        .receiveBroadcastStream()
        .map<void>((_) {});
    return _onClipboardChanged!;
  }
}
