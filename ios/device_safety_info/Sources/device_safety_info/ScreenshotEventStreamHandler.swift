import Flutter
import UIKit

/// Stream handler for `screenshot_events` (fires whenever the user takes a screenshot).
/// A class can only conform to FlutterStreamHandler once, so we use a dedicated object rather than
/// the plugin itself.
class ScreenshotEventStreamHandler: NSObject, FlutterStreamHandler {
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
