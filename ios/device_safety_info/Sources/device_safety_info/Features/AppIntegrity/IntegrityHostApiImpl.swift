import CryptoKit
import DeviceCheck
import Foundation

/// App Attest and DeviceCheck. Play Integrity is Android only and reports UNSUPPORTED here.
/// Challenges and client data are hashed with SHA-256 before being passed to App Attest, so the
/// server must hash the same bytes.
final class IntegrityHostApiImpl: IntegrityHostApi {
    private let service = DCAppAttestService.shared

    func isPlayIntegrityAvailable() throws -> Bool { false }

    func preparePlayIntegrity(cloudProjectNumber: Int64) async throws {
        throw PluginSupport.unsupported("Play Integrity")
    }

    func requestPlayIntegrityToken(requestHash: String) async throws -> String {
        throw PluginSupport.unsupported("Play Integrity")
    }

    func isAppAttestSupported() throws -> Bool { service.isSupported }

    func generateAppAttestKey() async throws -> String {
        try requireAppAttest()
        do {
            return try await service.generateKey()
        } catch {
            throw Self.pigeonError(error)
        }
    }

    func attestAppAttestKey(keyId: String, challenge: String) async throws -> String {
        try requireAppAttest()
        do {
            return try await service.attestKey(keyId, clientDataHash: Self.sha256(challenge))
                .base64EncodedString()
        } catch {
            throw Self.pigeonError(error)
        }
    }

    func generateAppAttestAssertion(keyId: String, clientData: String) async throws -> String {
        try requireAppAttest()
        do {
            return try await service.generateAssertion(keyId, clientDataHash: Self.sha256(clientData))
                .base64EncodedString()
        } catch {
            throw Self.pigeonError(error)
        }
    }

    func isDeviceCheckSupported() throws -> Bool { DCDevice.current.isSupported }

    func generateDeviceCheckToken() async throws -> String {
        guard DCDevice.current.isSupported else { throw Self.notSupportedHere }
        do {
            return try await DCDevice.current.generateToken().base64EncodedString()
        } catch {
            throw Self.pigeonError(error)
        }
    }

    private func requireAppAttest() throws {
        guard service.isSupported else { throw Self.notSupportedHere }
    }

    private static func sha256(_ string: String) -> Data {
        Data(SHA256.hash(data: Data(string.utf8)))
    }

    private static let notSupportedHere = PigeonError(
        code: "UNSUPPORTED",
        message: "Not supported on this device (simulator, app extension, or missing entitlement)",
        details: nil)

    private static func pigeonError(_ error: Error) -> PigeonError {
        let code: String
        if let dcError = error as? DCError {
            switch dcError.code {
            case .featureUnsupported: code = "UNSUPPORTED"
            case .invalidKey: code = "INVALID_KEY"
            case .invalidInput: code = "INVALID_INPUT"
            case .serverUnavailable: code = "SERVER_UNAVAILABLE"
            default: code = "UNKNOWN"
            }
        } else if (error as NSError).domain == NSURLErrorDomain {
            code = "NETWORK"
        } else {
            code = "UNKNOWN"
        }
        return PigeonError(code: code, message: error.localizedDescription, details: nil)
    }
}
