import '../../../core/platform/device_safety_platform.dart';
import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/result/risk_signal.dart';
import '../domain/vpn_repository.dart';

/// VPN detection through the platform API.
final class VpnRepositoryImpl implements VpnRepository {
  /// Creates the repository.
  VpnRepositoryImpl(this._platform, this._events);

  final VpnHostApi _platform;
  final PlatformEvents _events;

  @override
  Future<CheckReport> vpnReport() async =>
      (await _platform.vpnCheck()).toDomain();

  @override
  Stream<bool> changes() => _events.vpnChanges;
}
