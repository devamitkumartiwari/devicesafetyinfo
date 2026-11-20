import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// Emulator / simulator.
///
/// ```dart
/// final result = await DeviceSafety.emulator.check();
/// if (result.detected) blockSignUp();
/// ```
class EmulatorPage extends StatelessWidget {
  const EmulatorPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'Emulator / simulator',
    about: 'Finds an Android emulator or iOS simulator. Fraud farms run many fake devices on emulators.',
    platforms: 'Android and iOS',
    code: '''final result = await DeviceSafety.emulator.check();
if (result.detected) blockSignUp();
print(result.signals); // what was found''',
    check: DeviceSafety.emulator.check,
  );
}
