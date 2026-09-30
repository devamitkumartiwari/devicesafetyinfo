package com.devamitkumartiwari.device_safety_info.rooted

import java.io.File

/**
 * A utility to check for the presence of common root-related commands.
 *
 * This checker looks up binaries like `su` in every directory of the process's `PATH`,
 * the same lookup `which su` performs, but in-process: no subprocess is spawned, so there
 * are no stream-reader threads that can race the process being destroyed.
 */
object RootCommandsChecker {

    // Common binaries used to detect root.
    private val binaries = arrayOf(
        "su",         // Superuser binary
        "magisk",     // Magisk root manager
        "busybox",    // A common multi-call binary used in rooted environments
        "daemonsu"    // A daemon for managing superuser access
    )

    /**
     * Checks for the existence of common root-related command-line executables.
     *
     * @return `true` if any of the binaries is found in `PATH`, `false` otherwise.
     */
    fun checkCommands(): Boolean {
        return try {
            val dirs = (System.getenv("PATH") ?: return false)
                .split(':')
                .filter { it.isNotEmpty() }
            binaries.any { bin -> dirs.any { File(it, bin).exists() } }
        } catch (_: Exception) {
            false
        }
    }
}
