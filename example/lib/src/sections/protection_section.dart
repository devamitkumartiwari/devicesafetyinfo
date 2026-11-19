import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/demo_card.dart';
import '../widgets/section_header.dart';
import '../widgets/switch_tile.dart';

/// The action APIs: screenshot blocking and overlay, SecureScreen, app switcher, clipboard and
/// tapjacking protection.
class ProtectionSection extends StatefulWidget {
  const ProtectionSection({super.key});

  @override
  State<ProtectionSection> createState() => _ProtectionSectionState();
}

class _ProtectionSectionState extends State<ProtectionSection> {
  bool _blocked = false;
  bool _recentsOverlay = false;
  bool _blockObscured = false;
  ScreenshotOverlayMode _overlay = ScreenshotOverlayMode.none;
  String? _message;

  @override
  void initState() {
    super.initState();
    DeviceSafety.screen.isScreenshotBlocked().then((b) {
      if (mounted) setState(() => _blocked = b);
    });
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
      setState(() => _message = '$label: done');
    } on DeviceSafetyException catch (e) {
      setState(() => _message = '$label: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_message != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_message!, key: const ValueKey('protection_message')),
          ),
        sectionHeader(context, 'Screenshots and recording'),
        SwitchTile(
          key: const ValueKey('block_screenshots'),
          title: 'Block screenshots',
          subtitle: 'FLAG_SECURE on Android, secure layer on iOS',
          icon: Icons.screenshot_monitor,
          value: _blocked,
          onChanged: (v) => _run('Block screenshots', () async {
            await DeviceSafety.screen.blockScreenshots(block: v);
            _blocked = await DeviceSafety.screen.isScreenshotBlocked();
          }),
        ),
        DemoCard(
          children: [
            const Text('Overlay while the screen is captured'),
            const SizedBox(height: 8),
            SegmentedButton<ScreenshotOverlayMode>(
              segments: [
                for (final m in [
                  ScreenshotOverlayMode.none,
                  ScreenshotOverlayMode.blur,
                  ScreenshotOverlayMode.color,
                ])
                  ButtonSegment(value: m, label: Text(m.name)),
              ],
              selected: {_overlay},
              onSelectionChanged: (s) => _run('Overlay', () async {
                _overlay = s.single;
                await DeviceSafety.screen.setOverlayMode(
                  _overlay,
                  argbColor: 0xFF3F51B5,
                );
              }),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.lock),
            label: const Text('Open a SecureScreen page'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SecureScreen(
                  child: Scaffold(
                    appBar: AppBar(title: const Text('SecureScreen')),
                    body: const Center(
                      child: Text(
                        'Screenshots are blocked while this page is open.',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        sectionHeader(context, 'App switcher'),
        SwitchTile(
          title: 'Cover app in recents',
          icon: Icons.layers,
          value: _recentsOverlay,
          onChanged: (v) => _run('Recents overlay', () async {
            v
                ? await DeviceSafety.appSwitcher.setOverlay(
                    argbColor: 0xFF1A237E,
                  )
                : await DeviceSafety.appSwitcher.clearOverlay();
            _recentsOverlay = v;
          }),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: OutlinedButton(
            onPressed: () => _run(
              'Hide from recents',
              DeviceSafety.appSwitcher.hideFromRecents,
            ),
            child: const Text('Hide from recents (Android)'),
          ),
        ),
        sectionHeader(context, 'Clipboard'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('copy_secure'),
                onPressed: () => _run(
                  'Copy OTP (clears in 10 s)',
                  () => DeviceSafety.clipboard.copySecure(
                    '123456',
                    clearAfter: const Duration(seconds: 10),
                  ),
                ),
                child: const Text('Copy OTP securely'),
              ),
              OutlinedButton(
                onPressed: () =>
                    _run('Clear clipboard', DeviceSafety.clipboard.clear),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        sectionHeader(context, 'Tapjacking'),
        SwitchTile(
          title: 'Ignore touches while obscured',
          subtitle: 'Android only',
          icon: Icons.touch_app,
          value: _blockObscured,
          onChanged: (v) => _run('Block obscured touches', () async {
            await DeviceSafety.overlayAttack.blockTouchesWhenObscured(block: v);
            _blockObscured = v;
          }),
        ),
      ],
    );
  }
}
