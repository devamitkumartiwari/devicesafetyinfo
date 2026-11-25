import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// Debugger.
///
/// ```dart
/// final result = await DeviceSafety.debugger.check();
/// if (result.detected) blockPayments();
/// ```
class DebuggerPage extends StatelessWidget {
  const DebuggerPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'Debugger',
    about: 'Finds a debugger attached to your app. Attackers use one to step through and change your code. Run from Flutter in debug mode, this is expected.',
    platforms: 'Android and iOS',
    code: '''final result = await DeviceSafety.debugger.check();
if (result.detected) blockPayments();
print(result.signals); // what was found''',
    check: DeviceSafety.debugger.check,
  );
}
