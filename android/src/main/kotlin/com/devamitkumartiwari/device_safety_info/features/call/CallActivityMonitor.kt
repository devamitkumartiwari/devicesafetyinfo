package com.devamitkumartiwari.device_safety_info.features.call

import android.os.Handler
import android.os.Looper
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.generated.CallActivityStreamHandler
import com.devamitkumartiwari.device_safety_info.generated.CallEventMsg
import com.devamitkumartiwari.device_safety_info.generated.CallSourceMsg
import com.devamitkumartiwari.device_safety_info.generated.PigeonEventSink

/**
 * Emits call start/end events. SIM calls need READ_PHONE_STATE, which the app declares and
 * requests itself (the plugin no longer does); without it only VoIP audio is detected. A 2 s
 * poll backs up the callbacks, which some OEMs deliver unreliably.
 */
class CallActivityMonitor(private val host: PluginHost) : CallActivityStreamHandler(), Disposable {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: PigeonEventSink<CallEventMsg>? = null
    private var telephonyHandle: CallActivityWatcher.TelephonyHandle? = null
    private var audioHandle: CallActivityWatcher.AudioCallbackHandle? = null
    private var poll: Runnable? = null
    private var lastActive = false
    private var lastSource: CallActivityWatcher.Source? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<CallEventMsg>) {
        this.sink = sink
        val ctx = host.context ?: return
        telephonyHandle = CallActivityWatcher.registerTelephony(ctx, mainHandler) { evaluate() }
        audioHandle = CallActivityWatcher.registerAudioCallbacks(ctx, mainHandler) { evaluate() }
        val runnable = object : Runnable {
            override fun run() {
                evaluate()
                mainHandler.postDelayed(this, 2000L)
            }
        }
        poll = runnable
        mainHandler.postDelayed(runnable, 2000L)
        evaluate()
    }

    override fun onCancel(p0: Any?) = dispose()

    private fun evaluate() {
        val ctx = host.context ?: return
        val source = CallActivityWatcher.currentSource(ctx)
        val active = source != null
        if (active == lastActive && source == lastSource) return
        val reported = if (active) source else lastSource
        sink?.success(
            CallEventMsg(
                source = if (reported == CallActivityWatcher.Source.SIM) CallSourceMsg.SIM_CALL else CallSourceMsg.VOIP_CALL,
                started = active,
                timestampMs = System.currentTimeMillis(),
            ),
        )
        lastActive = active
        lastSource = source
    }

    override fun dispose() {
        CallActivityWatcher.unregisterTelephony(telephonyHandle)
        telephonyHandle = null
        CallActivityWatcher.unregisterAudioCallbacks(audioHandle)
        audioHandle = null
        poll?.let { mainHandler.removeCallbacks(it) }
        poll = null
        lastActive = false
        lastSource = null
        sink = null
    }
}
