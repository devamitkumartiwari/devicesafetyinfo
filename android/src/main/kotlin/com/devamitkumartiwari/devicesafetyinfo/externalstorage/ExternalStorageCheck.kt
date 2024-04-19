package com.devamitkumartiwari.devicesafetyinfo.externalstorage

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build

class ExternalStorageCheck {

    companion object {
        fun isExternalStorage(context: Context): Boolean {

            try {
                val pm = context.packageManager
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val pi = pm.getPackageInfo(
                        context.packageName,
                        PackageManager.PackageInfoFlags.of(0)
                    )
                    val ai = pi.applicationInfo
                    return ai.flags and ApplicationInfo.FLAG_EXTERNAL_STORAGE == ApplicationInfo.FLAG_EXTERNAL_STORAGE
                } else {
                    @Suppress("DEPRECATION")
                    val pi = pm.getPackageInfo(context.packageName, 0)
                    val ai = pi.applicationInfo
                    return ai.flags and ApplicationInfo.FLAG_EXTERNAL_STORAGE == ApplicationInfo.FLAG_EXTERNAL_STORAGE
                }
            } catch (e: PackageManager.NameNotFoundException) {
                // ignore
            }

            return false
        }

    }

}