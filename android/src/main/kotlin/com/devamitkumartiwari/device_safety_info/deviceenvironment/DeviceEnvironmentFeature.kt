package com.devamitkumartiwari.device_safety_info.deviceenvironment

import com.devamitkumartiwari.device_safety_info.accessibility.AccessibilityAbuseDetector
import com.devamitkumartiwari.device_safety_info.callscreening.CallScreeningRoleCheck
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.developmentmode.DevelopmentModeCheck
import com.devamitkumartiwari.device_safety_info.externalstorage.ExternalStorageCheck
import com.devamitkumartiwari.device_safety_info.notificationlistener.NotificationListenerAbuseDetector
import com.devamitkumartiwari.device_safety_info.playprotect.PlayProtectStatusCheck
import com.devamitkumartiwari.device_safety_info.realdevice.RealDeviceCheck
import com.devamitkumartiwari.device_safety_info.screenlock.ScreenLockCheck
import com.devamitkumartiwari.device_safety_info.sideload.UnknownSourcesCheck
import com.devamitkumartiwari.device_safety_info.storeinstallcheck.StoreInstallCheck
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/**
 * The one-shot device-posture/environment checks that don't warrant their own feature file:
 * real-device, external-storage, developer-mode, screen-lock, store-install, Play Protect,
 * accessibility/notification-listener abuse enumeration, sideloading, and call-screening role.
 */
class DeviceEnvironmentFeature(private val host: PluginHost) : FeatureMethodHandler {

    override val methods = setOf(
        "isRealDevice",
        "isExternalStorage",
        "isDeveloperMode",
        "isScreenLock",
        "isInstalledFromStore",
        "getPlayProtectStatus",
        "getEnabledAccessibilityServices",
        "getEnabledNotificationListeners",
        "isUnknownSourcesEnabled",
        "isCallScreeningRoleAvailable",
        "isCallScreeningRoleHeldByThisApp",
        "openCallScreeningRoleSettings",
    )

    override fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "isRealDevice" -> result.success(RealDeviceCheck.isRealDevice())
            "isExternalStorage" -> result.success(host.context?.let { ExternalStorageCheck.isExternalStorage(it) })
            "isDeveloperMode" -> result.success(host.context?.let { DevelopmentModeCheck.isDevMode(it) })
            "isScreenLock" -> result.success(host.context?.let { ScreenLockCheck.isDeviceScreenLocked(it) })
            "isInstalledFromStore" -> result.success(host.context?.let { StoreInstallCheck.isInstalledFromStore(it) })
            "getPlayProtectStatus" -> result.success(host.context?.let { PlayProtectStatusCheck.getStatus(it) } ?: 0)
            "getEnabledAccessibilityServices" -> {
                result.success(host.context?.let {
                    AccessibilityAbuseDetector.getEnabledAccessibilityServices(it)
                } ?: emptyList<String>())
            }
            "getEnabledNotificationListeners" -> {
                result.success(host.context?.let {
                    NotificationListenerAbuseDetector.getEnabledNotificationListeners(it)
                } ?: emptyList<String>())
            }
            "isUnknownSourcesEnabled" -> {
                result.success(host.context?.let { UnknownSourcesCheck.isUnknownSourcesEnabled(it) } ?: false)
            }
            "isCallScreeningRoleAvailable" -> {
                result.success(host.context?.let { CallScreeningRoleCheck.isRoleAvailable(it) } ?: false)
            }
            "isCallScreeningRoleHeldByThisApp" -> {
                result.success(host.context?.let { CallScreeningRoleCheck.isRoleHeldByThisApp(it) } ?: false)
            }
            "openCallScreeningRoleSettings" -> {
                val act = host.activity ?: run { result.error("NO_ACTIVITY", "Activity not attached", null); return }
                val intent = CallScreeningRoleCheck.createRequestRoleIntent(act)
                if (intent == null) {
                    result.error("UNSUPPORTED", "ROLE_CALL_SCREENING requires API 29+", null)
                } else {
                    act.startActivity(intent)
                    result.success(null)
                }
            }
        }
    }
}
