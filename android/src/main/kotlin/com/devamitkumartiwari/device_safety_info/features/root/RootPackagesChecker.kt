package com.devamitkumartiwari.device_safety_info.features.root

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.generated.Signatures

/**
 * Looks for installed root-manager apps (Magisk, KernelSU, APatch, SuperSU, LSPosed manager,
 * ...) and root-cloaking or app-patching tools. The plugin's manifest declares these packages in
 * `<queries>` so they're visible on Android 11+.
 *
 * Root managers are high-risk. Cloaking/patching tools are low-risk: they point to intent but
 * don't need root to be installed. Magisk can repackage itself under a random name, so finding
 * nothing is not proof.
 */
object RootPackagesChecker {

    fun signals(
        isInstalled: (String) -> Boolean,
        managers: List<String> = Signatures.rootManagerPackages,
        cloaks: List<String> = Signatures.rootCloakPackages,
    ): List<RiskSignal> =
        managers.filter(isInstalled).map { RiskSignal("root.manager_app:$it", highRisk = true) } +
            cloaks.filter(isInstalled).map { RiskSignal("root.cloak_app:$it", highRisk = false) }

    fun signals(context: Context): List<RiskSignal> {
        val pm = context.packageManager
        return signals(isInstalled = { pkg -> isInstalled(pm, pkg) })
    }

    private fun isInstalled(pm: PackageManager, pkg: String): Boolean = try {
        if (Build.VERSION.SDK_INT >= 33) {
            pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(pkg, 0)
        }
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }
}
