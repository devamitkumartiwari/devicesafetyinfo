import Flutter
import UIKit

/// One indicator found by a check. `id` is `<check>.<signal>` optionally followed by
/// `:<detail>`; the part before `:` is what apps override by.
struct RiskSignal {
    let id: String
    let highRisk: Bool

    var msg: SignalMsg { SignalMsg(id: id, level: highRisk ? .high : .low) }
}

/// Everything one check found. Policy is applied in Dart, not here.
struct RiskReport {
    var signals: [RiskSignal] = []
    var supported = true

    static let empty = RiskReport()
    static let unsupported = RiskReport(signals: [], supported: false)

    static func of(_ condition: Bool, _ id: String, highRisk: Bool) -> RiskReport {
        condition ? RiskReport(signals: [RiskSignal(id: id, highRisk: highRisk)]) : .empty
    }

    var msg: CheckReportMsg {
        CheckReportMsg(signals: signals.map { $0.msg }, supported: supported)
    }
}

enum PluginSupport {
    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    static func uiColor(fromARGB value: Int64) -> UIColor {
        let v = UInt32(truncatingIfNeeded: value)
        return UIColor(
            red: CGFloat((v >> 16) & 0xFF) / 255.0,
            green: CGFloat((v >> 8) & 0xFF) / 255.0,
            blue: CGFloat(v & 0xFF) / 255.0,
            alpha: CGFloat((v >> 24) & 0xFF) / 255.0)
    }

    static func nowMillis() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    static func unsupported(_ what: String) -> PigeonError {
        PigeonError(code: "UNSUPPORTED", message: "\(what) is not available on iOS", details: nil)
    }

    /// Runs blocking work on a background queue and resumes with its result. Errors propagate
    /// to Pigeon, which reports them to Dart as a PlatformException.
    static func background<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try work() })
            }
        }
    }
}
