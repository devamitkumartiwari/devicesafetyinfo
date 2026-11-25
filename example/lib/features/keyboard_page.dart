import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// Third-party keyboard.
///
/// ```dart
/// final result = await DeviceSafety.keyboard.check();
/// if (result.detected) useSecureField();
/// ```
class KeyboardPage extends StatelessWidget {
  const KeyboardPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'Third-party keyboard',
    about: 'Finds a third-party default keyboard, which could log what is typed. High risk when it also runs an accessibility service. System keyboards, Gboard and SwiftKey are trusted.',
    platforms: 'Android only (iOS: see Secure text fields)',
    code: '''final result = await DeviceSafety.keyboard.check();
if (result.detected) useSecureField();
print(result.signals); // what was found''',
    check: DeviceSafety.keyboard.check,
  );
}
