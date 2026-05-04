package com.devamitkumartiwari.device_safety_info.screencapturedetector

import android.content.Context
import android.hardware.display.DisplayManager
import android.view.Display

class ScreenCaptureDetector(private val context: Context) {
    fun isScreenBeingCaptured(): Boolean {
        val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        return displayManager.displays.any { display ->
            // Flag only non-default displays that are NOT presentation displays.
            // FLAG_PRESENTATION is set for legitimate external mirrors (HDMI, Cast receiver).
            // Screen-recording virtual displays do NOT carry FLAG_PRESENTATION.
            display.displayId != Display.DEFAULT_DISPLAY &&
                (display.flags and Display.FLAG_PRESENTATION == 0)
        }
    }
}
