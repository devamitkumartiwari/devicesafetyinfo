import Flutter
import UIKit

/// Stream handler for `screen_capture_events` plus the `isScreenCaptured` method call. Backed by
/// `UIScreen.isCaptured` / `capturedDidChangeNotification` via the shared `IOSScreenCaptureSignal`
/// — see that file's docs for why the OS observer is centralized there rather than registered
/// independently by every feature that needs this signal.
final class ScreenCaptureHandler: NSObject, FlutterStreamHandler, DSIMethodHandler {
    let methods: Set<String> = ["isScreenCaptured"]

    private var eventSink: FlutterEventSink?
    private var listenerToken: UUID?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isScreenCaptured":
            result(IOSScreenCaptureSignal.shared.isCaptured)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        listenerToken = IOSScreenCaptureSignal.shared.addListener { [weak self] captured in
            self?.eventSink?(captured)
        }
        events(IOSScreenCaptureSignal.shared.isCaptured)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let token = listenerToken {
            IOSScreenCaptureSignal.shared.removeListener(token)
        }
        listenerToken = nil
        eventSink = nil
        return nil
    }
}
