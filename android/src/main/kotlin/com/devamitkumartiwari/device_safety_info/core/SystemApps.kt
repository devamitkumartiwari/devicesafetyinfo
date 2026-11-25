package com.devamitkumartiwari.device_safety_info.core

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build

/** Whether a package is a preinstalled system app (or an update to one). */
object SystemApps {

    /** The package part of a component name like `com.example/.Service`. */
    fun packageOf(componentId: String): String = componentId.substringBefore('/')

    /** True for system apps; false for user-installed, unknown or invisible packages. */
    fun isSystemApp(context: Context, packageName: String): Boolean = try {
        val info = if (Build.VERSION.SDK_INT >= 33) {
            context.packageManager.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getApplicationInfo(packageName, 0)
        }
        info.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
    } catch (_: Exception) {
        false
    }
}
