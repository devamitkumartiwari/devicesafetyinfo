import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/device_safety_channels.dart';

/// The state of Google Play Protect, read from the OS setting its toggle controls. There is no
/// public "Play Protect API" — SafetyNet's Verify Apps API, which used to expose this, was fully
/// retired in January 2025. Android only; always [unknown] on iOS.
enum PlayProtectStatus { enabled, disabled, unknown }

/// The small, mostly one-shot device/environment checks that don't warrant their own feature
/// module (real-device, screen-lock, store-install, developer-mode, Play Protect, accessibility/
/// notification-listener abuse surfaces, sideloading rights, call-screening role). Internal
/// implementation detail — reached only through DeviceSafetyInfo's forwarding members, which carry
/// the full docs.
class DeviceChecks {
  DeviceChecks._();

  static Future<bool> get isExternalStorage async {
    if (!kIsWeb && Platform.isAndroid) {
      final bool? isExternalStorage = await DeviceSafetyChannels.method
          .invokeMethod<bool>('isExternalStorage');
      return isExternalStorage ?? false;
    }
    return false;
  }

  static Future<bool> get isRealDevice async {
    final bool? isRealDevice = await DeviceSafetyChannels.method
        .invokeMethod<bool>('isRealDevice');
    return isRealDevice ?? false;
  }

  static Future<bool> get isDeveloperMode async {
    if (!kIsWeb && Platform.isAndroid) {
      bool? isDeveloperMode = await DeviceSafetyChannels.method
          .invokeMethod<bool>('isDeveloperMode');
      return isDeveloperMode ?? false;
    }
    return false;
  }

  static Future<bool> get isScreenLock async {
    final bool? isScreenLock = await DeviceSafetyChannels.method
        .invokeMethod<bool>('isScreenLock');
    return isScreenLock ?? false;
  }

  static Future<bool> get isInstalledFromStore async {
    final bool? isInstalledFromStore = await DeviceSafetyChannels.method
        .invokeMethod<bool>('isInstalledFromStore');
    return isInstalledFromStore ?? false;
  }

  static Future<PlayProtectStatus> get playProtectStatus async {
    if (!kIsWeb && Platform.isAndroid) {
      final raw = await DeviceSafetyChannels.method.invokeMethod<int>(
        'getPlayProtectStatus',
      );
      switch (raw) {
        case 1:
          return PlayProtectStatus.enabled;
        case -1:
          return PlayProtectStatus.disabled;
        default:
          return PlayProtectStatus.unknown;
      }
    }
    return PlayProtectStatus.unknown;
  }

  static Future<List<String>> get enabledAccessibilityServices async {
    if (!kIsWeb && Platform.isAndroid) {
      final result = await DeviceSafetyChannels.method
          .invokeMethod<List<Object?>>('getEnabledAccessibilityServices');
      return result?.cast<String>() ?? const [];
    }
    return const [];
  }

  static Future<bool> get isAnyAccessibilityServiceEnabled async =>
      (await enabledAccessibilityServices).isNotEmpty;

  static Future<List<String>> get enabledNotificationListeners async {
    if (!kIsWeb && Platform.isAndroid) {
      final result = await DeviceSafetyChannels.method
          .invokeMethod<List<Object?>>('getEnabledNotificationListeners');
      return result?.cast<String>() ?? const [];
    }
    return const [];
  }

  static Future<bool> get isAnyNotificationListenerEnabled async =>
      (await enabledNotificationListeners).isNotEmpty;

  static Future<bool> get isUnknownSourcesEnabled async {
    if (!kIsWeb && Platform.isAndroid) {
      final result = await DeviceSafetyChannels.method.invokeMethod<bool>(
        'isUnknownSourcesEnabled',
      );
      return result ?? false;
    }
    return false;
  }

  static Future<bool> get isCallScreeningRoleAvailable async {
    if (!kIsWeb && Platform.isAndroid) {
      final result = await DeviceSafetyChannels.method.invokeMethod<bool>(
        'isCallScreeningRoleAvailable',
      );
      return result ?? false;
    }
    return false;
  }

  static Future<bool> get isCallScreeningRoleHeldByThisApp async {
    if (!kIsWeb && Platform.isAndroid) {
      final result = await DeviceSafetyChannels.method.invokeMethod<bool>(
        'isCallScreeningRoleHeldByThisApp',
      );
      return result ?? false;
    }
    return false;
  }

  static Future<void> openCallScreeningRoleSettings() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await DeviceSafetyChannels.method.invokeMethod(
          'openCallScreeningRoleSettings',
        );
      } on PlatformException catch (e) {
        debugPrint(
          "Failed to open call screening role settings: '${e.message}'",
        );
      }
    }
  }
}
