package com.devamitkumartiwari.device_safety_info

import android.app.Activity
import android.content.Context
import com.devamitkumartiwari.device_safety_info.core.BackgroundRunner
import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.features.app_info.AppInfoHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.app_integrity.IntegrityHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.app_switcher.AppSwitcherHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.batch.BatchHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.call.CallActivityMonitor
import com.devamitkumartiwari.device_safety_info.features.call.CallHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.clipboard.ClipboardChangeMonitor
import com.devamitkumartiwari.device_safety_info.features.clipboard.ClipboardHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.hooking.HookingHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.malware.MalwareHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.overlay_attack.OverlayAttackHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.overlay_attack.OverlayAttackMonitor
import com.devamitkumartiwari.device_safety_info.features.environment.EnvironmentHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.posture.PostureHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.root.RootHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.screen_protection.ScreenCaptureMonitor
import com.devamitkumartiwari.device_safety_info.features.screen_protection.ScreenProtectionHostApiImpl
import com.devamitkumartiwari.device_safety_info.features.screen_protection.ScreenRecordingMonitor
import com.devamitkumartiwari.device_safety_info.features.screen_protection.ScreenshotMonitor
import com.devamitkumartiwari.device_safety_info.features.vpn.VpnChangeMonitor
import com.devamitkumartiwari.device_safety_info.features.vpn.VpnHostApiImpl
import com.devamitkumartiwari.device_safety_info.generated.AppInfoHostApi
import com.devamitkumartiwari.device_safety_info.generated.AppSwitcherHostApi
import com.devamitkumartiwari.device_safety_info.generated.BatchHostApi
import com.devamitkumartiwari.device_safety_info.generated.CallActivityStreamHandler
import com.devamitkumartiwari.device_safety_info.generated.CallHostApi
import com.devamitkumartiwari.device_safety_info.generated.ClipboardChangedStreamHandler
import com.devamitkumartiwari.device_safety_info.generated.ClipboardHostApi
import com.devamitkumartiwari.device_safety_info.generated.HookingHostApi
import com.devamitkumartiwari.device_safety_info.generated.IntegrityHostApi
import com.devamitkumartiwari.device_safety_info.generated.MalwareHostApi
import com.devamitkumartiwari.device_safety_info.generated.OverlayAttackHostApi
import com.devamitkumartiwari.device_safety_info.generated.OverlayAttackStreamHandler
import com.devamitkumartiwari.device_safety_info.generated.EnvironmentHostApi
import com.devamitkumartiwari.device_safety_info.generated.PostureHostApi
import com.devamitkumartiwari.device_safety_info.generated.RootHostApi
import com.devamitkumartiwari.device_safety_info.generated.ScreenCaptureChangedStreamHandler
import com.devamitkumartiwari.device_safety_info.generated.ScreenProtectionHostApi
import com.devamitkumartiwari.device_safety_info.generated.ScreenRecordingChangedStreamHandler
import com.devamitkumartiwari.device_safety_info.generated.ScreenshotTakenStreamHandler
import com.devamitkumartiwari.device_safety_info.generated.VpnChangedStreamHandler
import com.devamitkumartiwari.device_safety_info.generated.VpnHostApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger

/**
 * Plugin entry point. Only wires the Pigeon host APIs and event streams to their feature
 * implementations and forwards activity lifecycle; all logic lives under `features/`.
 *
 * The plugin never terminates or uninstalls the app. Detection results go to Dart, where the
 * app decides what to do.
 */
class DeviceSafetyInfoPlugin : FlutterPlugin, ActivityAware, PluginHost {

    override var context: Context? = null
        private set
    override var activity: Activity? = null
        private set

    private var messenger: BinaryMessenger? = null
    private var bg: BackgroundRunner? = null
    private var disposables: List<Disposable> = emptyList()
    private var overlayMonitor: OverlayAttackMonitor? = null
    private var recordingMonitor: ScreenRecordingMonitor? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        val m = binding.binaryMessenger
        messenger = m
        val runner = BackgroundRunner().also { bg = it }

        val capture = ScreenCaptureMonitor(this)
        val recording = ScreenRecordingMonitor(this).also { recordingMonitor = it }
        val screenshots = ScreenshotMonitor(this)
        val screen = ScreenProtectionHostApiImpl(this, capture, recording)
        val appSwitcher = AppSwitcherHostApiImpl(this)
        val clipboard = ClipboardHostApiImpl(this)
        val clipboardChanges = ClipboardChangeMonitor(clipboard)
        val overlay = OverlayAttackMonitor(this).also { overlayMonitor = it }
        val vpnChanges = VpnChangeMonitor(this)
        val calls = CallActivityMonitor(this)
        val integrity = IntegrityHostApiImpl(this)

        RootHostApi.setUp(m, RootHostApiImpl(this, runner))
        HookingHostApi.setUp(m, HookingHostApiImpl(this, runner))
        PostureHostApi.setUp(m, PostureHostApiImpl(this, runner))
        EnvironmentHostApi.setUp(m, EnvironmentHostApiImpl(this, runner))
        BatchHostApi.setUp(m, BatchHostApiImpl(this, runner, recording))
        VpnHostApi.setUp(m, VpnHostApiImpl(this, runner))
        MalwareHostApi.setUp(m, MalwareHostApiImpl(this, runner))
        ScreenProtectionHostApi.setUp(m, screen)
        AppSwitcherHostApi.setUp(m, appSwitcher)
        ClipboardHostApi.setUp(m, clipboard)
        OverlayAttackHostApi.setUp(m, OverlayAttackHostApiImpl(this))
        CallHostApi.setUp(m, CallHostApiImpl(this))
        AppInfoHostApi.setUp(m, AppInfoHostApiImpl(this, runner))
        IntegrityHostApi.setUp(m, integrity)

        ScreenshotTakenStreamHandler.register(m, screenshots)
        ScreenCaptureChangedStreamHandler.register(m, capture)
        ScreenRecordingChangedStreamHandler.register(m, recording)
        OverlayAttackStreamHandler.register(m, overlay)
        ClipboardChangedStreamHandler.register(m, clipboardChanges)
        VpnChangedStreamHandler.register(m, vpnChanges)
        CallActivityStreamHandler.register(m, calls)

        disposables = listOf(
            screen, capture, recording, screenshots, appSwitcher, clipboardChanges, clipboard,
            overlay, vpnChanges, calls, integrity,
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        disposables.forEach { runCatching { it.dispose() } }
        disposables = emptyList()
        messenger?.let { m ->
            RootHostApi.setUp(m, null)
            HookingHostApi.setUp(m, null)
            PostureHostApi.setUp(m, null)
            EnvironmentHostApi.setUp(m, null)
            BatchHostApi.setUp(m, null)
            VpnHostApi.setUp(m, null)
            MalwareHostApi.setUp(m, null)
            ScreenProtectionHostApi.setUp(m, null)
            AppSwitcherHostApi.setUp(m, null)
            ClipboardHostApi.setUp(m, null)
            OverlayAttackHostApi.setUp(m, null)
            CallHostApi.setUp(m, null)
            AppInfoHostApi.setUp(m, null)
            IntegrityHostApi.setUp(m, null)
        }
        bg?.shutdown()
        bg = null
        messenger = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onDetachedFromActivity() = detach()

    private fun attach(binding: ActivityPluginBinding) {
        activity = binding.activity
        overlayMonitor?.onActivityAttached()
        recordingMonitor?.onActivityAttached()
    }

    private fun detach() {
        overlayMonitor?.onActivityDetached()
        recordingMonitor?.onActivityDetached()
        activity = null
    }
}
