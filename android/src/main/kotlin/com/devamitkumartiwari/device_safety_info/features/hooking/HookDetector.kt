package com.devamitkumartiwari.device_safety_info.features.hooking

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Debug
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.generated.Signatures
import java.io.File

/**
 * JVM-side hooking and debugger checks. The harder-to-hook native checks (Frida in
 * /proc/self/maps, its threads, file descriptors and port, patched libc code, TracerPid) run in
 * C through FFI and are merged in Dart.
 */
object HookDetector {

    // Frida server binaries in system paths. (Copies in /data/local/tmp are invisible to apps on
    // Android 10+, so they aren't probed; the native thread, fd and port checks cover them.)
    private val fridaServerPaths get() = Signatures.fridaServerPaths

    fun hookReport(): RiskReport = hookReport(
        exists = { File(it).exists() },
        classLoadable = ::classLoadable,
        stackTrace = { Throwable().stackTrace.map { "${it.className}.${it.methodName}" } },
        maps = MemoryMapsScanner::scanSelf,
    )

    /** The detection logic with every probe injectable, for tests. */
    fun hookReport(
        exists: (String) -> Boolean,
        classLoadable: (String) -> Boolean,
        stackTrace: () -> List<String>,
        maps: () -> MemoryMapsScanner.Findings,
    ): RiskReport {
        val signals = mutableListOf<RiskSignal>()
        fridaServerPaths.firstOrNull(exists)?.let {
            signals += RiskSignal("hooking.frida_server:$it", highRisk = true)
        }
        // Hooking framework libraries installed system-wide (pre-Zygisk installs).
        Signatures.hookLibraries.firstOrNull { lib ->
            exists("/system/lib/$lib") || exists("/system/lib64/$lib")
        }?.let { signals += RiskSignal("hooking.system_library:$it", highRisk = true) }
        // Classes that exist in this process only when an Xposed-family framework loaded them.
        Signatures.xposedClasses.firstOrNull(classLoadable)?.let {
            signals += RiskSignal("hooking.xposed_class:$it", highRisk = true)
        }
        // A hooked method in the current call chain leaves the framework's bridge frames behind.
        val frames = stackTrace()
        Signatures.hookStackMarkers.firstOrNull { marker -> frames.any { it.contains(marker) } }?.let {
            signals += RiskSignal("hooking.stack_frame:$it", highRisk = true)
        }
        val found = maps()
        found.hookMarkers.forEach { signals += RiskSignal("hooking.framework_mapped:$it", highRisk = true) }
        found.rwxLibraries.forEach { signals += RiskSignal("hooking.rwx_library:$it", highRisk = false) }
        return RiskReport(signals.distinctBy { it.id })
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
