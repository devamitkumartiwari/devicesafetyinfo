package com.devamitkumartiwari.device_safety_info.features.root

import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.generated.Signatures
import java.io.File

/**
 * Looks up root binaries (`su`, `magisk`, KernelSU's `ksud`, APatch's `apd`, `resetprop`, ...)
 * in every directory of the process's `PATH`: the lookup `which su` performs, but in-process,
 * so no subprocess is spawned.
 *
 * Like `which`, a binary only counts as high-risk when this app can execute it. A file that
 * merely exists (common for stock `su`/`busybox` on some Xiaomi, Redmi and Samsung ROMs) is
 * reported as low-risk. `busybox` is always low-risk: several OEMs ship it on stock firmware.
 */
object RootCommandsChecker {

    /** All inputs are injectable for tests. */
    fun signals(
        path: String? = System.getenv("PATH"),
        isFile: (File) -> Boolean = { it.isFile },
        canExecute: (File) -> Boolean = { it.canExecute() },
        rootBinaries: List<String> = Signatures.rootBinaries,
        lowRiskBinaries: List<String> = Signatures.lowRiskBinaries,
    ): List<RiskSignal> {
        val dirs = (path ?: return emptyList())
            .split(':')
            .filter { it.isNotEmpty() }
            .distinct()
        val found = mutableListOf<RiskSignal>()
        for (dir in dirs) {
            for (bin in rootBinaries) {
                val f = File(dir, bin)
                if (isFile(f)) {
                    val exec = canExecute(f)
                    found += RiskSignal(
                        if (exec) "root.binary_executable:${f.path}" else "root.binary_present:${f.path}",
                        exec,
                    )
                }
            }
            for (bin in lowRiskBinaries) {
                val f = File(dir, bin)
                if (isFile(f)) found += RiskSignal("root.busybox:${f.path}", highRisk = false)
            }
        }
        return found
    }
}
