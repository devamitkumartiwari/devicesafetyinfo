import Flutter
import UIKit

/// Plugin entry point: constructs one instance of each feature handler, wires the single
/// MethodChannel and every EventChannel, and dispatches `handle(_:result:)` by method name over
/// `[DSIMethodHandler]`. All feature-specific logic lives in the per-concern handler files
/// alongside this one — see `PluginHelpers.swift` for the shared dispatch protocol and
/// `IOSScreenCaptureSignal.swift` for the shared screen-capture/recording OS signal.
public class DeviceSafetyInfoPlugin: NSObject, FlutterPlugin {

    // Feature handlers. Stream-backed features keep a single instance so the same object both
    // handles its EventChannel registration and (where applicable) participates in method
    // dispatch below.
    private let rootDetectionHandler = RootDetectionHandler()
    private let screenCaptureHandler = ScreenCaptureHandler()
    private let screenRecordingHandler = ScreenRecordingHandler()
    private let screenshotProtectionHandler = ScreenshotProtectionHandler()
    private let screenshotStreamHandler = ScreenshotEventStreamHandler()
    private let appSwitcherPrivacyHandler = AppSwitcherPrivacyHandler()
    private let overlayAttackHandler = OverlayAttackHandler()
    private let overlayStreamHandler = UnsupportedOverlayStreamHandler()
    private let clipboardProtectionHandler = ClipboardProtectionHandler()
    private let connectivityStreamHandler = ConnectivityEventStreamHandler()
    private let callActivityStreamHandler = CallActivityEventStreamHandler()
    private let vpnHandler = VpnHandler()
    private let deviceEnvironmentHandler = DeviceEnvironmentHandler()
    private let versionCheckHandler = VersionCheckHandler()

    // Flat method-dispatch table, mirroring the Android side's FeatureMethodHandler map. The
    // first handler whose `methods` contains the incoming method name wins.
    private lazy var methodHandlers: [DSIMethodHandler] = [
        rootDetectionHandler,
        screenCaptureHandler,
        screenRecordingHandler,
        screenshotProtectionHandler,
        appSwitcherPrivacyHandler,
        overlayAttackHandler,
        clipboardProtectionHandler,
        vpnHandler,
        deviceEnvironmentHandler,
        versionCheckHandler,
        callActivityStreamHandler,
    ]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "device_safety_info", binaryMessenger: registrar.messenger())
        let instance = DeviceSafetyInfoPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let captureEventChannel = FlutterEventChannel(
            name: "device_safety_info/screen_capture_events",
            binaryMessenger: registrar.messenger())
        captureEventChannel.setStreamHandler(instance.screenCaptureHandler)

        let screenshotEventChannel = FlutterEventChannel(
            name: "device_safety_info/screenshot_events",
            binaryMessenger: registrar.messenger())
        screenshotEventChannel.setStreamHandler(instance.screenshotStreamHandler)

        let screenRecordingEventChannel = FlutterEventChannel(
            name: "device_safety_info/screen_recording_events",
            binaryMessenger: registrar.messenger())
        screenRecordingEventChannel.setStreamHandler(instance.screenRecordingHandler)

        let clipboardEventChannel = FlutterEventChannel(
            name: "device_safety_info/clipboard_events",
            binaryMessenger: registrar.messenger())
        clipboardEventChannel.setStreamHandler(instance.clipboardProtectionHandler)

        let overlayEventChannel = FlutterEventChannel(
            name: "device_safety_info/overlay_events",
            binaryMessenger: registrar.messenger())
        overlayEventChannel.setStreamHandler(instance.overlayStreamHandler)

        let connectivityEventChannel = FlutterEventChannel(
            name: "device_safety_info/connectivity_events",
            binaryMessenger: registrar.messenger())
        connectivityEventChannel.setStreamHandler(instance.connectivityStreamHandler)

        let callActivityEventChannel = FlutterEventChannel(
            name: "device_safety_info/call_activity_events",
            binaryMessenger: registrar.messenger())
        callActivityEventChannel.setStreamHandler(instance.callActivityStreamHandler)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getPlatformVersion" {
            result("iOS " + UIDevice.current.systemVersion)
            return
        }
        guard let handler = methodHandlers.first(where: { $0.methods.contains(call.method) }) else {
            result(FlutterMethodNotImplemented)
            return
        }
        handler.handle(call, result: result)
    }
}
