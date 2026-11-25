import 'dart:typed_data';

import '../../../core/platform/device_safety_platform.dart';
import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/result/risk_signal.dart';
import '../domain/screen_protection_repository.dart';

/// Screen protection through the platform API and event channels.
final class ScreenProtectionRepositoryImpl
    implements ScreenProtectionRepository {
  /// Creates the repository.
  ScreenProtectionRepositoryImpl(this._platform, this._events);

  final ScreenProtectionHostApi _platform;
  final PlatformEvents _events;

  @override
  Future<void> blockScreenshots(bool block) =>
      _platform.blockScreenshots(block);

  @override
  Future<bool> isScreenshotBlocked() => _platform.isScreenshotBlocked();

  @override
  Future<void> setOverlayMode(
    ScreenshotOverlayMode mode, {
    required double blurRadius,
    int? argbColor,
    Uint8List? imageBytes,
  }) => _platform.setOverlayMode(
    OverlayConfigMsg(
      mode: switch (mode) {
        ScreenshotOverlayMode.none => OverlayModeMsg.none,
        ScreenshotOverlayMode.blur => OverlayModeMsg.blur,
        ScreenshotOverlayMode.color => OverlayModeMsg.color,
        ScreenshotOverlayMode.image => OverlayModeMsg.image,
      },
      blurRadius: blurRadius,
      argbColor: argbColor,
      imageBytes: imageBytes,
    ),
  );

  @override
  Future<void> clearOverlayMode() => _platform.clearOverlayMode();

  @override
  Future<CheckReport> captureReport() async =>
      (await _platform.screenCaptureCheck()).toDomain();

  @override
  Future<bool> isRecordingDetectionSupported() =>
      _platform.isRecordingDetectionSupported();

  @override
  Stream<DateTime> screenshots() =>
      _events.screenshots.map(DateTime.fromMillisecondsSinceEpoch);

  @override
  Stream<bool> captureChanges() => _events.captureChanges;

  @override
  Stream<bool> recordingChanges() => _events.recordingChanges;
}
