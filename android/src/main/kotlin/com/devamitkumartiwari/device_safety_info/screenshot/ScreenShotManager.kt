package com.devamitkumartiwari.device_safety_info.screenshot

import android.app.Activity
import android.view.WindowManager

/**
 * Manages screenshot prevention for an activity's window.
 */
object ScreenShotManager {

    /**
     * Blocks or unblocks screenshots for the given activity.
     *
     * @param activity The activity to modify.
     * @param block If true, prevents screenshots and screen recordings.
     *              If false, allows screenshots.
     */
    fun setScreenshotBlock(activity: Activity, block: Boolean) {
        if (block) {
            activity.window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            activity.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
