import '../../../core/result/check_type.dart';
import '../../../core/runner/check_runner.dart';
import '../../../core/runner/detection_api.dart';
import '../../../core/threats/threat_bus.dart';
import '../../../core/utils/stream_utils.dart';
import '../domain/vpn_repository.dart';

/// VPN and HTTP proxy detection. Both are low risk by default (counted only under the strict
/// policy), since VPNs are common and legitimate; raise them with
/// `signalOverrides: {'vpn.active': .high}` if your threat model needs it.
final class VpnApi extends DetectionApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.vpn`.
  VpnApi(CheckRunner runner, this._repository, this._threats)
    : _runner = runner,
      super(CheckType.vpn, runner, _repository.vpnReport);

  final VpnRepository _repository;
  final ThreatBus _threats;
  final CheckRunner _runner;

  /// Whether a VPN is active, emitted on connectivity changes (settled for 500 ms,
  /// de-duplicated). Each change invalidates the cached [check]; a VPN connecting is also
  /// sent to `DeviceSafety.threats`.
  Stream<bool> get changes => _repository
      .changes()
      .settled(const Duration(milliseconds: 500))
      .map((active) {
        _runner.invalidate(CheckType.vpn);
        if (active) _threats.emit(CheckType.vpn, 'vpn_connected');
        return active;
      });
}
