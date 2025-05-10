package com.devamitkumartiwari.device_safety_info.screenlock

import android.annotation.TargetApi
import android.app.KeyguardManager
import android.content.ContentResolver
import android.content.Context
import android.os.Build
import android.provider.Settings

class ScreenLockCheck {

    companion object {

        /**
         * Check if the device is screen locked (either with pattern, PIN, or password).
         */
        fun isDeviceScreenLocked(appCon: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                isDeviceLocked(appCon)
            } else {
                isPatternSet(appCon) || isPassOrPinSet(appCon)
            }
        }

        /**
         * Check if the device has a pattern lock set.
         * @return true if pattern is set, false if not or an error occurs.
         */
        fun isPatternSet(appCon: Context): Boolean {
            return try {
                val cr: ContentResolver = appCon.contentResolver
                val lockPatternEnable: Int =
                    Settings.Secure.getInt(cr, Settings.Secure.LOCK_PATTERN_ENABLED)
                lockPatternEnable == 1
            } catch (e: Settings.SettingNotFoundException) {
                false
            }
        }

        /**
         * Check if the device has a PIN or password set.
         * @return true if PIN or password is set, false if not.
         */
        fun isPassOrPinSet(appCon: Context): Boolean {
            val keyguardManager =
                appCon.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            return keyguardManager.isKeyguardSecure
        }

        /**
         * Check if the device is locked (securely locked, including PIN, pattern, or password).
         * This method only works on API 23 and above.
         * @return true if device is locked, false if not.
         */
        @TargetApi(23)
        fun isDeviceLocked(appCon: Context): Boolean {
            val keyguardManager =
                appCon.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            return keyguardManager.isDeviceSecure
        }
    }
}
