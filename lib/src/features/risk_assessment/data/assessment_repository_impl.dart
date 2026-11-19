import '../../../core/config/device_safety_config.dart';
import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/platform/native_checks_ffi.dart';
import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';
import '../../../core/utils/platform_guard.dart';
import '../../accessibility_abuse/domain/accessibility_signals.dart';
import '../../malware/domain/malware_repository.dart';
import '../../notification_listener/domain/notification_listener_signals.dart';
import '../domain/assessment_repository.dart';

/// One `BatchHostApi.runChecks` call (the platform runs the checks in parallel) alongside one
/// native FFI call on a background isolate. The native signals are merged into root, hooking
/// and debugger; the allowlist-based checks are evaluated here from the raw lists.
final class AssessmentRepositoryImpl implements AssessmentRepository {
  /// Creates the repository.
  AssessmentRepositoryImpl(this._batch, this._ffi);

  final BatchHostApi _batch;
  final NativeChecksSource _ffi;

  static const _ffiChecks = {
    CheckType.root,
    CheckType.hooking,
    CheckType.debugger,
  };

  @override
  Future<Map<CheckType, CheckReport>> collect(
    Set<CheckType> types,
    DeviceSafetyConfig config,
  ) async {
    final request = BatchRequestMsg(
      checkIds: [
        for (final t in types)
          if (t != CheckType.overlayAttack) t.id,
      ],
      malwarePackages: types.contains(CheckType.malware)
          ? config.malwarePackages.toList()
          : const [],
    );
    final (result, native) = await (
      _batch.runChecks(request),
      types.any(_ffiChecks.contains)
          ? _ffi.collect()
          : Future.value(NativeChecks.unavailable),
    ).wait;

    final out = <CheckType, CheckReport>{
      for (final MapEntry(:key, :value) in result.reports.entries)
        if (CheckType.fromId(key) case final t? when types.contains(t))
          t: value.toDomain(),
    };

    void mergeNative(CheckType type, List<RiskSignal> signals) {
      if (!types.contains(type)) return;
      final platform = out[type];
      // A platform check that failed (missing) stays missing: Dart reports it as an error
      // rather than hiding the failure behind the native result.
      if (platform == null) return;
      out[type] = platform.merge(
        CheckReport(signals, supported: native.supported),
      );
    }

    mergeNative(CheckType.root, native.rootSignals);
    mergeNative(CheckType.hooking, native.hookingSignals);
    mergeNative(CheckType.debugger, native.debuggerSignals);

    final android = PlatformGuard.isAndroid;
    if (types.contains(CheckType.accessibility)) {
      out[CheckType.accessibility] = android
          ? CheckReport(
              accessibilitySignals([
                for (final s in result.accessibilityServices)
                  AccessibilityService(
                    s.id,
                    canRetrieveWindowContent: s.canRetrieveWindowContent,
                  ),
              ], config.accessibilityAllowlist),
            )
          : CheckReport.unsupported;
    }
    if (types.contains(CheckType.notificationListener)) {
      out[CheckType.notificationListener] = android
          ? CheckReport(
              notificationListenerSignals(
                result.notificationListeners,
                config.notificationListenerAllowlist,
              ),
            )
          : CheckReport.unsupported;
    }
    if (types.contains(CheckType.malware)) {
      out[CheckType.malware] = android
          ? CheckReport(malwareSignals(result.installedPackages))
          : CheckReport.unsupported;
    }
    if (types.contains(CheckType.overlayAttack)) {
      // Event-only; there's nothing to poll.
      out[CheckType.overlayAttack] = CheckReport.unsupported;
    }
    return out;
  }
}
