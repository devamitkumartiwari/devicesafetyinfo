import Foundation

/// Runs many checks in one round trip, concurrently. Checks without an iOS equivalent come
/// back unsupported. A check that throws is left out; Dart reports it as an error.
final class BatchHostApiImpl: BatchHostApi {
    func runChecks(request: BatchRequestMsg) async throws -> BatchResultMsg {
        let ids = Set(request.checkIds)
        let reports = await withTaskGroup(of: (String, CheckReportMsg?).self) { group in
            for id in ids {
                group.addTask { (id, await Self.report(for: id)?.msg) }
            }
            var out: [String: CheckReportMsg] = [:]
            for await (id, msg) in group {
                if let msg { out[id] = msg }
            }
            return out
        }
        let signing = ids.contains("tampering") ? SigningInfoReader.read() : nil
        return BatchResultMsg(
            reports: reports, accessibilityServices: [], notificationListeners: [],
            installedPackages: [], failedLists: [], signing: signing)
    }

    private static func report(for id: String) async -> RiskReport? {
        switch id {
        case "root":
            return await MainActor.run { JailbreakSignals.report() }
        case "emulator":
            return JailbreakSignals.simulatorReport()
        case "hooking":
            return try? await PluginSupport.background { HookingSignals.hookReport() }
        case "debugger":
            return HookingSignals.debuggerReport()
        case "screenLock":
            return try? await PluginSupport.background { PostureSignals.screenLock() }
        case "storeInstall":
            return PostureSignals.storeInstall()
        case "vpn":
            return try? await PluginSupport.background { VpnSignals.report() }
        case "screenCapture":
            return await MainActor.run { ScreenProtectionHostApiImpl.captureReport() }
        case "developerMode", "externalStorage", "unknownSources", "playProtect",
            "remoteAccess", "locationSpoofing", "appCloning", "mitm":
            return .unsupported
        default:
            // accessibility / notificationListener / malware are answered by the lists above.
            return nil
        }
    }
}
