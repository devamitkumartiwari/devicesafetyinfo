package com.devamitkumartiwari.device_safety_info.clipboard

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.PersistableBundle

// Wraps ClipboardManager with a "sensitive" copy (hides the system clipboard preview UI on
// API 33+ via ClipDescription.EXTRA_IS_SENSITIVE) and an optional auto-clear timer.
class ClipboardProtectionManager(private val context: Context) {

    private val clipboardManager: ClipboardManager
        get() = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    private var autoClearRunnable: Runnable? = null
    private var autoClearHandler: Handler? = null

    fun copyToClipboard(text: String, sensitive: Boolean, autoClearMillis: Long?, mainHandler: Handler) {
        val clip = ClipData.newPlainText("device_safety_info", text)
        if (sensitive && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            clip.description.extras = PersistableBundle().apply {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            }
        }
        clipboardManager.setPrimaryClip(clip)

        cancelPendingAutoClear()
        if (autoClearMillis != null) {
            val runnable = Runnable { clearClipboard() }
            autoClearRunnable = runnable
            autoClearHandler = mainHandler
            mainHandler.postDelayed(runnable, autoClearMillis)
        }
    }

    fun clearClipboard() {
        cancelPendingAutoClear()
        clipboardManager.setPrimaryClip(ClipData.newPlainText("", ""))
    }

    fun addChangeListener(listener: ClipboardManager.OnPrimaryClipChangedListener) {
        clipboardManager.addPrimaryClipChangedListener(listener)
    }

    fun removeChangeListener(listener: ClipboardManager.OnPrimaryClipChangedListener) {
        clipboardManager.removePrimaryClipChangedListener(listener)
    }

    private fun cancelPendingAutoClear() {
        autoClearRunnable?.let { autoClearHandler?.removeCallbacks(it) }
        autoClearRunnable = null
        autoClearHandler = null
    }
}
