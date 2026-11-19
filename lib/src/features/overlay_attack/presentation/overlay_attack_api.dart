import '../../../core/platform/action_guard.dart';
import '../../../core/result/check_type.dart';
import '../../../core/threats/threat_bus.dart';
import '../domain/overlay_attack_repository.dart';

/// Tapjacking (overlay attack) protection (Android). On iOS app sandboxing makes these attacks
/// impossible: [blockTouchesWhenObscured] throws `UnsupportedPlatformException` and
/// [obscuredTouches] never fires.
final class OverlayAttackApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.overlayAttack`.
  OverlayAttackApi(this._repository, this._threats);

  final OverlayAttackRepository _repository;
  final ThreatBus _threats;

  /// Drops touches that arrive while another app's window covers this one.
  Future<void> blockTouchesWhenObscured({bool block = true}) => guardAction(
    'blockTouchesWhenObscured',
    () => _repository.blockTouchesWhenObscured(block),
  );

  /// Fires on each touch received while obscured. Each event is also sent to
  /// `DeviceSafety.threats`.
  Stream<DateTime> get obscuredTouches =>
      _repository.obscuredTouches().map((at) {
        _threats.emit(CheckType.overlayAttack, 'obscured_touch');
        return at;
      });
}
