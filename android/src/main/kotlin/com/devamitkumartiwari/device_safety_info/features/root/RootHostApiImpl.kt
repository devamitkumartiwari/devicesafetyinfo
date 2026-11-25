package com.devamitkumartiwari.device_safety_info.features.root

import com.devamitkumartiwari.device_safety_info.core.BackgroundRunner
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.requireContext
import com.devamitkumartiwari.device_safety_info.features.emulator.RealDeviceCheck
import com.devamitkumartiwari.device_safety_info.generated.CheckReportMsg
import com.devamitkumartiwari.device_safety_info.generated.RootHostApi

class RootHostApiImpl(
    private val host: PluginHost,
    private val bg: BackgroundRunner,
) : RootHostApi {
    override suspend fun rootCheck(): CheckReportMsg {
        val ctx = host.requireContext()
        return bg.run { RootedDeviceCheck.evaluate(ctx).toMsg() }
    }

    override suspend fun emulatorCheck(): CheckReportMsg {
        val ctx = host.context
        return bg.run { RealDeviceCheck.evaluate(ctx).toMsg() }
    }
}
