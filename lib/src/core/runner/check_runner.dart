import 'dart:async';

import '../config/device_safety_config.dart';
import '../config/risk_policy.dart';
import '../policy/policy_evaluator.dart';
import '../result/check_result.dart';
import '../result/check_type.dart';
import '../result/risk_signal.dart';
import '../threats/threat_bus.dart';
import '../utils/ttl_cache.dart';

/// Loads the raw report for one check.
typedef ReportLoader = Future<CheckReport> Function();

/// Loads raw reports for several checks in one call. Checks missing from the returned map are
/// reported as errors.
typedef BatchReportLoader = Future<Map<CheckType, CheckReport>> Function(
  Set<CheckType> types,
);

/// Runs detection checks the same way for every feature: policy `off` short-circuit, result
/// cache with in-flight dedupe, timeout, error capture, policy evaluation and threat events.
/// Detection APIs never throw because this class turns every failure into a [CheckResult].
final class CheckRunner {
  /// Creates a runner. [config] is read on every run, so replacing the configuration takes
  /// effect immediately (call [reset] to drop results computed under the old one).
  CheckRunner({
    required DeviceSafetyConfig Function() config,
    required this._threats,
    this._evaluator = const PolicyEvaluator(),
    DateTime Function()? clock,
  }) : _config = config,
       _cache = TtlCache(ttl: () => config().cacheTtl, clock: clock);

  final DeviceSafetyConfig Function() _config;
  final ThreatBus _threats;
  final PolicyEvaluator _evaluator;
  final TtlCache<CheckType, CheckResult> _cache;

  /// Checks for threats that can appear at any moment (Frida attaching, a debugger connecting).
  /// Their results are never cached: a clean answer from a few seconds ago says nothing about
  /// now. Concurrent calls still share one in-flight run.
  static const Set<CheckType> dynamicChecks = {
    CheckType.hooking,
    CheckType.debugger,
  };

  static bool _cacheable(CheckResult r) =>
      !dynamicChecks.contains(r.type) &&
      (r.status == CheckStatus.completed ||
          r.status == CheckStatus.unsupported);

  /// Runs [type] with [load], or returns a cached result. [refresh] bypasses the cache.
  Future<CheckResult> run(
    CheckType type,
    ReportLoader load, {
    bool refresh = false,
  }) {
    final config = _config();
    if (config.policyFor(type) == RiskPolicy.off) {
      return Future.value(CheckResult.skipped(type));
    }
    if (refresh) _cache.invalidate(type);
    return _cache.get(
      type,
      () => _execute(type, load, config),
      shouldCache: _cacheable,
    );
  }

  /// Runs several checks, loading every one that isn't cached (or `off`) through a single
  /// [load] call. Returns results in the order of [types].
  Future<Map<CheckType, CheckResult>> runBatch(
    Iterable<CheckType> types,
    BatchReportLoader load, {
    bool refresh = false,
  }) async {
    final config = _config();
    final results = <CheckType, CheckResult>{};
    final needed = <CheckType>{};
    for (final type in types) {
      if (config.policyFor(type) == RiskPolicy.off) {
        results[type] = CheckResult.skipped(type);
        continue;
      }
      if (refresh) _cache.invalidate(type);
      final hit = _cache.peek(type);
      if (hit != null) {
        results[type] = hit.value;
      } else {
        needed.add(type);
      }
    }

    if (needed.isNotEmpty) {
      final sw = Stopwatch()..start();
      Map<CheckType, CheckReport>? reports;
      CheckStatus failure = CheckStatus.error;
      Object? error;
      try {
        reports = await load(needed).timeout(config.timeout);
      } on TimeoutException catch (e) {
        failure = CheckStatus.timedOut;
        error = e;
      } catch (e, st) {
        error = e;
        config.logger?.call('Batch check failed', error: e, stackTrace: st);
      }
      sw.stop();
      for (final type in needed) {
        final report = reports?[type];
        final result = report == null
            ? _evaluator.evaluate(
                type,
                reports == null ? failure : CheckStatus.error,
                const [],
                config,
                error: error ?? StateError('No report for ${type.id}'),
                elapsed: sw.elapsed,
              )
            : _evaluate(type, report, config, sw.elapsed);
        if (_cacheable(result)) _cache.put(type, result);
        _threats.onResult(result);
        results[type] = result;
      }
    }
    return {for (final type in types) type: results[type]!};
  }

  /// Drops the cached result for [type] (e.g. after a VPN state change).
  void invalidate(CheckType type) => _cache.invalidate(type);

  /// Drops every cached result and the threat bus's memory of past detections.
  void reset() {
    _cache.clear();
    _threats.reset();
  }

  Future<CheckResult> _execute(
    CheckType type,
    ReportLoader load,
    DeviceSafetyConfig config,
  ) async {
    final sw = Stopwatch()..start();
    CheckResult result;
    try {
      final report = await Future.sync(load).timeout(config.timeout);
      result = _evaluate(type, report, config, sw.elapsed);
    } on TimeoutException catch (e) {
      result = _evaluator.evaluate(
        type,
        CheckStatus.timedOut,
        const [],
        config,
        error: e,
        elapsed: sw.elapsed,
      );
    } catch (e, st) {
      config.logger?.call('Check ${type.id} failed', error: e, stackTrace: st);
      result = _evaluator.evaluate(
        type,
        CheckStatus.error,
        const [],
        config,
        error: e,
        elapsed: sw.elapsed,
      );
    }
    _threats.onResult(result);
    return result;
  }

  CheckResult _evaluate(
    CheckType type,
    CheckReport report,
    DeviceSafetyConfig config,
    Duration elapsed,
  ) => _evaluator.evaluate(
    type,
    report.supported ? CheckStatus.completed : CheckStatus.unsupported,
    report.signals,
    config,
    elapsed: elapsed,
  );
}
