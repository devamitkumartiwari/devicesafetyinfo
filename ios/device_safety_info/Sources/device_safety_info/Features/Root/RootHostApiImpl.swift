import IOSSecuritySuite
import UIKit

/// Jailbreak and simulator signals.
enum JailbreakSignals {
    /// IOSSecuritySuite's failed checks as signals. A registered `cydia://` URL scheme alone is
    /// weak evidence (some legitimate apps register it), so it's low risk; every other failed
    /// check is high. Must run on the main thread: the URL-scheme check calls `canOpenURL`.
    static func report() -> RiskReport {
        let result = IOSSecuritySuite.amIJailbrokenWithFailedChecks()
        return report(
            jailbroken: result.jailbroken,
            failedChecks: result.failedChecks.map { String(describing: $0.check) })
    }

    /// The mapping, independent of the device. `failedChecks` are IOSSecuritySuite
    /// `FailedCheck` case names.
    static func report(jailbroken: Bool, failedChecks: [String]) -> RiskReport {
        guard jailbroken else { return .empty }
        let signals = failedChecks.map { name in
            RiskSignal(id: "root.jailbreak_\(name)", highRisk: name != "urlSchemes")
        }
        return RiskReport(
            signals: signals.isEmpty ? [RiskSignal(id: "root.jailbreak", highRisk: true)] : signals)
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
