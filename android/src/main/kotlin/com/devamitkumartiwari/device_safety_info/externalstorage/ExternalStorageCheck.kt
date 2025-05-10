package com.devamitkumartiwari.device_safety_info.externalstorage

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build

class ExternalStorageCheck {

    companion object {
        fun isExternalStorage(context: Context): Boolean {
            return try {
                val pm = context.packageManager
                val ai: ApplicationInfo? =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val pi = pm.getPackageInfo(
                            context.packageName,
                            PackageManager.PackageInfoFlags.of(0)
                        )
                        pi.applicationInfo
                    } else {
                        @Suppress("DEPRECATION")
                        val pi = pm.getPackageInfo(context.packageName, 0)
                        pi.applicationInfo
                    }

                // ✅ Safe null check
                ai?.flags?.and(ApplicationInfo.FLAG_EXTERNAL_STORAGE) == ApplicationInfo.FLAG_EXTERNAL_STORAGE
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
        }
    }
}
