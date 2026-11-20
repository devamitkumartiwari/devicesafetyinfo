import Flutter
import UIKit

/// Plugin entry point. Only wires the Pigeon host APIs and event streams to their feature
/// implementations; all logic lives under `Features/`.
///
/// The plugin never terminates the app. Detection results go to Dart, where the app decides
/// what to do.
public class DeviceSafetyInfoPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let m = registrar.messenger()

        RootHostApiSetup.setUp(binaryMessenger: m, api: RootHostApiImpl())
        HookingHostApiSetup.setUp(binaryMessenger: m, api: HookingHostApiImpl())
        PostureHostApiSetup.setUp(binaryMessenger: m, api: PostureHostApiImpl())
        EnvironmentHostApiSetup.setUp(binaryMessenger: m, api: EnvironmentHostApiImpl())
        BatchHostApiSetup.setUp(binaryMessenger: m, api: BatchHostApiImpl())
        VpnHostApiSetup.setUp(binaryMessenger: m, api: VpnHostApiImpl())
        MalwareHostApiSetup.setUp(binaryMessenger: m, api: MalwareHostApiImpl())
        ScreenProtectionHostApiSetup.setUp(binaryMessenger: m, api: ScreenProtectionHostApiImpl())
        AppSwitcherHostApiSetup.setUp(binaryMessenger: m, api: AppSwitcherHostApiImpl())
        ClipboardHostApiSetup.setUp(binaryMessenger: m, api: ClipboardHostApiImpl())
        OverlayAttackHostApiSetup.setUp(binaryMessenger: m, api: OverlayAttackHostApiImpl())
        CallHostApiSetup.setUp(binaryMessenger: m, api: CallHostApiImpl())
        AppInfoHostApiSetup.setUp(binaryMessenger: m, api: AppInfoHostApiImpl())
        IntegrityHostApiSetup.setUp(binaryMessenger: m, api: IntegrityHostApiImpl())

        ScreenshotTakenStreamHandler.register(with: m, streamHandler: ScreenshotMonitor())
        ScreenCaptureChangedStreamHandler.register(with: m, streamHandler: ScreenCaptureMonitor())
        ScreenRecordingChangedStreamHandler.register(with: m, streamHandler: ScreenRecordingMonitor())
        OverlayAttackStreamHandler.register(with: m, streamHandler: OverlayAttackMonitor())
        ClipboardChangedStreamHandler.register(with: m, streamHandler: ClipboardChangeMonitor())
        VpnChangedStreamHandler.register(with: m, streamHandler: VpnChangeMonitor())
        CallActivityStreamHandler.register(with: m, streamHandler: CallActivityMonitor())
    }
}
