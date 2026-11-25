package com.devamitkumartiwari.device_safety_info.core

import android.app.Activity
import android.content.Context

/**
 * The slice of [DeviceSafetyInfoPlugin]'s state that individual feature classes need: the current
 * application context and (when attached) the foreground activity. Both are read live off the
 * plugin on every access rather than snapshotted, since activity attachment can change (config
 * changes, detach/reattach) independently of a feature's own lifecycle.
 */
interface PluginHost {
    val context: Context?
    val activity: Activity?
}

/** The application context, or a [com.devamitkumartiwari.device_safety_info.generated.FlutterError]
 *  if the plugin isn't attached. */
fun PluginHost.requireContext(): Context =
    context ?: throw com.devamitkumartiwari.device_safety_info.generated.FlutterError(
        "NO_CONTEXT", "Application context not attached",
    )

/** The foreground activity, or a FlutterError if none is attached. */
fun PluginHost.requireActivity(): Activity =
    activity ?: throw com.devamitkumartiwari.device_safety_info.generated.FlutterError(
        "NO_ACTIVITY", "Activity not attached",
    )
