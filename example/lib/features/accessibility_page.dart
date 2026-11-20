import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// Accessibility services.
///
/// ```dart
/// final result = await DeviceSafety.accessibility.check();
/// if (result.detected) warnUser();
/// ```
class AccessibilityPage extends StatelessWidget {
  const AccessibilityPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'Accessibility services',
    about: 'Finds accessibility services that can read and tap the screen. Banking malware uses them to steal codes. Trusted ones (like TalkBack) go in accessibilityAllowlist.',
    platforms: 'Android only',
    code: '''final result = await DeviceSafety.accessibility.check();
if (result.detected) warnUser();
print(result.signals); // what was found''',
    check: DeviceSafety.accessibility.check,
  );
}
