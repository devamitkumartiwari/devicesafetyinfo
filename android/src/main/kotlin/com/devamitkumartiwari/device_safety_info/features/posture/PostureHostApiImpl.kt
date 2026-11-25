package com.devamitkumartiwari.device_safety_info.features.posture

import com.devamitkumartiwari.device_safety_info.core.BackgroundRunner
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.requireContext
import com.devamitkumartiwari.device_safety_info.features.accessibility.AccessibilityAbuseDetector
import com.devamitkumartiwari.device_safety_info.features.notification_listener.NotificationListenerAbuseDetector
import com.devamitkumartiwari.device_safety_info.generated.AccessibilityServiceMsg
import com.devamitkumartiwari.device_safety_info.generated.CheckReportMsg
import com.devamitkumartiwari.device_safety_info.generated.NotificationListenerMsg
import com.devamitkumartiwari.device_safety_info.generated.PostureHostApi

class PostureHostApiImpl(
    private val host: PluginHost,
    private val bg: BackgroundRunner,
) : PostureHostApi {

    private suspend fun report(block: (android.content.Context) -> com.devamitkumartiwari.device_safety_info.core.RiskReport): CheckReportMsg {
        val ctx = host.requireContext()
        return bg.run { block(ctx).toMsg() }
    }

    override suspend fun developerMode() = report(PostureReports::developerMode)
    override suspend fun screenLock() = report(PostureReports::screenLock)
    override suspend fun storeInstall() = report(PostureReports::storeInstall)
    override suspend fun externalStorage() = report(PostureReports::externalStorage)
    override suspend fun unknownSources() = report(PostureReports::unknownSources)
    override suspend fun playProtect() = report(PostureReports::playProtect)

    override suspend fun enabledAccessibilityServices(): List<AccessibilityServiceMsg> {
        val ctx = host.requireContext()
        return bg.run { AccessibilityAbuseDetector.enabledServices(ctx) }
    }

    override suspend fun enabledNotificationListeners(): List<NotificationListenerMsg> {
        val ctx = host.requireContext()
        return bg.run { NotificationListenerAbuseDetector.enabledListeners(ctx) }
    }
}
