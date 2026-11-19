import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/testing.dart';
import 'package:device_safety_info_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home page lists every demo page', (tester) async {
    DeviceSafety.forTesting(
      platform: DeviceSafetyPlatform(ffi: const FakeNativeChecks()),
    );
    await tester.pumpWidget(const DemoApp());
    for (final title in [
      'Overview',
      'All checks',
      'Policy',
      'Protection',
      'Live events',
      'Tools',
      'App integrity',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    DeviceSafety.resetForTesting();
  });
}
