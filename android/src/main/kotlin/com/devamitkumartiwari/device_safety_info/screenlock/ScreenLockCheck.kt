package com.devamitkumartiwari.device_safety_info.screenlock

import android.annotation.TargetApi
import android.app.KeyguardManager
import android.content.ContentResolver
import android.content.Context
import android.os.Build
import android.provider.Settings;


class ScreenLockCheck {


    companion object{

        fun isDeviceScreenLocked(appCon: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                isDeviceLocked(appCon)
            } else {
                isPatternSet(appCon) || isPassOrPinSet(appCon)
            }
        }

        /**
         * @return true if pattern set, false if not (or if an issue when checking)
         */
       fun isPatternSet(appCon: Context): Boolean {
            val cr: ContentResolver = appCon.contentResolver
            return try {
                val lockPatternEnable: Int =
                    Settings.Secure.getInt(cr, Settings.Secure.LOCK_PATTERN_ENABLED)
                lockPatternEnable == 1
            } catch (e: Settings.SettingNotFoundException) {
                false
            }
        }

        /**
         * @return true if pass or pin set
         */
        fun isPassOrPinSet(appCon: Context): Boolean {
            val keyguardManager =
                appCon.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager //api 16+
            return keyguardManager.isKeyguardSecure
        }

        /**
         * @return true if pass or pin or pattern locks screen
         */
        @TargetApi(23)
        fun isDeviceLocked(appCon: Context): Boolean {
            val keyguardManager =
                appCon.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager //api 23+
            return keyguardManager.isDeviceSecure
        }

    }


}