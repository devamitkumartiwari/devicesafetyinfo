/// Device and app security for Flutter: root/jailbreak, emulator, hooking and debugger
/// detection with configurable policies; device posture checks; screenshot, clipboard,
/// app-switcher and tapjacking protection; VPN, malware and call detection; Play Integrity and
/// App Attest tokens.
///
/// Start with [DeviceSafety]:
///
/// ```dart
/// await DeviceSafety.initialize(DeviceSafetyConfig(
///   policies: {CheckType.root: .strict},
///   failModes: {CheckType.root: .closed},
/// ));
/// final report = await DeviceSafety.assess();
/// if (report.detected) showWarning(report.flags);
/// ```
library;

export 'src/core/config/device_safety_config.dart';
export 'src/core/config/fail_mode.dart';
export 'src/core/config/risk_policy.dart';
export 'src/core/result/check_result.dart';
export 'src/core/result/check_type.dart';
export 'src/core/result/device_safety_exception.dart';
export 'src/core/result/risk_signal.dart'
    show RiskLevel, RiskSignal, SignalSource;
export 'src/core/runner/detection_api.dart' show DetectionApi;
export 'src/core/threats/threat_bus.dart' show ThreatEvent;
export 'src/device_safety.dart';
export 'src/features/accessibility_abuse/domain/accessibility_signals.dart'
    show AccessibilityService;
export 'src/features/accessibility_abuse/presentation/accessibility_api.dart';
export 'src/features/app_integrity/presentation/integrity_api.dart';
export 'src/features/app_switcher/presentation/app_switcher_api.dart';
export 'src/features/call_activity/presentation/call_activity_api.dart';
export 'src/features/call_screening/presentation/call_screening_api.dart';
export 'src/features/clipboard/presentation/clipboard_api.dart';
export 'src/features/debugger/presentation/debugger_api.dart';
export 'src/features/device_posture/presentation/posture_api.dart';
export 'src/features/emulator/presentation/emulator_api.dart';
export 'src/features/hooking/presentation/hooking_api.dart';
export 'src/features/idle_timeout/presentation/idle_timeout_guard.dart';
export 'src/features/ioc_domain/presentation/ioc_domain_api.dart';
export 'src/features/malware/presentation/malware_api.dart';
export 'src/features/notification_listener/domain/notification_listener_signals.dart'
    show NotificationListenerInfo;
export 'src/features/notification_listener/presentation/notification_listener_api.dart';
export 'src/features/overlay_attack/presentation/overlay_attack_api.dart';
export 'src/features/risk_assessment/presentation/risk_assessment.dart';
export 'src/features/root/presentation/root_api.dart';
export 'src/features/screen_protection/presentation/screen_protection_api.dart';
export 'src/features/screen_protection/presentation/widgets/secure_screen.dart';
export 'src/features/tampering/domain/tampering_signals.dart'
    show SigningInfo, normalizeCertificateDigest;
export 'src/features/tampering/presentation/tampering_api.dart';
export 'src/features/environment/presentation/environment_apis.dart';
export 'src/features/pinning/presentation/pinning_api.dart';
export 'src/features/secure_input/domain/secure_input_config.dart';
export 'src/features/secure_input/presentation/secure_editable_text.dart';
export 'src/features/secure_input/presentation/secure_field_guard.dart';
export 'src/core/result/device_key_info.dart';
export 'src/features/device_key/presentation/device_key_api.dart';
export 'src/features/biometric/presentation/biometric_api.dart';
export 'src/features/version_check/presentation/version_check_api.dart';
export 'src/features/vpn/presentation/vpn_api.dart';
