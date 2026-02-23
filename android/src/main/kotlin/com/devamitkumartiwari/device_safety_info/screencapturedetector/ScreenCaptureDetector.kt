package com.devamitkumartiwari.device_safety_info.screencapturedetector

import android.content.Context
import android.hardware.display.DisplayManager
import android.media.projection.MediaProjection
import android.view.Display

class ScreenCaptureDetector(private val context: Context) {
    companion object {
        @Volatile
        var screenshotTaken = false
    }

    fun isScreenBeingCaptured(mediaProjection: MediaProjection?): Boolean {
        if (screenshotTaken || mediaProjection != null) {
            return true
        }

        val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val displays = displayManager.displays
        for (display in displays) {
            if (display.displayId != Display.DEFAULT_DISPLAY) {
                return true
            }
        }
        return false
    }
}
