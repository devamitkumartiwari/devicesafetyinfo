package com.devamitkumartiwari.device_safety_info.features.root

import com.devamitkumartiwari.device_safety_info.core.BackgroundRunner
import com.devamitkumartiwari.device_safety_info.features.emulator.RealDeviceCheck
import com.devamitkumartiwari.device_safety_info.generated.CheckReportMsg
import com.devamitkumartiwari.device_safety_info.generated.RootHostApi

class RootHostApiImpl(private val bg: BackgroundRunner) : RootHostApi {
    override suspend fun rootCheck(): CheckReportMsg = bg.run { RootedDeviceCheck.evaluate().toMsg() }

    override suspend fun emulatorCheck(): CheckReportMsg = bg.run { RealDeviceCheck.evaluate().toMsg() }
}
