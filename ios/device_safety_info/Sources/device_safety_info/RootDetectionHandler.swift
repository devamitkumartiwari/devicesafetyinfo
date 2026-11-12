import Flutter
import IOSSecuritySuite

// Direct reference to the C-level debugger check compiled from DeviceSafetyFfi.c.
// Using @_silgen_name avoids the need for a bridging header (required for SPM).
@_silgen_name("dsi_is_debugger_attached")
private func dsi_is_debugger_attached() -> Int32

/// Root/jailbreak, emulator, hook, and debugger detection — all backed by IOSSecuritySuite plus
/// one native C-level debugger check.
final class RootDetectionHandler: DSIMethodHandler {
    let methods: Set<String> = [
        "isRootedDevice", "rootCheck", "isRealDevice", "emulatorCheck", "isHooked", "isDebuggerAttached",
    ]

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isRootedDevice":
            result(IOSSecuritySuite.amIJailbroken())
        case "rootCheck":
            // IOSSecuritySuite's indicators (Cydia/Sileo, writable system paths, suspicious
            // dylibs, ...) don't occur on stock iOS, so any hit is reported as high-risk.
            let check = IOSSecuritySuite.amIJailbrokenWithFailMessage()
            let signals = check.jailbroken
                ? check.failMessage
                    .split(separator: ",")
                    .map { "ios:" + $0.trimmingCharacters(in: .whitespaces) }
                    .filter { $0 != "ios:" }
                : []
            result([
                "level": check.jailbroken ? "high" : "none",
                "highRiskSignals": check.jailbroken && signals.isEmpty ? ["ios:jailbroken"] : signals,
                "lowRiskSignals": [String](),
            ])
        case "isRealDevice":
            result(!IOSSecuritySuite.amIRunInEmulator())
        case "emulatorCheck":
            // The iOS Simulator is unambiguous, so it is always high-risk.
            let simulator = IOSSecuritySuite.amIRunInEmulator()
            result([
                "level": simulator ? "high" : "none",
                "highRiskSignals": simulator ? ["ios:simulator"] : [String](),
                "lowRiskSignals": [String](),
            ])
        case "isHooked":
            result(IOSSecuritySuite.amIReverseEngineered())
        case "isDebuggerAttached":
            // Combine native sysctl C check with IOSSecuritySuite for best coverage.
            let cCheck = dsi_is_debugger_attached() != 0
            let suiteCheck = IOSSecuritySuite.amIDebugged()
            result(cCheck || suiteCheck)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
