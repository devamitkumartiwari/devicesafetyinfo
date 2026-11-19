import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import 'src/app_state.dart';
import 'src/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceSafety.initialize(AppState.instance.config);
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Safety Info',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      // Locks the session after 30 s without interaction (counted on the Live events page).
      builder: (context, child) => IdleTimeoutGuard(
        timeout: const Duration(seconds: 30),
        onTimeout: () {
          AppState.instance.idleTimeouts.value++;
          debugPrint('Idle timeout');
        },
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomePage(),
    );
  }
}
