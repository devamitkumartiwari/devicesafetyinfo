import Flutter
import UIKit
import CallKit
import AVFoundation

// Detects "is any call active" generically, mirroring the Android side's philosophy: cannot
// identify which app is calling, only that a call is happening. Two complementary signals:
//
// 1. CXCallObserver (CallKit) — real, public, no special entitlement for observation-only use —
//    but only sees calls the placing app specifically routed through CallKit. Not every VoIP app
//    integrates CallKit for every call type (confirmed gap: some WhatsApp video calls aren't
//    observed this way).
// 2. AVAudioSession.interruptionNotification — no permission/entitlement needed, fires for any
//    audio-focus-stealing event. Apple's own docs warn there's no guaranteed .began/.ended
//    pairing, so only .began is acted on directly; the "ended" transition is left to
//    CXCallObserver changes and the didBecomeActive re-sync below, which also closes most of the
//    "app suspended while a real call is in progress" delivery gap.
class CallActivityEventStreamHandler: NSObject, FlutterStreamHandler, CXCallObserverDelegate {
    let callObserver = CXCallObserver()

    private var eventSink: FlutterEventSink?
    private var lastActive = false
    private var lastSource: String?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        // Delegate queue is not guaranteed to be main — dispatch to main before touching eventSink,
        // same convention as ConnectivityEventStreamHandler's monitorQueue.
        callObserver.setDelegate(self, queue: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        evaluateAndEmit()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        callObserver.setDelegate(nil, queue: nil)
        NotificationCenter.default.removeObserver(
            self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: UIApplication.didBecomeActiveNotification, object: nil)
        eventSink = nil
        lastActive = false
        lastSource = nil
        return nil
    }

    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        DispatchQueue.main.async { self.evaluateAndEmit(hintedSource: "callKitObserved") }
    }

    @objc private func onAudioInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue),
              type == .began
        else { return }
        emit(active: true, source: "audioInterrupted")
    }

    @objc private func onAppDidBecomeActive() {
        evaluateAndEmit()
    }

    private func evaluateAndEmit(hintedSource: String? = nil) {
        let active = callObserver.calls.contains { !$0.hasEnded }
        emit(active: active, source: active ? (hintedSource ?? "callKitObserved") : nil)
    }

    private func emit(active: Bool, source: String?) {
        if active == lastActive && (!active || source == lastSource) { return }
        let payload: [String: Any] = [
            "source": active ? (source ?? "callKitObserved") : (lastSource ?? "unknown"),
            "state": active ? "started" : "ended",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
        ]
        eventSink?(payload)
        lastActive = active
        lastSource = active ? source : nil
    }
}
