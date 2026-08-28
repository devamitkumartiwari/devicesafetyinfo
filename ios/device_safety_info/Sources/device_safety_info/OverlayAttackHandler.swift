import Flutter
import Foundation

// Overlay attack detection is structurally impossible on iOS: app sandboxing means no other
// app can ever draw over this app's window (unlike Android's SYSTEM_ALERT_WINDOW). Rather than
// silently returning a default that implies "checked, all clear", calls throw so callers don't
// mistake platform inapplicability for a clean security check.
let unsupportedOverlayError = FlutterError(
    code: "UNSUPPORTED_PLATFORM",
    message: "Overlay attack detection is not applicable on iOS: app sandboxing makes cross-app overlays structurally impossible.",
    details: nil
)

// Without a registered stream handler at all, a Dart .listen() on this channel would hang
// forever with no reply rather than erroring — this makes the unsupported-platform error
// arrive immediately instead.
class UnsupportedOverlayStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        return unsupportedOverlayError
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}

/// `blockTouchesWhenObscured` method case — like overlay-attack detection itself, this is
/// structurally inapplicable on iOS (see `unsupportedOverlayError`).
final class OverlayAttackHandler: DSIMethodHandler {
    let methods: Set<String> = ["blockTouchesWhenObscured"]

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "blockTouchesWhenObscured":
            result(unsupportedOverlayError)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
