import IOSSecuritySuite

/// Swift-side hooking and debugger signals. The native checks (dyld image scan, P_TRACED) run
/// in C through FFI and are merged in Dart.
enum HookingSignals {
    static func hookReport() -> RiskReport {
        let result = IOSSecuritySuite.amIReverseEngineeredWithFailedChecks()
        guard result.reverseEngineered else { return .empty }
        let signals = result.failedChecks.map {
            RiskSignal(id: "hooking.\(String(describing: $0.check))", highRisk: true)
        }
        return RiskReport(
            signals: signals.isEmpty
                ? [RiskSignal(id: "hooking.reverse_engineering", highRisk: true)] : signals)
    }

    static func debuggerReport() -> RiskReport {
        var signals: [RiskSignal] = []
        if IOSSecuritySuite.amIDebugged() {
            signals.append(RiskSignal(id: "debugger.attached", highRisk: true))
        }
        #if DEBUG
            signals.append(RiskSignal(id: "debugger.debuggable_build", highRisk: false))
        #endif
        return RiskReport(signals: signals)
    }
}

final class HookingHostApiImpl: HookingHostApi {
    func hookCheck() async throws -> CheckReportMsg {
        try await PluginSupport.background { HookingSignals.hookReport().msg }
    }

    func debuggerCheck() throws -> CheckReportMsg {
        HookingSignals.debuggerReport().msg
    }
}
