import 'dart:async';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Tapjacking: another app draws over yours to trick the user into tapping.
///
/// ```dart
/// await DeviceSafety.overlayAttack.blockTouchesWhenObscured();
/// DeviceSafety.overlayAttack.obscuredTouches.listen((_) => warnUser());
/// ```
class TapjackingPage extends StatefulWidget {
  const TapjackingPage({super.key});

  @override
  State<TapjackingPage> createState() => _TapjackingPageState();
}

class _TapjackingPageState extends State<TapjackingPage> with StatusMessage {
  bool _block = false;
  int _blockedTouches = 0;
  StreamSubscription<DateTime>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = DeviceSafety.overlayAttack.obscuredTouches.listen(
      (_) => setState(() => _blockedTouches++),
      onError: (Object _) {}, // not supported on iOS
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
      title: 'Tapjacking',
      about:
          'A malicious app can draw a fake screen over yours so the user taps something '
          'they cannot see. This ignores touches while another app covers yours.',
      platforms: 'Android only',
      code: '''await DeviceSafety.overlayAttack.blockTouchesWhenObscured();

DeviceSafety.overlayAttack.obscuredTouches.listen((_) => warnUser());''',
      children: [
        SwitchListTile(
          key: const ValueKey('block_obscured'),
          title: const Text('Ignore touches while covered'),
          value: _block,
          onChanged: (on) => run(() async {
            await DeviceSafety.overlayAttack.blockTouchesWhenObscured(
              block: on,
            );
            _block = on;
            return on ? 'Protection on' : 'Protection off';
          }),
        ),
        ListTile(
          title: const Text('Covered touches seen'),
          trailing: Text('$_blockedTouches'),
        ),
        statusText(),
      ],
    );
  }
}
