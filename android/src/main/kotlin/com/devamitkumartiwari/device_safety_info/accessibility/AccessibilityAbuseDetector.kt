package com.devamitkumartiwari.device_safety_info.accessibility

import android.content.Context
import android.provider.Settings

// Reads the OS's own record of currently-enabled accessibility services. Malware that abuses the
// Accessibility API (to read screen content or auto-click on behalf of the user) shows up here
// the same way a legitimate screen reader would — this surfaces the raw list; distinguishing
// malicious from legitimate services against a known-good/known-bad list is left to the caller.
object AccessibilityAbuseDetector {
    fun getEnabledAccessibilityServices(context: Context): List<String> {
        val raw = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        if (raw.isNullOrEmpty()) return emptyList()
        return raw.split(':').filter { it.isNotBlank() }
    }
}
