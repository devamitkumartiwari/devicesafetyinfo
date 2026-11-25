package com.devamitkumartiwari.device_safety_info.features.root

import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.core.SystemProps

/**
 * Checks system properties that indicate an insecure or modified build.
 *
 * High-risk: values a locked, stock retail build never has (`ro.secure=0`, adbd running as root,
 * SELinux permissive, LineageOS app root access, or `ro.debuggable=1` on a `user` build, an
 * inconsistency left by `resetprop` or a patched boot image). Everything else also occurs on
 * unrooted devices (an unlocked bootloader, OEM firmware signed with `test-keys`, developer
 * builds) and is low-risk.
 */
object SystemPropsChecker {

    private class PropCheck(
        val id: String,
        val prop: String,
        val highRisk: Boolean,
        val matches: (String) -> Boolean,
    )

    private val propChecks = listOf(
        // adbd runs as root.
        PropCheck("root.ro_secure_off", "ro.secure", highRisk = true) { it == "0" },
        PropCheck("root.adb_root", "service.adb.root", highRisk = true) { it == "1" },
        // SELinux not enforcing: required by many root tools, never set on retail builds.
        PropCheck("root.selinux_permissive", "ro.boot.selinux", highRisk = true) { it == "permissive" },
        PropCheck("root.selinux_disabled", "ro.build.selinux", highRisk = true) { it == "0" },
        // LineageOS "Root access" developer option: 1 = apps, 3 = apps and ADB.
        PropCheck("root.lineage_root_access", "persist.sys.root_access", highRisk = true) {
            it == "1" || it == "3"
        },
        // "test-keys" is common on custom ROMs, but some OEM/MediaTek stock builds use it too.
        PropCheck("root.test_keys", "ro.build.tags", highRisk = false) { it.contains("test-keys") },
        // eng/userdebug builds are for development; retail devices ship "user".
        PropCheck("root.debug_build", "ro.build.type", highRisk = false) { it == "eng" || it == "userdebug" },
        // Booting into recovery or fastboot can be part of the rooting process.
        PropCheck("root.recovery_boot", "ro.bootmode", highRisk = false) { it == "recovery" || it == "fastboot" },
        // "orange" = unlocked bootloader, "yellow" = custom verified-boot key. Neither means root.
        PropCheck("root.verifiedboot_unlocked", "ro.boot.verifiedbootstate", highRisk = false) {
            it == "orange" || it == "yellow"
        },
        PropCheck("root.bootloader_unlocked", "ro.boot.vbmeta.device_state", highRisk = false) { it == "unlocked" },
        PropCheck("root.mock_location_allowed", "ro.allow.mock.location", highRisk = false) { it == "1" },
    )

    /** [property] reads a system property; injectable for tests. */
    fun signals(
        property: (String) -> String? = SystemProps::get,
    ): List<RiskSignal> {
        val found = propChecks.mapNotNullTo(mutableListOf()) { check ->
            val value = property(check.prop)
            if (value != null && check.matches(value)) RiskSignal("${check.id}:$value", check.highRisk) else null
        }
        // ro.debuggable=1 is normal on eng/userdebug builds, but a "user" build never sets it.
        // (ro.debuggable alone is intentionally not checked: it's "1" on every debug build.)
        if (property("ro.debuggable") == "1" && property("ro.build.type") == "user") {
            found += RiskSignal("root.debuggable_user_build", highRisk = true)
        }
        return found
    }
}
