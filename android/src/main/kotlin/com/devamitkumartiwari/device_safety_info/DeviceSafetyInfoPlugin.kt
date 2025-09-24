package com.devamitkumartiwari.device_safety_info

import android.content.Context
import com.devamitkumartiwari.device_safety_info.developmentmode.DevelopmentModeCheck
import com.devamitkumartiwari.device_safety_info.externalstorage.ExternalStorageCheck
import com.devamitkumartiwari.device_safety_info.realdevice.RealDeviceCheck
import com.devamitkumartiwari.device_safety_info.rooted.RootedDeviceCheck
import com.devamitkumartiwari.device_safety_info.screenlock.ScreenLockCheck
import com.devamitkumartiwari.device_safety_info.storeinstallcheck.StoreInstallCheck
import com.devamitkumartiwari.device_safety_info.vpn_check.VpnCheck

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** DeviceSafetyInfoPlugin */
class DeviceSafetyInfoPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var context: Context? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "device_safety_info")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            "isRootedDevice" -> {
                result.success(context?.let { RootedDeviceCheck.isRootedDevice(it) })
            }


            "isRealDevice" -> {
                result.success(RealDeviceCheck.isRealDevice())
            }

            "isExternalStorage" -> {
                result.success(context?.let { ExternalStorageCheck.isExternalStorage(it) })
            }

            "isDeveloperMode" -> {
                result.success(context?.let { DevelopmentModeCheck.isDevMode(it) })
            }

            "isScreenLock" -> {
                result.success(context?.let { ScreenLockCheck.isDeviceScreenLocked(it) })
            }

            "isVPNCheck" -> {
                result.success(context?.let { VpnCheck.isActiveVPN(it) }) // Optimized here
            }

            "isInstalledFromStore" -> {
                result.success(context?.let { StoreInstallCheck.isInstalledFromStore(it) })
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
