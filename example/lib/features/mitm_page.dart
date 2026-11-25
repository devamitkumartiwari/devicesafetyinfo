import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// HTTPS interception.
///
/// ```dart
/// final result = await DeviceSafety.mitm.check();
/// if (result.detected) warnUser();
/// ```
class MitmPage extends StatelessWidget {
  const MitmPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'HTTPS interception',
    about: 'Finds user-installed CA certificates that let a proxy read HTTPS traffic. High risk while a VPN or proxy is active. Pair it with certificate pinning.',
    platforms: 'Android only',
    code: '''final result = await DeviceSafety.mitm.check();
if (result.detected) warnUser();
print(result.signals); // what was found''',
    check: DeviceSafety.mitm.check,
  );
}
