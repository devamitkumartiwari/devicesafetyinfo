package com.devamitkumartiwari.device_safety_info.features.screen_protection

import android.content.Context
import android.hardware.display.DisplayManager
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.generated.PigeonEventSink
import com.devamitkumartiwari.device_safety_info.generated.ScreenCaptureChangedStreamHandler

/**
 * Watches for displays being added or removed (screen mirroring, recording virtual displays)
 * and reports the capture state. Other components (the screenshot overlay) can subscribe with
 * [addStateListener] independently of the Dart stream.
 */
class ScreenCaptureMonitor(private val host: PluginHost) :
    ScreenCaptureChangedStreamHandler(), Disposable {

    private val displayManager: DisplayManager? by lazy {
        host.context?.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
    }
    private var displayListener: DisplayManager.DisplayListener? = null
    private var sink: PigeonEventSink<Boolean>? = null
    private val stateListeners = mutableListOf<(Boolean) -> Unit>()

    fun isCurrentlyCaptured(): Boolean =
        host.context?.let { ScreenCaptureDetector(it).isScreenBeingCaptured() } ?: false

    fun addStateListener(listener: (Boolean) -> Unit) {
        stateListeners.add(listener)
        ensureRegistered()
    }

    fun removeStateListener(listener: (Boolean) -> Unit) {
        stateListeners.remove(listener)
        unregisterIfUnused()
    }

    override fun onListen(p0: Any?, sink: PigeonEventSink<Boolean>) {
        this.sink = sink
        ensureRegistered()
        sink.success(isCurrentlyCaptured())
    }

    override fun onCancel(p0: Any?) {
        sink = null
        unregisterIfUnused()
    }

    private fun ensureRegistered() {
        if (displayListener != null) return
        val listener = object : DisplayManager.DisplayListener {
            override fun onDisplayAdded(displayId: Int) = update()
            override fun onDisplayRemoved(displayId: Int) = update()
            override fun onDisplayChanged(displayId: Int) {}
        }
        displayManager?.registerDisplayListener(listener, null)
        displayListener = listener
    }

    private fun unregisterIfUnused() {
        if (sink != null || stateListeners.isNotEmpty()) return
        displayListener?.let { displayManager?.unregisterDisplayListener(it) }
        displayListener = null
    }

    private fun update() {
        val captured = isCurrentlyCaptured()
        sink?.success(captured)
        stateListeners.toList().forEach { it(captured) }
    }

    override fun dispose() {
        sink = null
        stateListeners.clear()
        unregisterIfUnused()
    }
}
