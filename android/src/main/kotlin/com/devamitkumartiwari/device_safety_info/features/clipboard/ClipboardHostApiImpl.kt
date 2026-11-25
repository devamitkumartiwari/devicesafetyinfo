package com.devamitkumartiwari.device_safety_info.features.clipboard

import android.content.ClipboardManager
import android.os.Handler
import android.os.Looper
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.generated.ClipboardChangedStreamHandler
import com.devamitkumartiwari.device_safety_info.generated.ClipboardHostApi
import com.devamitkumartiwari.device_safety_info.generated.FlutterError
import com.devamitkumartiwari.device_safety_info.generated.PigeonEventSink

class ClipboardHostApiImpl(private val host: PluginHost) : ClipboardHostApi, Disposable {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var manager: ClipboardProtectionManager? = null

    internal fun manager(): ClipboardProtectionManager? {
        manager?.let { return it }
        return host.context?.let { ClipboardProtectionManager(it) }?.also { manager = it }
    }

    override fun copySecure(text: String, sensitive: Boolean, clearAfterMs: Long?) {
        val m = manager() ?: throw FlutterError("NO_CONTEXT", "Application context not attached")
        m.copyToClipboard(text, sensitive, clearAfterMs?.takeIf { it > 0 }, mainHandler)
    }

    override fun clear() {
        manager()?.clearClipboard()
    }

    override fun dispose() {
        manager = null
    }
}

/** Sends a timestamp whenever the primary clip changes. */
class ClipboardChangeMonitor(private val api: ClipboardHostApiImpl) :
    ClipboardChangedStreamHandler(), Disposable {

    private var sink: PigeonEventSink<Long>? = null
    private var listener: ClipboardManager.OnPrimaryClipChangedListener? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<Long>) {
        this.sink = sink
        val l = ClipboardManager.OnPrimaryClipChangedListener {
            this.sink?.success(System.currentTimeMillis())
        }
        listener = l
        api.manager()?.addChangeListener(l)
    }

    override fun onCancel(p0: Any?) = dispose()

    override fun dispose() {
        listener?.let { api.manager()?.removeChangeListener(it) }
        listener = null
        sink = null
    }
}
