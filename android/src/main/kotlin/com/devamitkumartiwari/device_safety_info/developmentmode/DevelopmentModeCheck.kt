package com.devamitkumartiwari.device_safety_info.developmentmode

import android.content.Context
import android.os.Build
import android.provider.Settings

/**
 * A utility to check if developer mode is enabled on the device.
 */
object DevelopmentModeCheck {

    /**
     * Determines if the developer options are currently enabled on the device.
     *
     * This method checks the appropriate system setting based on the Android version.
     * For devices running API 17 (Jelly Bean MR1) and newer, it uses `Settings.Global`.
     * For older devices, it falls back to the deprecated `Settings.Secure`.
     *
     * @param context The application context, used to access the content resolver.
     * @return `true` if developer mode is enabled, `false` otherwise or if an error occurs.
     */
    fun isDevMode(context: Context): Boolean {
        return try {
            val contentResolver = context.contentResolver
            val devModeEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                Settings.Global.getInt(
                    contentResolver,
                    Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                    0
                )
            } else {
                @Suppress("DEPRECATION")
                Settings.Secure.getInt(
                    contentResolver,
                    Settings.Secure.DEVELOPMENT_SETTINGS_ENABLED,
                    0
                )
            }
            devModeEnabled != 0
        } catch (e: Exception) {
            // On failure (e.g., SecurityException or SettingNotFoundException), assume not enabled.
            e.printStackTrace()
            false
        }
    }
}
