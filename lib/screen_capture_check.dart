import 'package:device_safety_info/device_safety_info.dart';

class ScreenCapture {
  static Future<bool> isScreenCaptured() => DeviceSafetyInfo.isScreenCaptured;
}
