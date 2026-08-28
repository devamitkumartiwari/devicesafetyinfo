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
