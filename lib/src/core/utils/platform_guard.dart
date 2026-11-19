import 'package:flutter/foundation.dart';

import '../result/device_safety_exception.dart';

/// Platform checks based on [defaultTargetPlatform], so tests can override the platform with
/// `debugDefaultTargetPlatformOverride`. Web is never a supported platform.
abstract final class PlatformGuard {
  /// Running on Android.
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Running on iOS.
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Running on Android or iOS.
  static bool get isSupported => isAndroid || isIOS;

  /// Throws [UnsupportedPlatformException] unless on Android.
  static void requireAndroid(String operation) {
    if (!isAndroid) {
      throw UnsupportedPlatformException(operation, 'Android only');
    }
  }

  /// Throws [UnsupportedPlatformException] unless on iOS.
  static void requireIOS(String operation) {
    if (!isIOS) throw UnsupportedPlatformException(operation, 'iOS only');
  }

  /// Throws [UnsupportedPlatformException] unless on Android or iOS.
  static void requireMobile(String operation) {
    if (!isSupported) {
      throw UnsupportedPlatformException(operation, 'Android and iOS only');
    }
  }
}
