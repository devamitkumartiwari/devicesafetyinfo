package com.devamitkumartiwari.device_safety_info.features.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.os.Handler
import android.os.Looper
import com.devamitkumartiwari.device_safety_info.core.BackgroundRunner
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.core.requireContext
import com.devamitkumartiwari.device_safety_info.generated.CheckReportMsg
import com.devamitkumartiwari.device_safety_info.generated.PigeonEventSink
import com.devamitkumartiwari.device_safety_info.generated.VpnChangedStreamHandler
import com.devamitkumartiwari.device_safety_info.generated.VpnHostApi

object VpnReport {
    fun evaluate(context: Context): RiskReport {
        val signals = mutableListOf<RiskSignal>()
        if (VpnCheck.isActiveVPN(context)) signals += RiskSignal("vpn.active", highRisk = false)
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val proxy = try {
            cm?.defaultProxy?.host
        } catch (_: Exception) {
            null
        } ?: System.getProperty("http.proxyHost")
        if (!proxy.isNullOrBlank()) signals += RiskSignal("vpn.http_proxy", highRisk = false)
        return RiskReport(signals)
    }
}

class VpnHostApiImpl(
    private val host: PluginHost,
    private val bg: BackgroundRunner,
) : VpnHostApi {
    override suspend fun vpnCheck(): CheckReportMsg {
        val ctx = host.requireContext()
        return bg.run { VpnReport.evaluate(ctx).toMsg() }
    }
}

/** Sends whether a VPN is active on every connectivity change. */
class VpnChangeMonitor(private val host: PluginHost) : VpnChangedStreamHandler(), Disposable {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: PigeonEventSink<Boolean>? = null
    private var callback: ConnectivityManager.NetworkCallback? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<Boolean>) {
        this.sink = sink
        val ctx = host.context ?: return
        emit(ctx)
        callback = ConnectivityWatcher.register(ctx) { mainHandler.post { emit(ctx) } }
    }

    private fun emit(ctx: Context) {
        sink?.success(VpnCheck.isActiveVPN(ctx))
    }

    override fun onCancel(p0: Any?) = dispose()

    override fun dispose() {
        callback?.let { cb -> host.context?.let { ConnectivityWatcher.unregister(it, cb) } }
        callback = null
        sink = null
    }
}
