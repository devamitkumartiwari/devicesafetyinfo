import '../config/risk_policy.dart';
import 'check_type.dart';
import 'risk_signal.dart';

/// How a check ended.
enum CheckStatus {
  /// The check ran. [CheckResult.signals] lists what it found.
  completed,

  /// The check can't run on this platform or OS version. Never detected.
  unsupported,

  /// The check failed. [CheckResult.error] holds the cause; `detected` follows the fail mode.
  error,

  /// The check didn't finish within the configured timeout; `detected` follows the fail mode.
  timedOut,

  /// The check's policy is `RiskPolicy.off`, so it didn't run. Never detected.
  skipped,
}

/// The outcome of one detection check, with the configured policy already applied.
final class CheckResult {
  /// Creates a result. Results are normally produced by the package; this constructor exists
  /// for tests and fakes.
  const CheckResult({
    required this.type,
    required this.status,
    required this.policy,
    this.signals = const [],
    this.level = RiskLevel.none,
    this.detected = false,
    this.error,
    this.elapsed = Duration.zero,
  });

  /// A result for a check whose policy is [RiskPolicy.off].
  const CheckResult.skipped(this.type)
    : status = CheckStatus.skipped,
      policy = RiskPolicy.off,
      signals = const [],
      level = RiskLevel.none,
      detected = false,
      error = null,
      elapsed = Duration.zero;

  /// Which check this is.
  final CheckType type;

  /// How the check ended.
  final CheckStatus status;

  /// What was found, after `signalOverrides` (signals overridden to `none` are removed).
  final List<RiskSignal> signals;

  /// The highest level among [signals].
  final RiskLevel level;

  /// Whether this counts as a detection under [policy] (and the fail mode, for errors).
  final bool detected;

  /// The policy that was applied.
  final RiskPolicy policy;

  /// The failure, when [status] is [CheckStatus.error] or [CheckStatus.timedOut].
  final Object? error;

  /// How long the check took.
  final Duration elapsed;

  /// The [RiskLevel.high] signals.
  List<RiskSignal> get high => [
    for (final s in signals)
      if (s.level == RiskLevel.high) s,
  ];

  /// The [RiskLevel.low] signals.
  List<RiskSignal> get low => [
    for (final s in signals)
      if (s.level == RiskLevel.low) s,
  ];

  /// Whether the check ran to completion.
  bool get isCompleted => status == CheckStatus.completed;

  @override
  String toString() =>
      'CheckResult(${type.name}, ${status.name}, detected: $detected, '
      'level: ${level.name}, signals: $signals'
      '${error == null ? '' : ', error: $error'})';
}
