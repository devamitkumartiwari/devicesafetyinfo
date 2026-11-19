package com.devamitkumartiwari.device_safety_info.features.overlay_attack

import android.app.Activity
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.requireActivity
import com.devamitkumartiwari.device_safety_info.generated.OverlayAttackHostApi
import com.devamitkumartiwari.device_safety_info.generated.OverlayAttackStreamHandler
import com.devamitkumartiwari.device_safety_info.generated.PigeonEventSink

class OverlayAttackHostApiImpl(private val host: PluginHost) : OverlayAttackHostApi {
    override fun blockTouchesWhenObscured(block: Boolean) {
        host.requireActivity().window.decorView.filterTouchesWhenObscured = block
    }
}

/**
 * Reports touches that arrive while another app's window covers this one (tapjacking). The
 * detector wraps the activity's Window.Callback, so it's reinstalled whenever the activity
 * attaches again.
 */
class OverlayAttackMonitor(private val host: PluginHost) : OverlayAttackStreamHandler(), Disposable {

    private var sink: PigeonEventSink<Long>? = null
    private var detector: OverlayAttackDetector? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<Long>) {
        this.sink = sink
        host.activity?.let { install(it) }
    }

    override fun onCancel(p0: Any?) {
        sink = null
        host.activity?.let { uninstall(it) }
    }

    fun onActivityAttached() {
        if (sink != null) host.activity?.let { install(it) }
    }

    fun onActivityDetached() {
        host.activity?.let { uninstall(it) }
    }

    private fun install(act: Activity) {
        if (detector != null) return
        detector = OverlayAttackDetector.install(act) {
            sink?.success(System.currentTimeMillis())
        }
    }

    private fun uninstall(act: Activity) {
        detector?.let { OverlayAttackDetector.uninstall(act, it) }
        detector = null
    }

    override fun dispose() {
        host.activity?.let { uninstall(it) }
        sink = null
    }
}
