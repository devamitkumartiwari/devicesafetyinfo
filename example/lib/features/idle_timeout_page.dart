import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Idle session timeout.
///
/// ```dart
/// IdleTimeoutGuard(
///   timeout: const Duration(minutes: 5),
///   onTimeout: () => logOut(),
///   child: const HomePage(),
/// );
/// ```
class IdleTimeoutPage extends StatefulWidget {
  const IdleTimeoutPage({super.key});

  @override
  State<IdleTimeoutPage> createState() => _IdleTimeoutPageState();
}

class _IdleTimeoutPageState extends State<IdleTimeoutPage> {
  int _timeouts = 0;

  @override
  Widget build(BuildContext context) {
    return IdleTimeoutGuard(
      timeout: const Duration(seconds: 10),
      onTimeout: () => setState(() => _timeouts++),
      child: DemoScaffold(
        title: 'Idle timeout',
        about:
            'Locks the session when nobody touches the app for a while, so an unlocked '
            'phone left on a table does not expose the account.',
        code: '''IdleTimeoutGuard(
  timeout: const Duration(minutes: 5),
  onTimeout: () => logOut(),
  child: const HomePage(),
);''',
        children: [
          const Text(
            'This page uses a 10 second timeout. Stop touching the screen.',
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Timeouts so far'),
              trailing: Text(
                '$_timeouts',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
