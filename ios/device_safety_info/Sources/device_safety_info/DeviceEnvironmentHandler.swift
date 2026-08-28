import Flutter
import LocalAuthentication

/// One-shot environment checks that don't need any persistent state: device passcode/biometric
/// lock, store-install provenance, and two Android-only concepts that always report a fixed value
/// on iOS.
final class DeviceEnvironmentHandler: DSIMethodHandler {
    let methods: Set<String> = [
        "isScreenLock", "isInstalledFromStore", "isDeveloperMode", "isExternalStorage",
    ]

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isScreenLock":
            let context = LAContext()
            result(context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil))
        case "isInstalledFromStore":
            result(isInstalledFromStoreInternal())
        case "isDeveloperMode":
            // Developer mode state is not readable via public iOS API.
            result(false)
        case "isExternalStorage":
            // External storage in the Android sense does not exist on iOS.
            result(false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func isInstalledFromStoreInternal() -> Bool {
        #if targetEnvironment(simulator)
            return false
        #else
            #if DEBUG
                return false
            #else
                guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
                    return false
                }
                let path = appStoreReceiptURL.path
                // sandboxReceipt = TestFlight, receipt = App Store
                return path.contains("sandboxReceipt") || path.contains("receipt")
            #endif
        #endif
    }
}
