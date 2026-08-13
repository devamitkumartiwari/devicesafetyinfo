package com.devamitkumartiwari.device_safety_info.notificationlistener

import android.content.Context
import android.provider.Settings

// Reads the OS's own record of currently-enabled Notification Listener services. Malware that
// abuses this API (to read/intercept OTP and SMS notifications) shows up here the same way a
// legitimate notification-reading app would — this surfaces the raw list; distinguishing
// malicious from legitimate listeners against a known-good/known-bad list is left to the caller.
//
// Unlike ENABLED_ACCESSIBILITY_SERVICES, there is no public Settings.Secure constant for this key
// — "enabled_notification_listeners" is read directly as a raw string, same as
// PlayProtectStatusCheck's "package_verifier_user_consent".
object NotificationListenerAbuseDetector {
    private const val SETTING_KEY = "enabled_notification_listeners"

    fun getEnabledNotificationListeners(context: Context): List<String> {
        val raw = Settings.Secure.getString(context.contentResolver, SETTING_KEY)
        if (raw.isNullOrEmpty()) return emptyList()
        return raw.split(':').filter { it.isNotBlank() }
    }
}
