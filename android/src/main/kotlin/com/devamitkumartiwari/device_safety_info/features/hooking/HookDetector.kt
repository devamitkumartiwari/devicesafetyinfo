package com.devamitkumartiwari.device_safety_info.features.hooking

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Debug
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import java.io.File

/**
 * JVM-side hooking and debugger checks. The harder-to-hook native checks (Frida in
 * /proc/self/maps, Frida's port, TracerPid) run in C through FFI and are merged in Dart.
 */
object HookDetector {

    private val fridaServerPaths = listOf(
        "/data/local/tmp/frida-server",
        "/data/local/tmp/re.frida.server",
        "/system/bin/frida-server",
        "/system/xbin/frida-server",
    )

    private val freedaServerPaths = listOf(
        "/data/local/tmp/freeda-server",
        "/system/bin/freeda-server",
        "/system/xbin/freeda-server",
    )

    // Hooking framework libraries installed system-wide.
    private val hookLibraries = mapOf(
        "hooking.shadowhook" to listOf("libshadowhook.so", "libshadow.so"),
        "hooking.xposed" to listOf("libxposed.so", "libedxposed.so", "liblspd.so"),
        "hooking.substrate" to listOf("libsubstrate.so", "libsubstrate-dvm.so"),
    )

    // Classes that exist in the app's process only when an Xposed-family framework loaded it.
    private val xposedClasses = listOf(
        "de.robv.android.xposed.XposedBridge",
        "de.robv.android.xposed.XposedHelpers",
        "org.lsposed.lspd.core.Main",
    )

    fun hookReport(): RiskReport {
        val signals = mutableListOf<RiskSignal>()
        fridaServerPaths.firstOrNull { File(it).exists() }?.let {
            signals += RiskSignal("hooking.frida_server:$it", highRisk = true)
        }
        freedaServerPaths.firstOrNull { File(it).exists() }?.let {
            signals += RiskSignal("hooking.freeda_server:$it", highRisk = true)
        }
        for ((id, libs) in hookLibraries) {
            val found = libs.firstOrNull { lib ->
                File("/system/lib/$lib").exists() || File("/system/lib64/$lib").exists()
            }
            if (found != null) signals += RiskSignal("$id:$found", highRisk = true)
        }
        xposedClasses.firstOrNull { classLoadable(it) }?.let {
            signals += RiskSignal("hooking.xposed_class:$it", highRisk = true)
        }
        return RiskReport(signals)
    }

    fun debuggerReport(context: Context?): RiskReport {
        val signals = mutableListOf<RiskSignal>()
        if (Debug.isDebuggerConnected() || Debug.waitingForDebugger()) {
            signals += RiskSignal("debugger.attached", highRisk = true)
        }
        val flags = context?.applicationInfo?.flags ?: 0
        if (flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            signals += RiskSignal("debugger.debuggable_build", highRisk = false)
        }
        return RiskReport(signals)
    }

    private fun classLoadable(name: String): Boolean = try {
        Class.forName(name, false, ClassLoader.getSystemClassLoader())
        true
    } catch (_: Throwable) {
        try {
            Class.forName(name, false, HookDetector::class.java.classLoader)
            true
        } catch (_: Throwable) {
            false
        }
    }
}
