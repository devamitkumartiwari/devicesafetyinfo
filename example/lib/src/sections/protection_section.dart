import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/widgets.dart';

import '../ui/adaptive.dart';

/// The action APIs: screenshot blocking and overlay, SecureScreen, app switcher, clipboard and
/// tapjacking protection. Results are shown with [showStatus], which floats above the page, so
/// controls never move after an action.
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

  @override
  void initState() {
    super.initState();
    DeviceSafety.screen.isScreenshotBlocked().then((b) {
      if (mounted) setState(() => _blocked = b);
    });
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    String message;
    try {
      await action();
      message = '$label: done';
    } on DeviceSafetyException catch (e) {
      message = '$label: $e';
    }
    if (!mounted) return;
    setState(() {});
    showStatus(context, message);
  }

  void _openSecureScreen() => pushPage(
    context,
    const SecureScreen(
      child: AdaptivePage(
        title: 'SecureScreen',
        child: AdaptiveSection(
          children: [
            AdaptiveTile(
              title: 'Screenshots are blocked',
              subtitle: 'while this page is open. Go back to unblock.',
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveSection(
          header: 'Screenshots and recording',
          children: [
            AdaptiveSwitchTile(
              key: const ValueKey('block_screenshots'),
              title: 'Block screenshots',
              subtitle: 'FLAG_SECURE on Android, secure layer on iOS',
              icon: adaptiveIcon(
                Icons.screenshot_monitor,
                CupertinoIcons.camera_viewfinder,
              ),
              value: _blocked,
              onChanged: (v) => _run(
                v ? 'Block screenshots' : 'Unblock screenshots',
                () async {
                  await DeviceSafety.screen.blockScreenshots(block: v);
                  _blocked = await DeviceSafety.screen.isScreenshotBlocked();
                },
              ),
            ),
            SectionContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Overlay while the screen is captured'),
                  const SizedBox(height: 8),
                  AdaptiveSegmented<ScreenshotOverlayMode>(
                    key: const ValueKey('overlay_mode'),
                    segments: const {
                      ScreenshotOverlayMode.none: 'none',
                      ScreenshotOverlayMode.blur: 'blur',
                      ScreenshotOverlayMode.color: 'color',
                    },
                    selected: _overlay,
                    onChanged: (m) => _run('Overlay ${m.name}', () async {
                      await DeviceSafety.screen.setOverlayMode(
                        m,
                        argbColor: 0xFF3F51B5,
                      );
                      _overlay = m;
                    }),
                  ),
                ],
              ),
            ),
            AdaptiveTile(
              key: const ValueKey('open_secure_screen'),
              leading: Icon(adaptiveIcon(Icons.lock, CupertinoIcons.lock)),
              title: 'Open a SecureScreen page',
              trailing: Icon(
                adaptiveIcon(
                  Icons.chevron_right,
                  CupertinoIcons.chevron_forward,
                ),
              ),
              onTap: _openSecureScreen,
            ),
          ],
        ),
        AdaptiveSection(
          header: 'App switcher',
          children: [
            AdaptiveSwitchTile(
              key: const ValueKey('recents_overlay'),
              title: 'Cover app in recents',
              icon: adaptiveIcon(
                Icons.layers,
                CupertinoIcons.square_stack_3d_up,
              ),
              value: _recentsOverlay,
              onChanged: (v) => _run('Recents cover', () async {
                v
                    ? await DeviceSafety.appSwitcher.setOverlay(
                        argbColor: 0xFF1A237E,
                      )
                    : await DeviceSafety.appSwitcher.clearOverlay();
                _recentsOverlay = v;
              }),
            ),
            AdaptiveTile(
              key: const ValueKey('hide_from_recents'),
              leading: Icon(
                adaptiveIcon(Icons.visibility_off, CupertinoIcons.eye_slash),
              ),
              title: 'Hide from recents',
              subtitle: 'Android only',
              onTap: () => _run(
                'Hide from recents',
                DeviceSafety.appSwitcher.hideFromRecents,
              ),
            ),
          ],
        ),
        AdaptiveSection(
          header: 'Clipboard',
          footer: 'The code is marked sensitive and cleared after 10 seconds.',
          children: [
            SectionContent(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AdaptiveButton(
                    key: const ValueKey('copy_secure'),
                    label: 'Copy OTP securely',
                    onPressed: () => _run(
                      'Copied 123456',
                      () => DeviceSafety.clipboard.copySecure(
                        '123456',
                        clearAfter: const Duration(seconds: 10),
                      ),
                    ),
                  ),
                  AdaptiveButton(
                    key: const ValueKey('clear_clipboard'),
                    label: 'Clear',
                    filled: false,
                    onPressed: () =>
                        _run('Clear clipboard', DeviceSafety.clipboard.clear),
                  ),
                ],
              ),
            ),
          ],
        ),
        AdaptiveSection(
          header: 'Tapjacking',
          children: [
            AdaptiveSwitchTile(
              key: const ValueKey('block_obscured'),
              title: 'Ignore touches while obscured',
              subtitle: 'Android only',
              icon: adaptiveIcon(Icons.touch_app, CupertinoIcons.hand_raised),
              value: _blockObscured,
              onChanged: (v) => _run('Block obscured touches', () async {
                await DeviceSafety.overlayAttack.blockTouchesWhenObscured(
                  block: v,
                );
                _blockObscured = v;
              }),
            ),
          ],
        ),
      ],
    );
  }
}
