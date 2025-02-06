package com.devamitkumartiwari.device_safety_info.storeinstallcheck

import android.content.Context
import android.os.Build

class StoreInstallCheck {

    companion object {


        private val trustedStores = setOf(
            "com.android.vending",               // Google Play Store
            "com.google.android.packageinstaller", // Default package installer
            "com.skt.skaf.A000Z00040",           // SKT T Store (Korea)
            "com.kt.olleh.storefront",           // Olleh Market (Korea)
            "android.lgt.appstore",              // LG U+ Store (Korea)
            "com.lguplus.appstore",              // LG U+ Store (Alternative)
            "com.sec.android.app.samsungapps",   // Samsung Galaxy Store
            "com.samsung.android.mateagent",     // Samsung Smart Switch
            "com.sec.android.easyMover.Agent",   // Samsung Easy Mover
            "com.huawei.appmarket",              // Huawei AppGallery
            "com.amazon.venezia",                // Amazon Appstore
            "com.xiaomi.market",                 // Xiaomi GetApps
            "com.oppo.market",                   // Oppo App Market
            "com.vivo.appstore",                 // Vivo App Store
            "com.heytap.market"                  // OnePlus Store (HeyTap)
        )

        fun isInstalledFromStore(context: Context?): Boolean {
            if (context == null) return false

            val packageName: String? = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    context.packageManager.getInstallerPackageName(context.packageName)
                }
            } catch (e: Exception) {
                null // Return null if an exception occurs
            }

            return packageName != null && trustedStores.contains(packageName)
        }
    }


}