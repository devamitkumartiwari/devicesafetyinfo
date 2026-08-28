package com.devamitkumartiwari.device_safety_info.overlay

import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/**
 * `blockTouchesWhenObscured` method + `overlay_events` stream (tapjacking/overlay-attack
 * detection, wrapping [OverlayAttackDetector]).
 *
 * The detector is installed against the live Activity, so it needs to be reinstalled whenever the
 * activity attaches/reattaches and uninstalled on detach — the plugin's `ActivityAware` callbacks
 * call [onActivityAttached]/[onActivityDetached] to drive this.
 */
class OverlayAttackFeature(private val host: PluginHost) :
    FeatureMethodHandler, EventChannel.StreamHandler, Disposable {

    override val methods = setOf("blockTouchesWhenObscured")

    private var eventSink: EventChannel.EventSink? = null
    private var overlayDetector: OverlayAttackDetector? = null

    override fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "blockTouchesWhenObscured" -> {
                val block = call.argument<Boolean>("block") ?: true
                val act = host.activity ?: run { result.error("NO_ACTIVITY", "Activity not attached", null); return }
                act.window.decorView.filterTouchesWhenObscured = block
                result.success(null)
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        host.activity?.let { installOverlayDetector(it) }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        host.activity?.let { uninstallOverlayDetector(it) }
    }

    /** Called by the plugin's ActivityAware callbacks when an activity attaches (or reattaches). */
    fun onActivityAttached() {
        if (eventSink != null) host.activity?.let { installOverlayDetector(it) }
    }

    /** Called by the plugin's ActivityAware callbacks when the activity detaches — must be called
     * before the plugin nulls out its `activity` reference, since this reads [PluginHost.activity]. */
    fun onActivityDetached() {
        host.activity?.let { uninstallOverlayDetector(it) }
    }

    private fun installOverlayDetector(act: android.app.Activity) {
        if (overlayDetector != null) return
        overlayDetector = OverlayAttackDetector.install(act) {
            eventSink?.success(null)
        }
    }

    private fun uninstallOverlayDetector(act: android.app.Activity) {
        overlayDetector?.let { OverlayAttackDetector.uninstall(act, it) }
        overlayDetector = null
    }

    override fun dispose() {
        host.activity?.let { uninstallOverlayDetector(it) }
        eventSink = null
    }
}
