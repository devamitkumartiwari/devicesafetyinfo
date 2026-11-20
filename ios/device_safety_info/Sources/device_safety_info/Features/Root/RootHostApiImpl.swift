import IOSSecuritySuite
import UIKit

/// Jailbreak and simulator signals.
enum JailbreakSignals {
    /// IOSSecuritySuite's failed checks as signals. A registered jailbreak-app URL scheme
    /// (`sileo://`, `zbra://`, `filza://`, `undecimus://`) alone is weak evidence, so it's low
    /// risk; every other failed check is high. Must run on the main thread: IOSSecuritySuite
    /// runs its URL-scheme check (`canOpenURL`) together with the others and offers no way to
    /// skip it. The C jailbreak-file check (`root.native_jailbreak_files`) runs off the main
    /// thread as a second opinion.
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
