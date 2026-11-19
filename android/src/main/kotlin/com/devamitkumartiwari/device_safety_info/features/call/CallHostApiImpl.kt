package com.devamitkumartiwari.device_safety_info.features.call

import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.requireActivity
import com.devamitkumartiwari.device_safety_info.generated.CallHostApi
import com.devamitkumartiwari.device_safety_info.generated.FlutterError

class CallHostApiImpl(private val host: PluginHost) : CallHostApi {

    override fun isCallActive(): Boolean =
        host.context?.let { CallActivityWatcher.isCallActive(it) } ?: false

    override fun isScreeningRoleAvailable(): Boolean =
        host.context?.let { CallScreeningRoleCheck.isRoleAvailable(it) } ?: false

    override fun isScreeningRoleHeld(): Boolean =
        host.context?.let { CallScreeningRoleCheck.isRoleHeldByThisApp(it) } ?: false

    override fun openScreeningRoleSettings() {
        val act = host.requireActivity()
        val intent = CallScreeningRoleCheck.createRequestRoleIntent(act)
            ?: throw FlutterError("UNSUPPORTED", "ROLE_CALL_SCREENING requires Android 10 (API 29)+")
        act.startActivity(intent)
    }
}
