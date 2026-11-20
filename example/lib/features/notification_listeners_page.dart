import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// Notification listeners.
///
/// ```dart
/// final result = await DeviceSafety.notificationListeners.check();
/// if (result.detected) warnUser();
/// ```
class NotificationListenersPage extends StatelessWidget {
  const NotificationListenersPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'Notification listeners',
    about: 'Finds apps that can read every notification, including SMS one-time codes. Trusted ones go in notificationListenerAllowlist.',
    platforms: 'Android only',
    code: '''final result = await DeviceSafety.notificationListeners.check();
if (result.detected) warnUser();
print(result.signals); // what was found''',
    check: DeviceSafety.notificationListeners.check,
  );
}
