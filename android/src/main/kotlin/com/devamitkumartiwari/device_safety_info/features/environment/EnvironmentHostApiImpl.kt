package com.devamitkumartiwari.device_safety_info.features.environment

import android.content.Context
import com.devamitkumartiwari.device_safety_info.core.BackgroundRunner
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.requireContext
import com.devamitkumartiwari.device_safety_info.generated.CheckReportMsg
import com.devamitkumartiwari.device_safety_info.generated.EnvironmentHostApi

class EnvironmentHostApiImpl(
    private val host: PluginHost,
    private val bg: BackgroundRunner,
) : EnvironmentHostApi {

    private suspend fun run(block: (Context) -> RiskReport): CheckReportMsg {
        val ctx = host.requireContext()
        return bg.run { block(ctx).toMsg() }
    }

    override suspend fun remoteAccess() = run(RemoteAccessDetector::report)
    override suspend fun locationSpoofing() = run(MockLocationDetector::report)
    override suspend fun appCloning() = run(CloneDetector::report)
    override suspend fun mitm() = run(UserCaDetector::report)
    override suspend fun keyboard() = run(KeyboardDetector::report)

    /** iOS only. */
    override fun setBlockCustomKeyboards(block: Boolean) = Unit
}
