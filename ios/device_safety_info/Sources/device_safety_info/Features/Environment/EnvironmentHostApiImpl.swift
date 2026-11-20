import Foundation

/// Remote access, GPS spoofing, app cloning, user-CA and keyboard checks have no reliable iOS
/// equivalent (apps can't see other apps, mock-location state, the trust store or the active
/// keyboard), so they report unsupported. iOS screen sharing is covered by the screen-capture
/// check; third-party keyboards can be refused with `KeyboardPolicy`.
final class EnvironmentHostApiImpl: EnvironmentHostApi {
    func remoteAccess() async throws -> CheckReportMsg { RiskReport.unsupported.msg }
    func locationSpoofing() async throws -> CheckReportMsg { RiskReport.unsupported.msg }
    func appCloning() async throws -> CheckReportMsg { RiskReport.unsupported.msg }
    func mitm() async throws -> CheckReportMsg { RiskReport.unsupported.msg }
    func keyboard() async throws -> CheckReportMsg { RiskReport.unsupported.msg }

    func setBlockCustomKeyboards(block: Bool) throws {
        KeyboardPolicy.blockCustomKeyboards = block
    }
}
