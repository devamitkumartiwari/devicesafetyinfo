import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import 'src/pages/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Shared with whichever page hosts [StreamsSection] (only mounted while that page
  /// is open). [IdleTimeoutGuard] below wraps every page via [MaterialApp.builder], so
  /// this counter stays correct no matter which page is on screen when it fires.
  final ValueNotifier<int> _idleTimeoutCount = ValueNotifier<int>(0);

  @override
  void dispose() {
    _idleTimeoutCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Safety Info',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      builder: (context, child) => IdleTimeoutGuard(
        timeout: const Duration(seconds: 30),
        onTimeout: () => _idleTimeoutCount.value++,
        child: child!,
      ),
      home: HomePage(idleTimeoutCount: _idleTimeoutCount),
    );
  }
}
