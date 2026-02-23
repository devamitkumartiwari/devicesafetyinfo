package com.devamitkumartiwari.device_safety_info

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.view.Display
import com.devamitkumartiwari.device_safety_info.developmentmode.DevelopmentModeCheck
import com.devamitkumartiwari.device_safety_info.externalstorage.ExternalStorageCheck
import com.devamitkumartiwari.device_safety_info.hooks.HookDetector
import com.devamitkumartiwari.device_safety_info.realdevice.RealDeviceCheck
import com.devamitkumartiwari.device_safety_info.rooted.RootedDeviceCheck
import com.devamitkumartiwari.device_safety_info.screencapturedetector.ScreenCaptureDetector
import com.devamitkumartiwari.device_safety_info.screenlock.ScreenLockCheck
import com.devamitkumartiwari.device_safety_info.screenshot.RecentsMenuManager
import com.devamitkumartiwari.device_safety_info.screenshot.ScreenShotManager
import com.devamitkumartiwari.device_safety_info.storeinstallcheck.StoreInstallCheck
import com.devamitkumartiwari.device_safety_info.vpn_check.VpnCheck
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.BufferedReader
import java.io.DataOutputStream
import java.io.InputStreamReader
import java.util.concurrent.Executor
import kotlin.system.exitProcess

class DeviceSafetyInfoPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private var displayManager: DisplayManager? = null
    private var displayListener: DisplayManager.DisplayListener? = null
    private var screenCaptureCallback: Activity.ScreenCaptureCallback? = null
    private var mediaProjection: MediaProjection? = null
    private var mediaProjectionCallback: MediaProjection.Callback? = null


    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "device_safety_info")
        channel.setMethodCallHandler(this)

        val eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "device_safety_info/screen_capture_events")
        eventChannel.setStreamHandler(this)

        displayManager = context?.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            screenCaptureCallback = Activity.ScreenCaptureCallback {
                updateScreenCaptureState(true)
            }
            activity?.registerScreenCaptureCallback(context?.mainExecutor as Executor, screenCaptureCallback!!)
        }
    }

    override fun onDetachedFromActivity() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && screenCaptureCallback != null) {
            activity?.unregisterScreenCaptureCallback(screenCaptureCallback!!)
        }
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val exitIfTrue = call.argument<Boolean>("exitProcessIfTrue") ?: false
        val uninstallIfTrue = call.argument<Boolean>("uninstallIfTrue") ?: false

        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "isRealDevice" -> result.success(RealDeviceCheck.isRealDevice())
            "isExternalStorage" -> result.success(context?.let { ExternalStorageCheck.isExternalStorage(it) })
            "isDeveloperMode" -> result.success(context?.let { DevelopmentModeCheck.isDevMode(it) })
            "isScreenLock" -> result.success(context?.let { ScreenLockCheck.isDeviceScreenLocked(it) })
            "isVPNCheck" -> result.success(context?.let { VpnCheck.isActiveVPN(it) })
            "isInstalledFromStore" -> result.success(context?.let { StoreInstallCheck.isInstalledFromStore(it) })
            "isScreenCaptured" -> {
                val mediaProjectionManager = context?.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                mediaProjection = mediaProjectionManager.getMediaProjection(Activity.RESULT_OK, Intent())
                result.success(context?.let { ScreenCaptureDetector(it).isScreenBeingCaptured(mediaProjection) })
            }
            "isRootedDevice" -> {
                val isRooted = RootedDeviceCheck.isRootedDevice()
                handleExitOrUninstall(isRooted, exitIfTrue, uninstallIfTrue)
                result.success(isRooted)
            }
            "isHooked" -> {
                val isHooked = HookDetector.check()
                handleExitOrUninstall(isHooked, exitIfTrue, uninstallIfTrue)
                result.success(isHooked)
            }
            "blockScreenShots" -> {
                val block = call.argument<Boolean>("block") ?: false
                activity?.let { ScreenShotManager.setScreenshotBlock(it, block) }
                result.success(null)
            }
            "hideMenu" -> {
                val hide = call.argument<Boolean>("hide") ?: false
                activity?.let { RecentsMenuManager.setRecentsMenuHidden(it, hide) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleExitOrUninstall(shouldHandle: Boolean, exitProcessIfTrue: Boolean, uninstallIfTrue: Boolean) {
        if (shouldHandle) {
            if (uninstallIfTrue) {
                uninstallApp()
            } else if (exitProcessIfTrue) {
                activity?.finishAffinity()
                exitProcess(0)
            }
        }
    }

    private fun uninstallApp() {
        try {
            val packageName = context?.packageName ?: return
            val process = Runtime.getRuntime().exec("su")
            DataOutputStream(process.outputStream).use { os ->
                os.writeBytes("pm uninstall $packageName\n")
                os.flush()
            }

            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val result = reader.readText()
            reader.close()

            if (!result.contains("Success", ignoreCase = true)) {
                val intent = Intent(Intent.ACTION_DELETE).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context?.startActivity(intent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        mediaProjection?.stop()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        if (displayListener == null) {
            displayListener = object : DisplayManager.DisplayListener {
                override fun onDisplayAdded(displayId: Int) {
                    updateScreenCaptureState()
                }

                override fun onDisplayRemoved(displayId: Int) {
                    updateScreenCaptureState()
                }

                override fun onDisplayChanged(displayId: Int) {
                    // Not used
                }
            }
            displayManager?.registerDisplayListener(displayListener, null)
            updateScreenCaptureState()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            mediaProjectionCallback = object : MediaProjection.Callback() {
                override fun onStop() {
                    updateScreenCaptureState(false)
                }
            }
            mediaProjection?.registerCallback(mediaProjectionCallback!!, null)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        if (displayListener != null) {
            displayManager?.unregisterDisplayListener(displayListener)
            displayListener = null
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && mediaProjectionCallback != null) {
            mediaProjection?.unregisterCallback(mediaProjectionCallback!!)
            mediaProjectionCallback = null
        }
    }

    private fun updateScreenCaptureState(isCaptured: Boolean? = null) {
        val finalCapturedState = isCaptured ?: (context?.let { ScreenCaptureDetector(it).isScreenBeingCaptured(mediaProjection) } ?: false)
        eventSink?.success(finalCapturedState)
    }
}
