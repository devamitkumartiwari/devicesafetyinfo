package com.devamitkumartiwari.device_safety_info

import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.features.emulator.RealDeviceCheck
import com.devamitkumartiwari.device_safety_info.features.hooking.MemoryMapsScanner
import com.devamitkumartiwari.device_safety_info.features.root.RootFilesChecker
import com.devamitkumartiwari.device_safety_info.features.root.SystemPropsChecker
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SystemPropsCheckerTest {

    private fun signals(vararg props: Pair<String, String>): List<RiskSignal> {
        val map = props.toMap()
        return SystemPropsChecker.signals { map[it] }
    }

    @Test
    fun cleanDeviceHasNoSignals() {
        assertEquals(
            emptyList(),
            signals("ro.secure" to "1", "ro.build.tags" to "release-keys", "ro.boot.verifiedbootstate" to "green"),
        )
    }

    @Test
    fun roSecureOffIsHighRisk() {
        assertEquals(listOf(RiskSignal("root.ro_secure_off:0", true)), signals("ro.secure" to "0"))
    }

    @Test
    fun weakIndicatorsAreLowRisk() {
        val s = signals(
            "ro.build.tags" to "test-keys",
            "ro.bootmode" to "recovery",
            "ro.boot.verifiedbootstate" to "orange",
        )
        assertEquals(
            listOf("root.test_keys:test-keys", "root.recovery_boot:recovery", "root.verifiedboot_unlocked:orange"),
            s.map { it.id },
        )
        assertTrue(s.none { it.highRisk })
    }

    @Test
    fun missingPropertiesAreIgnored() {
        assertEquals(emptyList(), SystemPropsChecker.signals { null })
    }
}

class RootFilesCheckerTest {

    @Test
    fun executableSuIsHighAndNonExecutableIsLow() {
        val present = setOf("/system/xbin/su", "/sbin/su")
        val s = RootFilesChecker.signals(
            exists = { it in present },
            canExecute = { it == "/system/xbin/su" },
        )
        assertEquals(
            listOf(
                RiskSignal("root.su_executable:/system/xbin/su", true),
                RiskSignal("root.su_present:/sbin/su", false),
            ),
            s,
        )
    }

    @Test
    fun magiskIsHighRiskWhenPresent() {
        val s = RootFilesChecker.signals(exists = { it == "/data/adb/magisk" }, canExecute = { false })
        assertEquals(listOf(RiskSignal("root.manager_file:/data/adb/magisk", true)), s)
    }

    @Test
    fun nothingPresent() {
        assertEquals(emptyList(), RootFilesChecker.signals(exists = { false }, canExecute = { true }))
    }
}

class RealDeviceCheckTest {

    private val pixel = mapOf(
        "fingerprint" to "google/husky/husky:15/AP4A/123:user/release-keys",
        "model" to "Pixel 8 Pro",
        "manufacturer" to "Google",
        "brand" to "google",
        "device" to "husky",
        "product" to "husky",
    )

    @Test
    fun realPhoneIsClean() {
        val r = RealDeviceCheck.evaluate("husky", pixel) { null }
        assertEquals(emptyList(), r.signals)
    }

    @Test
    fun emulatorHardwareAndQemuAreHighRisk() {
        val r = RealDeviceCheck.evaluate("ranchu", pixel) { if (it == "ro.kernel.qemu") "1" else null }
        assertEquals(listOf("emulator.hardware:ranchu", "emulator.qemu:ro.kernel.qemu"), r.signals.map { it.id })
        assertTrue(r.isHighRisk)
    }

    @Test
    fun sdkBuildNamesAreHighRisk() {
        val r = RealDeviceCheck.evaluate(
            "goldfish_x86",
            pixel + ("model" to "sdk_gphone64_x86_64") + ("product" to "sdk_gphone64_x86_64"),
        ) { null }
        assertTrue("emulator.build_name:model" in r.signals.map { it.id })
        assertTrue("emulator.build_name:product" in r.signals.map { it.id })
    }

    @Test
    fun genericBrandAndDeviceTogetherAreHigh() {
        val r = RealDeviceCheck.evaluate("x", pixel + ("brand" to "generic") + ("device" to "generic_x86")) { null }
        assertTrue(RiskSignal("emulator.generic_brand_device", true) in r.signals)
        // A field already reported high isn't reported low as well.
        assertTrue(r.signals.none { it.id == "emulator.generic_build:brand" })
    }

    @Test
    fun weakWordsInOneFieldAreLowRiskOnly() {
        val r = RealDeviceCheck.evaluate("mt6765", pixel + ("manufacturer" to "unknown")) { null }
        assertEquals(listOf(RiskSignal("emulator.generic_build:manufacturer", false)), r.signals)
    }
}

class MemoryMapsScannerTest {

    @Test
    fun reportsOnlyUntrustedRwxLibraries() {
        val maps = sequenceOf(
            "7f00000000-7f00001000 r-xp 00000000 fd:00 123  /system/lib64/libc.so",
            "7f00002000-7f00003000 rwxp 00000000 fd:00 124  /system/lib64/libart.so",
            "7f00004000-7f00005000 rwxp 00000000 fd:00 125  /data/app/~~x/com.example-1/lib/arm64/libapp.so",
            "7f00006000-7f00007000 rwxp 00000000 fd:00 126  /data/local/tmp/re.frida.agent.so",
            "7f00008000-7f00009000 rwxp 00000000 00:00 0    [anon:dalvik-jit-code-cache]",
            "7f0000a000-7f0000b000 rw-p 00000000 fd:00 127  /data/local/tmp/libother.so",
            "too short",
        )
        assertEquals(setOf("re.frida.agent.so"), MemoryMapsScanner.rwxLibraries(maps))
    }

    @Test
    fun cleanMapsReportNothing() {
        assertEquals(emptySet(), MemoryMapsScanner.rwxLibraries(emptySequence()))
    }
}
