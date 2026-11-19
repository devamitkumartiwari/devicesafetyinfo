import 'dart:typed_data';

import '../../../core/result/risk_signal.dart';

/// What the app shows in place of its content while the screen is captured.
enum ScreenshotOverlayMode {
  /// No overlay.
  none,

  /// A blur over the app.
  blur,

  /// A solid color.
  color,

  /// An image.
  image,
}

/// Platform screen protection: blocking screenshots, the capture overlay, capture detection
/// and the live screenshot / capture / recording events.
abstract interface class ScreenProtectionRepository {
  Future<void> blockScreenshots(bool block);
  Future<bool> isScreenshotBlocked();
  Future<void> setOverlayMode(
    ScreenshotOverlayMode mode, {
    required double blurRadius,
    int? argbColor,
    Uint8List? imageBytes,
  });
  Future<void> clearOverlayMode();
  Future<CheckReport> captureReport();
  Future<bool> isRecordingDetectionSupported();

  /// Times of screenshots.
  Stream<DateTime> screenshots();

  /// Capture (recording or mirroring) state changes.
  Stream<bool> captureChanges();

  /// Recording state changes (Android 15+, iOS).
  Stream<bool> recordingChanges();
}
