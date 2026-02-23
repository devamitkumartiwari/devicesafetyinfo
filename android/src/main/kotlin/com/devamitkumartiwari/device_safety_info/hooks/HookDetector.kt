package com.devamitkumartiwari.device_safety_info.hooks

import java.io.File

/**
 * A utility to detect the presence of common hooking frameworks on the device.
 *
 * Hooking frameworks like Frida, Xposed, and Substrate can be used to tamper with
 * an application's runtime behavior, which can be a security risk. This object
 * provides methods to check for signs of these frameworks.
 */
object HookDetector {

    /**
     * Runs all available checks for hooking frameworks.
     *
     * @return `true` if any hooking framework is detected, `false` otherwise.
     */
    fun check(): Boolean {
        return isFridaPresent() || isShadowPresent() || isXposedPresent() || isSubstratePresent() || isFreedaPresent()
    }

    /**
     * Checks for the presence of the Frida instrumentation toolkit.
     * It looks for the `frida-server` executable in common locations.
     */
    private fun isFridaPresent(): Boolean {
        val paths = arrayOf(
            "/data/local/tmp/frida-server",
            "/system/bin/frida-server",
            "/system/xbin/frida-server",
            "/data/local/tmp/re.frida.server"
        )
        return paths.any { File(it).exists() }
    }

    /**
     * Checks for the presence of the Shadow hooking framework.
     * It looks for common Shadow library files.
     */
    private fun isShadowPresent(): Boolean {
        val hookingLibs = arrayOf("libshadowhook.so", "libshadow.so")
        return checkForLibraries(hookingLibs)
    }

    /**
     * Checks for the presence of the Xposed framework.
     * It looks for common Xposed library files.
     */
    private fun isXposedPresent(): Boolean {
        val hookingLibs = arrayOf("libxposed.so", "libedxposed.so")
        return checkForLibraries(hookingLibs)
    }

    /**
     * Checks for the presence of the Cydia Substrate framework.
     * It looks for common Substrate library files.
     */
    private fun isSubstratePresent(): Boolean {
        val hookingLibs = arrayOf("libsubstrate.so", "libsubstrate-dvm.so")
        return checkForLibraries(hookingLibs)
    }

    /**
     * Checks for the presence of the Freeda toolkit (a Frida variant).
     * It looks for the `freeda-server` executable in common locations.
     */
    private fun isFreedaPresent(): Boolean {
        val paths = arrayOf(
            "/data/local/tmp/freeda-server",
            "/system/bin/freeda-server",
            "/system/xbin/freeda-server"
        )
        return paths.any { File(it).exists() }
    }

    /**
     * A helper function to check for the existence of specific shared libraries
     * in the standard system library directories.
     *
     * @param libs An array of library filenames to search for.
     * @return `true` if any of the specified libraries are found, `false` otherwise.
     */
    private fun checkForLibraries(libs: Array<String>): Boolean {
        return libs.any { lib ->
            File("/system/lib/$lib").exists() || File("/system/lib64/$lib").exists()
        }
    }
}
