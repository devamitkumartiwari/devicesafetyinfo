import '../result/risk_signal.dart';
import '../utils/platform_guard.dart';
import 'generated/device_safety_api.g.dart';
import 'generated/dsi_bindings.g.dart' as dsi;
import 'mappers.dart';
import 'native_checks_ffi.dart';

/// Reported when the bundled native library can't run on Android or iOS, where it always
/// ships. A stripped or swapped `libdsi` is a tampering indicator, but an ABI mismatch after a
/// bad build looks the same, so it's low risk.
const RiskSignal nativeUnavailableSignal = RiskSignal(
  'integrity.native_unavailable',
  RiskLevel.low,
  source: SignalSource.dart,
);

/// Reported alongside native evidence when the platform half of a check failed. Hooking the
/// Kotlin/Swift call to make it throw is a cheap way to defeat a check, so the failure itself
/// is worth surfacing.
const RiskSignal platformCheckFailedSignal = RiskSignal(
  'integrity.platform_check_failed',
  RiskLevel.low,
  source: SignalSource.dart,
);

/// Reported when the Kotlin and C root checks disagree about the same file list: one found an
/// executable `su` or a root-manager artifact and the other didn't. Both read the same paths,
/// so a disagreement means one layer was hooked to hide them (or, rarely, a race).
const RiskSignal layerMismatchSignal = RiskSignal(
  'integrity.layer_mismatch:root_files',
  RiskLevel.low,
  source: SignalSource.dart,
);

/// Cross-checks the Android root file lookups of both layers; see [layerMismatchSignal].
List<RiskSignal> rootLayerMismatch(CheckReport platform, NativeChecks native) {
  if (!native.supported || !PlatformGuard.isAndroid) return const [];
  final platformFound = platform.signals.any(
    (s) => s.key == 'root.su_executable' || s.key == 'root.manager_file',
  );
  final nativeFound = native.bits & dsi.DSI_ROOT_FILES_HIGH != 0;
  return platformFound == nativeFound ? const [] : const [layerMismatchSignal];
}

/// The native half of a check as a report: [signals] plus [nativeUnavailableSignal] when the
/// library didn't run on a platform it ships for.
CheckReport nativeReport(NativeChecks native, List<RiskSignal> signals) =>
    CheckReport([
      ...signals,
      if (!native.supported && PlatformGuard.isSupported)
        nativeUnavailableSignal,
    ], supported: native.supported);

/// Whether [report] holds evidence strong enough to stand on its own.
bool hasHighRisk(CheckReport report) =>
    report.signals.any((s) => s.level == RiskLevel.high);

/// Merges a platform check with its native counterpart, both already started.
///
/// If the platform call fails, high-risk native evidence still yields a report (plus
/// [platformCheckFailedSignal]) instead of being discarded with the error. Without such
/// evidence the platform error is rethrown, so the runner reports `CheckStatus.error` and the
/// configured fail mode applies.
///
/// [crossCheck] can add signals that compare the two halves when both ran.
Future<CheckReport> mergePlatformWithNative(
  Future<CheckReportMsg> platform,
  Future<NativeChecks> native,
  List<RiskSignal> Function(NativeChecks) pick, {
  List<RiskSignal> Function(CheckReport platform, NativeChecks native)?
  crossCheck,
}) async {
  // Listen to the native future right away so a failure there is never an unhandled error
  // while the platform call is still pending. A native failure is an unavailable library.
  final nativeOrUnavailable = native.catchError(
    (Object _) => NativeChecks.unavailable,
  );
  CheckReportMsg? msg;
  Object? error;
  StackTrace? stack;
  try {
    msg = await platform;
  } catch (e, st) {
    error = e;
    stack = st;
  }
  final n = await nativeOrUnavailable;
  final fromNative = nativeReport(n, pick(n));
  if (msg != null) {
    final fromPlatform = msg.toDomain();
    return fromPlatform
        .merge(fromNative)
        // supported: false so the extra signals never change the merged support flag.
        .merge(
          CheckReport(
            crossCheck?.call(fromPlatform, n) ?? const [],
            supported: false,
          ),
        );
  }
  if (hasHighRisk(fromNative)) {
    return CheckReport([
      ...fromNative.signals,
      platformCheckFailedSignal,
    ], supported: true);
  }
  Error.throwWithStackTrace(error!, stack!);
}
