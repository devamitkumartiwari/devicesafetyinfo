package com.devamitkumartiwari.device_safety_info.screenshot

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.RenderEffect
import android.graphics.Shader
import android.os.Build
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import com.devamitkumartiwari.device_safety_info.core.PluginHost

/** Which overlay content [ScreenshotOverlayManager] should render. Mirrors the Dart
 * `ScreenshotOverlayMode` enum (`lib/src/screenshot/screenshot_overlay_mode.dart`) by name. */
enum class OverlayMode { NONE, BLUR, COLOR, IMAGE }

data class OverlayConfig(
    val mode: OverlayMode,
    val blurRadius: Float,
    val argbColor: Int?,
    val imageBytes: ByteArray?,
)

/**
 * Manages a full-screen, non-secure overlay `View` added to the attached activity's decor view —
 * the same add/removeView-on-decor mechanics as the recents-overlay feature
 * ([com.devamitkumartiwari.device_safety_info.appswitcherprivacy.AppSwitcherPrivacyFeature]).
 *
 * `FLAG_SECURE` makes the OS render nothing at all into a screenshot/recording, so this overlay can
 * never appear *inside* a capture — it only exists as a visible, on-screen effect. It is therefore
 * shown/hidden reactively: [setActive] is driven by [ScreenshotFeature] forwarding
 * capture-state/recording-state transitions from `ScreenCaptureFeature`/`ScreenRecordingFeature`,
 * not by any timer or "always on" logic.
 *
 * All operations are wrapped in try/catch and fail silently (logged via [Log.w]) — this is a
 * cosmetic feature and must never crash the host app.
 */
class ScreenshotOverlayManager(private val host: PluginHost) {

    companion object {
        private const val TAG = "ScreenshotOverlayMgr"
        private const val VIEW_TAG = "dsi_screenshot_overlay"
    }

    private var config: OverlayConfig? = null
    private var visible = false

    /** Stores (or replaces) the desired overlay config. Does not itself change visibility — call
     * [setActive] with the current capture/recording state afterward. */
    fun setConfig(config: OverlayConfig) {
        this.config = config
    }

    /** Removes any on-screen overlay and forgets the configured mode entirely. */
    fun clear() {
        config = null
        hide()
    }

    /** Reactive entry point: show the configured overlay while [active] is true, hide it
     * otherwise. A no-op (and always hidden) when no mode is configured. */
    fun setActive(active: Boolean) {
        if (config == null) {
            hide()
            return
        }
        if (active) show() else hide()
    }

    private fun show() {
        val cfg = config ?: return
        try {
            val act = host.activity ?: return
            val decor = act.window.decorView as? ViewGroup ?: return
            if (decor.findViewWithTag<View>(VIEW_TAG) != null) {
                visible = true
                return
            }
            val overlayView = buildView(act, cfg) ?: return
            overlayView.tag = VIEW_TAG
            decor.addView(
                overlayView,
                ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
            )
            visible = true
        } catch (e: Exception) {
            Log.w(TAG, "Failed to show screenshot overlay: ${e.message}")
        }
    }

    private fun hide() {
        try {
            val decor = host.activity?.window?.decorView as? ViewGroup ?: return
            decor.findViewWithTag<View>(VIEW_TAG)?.let { decor.removeView(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to hide screenshot overlay: ${e.message}")
        } finally {
            visible = false
        }
    }

    private fun buildView(act: Activity, cfg: OverlayConfig): View? = when (cfg.mode) {
        OverlayMode.COLOR -> View(act).apply { setBackgroundColor(cfg.argbColor ?: Color.BLACK) }
        OverlayMode.BLUR -> buildBlurView(act, cfg)
        OverlayMode.IMAGE -> buildImageView(act, cfg)
        OverlayMode.NONE -> null
    }

    // `RenderEffect.createBlurEffect` blurs the *view it's applied to*, not whatever is behind it —
    // there's no "blur what's on screen right now" primitive. The simplest correct approach that
    // actually blurs real on-screen content: snapshot the decor view into a Bitmap, show that
    // snapshot in an ImageView, and apply the RenderEffect blur to the snapshot ImageView. Below
    // API 31 (no RenderEffect at all), degrade to a translucent scrim per the plan's documented,
    // accepted degradation.
    private fun buildBlurView(act: Activity, cfg: OverlayConfig): View {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val decor = act.window.decorView
                if (decor.width > 0 && decor.height > 0) {
                    val bitmap = Bitmap.createBitmap(decor.width, decor.height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bitmap)
                    decor.draw(canvas)
                    return ImageView(act).apply {
                        setImageBitmap(bitmap)
                        scaleType = ImageView.ScaleType.CENTER_CROP
                        setRenderEffect(
                            RenderEffect.createBlurEffect(cfg.blurRadius, cfg.blurRadius, Shader.TileMode.CLAMP)
                        )
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Blur snapshot failed, falling back to scrim: ${e.message}")
            }
        }
        return View(act).apply { setBackgroundColor(Color.argb(180, 128, 128, 128)) }
    }

    private fun buildImageView(act: Activity, cfg: OverlayConfig): View? {
        val bytes = cfg.imageBytes ?: return null
        val bitmap = try {
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to decode overlay image: ${e.message}")
            null
        } ?: return null
        return ImageView(act).apply {
            setImageBitmap(bitmap)
            scaleType = ImageView.ScaleType.CENTER_CROP
            setBackgroundColor(Color.BLACK)
        }
    }
}
