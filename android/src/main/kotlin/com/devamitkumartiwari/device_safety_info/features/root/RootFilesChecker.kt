package com.devamitkumartiwari.device_safety_info.features.root

import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.generated.Signatures
import java.io.File

/**
 * Checks for root-related files: `su` binaries, and Magisk, KernelSU, APatch, SuperSU and
 * Superuser artifacts. The same lists (from `tool/signatures.json`) are checked again in C.
 *
 * `su` paths are high-risk only when this app can actually execute them: some stock OEM ROMs
 * leave a non-executable `su` behind, which is reported as low-risk instead. Root-manager
 * artifacts never ship on stock firmware, so their mere presence is high-risk. Most `/data/adb`
 * paths are hidden from apps by SELinux; they're checked for devices where the policy is loose.
 */
object RootFilesChecker {

    /** [exists] and [canExecute] probe a path; everything is injectable for tests. */
    fun signals(
        exists: (String) -> Boolean = { File(it).exists() },
        canExecute: (String) -> Boolean = { File(it).canExecute() },
        suPaths: List<String> = Signatures.suPaths,
        rootManagerPaths: List<String> = Signatures.rootManagerPaths,
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
