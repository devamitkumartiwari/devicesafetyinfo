import Foundation

final class AppInfoHostApiImpl: AppInfoHostApi {
    func packageInfo() throws -> AppInfoMsg {
        let info = Bundle.main.infoDictionary
        return AppInfoMsg(
            packageName: Bundle.main.bundleIdentifier ?? "",
            version: info?["CFBundleShortVersionString"] as? String ?? "0.0.0",
            buildNumber: info?["CFBundleVersion"] as? String ?? "0")
    }

    func signingInfo() async throws -> SigningInfoMsg {
        try await PluginSupport.background { SigningInfoReader.read() }
    }
}

/// Reads the app's provisioning profile, for the tampering check. App Store and TestFlight
/// builds have no `embedded.mobileprovision`; development, ad-hoc, enterprise and re-signed
/// (sideloaded) builds do, and its team identifier says who signed them.
enum SigningInfoReader {
    static func read(bundle: Bundle = .main) -> SigningInfoMsg {
        guard let path = bundle.path(forResource: "embedded", ofType: "mobileprovision"),
            let data = FileManager.default.contents(atPath: path)
        else {
            return SigningInfoMsg(certificateSha256: [], hasProvisioningProfile: false, teamId: nil)
        }
        return SigningInfoMsg(
            certificateSha256: [], hasProvisioningProfile: true, teamId: teamId(inProfile: data))
    }

    /// The `TeamIdentifier` of a provisioning profile. The profile is a CMS-signed message whose
    /// payload is an XML property list stored as plain text, so it can be cut out directly.
    static func teamId(inProfile data: Data) -> String? {
        guard let start = data.range(of: Data("<?xml".utf8)),
            let end = data.range(
                of: Data("</plist>".utf8), options: [], in: start.lowerBound..<data.endIndex)
        else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard
            let plist = try? PropertyListSerialization.propertyList(
                from: plistData, options: [], format: nil) as? [String: Any]
        else { return nil }
        return (plist["TeamIdentifier"] as? [String])?.first
    }
}

/// iOS apps can't list or query other installed apps, so the malware package check reports
/// nothing.
final class MalwareHostApiImpl: MalwareHostApi {
    func installedOf(packages: [String]) async throws -> [String] { [] }
}
