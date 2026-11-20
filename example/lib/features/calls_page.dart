import 'dart:async';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Call detection: scammers talk users through payments on the phone.
///
/// ```dart
/// if (await DeviceSafety.calls.isCallActive()) {
///   showWarning('Are you on a call? Never share codes with callers.');
/// }
/// DeviceSafety.calls.changes.listen((e) => e.started ? pause() : resume());
/// ```
class CallsPage extends StatefulWidget {
  const CallsPage({super.key});

  @override
  State<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends State<CallsPage> with StatusMessage {
  CallActivityEvent? _last;
  StreamSubscription<CallActivityEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = DeviceSafety.calls.changes.listen(
      (e) => setState(() => _last = e),
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Phone calls',
      about:
          'Many scams happen while the victim is on a call with the scammer. Warn the '
          'user, or pause a payment, while a call is active.',
      code: '''if (await DeviceSafety.calls.isCallActive()) {
  showWarning('Never share codes with callers.');
}

DeviceSafety.calls.changes.listen((e) => e.started ? pause() : resume());''',
      children: [
        FilledButton(
          child: const Text('Is a call active?'),
          onPressed: () => run(
            () async => (await DeviceSafety.calls.isCallActive())
                ? 'Yes, a call is active'
                : 'No call',
          ),
        ),
        ListTile(
          title: const Text('Last call event'),
          trailing: Text(
            _last == null ? '-' : (_last!.started ? 'started' : 'ended'),
          ),
        ),
        const Divider(),
        const Text(
          'Android: with the call screening role your app is told about incoming '
          'calls, e.g. to warn about calls from unknown numbers.',
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          child: const Text('Request call screening role'),
          onPressed: () => run(() async {
            await DeviceSafety.callScreening.requestRole();
            return 'Role held: ${await DeviceSafety.callScreening.isRoleHeld()}';
          }),
        ),
        statusText(),
      ],
    );
  }
}
