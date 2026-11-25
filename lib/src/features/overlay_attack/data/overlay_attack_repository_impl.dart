import '../../../core/platform/device_safety_platform.dart';
import '../../../core/platform/generated/device_safety_api.g.dart';
import '../domain/overlay_attack_repository.dart';

/// Overlay attack protection through the platform API.
final class OverlayAttackRepositoryImpl implements OverlayAttackRepository {
  /// Creates the repository.
  OverlayAttackRepositoryImpl(this._platform, this._events);

  final OverlayAttackHostApi _platform;
  final PlatformEvents _events;

  @override
  Future<void> blockTouchesWhenObscured(bool block) =>
      _platform.blockTouchesWhenObscured(block);

  @override
  Stream<DateTime> obscuredTouches() =>
      _events.overlayAttacks.map(DateTime.fromMillisecondsSinceEpoch);
}
