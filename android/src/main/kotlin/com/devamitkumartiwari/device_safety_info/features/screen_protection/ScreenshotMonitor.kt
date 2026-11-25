package com.devamitkumartiwari.device_safety_info.features.screen_protection

import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.generated.PigeonEventSink
import com.devamitkumartiwari.device_safety_info.generated.ScreenshotTakenStreamHandler
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Reports screenshots: Activity.ScreenCaptureCallback on Android 14+, otherwise a MediaStore
 * observer that matches "screenshot" in new image paths.
 */
class ScreenshotMonitor(private val host: PluginHost) : ScreenshotTakenStreamHandler(), Disposable {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: PigeonEventSink<Long>? = null
    private var contentObserver: ContentObserver? = null
    private var api34Callback: Any? = null // Activity.ScreenCaptureCallback
    private var api34Executor: ExecutorService? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<Long>) {
        this.sink = sink
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) startApi34() else startObserver()
        } catch (e: SecurityException) {
            sink.error("permission_denied", e.message, null)
        }
    }

    override fun onCancel(p0: Any?) = dispose()

    private fun emit() {
        mainHandler.post { sink?.success(System.currentTimeMillis()) }
    }

    @Suppress("NewApi")
    private fun startApi34() {
        val act = host.activity ?: return
        val executor = Executors.newSingleThreadExecutor()
        val callback = android.app.Activity.ScreenCaptureCallback { emit() }
        act.registerScreenCaptureCallback(executor, callback)
        api34Executor = executor
        api34Callback = callback
    }

    private fun startObserver() {
        val ctx = host.context ?: return
        val observer = object : ContentObserver(mainHandler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                uri?.let { checkIfScreenshot(it) }
            }
        }
        ctx.contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true, observer,
        )
        contentObserver = observer
    }

    private fun checkIfScreenshot(uri: Uri) {
        try {
            val projection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                arrayOf(MediaStore.Images.Media.RELATIVE_PATH)
            } else {
                @Suppress("DEPRECATION")
                arrayOf(MediaStore.Images.Media.DATA)
            }
            host.context?.contentResolver?.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val path = cursor.getString(0) ?: return
                    if (path.contains("screenshot", ignoreCase = true)) emit()
                }
            }
        } catch (_: Exception) {
        }
    }

    override fun dispose() {
        contentObserver?.let { host.context?.contentResolver?.unregisterContentObserver(it) }
        contentObserver = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            @Suppress("NewApi")
            (api34Callback as? android.app.Activity.ScreenCaptureCallback)?.let {
                try {
                    host.activity?.unregisterScreenCaptureCallback(it)
                } catch (_: Exception) {
                }
            }
        }
        api34Callback = null
        api34Executor?.shutdown()
        api34Executor = null
        sink = null
    }
}
