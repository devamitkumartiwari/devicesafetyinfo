package com.devamitkumartiwari.device_safety_info.realdevice

import android.os.Build

class RealDeviceCheck {

    companion object {

        fun isRealDevice(): Boolean {
            // List of device properties to check for emulator-related patterns
            val buildProps = listOf(
                Build.FINGERPRINT?.lowercase() ?: "",
                Build.MODEL?.lowercase() ?: "",
                Build.MANUFACTURER?.lowercase() ?: "",
                Build.DEVICE?.lowercase() ?: "",
                Build.BRAND?.lowercase() ?: "",
                Build.PRODUCT?.lowercase() ?: ""
            )

            // Emulator indicators
            val emulatorIndicators = listOf(
                "generic", "unknown", "google_sdk", "emulator",
                "android sdk built for x86", "genymotion", "sdk_", "sdk"
            )

            // Return true for real device (none of the properties should match emulator indicators)
            return buildProps.none { prop ->
                emulatorIndicators.any { indicator -> prop.contains(indicator) }
            }
        }
    }
}
