package com.devamitkumartiwari.device_safety_info.features.accessibility

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import com.devamitkumartiwari.device_safety_info.generated.AccessibilityServiceMsg

/**
 * Lists enabled accessibility services and whether each can read window content (the
 * capability banking trojans abuse to scrape the screen). Allowlisting happens in Dart.
 */
object AccessibilityAbuseDetector {

    fun enabledServices(context: Context): List<AccessibilityServiceMsg> {
        val canRead = mutableMapOf<String, Boolean>()
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
        am?.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)?.forEach { info ->
            val id = info.id ?: return@forEach
            canRead[id] = info.capabilities and
                AccessibilityServiceInfo.CAPABILITY_CAN_RETRIEVE_WINDOW_CONTENT != 0
        }

        // The Settings list also contains services the manager doesn't report (e.g. ones that
        // crashed); include them, assuming the worst about their capabilities.
        val fromSettings = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        )?.split(':')?.filter { it.isNotBlank() }.orEmpty()

        val ids = LinkedHashSet<String>().apply {
            addAll(canRead.keys)
            addAll(fromSettings)
        }
        return ids.map { AccessibilityServiceMsg(it, canRead[it] ?: true) }
    }
}
