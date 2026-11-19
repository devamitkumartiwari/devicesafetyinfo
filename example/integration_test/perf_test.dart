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

/// 1.x API: `RiskSummary.evaluate()` (6 parallel channel calls).
Future<void> _fullAssessment() => RiskSummary.evaluate();

/// 1.x API: a single, cheap channel call.
Future<void> _singleCheck() => DeviceSafetyInfo.isVPNCheck;

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
  final report = <String, Object>{};

  testWidgets('full assessment: cold then warm', (tester) async {
    await tester.pumpWidget(const SizedBox());
    report['full_cold_ms'] = await _time(_fullAssessment) / 1000;
    final warm = [for (var i = 0; i < _runs; i++) await _time(_fullAssessment)];
    report['full_warm'] = _stats(warm);
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
      'build': _stats([for (final t in timings) t.buildDuration.inMicroseconds]),
      'raster': _stats([for (final t in timings) t.rasterDuration.inMicroseconds]),
    };
  });

  tearDownAll(() {
    binding.reportData = {...?binding.reportData, 'perf': report};
    // ignore: avoid_print
    print('PERF $report');
  });
}
