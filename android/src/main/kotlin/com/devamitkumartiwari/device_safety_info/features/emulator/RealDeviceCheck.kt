package com.devamitkumartiwari.device_safety_info.features.emulator

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.telephony.TelephonyManager
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.core.SystemProps
import com.devamitkumartiwari.device_safety_info.generated.Signatures
import java.io.File

/**
 * Checks whether the app is running on a real device or an emulator.
 *
 * Signals are tiered like root detection:
 *  - **High-risk**: evidence that only emulators produce. Emulator hardware (`goldfish`,
 *    `ranchu`, `vbox86`, `nox`, `ttvm`), `ro.kernel.qemu=1` / `ro.boot.qemu=1` and other
 *    QEMU-only properties, QEMU pipes and vendor emulator files (Genymotion, BlueStacks, Nox,
 *    MEmu, LDPlayer, ttVM), emulator product or model names, or the classic `generic` brand
 *    **and** `generic` device pair.
 *  - **Low-risk**: hints that also fit some real devices. `unknown`, `generic` or `nox` inside a
 *    single build field, an x86-only CPU (Chromebooks, a few Intel tablets), no motion sensors
 *    (TV boxes), or a mobile network literally named "Android".
 *
 * Only high-risk signals mean "emulator" under the standard policy.
 */
object RealDeviceCheck {

    /** Runs every emulator check against this device. [context] enables the sensor and
     *  telephony hints. */
    fun evaluate(context: Context?): RiskReport = evaluate(
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
        exists = { File(it).exists() },
        supportedAbis = Build.SUPPORTED_ABIS?.toList().orEmpty(),
        hasMotionSensors = context?.let(::hasMotionSensors),
        networkOperatorName = context?.let(::networkOperatorName),
    )

    /**
     * The detection logic, independent of the device: [buildFields] maps a field name
     * (`fingerprint`, `model`, `manufacturer`, `brand`, `device`, `product`) to its value,
     * [property] reads a system property and [exists] probes a path. `null` for
     * [hasMotionSensors] or [networkOperatorName] skips that hint.
     */
    fun evaluate(
        hardware: String,
        buildFields: Map<String, String>,
        exists: (String) -> Boolean = { false },
        supportedAbis: List<String> = emptyList(),
        hasMotionSensors: Boolean? = null,
        networkOperatorName: String? = null,
        property: (String) -> String?,
    ): RiskReport {
        val signals = mutableListOf<RiskSignal>()

        // --- High-risk: hardware
        val hw = hardware.lowercase()
        if (Signatures.emulatorHardware.any { hw.contains(it) }) {
            signals += RiskSignal("emulator.hardware:$hw", highRisk = true)
        }

        // --- High-risk: QEMU kernel properties (set by every Android emulator image)
        for (prop in listOf("ro.kernel.qemu", "ro.boot.qemu")) {
            if (property(prop) == "1") signals += RiskSignal("emulator.qemu:$prop", highRisk = true)
        }
        // --- High-risk: properties only emulator images define at all
        Signatures.emulatorProps.firstOrNull { property(it) != null }?.let {
            signals += RiskSignal("emulator.qemu_prop:$it", highRisk = true)
        }

        // --- High-risk: QEMU pipes and vendor emulator files
        Signatures.emulatorFiles.firstOrNull(exists)?.let {
            signals += RiskSignal("emulator.file:$it", highRisk = true)
        }

        val fields = buildFields.mapValues { it.value.lowercase() }

        // --- High-risk: emulator-only names
        val highFields = mutableSetOf<String>()
        for ((name, value) in fields) {
            if (Signatures.emulatorNames.any { value.contains(it) }) {
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
            if (name !in highFields && Signatures.emulatorWeakWords.any { value.contains(it) }) {
                signals += RiskSignal("emulator.generic_build:$name", highRisk = false)
            }
        }

        // --- Low-risk: device-shape hints
        if (supportedAbis.isNotEmpty() && supportedAbis.all { it.startsWith("x86") }) {
            signals += RiskSignal("emulator.x86_only", highRisk = false)
        }
        if (hasMotionSensors == false) {
            signals += RiskSignal("emulator.no_motion_sensors", highRisk = false)
        }
        if (networkOperatorName.equals("Android", ignoreCase = true)) {
            signals += RiskSignal("emulator.network_operator", highRisk = false)
        }

        return RiskReport(signals.distinctBy { it.id })
    }

    private fun hasMotionSensors(context: Context): Boolean? = try {
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        sm?.let {
            it.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null ||
                it.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null
        }
    } catch (_: Exception) {
        null
    }

    // networkOperatorName needs no permission. Wi-Fi-only devices report "", which isn't flagged.
    private fun networkOperatorName(context: Context): String? = try {
        (context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager)?.networkOperatorName
    } catch (_: Exception) {
        null
    }
}
