import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// App switcher (recent apps) privacy.
///
/// ```dart
/// await DeviceSafety.appSwitcher.setOverlay(argbColor: 0xFF000000);
/// await DeviceSafety.appSwitcher.hideFromRecents(); // Android only
/// ```
class AppSwitcherPage extends StatefulWidget {
  const AppSwitcherPage({super.key});

  @override
  State<AppSwitcherPage> createState() => _AppSwitcherPageState();
}

class _AppSwitcherPageState extends State<AppSwitcherPage> with StatusMessage {
  bool _cover = false;

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'App switcher',
      about:
          'The recent-apps screen shows a picture of your app. Cover it with a color so '
          'balances and messages are not visible there.',
      code: '''// Cover the app with a color in recent apps:
await DeviceSafety.appSwitcher.setOverlay(argbColor: 0xFF000000);

// Android: hide the app from recent apps completely:
await DeviceSafety.appSwitcher.hideFromRecents();''',
      children: [
        SwitchListTile(
          key: const ValueKey('recents_overlay'),
          title: const Text('Cover app in recent apps'),
          subtitle: const Text('Turn on, then open the app switcher'),
          value: _cover,
          onChanged: (on) => run(() async {
            on
                ? await DeviceSafety.appSwitcher.setOverlay(
                    argbColor: 0xFF1A237E,
                  )
                : await DeviceSafety.appSwitcher.clearOverlay();
            _cover = on;
            return on ? 'Cover on' : 'Cover off';
          }),
        ),
        ListTile(
          key: const ValueKey('hide_from_recents'),
          leading: const Icon(Icons.visibility_off),
          title: const Text('Hide from recent apps'),
          subtitle: const Text('Android only'),
          onTap: () => run(() async {
            await DeviceSafety.appSwitcher.hideFromRecents();
            return 'Hidden from recent apps';
          }),
        ),
        statusText(),
      ],
    );
  }
}
