package com.devamitkumartiwari.device_safety_info.rooted

import java.io.File

/**
 * A utility to check for the presence of common root-related files.
 *
 * This object checks a predefined list of paths where `su` binaries, Superuser applications,
 * and Magisk files are commonly found. The existence of any of these files is a strong
 * indicator that the device is rooted.
 */
object RootFilesChecker {

    /**
     * Checks for the existence of `su` and other root-related files.
     *
     * @return `true` if any of the predefined file paths exist, `false` otherwise.
     */
    fun checkSuFiles(): Boolean {
        // A comprehensive list of paths where root-related files and binaries are commonly located.
        // Using a Set to ensure there are no duplicate path checks.
        val paths = setOf(
            // Standard `su` binary locations
            "/system/xbin/su",
            "/system/bin/su",
            "/sbin/su",
            "/system/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",

            // Superuser application
            "/system/app/Superuser.apk",

            // Less common or alternative `su` locations
            "/system/bin/.ext/.su",
            "/system/sd/xbin/su",

            // Daemonsu locations (for older root methods)
            "/system/etc/init.d/99SuperSUDaemon",
            "/system/xbin/daemonsu",

            // Magisk-related paths
            "/system/bin/magisk",
            "/sbin/.magisk",
            "/sbin/magisk",
            "/data/adb/magisk",
            "/data/local/tmp/magisk",

            // Magisk Hide paths
            "/system/bin/magiskhide",
            "/sbin/magiskhide",
            "/data/local/tmp/magiskhide"
        )

        return paths.any { File(it).exists() }
    }
}
