// Driver for profile-mode integration tests (used by the perf benchmark):
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/perf_test.dart -d <device>
// Report data, including timelines, is written to build/integration_response_data.json
// and build/*.timeline_summary.json.
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver();
