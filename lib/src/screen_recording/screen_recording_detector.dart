import 'dart:async';

import '../core/device_safety_channels.dart';

/// Detects an active screen-recording session, distinct from [DeviceSafetyInfo.isScreenCaptured] /
/// [DeviceSafetyInfo.onScreenCapturedChanged], which cover screen mirroring/external-display
/// capture instead.
///
/// Android: backed by the platform's screen-recording-session callback (API 35+ only — see
/// [isSupported]). iOS: backed by `UIScreen.isCaptured`, the same OS signal
/// [DeviceSafetyInfo.isScreenCaptured] already observes on that platform — iOS has no separate API
/// to distinguish "recording" from "mirroring/AirPlay", so the two report identically there. The
/// distinction between capture and recording is only real on Android.
class ScreenRecordingDetector {
  ScreenRecordingDetector._();

  static Stream<bool>? _onScreenRecordingChanged;

  /// Whether this platform/OS version can actually distinguish a screen-recording session from
  /// other forms of capture. `false` (rather than silently-wrong data) below Android API 35;
  /// `true` on iOS.
  static Future<bool> get isSupported async {
    final result = await DeviceSafetyChannels.method.invokeMethod<bool>(
      'isScreenRecordingDetectionSupported',
    );
    return result ?? false;
  }

  /// Fires whenever screen recording starts (`true`) or stops (`false`). Subscribing starts native
  /// observation; cancelling the subscription stops it — there are no separate start/stop methods.
  ///
  /// On Android, [isSupported] reflects OS *version* support only — it cannot know ahead of time
  /// whether this device's manufacturer actually grants the underlying permission to third-party
  /// apps. If it doesn't (observed on at least one Samsung device, which enforces this through an
  /// internal Knox-branded path even with the permission declared), this stream delivers a
  /// `PlatformException('permission_denied', ...)` via [Stream.listen]'s `onError` instead of
  /// values — always attach an `onError` handler.
  static Stream<bool> get onScreenRecordingChanged {
    _onScreenRecordingChanged ??= DeviceSafetyChannels.screenRecording
        .receiveBroadcastStream()
        .map<bool>((event) => event as bool);
    return _onScreenRecordingChanged!;
  }

  /// Convenience filter over [onScreenRecordingChanged] that only fires when recording starts.
  static Stream<void> get onScreenRecordingStarted =>
      onScreenRecordingChanged.where((started) => started).map((_) {});

  /// Convenience filter over [onScreenRecordingChanged] that only fires when recording stops.
  static Stream<void> get onScreenRecordingStopped =>
      onScreenRecordingChanged.where((started) => !started).map((_) {});
}
