package com.devamitkumartiwari.device_safety_info.rootdetection

import android.content.Intent
import android.net.Uri
import android.os.Debug
import android.os.Handler
import android.os.Looper
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.hooks.HookDetector
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.rooted.RootedDeviceCheck
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executors
import kotlin.system.exitProcess

/**
 * `isRootedDevice` / `rootCheck` / `isHooked` / `isDebuggerAttached`. Owns the 30s TTL caches for the two
 * expensive shell-spawning checks plus the background thread pool they run on, and the shared
 * exit/uninstall-on-detection helper both checks use.
 */
class RootDetectionFeature(private val host: PluginHost) : FeatureMethodHandler, Disposable {

    override val methods = setOf("isRootedDevice", "rootCheck", "isHooked", "isDebuggerAttached")

    // Background thread pool for checks that spawn shell processes (isRootedDevice,
    // isHooked). Two threads is enough for the two checks that can be in-flight
    // simultaneously. Delivering results on mainHandler satisfies Flutter's threading contract.
    private val bgExecutor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

    // 30-second TTL cache for expensive security checks. Security state doesn't change
    // mid-session on real devices; the short TTL still catches dynamic Frida attachment.
    @Volatile private var cachedRootReport: Pair<RiskReport, Long>? = null
    @Volatile private var cachedHooked: Pair<Boolean, Long>? = null
    private val cacheTtlMs = 30_000L

    override fun handle(call: MethodCall, result: Result) {
        val exitIfTrue = call.argument<Boolean>("exitProcessIfTrue") ?: false
        val uninstallIfTrue = call.argument<Boolean>("uninstallIfTrue") ?: false

        when (call.method) {
            "isDebuggerAttached" -> result.success(Debug.isDebuggerConnected())
            "isRootedDevice" -> withRootReport { report ->
                // Only high-risk indicators count as rooted; see RootedDeviceCheck.
                result.success(report.isHighRisk)
                if (report.isHighRisk) handleExitOrUninstall(exitIfTrue, uninstallIfTrue)
            }
            "rootCheck" -> withRootReport { report ->
                result.success(report.toMap())
                if (report.isHighRisk) handleExitOrUninstall(exitIfTrue, uninstallIfTrue)
            }
            "isHooked" -> {
                val now = System.currentTimeMillis()
                val cached = cachedHooked
                if (cached != null && (now - cached.second) < cacheTtlMs) {
                    result.success(cached.first)
                    if (cached.first) handleExitOrUninstall(exitIfTrue, uninstallIfTrue)
                    return
                }
                bgExecutor.execute {
                    val isHooked = try {
                        HookDetector.check().also {
                            cachedHooked = Pair(it, System.currentTimeMillis())
                        }
                    } catch (_: Exception) {
                        false
                    }
                    mainHandler.post {
                        result.success(isHooked)
                        if (isHooked) handleExitOrUninstall(exitIfTrue, uninstallIfTrue)
                    }
                }
            }
        }
    }

    /**
     * Delivers the (30s-cached) root report on the main thread. The evaluation runs on the
     * background pool; a checker failure yields an empty report rather than crashing the app or
     * leaving the Dart Future pending, and failed evaluations are not cached.
     */
    private fun withRootReport(onResult: (RiskReport) -> Unit) {
        val cached = cachedRootReport
        if (cached != null && (System.currentTimeMillis() - cached.second) < cacheTtlMs) {
            onResult(cached.first)
            return
        }
        bgExecutor.execute {
            val report = try {
                RootedDeviceCheck.evaluate().also {
                    cachedRootReport = Pair(it, System.currentTimeMillis())
                }
            } catch (_: Exception) {
                RiskReport.EMPTY
            }
            mainHandler.post { onResult(report) }
        }
    }

    private fun handleExitOrUninstall(exitProcessIfTrue: Boolean, uninstallIfTrue: Boolean) {
        if (uninstallIfTrue) {
            launchUninstallIntent()
        } else if (exitProcessIfTrue) {
            host.activity?.finishAffinity()
            exitProcess(0)
        }
    }

    private fun launchUninstallIntent() {
        try {
            val packageName = host.context?.packageName ?: return
            host.context?.startActivity(Intent(Intent.ACTION_DELETE).apply {
                data = Uri.parse("package:$packageName")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            })
        } catch (_: Exception) {}
    }

    override fun dispose() {
        cachedRootReport = null
        cachedHooked = null
        bgExecutor.shutdown()
    }
}
