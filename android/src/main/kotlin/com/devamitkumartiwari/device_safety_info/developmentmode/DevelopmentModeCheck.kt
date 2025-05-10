package com.devamitkumartiwari.device_safety_info.developmentmode

import android.content.Context
import android.os.Build
import android.provider.Settings

class DevelopmentModeCheck {

    companion object {

        fun isDevMode(context: Context): Boolean {
            return try {
                val contentResolver = context.contentResolver
                val devModeEnabled = Settings.Secure.getInt(
                    contentResolver,
                    Settings.Secure.DEVELOPMENT_SETTINGS_ENABLED,
                    0
                )
                devModeEnabled != 0
            } catch (e: Exception) {
                false // Return false on failure (e.g., SecurityException or SettingNotFoundException)
            }
        }
    }
}
