import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// VPN / proxy.
///
/// ```dart
/// final result = await DeviceSafety.vpn.check();
/// if (result.detected) warnUser();
/// ```
class VpnPage extends StatelessWidget {
  const VpnPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'VPN / proxy',
    about: 'Finds an active VPN or HTTP proxy. Low risk by default, because many honest users run a VPN.',
    platforms: 'Android and iOS',
    code: '''final result = await DeviceSafety.vpn.check();
if (result.detected) warnUser();
print(result.signals); // what was found''',
    check: DeviceSafety.vpn.check,
  );
}
