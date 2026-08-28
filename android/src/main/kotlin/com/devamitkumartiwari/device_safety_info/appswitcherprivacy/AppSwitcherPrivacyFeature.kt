package com.devamitkumartiwari.device_safety_info.appswitcherprivacy

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.screenshot.RecentsMenuManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/**
 * `hideMenu` / `setRecentsOverlay` / `clearRecentsOverlay` — recents/app-switcher privacy: hiding
 * the activity's task-switcher thumbnail entirely, or covering it with a solid-color overlay
 * whenever the activity is backgrounded.
 */
class AppSwitcherPrivacyFeature(private val host: PluginHost) : FeatureMethodHandler, Disposable {

    override val methods = setOf("hideMenu", "setRecentsOverlay", "clearRecentsOverlay")

    private var recentsOverlayCallbacks: Application.ActivityLifecycleCallbacks? = null

    override fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "hideMenu" -> {
                val hide = call.argument<Boolean>("hide") ?: false
                val act = host.activity ?: run { result.error("NO_ACTIVITY", "Activity not attached", null); return }
                RecentsMenuManager.setRecentsMenuHidden(act, hide)
                result.success(null)
            }
            "setRecentsOverlay" -> {
                val color = call.argument<Int>("color") ?: 0xFF000000.toInt()
                setRecentsOverlay(color)
                result.success(null)
            }
            "clearRecentsOverlay" -> {
                clearRecentsOverlay()
                result.success(null)
            }
        }
    }

    private fun setRecentsOverlay(color: Int) {
        clearRecentsOverlay()
        val app = host.context?.applicationContext as? Application ?: return

        val callbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityPaused(a: Activity) {
                if (a === host.activity) addOverlay(a, color)
            }
            override fun onActivityResumed(a: Activity) {
                if (a === host.activity) removeOverlay(a)
            }
            override fun onActivityDestroyed(a: Activity) {
                if (a === host.activity) removeOverlay(a)
            }
            override fun onActivityCreated(a: Activity, b: Bundle?) {}
            override fun onActivityStarted(a: Activity) {}
            override fun onActivityStopped(a: Activity) {}
            override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
        }
        app.registerActivityLifecycleCallbacks(callbacks)
        recentsOverlayCallbacks = callbacks
    }

    private fun clearRecentsOverlay() {
        recentsOverlayCallbacks?.let {
            (host.context?.applicationContext as? Application)?.unregisterActivityLifecycleCallbacks(it)
        }
        recentsOverlayCallbacks = null
        host.activity?.let { removeOverlay(it) }
    }

    private fun addOverlay(act: Activity, color: Int) {
        val decor = act.window.decorView as? ViewGroup ?: return
        if (decor.findViewWithTag<View>("dsi_overlay") != null) return
        decor.addView(View(act).apply {
            tag = "dsi_overlay"
            setBackgroundColor(color)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        })
    }

    private fun removeOverlay(act: Activity) {
        val decor = act.window.decorView as? ViewGroup ?: return
        decor.findViewWithTag<View>("dsi_overlay")?.let { decor.removeView(it) }
    }

    override fun dispose() {
        clearRecentsOverlay()
    }
}
