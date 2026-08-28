package com.devamitkumartiwari.device_safety_info.clipboard

import android.content.ClipboardManager
import android.os.Handler
import android.os.Looper
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/** `copyToClipboard` / `clearClipboard` methods + `clipboard_events` stream. */
class ClipboardFeature(private val host: PluginHost) :
    FeatureMethodHandler, EventChannel.StreamHandler, Disposable {

    override val methods = setOf("copyToClipboard", "clearClipboard")

    private val mainHandler = Handler(Looper.getMainLooper())
    private var clipboardProtectionManager: ClipboardProtectionManager? =
        host.context?.let { ClipboardProtectionManager(it) }

    private var eventSink: EventChannel.EventSink? = null
    private var clipboardChangeListener: ClipboardManager.OnPrimaryClipChangedListener? = null

    override fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "copyToClipboard" -> {
                val text = call.argument<String>("text") ?: ""
                val sensitive = call.argument<Boolean>("sensitive") ?: true
                val autoClearMillis = call.argument<Int>("autoClearMillis")?.toLong()
                clipboardProtectionManager?.copyToClipboard(text, sensitive, autoClearMillis, mainHandler)
                result.success(null)
            }
            "clearClipboard" -> {
                clipboardProtectionManager?.clearClipboard()
                result.success(null)
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val listener = ClipboardManager.OnPrimaryClipChangedListener {
            eventSink?.success(null)
        }
        clipboardChangeListener = listener
        clipboardProtectionManager?.addChangeListener(listener)
    }

    override fun onCancel(arguments: Any?) {
        clipboardChangeListener?.let { clipboardProtectionManager?.removeChangeListener(it) }
        clipboardChangeListener = null
        eventSink = null
    }

    override fun dispose() {
        clipboardChangeListener?.let { clipboardProtectionManager?.removeChangeListener(it) }
        clipboardChangeListener = null
        eventSink = null
        clipboardProtectionManager = null
    }
}
