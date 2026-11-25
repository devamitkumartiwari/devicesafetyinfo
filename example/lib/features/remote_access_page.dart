import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// Remote access apps.
///
/// ```dart
/// final result = await DeviceSafety.remoteAccess.check();
/// if (result.detected) warnUser();
/// ```
class RemoteAccessPage extends StatelessWidget {
  const RemoteAccessPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'Remote access apps',
    about: 'Finds remote-control apps (AnyDesk, TeamViewer QuickSupport, RustDesk...) used in fake support-call scams. High risk when one can control the screen.',
    platforms: 'Android only',
    code: '''final result = await DeviceSafety.remoteAccess.check();
if (result.detected) warnUser();
print(result.signals); // what was found''',
    check: DeviceSafety.remoteAccess.check,
  );
}
