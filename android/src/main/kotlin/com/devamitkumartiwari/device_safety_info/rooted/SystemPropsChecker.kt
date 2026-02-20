package com.devamitkumartiwari.device_safety_info.rooted

/**
 * A utility to check for system properties that may indicate a rooted device.
 *
 * This object checks several `ro.` (read-only) properties that can reveal if the
 * device is running a non-standard or insecure build, which is common on rooted devices.
 */
object SystemPropsChecker {

    // A map where the key is the system property to check, and the value is a lambda
    // function that returns true if the property's value indicates a rooted state.
    private val propsToChecks: Map<String, (String) -> Boolean> = mapOf(
        // "test-keys" is often found on custom ROMs and rooted devices.
        "ro.build.tags" to { it.contains("test-keys") },
        // A value of "1" means USB debugging is enabled, which is common on rooted devices.
        "ro.debuggable" to { it == "1" },
        // A value of "0" means the device is not running in a secure mode.
        "ro.secure" to { it == "0" },
        // Booting into recovery or fastboot can be part of the rooting process.
        "ro.bootmode" to { it == "recovery" || it == "fastboot" },
        // An "orange" or "yellow" state indicates that the bootloader is unlocked.
        "ro.boot.verifiedbootstate" to { it == "orange" || it == "yellow" }
    )

    /**
     * Checks for system properties that indicate the device might be rooted.
     *
     * @return `true` if any of the properties match a known root indicator, `false` otherwise.
     */
    fun checkSystemProps(): Boolean {
        return propsToChecks.any { (prop, check) ->
            val value = ShellExecutor.getSystemProperty(prop)
            value != null && check(value)
        }
    }
}
