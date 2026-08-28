package com.devamitkumartiwari.device_safety_info.screenshot

import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.WindowManager
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.screencapturedetector.ScreenCaptureFeature
import com.devamitkumartiwari.device_safety_info.screenrecording.ScreenRecordingFeature
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * `blockScreenShots` / `isScreenshotBlocked` / `setScreenshotOverlayMode` /
 * `clearScreenshotOverlayMode` methods + `screenshot_events` stream (screenshot-taken detection).
 *
 * Takes [screenCaptureFeature] and [screenRecordingFeature] so the overlay-mode feature can query
 * "is a capture/recording happening right now" and react to future transitions — the minimal
 * wiring needed for three call sites, rather than a generic pub/sub system.
 */
class ScreenshotFeature(
    private val host: PluginHost,
    private val screenCaptureFeature: ScreenCaptureFeature,
    private val screenRecordingFeature: ScreenRecordingFeature,
) : FeatureMethodHandler, EventChannel.StreamHandler, Disposable {

    override val methods = setOf(
        "blockScreenShots",
        "isScreenshotBlocked",
        "setScreenshotOverlayMode",
        "clearScreenshotOverlayMode",
    )

    private val overlayManager = ScreenshotOverlayManager(host)
    private var overlayListenersRegistered = false
    private val captureStateListener: (Boolean) -> Unit = { updateOverlayActive() }
    private val recordingStateListener: (Boolean) -> Unit = { updateOverlayActive() }

    // --- Screenshot detection stream state ---
    private var eventSink: EventChannel.EventSink? = null
    private var screenshotContentObserver: ContentObserver? = null
    private var api34ScreenshotCallback: Any? = null // Activity.ScreenCaptureCallback (API 34+)
    private var api34Executor: ExecutorService? = null

    override fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "blockScreenShots" -> {
                val block = call.argument<Boolean>("block") ?: false
                val act = host.activity ?: run { result.error("NO_ACTIVITY", "Activity not attached", null); return }
                ScreenShotManager.setScreenshotBlock(act, block)
                result.success(null)
            }
            "isScreenshotBlocked" -> {
                val act = host.activity
                if (act == null) {
                    result.success(false)
                    return
                }
                val flags = act.window.attributes.flags
                result.success((flags and WindowManager.LayoutParams.FLAG_SECURE) != 0)
            }
            "setScreenshotOverlayMode" -> {
                val modeArg = (call.argument<String>("mode") ?: "none").uppercase()
                val mode = try {
                    OverlayMode.valueOf(modeArg)
                } catch (_: IllegalArgumentException) {
                    OverlayMode.NONE
                }
                if (mode == OverlayMode.NONE) {
                    clearOverlay()
                    result.success(null)
                    return
                }
                val blurRadius = (call.argument<Double>("blurRadius") ?: 10.0).toFloat()
                val argbColor = call.argument<Int>("argbColor")
                val imageBytes = call.argument<ByteArray>("imageBytes")
                overlayManager.setConfig(OverlayConfig(mode, blurRadius, argbColor, imageBytes))
                registerOverlayListenersIfNeeded()
                updateOverlayActive()
                result.success(null)
            }
            "clearScreenshotOverlayMode" -> {
                clearOverlay()
                result.success(null)
            }
        }
    }

    private fun clearOverlay() {
        overlayManager.clear()
        unregisterOverlayListeners()
    }

    private fun registerOverlayListenersIfNeeded() {
        if (overlayListenersRegistered) return
        screenCaptureFeature.addStateListener(captureStateListener)
        screenRecordingFeature.addStateListener(recordingStateListener)
        overlayListenersRegistered = true
    }

    private fun unregisterOverlayListeners() {
        if (!overlayListenersRegistered) return
        screenCaptureFeature.removeStateListener(captureStateListener)
        screenRecordingFeature.removeStateListener(recordingStateListener)
        overlayListenersRegistered = false
    }

    private fun updateOverlayActive() {
        val active = screenCaptureFeature.isCurrentlyCaptured() || screenRecordingFeature.isCurrentlyRecording()
        overlayManager.setActive(active)
    }

    // --- Screenshot detection stream handler ---

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        try {
            startScreenshotDetection()
        } catch (e: SecurityException) {
            // DETECT_SCREEN_CAPTURE not granted (e.g. missing from manifest on API 34+).
            // Deliver as stream error so the Dart onError handler catches it instead
            // of propagating through FlutterError and failing the test framework.
            events?.error("permission_denied", e.message, null)
            eventSink = null
        }
    }

    override fun onCancel(arguments: Any?) {
        stopScreenshotDetection()
        eventSink = null
    }

    private fun startScreenshotDetection() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startApi34ScreenshotDetection()
        } else {
            startContentObserverDetection()
        }
    }

    @Suppress("NewApi")
    private fun startApi34ScreenshotDetection() {
        val act = host.activity ?: return
        api34Executor?.shutdown()
        api34Executor = Executors.newSingleThreadExecutor()
        val callback = android.app.Activity.ScreenCaptureCallback {
            eventSink?.success(null)
        }
        act.registerScreenCaptureCallback(api34Executor!!, callback)
        api34ScreenshotCallback = callback
    }

    private fun startContentObserverDetection() {
        val ctx = host.context ?: return
        screenshotContentObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                uri?.let { checkIfScreenshot(it) }
            }
        }
        ctx.contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            screenshotContentObserver!!
        )
    }

    private fun checkIfScreenshot(uri: Uri) {
        try {
            val projection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                arrayOf(MediaStore.Images.Media.RELATIVE_PATH)
            } else {
                @Suppress("DEPRECATION")
                arrayOf(MediaStore.Images.Media.DATA)
            }
            host.context?.contentResolver?.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val path = cursor.getString(0) ?: return
                    if (path.contains("screenshot", ignoreCase = true)) {
                        eventSink?.success(null)
                    }
                }
            }
        } catch (_: Exception) {}
    }

    private fun stopScreenshotDetection() {
        screenshotContentObserver?.let {
            host.context?.contentResolver?.unregisterContentObserver(it)
            screenshotContentObserver = null
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            @Suppress("NewApi")
            (api34ScreenshotCallback as? android.app.Activity.ScreenCaptureCallback)?.let { cb ->
                host.activity?.unregisterScreenCaptureCallback(cb)
            }
            api34ScreenshotCallback = null
        }
        api34Executor?.shutdown()
        api34Executor = null
    }

    override fun dispose() {
        stopScreenshotDetection()
        eventSink = null
        clearOverlay()
    }
}
