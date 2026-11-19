package com.devamitkumartiwari.device_safety_info.features.emulator

import android.os.Build
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal

/**
 * A utility to check if the app is running on a real device or an emulator.
 *
 * Signals are tiered like root detection:
 *  - **High-risk** — evidence that only emulators produce: emulator hardware (`goldfish`,
 *    `ranchu`, `vbox86`, `nox`), `ro.kernel.qemu=1` / `ro.boot.qemu=1`, SDK/emulator product
 *    or model names (`sdk_gphone`, `google_sdk`, `Android SDK built for x86`, `Emulator`),
 *    Genymotion, or the classic `generic` brand **and** `generic` device pair.
 *  - **Low-risk** — words that also appear on real budget phones and generic-system-image ROMs:
 *    `unknown`, `generic` or `nox` inside a single build field.
 *
 * Only high-risk signals mean "emulator" under the standard policy.
 */
object RealDeviceCheck {

    // Build.HARDWARE values used only by emulators.
    private val emulatorHardware = listOf("goldfish", "ranchu", "vbox86", "nox")

    // Substrings that only emulator images put in MODEL / PRODUCT / FINGERPRINT.
    private val emulatorNames = listOf(
        "sdk_gphone", "google_sdk", "android sdk built for x86", "emulator",
        "vbox86p", "genymotion", "sdk_google",
    )

    // Words that emulators use but some real devices/ROMs also report.
    private val weakWords = listOf("unknown", "generic", "nox")

    /** Runs every emulator check and returns all indicators found. */
    fun evaluate(): RiskReport {
        val signals = mutableListOf<RiskSignal>()

        // --- High-risk: hardware
        val hardware = Build.HARDWARE.orEmpty().lowercase()
        if (emulatorHardware.any { hardware.contains(it) }) {
            signals += RiskSignal("emulator.hardware:$hardware", highRisk = true)
        }

        // --- High-risk: QEMU kernel properties (set by every Android emulator image)
        for (prop in listOf("ro.kernel.qemu", "ro.boot.qemu")) {
            if (systemProperty(prop) == "1") signals += RiskSignal("emulator.qemu:$prop", highRisk = true)
        }

        val fields = linkedMapOf(
            "fingerprint" to Build.FINGERPRINT,
            "model" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
        ).mapValues { it.value.orEmpty().lowercase() }

        // --- High-risk: emulator-only names
        val highFields = mutableSetOf<String>()
        for ((name, value) in fields) {
            if (emulatorNames.any { value.contains(it) }) {
                signals += RiskSignal("emulator.build_name:$name", highRisk = true)
                highFields += name
            }
        }
        if (fields["fingerprint"]!!.startsWith("generic")) {
            signals += RiskSignal("emulator.generic_fingerprint", highRisk = true)
            highFields += "fingerprint"
        }
        if (fields["brand"]!!.startsWith("generic") && fields["device"]!!.startsWith("generic")) {
            signals += RiskSignal("emulator.generic_brand_device", highRisk = true)
            highFields += "brand"
            highFields += "device"
        }

        // --- Low-risk: weak words in a field not already reported as high-risk
        for ((name, value) in fields) {
            if (name !in highFields && weakWords.any { value.contains(it) }) {
                signals += RiskSignal("emulator.generic_build:$name", highRisk = false)
            }
        }

        return RiskReport(signals.distinctBy { it.id })
    }

    // Reflection-only read of android.os.SystemProperties: cheap and safe on the main thread
    // (no getprop subprocess). Returns null if reflection is unavailable.
    private fun systemProperty(name: String): String? = try {
        Class.forName("android.os.SystemProperties")
            .getMethod("get", String::class.java, String::class.java)
            .invoke(null, name, "") as? String
    } catch (_: Exception) {
        null
    }
}
