package com.devamitkumartiwari.device_safety_info.rooted

/**
 * A utility to check for the presence of common root-related commands.
 *
 * This checker attempts to execute commands like `which su` to see if the `su` binary
 * (or other root-associated binaries) exists in the system's PATH.
 */
object RootCommandsChecker {

    /**
     * Checks for the existence of common root-related command-line executables.
     *
     * @return `true` if any of the commands succeed (indicating the binary was found), `false` otherwise.
     */
    fun checkCommands(): Boolean {
        // A list of commands used to detect root by checking for common binaries.
        val commands = arrayOf(
            "which su",         // Superuser binary
            "which magisk",     // Magisk root manager
            "which busybox",    // A common multi-call binary used in rooted environments
            "which daemonsu"    // A daemon for managing superuser access
        )

        // Return true if any of the shell commands execute successfully.
        return commands.any { ShellExecutor.executeCommand(it) }
    }
}
