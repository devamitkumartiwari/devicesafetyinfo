package com.devamitkumartiwari.devicesafetyinfo.developmentmode

import android.content.Context
import android.os.Build
import android.provider.Settings

class DevelopmentModeCheck {

    companion object{

        fun isDevMode(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Settings.Secure.getInt(
                    context.contentResolver,
                    Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                    0
                ) != 0
            } else {
                Settings.Secure.getInt(
                    context.contentResolver,
                    Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                    1
                ) != 0
            }
        }

    }



}