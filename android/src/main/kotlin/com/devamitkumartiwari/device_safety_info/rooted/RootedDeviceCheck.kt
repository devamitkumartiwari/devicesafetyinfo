package com.devamitkumartiwari.device_safety_info.rooted

import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File
import java.io.BufferedReader
import java.io.InputStreamReader

object RootedDeviceCheck {
    private const val TAG = "RootedDeviceCheck"

    fun isRootedDevice(context: Context): Boolean {
        Log.d(TAG, "Starting root detection checks.")
        val checks = arrayOf(
            checkSuExists(),
            checkTestKeys(),
            checkRootManagementApps(context),
            checkMagiskExists(),
            checkWriteablePaths(),
            checkForDangerousProps(),
            checkForBusyBox()
        )

        val isRooted = checks.any { it }
        Log.d(TAG, "Overall rooted status: $isRooted")
        return isRooted
    }

    private fun checkSuExists(): Boolean {
        val paths = arrayOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/vendor/bin/su",
            "/system/su", "/data/local/xbin/su", "/data/local/bin/su",
            "/system/bin/.ext/.su", "/system/app/Superuser.apk"
        )
        return paths.any {
            try {
                File(it).exists().also { exists ->
                    if (exists) Log.d(TAG, "Found su binary at: $it")
                }
            } catch (e: Exception) {
                false
            }
        }
    }

    private fun checkTestKeys(): Boolean {
        val buildTags = Build.TAGS
        val isTestKeys = buildTags != null && buildTags.contains("test-keys")
        if (isTestKeys) Log.d(TAG, "Build tags contain 'test-keys'")
        return isTestKeys
    }

    private fun checkRootManagementApps(context: Context): Boolean {
        val rootPackages = arrayOf(
            "com.noshufou.android.su", "eu.chainfire.supersu", "com.topjohnwu.magisk",
            "com.koushikdutta.superuser", "com.ramdroid.appquarantine", "com.thirdparty.superuser"
        )
        return rootPackages.any { pkg ->
            try {
                context.packageManager.getPackageInfo(pkg, 0)
                Log.d(TAG, "Found root management app: $pkg")
                true
            } catch (e: Exception) {
                false
            }
        }
    }

    private fun checkMagiskExists(): Boolean {
        val magiskPaths = arrayOf(
            "/sbin/magisk", "/data/adb/magisk", "/system/bin/magisk"
        )
        return magiskPaths.any { path ->
            try {
                File(path).exists().also { exists ->
                    if (exists) Log.d(TAG, "Found Magisk binary at: $path")
                }
            } catch (e: Exception) {
                false
            }
        }
    }

    private fun checkWriteablePaths(): Boolean {
        val paths = arrayOf("/system", "/system/bin", "/system/xbin", "/data")
        return paths.any { path ->
            try {
                val f = File(path)
                f.canWrite().also { canWrite ->
                    if (canWrite) Log.d(TAG, "Path is writable: $path")
                }
            } catch (e: Exception) {
                false
            }
        }
    }

    private fun checkForDangerousProps(): Boolean {
        return try {
            val debuggable = Runtime.getRuntime().exec("getprop ro.debuggable").inputStream.bufferedReader().use { it.readLine() }
            val secure = Runtime.getRuntime().exec("getprop ro.secure").inputStream.bufferedReader().use { it.readLine() }

            val isDangerous = debuggable == "1" || secure == "0"
            if (isDangerous) Log.d(TAG, "Found dangerous properties: ro.debuggable=$debuggable, ro.secure=$secure")
            isDangerous
        } catch (e: Exception) {
            false
        }
    }

    private fun checkForBusyBox(): Boolean {
        val paths = arrayOf(
            "/system/bin/busybox", "/system/xbin/busybox", "/sbin/busybox"
        )
        return paths.any { path ->
            try {
                File(path).exists().also { exists ->
                    if (exists) Log.d(TAG, "Found busybox binary at: $path")
                }
            } catch (e: Exception) {
                false
            }
        }
    }
}