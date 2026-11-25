import UIKit
import UniformTypeIdentifiers

final class ClipboardHostApiImpl: ClipboardHostApi {
    private var autoClear: DispatchWorkItem?

    /// `sensitive` keeps the item off Universal Clipboard (other Apple devices). `clearAfterMs`
    /// both sets the pasteboard expiration and schedules an explicit clear.
    func copySecure(text: String, sensitive: Bool, clearAfterMs: Int64?) throws {
        autoClear?.cancel()
        autoClear = nil
        var options: [UIPasteboard.OptionsKey: Any] = [:]
        if sensitive { options[.localOnly] = true }
        let millis = clearAfterMs.flatMap { $0 > 0 ? $0 : nil }
        if let millis {
            options[.expirationDate] = Date().addingTimeInterval(TimeInterval(millis) / 1000)
        }
        UIPasteboard.general.setItems([[UTType.plainText.identifier: text]], options: options)
        if let millis {
            let work = DispatchWorkItem { [weak self] in try? self?.clear() }
            autoClear = work
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(millis)), execute: work)
        }
    }

    func clear() throws {
        autoClear?.cancel()
        autoClear = nil
        UIPasteboard.general.items = []
    }
}

final class ClipboardChangeMonitor: ClipboardChangedStreamHandler {
    private var observer: NSObjectProtocol?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<Int64>) {
        observer = NotificationCenter.default.addObserver(
            forName: UIPasteboard.changedNotification, object: nil, queue: .main
        ) { _ in sink.success(PluginSupport.nowMillis()) }
    }

    override func onCancel(withArguments arguments: Any?) {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }
}
