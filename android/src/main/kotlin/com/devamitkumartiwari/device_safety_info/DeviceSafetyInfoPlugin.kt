package com.devamitkumartiwari.device_safety_info

import android.app.Activity
import android.app.Application
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.hardware.display.DisplayManager
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.View
import android.view.ViewGroup
import com.devamitkumartiwari.device_safety_info.accessibility.AccessibilityAbuseDetector
import com.devamitkumartiwari.device_safety_info.callactivity.CallActivityWatcher
import com.devamitkumartiwari.device_safety_info.callscreening.CallScreeningRoleCheck
import com.devamitkumartiwari.device_safety_info.clipboard.ClipboardProtectionManager
import com.devamitkumartiwari.device_safety_info.connectivity.ConnectivityWatcher
import com.devamitkumartiwari.device_safety_info.developmentmode.DevelopmentModeCheck
import com.devamitkumartiwari.device_safety_info.externalstorage.ExternalStorageCheck
import com.devamitkumartiwari.device_safety_info.hooks.HookDetector
import com.devamitkumartiwari.device_safety_info.malware.MalwarePackageDetector
import com.devamitkumartiwari.device_safety_info.notificationlistener.NotificationListenerAbuseDetector
import com.devamitkumartiwari.device_safety_info.overlay.OverlayAttackDetector
import com.devamitkumartiwari.device_safety_info.playprotect.PlayProtectStatusCheck
import com.devamitkumartiwari.device_safety_info.realdevice.RealDeviceCheck
import com.devamitkumartiwari.device_safety_info.rooted.RootedDeviceCheck
import com.devamitkumartiwari.device_safety_info.screencapturedetector.ScreenCaptureDetector
import com.devamitkumartiwari.device_safety_info.screenlock.ScreenLockCheck
import com.devamitkumartiwari.device_safety_info.screenshot.RecentsMenuManager
import com.devamitkumartiwari.device_safety_info.screenshot.ScreenShotManager
import com.devamitkumartiwari.device_safety_info.sideload.UnknownSourcesCheck
import com.devamitkumartiwari.device_safety_info.storeinstallcheck.StoreInstallCheck
import com.devamitkumartiwari.device_safety_info.vpn_check.VpnCheck
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.DataOutputStream
import java.util.concurrent.Executors
import kotlin.system.exitProcess

class DeviceSafetyInfoPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null

    // Background thread pool for checks that spawn shell processes (isRootedDevice,
    // isHooked). Two threads is enough for the two checks that can be in-flight
    // simultaneously. Delivering results on mainHandler satisfies Flutter's threading contract.
    private val bgExecutor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

    // 30-second TTL cache for expensive security checks. Security state doesn't change
    // mid-session on real devices; the short TTL still catches dynamic Frida attachment.
    @Volatile private var cachedRooted: Pair<Boolean, Long>? = null
    @Volatile private var cachedHooked: Pair<Boolean, Long>? = null
    private val cacheTtlMs = 30_000L

    // --- Screen capture stream ---
    private var screenCaptureEventSink: EventChannel.EventSink? = null
    private var displayManager: DisplayManager? = null
    private var displayListener: DisplayManager.DisplayListener? = null

    // --- Screenshot detection stream ---
    private var screenshotEventSink: EventChannel.EventSink? = null
    private var screenshotContentObserver: ContentObserver? = null
    private var api34ScreenshotCallback: Any? = null  // Activity.ScreenshotCallback (API 34+)
    private var api34Executor: java.util.concurrent.ExecutorService? = null

    // --- Recents overlay ---
    private var recentsOverlayCallbacks: Application.ActivityLifecycleCallbacks? = null

    // --- Overlay attack detection ---
    private var overlayEventSink: EventChannel.EventSink? = null
    private var overlayDetector: OverlayAttackDetector? = null

    // --- Clipboard protection ---
    private var clipboardProtectionManager: ClipboardProtectionManager? = null
    private var clipboardEventSink: EventChannel.EventSink? = null
    private var clipboardChangeListener: ClipboardManager.OnPrimaryClipChangedListener? = null

    // --- Connectivity change stream ---
    private var connectivityEventSink: EventChannel.EventSink? = null
    private var connectivityCallback: ConnectivityManager.NetworkCallback? = null

    // --- Call activity stream ---
    private var callActivityEventSink: EventChannel.EventSink? = null
    private var callActivityTelephonyHandle: CallActivityWatcher.TelephonyHandle? = null
    private var callActivityAudioHandle: CallActivityWatcher.AudioCallbackHandle? = null
    private var callActivityPollRunnable: Runnable? = null
    private var callActivityLastActive = false
    private var callActivityLastSource: CallActivityWatcher.Source? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "device_safety_info")
        channel.setMethodCallHandler(this)

        displayManager = context?.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        clipboardProtectionManager = ClipboardProtectionManager(context!!)

        EventChannel(binding.binaryMessenger, "device_safety_info/screen_capture_events")
            .setStreamHandler(screenCaptureStreamHandler)

        EventChannel(binding.binaryMessenger, "device_safety_info/screenshot_events")
            .setStreamHandler(screenshotStreamHandler)

        EventChannel(binding.binaryMessenger, "device_safety_info/overlay_events")
            .setStreamHandler(overlayStreamHandler)

        EventChannel(binding.binaryMessenger, "device_safety_info/clipboard_events")
            .setStreamHandler(clipboardStreamHandler)

        EventChannel(binding.binaryMessenger, "device_safety_info/connectivity_events")
            .setStreamHandler(connectivityStreamHandler)

        EventChannel(binding.binaryMessenger, "device_safety_info/call_activity_events")
            .setStreamHandler(callActivityStreamHandler)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        if (overlayEventSink != null) installOverlayDetector(activity!!)
    }

    override fun onDetachedFromActivity() {
        activity?.let { uninstallOverlayDetector(it) }
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        if (overlayEventSink != null) installOverlayDetector(activity!!)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity?.let { uninstallOverlayDetector(it) }
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val exitIfTrue = call.argument<Boolean>("exitProcessIfTrue") ?: false
        val uninstallIfTrue = call.argument<Boolean>("uninstallIfTrue") ?: false

        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "isRealDevice" -> result.success(RealDeviceCheck.isRealDevice())
            "isExternalStorage" -> result.success(context?.let { ExternalStorageCheck.isExternalStorage(it) })
            "isDeveloperMode" -> result.success(context?.let { DevelopmentModeCheck.isDevMode(it) })
            "isScreenLock" -> result.success(context?.let { ScreenLockCheck.isDeviceScreenLocked(it) })
            "isVPNCheck" -> result.success(context?.let { VpnCheck.isActiveVPN(it) })
            "isInstalledFromStore" -> result.success(context?.let { StoreInstallCheck.isInstalledFromStore(it) })
            "isScreenCaptured" -> result.success(context?.let { ScreenCaptureDetector(it).isScreenBeingCaptured() })
            "isDebuggerAttached" -> result.success(android.os.Debug.isDebuggerConnected())
            "isRootedDevice" -> {
                val now = System.currentTimeMillis()
                val cached = cachedRooted
                if (cached != null && (now - cached.second) < cacheTtlMs) {
                    result.success(cached.first)
                    if (cached.first) handleExitOrUninstall(exitIfTrue, uninstallIfTrue)
                    return
                }
                bgExecutor.execute {
                    val isRooted = RootedDeviceCheck.isRootedDevice()
                    cachedRooted = Pair(isRooted, System.currentTimeMillis())
                    mainHandler.post {
                        result.success(isRooted)
                        if (isRooted) handleExitOrUninstall(exitIfTrue, uninstallIfTrue)
                    }
                }
            }
            "isHooked" -> {
                val now = System.currentTimeMillis()
                val cached = cachedHooked
                if (cached != null && (now - cached.second) < cacheTtlMs) {
                    result.success(cached.first)
                    if (cached.first) handleExitOrUninstall(exitIfTrue, uninstallIfTrue)
                    return
                }
                bgExecutor.execute {
                    val isHooked = HookDetector.check()
                    cachedHooked = Pair(isHooked, System.currentTimeMillis())
                    mainHandler.post {
                        result.success(isHooked)
                        if (isHooked) handleExitOrUninstall(exitIfTrue, uninstallIfTrue)
                    }
                }
            }
            "blockScreenShots" -> {
                val block = call.argument<Boolean>("block") ?: false
                val act = activity ?: run { result.error("NO_ACTIVITY", "Activity not attached", null); return }
                ScreenShotManager.setScreenshotBlock(act, block)
                result.success(null)
            }
            "hideMenu" -> {
                val hide = call.argument<Boolean>("hide") ?: false
                val act = activity ?: run { result.error("NO_ACTIVITY", "Activity not attached", null); return }
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
            "blockTouchesWhenObscured" -> {
                val block = call.argument<Boolean>("block") ?: true
                val act = activity ?: run { result.error("NO_ACTIVITY", "Activity not attached", null); return }
                act.window.decorView.filterTouchesWhenObscured = block
                result.success(null)
            }
            "copyToClipboard" -> {
                val text = call.argument<String>("text") ?: ""
                val sensitive = call.argument<Boolean>("sensitive") ?: true
                val autoClearMillis = call.argument<Int>("autoClearMillis")?.toLong()
                clipboardProtectionManager?.copyToClipboard(text, sensitive, autoClearMillis, mainHandler)
                result.success(null)
            }
            "clearClipboard" -> {
                clipboardProtectionManager?.clearClipboard()
                result.success(null)
            }
            "isPackageInstalled" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName.isNullOrEmpty()) {
                    result.success(false)
                } else {
                    result.success(context?.let {
                        MalwarePackageDetector.isPackageInstalled(it, packageName)
                    } ?: false)
                }
            }
            "getEnabledAccessibilityServices" -> {
                result.success(context?.let {
                    AccessibilityAbuseDetector.getEnabledAccessibilityServices(it)
                } ?: emptyList<String>())
            }
            "getPlayProtectStatus" -> {
                result.success(context?.let { PlayProtectStatusCheck.getStatus(it) } ?: 0)
            }
            "getPackageInfo" -> {
                val ctx = context ?: run { result.error("NO_CONTEXT", "Application context not attached", null); return }
                try {
                    val pInfo = ctx.packageManager.getPackageInfo(ctx.packageName, 0)
                    result.success(mapOf(
                        "packageName" to ctx.packageName,
                        "version" to (pInfo.versionName ?: "0.0.0")
                    ))
                } catch (e: Exception) {
                    result.error("PACKAGE_INFO_ERROR", e.message, null)
                }
            }
            "getEnabledNotificationListeners" -> {
                result.success(context?.let {
                    NotificationListenerAbuseDetector.getEnabledNotificationListeners(it)
                } ?: emptyList<String>())
            }
            "isUnknownSourcesEnabled" -> {
                result.success(context?.let { UnknownSourcesCheck.isUnknownSourcesEnabled(it) } ?: false)
            }
            "isCallScreeningRoleAvailable" -> {
                result.success(context?.let { CallScreeningRoleCheck.isRoleAvailable(it) } ?: false)
            }
            "isCallScreeningRoleHeldByThisApp" -> {
                result.success(context?.let { CallScreeningRoleCheck.isRoleHeldByThisApp(it) } ?: false)
            }
            "openCallScreeningRoleSettings" -> {
                val act = activity ?: run { result.error("NO_ACTIVITY", "Activity not attached", null); return }
                val intent = CallScreeningRoleCheck.createRequestRoleIntent(act)
                if (intent == null) {
                    result.error("UNSUPPORTED", "ROLE_CALL_SCREENING requires API 29+", null)
                } else {
                    act.startActivity(intent)
                    result.success(null)
                }
            }
            "isCallActive" -> {
                result.success(context?.let { CallActivityWatcher.isCallActive(it) } ?: false)
            }
            else -> result.notImplemented()
        }
    }

    // --- Screen capture stream handler ---

    private val screenCaptureStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            screenCaptureEventSink = events
            if (displayListener == null) {
                displayListener = object : DisplayManager.DisplayListener {
                    override fun onDisplayAdded(displayId: Int) = updateScreenCaptureState()
                    override fun onDisplayRemoved(displayId: Int) = updateScreenCaptureState()
                    override fun onDisplayChanged(displayId: Int) {}
                }
                displayManager?.registerDisplayListener(displayListener, null)
                updateScreenCaptureState()
            }
        }

        override fun onCancel(arguments: Any?) {
            screenCaptureEventSink = null
            displayListener?.let { displayManager?.unregisterDisplayListener(it) }
            displayListener = null
        }
    }

    private fun updateScreenCaptureState() {
        val isCaptured = context?.let { ScreenCaptureDetector(it).isScreenBeingCaptured() } ?: false
        screenCaptureEventSink?.success(isCaptured)
    }

    // --- Screenshot detection stream handler ---

    private val screenshotStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            screenshotEventSink = events
            try {
                startScreenshotDetection()
            } catch (e: SecurityException) {
                // DETECT_SCREEN_CAPTURE not granted (e.g. missing from manifest on API 34+).
                // Deliver as stream error so the Dart onError handler catches it instead
                // of propagating through FlutterError and failing the test framework.
                events?.error("permission_denied", e.message, null)
                screenshotEventSink = null
            }
        }

        override fun onCancel(arguments: Any?) {
            stopScreenshotDetection()
            screenshotEventSink = null
        }
    }

    private fun startScreenshotDetection() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startApi34ScreenshotDetection()
        } else {
            startContentObserverDetection()
        }
    }

    @Suppress("NewApi")
    private fun startApi34ScreenshotDetection() {
        val act = activity ?: return
        api34Executor?.shutdown()
        api34Executor = Executors.newSingleThreadExecutor()
        val callback = android.app.Activity.ScreenCaptureCallback {
            screenshotEventSink?.success(null)
        }
        act.registerScreenCaptureCallback(api34Executor!!, callback)
        api34ScreenshotCallback = callback
    }

    private fun startContentObserverDetection() {
        val ctx = context ?: return
        screenshotContentObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                uri?.let { checkIfScreenshot(it) }
            }
        }
        ctx.contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            screenshotContentObserver!!
        )
    }

    private fun checkIfScreenshot(uri: Uri) {
        try {
            val projection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                arrayOf(MediaStore.Images.Media.RELATIVE_PATH)
            } else {
                @Suppress("DEPRECATION")
                arrayOf(MediaStore.Images.Media.DATA)
            }
            context?.contentResolver?.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val path = cursor.getString(0) ?: return
                    if (path.contains("screenshot", ignoreCase = true)) {
                        screenshotEventSink?.success(null)
                    }
                }
            }
        } catch (_: Exception) {}
    }

    private fun stopScreenshotDetection() {
        screenshotContentObserver?.let {
            context?.contentResolver?.unregisterContentObserver(it)
            screenshotContentObserver = null
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            @Suppress("NewApi")
            (api34ScreenshotCallback as? android.app.Activity.ScreenCaptureCallback)?.let { cb ->
                activity?.unregisterScreenCaptureCallback(cb)
            }
            api34ScreenshotCallback = null
        }
        api34Executor?.shutdown()
        api34Executor = null
    }

    // --- Recents overlay ---

    private fun setRecentsOverlay(color: Int) {
        clearRecentsOverlay()
        val app = context?.applicationContext as? Application ?: return

        val callbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityPaused(a: Activity) {
                if (a === activity) addOverlay(a, color)
            }
            override fun onActivityResumed(a: Activity) {
                if (a === activity) removeOverlay(a)
            }
            override fun onActivityDestroyed(a: Activity) {
                if (a === activity) removeOverlay(a)
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
            (context?.applicationContext as? Application)?.unregisterActivityLifecycleCallbacks(it)
        }
        recentsOverlayCallbacks = null
        activity?.let { removeOverlay(it) }
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

    // --- Overlay attack detection stream handler ---

    private val overlayStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            overlayEventSink = events
            activity?.let { installOverlayDetector(it) }
        }

        override fun onCancel(arguments: Any?) {
            overlayEventSink = null
            activity?.let { uninstallOverlayDetector(it) }
        }
    }

    private fun installOverlayDetector(act: Activity) {
        if (overlayDetector != null) return
        overlayDetector = OverlayAttackDetector.install(act) {
            overlayEventSink?.success(null)
        }
    }

    private fun uninstallOverlayDetector(act: Activity) {
        overlayDetector?.let { OverlayAttackDetector.uninstall(act, it) }
        overlayDetector = null
    }

    // --- Clipboard protection stream handler ---

    private val clipboardStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            clipboardEventSink = events
            val listener = ClipboardManager.OnPrimaryClipChangedListener {
                clipboardEventSink?.success(null)
            }
            clipboardChangeListener = listener
            clipboardProtectionManager?.addChangeListener(listener)
        }

        override fun onCancel(arguments: Any?) {
            clipboardChangeListener?.let { clipboardProtectionManager?.removeChangeListener(it) }
            clipboardChangeListener = null
            clipboardEventSink = null
        }
    }

    // --- Connectivity change stream handler ---
    //
    // ConnectivityManager.registerNetworkCallback(request, callback) without a Handler
    // delivers callbacks on a background thread. Since minSdk is 24 but the Handler-accepting
    // overloads require API 26/28, results are posted through mainHandler before touching the
    // EventSink, which must only be called on the main thread.

    private val connectivityStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            connectivityEventSink = events
            val ctx = context ?: return
            connectivityCallback = ConnectivityWatcher.register(ctx) {
                mainHandler.post { connectivityEventSink?.success(null) }
            }
        }

        override fun onCancel(arguments: Any?) {
            connectivityEventSink = null
            connectivityCallback?.let { cb -> context?.let { ConnectivityWatcher.unregister(it, cb) } }
            connectivityCallback = null
        }
    }

    // --- Call activity stream handler ---
    //
    // Three signal sources (telephony push, audio-config push, and a ~2s audio-mode poll safety
    // net for transitions the config-list callbacks miss) all funnel into evaluateAndCallActivity,
    // which diffs against the last-emitted state so near-simultaneous signals for the same call
    // don't double-fire. Everything here only runs between onListen and onCancel — nothing is
    // registered merely because the plugin is bundled.

    private val callActivityStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            callActivityEventSink = events
            val ctx = context ?: return

            callActivityTelephonyHandle =
                CallActivityWatcher.registerTelephony(ctx, mainHandler) { evaluateAndEmitCallActivity() }
            callActivityAudioHandle =
                CallActivityWatcher.registerAudioCallbacks(ctx, mainHandler) { evaluateAndEmitCallActivity() }

            val poll = object : Runnable {
                override fun run() {
                    evaluateAndEmitCallActivity()
                    mainHandler.postDelayed(this, 2000L)
                }
            }
            callActivityPollRunnable = poll
            mainHandler.postDelayed(poll, 2000L)

            evaluateAndEmitCallActivity()
        }

        override fun onCancel(arguments: Any?) {
            callActivityEventSink = null
            CallActivityWatcher.unregisterTelephony(callActivityTelephonyHandle)
            callActivityTelephonyHandle = null
            CallActivityWatcher.unregisterAudioCallbacks(callActivityAudioHandle)
            callActivityAudioHandle = null
            callActivityPollRunnable?.let { mainHandler.removeCallbacks(it) }
            callActivityPollRunnable = null
            callActivityLastActive = false
            callActivityLastSource = null
        }
    }

    private fun evaluateAndEmitCallActivity() {
        val ctx = context ?: return
        val source = CallActivityWatcher.currentSource(ctx)
        val active = source != null

        if (active == callActivityLastActive && source == callActivityLastSource) return

        if (active) {
            callActivityEventSink?.success(mapOf(
                "source" to (if (source == CallActivityWatcher.Source.SIM) "simCall" else "voipCall"),
                "state" to "started",
                "timestamp" to System.currentTimeMillis()
            ))
        } else {
            callActivityEventSink?.success(mapOf(
                "source" to (if (callActivityLastSource == CallActivityWatcher.Source.SIM) "simCall" else "voipCall"),
                "state" to "ended",
                "timestamp" to System.currentTimeMillis()
            ))
        }

        callActivityLastActive = active
        callActivityLastSource = source
    }

    // --- Engine detach cleanup ---

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        cachedRooted = null
        cachedHooked = null
        bgExecutor.shutdown()
        channel.setMethodCallHandler(null)
        displayListener?.let { displayManager?.unregisterDisplayListener(it) }
        displayListener = null
        screenCaptureEventSink = null
        stopScreenshotDetection()
        screenshotEventSink = null
        clearRecentsOverlay()
        activity?.let { uninstallOverlayDetector(it) }
        overlayEventSink = null
        clipboardChangeListener?.let { clipboardProtectionManager?.removeChangeListener(it) }
        clipboardChangeListener = null
        clipboardEventSink = null
        clipboardProtectionManager = null
        connectivityCallback?.let { cb -> context?.let { ConnectivityWatcher.unregister(it, cb) } }
        connectivityCallback = null
        connectivityEventSink = null
        CallActivityWatcher.unregisterTelephony(callActivityTelephonyHandle)
        callActivityTelephonyHandle = null
        CallActivityWatcher.unregisterAudioCallbacks(callActivityAudioHandle)
        callActivityAudioHandle = null
        callActivityPollRunnable?.let { mainHandler.removeCallbacks(it) }
        callActivityPollRunnable = null
        callActivityEventSink = null
    }

    // --- Helpers ---

    private fun handleExitOrUninstall(exitProcessIfTrue: Boolean, uninstallIfTrue: Boolean) {
        if (uninstallIfTrue) {
            launchUninstallIntent()
        } else if (exitProcessIfTrue) {
            activity?.finishAffinity()
            exitProcess(0)
        }
    }

    private fun launchUninstallIntent() {
        try {
            val packageName = context?.packageName ?: return
            context?.startActivity(Intent(Intent.ACTION_DELETE).apply {
                data = Uri.parse("package:$packageName")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            })
        } catch (_: Exception) {}
    }
}
