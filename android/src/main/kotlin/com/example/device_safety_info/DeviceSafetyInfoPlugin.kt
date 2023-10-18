package com.example.device_safety_info

import android.content.Context
import com.example.device_safety_info.developmentmode.DevelopmentModeCheck
import com.example.device_safety_info.externalstorage.ExternalStorageCheck
import com.example.device_safety_info.realdevice.RealDeviceCheck
import com.example.device_safety_info.rooted.RootedDeviceCheck
import com.example.device_safety_info.screenlock.ScreenLockCheck
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result


/** DeviceSafetyInfoPlugin */
class DeviceSafetyInfoPlugin: FlutterPlugin, MethodCallHandler {

  private lateinit var channel : MethodChannel
  private var context: Context? = null


  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.getApplicationContext()
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "device_safety_info")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else if (call.method.equals("isRootedDevice")) {
      result.success(context?.let { RootedDeviceCheck.isRootedDevice(it) })
    } else if (call.method.equals("isRealDevice")) {
      result.success(!RealDeviceCheck.isRealDevice())
    } else if (call.method.equals("isExternalStorage")) {
      result.success(context?.let { ExternalStorageCheck.isExternalStorage(it) })
    } else if (call.method.equals("isDeveloperMode")) {
      result.success(context?.let { DevelopmentModeCheck.isDevMode(it) })
    }  else if (call.method.equals("isScreenLock")) {
      result.success(context?.let { ScreenLockCheck.isDeviceScreenLocked(it) })
    }else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

}
