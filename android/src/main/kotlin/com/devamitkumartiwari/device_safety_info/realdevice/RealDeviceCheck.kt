package com.devamitkumartiwari.device_safety_info.realdevice

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
 * [isRealDevice] only returns `false` for high-risk signals.
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
        emulatorHardware.firstOrNull { hardware.contains(it) }?.let {
            signals += RiskSignal("hardware:$hardware", highRisk = true)
        }

        // --- High-risk: QEMU kernel properties (set by every Android emulator image)
        for (prop in listOf("ro.kernel.qemu", "ro.boot.qemu")) {
            if (systemProperty(prop) == "1") signals += RiskSignal("prop:$prop=1", highRisk = true)
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
        for ((name, value) in fields) {
            emulatorNames.firstOrNull { value.contains(it) }?.let {
                signals += RiskSignal("$name:$value", highRisk = true)
            }
        }
        if (fields["fingerprint"]!!.startsWith("generic")) {
            signals += RiskSignal("fingerprint:${fields["fingerprint"]}", highRisk = true)
        }
        if (fields["brand"]!!.startsWith("generic") && fields["device"]!!.startsWith("generic")) {
            signals += RiskSignal("brand+device:generic", highRisk = true)
        }

        // --- Low-risk: weak words in any single field
        for ((name, value) in fields) {
            weakWords.firstOrNull { value.contains(it) }?.let {
                signals += RiskSignal("$name:$value", highRisk = false)
            }
        }

        // A field already reported as high-risk shouldn't also appear as low-risk.
        val highIds = signals.filter { it.highRisk }.map { it.id }.toSet()
        return RiskReport(
            signals.filter { it.highRisk || it.id !in highIds }.distinctBy { it.id }
        )
    }

    /**
     * Determines if the current device is a physical device rather than an emulator.
     *
     * @return `false` only when a high-risk emulator indicator is present.
     */
    fun isRealDevice(): Boolean = !evaluate().isHighRisk

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
