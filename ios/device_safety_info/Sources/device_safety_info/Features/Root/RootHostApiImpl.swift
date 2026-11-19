import IOSSecuritySuite
import UIKit

/// Jailbreak and simulator signals.
enum JailbreakSignals {
    /// IOSSecuritySuite's failed checks as signals. A registered `cydia://` URL scheme alone is
    /// weak evidence (some legitimate apps register it), so it's low risk; every other failed
    /// check is high. Must run on the main thread: the URL-scheme check calls `canOpenURL`.
    static func report() -> RiskReport {
        let result = IOSSecuritySuite.amIJailbrokenWithFailedChecks()
        guard result.jailbroken else { return .empty }
        var signals = result.failedChecks.map { failed -> RiskSignal in
            let name = String(describing: failed.check)
            return RiskSignal(id: "root.jailbreak_\(name)", highRisk: name != "urlSchemes")
        }
        if signals.isEmpty {
            signals = [RiskSignal(id: "root.jailbreak", highRisk: true)]
        }
        return RiskReport(signals: signals)
    }

    static func simulatorReport() -> RiskReport {
        RiskReport.of(IOSSecuritySuite.amIRunInEmulator(), "emulator.simulator", highRisk: true)
    }
}

final class RootHostApiImpl: RootHostApi {
    func rootCheck() async throws -> CheckReportMsg {
        await MainActor.run { JailbreakSignals.report().msg }
    }

    func emulatorCheck() async throws -> CheckReportMsg {
        JailbreakSignals.simulatorReport().msg
    }
}
