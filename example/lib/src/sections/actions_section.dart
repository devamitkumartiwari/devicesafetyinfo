import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../platform_support.dart';
import '../widgets/section_header.dart';
import '../widgets/switch_tile.dart';

/// ON/OFF action toggles: block screenshots, recents overlay, and (Android-only)
/// hide-in-recents / block-touches-when-obscured.
class ActionsSection extends StatefulWidget {
  const ActionsSection({super.key});

  @override
  State<ActionsSection> createState() => ActionsSectionState();
}

class ActionsSectionState extends State<ActionsSection> {
  bool _blockScreenshots = false;
  bool _recentsOverlayEnabled = false;
  bool _hideInRecents = false;
  bool _blockTouchesWhenObscured = false;

  Future<void> _toggleBlockScreenshots(bool value) async {
    await DeviceSafetyInfo.blockScreenshots(block: value);
    if (mounted) setState(() => _blockScreenshots = value);
  }

  Future<void> _toggleRecentsOverlay(bool value) async {
    if (value) {
      await DeviceSafetyInfo.setRecentsOverlay(argbColor: 0xFF1A1A2E);
    } else {
      await DeviceSafetyInfo.clearRecentsOverlay();
    }
    if (mounted) setState(() => _recentsOverlayEnabled = value);
  }

  Future<void> _toggleHideInRecents(bool value) async {
    await DeviceSafetyInfo.hideMenu(hide: value);
    if (mounted) setState(() => _hideInRecents = value);
  }

  Future<void> _toggleBlockTouchesWhenObscured(bool value) async {
    try {
      await DeviceSafetyInfo.blockTouchesWhenObscured(block: value);
      if (mounted) setState(() => _blockTouchesWhenObscured = value);
    } catch (e) {
      // Throws by design on iOS — overlay attacks are structurally impossible there.
      debugPrint('blockTouchesWhenObscured error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(context, 'Actions'),
        SwitchTile(
          title: 'Block Screenshots',
          value: _blockScreenshots,
          onChanged: _toggleBlockScreenshots,
          icon: Icons.screen_lock_portrait,
          subtitle: 'Prevents screenshots and screen recordings.',
        ),
        SwitchTile(
          title: 'Recents Overlay',
          value: _recentsOverlayEnabled,
          onChanged: _toggleRecentsOverlay,
          icon: Icons.blur_on,
          subtitle: 'Solid color overlay in the app switcher.',
        ),
        AndroidOnly(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchTile(
                title: 'Hide in Recents',
                value: _hideInRecents,
                onChanged: _toggleHideInRecents,
                icon: Icons.visibility_off,
                subtitle: 'Android-only. Hides app from recent apps list.',
              ),
              SwitchTile(
                title: 'Block Touches When Obscured',
                value: _blockTouchesWhenObscured,
                onChanged: _toggleBlockTouchesWhenObscured,
                icon: Icons.layers_clear,
                subtitle: 'Android-only. Drops touches while another app overlays yours.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
