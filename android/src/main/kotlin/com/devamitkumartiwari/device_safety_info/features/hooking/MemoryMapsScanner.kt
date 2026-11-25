package com.devamitkumartiwari.device_safety_info.features.hooking

import com.devamitkumartiwari.device_safety_info.generated.Signatures
import java.io.File

/**
 * Scans this process's memory map (`/proc/self/maps`) for two things:
 *  - native libraries mapped both writable and executable (`rwx`) from outside the system and
 *    the app's own install directory. Legitimate code is never mapped rwx; injected agents and
 *    some hooking frameworks are. A weak signal (some JIT-heavy SDKs do odd things).
 *  - mappings whose path names a hooking framework (LSPosed, EdXposed, Riru, Zygisk modules,
 *    Shamiko, SandHook, Substrate). Zygisk-era frameworks never install into `/system/lib`, so
 *    the memory map is where they show up.
 */
object MemoryMapsScanner {

    /** What one pass over the map found. */
    data class Findings(val rwxLibraries: Set<String>, val hookMarkers: Set<String>)

    private val trustedPrefixes = listOf(
        "/system/", "/apex/", "/vendor/", "/product/", "/system_ext/", "/odm/", "/data/app/",
    )

    private val whitespace = Regex("""\s+""")

    /** Scans [lines] (the contents of /proc/self/maps). */
    fun scan(
        lines: Sequence<String>,
        markers: List<String> = Signatures.hookMapMarkers,
    ): Findings {
        val rwx = linkedSetOf<String>()
        val hooks = linkedSetOf<String>()
        for (line in lines) {
            // address perms offset dev inode [path]
            val parts = line.trim().split(whitespace, limit = 6)
            if (parts.size < 6) continue
            val perms = parts[1]
            val path = parts[5]
            val lower = path.lowercase()
            markers.firstOrNull { lower.contains(it) }?.let { hooks += it }
            if (!perms.startsWith("rwx")) continue
            if (!path.startsWith("/") || !path.contains(".so")) continue
            if (trustedPrefixes.any { path.startsWith(it) }) continue
            rwx += path.substringAfterLast('/')
        }
        return Findings(rwx, hooks)
    }

    /** Names of suspicious rwx libraries in [lines]. */
    fun rwxLibraries(lines: Sequence<String>): Set<String> = scan(lines).rwxLibraries

    /** Scans this process; empty if /proc/self/maps can't be read. */
    fun scanSelf(): Findings = try {
        File("/proc/self/maps").useLines { scan(it) }
    } catch (_: Exception) {
        Findings(emptySet(), emptySet())
    }
}
