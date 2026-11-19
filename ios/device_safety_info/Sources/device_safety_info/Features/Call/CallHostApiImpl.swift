import AVFoundation
import CallKit
import UIKit

final class CallHostApiImpl: CallHostApi {
    private let observer = CXCallObserver()

    func isCallActive() throws -> Bool { observer.calls.contains { !$0.hasEnded } }

    // The call screening role is an Android concept.
    func isScreeningRoleAvailable() throws -> Bool { false }

    func isScreeningRoleHeld() throws -> Bool { false }

    func openScreeningRoleSettings() throws {
        throw PluginSupport.unsupported("openScreeningRoleSettings")
    }
}

/// Call start/end events from CallKit's call observer (system and VoIP calls), plus audio
/// session interruptions, which are the only signal for some third-party call apps.
final class CallActivityMonitor: CallActivityStreamHandler {
    private let callObserver = CXCallObserver()
    private lazy var delegate = CallObserverDelegate { [weak self] in self?.evaluate() }
    private var sink: PigeonEventSink<CallEventMsg>?
    private var tokens: [NSObjectProtocol] = []
    private var lastActive = false
    private var lastSource: CallSourceMsg?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<CallEventMsg>) {
        self.sink = sink
        callObserver.setDelegate(delegate, queue: .main)
        let center = NotificationCenter.default
        tokens = [
            center.addObserver(
                forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
            ) { [weak self] note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                    AVAudioSession.InterruptionType(rawValue: raw) == .began
                else { return }
                self?.emit(active: true, source: .audioInterrupted)
            },
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.evaluate() },
        ]
        evaluate()
    }

    override func onCancel(withArguments arguments: Any?) {
        callObserver.setDelegate(nil, queue: nil)
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens = []
        sink = nil
        lastActive = false
        lastSource = nil
    }

    private func evaluate() {
        let active = callObserver.calls.contains { !$0.hasEnded }
        emit(active: active, source: active ? .callKitObserved : nil)
    }

    private func emit(active: Bool, source: CallSourceMsg?) {
        if active == lastActive && (!active || source == lastSource) { return }
        let reported: CallSourceMsg = active ? (source ?? .callKitObserved) : (lastSource ?? .unknown)
        sink?.success(CallEventMsg(source: reported, started: active, timestampMs: PluginSupport.nowMillis()))
        lastActive = active
        lastSource = active ? source : nil
    }
}

/// CXCallObserverDelegate must be an NSObject; Pigeon's stream handler base class isn't.
private final class CallObserverDelegate: NSObject, CXCallObserverDelegate {
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        onChange()
    }
}
