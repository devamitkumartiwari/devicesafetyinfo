import Flutter
import UIKit

/// Screenshot/recording blocking (the `UITextField.isSecureTextEntry` layer trick) plus the newer
/// overlay-mode feature: a real, visible view shown over the app's content whenever the screen is
/// actually being captured/recorded/mirrored.
///
/// Key design point: the secure-layer trick below makes the OS render
/// nothing at all into a screenshot or screen recording, so a custom overlay can never appear
/// *inside* a capture — there is no way to composite custom pixels into a blocked capture. What
/// this feature does instead is show a real, on-screen-only view reactively, exactly when
/// `IOSScreenCaptureSignal` reports the screen is currently captured, so anyone glancing at the
/// live device screen sees a branded placeholder instead of the app's normal content. This mirrors
/// the existing recents-overlay feature's mechanics (see `AppSwitcherPrivacyHandler`), just driven
/// by capture state instead of app-background state.
final class ScreenshotProtectionHandler: DSIMethodHandler {
    let methods: Set<String> = [
        "blockScreenShots", "isScreenshotBlocked",
        "setScreenshotOverlayMode", "clearScreenshotOverlayMode",
    ]

    // MARK: - Screenshot blocking (UITextField isSecureTextEntry trick)
    //
    // Re-parents the key window's CALayer into the secure sublayer of a UITextField
    // with isSecureTextEntry = true. The system prevents that secure layer's
    // contents from appearing in screenshots and screen recordings.
    private var secureTextField: UITextField?
    private var secureFieldHostWindow: UIWindow?
    private var secureWindowOriginalSuperLayer: CALayer?

    // MARK: - Overlay mode state
    private var overlayMode: String?
    private var overlayColor: UIColor = .black
    private var overlayImage: UIImage?
    private var overlayView: UIView?
    private var captureListenerToken: UUID?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "blockScreenShots":
            let block = (call.arguments as? [String: Any])?["block"] as? Bool ?? false
            if block {
                enableScreenshotBlocking()
            } else {
                disableScreenshotBlocking()
            }
            result(true)
        case "isScreenshotBlocked":
            result(secureTextField != nil)
        case "setScreenshotOverlayMode":
            applySetOverlayMode(call.arguments as? [String: Any])
            result(nil)
        case "clearScreenshotOverlayMode":
            clearOverlayModeState()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Screenshot blocking

    private func enableScreenshotBlocking() {
        guard secureTextField == nil, let window = PluginHelpers.keyWindow else { return }

        let field = UITextField()
        field.isSecureTextEntry = true

        // Host the field in its own window rather than adding it as a subview of
        // `window`. If the field lived inside `window`'s view hierarchy, its secure
        // sublayer would already be a descendant of `window.layer`, and reparenting
        // `window.layer` into it below would make `window.layer` its own ancestor —
        // a cycle that crashes CoreAnimation with "layer is a part of cycle in its
        // layer tree". Keeping the field's layer tree fully separate avoids that.
        let hostWindow: UIWindow
        if let scene = window.windowScene {
            hostWindow = UIWindow(windowScene: scene)
        } else {
            hostWindow = UIWindow(frame: .zero)
        }
        hostWindow.windowLevel = .init(rawValue: -.greatestFiniteMagnitude)
        hostWindow.isHidden = false
        hostWindow.addSubview(field)
        secureFieldHostWindow = hostWindow

        secureWindowOriginalSuperLayer = window.layer.superlayer

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
            originalParent.addSublayer(PluginHelpers.keyWindow?.layer ?? CALayer())
        }
        field.removeFromSuperview()
        secureFieldHostWindow = nil
        secureTextField = nil
        secureWindowOriginalSuperLayer = nil
    }

    // MARK: - Overlay modes
    //
    // `blurRadius` is accepted from Dart for API parity with Android (which drives a real
    // RenderEffect blur radius via a numeric parameter) but has no direct equivalent here:
    // UIBlurEffect exposes only fixed styles, not a radius knob. Rather than build a custom
    // CIFilter-based blur pipeline (which would need to continuously re-render the live view
    // hierarchy into a bitmap — real CPU/GPU cost — just to approximate a cosmetic parameter),
    // this uses a plain UIVisualEffectView(.systemMaterial) blur and ignores blurRadius. That is a
    // deliberate simplification: documented here, not a missed requirement.

    private func applySetOverlayMode(_ args: [String: Any]?) {
        let mode = args?["mode"] as? String ?? "none"

        if let argb = args?["argbColor"] as? Int {
            overlayColor = PluginHelpers.uiColor(fromARGB: argb)
        } else {
            overlayColor = .black
        }

        if let typedData = args?["imageBytes"] as? FlutterStandardTypedData {
            overlayImage = UIImage(data: typedData.data)
        } else {
            overlayImage = nil
        }

        guard mode != "none" else {
            clearOverlayModeState()
            return
        }

        overlayMode = mode
        startObservingCaptureIfNeeded()
        // Reflect the current capture state immediately instead of waiting for the next transition
        // — a caller that configures a mode while already mid-capture should see it right away.
        applyOverlay(forCaptured: IOSScreenCaptureSignal.shared.isCaptured)
    }

    private func clearOverlayModeState() {
        overlayMode = nil
        overlayImage = nil
        stopObservingCapture()
        hideOverlay()
    }

    private func startObservingCaptureIfNeeded() {
        guard captureListenerToken == nil else { return }
        captureListenerToken = IOSScreenCaptureSignal.shared.addListener { [weak self] captured in
            self?.applyOverlay(forCaptured: captured)
        }
    }

    private func stopObservingCapture() {
        if let token = captureListenerToken {
            IOSScreenCaptureSignal.shared.removeListener(token)
        }
        captureListenerToken = nil
    }

    private func applyOverlay(forCaptured captured: Bool) {
        guard overlayMode != nil else { return }
        if captured {
            showOverlay()
        } else {
            hideOverlay()
        }
    }

    private func showOverlay() {
        guard let mode = overlayMode, let window = PluginHelpers.keyWindow else { return }
        hideOverlay()

        let view: UIView
        switch mode {
        case "blur":
            let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            effectView.frame = window.bounds
            view = effectView
        case "color":
            let colorView = UIView(frame: window.bounds)
            colorView.backgroundColor = overlayColor
            view = colorView
        case "image":
            let imageView = UIImageView(frame: window.bounds)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.image = overlayImage
            view = imageView
        default:
            return
        }

        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.tag = 997
        window.addSubview(view)
        overlayView = view
    }

    private func hideOverlay() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }
}
