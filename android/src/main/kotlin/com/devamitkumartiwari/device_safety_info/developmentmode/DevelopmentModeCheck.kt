package com.devamitkumartiwari.device_safety_info.developmentmode

import android.content.Context
import android.provider.Settings

object DevelopmentModeCheck {

    fun isDevMode(context: Context): Boolean {
        return try {
            Settings.Global.getInt(
                context.contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                0
            ) != 0
        } catch (e: Exception) {
            false
        }
    }
}
