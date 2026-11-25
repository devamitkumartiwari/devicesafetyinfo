import Flutter
import UIKit

/// Screenshot blocking (secure text field layer trick), the capture overlay shown while the
/// screen is recorded or mirrored, and the capture check.
final class ScreenProtectionHostApiImpl: ScreenProtectionHostApi {
    private var secureTextField: UITextField?
    private var secureFieldHostWindow: UIWindow?
    private var secureWindowOriginalSuperLayer: CALayer?

    private var overlayMode: OverlayModeMsg?
    private var overlayColor: UIColor = .black
    private var overlayImage: UIImage?
    private var overlayView: UIView?
    private var captureListenerToken: UUID?

    func blockScreenshots(block: Bool) throws {
        if block { enableBlocking() } else { disableBlocking() }
    }

    func isScreenshotBlocked() throws -> Bool { secureTextField != nil }

    func setOverlayMode(config: OverlayConfigMsg) throws {
        overlayColor = config.argbColor.map { PluginSupport.uiColor(fromARGB: $0) } ?? .black
        overlayImage = config.imageBytes.flatMap { UIImage(data: $0.data) }
        guard config.mode != .none else {
            try clearOverlayMode()
            return
        }
        overlayMode = config.mode
        if captureListenerToken == nil {
            captureListenerToken = IOSScreenCaptureSignal.shared.addListener { [weak self] captured in
                self?.applyOverlay(captured: captured)
            }
        }
        applyOverlay(captured: IOSScreenCaptureSignal.shared.isCaptured)
    }

    func clearOverlayMode() throws {
        overlayMode = nil
        overlayImage = nil
        if let token = captureListenerToken {
            IOSScreenCaptureSignal.shared.removeListener(token)
        }
        captureListenerToken = nil
        hideOverlay()
    }

    func screenCaptureCheck() throws -> CheckReportMsg {
        ScreenProtectionHostApiImpl.captureReport().msg
    }

    func isRecordingDetectionSupported() throws -> Bool { true }

    /// iOS reports recording and mirroring together (UIScreen.isCaptured): high risk. An
    /// additional connected screen (AirPlay / HDMI as a second display) is low risk.
    static func captureReport() -> RiskReport {
        var signals: [RiskSignal] = []
        if IOSScreenCaptureSignal.shared.isCaptured {
            signals.append(RiskSignal(id: "screen_capture.recording", highRisk: true))
        }
        let externalScreens = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowExternalDisplayNonInteractive }
        if !externalScreens.isEmpty {
            signals.append(RiskSignal(id: "screen_capture.external_display", highRisk: false))
        }
        return RiskReport(signals: signals)
    }

    // MARK: Screenshot blocking

    // Moving the key window's layer under a secure UITextField's layer makes iOS render it
    // blank in screenshots and recordings.
    private func enableBlocking() {
        guard secureTextField == nil, let window = PluginSupport.keyWindow else { return }
        let field = UITextField()
        field.isSecureTextEntry = true
        let hostWindow = window.windowScene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: .zero)
        hostWindow.windowLevel = .init(rawValue: -.greatestFiniteMagnitude)
        hostWindow.isHidden = false
        hostWindow.addSubview(field)
        secureFieldHostWindow = hostWindow
        secureWindowOriginalSuperLayer = window.layer.superlayer
        field.layer.sublayers?.last?.addSublayer(window.layer)
        secureTextField = field
    }

    private func disableBlocking() {
        guard let field = secureTextField else { return }
        if let originalParent = secureWindowOriginalSuperLayer, let window = PluginSupport.keyWindow {
            originalParent.addSublayer(window.layer)
        }
        field.removeFromSuperview()
        secureFieldHostWindow = nil
        secureTextField = nil
        secureWindowOriginalSuperLayer = nil
    }

    // MARK: Capture overlay

    private func applyOverlay(captured: Bool) {
        guard overlayMode != nil else { return }
        if captured { showOverlay() } else { hideOverlay() }
    }

    private func showOverlay() {
        guard let mode = overlayMode, let window = PluginSupport.keyWindow else { return }
        hideOverlay()
        let view: UIView
        switch mode {
        case .blur:
            view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        case .color:
            view = UIView()
            view.backgroundColor = overlayColor
        case .image:
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.image = overlayImage
            view = imageView
        case .none:
            return
        }
        view.frame = window.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
        overlayView = view
    }

    private func hideOverlay() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }
}

final class ScreenshotMonitor: ScreenshotTakenStreamHandler {
    private var observer: NSObjectProtocol?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<Int64>) {
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main
        ) { _ in sink.success(PluginSupport.nowMillis()) }
    }

    override func onCancel(withArguments arguments: Any?) {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }
}

/// Capture (recording or mirroring) state; sends the current state first.
final class ScreenCaptureMonitor: ScreenCaptureChangedStreamHandler {
    private var token: UUID?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<Bool>) {
        token = IOSScreenCaptureSignal.shared.addListener { sink.success($0) }
        sink.success(IOSScreenCaptureSignal.shared.isCaptured)
    }

    override func onCancel(withArguments arguments: Any?) {
        if let token { IOSScreenCaptureSignal.shared.removeListener(token) }
        token = nil
    }
}

/// iOS can't tell recording from mirroring, so this mirrors the capture state.
final class ScreenRecordingMonitor: ScreenRecordingChangedStreamHandler {
    private var token: UUID?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<Bool>) {
        token = IOSScreenCaptureSignal.shared.addListener { sink.success($0) }
        sink.success(IOSScreenCaptureSignal.shared.isCaptured)
    }

    override func onCancel(withArguments arguments: Any?) {
        if let token { IOSScreenCaptureSignal.shared.removeListener(token) }
        token = nil
    }
}
