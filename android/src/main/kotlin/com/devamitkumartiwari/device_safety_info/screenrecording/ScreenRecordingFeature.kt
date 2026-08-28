package com.devamitkumartiwari.device_safety_info.screenrecording

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executor
import java.util.function.Consumer

/**
 * `isScreenRecordingDetectionSupported` method + `screen_recording_events` stream.
 *
 * API verification note (do not remove without re-checking): the plan called for confirming the
 * exact Android 15/16 screen-recording-callback API against the SDK actually installed on this
 * machine before writing this class. Verified via:
 *   `javap -public -classpath $ANDROID_HOME/platforms/android-35/android.jar android.view.WindowManager`
 * which shows (absent from the API 34 jar, present starting at API 35):
 *   `public default int addScreenRecordingCallback(Executor, Consumer<Integer>)`
 *   `public default void removeScreenRecordingCallback(Consumer<Integer>)`
 *   `SCREEN_RECORDING_STATE_VISIBLE` / `SCREEN_RECORDING_STATE_NOT_VISIBLE` constants
 * This is a real, shipped API (`Build.VERSION_CODES.VANILLA_ICE_CREAM` == 35), a genuine
 * MediaProjection-recording-visibility signal for the calling window — distinct from the
 * mirroring/external-display heuristic in `ScreenCaptureFeature`. `addScreenRecordingCallback`
 * both registers the listener and synchronously returns the *current* state, which is used as the
 * initial emission. compileSdk is 37, so no additional Gradle changes were needed; the guard below
 * is a pure runtime `Build.VERSION.SDK_INT` check.
 *
 * The callback is registered against the attached Activity's `WindowManager` (it is a
 * window-scoped signal), so — like [com.devamitkumartiwari.device_safety_info.overlay.OverlayAttackFeature] —
 * this feature exposes [onActivityAttached]/[onActivityDetached] for the plugin's `ActivityAware`
 * callbacks to drive, re-registering across activity attach/detach and configuration changes.
 *
 * Real-device finding: even with `DETECT_SCREEN_RECORDING` declared in the manifest,
 * `addScreenRecordingCallback` has been observed throwing `SecurityException` at runtime on some
 * OEM builds (observed on a Samsung device, whose `WindowManagerService` routes this call through
 * an internal Knox-branded path with its own enforcement). [isApiSupported] can only reflect SDK
 * level, not per-device grantability, so [registerIfPossible] treats that exception as "not
 * actually usable here" and errors the stream (same `permission_denied`-class handling
 * [com.devamitkumartiwari.device_safety_info.screenshot.ScreenshotFeature] already uses for the
 * sibling `DETECT_SCREEN_CAPTURE` permission) rather than crashing the host app.
 */
class ScreenRecordingFeature(private val host: PluginHost) :
    FeatureMethodHandler, EventChannel.StreamHandler, Disposable {

    companion object {
        // Build.VERSION_CODES.VANILLA_ICE_CREAM (35) isn't a named constant on every AGP/Kotlin
        // combination this plugin supports building against, so the raw level is used directly.
        private const val MIN_SDK_FOR_RECORDING_CALLBACK = 35
        val isApiSupported: Boolean = Build.VERSION.SDK_INT >= MIN_SDK_FOR_RECORDING_CALLBACK
    }

    override val methods = setOf("isScreenRecordingDetectionSupported")

    private val mainHandler = Handler(Looper.getMainLooper())
    private val callbackExecutor = Executor { command -> mainHandler.post(command) }

    private var eventSink: EventChannel.EventSink? = null
    private var registeredCallback: Consumer<Int>? = null
    private var registeredOnWindowManager: WindowManager? = null
    @Volatile private var lastRecording: Boolean = false

    private val stateListeners = mutableListOf<(Boolean) -> Unit>()

    fun addStateListener(listener: (Boolean) -> Unit) {
        stateListeners.add(listener)
    }

    fun removeStateListener(listener: (Boolean) -> Unit) {
        stateListeners.remove(listener)
    }

    fun isCurrentlyRecording(): Boolean = isApiSupported && lastRecording

    override fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "isScreenRecordingDetectionSupported" -> result.success(isApiSupported)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        if (!isApiSupported) return
        registerIfPossible()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        unregisterIfNeeded()
    }

    /** Called by the plugin's ActivityAware callbacks when an activity attaches (or reattaches). */
    fun onActivityAttached() {
        if (eventSink != null) registerIfPossible()
    }

    /** Called by the plugin's ActivityAware callbacks when the activity detaches. */
    fun onActivityDetached() {
        unregisterIfNeeded()
    }

    @Suppress("NewApi")
    private fun registerIfPossible() {
        if (!isApiSupported || registeredCallback != null) return
        val wm = host.activity?.windowManager ?: return
        val consumer = Consumer<Int> { state ->
            val recording = state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
            if (recording == lastRecording) return@Consumer
            lastRecording = recording
            eventSink?.success(recording)
            stateListeners.toList().forEach { it(recording) }
        }
        try {
            val initialState = wm.addScreenRecordingCallback(callbackExecutor, consumer)
            registeredOnWindowManager = wm
            lastRecording = initialState == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
        } catch (e: SecurityException) {
            // Declared in the manifest but denied at runtime by this OEM's WindowManagerService
            // (see class doc). Deliver as a stream error so the Dart onError handler catches it
            // instead of an uncaught SecurityException reaching the host app.
            eventSink?.error("permission_denied", e.message, null)
            eventSink = null
            return
        }
        registeredCallback = consumer
        // Emit the current state immediately, same as ScreenCaptureFeature does on listen —
        // otherwise a subscriber gets nothing until the next actual transition.
        eventSink?.success(lastRecording)
    }

    @Suppress("NewApi")
    private fun unregisterIfNeeded() {
        val consumer = registeredCallback ?: return
        try {
            registeredOnWindowManager?.removeScreenRecordingCallback(consumer)
        } catch (e: Exception) {
            // Best-effort cleanup — never let unregistration crash the host app.
        }
        registeredCallback = null
        registeredOnWindowManager = null
    }

    override fun dispose() {
        eventSink = null
        unregisterIfNeeded()
        stateListeners.clear()
    }
}
