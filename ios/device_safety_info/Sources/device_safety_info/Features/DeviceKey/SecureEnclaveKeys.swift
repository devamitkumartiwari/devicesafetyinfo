import Flutter
import Foundation
import LocalAuthentication
import Security

/// EC P-256 signing keys in the Secure Enclave (software keys on the simulator, reported as
/// `software`). Private keys never leave the Secure Enclave.
enum SecureEnclaveKeys {
    /// Plugin namespace, so app aliases can't collide with other Keychain users.
    static func tag(_ kind: String, _ alias: String) -> Data {
        Data("dsi.\(kind).\(alias)".utf8)
    }

    static var hasSecureEnclave: Bool {
        #if targetEnvironment(simulator)
            return false
        #else
            return true
        #endif
    }

    /// Creates (replacing any existing) key under [tag]. [flags] adds access-control
    /// requirements such as `.biometryCurrentSet`.
    static func create(tag: Data, flags: SecAccessControlCreateFlags) throws {
        delete(tag: tag)
        var error: Unmanaged<CFError>?
        var accessFlags = flags
        if hasSecureEnclave { accessFlags.insert(.privateKeyUsage) }
        guard
            let access = SecAccessControlCreateWithFlags(
                nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, accessFlags, &error)
        else {
            throw failure(error?.takeRetainedValue())
        }
        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: access,
            ],
        ]
        if hasSecureEnclave {
            attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }
        guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
            throw failure(error?.takeRetainedValue())
        }
    }

    static func privateKey(tag: Data, context: LAContext? = nil) -> SecKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]
        if let context { query[kSecUseAuthenticationContext as String] = context }
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let item else {
            return nil
        }
        return (item as! SecKey)
    }

    static func exists(tag: Data) -> Bool { privateKey(tag: tag) != nil }

    static func delete(tag: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// The key's info, or nil if it doesn't exist.
    static func info(tag: Data) throws -> DeviceKeyInfoMsg? {
        guard let key = privateKey(tag: tag) else { return nil }
        guard let pub = SecKeyCopyPublicKey(key) else {
            throw PigeonError(code: "FAILED", message: "No public key", details: nil)
        }
        var error: Unmanaged<CFError>?
        guard let raw = SecKeyCopyExternalRepresentation(pub, &error) as Data? else {
            throw failure(error?.takeRetainedValue())
        }
        return DeviceKeyInfoMsg(
            publicKey: spki(fromX963: raw).base64EncodedString(),
            securityLevel: hasSecureEnclave ? .secureEnclave : .software,
            attestationChain: [])
    }

    /// DER ECDSA signature (same format as Android's SHA256withECDSA). Blocks while the system
    /// shows a biometric prompt, so call it off the main thread.
    static func sign(tag: Data, data: Data, context: LAContext? = nil) throws -> Data {
        guard let key = privateKey(tag: tag, context: context) else {
            throw PigeonError(code: "KEY_MISSING", message: "No key for this alias", details: nil)
        }
        var error: Unmanaged<CFError>?
        guard
            let signature = SecKeyCreateSignature(
                key, .ecdsaSignatureMessageX962SHA256, data as CFData, &error) as Data?
        else {
            throw failure(error?.takeRetainedValue())
        }
        return signature
    }

    /// Wraps an uncompressed P-256 point (0x04 || X || Y) in a SubjectPublicKeyInfo.
    static func spki(fromX963 point: Data) -> Data {
        let header: [UInt8] = [
            0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08,
            0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
        ]
        return Data(header) + point
    }

    /// Maps Security / LocalAuthentication errors to the plugin's error codes.
    static func failure(_ error: Error?) -> PigeonError {
        let nsError = error as NSError?
        let code: String
        switch (nsError?.domain, nsError?.code) {
        case (LAError.errorDomain, LAError.userCancel.rawValue),
            (LAError.errorDomain, LAError.appCancel.rawValue),
            (LAError.errorDomain, LAError.systemCancel.rawValue),
            (NSOSStatusErrorDomain, Int(errSecUserCanceled)):
            code = "CANCELLED"
        case (LAError.errorDomain, LAError.biometryLockout.rawValue):
            code = "LOCKED_OUT"
        case (LAError.errorDomain, LAError.biometryNotEnrolled.rawValue):
            code = "NOT_ENROLLED"
        case (LAError.errorDomain, LAError.biometryNotAvailable.rawValue):
            code = "UNSUPPORTED"
        default:
            code = "FAILED"
        }
        return PigeonError(code: code, message: nsError?.localizedDescription, details: nil)
    }
}

final class DeviceKeyHostApiImpl: DeviceKeyHostApi {
    private func tag(_ alias: String) -> Data { SecureEnclaveKeys.tag("devicekey", alias) }

    // iOS has no per-key attestation (use App Attest for that); `challenge` and
    // `preferStrongBox` are Android-only.
    func create(alias: String, challenge: FlutterStandardTypedData?, preferStrongBox: Bool)
        async throws -> DeviceKeyInfoMsg
    {
        let tag = tag(alias)
        return try await PluginSupport.background {
            try SecureEnclaveKeys.create(tag: tag, flags: [])
            guard let info = try SecureEnclaveKeys.info(tag: tag) else {
                throw PigeonError(code: "FAILED", message: "Key generation failed", details: nil)
            }
            return info
        }
    }

    func info(alias: String) async throws -> DeviceKeyInfoMsg? {
        let tag = tag(alias)
        return try await PluginSupport.background { try SecureEnclaveKeys.info(tag: tag) }
    }

    func sign(alias: String, data: FlutterStandardTypedData) async throws -> FlutterStandardTypedData {
        let tag = tag(alias)
        let bytes = data.data
        let signature = try await PluginSupport.background {
            try SecureEnclaveKeys.sign(tag: tag, data: bytes)
        }
        return FlutterStandardTypedData(bytes: signature)
    }

    func exists(alias: String) throws -> Bool { SecureEnclaveKeys.exists(tag: tag(alias)) }

    func delete(alias: String) throws { SecureEnclaveKeys.delete(tag: tag(alias)) }
}
