import '../config/device_safety_config.dart';
import '../config/fail_mode.dart';
import '../config/risk_policy.dart';
import '../result/check_result.dart';
import '../result/check_type.dart';
import '../result/risk_signal.dart';

/// Decides whether a check counts as detected. This is the only place that decision is made.
///
/// Rules:
/// * [RiskPolicy.off] → [CheckStatus.skipped], never detected.
/// * Signal levels are first replaced by `config.signalOverrides[signal.key]`; signals that end
///   up at [RiskLevel.none] are dropped, and duplicate ids keep their highest level.
/// * [CheckStatus.completed]: [RiskPolicy.standard] detects [RiskLevel.high];
///   [RiskPolicy.strict] detects any remaining signal.
/// * [CheckStatus.error] / [CheckStatus.timedOut]: detected only under [FailMode.closed].
/// * [CheckStatus.unsupported] / [CheckStatus.skipped]: never detected.
final class PolicyEvaluator {
  /// Creates an evaluator. It's stateless; one instance can be shared.
  const PolicyEvaluator();

  /// Applies [config] to a raw check outcome.
  CheckResult evaluate(
    CheckType type,
    CheckStatus status,
    List<RiskSignal> raw,
    DeviceSafetyConfig config, {
    Object? error,
    Duration elapsed = Duration.zero,
  }) {
    final policy = config.policyFor(type);
    if (policy == RiskPolicy.off || status == CheckStatus.skipped) {
      return CheckResult.skipped(type);
    }

    // Overrides, then drop `none`, then dedupe by id keeping the highest level. Insertion
    // order is preserved so results read in the order the checks produced them.
    final byId = <String, RiskSignal>{};
    for (final s in raw) {
      final level = config.signalOverrides[s.key] ?? s.level;
      if (level == RiskLevel.none) continue;
      final existing = byId[s.id];
      if (existing == null || level.index > existing.level.index) {
        byId[s.id] = s.withLevel(level);
      }
    }
    final signals = List<RiskSignal>.unmodifiable(byId.values);
    final level = signals.fold(RiskLevel.none, (m, s) => m.max(s.level));

    final detected = switch (status) {
      CheckStatus.completed => switch (policy) {
        RiskPolicy.strict => level != RiskLevel.none,
        _ => level == RiskLevel.high,
      },
      CheckStatus.error ||
      CheckStatus.timedOut => config.failModeFor(type) == FailMode.closed,
      CheckStatus.unsupported || CheckStatus.skipped => false,
    };

    return CheckResult(
      type: type,
      status: status,
      policy: policy,
      signals: signals,
      level: level,
      detected: detected,
      error: error,
      elapsed: elapsed,
    );
  }
}
