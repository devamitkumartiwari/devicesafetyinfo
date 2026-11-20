import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Secure clipboard.
///
/// ```dart
/// await DeviceSafety.clipboard.copySecure(
///   '123456',
///   clearAfter: const Duration(seconds: 30),
/// );
/// ```
class ClipboardPage extends StatefulWidget {
  const ClipboardPage({super.key});

  @override
  State<ClipboardPage> createState() => _ClipboardPageState();
}

class _ClipboardPageState extends State<ClipboardPage> with StatusMessage {
  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Secure clipboard',
      about:
          'Copy a one-time code or account number safely: it is hidden from the '
          'clipboard preview, not synced to other devices, and cleared after a delay.',
      code: '''await DeviceSafety.clipboard.copySecure(
  '123456',
  clearAfter: const Duration(seconds: 30),
);''',
      children: [
        FilledButton.icon(
          key: const ValueKey('copy_secure'),
          icon: const Icon(Icons.copy),
          label: const Text('Copy 123456 (cleared after 10 s)'),
          onPressed: () => run(() async {
            await DeviceSafety.clipboard.copySecure(
              '123456',
              clearAfter: const Duration(seconds: 10),
            );
            return 'Copied 123456. Paste somewhere within 10 seconds.';
          }),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('clear_clipboard'),
          child: const Text('Clear clipboard now'),
          onPressed: () => run(() async {
            await DeviceSafety.clipboard.clear();
            return 'Clipboard cleared';
          }),
        ),
        statusText(),
      ],
    );
  }
}
