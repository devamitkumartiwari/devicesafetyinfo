package com.devamitkumartiwari.device_safety_info.externalstorage

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build

/**
 * A utility to check if the application is installed on external storage.
 */
object ExternalStorageCheck {

    /**
     * Checks if the application is currently installed on external storage (e.g., an SD card).
     *
     * An app being on external storage can sometimes imply a higher risk of tampering.
     *
     * @param context The application context, used to access the package manager.
     * @return `true` if the app is on external storage, `false` otherwise or if an error occurs.
     */
    fun isExternalStorage(context: Context): Boolean {
        return try {
            val pm = context.packageManager
            val ai: ApplicationInfo? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getPackageInfo(
                        context.packageName,
                        PackageManager.PackageInfoFlags.of(0)
                    ).applicationInfo
                } else {
                    @Suppress("DEPRECATION")
                    pm.getPackageInfo(context.packageName, 0).applicationInfo
                }

            // Check if the FLAG_EXTERNAL_STORAGE is set in the application's flags.
            ai?.let { (it.flags and ApplicationInfo.FLAG_EXTERNAL_STORAGE) != 0 } ?: false
        } catch (e: PackageManager.NameNotFoundException) {
            // This should not happen if we are checking our own package.
            e.printStackTrace()
            false
        }
    }
}
