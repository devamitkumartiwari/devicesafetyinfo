import Flutter
import UIKit

/// The `isScreenRecordingDetectionSupported` method plus the `screen_recording_events`
/// EventChannel.
///
/// iOS has no API that distinguishes an active screen-recording session from screen
/// mirroring/AirPlay — both surface through the identical `UIScreen.isCaptured` /
/// `capturedDidChangeNotification` signal that `ScreenCaptureHandler` already observes (see
/// `IOSScreenCaptureSignal`, which both handlers consume so there's a single shared observer
/// rather than two independently-registered ones). So on iOS, `screen_recording_events` and
/// `screen_capture_events` report identically at all times. The distinction between "recording"
/// and "mirroring/capture" is only real on Android, which has a dedicated MediaProjection-based
/// recording-session callback (API 35+).
final class ScreenRecordingHandler: NSObject, FlutterStreamHandler, DSIMethodHandler {
    let methods: Set<String> = ["isScreenRecordingDetectionSupported"]

    private var eventSink: FlutterEventSink?
    private var listenerToken: UUID?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isScreenRecordingDetectionSupported":
            // The underlying UIScreen.isCaptured signal has existed since iOS 11, and this
            // plugin's minimum deployment target is iOS 16 (see Package.swift / the podspec), so
            // detection is unconditionally supported — no version gate needed.
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        listenerToken = IOSScreenCaptureSignal.shared.addListener { [weak self] captured in
            self?.eventSink?(captured)
        }
        events(IOSScreenCaptureSignal.shared.isCaptured)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let token = listenerToken {
            IOSScreenCaptureSignal.shared.removeListener(token)
        }
        listenerToken = nil
        eventSink = nil
        return nil
    }
}
