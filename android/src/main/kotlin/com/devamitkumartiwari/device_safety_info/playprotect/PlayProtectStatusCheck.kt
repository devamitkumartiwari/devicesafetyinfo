package com.devamitkumartiwari.device_safety_info.playprotect

import android.content.Context
import android.provider.Settings

// Reads the Settings.Global key that Google Play Protect's on/off toggle actually controls under
// the hood (package_verifier_user_consent). There is no public "Play Protect API" — SafetyNet's
// Verify Apps API, which used to expose this, was fully retired in January 2025, and its signals
// now live only inside Play Integrity API verdicts, which this plugin deliberately doesn't bundle
// (see CHANGELOG). This is the same underlying setting, read directly, no permission or dependency
// required. 1 = enabled, -1 = disabled, 0 = undetermined/not yet asked.
object PlayProtectStatusCheck {
    private const val SETTING_KEY = "package_verifier_user_consent"

    fun getStatus(context: Context): Int {
        return try {
            Settings.Global.getInt(context.contentResolver, SETTING_KEY)
        } catch (e: Settings.SettingNotFoundException) {
            0
        } catch (e: SecurityException) {
            0
        }
    }
}
