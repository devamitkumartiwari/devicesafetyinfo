import Flutter
import Foundation

/// `getPackageInfo` — the host app's bundle identifier and marketing version.
final class VersionCheckHandler: DSIMethodHandler {
    let methods: Set<String> = ["getPackageInfo"]

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPackageInfo":
            let bundleId = Bundle.main.bundleIdentifier ?? ""
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            result(["packageName": bundleId, "version": version])
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
