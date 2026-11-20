package com.devamitkumartiwari.device_safety_info

import com.devamitkumartiwari.device_safety_info.features.app_integrity.SigningInfoReader
import com.devamitkumartiwari.device_safety_info.features.emulator.RealDeviceCheck
import com.devamitkumartiwari.device_safety_info.features.hooking.HookDetector
import com.devamitkumartiwari.device_safety_info.features.hooking.MemoryMapsScanner
import com.devamitkumartiwari.device_safety_info.features.root.MountChecker
import com.devamitkumartiwari.device_safety_info.features.root.RootCommandsChecker
import com.devamitkumartiwari.device_safety_info.features.root.RootFilesChecker
import com.devamitkumartiwari.device_safety_info.features.root.RootPackagesChecker
import com.devamitkumartiwari.device_safety_info.features.root.SystemPropsChecker
import com.devamitkumartiwari.device_safety_info.generated.Signatures
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SignaturesTest {

    @Test
    fun encodedListsDecodeToTheSourceStrings() {
        assertEquals("/system/xbin/su", Signatures.suPaths.first())
        assertTrue("/data/adb/ksu" in Signatures.rootManagerPaths)
        assertTrue("com.topjohnwu.magisk" in Signatures.rootManagerPackages)
        assertTrue(Signatures.rootBinaries.containsAll(listOf("su", "ksud", "apd", "resetprop")))
        assertTrue(Signatures.suPaths.none { it.isEmpty() })
    }
}

class ModernRootTest {

    @Test
    fun kernelSuApatchAndMagiskPathsAreHighRisk() {
        for (path in listOf("/data/adb/ksu", "/data/adb/ap", "/debug_ramdisk/magisk")) {
            val s = RootFilesChecker.signals(exists = { it == path }, canExecute = { false })
            assertEquals(listOf("root.manager_file:$path" to true), s.map { it.id to it.highRisk })
        }
    }

    @Test
    fun rootBinariesInPathAreFoundInProcess() {
        val present = setOf("/sbin/ksud", "/system/bin/busybox", "/system/xbin/su")
        val s = RootCommandsChecker.signals(
            path = "/sbin:/system/bin::/system/xbin:/sbin",
            isFile = { it.path.replace(File.separatorChar, '/') in present },
            canExecute = { it.name != "su" },
        )
        assertEquals(
            setOf(
                "root.binary_executable:/sbin/ksud" to true,
                "root.busybox:/system/bin/busybox" to false,
                "root.binary_present:/system/xbin/su" to false,
            ),
            s.map { it.id.replace(File.separatorChar, '/') to it.highRisk }.toSet(),
        )
        assertTrue(RootCommandsChecker.signals(path = null).isEmpty())
    }

    @Test
    fun insecureBuildPropertiesAreHighRisk() {
        val props = mapOf(
            "service.adb.root" to "1",
            "ro.boot.selinux" to "permissive",
            "persist.sys.root_access" to "3",
            "ro.debuggable" to "1",
            "ro.build.type" to "user",
        )
        val s = SystemPropsChecker.signals { props[it] }.associate { it.id to it.highRisk }
        assertEquals(
            mapOf(
                "root.adb_root:1" to true,
                "root.selinux_permissive:permissive" to true,
                "root.lineage_root_access:3" to true,
                "root.debuggable_user_build" to true,
            ),
            s,
        )
    }

    @Test
    fun developerBuildPropertiesAreLowRisk() {
        val props = mapOf(
            "ro.build.type" to "userdebug",
            "ro.debuggable" to "1",
            "ro.boot.vbmeta.device_state" to "unlocked",
            "ro.allow.mock.location" to "1",
        )
        val s = SystemPropsChecker.signals { props[it] }
        // ro.debuggable on a userdebug build is expected, not an inconsistency.
        assertTrue(s.none { it.highRisk }, "$s")
        assertEquals(
            setOf("root.debug_build", "root.bootloader_unlocked", "root.mock_location_allowed"),
            s.map { it.id.substringBefore(':') }.toSet(),
        )
    }

    @Test
    fun mountsShowSystemlessRoot() {
        val lines = sequenceOf(
            "/dev/block/dm-0 / ext4 ro,seclabel,relatime 0 0",
            "tmpfs /apex tmpfs rw,seclabel,nosuid 0 0",
            "magisk /system/bin tmpfs rw,seclabel 0 0",
            "KSU /vendor/bin overlay ro,seclabel 0 0",
            "overlay /product overlay ro,lowerdir=/data/adb/modules/x/product:/product 0 0",
            "/dev/block/dm-1 /system_ext ext4 rw,seclabel 0 0",
            "tmpfs /system/xbin tmpfs rw,seclabel 0 0",
            "/dev/block/sda1 /data f2fs rw,lazytime 0 0",
        )
        assertEquals(
            listOf(
                "root.mount_marker:/system/bin",
                "root.mount_marker:/vendor/bin",
                "root.mount_marker:/product",
                "root.system_rw:/system_ext",
                "root.system_overlay:/system/xbin",
            ),
            MountChecker.signals(lines).map { it.id },
        )
    }

    @Test
    fun stockMountsAreClean() {
        val lines = sequenceOf(
            "/dev/block/dm-0 / erofs ro,seclabel 0 0",
            "/dev/block/dm-3 /vendor erofs ro,seclabel 0 0",
            "tmpfs /dev tmpfs rw,seclabel,nosuid 0 0",
            "/dev/block/sda1 /data f2fs rw,lazytime 0 0",
            "short",
        )
        assertTrue(MountChecker.signals(lines).isEmpty())
    }

    @Test
    fun rootManagerAppsAreHighAndCloakingAppsLow() {
        val installed = setOf("com.topjohnwu.magisk", "com.tsng.hidemyapplist", "com.example.app")
        val s = RootPackagesChecker.signals(isInstalled = { it in installed })
        assertEquals(
            listOf(
                "root.manager_app:com.topjohnwu.magisk" to true,
                "root.cloak_app:com.tsng.hidemyapplist" to false,
            ),
            s.map { it.id to it.highRisk },
        )
    }
}

class HookingTest {

    private val noMaps = MemoryMapsScanner.Findings(emptySet(), emptySet())

    @Test
    fun cleanProcessReportsNothing() {
        val r = HookDetector.hookReport(
            exists = { false },
            classLoadable = { false },
            stackTrace = { listOf("com.example.Main.run", "android.os.Looper.loop") },
            maps = { noMaps },
        )
        assertTrue(r.signals.isEmpty())
    }

    @Test
    fun xposedFramesMappedFrameworksAndServersAreHighRisk() {
        val r = HookDetector.hookReport(
            exists = { it == "/system/bin/frida-server" },
            classLoadable = { false },
            stackTrace = {
                listOf("de.robv.android.xposed.XposedBridge.handleHookedMethod", "com.example.Main.run")
            },
            maps = { MemoryMapsScanner.Findings(setOf("libevil.so"), setOf("liblspd")) },
        )
        assertEquals(
            listOf(
                "hooking.frida_server:/system/bin/frida-server" to true,
                "hooking.stack_frame:de.robv.android.xposed" to true,
                "hooking.framework_mapped:liblspd" to true,
                "hooking.rwx_library:libevil.so" to false,
            ),
            r.signals.map { it.id to it.highRisk },
        )
    }

    @Test
    fun mapsScanFindsZygiskEraFrameworks() {
        val lines = sequenceOf(
            "7f00-7f01 r-xp 0 fd:01 9 /apex/com.android.runtime/lib64/bionic/libc.so",
            "7f02-7f03 r-xp 0 fd:01 9 /data/adb/modules/zygisk_lsposed/lib/arm64-v8a/liblspd.so",
            "7f04-7f05 r-xp 0 fd:01 9 /data/adb/modules/zygisk_shamiko/zygisk/arm64-v8a.so",
        )
        val found = MemoryMapsScanner.scan(lines)
        // One marker per mapping: the first one in the list that matches.
        assertEquals(setOf("liblspd", "zygisk"), found.hookMarkers)
        assertTrue(found.rwxLibraries.isEmpty())
    }
}

class EmulatorHintsTest {

    private val realPhone = mapOf(
        "fingerprint" to "samsung/r9qxeea/r9q:14/UP1A/S711BXXU:user/release-keys",
        "model" to "SM-S711B",
        "manufacturer" to "samsung",
        "brand" to "samsung",
        "device" to "r9q",
        "product" to "r9qxeea",
    )

    @Test
    fun vendorEmulatorFilesAndPropsAreHighRisk() {
        val r = RealDeviceCheck.evaluate(
            hardware = "qcom",
            buildFields = realPhone,
            exists = { it == "/data/.bluestacks.prop" },
        ) { if (it == "init.svc.qemu-props") "running" else null }
        assertEquals(
            setOf("emulator.qemu_prop:init.svc.qemu-props", "emulator.file:/data/.bluestacks.prop"),
            r.signals.filter { it.highRisk }.map { it.id }.toSet(),
        )
    }

    @Test
    fun deviceShapeHintsAreLowRiskOnly() {
        val r = RealDeviceCheck.evaluate(
            hardware = "qcom",
            buildFields = realPhone,
            supportedAbis = listOf("x86_64", "x86"),
            hasMotionSensors = false,
            networkOperatorName = "Android",
        ) { null }
        assertFalse(r.isHighRisk)
        assertEquals(
            setOf("emulator.x86_only", "emulator.no_motion_sensors", "emulator.network_operator"),
            r.signals.map { it.id }.toSet(),
        )
    }

    @Test
    fun armPhoneWithSensorsIsClean() {
        val r = RealDeviceCheck.evaluate(
            hardware = "qcom",
            buildFields = realPhone,
            supportedAbis = listOf("arm64-v8a", "armeabi-v7a"),
            hasMotionSensors = true,
            networkOperatorName = "Vodafone",
        ) { null }
        assertTrue(r.signals.isEmpty(), "${r.signals}")
    }
}

class SigningInfoTest {

    @Test
    fun digestIsLowercaseHexSha256() {
        assertEquals(
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            SigningInfoReader.sha256Hex(ByteArray(0)),
        )
    }
}
