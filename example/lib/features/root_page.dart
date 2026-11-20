import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// Root / jailbreak.
///
/// ```dart
/// final result = await DeviceSafety.root.check();
/// if (result.detected) blockPayments();
/// ```
class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'Root / jailbreak',
    about: 'Finds a rooted Android phone or a jailbroken iPhone. Root lets other apps read your app\'s data and switch off security checks.',
    platforms: 'Android and iOS',
    code: '''final result = await DeviceSafety.root.check();
if (result.detected) blockPayments();
print(result.signals); // what was found''',
    check: DeviceSafety.root.check,
  );
}
