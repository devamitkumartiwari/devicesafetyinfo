import Flutter
import UIKit

/// `setRecentsOverlay`/`clearRecentsOverlay` — covers the window with an opaque view while the app
/// is backgrounded, so the OS app-switcher snapshot doesn't expose sensitive content. Also owns the
/// no-op `hideMenu` case (app-switcher visibility itself is not controllable via public iOS API).
final class AppSwitcherPrivacyHandler: NSObject, DSIMethodHandler {
    let methods: Set<String> = ["setRecentsOverlay", "clearRecentsOverlay", "hideMenu"]

    private var recentsOverlayView: UIView?
    private var recentsOverlayColor: UIColor = .black

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setRecentsOverlay":
            let colorInt = (call.arguments as? [String: Any])?["color"] as? Int ?? Int(bitPattern: 0xFF000000)
            recentsOverlayColor = PluginHelpers.uiColor(fromARGB: colorInt)
            registerRecentsOverlayObservers()
            result(nil)
        case "clearRecentsOverlay":
            unregisterRecentsOverlayObservers()
            hideRecentsOverlay()
            result(nil)
        case "hideMenu":
            // App switching/recents visibility is not controllable on iOS.
            result(false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

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
        guard let window = PluginHelpers.keyWindow else { return }
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
}
