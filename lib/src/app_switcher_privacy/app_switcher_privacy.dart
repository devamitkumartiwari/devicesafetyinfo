import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/device_safety_channels.dart';

/// Hiding app content from the recent-apps switcher. Internal implementation detail — reached only
/// through DeviceSafetyInfo's forwarding members, which carry the full docs.
class AppSwitcherPrivacy {
  AppSwitcherPrivacy._();

  static Future<void> setRecentsOverlay({int argbColor = 0xFF000000}) async {
    try {
      await DeviceSafetyChannels.method.invokeMethod('setRecentsOverlay', {
        'color': argbColor,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to set recents overlay: '${e.message}'");
    }
  }

  static Future<void> clearRecentsOverlay() async {
    try {
      await DeviceSafetyChannels.method.invokeMethod('clearRecentsOverlay');
    } on PlatformException catch (e) {
      debugPrint("Failed to clear recents overlay: '${e.message}'");
    }
  }

  static Future<void> hideMenu({bool hide = true}) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await DeviceSafetyChannels.method.invokeMethod('hideMenu', {
          'hide': hide,
        });
      } on PlatformException catch (e) {
        debugPrint("Failed to set app recents visibility: '${e.message}'");
      }
    }
  }
}
