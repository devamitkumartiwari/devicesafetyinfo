import 'package:device_safety_info/device_safety_info.dart';

/// A thin convenience wrapper around [DeviceSafetyInfo.isScreenCaptured].
class ScreenCapture {
  ScreenCapture._();

  /// Returns true if the screen is currently being captured, recorded, or mirrored.
  static Future<bool> isScreenCaptured() => DeviceSafetyInfo.isScreenCaptured;
}
