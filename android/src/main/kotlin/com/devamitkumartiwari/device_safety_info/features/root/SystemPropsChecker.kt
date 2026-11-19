package com.devamitkumartiwari.device_safety_info.features.root

import com.devamitkumartiwari.device_safety_info.core.RiskSignal

/**
 * A utility to check for system properties that may indicate a rooted device.
 *
 * Only `ro.secure=0` is high-risk. The rest also occur on unrooted devices — an unlocked
 * bootloader (`orange`/`yellow` verified-boot state), OEM firmware signed with `test-keys`,
 * or an odd `ro.bootmode` — so they are reported as low-risk.
 */
object SystemPropsChecker {

    private class PropCheck(
        val id: String,
        val prop: String,
        val highRisk: Boolean,
        val matches: (String) -> Boolean,
    )

    private val propChecks = listOf(
        // A value of "0" means the device is not running in a secure mode (adbd runs as root).
        PropCheck("root.ro_secure_off", "ro.secure", highRisk = true) { it == "0" },
        // "test-keys" is common on custom ROMs, but some OEM/MediaTek stock builds use it too.
        // ro.debuggable is intentionally not checked: "1" appears on all standard debug builds.
        PropCheck("root.test_keys", "ro.build.tags", highRisk = false) { it.contains("test-keys") },
        // Booting into recovery or fastboot can be part of the rooting process.
        PropCheck("root.recovery_boot", "ro.bootmode", highRisk = false) { it == "recovery" || it == "fastboot" },
        // "orange" = unlocked bootloader, "yellow" = custom verified-boot key. Neither means root.
        PropCheck("root.verifiedboot_unlocked", "ro.boot.verifiedbootstate", highRisk = false) { it == "orange" || it == "yellow" },
    )

    fun signals(): List<RiskSignal> = propChecks.mapNotNull { check ->
        val value = ShellExecutor.getSystemProperty(check.prop)
        if (value != null && check.matches(value)) {
            RiskSignal("${check.id}:$value", check.highRisk)
        } else {
            null
        }
    }

    /** Backward-compatible boolean: `true` if a high-risk property matched. */
}
