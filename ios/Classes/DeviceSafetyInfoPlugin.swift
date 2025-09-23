import Flutter
import UIKit
import IOSSecuritySuite
import LocalAuthentication
import Foundation

public class DeviceSafetyInfoPlugin: NSObject, FlutterPlugin {

    private let vpnProtocolsKeysIdentifiers = [
        "tap", "tun", "ppp", "ipsec", "utun",
    ]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "device_safety_info", binaryMessenger: registrar.messenger())
        let instance = DeviceSafetyInfoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "isRootedDevice":
            let isRooted = IOSSecuritySuite.amIJailbroken()
            result(isRooted)
        case "isRealDevice":
            let isEmulator = IOSSecuritySuite.amIRunInEmulator()
            result(!isEmulator)
        case "isScreenLock":
            let context = LAContext()
            let isScreenLockEnabled = context.canEvaluatePolicy(
                .deviceOwnerAuthentication, error: nil)
            result(isScreenLockEnabled)
        case "isVPNCheck":
            let isVPN = isVpnActive()
            result(isVPN)
        case "isInstalledFromStore":
            let isInstalledFromStore = isValidApp()
            result(isInstalledFromStore)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func isVpnActive() -> Bool {
        guard let cfDict = CFNetworkCopySystemProxySettings() else { return false }
        let nsDict = cfDict.takeRetainedValue() as NSDictionary
        guard let keys = nsDict["__SCOPED__"] as? NSDictionary,
            let allKeys = keys.allKeys as? [String]
        else { return false }

        // Check for VPN-related tunneling protocols
        return allKeys.contains { key in
            vpnProtocolsKeysIdentifiers.contains { key.starts(with: $0) }
        }
    }

    private func isValidApp() -> Bool {
        return isInstalledFromStoreInternal()
    }

    private func isInstalledFromStoreInternal() -> Bool {
        // Check if the app is running in the simulator
        #if TARGET_OS_SIMULATOR
            print("App is running in the simulator")
            return false
        #else
            // Check for Debug build first and handle accordingly
            #if DEBUG
                print("App is running in DEBUG mode")
                return false
            #else
                // If not DEBUG or simulator, proceed with receipt check
                guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
                    return false
                }

                let path = appStoreReceiptURL.path
                print("Receipt path: \(path)")  // Log the path for debugging

                // Check if the path contains "sandboxReceipt" (TestFlight) or "receipt" (App Store)
                if path.contains("sandboxReceipt") {
                    print("App installed via TestFlight")
                    return true
                } else if path.contains("receipt") {
                    print("App installed from App Store")
                    return true
                } else {
                    print("App installed from unknown source")
                    return false
                }
            #endif
        #endif
    }

}
