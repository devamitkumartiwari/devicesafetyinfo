package com.devamitkumartiwari.device_safety_info.features.screen_protection

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.generated.PigeonEventSink
import com.devamitkumartiwari.device_safety_info.generated.ScreenRecordingChangedStreamHandler
import java.util.concurrent.Executor
import java.util.function.Consumer

/**
 * Screen-recording state through WindowManager.addScreenRecordingCallback (Android 15+). The
 * callback is tied to an activity's WindowManager, so it's re-registered on activity attach.
 */
class ScreenRecordingMonitor(private val host: PluginHost) :
    ScreenRecordingChangedStreamHandler(), Disposable {

    companion object {
        val isApiSupported: Boolean = Build.VERSION.SDK_INT >= 35
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val callbackExecutor = Executor { command -> mainHandler.post(command) }

    private var sink: PigeonEventSink<Boolean>? = null
    private var registeredCallback: Consumer<Int>? = null
    private var registeredOn: WindowManager? = null
    @Volatile private var lastRecording = false
    private val stateListeners = mutableListOf<(Boolean) -> Unit>()

    fun isCurrentlyRecording(): Boolean = isApiSupported && lastRecording

    fun addStateListener(listener: (Boolean) -> Unit) {
        stateListeners.add(listener)
        registerIfPossible()
    }

    fun removeStateListener(listener: (Boolean) -> Unit) {
        stateListeners.remove(listener)
    }

    override fun onListen(p0: Any?, sink: PigeonEventSink<Boolean>) {
        this.sink = sink
        if (!isApiSupported) return
        registerIfPossible()
        sink.success(lastRecording)
    }

    override fun onCancel(p0: Any?) {
        sink = null
        if (stateListeners.isEmpty()) unregister()
    }

    fun onActivityAttached() {
        if (sink != null || stateListeners.isNotEmpty()) registerIfPossible()
    }

    fun onActivityDetached() = unregister()

    @Suppress("NewApi")
    private fun registerIfPossible() {
        if (!isApiSupported || registeredCallback != null) return
        val wm = host.activity?.windowManager ?: return
        val consumer = Consumer<Int> { state ->
            val recording = state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
            if (recording == lastRecording) return@Consumer
            lastRecording = recording
            sink?.success(recording)
            stateListeners.toList().forEach { it(recording) }
        }
        try {
            val initial = wm.addScreenRecordingCallback(callbackExecutor, consumer)
            lastRecording = initial == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
        } catch (e: SecurityException) {
            // Some OEMs enforce DETECT_SCREEN_RECORDING differently; fail soft.
            sink?.error("permission_denied", e.message, null)
            return
        }
        registeredOn = wm
        registeredCallback = consumer
    }

    @Suppress("NewApi")
    private fun unregister() {
        val consumer = registeredCallback ?: return
        try {
            registeredOn?.removeScreenRecordingCallback(consumer)
        } catch (_: Exception) {
        }
        registeredCallback = null
        registeredOn = null
    }

    override fun dispose() {
        sink = null
        stateListeners.clear()
        unregister()
    }
}
