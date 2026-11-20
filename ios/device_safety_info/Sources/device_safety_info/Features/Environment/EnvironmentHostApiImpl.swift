import Foundation

/// Remote access, GPS spoofing, app cloning and user-CA checks have no reliable iOS equivalent
/// (apps can't see other apps, mock-location state or the trust store), so they report
/// unsupported. iOS screen sharing is covered by the screen-capture check.
final class EnvironmentHostApiImpl: EnvironmentHostApi {
    func remoteAccess() async throws -> CheckReportMsg { RiskReport.unsupported.msg }
    func locationSpoofing() async throws -> CheckReportMsg { RiskReport.unsupported.msg }
    func appCloning() async throws -> CheckReportMsg { RiskReport.unsupported.msg }
    func mitm() async throws -> CheckReportMsg { RiskReport.unsupported.msg }
}
