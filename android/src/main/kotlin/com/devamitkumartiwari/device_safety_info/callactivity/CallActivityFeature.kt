package com.devamitkumartiwari.device_safety_info.callactivity

import android.os.Handler
import android.os.Looper
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/**
 * `isCallActive` method + `call_activity_events` stream.
 *
 * Three signal sources (telephony push, audio-config push, and a ~2s audio-mode poll safety
 * net for transitions the config-list callbacks miss) all funnel into evaluateAndEmitCallActivity,
 * which diffs against the last-emitted state so near-simultaneous signals for the same call
 * don't double-fire. Everything here only runs between onListen and onCancel — nothing is
 * registered merely because the plugin is bundled.
 */
class CallActivityFeature(private val host: PluginHost) :
    FeatureMethodHandler, EventChannel.StreamHandler, Disposable {

    override val methods = setOf("isCallActive")

    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var telephonyHandle: CallActivityWatcher.TelephonyHandle? = null
    private var audioHandle: CallActivityWatcher.AudioCallbackHandle? = null
    private var pollRunnable: Runnable? = null
    private var lastActive = false
    private var lastSource: CallActivityWatcher.Source? = null

    override fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "isCallActive" -> result.success(host.context?.let { CallActivityWatcher.isCallActive(it) } ?: false)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val ctx = host.context ?: return

        telephonyHandle = CallActivityWatcher.registerTelephony(ctx, mainHandler) { evaluateAndEmitCallActivity() }
        audioHandle = CallActivityWatcher.registerAudioCallbacks(ctx, mainHandler) { evaluateAndEmitCallActivity() }

        val poll = object : Runnable {
            override fun run() {
                evaluateAndEmitCallActivity()
                mainHandler.postDelayed(this, 2000L)
            }
        }
        pollRunnable = poll
        mainHandler.postDelayed(poll, 2000L)

        evaluateAndEmitCallActivity()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        CallActivityWatcher.unregisterTelephony(telephonyHandle)
        telephonyHandle = null
        CallActivityWatcher.unregisterAudioCallbacks(audioHandle)
        audioHandle = null
        pollRunnable?.let { mainHandler.removeCallbacks(it) }
        pollRunnable = null
        lastActive = false
        lastSource = null
    }

    private fun evaluateAndEmitCallActivity() {
        val ctx = host.context ?: return
        val source = CallActivityWatcher.currentSource(ctx)
        val active = source != null

        if (active == lastActive && source == lastSource) return

        if (active) {
            eventSink?.success(mapOf(
                "source" to (if (source == CallActivityWatcher.Source.SIM) "simCall" else "voipCall"),
                "state" to "started",
                "timestamp" to System.currentTimeMillis()
            ))
        } else {
            eventSink?.success(mapOf(
                "source" to (if (lastSource == CallActivityWatcher.Source.SIM) "simCall" else "voipCall"),
                "state" to "ended",
                "timestamp" to System.currentTimeMillis()
            ))
        }

        lastActive = active
        lastSource = source
    }

    override fun dispose() {
        CallActivityWatcher.unregisterTelephony(telephonyHandle)
        telephonyHandle = null
        CallActivityWatcher.unregisterAudioCallbacks(audioHandle)
        audioHandle = null
        pollRunnable?.let { mainHandler.removeCallbacks(it) }
        pollRunnable = null
        eventSink = null
    }
}
