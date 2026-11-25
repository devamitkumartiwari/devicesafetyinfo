import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/check_page.dart';

/// App cloning.
///
/// ```dart
/// final result = await DeviceSafety.appCloning.check();
/// if (result.detected) warnUser();
/// ```
class AppCloningPage extends StatelessWidget {
  const AppCloningPage({super.key});

  @override
  Widget build(BuildContext context) => CheckPage(
    title: 'App cloning',
    about: 'Finds your app running inside a cloner (Parallel Space, dual apps), a second user or a work profile.',
    platforms: 'Android only',
    code: '''final result = await DeviceSafety.appCloning.check();
if (result.detected) warnUser();
print(result.signals); // what was found''',
    check: DeviceSafety.appCloning.check,
  );
}
