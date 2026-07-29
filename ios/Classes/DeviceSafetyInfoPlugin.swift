import Flutter
import UIKit
import IOSSecuritySuite
import LocalAuthentication
import Foundation
import MobileCoreServices

// Direct reference to the C-level debugger check compiled from DeviceSafetyFfi.c.
// Using @_silgen_name avoids the need for a bridging header (required for SPM).
@_silgen_name("dsi_is_debugger_attached")
private func dsi_is_debugger_attached() -> Int32

// Separate stream handler for screenshot detection events.
// A class can only conform to FlutterStreamHandler once, so we use a dedicated object.
private class ScreenshotEventStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        eventSink = nil
        return nil
    }

    @objc private func onScreenshot() {
        eventSink?(nil)
    }
}

// Separate stream handler for clipboard change events.
private class ClipboardEventStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onClipboardChanged),
            name: UIPasteboard.changedNotification,
            object: nil
        )
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(
            self, name: UIPasteboard.changedNotification, object: nil)
        eventSink = nil
        return nil
    }

    @objc private func onClipboardChanged() {
        eventSink?(nil)
    }
}

// Overlay attack detection is structurally impossible on iOS: app sandboxing means no other
// app can ever draw over this app's window (unlike Android's SYSTEM_ALERT_WINDOW). Rather than
// silently returning a default that implies "checked, all clear", calls throw so callers don't
// mistake platform inapplicability for a clean security check.
private let unsupportedOverlayError = FlutterError(
    code: "UNSUPPORTED_PLATFORM",
    message: "Overlay attack detection is not applicable on iOS: app sandboxing makes cross-app overlays structurally impossible.",
    details: nil
)

// Without a registered stream handler at all, a Dart .listen() on this channel would hang
// forever with no reply rather than erroring — this makes the unsupported-platform error
// arrive immediately instead.
private class UnsupportedOverlayStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        return unsupportedOverlayError
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}

public class DeviceSafetyInfoPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    // Set for O(1) prefix-lookup performance
    private let vpnProtocolsKeysIdentifiers: Set<String> = [
        "tap", "tun", "ppp", "ipsec", "utun",
    ]

    private var eventSink: FlutterEventSink?

    // Kept alive for the lifetime of the plugin instance so the EventChannel
    // retains its stream handler and screenshot events keep firing.
    private let screenshotStreamHandler = ScreenshotEventStreamHandler()

    // Kept alive for the lifetime of the plugin instance, same reasoning as screenshotStreamHandler.
    private let clipboardStreamHandler = ClipboardEventStreamHandler()
    private let overlayStreamHandler = UnsupportedOverlayStreamHandler()

    // --- Screenshot blocking (UITextField isSecureTextEntry layer trick) ---
    private var secureTextField: UITextField?
    private var secureWindowOriginalSuperLayer: CALayer?

    // --- Recents overlay ---
    private var recentsOverlayView: UIView?
    private var recentsOverlayColor: UIColor = .black

    // --- Clipboard protection ---
    private var clipboardAutoClearWorkItem: DispatchWorkItem?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "device_safety_info", binaryMessenger: registrar.messenger())
        let instance = DeviceSafetyInfoPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let captureEventChannel = FlutterEventChannel(
            name: "device_safety_info/screen_capture_events",
            binaryMessenger: registrar.messenger())
        captureEventChannel.setStreamHandler(instance)

        let screenshotEventChannel = FlutterEventChannel(
            name: "device_safety_info/screenshot_events",
            binaryMessenger: registrar.messenger())
        screenshotEventChannel.setStreamHandler(instance.screenshotStreamHandler)

        let clipboardEventChannel = FlutterEventChannel(
            name: "device_safety_info/clipboard_events",
            binaryMessenger: registrar.messenger())
        clipboardEventChannel.setStreamHandler(instance.clipboardStreamHandler)

        let overlayEventChannel = FlutterEventChannel(
            name: "device_safety_info/overlay_events",
            binaryMessenger: registrar.messenger())
        overlayEventChannel.setStreamHandler(instance.overlayStreamHandler)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "isRootedDevice":
            result(IOSSecuritySuite.amIJailbroken())
        case "isRealDevice":
            result(!IOSSecuritySuite.amIRunInEmulator())
        case "isScreenLock":
            let context = LAContext()
            result(context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil))
        case "isVPNCheck":
            result(isVpnActive())
        case "isInstalledFromStore":
            result(isInstalledFromStoreInternal())
        case "isScreenCaptured":
            result(currentScreenCaptured())
        case "isHooked":
            result(IOSSecuritySuite.amIReverseEngineered())
        case "isDeveloperMode":
            // Developer mode state is not readable via public iOS API.
            result(false)
        case "blockScreenShots":
            let block = (call.arguments as? [String: Any])?["block"] as? Bool ?? false
            if block {
                enableScreenshotBlocking()
            } else {
                disableScreenshotBlocking()
            }
            result(true)
        case "hideMenu":
            // App switching/recents visibility is not controllable on iOS.
            result(false)
        case "isExternalStorage":
            // External storage in the Android sense does not exist on iOS.
            result(false)
        case "isDebuggerAttached":
            // Combine native sysctl C check with IOSSecuritySuite for best coverage.
            let cCheck = dsi_is_debugger_attached() != 0
            let suiteCheck = IOSSecuritySuite.amIDebugged()
            result(cCheck || suiteCheck)
        case "setRecentsOverlay":
            let colorInt = (call.arguments as? [String: Any])?["color"] as? Int ?? Int(bitPattern: 0xFF000000)
            recentsOverlayColor = uiColor(fromARGB: colorInt)
            registerRecentsOverlayObservers()
            result(nil)
        case "clearRecentsOverlay":
            unregisterRecentsOverlayObservers()
            hideRecentsOverlay()
            result(nil)
        case "blockTouchesWhenObscured":
            // Overlay attacks are structurally impossible on iOS (see unsupportedOverlayError).
            result(unsupportedOverlayError)
        case "copyToClipboard":
            let args = call.arguments as? [String: Any]
            let text = args?["text"] as? String ?? ""
            let autoClearMillis = args?["autoClearMillis"] as? Int
            copyToClipboard(text, autoClearMillis: autoClearMillis)
            result(nil)
        case "clearClipboard":
            clearClipboard()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Screen capture stream (FlutterStreamHandler)

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        if #available(iOS 11.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onScreenCaptureChanged),
                name: UIScreen.capturedDidChangeNotification,
                object: nil
            )
            events(currentScreenCaptured())
        } else {
            events(false)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        if #available(iOS 11.0, *) {
            NotificationCenter.default.removeObserver(
                self, name: UIScreen.capturedDidChangeNotification, object: nil)
        }
        return nil
    }

    @objc private func onScreenCaptureChanged() {
        eventSink?(currentScreenCaptured())
    }

    // Returns the current screen capture state, using the scene-based API on iOS 16+
    // and falling back to UIScreen.main on iOS 11–15.
    private func currentScreenCaptured() -> Bool {
        if #available(iOS 16.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.screen.isCaptured ?? false
        } else if #available(iOS 11.0, *) {
            return UIScreen.main.isCaptured
        }
        return false
    }

    // MARK: - VPN check

    func isVpnActive() -> Bool {
        guard let cfDict = CFNetworkCopySystemProxySettings() else { return false }
        let nsDict = cfDict.takeRetainedValue() as NSDictionary
        guard let keys = nsDict["__SCOPED__"] as? NSDictionary,
              let allKeys = keys.allKeys as? [String]
        else { return false }
        return allKeys.contains { key in
            vpnProtocolsKeysIdentifiers.contains { key.starts(with: $0) }
        }
    }

    // MARK: - Store install check

    private func isInstalledFromStoreInternal() -> Bool {
        #if targetEnvironment(simulator)
            return false
        #else
            #if DEBUG
                return false
            #else
                guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
                    return false
                }
                let path = appStoreReceiptURL.path
                // sandboxReceipt = TestFlight, receipt = App Store
                return path.contains("sandboxReceipt") || path.contains("receipt")
            #endif
        #endif
    }

    // MARK: - Screenshot blocking (UITextField isSecureTextEntry trick)
    //
    // Re-parents the key window's CALayer into the secure sublayer of a UITextField
    // with isSecureTextEntry = true. The system prevents that secure layer's
    // contents from appearing in screenshots and screen recordings.

    private func enableScreenshotBlocking() {
        guard secureTextField == nil, let window = keyWindow else { return }

        let field = UITextField()
        field.isSecureTextEntry = true

        secureWindowOriginalSuperLayer = window.layer.superlayer
        window.addSubview(field)

        // The last sublayer of the text field's layer is the protected secure layer.
        if let secureSubLayer = field.layer.sublayers?.last {
            secureSubLayer.addSublayer(window.layer)
        }
        secureTextField = field
    }

    private func disableScreenshotBlocking() {
        guard let field = secureTextField else { return }

        // Restore the window layer to its original parent so it stays visible.
        if let originalParent = secureWindowOriginalSuperLayer {
            originalParent.addSublayer(keyWindow?.layer ?? CALayer())
        }
        field.removeFromSuperview()
        secureTextField = nil
        secureWindowOriginalSuperLayer = nil
    }

    // MARK: - Recents overlay

    private func registerRecentsOverlayObservers() {
        // Remove first to avoid duplicate registrations.
        NotificationCenter.default.removeObserver(
            self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: UIApplication.didBecomeActiveNotification, object: nil)

        NotificationCenter.default.addObserver(
            self, selector: #selector(showRecentsOverlay),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(hideRecentsOverlay),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    private func unregisterRecentsOverlayObservers() {
        NotificationCenter.default.removeObserver(
            self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func showRecentsOverlay() {
        guard let window = keyWindow else { return }
        hideRecentsOverlay()
        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = recentsOverlayColor
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.tag = 998
        window.addSubview(overlay)
        recentsOverlayView = overlay
    }

    @objc private func hideRecentsOverlay() {
        recentsOverlayView?.removeFromSuperview()
        recentsOverlayView = nil
    }

    // MARK: - Clipboard protection
    //
    // UIPasteboard.setItems(_:options:) natively supports .expirationDate and .localOnly —
    // "sensitive, auto-clearing copy" maps directly onto a first-class OS API here, unlike
    // Android where EXTRA_IS_SENSITIVE only affects the preview UI (API 33+).

    private func copyToClipboard(_ text: String, autoClearMillis: Int?) {
        clipboardAutoClearWorkItem?.cancel()
        clipboardAutoClearWorkItem = nil

        var options: [UIPasteboard.OptionsKey: Any] = [.localOnly: true]
        if let millis = autoClearMillis {
            options[.expirationDate] = Date().addingTimeInterval(TimeInterval(millis) / 1000)
        }
        UIPasteboard.general.setItems([[kUTTypePlainText as String: text]], options: options)

        if let millis = autoClearMillis {
            let workItem = DispatchWorkItem { [weak self] in self?.clearClipboard() }
            clipboardAutoClearWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(millis), execute: workItem)
        }
    }

    private func clearClipboard() {
        clipboardAutoClearWorkItem?.cancel()
        clipboardAutoClearWorkItem = nil
        UIPasteboard.general.items = []
    }

    // MARK: - Helpers

    private var keyWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first(where: { $0.isKeyWindow })
        } else {
            return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        }
    }

    private func uiColor(fromARGB value: Int) -> UIColor {
        let a = CGFloat((value >> 24) & 0xFF) / 255.0
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8)  & 0xFF) / 255.0
        let b = CGFloat( value        & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
