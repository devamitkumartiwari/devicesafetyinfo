import '../../../core/result/risk_signal.dart';

/// VPN and proxy detection.
abstract interface class VpnRepository {
  /// Raw VPN / proxy report.
  Future<CheckReport> vpnReport();

  /// Whether a VPN is active, on each connectivity change.
  Stream<bool> changes();
}
