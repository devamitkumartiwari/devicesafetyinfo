import 'dart:typed_data';

import '../../../core/platform/action_guard.dart';
import '../../../core/result/check_type.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../../../core/threats/threat_bus.dart';
import '../../../core/utils/stream_utils.dart';
import '../domain/screen_protection_repository.dart';

export '../domain/screen_protection_repository.dart' show ScreenshotOverlayMode;

/// Screenshot and screen-recording protection.
///
/// As a detection check ([check], `CheckType.screenCapture`): recording or mirroring active
/// is high risk; an external presentation display (HDMI, Cast) is low risk.
final class ScreenProtectionApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.screen`.
  ScreenProtectionApi(CheckRunner runner, this._repository, this._threats)
    : _runner = runner,
      super(CheckType.screenCapture, runner, _repository.captureReport);

  final ScreenProtectionRepository _repository;
  final ThreatBus _threats;
  final CheckRunner _runner;

  /// Blocks (or unblocks) screenshots and screen recording of the app (FLAG_SECURE on
  /// Android, a secure layer on iOS). Prefer the `SecureScreen` widget for single screens.
  Future<void> blockScreenshots({bool block = true}) => guardAction(
    'blockScreenshots',
    () => _repository.blockScreenshots(block),
  );

  /// Whether screenshots are currently blocked.
  Future<bool> isScreenshotBlocked() =>
      guardAction('isScreenshotBlocked', _repository.isScreenshotBlocked);

  /// Shows [mode] over the app while the screen is captured, instead of blocking capture.
  /// [argbColor] is used by [ScreenshotOverlayMode.color], [imageBytes] (PNG/JPEG) by
  /// [ScreenshotOverlayMode.image].
  Future<void> setOverlayMode(
    ScreenshotOverlayMode mode, {
    double blurRadius = 10,
    int? argbColor,
    Uint8List? imageBytes,
  }) => guardAction(
    'setOverlayMode',
    () => _repository.setOverlayMode(
      mode,
      blurRadius: blurRadius,
      argbColor: argbColor,
      imageBytes: imageBytes,
    ),
  );

  /// Removes the capture overlay.
  Future<void> clearOverlayMode() =>
      guardAction('clearOverlayMode', _repository.clearOverlayMode);

  /// Whether screen-recording state can be observed (Android 15+, iOS).
  Future<bool> isRecordingDetectionSupported() => guardAction(
    'isRecordingDetectionSupported',
    _repository.isRecordingDetectionSupported,
  );

  /// Fires when the user takes a screenshot. Each event is also sent to
  /// `DeviceSafety.threats`.
  Stream<DateTime> get onScreenshot => _repository.screenshots().map((at) {
    _threats.emit(CheckType.screenCapture, 'screenshot');
    return at;
  });

  /// Capture (recording or mirroring) state, settled for 300 ms and de-duplicated. Starting a
  /// capture is also sent to `DeviceSafety.threats`, and invalidates the cached [check].
  Stream<bool> get captureChanges => _repository
      .captureChanges()
      .settled(const Duration(milliseconds: 300))
      .map((captured) {
        _runner.invalidate(CheckType.screenCapture);
        if (captured) _threats.emit(CheckType.screenCapture, 'capture_started');
        return captured;
      });

  /// Recording state (Android 15+, iOS), settled and de-duplicated like [captureChanges].
  Stream<bool> get recordingChanges => _repository
      .recordingChanges()
      .settled(const Duration(milliseconds: 300))
      .map((recording) {
        _runner.invalidate(CheckType.screenCapture);
        if (recording) {
          _threats.emit(CheckType.screenCapture, 'recording_started');
        }
        return recording;
      });
}
