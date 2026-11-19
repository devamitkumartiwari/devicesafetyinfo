// Performance benchmark for the full risk assessment and a single check.
//
// Run on a device in profile mode:
//   cd example
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/perf_test.dart -d <device>
//
// On Windows with the pub cache and the project on different drives, add
// `kotlin.incremental=false` to android/gradle.properties for the run
// (Kotlin incremental-cache "different roots" bug).
//
// The numbers are printed (look for "PERF") and written to the integration_test
// report data. The `_fullAssessment` / `_singleCheck` functions are the only
// API-specific code; they are swapped when the package API changes so the
// same harness compares 1.x and 2.x.
import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _runs = 20;

/// The 6 checks 1.x's `RiskSummary.evaluate()` ran (6 channel calls in 1.x).
const _summaryChecks = [
  CheckType.root,
  CheckType.hooking,
  CheckType.debugger,
  CheckType.screenCapture,
  CheckType.vpn,
  CheckType.screenLock,
];

/// 2.0: the same 6 checks in one batched round trip, bypassing the result cache so the
/// native work runs every time (comparable to 1.x).
Future<void> _fullAssessment() =>
    DeviceSafety.assess(checks: _summaryChecks, refresh: true);

/// 2.0: a single check, bypassing the cache.
Future<void> _singleCheck() => DeviceSafety.vpn.check(refresh: true);

/// 2.0 only: the same assessment served from the result cache.
Future<void> _cachedAssessment() => DeviceSafety.assess(checks: _summaryChecks);

/// 2.0 only: every detection check (15) in one round trip, uncached.
Future<void> _allChecks() => DeviceSafety.assess(refresh: true);

Map<String, num> _stats(List<int> micros) {
  if (micros.isEmpty) return {'samples': 0};
  final sorted = [...micros]..sort();
  num pct(double p) => sorted[((sorted.length - 1) * p).round()] / 1000;
  return {
    'median_ms': pct(0.5),
    'p95_ms': pct(0.95),
    'min_ms': sorted.first / 1000,
    'max_ms': sorted.last / 1000,
  };
}

Future<int> _time(Future<void> Function() f) async {
  final sw = Stopwatch()..start();
  await f();
  sw.stop();
  return sw.elapsedMicroseconds;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => DeviceSafety.initialize());
  final report = <String, Object>{};

  testWidgets('full assessment: cold then warm', (tester) async {
    await tester.pumpWidget(const SizedBox());
    report['full_cold_ms'] = await _time(_fullAssessment) / 1000;
    final warm = [for (var i = 0; i < _runs; i++) await _time(_fullAssessment)];
    report['full_warm'] = _stats(warm);
  });

  testWidgets('2.0 extras: cached and all checks', (tester) async {
    await _cachedAssessment();
    report['cached'] = _stats([
      for (var i = 0; i < _runs; i++) await _time(_cachedAssessment),
    ]);
    report['all_checks'] = _stats([
      for (var i = 0; i < _runs; i++) await _time(_allChecks),
    ]);
  });

  testWidgets('single check', (tester) async {
    final runs = [for (var i = 0; i < _runs; i++) await _time(_singleCheck)];
    report['single'] = _stats(runs);
  });

  testWidgets('frames while assessing', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text('perf')),
      ),
    );
    // Frame timings are collected in-app (no VM-service connection needed, so
    // this also works over wireless adb). The app is already warm here, so
    // this measures UI-thread cost of running checks, not cold-start cost.
    final timings = <FrameTiming>[];
    void onTimings(List<FrameTiming> t) => timings.addAll(t);
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    for (var i = 0; i < 5; i++) {
      final f = _fullAssessment();
      for (var j = 0; j < 10; j++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await f;
    }
    await tester.pump(const Duration(milliseconds: 500));
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
    report['frames'] = {
      'count': timings.length,
      'build': _stats([
        for (final t in timings) t.buildDuration.inMicroseconds,
      ]),
      'raster': _stats([
        for (final t in timings) t.rasterDuration.inMicroseconds,
      ]),
    };
  });

  tearDownAll(() {
    binding.reportData = {...?binding.reportData, 'perf': report};
    // ignore: avoid_print
    print('PERF $report');
  });
}
