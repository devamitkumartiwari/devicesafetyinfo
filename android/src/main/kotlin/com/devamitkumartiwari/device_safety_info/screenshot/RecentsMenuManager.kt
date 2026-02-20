package com.devamitkumartiwari.device_safety_info.screenshot

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.os.Build

/**
 * Manages app visibility in the recents screen.
 */
object RecentsMenuManager {

    /**
     * Hides or shows the app in the recents screen.
     *
     * @param activity The activity to modify.
     * @param hide If true, hides the app from the recents screen.
     *             If false, shows the app in the recents screen.
     */
    fun setRecentsMenuHidden(activity: Activity, hide: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val am = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            am.appTasks.firstOrNull()?.setExcludeFromRecents(hide)
        }
    }
}
