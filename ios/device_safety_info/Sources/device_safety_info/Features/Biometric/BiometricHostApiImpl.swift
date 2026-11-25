import Flutter
import Foundation
import LocalAuthentication
import Security

/// Biometric-approved actions: a Secure Enclave key whose use requires Face ID / Touch ID
/// (`.biometryCurrentSet`), so only a real biometric match produces the signature.
///
/// Enrollment changes: `.biometryCurrentSet` already makes the key unusable after a new face or
/// fingerprint is added. To report that as `invalidated` (rather than a generic failure), the
/// biometric domain state at enrollment time is stored in the Keychain and compared.
final class BiometricHostApiImpl: BiometricHostApi {
    private func tag(_ alias: String) -> Data { SecureEnclaveKeys.tag("biometric", alias) }
    private func stateAccount(_ alias: String) -> String { "dsi.biometric.state.\(alias)" }

    func isAvailable() throws -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func enroll(alias: String) async throws -> DeviceKeyInfoMsg {
        let context = LAContext()
        var laError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &laError)
        else {
            throw SecureEnclaveKeys.failure(laError)
        }
        let tag = tag(alias)
        let account = stateAccount(alias)
        let domainState = context.evaluatedPolicyDomainState ?? Data()
        return try await PluginSupport.background {
            try SecureEnclaveKeys.create(tag: tag, flags: [.biometryCurrentSet])
            Self.storeState(domainState, account: account)
            guard let info = try SecureEnclaveKeys.info(tag: tag) else {
                throw PigeonError(code: "FAILED", message: "Key generation failed", details: nil)
            }
            return info
        }
    }

    func approve(alias: String, payload: FlutterStandardTypedData, title: String, reason: String)
        async throws -> FlutterStandardTypedData
    {
        switch try keyState(alias: alias) {
        case .missing:
            throw PigeonError(code: "KEY_MISSING", message: "No key for this alias", details: nil)
        case .invalidated:
            throw PigeonError(
                code: "ENROLLMENT_CHANGED",
                message: "Biometric enrollment changed since the key was created", details: nil)
        case .valid:
            break
        }
        let context = LAContext()
        context.localizedReason = reason
        let tag = tag(alias)
        let bytes = payload.data
        let signature = try await PluginSupport.background {
            try SecureEnclaveKeys.sign(tag: tag, data: bytes, context: context)
        }
        return FlutterStandardTypedData(bytes: signature)
    }

    func keyState(alias: String) throws -> BiometricKeyStateMsg {
        guard SecureEnclaveKeys.exists(tag: tag(alias)) else { return .missing }
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        guard let current = context.evaluatedPolicyDomainState,
            let stored = Self.loadState(account: stateAccount(alias))
        else {
            // No biometrics enrolled any more, or no stored state: the key can't be used.
            return .invalidated
        }
        return current == stored ? .valid : .invalidated
    }

    func delete(alias: String) throws {
        SecureEnclaveKeys.delete(tag: tag(alias))
        Self.deleteState(account: stateAccount(alias))
    }

    // MARK: Domain state storage (Keychain generic password)

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "device_safety_info",
            kSecAttrAccount as String: account,
        ]
    }

    private static func storeState(_ state: Data, account: String) {
        deleteState(account: account)
        var query = baseQuery(account)
        query[kSecValueData as String] = state
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadState(account: String) -> Data? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func deleteState(account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }
}
