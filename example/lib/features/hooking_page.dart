import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// Hooking (Frida, Xposed).
///
/// ```dart
/// final result = await DeviceSafety.hooking.check();
/// if (result.detected) blockPayments();
/// ```
class HookingPage extends StatelessWidget {
  const HookingPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'Hooking (Frida, Xposed)',
    about: 'Finds tools such as Frida, Xposed or Zygisk that change your app\'s code while it runs. Never cached, because they can attach at any time.',
    platforms: 'Android and iOS',
    code: '''final result = await DeviceSafety.hooking.check();
if (result.detected) blockPayments();
print(result.signals); // what was found''',
    check: DeviceSafety.hooking.check,
  );
}
