import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import 'home_page.dart';

/// Optional: your signing certificate, to try the tampering check.
/// `flutter run --dart-define=EXPECTED_SIGNING_CERT=<sha-256>`
const _expectedCert = String.fromEnvironment('EXPECTED_SIGNING_CERT');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional. Without it, every check uses safe defaults.
  await DeviceSafety.initialize(
    DeviceSafetyConfig(
      // Trusted apps that should never be reported:
      accessibilityAllowlist: {'com.google.android.marvin.talkback'},
      // Your list of known malware and bad domains:
      malwarePackages: {'com.example.fakemalware'},
      iocBlocklist: {'malicious.example', '*.phishing.example'},
      // Your real signing certificate, for the tampering check:
      expectedSigningCertificates: {
        if (_expectedCert.isNotEmpty) _expectedCert,
      },
    ),
  );

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Safety Info',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const HomePage(),
    );
  }
}

/// Teal from the app icon. Problems and errors use the scheme's red `error` color.
const _iconTeal = Color(0xFF00796B);

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _iconTeal,
    brightness: brightness,
    // Keep teal vivid like the icon instead of Material's muted tone.
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  return ThemeData(
    colorScheme: scheme,
    // Teal app bar, like the icon background.
    appBarTheme: AppBarTheme(
      backgroundColor: brightness == Brightness.light
          ? _iconTeal
          : scheme.surfaceContainer,
      foregroundColor: brightness == Brightness.light
          ? Colors.white
          : scheme.onSurface,
    ),
  );
}
