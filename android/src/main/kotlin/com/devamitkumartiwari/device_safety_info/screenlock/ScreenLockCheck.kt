package com.devamitkumartiwari.device_safety_info.screenlock

import android.annotation.TargetApi
import android.app.KeyguardManager
import android.content.ContentResolver
import android.content.Context
import android.os.Build
import android.provider.Settings

/**
 * A utility to check if the device has a screen lock enabled.
 */
object ScreenLockCheck {

    /**
     * Checks if the device has a screen lock set (e.g., PIN, pattern, or password).
     *
     * This method adapts its approach based on the Android version.
     * On Android M (API 23) and above, it uses the recommended `isDeviceSecure` method.
     * On older versions, it falls back to checking for a pattern or a PIN/password individually.
     *
     * @param context The application context.
     * @return `true` if a screen lock is enabled, `false` otherwise.
     */
    fun isDeviceScreenLocked(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            isDeviceLocked(context)
        } else {
            isPatternSet(context) || isPassOrPinSet(context)
        }
    }

    /**
     * Legacy check for a pattern lock on pre-M devices.
     * This method is private as it is an implementation detail.
     */
    private fun isPatternSet(context: Context): Boolean {
        return try {
            val cr: ContentResolver = context.contentResolver
            @Suppress("DEPRECATION")
            val lockPatternEnable: Int =
                Settings.Secure.getInt(cr, Settings.Secure.LOCK_PATTERN_ENABLED)
            lockPatternEnable == 1
        } catch (e: Settings.SettingNotFoundException) {
            false
        }
    }

    /**
     * Legacy check for a PIN or password on pre-M devices.
     * This method is private as it is an implementation detail.
     */
    private fun isPassOrPinSet(context: Context): Boolean {
        val keyguardManager =
            context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return keyguardManager.isKeyguardSecure
    }

    /**
     * Modern check for any secure screen lock on API 23+ devices.
     * This method is private as it is an implementation detail.
     */
    @TargetApi(23)
    private fun isDeviceLocked(context: Context): Boolean {
        val keyguardManager =
            context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return keyguardManager.isDeviceSecure
    }
}
