import Foundation
import LocalAuthentication

/// Device posture on iOS. Developer mode, external storage, unknown sources, Play Protect,
/// accessibility services and notification listeners have no iOS equivalent and report
/// unsupported / empty.
enum PostureSignals {
    static func screenLock() -> RiskReport {
        let hasPasscode = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return .of(!hasPasscode, "screen_lock.none", highRisk: true)
    }

    /// App Store and TestFlight builds carry a receipt; Xcode, ad-hoc and enterprise builds
    /// don't. Simulator and debug builds are never treated as store installs.
    static func storeInstall() -> RiskReport {
        #if targetEnvironment(simulator) || DEBUG
            let fromStore = false
        #else
            let fromStore: Bool = {
                guard let url = Bundle.main.appStoreReceiptURL else { return false }
                return FileManager.default.fileExists(atPath: url.path)
            }()
        #endif
        return .of(!fromStore, "store_install.unknown_installer", highRisk: false)
    }
}

final class PostureHostApiImpl: PostureHostApi {
    func developerMode() async throws -> CheckReportMsg { RiskReport.unsupported.msg }

    func screenLock() async throws -> CheckReportMsg {
        try await PluginSupport.background { PostureSignals.screenLock().msg }
    }

    func storeInstall() async throws -> CheckReportMsg { PostureSignals.storeInstall().msg }

    func externalStorage() async throws -> CheckReportMsg { RiskReport.unsupported.msg }

    func unknownSources() async throws -> CheckReportMsg { RiskReport.unsupported.msg }

    func playProtect() async throws -> CheckReportMsg { RiskReport.unsupported.msg }

    func enabledAccessibilityServices() async throws -> [AccessibilityServiceMsg] { [] }

    func enabledNotificationListeners() async throws -> [String] { [] }
}
