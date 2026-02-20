package com.devamitkumartiwari.device_safety_info.realdevice

import android.os.Build

/**
 * A utility to check if the app is running on a real device or an emulator.
 */
object RealDeviceCheck {

    /**
     * Determines if the current device is a physical device rather than an emulator.
     *
     * This check is based on inspecting various properties of the `android.os.Build` class
     * for tell-tale signs of an emulated environment. It also checks the hardware name,
     * which is a strong indicator.
     *
     * @return `true` if the device is believed to be real, `false` if it is likely an emulator.
     */
    fun isRealDevice(): Boolean {
        // Check for specific hardware names known to be used by emulators.
        val hardware = Build.HARDWARE.lowercase()
        if (hardware.contains("goldfish") || hardware.contains("ranchu")) {
            return false
        }

        // List of device properties to check for other emulator-related patterns.
        val buildProps = listOf(
            Build.FINGERPRINT,
            Build.MODEL,
            Build.MANUFACTURER,
            Build.DEVICE,
            Build.BRAND,
            Build.PRODUCT
        ).mapNotNull { it?.lowercase() }

        // A list of common patterns found in emulator properties.
        val emulatorIndicators = listOf(
            "generic", "unknown", "google_sdk", "sdk", "emulator",
            "android sdk built for x86", "genymotion", "vbox", "nox"
        )

        // Return true only if none of the properties contain an emulator indicator.
        return buildProps.none { prop ->
            emulatorIndicators.any { indicator -> prop.contains(indicator) }
        }
    }
}
