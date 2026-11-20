package com.devamitkumartiwari.device_safety_info.features.emulator

import android.os.Build
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.core.SystemProps

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

    /** Runs every emulator check against this device and returns all indicators found. */
    fun evaluate(): RiskReport = evaluate(
        hardware = Build.HARDWARE.orEmpty(),
        buildFields = linkedMapOf(
            "fingerprint" to Build.FINGERPRINT.orEmpty(),
            "model" to Build.MODEL.orEmpty(),
            "manufacturer" to Build.MANUFACTURER.orEmpty(),
            "brand" to Build.BRAND.orEmpty(),
            "device" to Build.DEVICE.orEmpty(),
            "product" to Build.PRODUCT.orEmpty(),
        ),
        property = SystemProps::get,
    )

    /**
     * The detection logic, independent of the device: [buildFields] maps a field name
     * (`fingerprint`, `model`, `manufacturer`, `brand`, `device`, `product`) to its value and
     * [property] reads a system property.
     */
    fun evaluate(
        hardware: String,
        buildFields: Map<String, String>,
        property: (String) -> String?,
    ): RiskReport {
        val signals = mutableListOf<RiskSignal>()

        // --- High-risk: hardware
        val hw = hardware.lowercase()
        if (emulatorHardware.any { hw.contains(it) }) {
            signals += RiskSignal("emulator.hardware:$hw", highRisk = true)
        }

        // --- High-risk: QEMU kernel properties (set by every Android emulator image)
        for (prop in listOf("ro.kernel.qemu", "ro.boot.qemu")) {
            if (property(prop) == "1") signals += RiskSignal("emulator.qemu:$prop", highRisk = true)
        }

        val fields = buildFields.mapValues { it.value.lowercase() }

        // --- High-risk: emulator-only names
        val highFields = mutableSetOf<String>()
        for ((name, value) in fields) {
            if (emulatorNames.any { value.contains(it) }) {
                signals += RiskSignal("emulator.build_name:$name", highRisk = true)
                highFields += name
            }
        }
        if (fields["fingerprint"].orEmpty().startsWith("generic")) {
            signals += RiskSignal("emulator.generic_fingerprint", highRisk = true)
            highFields += "fingerprint"
        }
        if (fields["brand"].orEmpty().startsWith("generic") && fields["device"].orEmpty().startsWith("generic")) {
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
}
