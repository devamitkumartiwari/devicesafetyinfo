import '../result/check_result.dart';
import '../result/check_type.dart';
import 'check_runner.dart';

/// A detection check exposed to apps. Every detection feature's public API extends this, so
/// they all behave the same way: cached, deduplicated, time-limited, policy-applied, and never
/// throwing.
base class DetectionApi {
  /// Creates the API for [type], loading raw reports with [load].
  DetectionApi(this.type, this._runner, this._load);

  /// Which check this is.
  final CheckType type;
  final CheckRunner _runner;
  final ReportLoader _load;

  /// Runs the check (or returns a cached result). [refresh] bypasses the cache.
  Future<CheckResult> check({bool refresh = false}) =>
      _runner.run(type, _load, refresh: refresh);

  /// Whether the check counts as detected under the configured policy.
  Future<bool> isDetected({bool refresh = false}) async =>
      (await check(refresh: refresh)).detected;
}
