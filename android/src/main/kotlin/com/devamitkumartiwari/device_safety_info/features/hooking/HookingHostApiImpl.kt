package com.devamitkumartiwari.device_safety_info.features.hooking

import com.devamitkumartiwari.device_safety_info.core.BackgroundRunner
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.generated.CheckReportMsg
import com.devamitkumartiwari.device_safety_info.generated.HookingHostApi

class HookingHostApiImpl(
    private val host: PluginHost,
    private val bg: BackgroundRunner,
) : HookingHostApi {
    override suspend fun hookCheck(): CheckReportMsg = bg.run { HookDetector.hookReport().toMsg() }

    // Cheap (two flag reads); answered synchronously on the main thread.
    override fun debuggerCheck(): CheckReportMsg = HookDetector.debuggerReport(host.context).toMsg()
}
