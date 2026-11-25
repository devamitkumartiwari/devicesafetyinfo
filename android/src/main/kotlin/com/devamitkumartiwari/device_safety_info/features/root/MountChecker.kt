package com.devamitkumartiwari.device_safety_info.features.root

import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.generated.Signatures
import java.io.File

/**
 * Looks for systemless-root mounts in this process's mount namespace (`/proc/self/mounts`):
 *  - a mount whose source is Magisk, KernelSU or APatch, or whose options point into
 *    `/data/adb` (module overlays) or `/debug_ramdisk`;
 *  - a system partition (`/`, `/system`, `/vendor`, ...) mounted read-write. This covers the
 *    "can write to a protected location" test: an app's own uid can't write there even on a
 *    rooted device, but a root tool remounting the partition read-write shows up here;
 *  - a tmpfs or overlay mounted *inside* a system partition (how modules replace binaries).
 *
 * Magisk's DenyList and Shamiko unmount these from processes they hide root from, so an empty
 * result is not proof. The C side runs the same check with direct syscalls.
 */
object MountChecker {

    private val whitespace = Regex("""\s+""")
    private val diskFs = setOf("ext4", "erofs", "f2fs", "squashfs", "overlay")
    private val overlayFs = setOf("tmpfs", "overlay")

    /** Signals for [lines] in `/proc/mounts` format: `source mountpoint fstype options ...`. */
    fun signals(
        lines: Sequence<String>,
        sources: List<String> = Signatures.mountSources,
        optionMarkers: List<String> = Signatures.mountOptionMarkers,
        protectedPoints: List<String> = Signatures.protectedMountPoints,
        protectedPrefixes: List<String> = Signatures.protectedMountPrefixes,
    ): List<RiskSignal> {
        val found = linkedSetOf<RiskSignal>()
        for (line in lines) {
            val parts = line.trim().split(whitespace)
            if (parts.size < 4) continue
            val (source, point, fs, options) = parts
            if (sources.any { source.equals(it, ignoreCase = true) } ||
                optionMarkers.any { options.contains(it) }
            ) {
                found += RiskSignal("root.mount_marker:$point", highRisk = true)
                continue
            }
            if (point in protectedPoints && fs in diskFs && options.split(',').first() == "rw") {
                found += RiskSignal("root.system_rw:$point", highRisk = true)
                continue
            }
            if (fs in overlayFs && protectedPrefixes.any { point.startsWith(it) }) {
                found += RiskSignal("root.system_overlay:$point", highRisk = true)
            }
        }
        return found.toList()
    }

    /** Reads this process's mounts; empty if they can't be read. */
    fun signals(): List<RiskSignal> = try {
        File("/proc/self/mounts").useLines { signals(it) }
    } catch (_: Exception) {
        emptyList()
    }
}
