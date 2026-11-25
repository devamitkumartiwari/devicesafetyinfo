import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Screenshots and screen recording.
///
/// ```dart
/// await DeviceSafety.screen.blockScreenshots();             // whole app
/// const SecureScreen(child: PaymentPage());                 // one page only
/// await DeviceSafety.screen.setOverlayMode(.blur);          // blur while recorded
/// DeviceSafety.screen.onScreenshot.listen((_) => warnUser());
/// ```
class ScreenshotPage extends StatefulWidget {
  const ScreenshotPage({super.key});

  @override
  State<ScreenshotPage> createState() => _ScreenshotPageState();
}

class _ScreenshotPageState extends State<ScreenshotPage> with StatusMessage {
  bool _blocked = false;
  bool _blur = false;

  @override
  void initState() {
    super.initState();
    DeviceSafety.screen.isScreenshotBlocked().then((b) {
      if (mounted) setState(() => _blocked = b);
    });
  }

  void _openSecurePage() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SecureScreen(
        child: Scaffold(
          appBar: AppBar(title: const Text('SecureScreen')),
          body: const Center(
            child: Text('Screenshots are blocked while this page is open.'),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Screenshots & recording',
      about:
          'Stop screenshots and screen recording of sensitive screens, or cover the '
          'app while the screen is being recorded or mirrored.',
      code: '''// Block for the whole app:
await DeviceSafety.screen.blockScreenshots();

// Or block only while one page is open:
const SecureScreen(child: PaymentPage());

// Blur the app while the screen is recorded:
await DeviceSafety.screen.setOverlayMode(.blur);''',
      children: [
        SwitchListTile(
          key: const ValueKey('block_screenshots'),
          title: const Text('Block screenshots'),
          value: _blocked,
          onChanged: (on) => run(() async {
            await DeviceSafety.screen.blockScreenshots(block: on);
            _blocked = await DeviceSafety.screen.isScreenshotBlocked();
            return on ? 'Screenshots blocked' : 'Screenshots allowed';
          }),
        ),
        SwitchListTile(
          key: const ValueKey('overlay_blur'),
          title: const Text('Blur the app while the screen is recorded'),
          value: _blur,
          onChanged: (on) => run(() async {
            on
                ? await DeviceSafety.screen.setOverlayMode(
                    ScreenshotOverlayMode.blur,
                  )
                : await DeviceSafety.screen.clearOverlayMode();
            _blur = on;
            return on ? 'Blur on' : 'Blur off';
          }),
        ),
        ListTile(
          key: const ValueKey('open_secure_screen'),
          leading: const Icon(Icons.lock),
          title: const Text('Open a SecureScreen page'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openSecurePage,
        ),
        statusText(),
      ],
    );
  }
}
