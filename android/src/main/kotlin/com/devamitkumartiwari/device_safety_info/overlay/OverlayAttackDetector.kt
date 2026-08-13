package com.devamitkumartiwari.device_safety_info.overlay

import android.app.Activity
import android.view.MotionEvent
import android.view.Window

// Wraps an Activity's Window.Callback to detect touches delivered while the window is
// obscured (or partially obscured) by another app's overlay — tapjacking / overlay-phishing.
// Uses MotionEvent.FLAG_WINDOW_IS_OBSCURED / FLAG_WINDOW_IS_PARTIALLY_OBSCURED.
class OverlayAttackDetector private constructor(
    private val original: Window.Callback,
    private val onObscuredTouch: () -> Unit,
) : Window.Callback by original {

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        val obscured = (event.flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED) != 0
        val partiallyObscured = (event.flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED) != 0
        if (obscured || partiallyObscured) {
            onObscuredTouch()
        }
        return original.dispatchTouchEvent(event)
    }

    companion object {
        fun install(activity: Activity, onObscuredTouch: () -> Unit): OverlayAttackDetector {
            val original = activity.window.callback
            val detector = OverlayAttackDetector(original, onObscuredTouch)
            activity.window.callback = detector
            return detector
        }

        fun uninstall(activity: Activity, detector: OverlayAttackDetector) {
            if (activity.window.callback === detector) {
                activity.window.callback = detector.original
            }
        }
    }
}
