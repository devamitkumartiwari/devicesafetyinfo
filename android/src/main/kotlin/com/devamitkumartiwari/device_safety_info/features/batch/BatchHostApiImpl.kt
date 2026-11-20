package com.devamitkumartiwari.device_safety_info.features.batch

import android.content.Context
import com.devamitkumartiwari.device_safety_info.core.BackgroundRunner
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.requireContext
import com.devamitkumartiwari.device_safety_info.features.accessibility.AccessibilityAbuseDetector
import com.devamitkumartiwari.device_safety_info.features.app_integrity.SigningInfoReader
import com.devamitkumartiwari.device_safety_info.features.environment.CloneDetector
import com.devamitkumartiwari.device_safety_info.features.environment.KeyboardDetector
import com.devamitkumartiwari.device_safety_info.features.environment.MockLocationDetector
import com.devamitkumartiwari.device_safety_info.features.environment.RemoteAccessDetector
import com.devamitkumartiwari.device_safety_info.features.environment.UserCaDetector
import com.devamitkumartiwari.device_safety_info.features.emulator.RealDeviceCheck
import com.devamitkumartiwari.device_safety_info.features.hooking.HookDetector
import com.devamitkumartiwari.device_safety_info.features.malware.MalwarePackageDetector
import com.devamitkumartiwari.device_safety_info.features.notification_listener.NotificationListenerAbuseDetector
import com.devamitkumartiwari.device_safety_info.features.posture.PostureReports
import com.devamitkumartiwari.device_safety_info.features.root.RootedDeviceCheck
import com.devamitkumartiwari.device_safety_info.features.screen_protection.ScreenProtectionHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.screen_protection.ScreenRecordingMonitor
import com.devamitkumartiwari.device_safety_info.features.vpn.VpnReport
import com.devamitkumartiwari.device_safety_info.generated.AccessibilityServiceMsg
import com.devamitkumartiwari.device_safety_info.generated.BatchHostApi
import com.devamitkumartiwari.device_safety_info.generated.BatchRequestMsg
import com.devamitkumartiwari.device_safety_info.generated.BatchResultMsg
import com.devamitkumartiwari.device_safety_info.generated.CheckReportMsg
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope

/**
 * Runs many checks in one round trip. Each check runs in parallel on the shared background
 * pool, so the total time is about that of the slowest check. A check that throws is left out
 * of the result; Dart reports a missing check as CheckStatus.error (subject to its fail mode).
 */
class BatchHostApiImpl(
    private val host: PluginHost,
    private val bg: BackgroundRunner,
    private val recording: ScreenRecordingMonitor,
) : BatchHostApi {

    private val reporters: Map<String, (Context) -> RiskReport> = mapOf(
        "root" to { ctx -> RootedDeviceCheck.evaluate(ctx) },
        "emulator" to { ctx -> RealDeviceCheck.evaluate(ctx) },
        "hooking" to { _ -> HookDetector.hookReport() },
        "debugger" to { ctx -> HookDetector.debuggerReport(ctx) },
        "developerMode" to PostureReports::developerMode,
        "screenLock" to PostureReports::screenLock,
        "storeInstall" to PostureReports::storeInstall,
        "externalStorage" to PostureReports::externalStorage,
        "unknownSources" to PostureReports::unknownSources,
        "playProtect" to PostureReports::playProtect,
        "vpn" to VpnReport::evaluate,
        "remoteAccess" to RemoteAccessDetector::report,
        "locationSpoofing" to MockLocationDetector::report,
        "appCloning" to CloneDetector::report,
        "mitm" to UserCaDetector::report,
        "keyboard" to KeyboardDetector::report,
        "screenCapture" to { ctx -> ScreenProtectionHostApiImpl.captureReport(ctx, recording) },
    )

    override suspend fun runChecks(request: BatchRequestMsg): BatchResultMsg = coroutineScope {
        val ctx = host.requireContext()
        val ids = request.checkIds.toSet()

        val reports = ids.mapNotNull { id ->
            val reporter = reporters[id] ?: return@mapNotNull null
            async {
                try {
                    id to bg.run { reporter(ctx).toMsg() }
                } catch (_: Throwable) {
                    null
                }
            }
        }

        // A list that can't be read is reported in failedLists, never as an empty (clean) list.
        val failed = java.util.Collections.synchronizedList(mutableListOf<String>())
        suspend fun <T> list(id: String, block: () -> List<T>): List<T> = try {
            bg.run { block() }
        } catch (_: Throwable) {
            failed += id
            emptyList()
        }

        val accessibility = if ("accessibility" in ids) {
            async { list("accessibility") { AccessibilityAbuseDetector.enabledServices(ctx) } }
        } else {
            null
        }
        val listeners = if ("notificationListener" in ids) {
            async {
                list("notificationListener") {
                    NotificationListenerAbuseDetector.enabledListeners(ctx)
                }
            }
        } else {
            null
        }
        val installed = if ("malware" in ids && request.malwarePackages.isNotEmpty()) {
            async {
                list("malware") {
                    request.malwarePackages.filter { MalwarePackageDetector.isPackageInstalled(ctx, it) }
                }
            }
        } else {
            null
        }
        val signing = if ("tampering" in ids) {
            async {
                try {
                    bg.run { SigningInfoReader.read(ctx) }
                } catch (_: Throwable) {
                    null
                }
            }
        } else {
            null
        }

        val reportMap: Map<String, CheckReportMsg> = reports.awaitAll().filterNotNull().toMap()
        BatchResultMsg(
            reports = reportMap,
            accessibilityServices = accessibility?.await() ?: emptyList<AccessibilityServiceMsg>(),
            notificationListeners = listeners?.await() ?: emptyList(),
            installedPackages = installed?.await() ?: emptyList(),
            failedLists = failed.toList(),
            signing = signing?.await(),
        )
    }
}
