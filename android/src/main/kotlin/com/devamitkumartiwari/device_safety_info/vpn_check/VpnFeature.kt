package com.devamitkumartiwari.device_safety_info.vpn_check

import android.net.ConnectivityManager
import android.os.Handler
import android.os.Looper
import com.devamitkumartiwari.device_safety_info.connectivity.ConnectivityWatcher
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/**
 * `isVPNCheck` method + `connectivity_events` stream.
 *
 * `ConnectivityManager.registerNetworkCallback(request, callback)` without a Handler
 * delivers callbacks on a background thread. Since minSdk is 24 but the Handler-accepting
 * overloads require API 26/28, results are posted through mainHandler before touching the
 * EventSink, which must only be called on the main thread.
 */
class VpnFeature(private val host: PluginHost) :
    FeatureMethodHandler, EventChannel.StreamHandler, Disposable {

    override val methods = setOf("isVPNCheck")

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var connectivityCallback: ConnectivityManager.NetworkCallback? = null

    override fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "isVPNCheck" -> result.success(host.context?.let { VpnCheck.isActiveVPN(it) })
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val ctx = host.context ?: return
        connectivityCallback = ConnectivityWatcher.register(ctx) {
            mainHandler.post { eventSink?.success(null) }
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        connectivityCallback?.let { cb -> host.context?.let { ConnectivityWatcher.unregister(it, cb) } }
        connectivityCallback = null
    }

    override fun dispose() {
        connectivityCallback?.let { cb -> host.context?.let { ConnectivityWatcher.unregister(it, cb) } }
        connectivityCallback = null
        eventSink = null
    }
}
