package com.devamitkumartiwari.device_safety_info.features.environment

import android.content.Context
import android.os.Build
import android.os.UserManager
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.features.malware.MalwarePackageDetector
import com.devamitkumartiwari.device_safety_info.generated.Signatures

/**
 * Whether this app runs in a cloned or dual-app space.
 *
 * High risk: the app's data lives inside another app's data directory, which is how virtual
 * containers (Parallel Space, VirtualXposed, App Cloner hosts) run apps. Low risk: running as a
 * secondary user (Samsung Dual Messenger, Xiaomi Second Space, Secure Folder), in a work
 * profile, or with a cloner app installed.
 */
object CloneDetector {

    fun report(context: Context): RiskReport {
        val signals = classify(context.applicationInfo.dataDir.orEmpty(), context.packageName)
            .toMutableList()
        if (Build.VERSION.SDK_INT >= 30) {
            val um = context.getSystemService(Context.USER_SERVICE) as? UserManager
            if (um?.isManagedProfile == true) signals += RiskSignal("clone.work_profile", highRisk = false)
        }
        Signatures.clonerPackages.filter { MalwarePackageDetector.isPackageInstalled(context, it) }
            .forEach { signals += RiskSignal("clone.cloner_installed:$it", highRisk = false) }
        return RiskReport(signals.distinctBy { it.id })
    }

    // /data/data/<pkg>, /data/user/<n>/<pkg>, /data/user_de/<n>/<pkg> and adoptable storage
    // /mnt/expand/<uuid>/user/<n>/<pkg>, each optionally followed by more path.
    private val legacy = Regex("""^/data/data/([^/]+)(/.*)?$""")
    private val perUser = Regex("""^(?:/mnt/expand/[^/]+)?/data/(?:user|user_de)/(\d+)/([^/]+)(/.*)?$""")
    private val adoptable = Regex("""^/mnt/expand/[^/]+/user/(\d+)/([^/]+)(/.*)?$""")

    /** Signals for a data directory, given this app's [ownPackage]. Pure, for tests. */
    fun classify(dataDir: String, ownPackage: String): List<RiskSignal> {
        val (user, host, rest) = legacy.find(dataDir)?.let { Triple(0, it.groupValues[1], it.groupValues[2]) }
            ?: (perUser.find(dataDir) ?: adoptable.find(dataDir))?.let {
                Triple(it.groupValues[1].toIntOrNull() ?: 0, it.groupValues[2], it.groupValues[3])
            }
            ?: return listOf(RiskSignal("clone.virtual_container:unknown_path", highRisk = true))
        val signals = mutableListOf<RiskSignal>()
        if (host != ownPackage || rest.isNotEmpty()) {
            signals += RiskSignal("clone.virtual_container:$host", highRisk = true)
        }
        if (user != 0) signals += RiskSignal("clone.secondary_user", highRisk = false)
        return signals
    }
}
