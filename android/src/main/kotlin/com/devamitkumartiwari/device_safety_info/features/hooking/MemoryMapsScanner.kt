package com.devamitkumartiwari.device_safety_info.features.hooking

import java.io.File

/**
 * Finds native libraries mapped both writable and executable (`rwx`) from outside the system
 * and the app's own install directory. Legitimate code is never mapped rwx; injected agents and
 * some hooking frameworks are. It is a weak signal (some JIT-heavy SDKs do odd things), so it's
 * reported as low risk.
 */
object MemoryMapsScanner {

    private val trustedPrefixes = listOf(
        "/system/", "/apex/", "/vendor/", "/product/", "/system_ext/", "/odm/", "/data/app/",
    )

    private val whitespace = Regex("""\s+""")

    /** Names of suspicious libraries in [lines] (the contents of /proc/self/maps). */
    fun rwxLibraries(lines: Sequence<String>): Set<String> {
        val found = linkedSetOf<String>()
        for (line in lines) {
            // address perms offset dev inode [path]
            val parts = line.trim().split(whitespace, limit = 6)
            if (parts.size < 6) continue
            val perms = parts[1]
            val path = parts[5]
            if (!perms.startsWith("rwx")) continue
            if (!path.startsWith("/") || !path.contains(".so")) continue
            if (trustedPrefixes.any { path.startsWith(it) }) continue
            found += path.substringAfterLast('/')
        }
        return found
    }

    /** Scans this process; empty if /proc/self/maps can't be read. */
    fun scanSelf(): Set<String> = try {
        File("/proc/self/maps").useLines { rwxLibraries(it) }
    } catch (_: Exception) {
        emptySet()
    }
}
