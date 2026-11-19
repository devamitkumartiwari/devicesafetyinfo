import Foundation

final class AppInfoHostApiImpl: AppInfoHostApi {
    func packageInfo() throws -> AppInfoMsg {
        let info = Bundle.main.infoDictionary
        return AppInfoMsg(
            packageName: Bundle.main.bundleIdentifier ?? "",
            version: info?["CFBundleShortVersionString"] as? String ?? "0.0.0",
            buildNumber: info?["CFBundleVersion"] as? String ?? "0")
    }
}

/// iOS apps can't list or query other installed apps, so the malware package check reports
/// nothing.
final class MalwareHostApiImpl: MalwareHostApi {
    func installedOf(packages: [String]) async throws -> [String] { [] }
}
