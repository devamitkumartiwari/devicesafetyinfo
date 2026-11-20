import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import 'src/app_state.dart';
import 'src/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceSafety.initialize(AppState.instance.config);
  runApp(const DemoApp());
}

/// Renders the demo as a MaterialApp or a CupertinoApp, following AppState.uiStyle. Switching
/// rebuilds the app from the home page.
class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  static const _seed = Color(0xFF3F51B5); // indigo

  // Locks the session after 30 s without interaction (counted on the Live events page).
  static Widget _idleGuard(BuildContext context, Widget? child) =>
      IdleTimeoutGuard(
        timeout: const Duration(seconds: 30),
        onTimeout: () => AppState.instance.idleTimeouts.value++,
        child: child ?? const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UiStyle>(
      valueListenable: AppState.instance.uiStyle,
      builder: (context, style, _) => switch (style) {
        UiStyle.cupertino => const CupertinoApp(
          key: ValueKey(UiStyle.cupertino),
          title: 'Device Safety Info',
          debugShowCheckedModeBanner: false,
          theme: CupertinoThemeData(primaryColor: _seed),
          builder: _idleGuard,
          home: HomePage(),
        ),
        UiStyle.material => MaterialApp(
          key: const ValueKey(UiStyle.material),
          title: 'Device Safety Info',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: _seed),
          ),
          builder: _idleGuard,
          home: const HomePage(),
        ),
      },
    );
  }
}
