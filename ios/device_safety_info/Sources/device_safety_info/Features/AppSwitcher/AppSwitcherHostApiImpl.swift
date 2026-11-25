import UIKit

/// Covers the app with a solid color when it resigns active, which is when iOS takes the app
/// switcher snapshot. iOS has no API to exclude an app from the switcher, so `hideFromRecents`
/// is unsupported.
final class AppSwitcherHostApiImpl: NSObject, AppSwitcherHostApi {
    private var overlay: UIView?
    private var color: UIColor = .black
    private var observing = false

    func setRecentsOverlay(argb: Int64) throws {
        color = PluginSupport.uiColor(fromARGB: argb)
        guard !observing else { return }
        observing = true
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(show),
            name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(
            self, selector: #selector(hide),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func clearRecentsOverlay() throws {
        if observing {
            NotificationCenter.default.removeObserver(self)
            observing = false
        }
        hide()
    }

    func hideFromRecents(hide: Bool) throws {
        throw PluginSupport.unsupported("hideFromRecents")
    }

    @objc private func show() {
        guard let window = PluginSupport.keyWindow else { return }
        hide()
        let view = UIView(frame: window.bounds)
        view.backgroundColor = color
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
        overlay = view
    }

    @objc private func hide() {
        overlay?.removeFromSuperview()
        overlay = nil
    }
}
