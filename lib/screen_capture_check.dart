import 'package:device_safety_info/device_safety_info.dart';

class ScreenCapture {
  static Future<bool> isScreenCaptured() async {
    try {
      final bool result = await DeviceSafetyInfo.channel
          .invokeMethod('isScreenCaptured');
      return result;
    } catch (e) {
      return false;
    }
  }
}
