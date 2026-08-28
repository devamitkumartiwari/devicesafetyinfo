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
        "isRootedDevice", "isRealDevice", "isHooked", "isDebuggerAttached",
    ]

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isRootedDevice":
            result(IOSSecuritySuite.amIJailbroken())
        case "isRealDevice":
            result(!IOSSecuritySuite.amIRunInEmulator())
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
