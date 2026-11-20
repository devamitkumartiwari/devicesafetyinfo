import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/testing.dart';
import 'package:device_safety_info_example/main.dart';
import 'package:device_safety_info_example/src/app_state.dart';
import 'package:device_safety_info_example/src/ui/adaptive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _titles = [
  'Overview',
  'All checks',
  'Policy',
  'Protection',
  'Live events',
  'Tools',
  'App integrity',
];

void main() {
  final style = AppState.instance.uiStyle;
  late UiStyle initial;

  setUp(() {
    initial = style.value;
    DeviceSafety.forTesting(
      platform: DeviceSafetyPlatform(ffi: const FakeNativeChecks()),
    );
  });

  tearDown(() {
    style.value = initial;
    DeviceSafety.resetForTesting();
  });

  for (final s in UiStyle.values) {
    testWidgets('home page lists every demo page (${s.name})', (tester) async {
      style.value = s;
      await tester.pumpWidget(const DemoApp());
      for (final title in _titles) {
        expect(find.text(title), findsOneWidget);
      }
      expect(
        find.byType(s == UiStyle.cupertino ? CupertinoApp : MaterialApp),
        findsOneWidget,
      );
    });
  }

  testWidgets('the toggle switches between Material and Cupertino', (
    tester,
  ) async {
    style.value = UiStyle.material;
    await tester.pumpWidget(const DemoApp());
    expect(find.byType(MaterialApp), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('style_toggle')));
    await tester.pumpAndSettle();
    expect(style.value, UiStyle.cupertino);
    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('style_toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  openEveryPage(UiStyle.material);
  openEveryPage(UiStyle.cupertino);

  group('showStatus floats and never changes the layout', () {
    Widget page() => const _StatusProbe();

    testWidgets('Material: SnackBar', (tester) async {
      style.value = UiStyle.material;
      await tester.pumpWidget(MaterialApp(home: page()));
      final before = tester.getTopLeft(find.text('target'));
      await tester.tap(find.text('show'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const ValueKey('status_message')), findsOneWidget);
      expect(tester.getTopLeft(find.text('target')), before);
    });

    testWidgets('Cupertino: toast that disappears', (tester) async {
      style.value = UiStyle.cupertino;
      await tester.pumpWidget(CupertinoApp(home: page()));
      final before = tester.getTopLeft(find.text('target'));
      await tester.tap(find.text('show'));
      await tester.pump();
      expect(find.byKey(const ValueKey('status_message')), findsOneWidget);
      expect(tester.getTopLeft(find.text('target')), before);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const ValueKey('status_message')), findsNothing);
    });
  });

  for (final s in UiStyle.values) {
    testWidgets('AdaptiveSegmented reports the chosen value (${s.name})', (
      tester,
    ) async {
      style.value = s;
      RiskPolicy? chosen;
      final control = AdaptiveSegmented<RiskPolicy>(
        segments: const {
          RiskPolicy.off: 'off',
          RiskPolicy.standard: 'standard',
          RiskPolicy.strict: 'strict',
        },
        selected: RiskPolicy.standard,
        onChanged: (v) => chosen = v,
      );
      await tester.pumpWidget(
        s == UiStyle.cupertino
            ? CupertinoApp(
                home: CupertinoPageScaffold(child: Center(child: control)),
              )
            : MaterialApp(
                home: Scaffold(body: Center(child: control)),
              ),
      );
      await tester.tap(find.text('strict'));
      await tester.pumpAndSettle();
      expect(chosen, RiskPolicy.strict);
    });
  }
}

class _StatusProbe extends StatelessWidget {
  const _StatusProbe();

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        const Text('target'),
        Builder(
          builder: (context) => GestureDetector(
            onTap: () => showStatus(context, 'hello'),
            child: const Text('show'),
          ),
        ),
      ],
    );
    return isCupertino
        ? CupertinoPageScaffold(child: SafeArea(child: body))
        : Scaffold(body: SafeArea(child: body));
  }
}

/// Opens every demo page in [style] and fails on any build/layout exception. The platform side
/// isn't available in widget tests, so pages also exercise their error handling.
void openEveryPage(UiStyle s) {
  testWidgets('every page renders (${s.name})', (tester) async {
    AppState.instance.uiStyle.value = s;
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const DemoApp());
    for (final title in _titles) {
      await tester.tap(
        find.byKey(ValueKey('menu_${title.replaceAll(' ', '_')}')),
      );
      await tester.pumpAndSettle();
      final error = tester.takeException();
      expect(error, isNull, reason: "$title: $error");
      expect(find.text(title), findsWidgets);
      // cupertino_ui's back button isn't the class tester.pageBack() looks for.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    }
    await tester.binding.setSurfaceSize(null);
  });
}
