import Flutter
import Network

/// Stream handler for `connectivity_events` (fires on any network path change).
class ConnectivityEventStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.devamitkumartiwari.device_safety_info.connectivity")

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        let pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.eventSink?(nil) }
        }
        pathMonitor.start(queue: monitorQueue)
        self.monitor = pathMonitor
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        monitor?.cancel()
        monitor = nil
        eventSink = nil
        return nil
    }
}
