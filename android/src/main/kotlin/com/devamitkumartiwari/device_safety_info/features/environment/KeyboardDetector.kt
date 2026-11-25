package com.devamitkumartiwari.device_safety_info.features.environment

import android.content.Context
import android.provider.Settings
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.core.SystemApps
import com.devamitkumartiwari.device_safety_info.features.accessibility.AccessibilityAbuseDetector

/**
 * The default keyboard (input method). A keyboard sees everything typed, including passwords
 * and OTPs, so a third-party one is worth knowing about. Preinstalled keyboards and the
 * widely used store keyboards from Google and Microsoft are trusted; allowlisting happens in
 * Dart (`DeviceSafetyConfig.keyboardAllowlist`).
 */
object KeyboardDetector {

    /** Store-installed keyboards from platform vendors, trusted like system apps. */
    val trustedKeyboards = setOf(
        "com.google.android.inputmethod.latin", // Gboard
        "com.touchtype.swiftkey", // Microsoft SwiftKey
        "com.samsung.android.honeyboard", // Samsung Keyboard
    )

    fun report(context: Context): RiskReport {
        val id = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.DEFAULT_INPUT_METHOD,
        )
        val services = try {
            AccessibilityAbuseDetector.enabledServices(context).map { it.id }
        } catch (_: Exception) {
            emptyList()
        }
        return RiskReport(
            signals(id, services) { SystemApps.isSystemApp(context, it) },
        )
    }

    /**
     * [defaultInputMethod]: the `DEFAULT_INPUT_METHOD` component id. [enabledServices]:
     * accessibility service component ids. [isSystemApp]: system-app test.
     */
    fun signals(
        defaultInputMethod: String?,
        enabledServices: List<String>,
        isSystemApp: (String) -> Boolean,
    ): List<RiskSignal> {
        if (defaultInputMethod.isNullOrBlank()) return emptyList()
        val pkg = SystemApps.packageOf(defaultInputMethod)
        if (pkg in trustedKeyboards || isSystemApp(pkg)) return emptyList()
        val alsoAccessibility = enabledServices.any { SystemApps.packageOf(it) == pkg }
        return listOf(RiskSignal("keyboard.third_party:$pkg", highRisk = alsoAccessibility))
    }
}
