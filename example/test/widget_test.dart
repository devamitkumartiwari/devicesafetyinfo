import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/testing.dart';
import 'package:device_safety_info_example/home_page.dart';
import 'package:device_safety_info_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUp(() {
    DeviceSafety.forTesting(
      platform: DeviceSafetyPlatform(ffi: const FakeNativeChecks()),
    );
  });

  tearDown(DeviceSafety.resetForTesting);

  final all = [for (final items in demos.values) ...items];

  testWidgets('home page lists every demo', (tester) async {
    // Tall enough that every tile is built without scrolling.
    await tester.binding.setSurfaceSize(const Size(400, 4000));
    await tester.pumpWidget(const ExampleApp());
    for (final demo in all) {
      expect(find.byKey(ValueKey('menu_${demo.id}')), findsOneWidget);
      expect(find.text(demo.title), findsOneWidget);
    }
    await tester.binding.setSurfaceSize(null);
  });

  // The platform side isn't available in widget tests, so every page also
  // exercises its error handling.
  for (final demo in all) {
    testWidgets('${demo.title} page renders', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(MaterialApp(home: demo.page));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text(demo.title), findsWidgets);
      // Let check timeouts (5 s) finish, then leave the page so subscriptions are cancelled.
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets('IOC page blocks a listed domain', (tester) async {
    await DeviceSafety.initialize(
      DeviceSafetyConfig(iocBlocklist: {'*.phishing.example'}),
    );
    final ioc = all.firstWhere((d) => d.id == 'ioc_domains');
    await tester.pumpWidget(MaterialApp(home: ioc.page));
    await tester.tap(find.byKey(const ValueKey('ioc_check')));
    await tester.pump();
    expect(find.text('BLOCKED'), findsOneWidget);
  });
}
