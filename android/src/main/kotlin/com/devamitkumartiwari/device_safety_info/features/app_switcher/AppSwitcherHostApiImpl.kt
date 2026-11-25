package com.devamitkumartiwari.device_safety_info.features.app_switcher

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.requireActivity
import com.devamitkumartiwari.device_safety_info.generated.AppSwitcherHostApi

/**
 * Hides app content in the recents (app switcher) screen: either by excluding the task from
 * recents, or by covering the activity with a solid color while it's paused, which is when the
 * system takes the recents snapshot.
 */
class AppSwitcherHostApiImpl(private val host: PluginHost) : AppSwitcherHostApi, Disposable {

    private var callbacks: Application.ActivityLifecycleCallbacks? = null

    override fun hideFromRecents(hide: Boolean) {
        RecentsMenuManager.setRecentsMenuHidden(host.requireActivity(), hide)
    }

    override fun setRecentsOverlay(argb: Long) {
        clearRecentsOverlay()
        val app = host.context?.applicationContext as? Application ?: return
        val color = argb.toInt()
        val cb = object : Application.ActivityLifecycleCallbacks {
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
        app.registerActivityLifecycleCallbacks(cb)
        callbacks = cb
    }

    override fun clearRecentsOverlay() {
        callbacks?.let {
            (host.context?.applicationContext as? Application)?.unregisterActivityLifecycleCallbacks(it)
        }
        callbacks = null
        host.activity?.let { removeOverlay(it) }
    }

    private fun addOverlay(act: Activity, color: Int) {
        val decor = act.window.decorView as? ViewGroup ?: return
        if (decor.findViewWithTag<View>(TAG) != null) return
        decor.addView(View(act).apply {
            tag = TAG
            setBackgroundColor(color)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        })
    }

    private fun removeOverlay(act: Activity) {
        val decor = act.window.decorView as? ViewGroup ?: return
        decor.findViewWithTag<View>(TAG)?.let { decor.removeView(it) }
    }

    override fun dispose() = clearRecentsOverlay()

    private companion object {
        const val TAG = "dsi_overlay"
    }
}
