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
import com.devamitkumartiwari.device_safety_info.rooted.RootedDeviceCheck
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executors
import kotlin.system.exitProcess

/**
 * `isRootedDevice` / `isHooked` / `isDebuggerAttached`. Owns the 30s TTL caches for the two
 * expensive shell-spawning checks plus the background thread pool they run on, and the shared
 * exit/uninstall-on-detection helper both checks use.
 */
class RootDetectionFeature(private val host: PluginHost) : FeatureMethodHandler, Disposable {

    override val methods = setOf("isRootedDevice", "isHooked", "isDebuggerAttached")

    // Background thread pool for checks that spawn shell processes (isRootedDevice,
    // isHooked). Two threads is enough for the two checks that can be in-flight
    // simultaneously. Delivering results on mainHandler satisfies Flutter's threading contract.
    private val bgExecutor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

    // 30-second TTL cache for expensive security checks. Security state doesn't change
    // mid-session on real devices; the short TTL still catches dynamic Frida attachment.
    @Volatile private var cachedRooted: Pair<Boolean, Long>? = null
    @Volatile private var cachedHooked: Pair<Boolean, Long>? = null
    private val cacheTtlMs = 30_000L

    override fun handle(call: MethodCall, result: Result) {
        val exitIfTrue = call.argument<Boolean>("exitProcessIfTrue") ?: false
        val uninstallIfTrue = call.argument<Boolean>("uninstallIfTrue") ?: false

        when (call.method) {
            "isDebuggerAttached" -> result.success(Debug.isDebuggerConnected())
            "isRootedDevice" -> {
                val now = System.currentTimeMillis()
                val cached = cachedRooted
                if (cached != null && (now - cached.second) < cacheTtlMs) {
                    result.success(cached.first)
                    if (cached.first) handleExitOrUninstall(exitIfTrue, uninstallIfTrue)
                    return
                }
                bgExecutor.execute {
                    val isRooted = RootedDeviceCheck.isRootedDevice()
                    cachedRooted = Pair(isRooted, System.currentTimeMillis())
                    mainHandler.post {
                        result.success(isRooted)
                        if (isRooted) handleExitOrUninstall(exitIfTrue, uninstallIfTrue)
                    }
                }
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
                    val isHooked = HookDetector.check()
                    cachedHooked = Pair(isHooked, System.currentTimeMillis())
                    mainHandler.post {
                        result.success(isHooked)
                        if (isHooked) handleExitOrUninstall(exitIfTrue, uninstallIfTrue)
                    }
                }
            }
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
        cachedRooted = null
        cachedHooked = null
        bgExecutor.shutdown()
    }
}
