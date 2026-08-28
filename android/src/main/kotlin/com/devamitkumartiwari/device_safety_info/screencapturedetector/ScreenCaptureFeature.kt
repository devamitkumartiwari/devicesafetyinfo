package com.devamitkumartiwari.device_safety_info.screencapturedetector

import android.content.Context
import android.hardware.display.DisplayManager
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/**
 * `isScreenCaptured` method + `screen_capture_events` stream (screen mirroring / external-display
 * capture, via [DisplayManager.DisplayListener] — distinct from the screenshot and screen-recording
 * features).
 */
class ScreenCaptureFeature(private val host: PluginHost) :
    FeatureMethodHandler, EventChannel.StreamHandler, Disposable {

    override val methods = setOf("isScreenCaptured")

    private val displayManager: DisplayManager? by lazy {
        host.context?.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
    }
    private var displayListener: DisplayManager.DisplayListener? = null
    private var eventSink: EventChannel.EventSink? = null

    /** Callbacks other features (e.g. the screenshot overlay) can register to react to changes. */
    private val stateListeners = mutableListOf<(Boolean) -> Unit>()

    fun addStateListener(listener: (Boolean) -> Unit) {
        stateListeners.add(listener)
    }

    fun removeStateListener(listener: (Boolean) -> Unit) {
        stateListeners.remove(listener)
    }

    fun isCurrentlyCaptured(): Boolean =
        host.context?.let { ScreenCaptureDetector(it).isScreenBeingCaptured() } ?: false

    override fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "isScreenCaptured" -> result.success(isCurrentlyCaptured())
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        if (displayListener == null) {
            displayListener = object : DisplayManager.DisplayListener {
                override fun onDisplayAdded(displayId: Int) = updateScreenCaptureState()
                override fun onDisplayRemoved(displayId: Int) = updateScreenCaptureState()
                override fun onDisplayChanged(displayId: Int) {}
            }
            displayManager?.registerDisplayListener(displayListener, null)
            updateScreenCaptureState()
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        displayListener?.let { displayManager?.unregisterDisplayListener(it) }
        displayListener = null
    }

    private fun updateScreenCaptureState() {
        val isCaptured = isCurrentlyCaptured()
        eventSink?.success(isCaptured)
        stateListeners.toList().forEach { it(isCaptured) }
    }

    override fun dispose() {
        displayListener?.let { displayManager?.unregisterDisplayListener(it) }
        displayListener = null
        eventSink = null
        stateListeners.clear()
    }
}
