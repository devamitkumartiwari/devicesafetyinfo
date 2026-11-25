import 'dart:convert';

import '../result/device_key_info.dart';
import '../result/risk_signal.dart';
import 'generated/device_safety_api.g.dart';

/// Converts platform messages to domain types. The only place that knows both.
extension CheckReportMsgMapping on CheckReportMsg {
  /// The domain report.
  CheckReport toDomain() => CheckReport([
    for (final s in signals) s.toDomain(),
  ], supported: supported);
}

/// Converts a platform signal.
extension SignalMsgMapping on SignalMsg {
  /// The domain signal.
  RiskSignal toDomain() => RiskSignal(id, switch (level) {
    SignalLevelMsg.high => RiskLevel.high,
    SignalLevelMsg.low => RiskLevel.low,
  });
}

/// Converts the platform message.
extension DeviceKeyInfoMsgMapping on DeviceKeyInfoMsg {
  /// The domain entity.
  DeviceKeyInfo toDomain() => DeviceKeyInfo(
    publicKey: base64.decode(publicKey),
    securityLevel: switch (securityLevel) {
      KeySecurityLevelMsg.strongBox => KeySecurityLevel.strongBox,
      KeySecurityLevelMsg.tee => KeySecurityLevel.tee,
      KeySecurityLevelMsg.secureEnclave => KeySecurityLevel.secureEnclave,
      KeySecurityLevelMsg.software => KeySecurityLevel.software,
    },
    attestationChain: [for (final c in attestationChain) base64.decode(c)],
  );
}
