import Flutter
import Foundation

/// `isVPNCheck` — inspects the system proxy settings' scoped keys for tunnel-interface prefixes.
final class VpnHandler: DSIMethodHandler {
    let methods: Set<String> = ["isVPNCheck"]

    // Set for O(1) prefix-lookup performance.
    private let vpnProtocolsKeysIdentifiers: Set<String> = [
        "tap", "tun", "ppp", "ipsec", "utun",
    ]

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isVPNCheck":
            result(isVpnActive())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func isVpnActive() -> Bool {
        guard let cfDict = CFNetworkCopySystemProxySettings() else { return false }
        let nsDict = cfDict.takeRetainedValue() as NSDictionary
        guard let keys = nsDict["__SCOPED__"] as? NSDictionary,
              let allKeys = keys.allKeys as? [String]
        else { return false }
        return allKeys.contains { key in
            vpnProtocolsKeysIdentifiers.contains { key.starts(with: $0) }
        }
    }
}
