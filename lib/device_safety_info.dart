library device_safety_info;

import 'package:flutter/services.dart';
import 'dart:async';

class DeviceSafetyInfo {

  static const MethodChannel _channel = MethodChannel('device_safety_info');

  // only for android detect if application is running on external storage
  static Future<bool> get isExternalStorage async {
    final bool isExternalStorage =
    await _channel.invokeMethod('isExternalStorage');
    return isExternalStorage;
  }

  // check whether device is real or emulator/simulator
  static Future<bool> get isRealDevice async {
    final bool isRealDevice = await _channel.invokeMethod('isRealDevice');
    return isRealDevice;
  }

  //check whether device jailbroken or rooted on ios/android
  static Future<bool> get isRootedDevice async {
    final bool isRootedDevice = await _channel.invokeMethod('isRootedDevice');
    return isRootedDevice;
  }

  // check developer mode android only
  static Future<bool> get isDeveloperMode async {
    bool? isDeveloperMode = await _channel.invokeMethod<bool>('isDeveloperMode');
    return isDeveloperMode ?? true;
  }


  static Future<bool> get isScreenLock async {
    final bool isScreenLock = await _channel.invokeMethod('isScreenLock');
    return isScreenLock;
  }

}
