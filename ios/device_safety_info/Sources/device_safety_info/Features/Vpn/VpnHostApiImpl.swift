import Foundation
import Network

enum VpnSignals {
    private static let vpnInterfacePrefixes = ["tap", "tun", "ppp", "ipsec", "utun"]

    static func report() -> RiskReport {
        guard let cf = CFNetworkCopySystemProxySettings() else { return .empty }
        let settings = cf.takeRetainedValue() as NSDictionary
        var signals: [RiskSignal] = []

        if let scoped = settings["__SCOPED__"] as? NSDictionary,
            let keys = scoped.allKeys as? [String],
            keys.contains(where: { key in vpnInterfacePrefixes.contains { key.hasPrefix($0) } })
        {
            signals.append(RiskSignal(id: "vpn.active", highRisk: false))
        }
        if let enabled = settings[kCFNetworkProxiesHTTPEnable as String] as? Int, enabled == 1 {
            signals.append(RiskSignal(id: "vpn.http_proxy", highRisk: false))
        }
        return RiskReport(signals: signals)
    }

    static var isVpnActive: Bool { report().signals.contains { $0.id == "vpn.active" } }
}

final class VpnHostApiImpl: VpnHostApi {
    func vpnCheck() async throws -> CheckReportMsg {
        try await PluginSupport.background { VpnSignals.report().msg }
    }
}

/// Sends whether a VPN is active on every network path change.
final class VpnChangeMonitor: VpnChangedStreamHandler {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.devamitkumartiwari.device_safety_info.vpn")

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<Bool>) {
        let pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { _ in
            let active = VpnSignals.isVpnActive
            DispatchQueue.main.async { sink.success(active) }
        }
        pathMonitor.start(queue: queue)
        monitor = pathMonitor
    }

    override func onCancel(withArguments arguments: Any?) {
        monitor?.cancel()
        monitor = nil
    }
}
