import CryptoKit
import DeviceCheck
import Flutter
import Foundation

/// App Attest (key generation, attestation, assertions) and DeviceCheck tokens — the client half of
/// Apple's attestation APIs. Produces opaque base64 blobs only; all verification happens on the
/// app's server (see example/server_dotnet). Requires the consuming app to carry the
/// `com.apple.developer.devicecheck.appattest-environment` entitlement for App Attest.
///
/// `challenge` / `clientData` arrive as strings and are SHA-256 hashed here into the
/// `clientDataHash` Apple expects; the server recomputes the same hash from the same string.
final class AppAttestHandler: DSIMethodHandler {
    let methods: Set<String> = [
        "isAppAttestSupported",
        "generateAppAttestKey",
        "attestAppAttestKey",
        "generateAppAttestAssertion",
        "isDeviceCheckSupported",
        "generateDeviceCheckToken",
    ]

    private let service = DCAppAttestService.shared

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        // DeviceCheck completion handlers run on an arbitrary queue; Flutter results must be
        // delivered on the platform (main) thread.
        let reply: (Any?) -> Void = { value in DispatchQueue.main.async { result(value) } }

        switch call.method {
        case "isAppAttestSupported":
            result(service.isSupported)

        case "isDeviceCheckSupported":
            result(DCDevice.current.isSupported)

        case "generateAppAttestKey":
            guard service.isSupported else { return result(Self.unsupported) }
            service.generateKey { keyId, error in
                if let error = error { return reply(Self.flutterError(error)) }
                reply(keyId)
            }

        case "attestAppAttestKey":
            guard service.isSupported else { return result(Self.unsupported) }
            guard let keyId = args["keyId"] as? String,
                  let challenge = args["challenge"] as? String
            else { return result(Self.invalid("keyId and challenge are required")) }
            service.attestKey(keyId, clientDataHash: Self.sha256(challenge)) { attestation, error in
                if let error = error { return reply(Self.flutterError(error)) }
                reply(attestation?.base64EncodedString())
            }

        case "generateAppAttestAssertion":
            guard service.isSupported else { return result(Self.unsupported) }
            guard let keyId = args["keyId"] as? String,
                  let clientData = args["clientData"] as? String
            else { return result(Self.invalid("keyId and clientData are required")) }
            service.generateAssertion(keyId, clientDataHash: Self.sha256(clientData)) { assertion, error in
                if let error = error { return reply(Self.flutterError(error)) }
                reply(assertion?.base64EncodedString())
            }

        case "generateDeviceCheckToken":
            guard DCDevice.current.isSupported else { return result(Self.unsupported) }
            DCDevice.current.generateToken { token, error in
                if let error = error { return reply(Self.flutterError(error)) }
                reply(token?.base64EncodedString())
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func sha256(_ string: String) -> Data {
        Data(SHA256.hash(data: Data(string.utf8)))
    }

    private static let unsupported = FlutterError(
        code: "UNSUPPORTED",
        message: "Not supported on this device (simulator, app extension, or missing entitlement)",
        details: nil)

    private static func invalid(_ message: String) -> FlutterError {
        FlutterError(code: "INVALID_INPUT", message: message, details: nil)
    }

    private static func flutterError(_ error: Error) -> FlutterError {
        let code: String
        if let dcError = error as? DCError {
            switch dcError.code {
            case .featureUnsupported: code = "UNSUPPORTED"
            // Key invalidated (e.g. app reinstall restored from backup): discard keyId,
            // generate a new key and attest it again.
            case .invalidKey: code = "INVALID_KEY"
            case .invalidInput: code = "INVALID_INPUT"
            // Apple's attestation servers are temporarily unreachable: retry later.
            case .serverUnavailable: code = "SERVER_UNAVAILABLE"
            default: code = "UNKNOWN"
            }
        } else {
            code = "UNKNOWN"
        }
        return FlutterError(code: code, message: error.localizedDescription, details: nil)
    }
}
