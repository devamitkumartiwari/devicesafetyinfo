package com.devamitkumartiwari.device_safety_info.features.screen_protection

import android.content.Context
import android.hardware.display.DisplayManager
import android.view.Display
import android.view.WindowManager
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.core.requireActivity
import com.devamitkumartiwari.device_safety_info.generated.CheckReportMsg
import com.devamitkumartiwari.device_safety_info.generated.OverlayConfigMsg
import com.devamitkumartiwari.device_safety_info.generated.OverlayModeMsg
import com.devamitkumartiwari.device_safety_info.generated.ScreenProtectionHostApi

class ScreenProtectionHostApiImpl(
    private val host: PluginHost,
    private val capture: ScreenCaptureMonitor,
    private val recording: ScreenRecordingMonitor,
) : ScreenProtectionHostApi, Disposable {

    private val overlayManager = ScreenshotOverlayManager(host)
    private var overlayListening = false
    private val captureListener: (Boolean) -> Unit = { updateOverlay() }
    private val recordingListener: (Boolean) -> Unit = { updateOverlay() }

    override fun blockScreenshots(block: Boolean) {
        ScreenShotManager.setScreenshotBlock(host.requireActivity(), block)
    }

    override fun isScreenshotBlocked(): Boolean {
        val act = host.activity ?: return false
        return act.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0
    }

    override fun setOverlayMode(config: OverlayConfigMsg) {
        val mode = when (config.mode) {
            OverlayModeMsg.NONE -> null
            OverlayModeMsg.BLUR -> OverlayMode.BLUR
            OverlayModeMsg.COLOR -> OverlayMode.COLOR
            OverlayModeMsg.IMAGE -> OverlayMode.IMAGE
        }
        if (mode == null) {
            clearOverlayMode()
            return
        }
        overlayManager.setConfig(
            OverlayConfig(mode, config.blurRadius.toFloat(), config.argbColor?.toInt(), config.imageBytes),
        )
        if (!overlayListening) {
            capture.addStateListener(captureListener)
            recording.addStateListener(recordingListener)
            overlayListening = true
        }
        updateOverlay()
    }

    override fun clearOverlayMode() {
        overlayManager.clear()
        if (overlayListening) {
            capture.removeStateListener(captureListener)
            recording.removeStateListener(recordingListener)
            overlayListening = false
        }
    }

    override fun screenCaptureCheck(): CheckReportMsg = captureReport(host.context, recording).toMsg()

    override fun isRecordingDetectionSupported(): Boolean = ScreenRecordingMonitor.isApiSupported

    private fun updateOverlay() {
        overlayManager.setActive(capture.isCurrentlyCaptured() || recording.isCurrentlyRecording())
    }

    override fun dispose() = clearOverlayMode()

    companion object {
        /**
         * High: a secondary display without FLAG_PRESENTATION (the virtual display used for
         * screen recording and mirroring) or an active recording (Android 15+).
         * Low: a presentation display such as HDMI or a Cast receiver, usually legitimate.
         */
        fun captureReport(context: Context?, recording: ScreenRecordingMonitor?): RiskReport {
            context ?: return RiskReport.UNSUPPORTED
            val signals = mutableListOf<RiskSignal>()
            val dm = context.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
            val secondary = dm?.displays.orEmpty().filter { it.displayId != Display.DEFAULT_DISPLAY }
            if (secondary.any { it.flags and Display.FLAG_PRESENTATION == 0 }) {
                signals += RiskSignal("screen_capture.mirroring", highRisk = true)
            }
            if (secondary.any { it.flags and Display.FLAG_PRESENTATION != 0 }) {
                signals += RiskSignal("screen_capture.external_display", highRisk = false)
            }
            if (recording?.isCurrentlyRecording() == true) {
                signals += RiskSignal("screen_capture.recording", highRisk = true)
            }
            return RiskReport(signals)
        }
    }
}
