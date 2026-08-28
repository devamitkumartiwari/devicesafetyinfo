package com.devamitkumartiwari.device_safety_info

import android.app.Activity
import android.content.Context
import android.os.Build
import com.devamitkumartiwari.device_safety_info.appswitcherprivacy.AppSwitcherPrivacyFeature
import com.devamitkumartiwari.device_safety_info.callactivity.CallActivityFeature
import com.devamitkumartiwari.device_safety_info.clipboard.ClipboardFeature
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.deviceenvironment.DeviceEnvironmentFeature
import com.devamitkumartiwari.device_safety_info.malware.MalwareFeature
import com.devamitkumartiwari.device_safety_info.overlay.OverlayAttackFeature
import com.devamitkumartiwari.device_safety_info.rootdetection.RootDetectionFeature
import com.devamitkumartiwari.device_safety_info.screencapturedetector.ScreenCaptureFeature
import com.devamitkumartiwari.device_safety_info.screenrecording.ScreenRecordingFeature
import com.devamitkumartiwari.device_safety_info.screenshot.ScreenshotFeature
import com.devamitkumartiwari.device_safety_info.versioncheck.VersionCheckFeature
import com.devamitkumartiwari.device_safety_info.vpn_check.VpnFeature
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Plugin entry point. Owns only: channel/stream registration, the ActivityAware lifecycle, and a
 * flat method-name -> feature dispatch table built once in [onAttachedToEngine]. All actual
 * feature logic lives in the `*Feature.kt` classes under each vertical-slice package (see the
 * per-feature files for behavior); this class intentionally holds no feature-specific state.
 */
class DeviceSafetyInfoPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginHost {

    private lateinit var channel: MethodChannel

    override var context: Context? = null
        private set
    override var activity: Activity? = null
        private set

    private var methodHandlers: Map<String, FeatureMethodHandler> = emptyMap()
    private var disposables: List<Disposable> = emptyList()

    private lateinit var overlayAttackFeature: OverlayAttackFeature
    private lateinit var screenRecordingFeature: ScreenRecordingFeature

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "device_safety_info")
        channel.setMethodCallHandler(this)

        val rootDetectionFeature = RootDetectionFeature(this)
        val screenCaptureFeature = ScreenCaptureFeature(this)
        screenRecordingFeature = ScreenRecordingFeature(this)
        val screenshotFeature = ScreenshotFeature(this, screenCaptureFeature, screenRecordingFeature)
        val appSwitcherPrivacyFeature = AppSwitcherPrivacyFeature(this)
        overlayAttackFeature = OverlayAttackFeature(this)
        val clipboardFeature = ClipboardFeature(this)
        val callActivityFeature = CallActivityFeature(this)
        val vpnFeature = VpnFeature(this)
        val malwareFeature = MalwareFeature(this)
        val versionCheckFeature = VersionCheckFeature(this)
        val deviceEnvironmentFeature = DeviceEnvironmentFeature(this)

        val features: List<FeatureMethodHandler> = listOf(
            rootDetectionFeature,
            screenCaptureFeature,
            screenshotFeature,
            screenRecordingFeature,
            appSwitcherPrivacyFeature,
            overlayAttackFeature,
            clipboardFeature,
            callActivityFeature,
            vpnFeature,
            malwareFeature,
            versionCheckFeature,
            deviceEnvironmentFeature,
        )

        methodHandlers = buildMap {
            for (feature in features) {
                for (method in feature.methods) {
                    put(method, feature)
                }
            }
        }
        disposables = features.filterIsInstance<Disposable>()

        EventChannel(binding.binaryMessenger, "device_safety_info/screen_capture_events")
            .setStreamHandler(screenCaptureFeature)

        EventChannel(binding.binaryMessenger, "device_safety_info/screenshot_events")
            .setStreamHandler(screenshotFeature)

        EventChannel(binding.binaryMessenger, "device_safety_info/screen_recording_events")
            .setStreamHandler(screenRecordingFeature)

        EventChannel(binding.binaryMessenger, "device_safety_info/overlay_events")
            .setStreamHandler(overlayAttackFeature)

        EventChannel(binding.binaryMessenger, "device_safety_info/clipboard_events")
            .setStreamHandler(clipboardFeature)

        EventChannel(binding.binaryMessenger, "device_safety_info/connectivity_events")
            .setStreamHandler(vpnFeature)

        EventChannel(binding.binaryMessenger, "device_safety_info/call_activity_events")
            .setStreamHandler(callActivityFeature)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        overlayAttackFeature.onActivityAttached()
        screenRecordingFeature.onActivityAttached()
    }

    override fun onDetachedFromActivity() {
        overlayAttackFeature.onActivityDetached()
        screenRecordingFeature.onActivityDetached()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        overlayAttackFeature.onActivityAttached()
        screenRecordingFeature.onActivityAttached()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        overlayAttackFeature.onActivityDetached()
        screenRecordingFeature.onActivityDetached()
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${Build.VERSION.RELEASE}")
            return
        }
        val handler = methodHandlers[call.method] ?: run {
            result.notImplemented()
            return
        }
        handler.handle(call, result)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        disposables.forEach { it.dispose() }
        disposables = emptyList()
        methodHandlers = emptyMap()
        channel.setMethodCallHandler(null)
    }
}
