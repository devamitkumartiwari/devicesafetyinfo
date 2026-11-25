import UIKit

/// Shared broadcaster for iOS's single screen-capture OS signal
/// (`UIScreen.isCaptured` / `UIScreen.capturedDidChangeNotification`).
///
/// iOS exposes exactly one signal for "something is capturing what's on screen" — screen
/// recording, screen mirroring, and AirPlay all surface identically through it; there is no
/// separate API to tell them apart. Both `ScreenCaptureHandler` (the existing
/// `screen_capture_events` stream / `isScreenCaptured` method, historically framed as
/// mirroring/external-display detection) and `ScreenRecordingHandler` (the new
/// `screen_recording_events` stream) and `ScreenshotProtectionHandler` (reactive overlay modes)
/// all need this same signal. Rather than
/// each registering its own `NotificationCenter` observer — which would work, but leaves multiple
/// independent sources of truth for "am I captured right now" that could silently drift — they all
/// go through this single shared instance, which owns the one observer's lifecycle.
///
/// Documented explicitly (see also the README): on iOS, "screen recording" and "screen
/// capture/mirroring" are the same OS signal. The distinction between the two is only real on
/// Android, which has a dedicated MediaProjection-based recording callback.
final class IOSScreenCaptureSignal: NSObject {
    static let shared = IOSScreenCaptureSignal()

    private var listeners: [UUID: (Bool) -> Void] = [:]
    private var isObserving = false

    private override init() {
        super.init()
    }

    /// Current capture state, using the scene-based API on iOS 16+ and falling back to
    /// UIScreen.main on iOS 11–15.
    var isCaptured: Bool {
        if #available(iOS 16.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.screen.isCaptured ?? false
        } else if #available(iOS 11.0, *) {
            return UIScreen.main.isCaptured
        }
        return false
    }

    /// Registers a listener invoked with the new capture state on every transition. Returns a
    /// token to pass to `removeListener`. Does not invoke the listener immediately with the
    /// current state — callers that need the current value right away should also read
    /// `isCaptured` directly.
    @discardableResult
    func addListener(_ listener: @escaping (Bool) -> Void) -> UUID {
        let token = UUID()
        listeners[token] = listener
        startObservingIfNeeded()
        return token
    }

    func removeListener(_ token: UUID) {
        listeners.removeValue(forKey: token)
        if listeners.isEmpty {
            stopObserving()
        }
    }

    private func startObservingIfNeeded() {
        guard !isObserving, #available(iOS 11.0, *) else { return }
        isObserving = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(onChanged),
            name: UIScreen.capturedDidChangeNotification, object: nil)
    }

    private func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        NotificationCenter.default.removeObserver(
            self, name: UIScreen.capturedDidChangeNotification, object: nil)
    }

    @objc private func onChanged() {
        let state = isCaptured
        for listener in listeners.values {
            listener(state)
        }
    }
}
