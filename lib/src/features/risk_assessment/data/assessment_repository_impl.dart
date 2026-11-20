import '../../../core/config/device_safety_config.dart';
import '../../../core/platform/generated/device_safety_api.g.dart';
import '../../../core/platform/mappers.dart';
import '../../../core/platform/native_checks_ffi.dart';
import '../../../core/platform/native_merge.dart';
import '../../../core/result/check_type.dart';
import '../../../core/result/risk_signal.dart';
import '../../../core/utils/platform_guard.dart';
import '../../accessibility_abuse/domain/accessibility_signals.dart';
import '../../malware/domain/malware_repository.dart';
import '../../notification_listener/domain/notification_listener_signals.dart';
import '../../tampering/data/tampering_repository_impl.dart';
import '../../tampering/domain/tampering_signals.dart';
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
    // Listen to the native future right away so it can't fail unhandled while the platform
    // call is pending; a native failure is an unavailable library.
    final nativeFuture =
        (types.any(_ffiChecks.contains)
                ? _ffi.collect()
                : Future.value(NativeChecks.unavailable))
            .catchError((Object _) => NativeChecks.unavailable);
    BatchResultMsg? batch;
    Object? error;
    StackTrace? stack;
    try {
      batch = await _batch.runChecks(request);
    } catch (e, st) {
      error = e;
      stack = st;
    }
    final native = await nativeFuture;

    if (batch == null) {
      // The whole platform call failed. Keep any high-risk native evidence (the other checks
      // are reported as errors by the runner); with none, surface the failure as before.
      final salvaged = <CheckType, CheckReport>{
        for (final type in types.where(_ffiChecks.contains))
          if (nativeReport(native, _nativeSignals(type, native)) case final r
              when hasHighRisk(r))
            type: CheckReport([...r.signals, platformCheckFailedSignal]),
      };
      if (salvaged.isEmpty) Error.throwWithStackTrace(error!, stack!);
      config.logger?.call(
        'Batch platform call failed; keeping native evidence',
        error: error,
        stackTrace: stack,
      );
      return salvaged;
    }
    final result = batch;

    final out = <CheckType, CheckReport>{
      for (final MapEntry(:key, :value) in result.reports.entries)
        if (CheckType.fromId(key) case final t? when types.contains(t))
          t: value.toDomain(),
    };

    for (final type in _ffiChecks) {
      if (!types.contains(type)) continue;
      final fromNative = nativeReport(native, _nativeSignals(type, native));
      final platform = out[type];
      if (platform != null) {
        out[type] = platform
            .merge(fromNative)
            .merge(
              CheckReport(
                type == CheckType.root
                    ? rootLayerMismatch(platform, native)
                    : const [],
                supported: false,
              ),
            );
      } else if (hasHighRisk(fromNative)) {
        // The platform half failed, but native evidence stands on its own.
        out[type] = CheckReport([
          ...fromNative.signals,
          platformCheckFailedSignal,
        ]);
      }
      // Otherwise a failed platform check stays missing, so the runner reports an error
      // instead of hiding the failure behind an empty native result.
    }

    final android = PlatformGuard.isAndroid;
    // A list the platform couldn't read stays missing, so the runner reports an error instead
    // of evaluating an empty (clean-looking) list.
    bool listFailed(CheckType type) => result.failedLists.contains(type.id);
    if (types.contains(CheckType.accessibility) &&
        !listFailed(CheckType.accessibility)) {
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
    if (types.contains(CheckType.notificationListener) &&
        !listFailed(CheckType.notificationListener)) {
      out[CheckType.notificationListener] = android
          ? CheckReport(
              notificationListenerSignals(
                result.notificationListeners,
                config.notificationListenerAllowlist,
              ),
            )
          : CheckReport.unsupported;
    }
    if (types.contains(CheckType.malware) && !listFailed(CheckType.malware)) {
      out[CheckType.malware] = android
          ? CheckReport(malwareSignals(result.installedPackages))
          : CheckReport.unsupported;
    }
    if (types.contains(CheckType.tampering)) {
      final signing = result.signing;
      if (!PlatformGuard.isSupported ||
          (android && config.expectedSigningCertificates.isEmpty)) {
        out[CheckType.tampering] = CheckReport.unsupported;
      } else if (signing != null) {
        out[CheckType.tampering] = tamperingReport(
          signing.toDomain(),
          android: android,
          expectedCertificates: config.expectedSigningCertificates,
          expectedTeamId: config.expectedIosTeamId,
        );
      }
      // No signing info: left missing, reported as an error.
    }
    if (types.contains(CheckType.overlayAttack)) {
      // Event-only; there's nothing to poll.
      out[CheckType.overlayAttack] = CheckReport.unsupported;
    }
    return out;
  }

  static List<RiskSignal> _nativeSignals(CheckType type, NativeChecks n) =>
      switch (type) {
        CheckType.root => n.rootSignals,
        CheckType.hooking => n.hookingSignals,
        CheckType.debugger => n.debuggerSignals,
        _ => const [],
      };
}
