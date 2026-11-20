package com.devamitkumartiwari.device_safety_info.features.root

import com.devamitkumartiwari.device_safety_info.core.RiskSignal

import java.io.File

/**
 * A utility to check for the presence of common root-related files.
 *
 * `su` paths are high-risk only when this app can actually execute them: some stock OEM ROMs
 * leave a non-executable `su` behind, which is reported as low-risk instead. Magisk, SuperSU and
 * Superuser artifacts never ship on stock firmware, so their mere presence is high-risk.
 */
object RootFilesChecker {

    // `su` binary locations — high-risk only if executable by this app.
    private val suPaths = listOf(
        "/system/xbin/su",
        "/system/bin/su",
        "/sbin/su",
        "/system/su",
        "/data/local/xbin/su",
        "/data/local/bin/su",
        "/system/bin/.ext/.su",
        "/system/sd/xbin/su",
    )

    // Root-manager artifacts — high-risk whenever present.
    private val rootManagerPaths = listOf(
        "/system/app/Superuser.apk",
        "/system/etc/init.d/99SuperSUDaemon",
        "/system/xbin/daemonsu",
        "/system/bin/magisk",
        "/sbin/.magisk",
        "/sbin/magisk",
        "/data/adb/magisk",
        "/data/local/tmp/magisk",
        "/system/bin/magiskhide",
        "/sbin/magiskhide",
        "/data/local/tmp/magiskhide",
    )

    /** [exists] and [canExecute] probe a path; injectable for tests. */
    fun signals(
        exists: (String) -> Boolean = { File(it).exists() },
        canExecute: (String) -> Boolean = { File(it).canExecute() },
    ): List<RiskSignal> {
        val found = mutableListOf<RiskSignal>()
        for (path in suPaths) {
            if (exists(path)) {
                val exec = canExecute(path)
                found += RiskSignal(if (exec) "root.su_executable:$path" else "root.su_present:$path", exec)
            }
        }
        for (path in rootManagerPaths) {
            if (exists(path)) found += RiskSignal("root.manager_file:$path", highRisk = true)
        }
        return found
    }
}
