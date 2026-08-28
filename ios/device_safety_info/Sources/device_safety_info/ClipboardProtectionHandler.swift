import Flutter
import MobileCoreServices
import UIKit

/// Stream handler for `clipboard_events` plus the `copyToClipboard`/`clearClipboard` method calls.
///
/// UIPasteboard.setItems(_:options:) natively supports .expirationDate and .localOnly —
/// "sensitive, auto-clearing copy" maps directly onto a first-class OS API here, unlike
/// Android where EXTRA_IS_SENSITIVE only affects the preview UI (API 33+).
class ClipboardProtectionHandler: NSObject, FlutterStreamHandler, DSIMethodHandler {
    let methods: Set<String> = ["copyToClipboard", "clearClipboard"]

    private var eventSink: FlutterEventSink?
    private var clipboardAutoClearWorkItem: DispatchWorkItem?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
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
}
