package com.devamitkumartiwari.device_safety_info.rooted

import android.content.Context
import android.os.Build
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.util.*
import com.scottyab.rootbeer.RootBeer

// Interface for checking rooted device based on API version
interface RootCheckApi {
    fun isDeviceRooted(): Boolean
}

// Root check method for devices with API level > 23
class GreaterThan23 : RootCheckApi {

    override fun isDeviceRooted(): Boolean {
        return checkRootMethod1() || checkRootMethod2()
    }

    // Method to check known root paths
    private fun checkRootMethod1(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su", "/system/bin/su", "/system/xbin/su",
            "/data/local/xbin/su", "/data/local/bin/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su", "/data/local/su"
        )
        return paths.any { File(it).exists() }
    }

    // Method to check su binary using runtime command
    private fun checkRootMethod2(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            BufferedReader(InputStreamReader(process.inputStream)).use {
                it.readLine() != null
            }
        } catch (e: Throwable) {
            false
        }
    }
}

class RootedDeviceCheck {

    companion object {

        private val ROOTED_MANUFACTURERS = listOf("oneplus", "moto", "xiaomi", "lenovo")

        // Main method to check if the device is rooted
        fun isRootedDevice(context: Context): Boolean {
            val check: RootCheckApi = GreaterThan23()
            return check.isDeviceRooted() || rootBeerCheck(context)
        }

        // Using RootBeer library to check rooted device
        private fun rootBeerCheck(context: Context): Boolean {
            val rootBeer = RootBeer(context)
            val brand = Build.BRAND.lowercase(Locale.getDefault())
            return if (ROOTED_MANUFACTURERS.any { brand.contains(it) }) {
                rootBeer.isRootedWithBusyBoxCheck
            } else {
                rootBeer.isRooted
            }
        }
    }
}
