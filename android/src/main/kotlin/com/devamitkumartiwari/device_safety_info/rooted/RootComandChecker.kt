package com.devamitkumartiwari.device_safety_info.rooted

import com.devamitkumartiwari.device_safety_info.core.RiskSignal

import java.io.File

/**
 * A utility to check for the presence of common root-related commands.
 *
 * This checker looks up binaries like `su` in every directory of the process's `PATH`,
 * the same lookup `which su` performs, but in-process: no subprocess is spawned, so there
 * are no stream-reader threads that can race the process being destroyed.
 *
 * Like `which`, a binary only counts as high-risk when this app can execute it. A file that
 * merely exists (common for stock `su`/`busybox` on some Xiaomi, Redmi and Samsung ROMs) is
 * reported as low-risk. `busybox` is always low-risk: several OEMs ship it on stock firmware.
 */
object RootCommandsChecker {

    // Binaries that indicate root when executable.
    private val rootBinaries = arrayOf(
        "su",         // Superuser binary
        "magisk",     // Magisk root manager
        "daemonsu"    // A daemon for managing superuser access
    )

    // Binaries that are suspicious but ship on some stock ROMs — never high-risk.
    private val lowRiskBinaries = arrayOf(
        "busybox"     // Multi-call binary; shipped by some OEMs
    )

    fun signals(): List<RiskSignal> {
        val dirs = (System.getenv("PATH") ?: return emptyList())
            .split(':')
            .filter { it.isNotEmpty() }
            .distinct()
        val found = mutableListOf<RiskSignal>()
        for (dir in dirs) {
            for (bin in rootBinaries) {
                val f = File(dir, bin)
                if (f.isFile) found += RiskSignal("path:${f.path}", highRisk = f.canExecute())
            }
            for (bin in lowRiskBinaries) {
                val f = File(dir, bin)
                if (f.isFile) found += RiskSignal("path:${f.path}", highRisk = false)
            }
        }
        return found
    }

    /** Backward-compatible boolean: `true` if an executable root binary is in `PATH`. */
    fun checkCommands(): Boolean = try {
        signals().any { it.highRisk }
    } catch (_: Exception) {
        false
    }
}
