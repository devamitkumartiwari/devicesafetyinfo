package com.devamitkumartiwari.device_safety_info.features.app_info

import android.content.pm.PackageManager
import android.os.Build
import com.devamitkumartiwari.device_safety_info.core.BackgroundRunner
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.requireContext
import com.devamitkumartiwari.device_safety_info.generated.AppInfoHostApi
import com.devamitkumartiwari.device_safety_info.generated.AppInfoMsg
import com.devamitkumartiwari.device_safety_info.generated.SigningInfoMsg
import com.devamitkumartiwari.device_safety_info.features.app_integrity.SigningInfoReader

class AppInfoHostApiImpl(
    private val host: PluginHost,
    private val bg: BackgroundRunner,
) : AppInfoHostApi {
    override suspend fun signingInfo(): SigningInfoMsg {
        val ctx = host.requireContext()
        return bg.run { SigningInfoReader.read(ctx) }
    }

    override fun packageInfo(): AppInfoMsg {
        val ctx = host.requireContext()
        val info = if (Build.VERSION.SDK_INT >= 33) {
            ctx.packageManager.getPackageInfo(ctx.packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            ctx.packageManager.getPackageInfo(ctx.packageName, 0)
        }
        val build = if (Build.VERSION.SDK_INT >= 28) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return AppInfoMsg(ctx.packageName, info.versionName ?: "0.0.0", build.toString())
    }
}
