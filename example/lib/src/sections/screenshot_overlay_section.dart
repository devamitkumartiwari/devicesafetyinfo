import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../widgets/demo_card.dart';
import '../widgets/section_header.dart';
import '../widgets/switch_tile.dart';

/// A 1x1 transparent PNG, used as placeholder bytes for [ScreenshotOverlayMode.image].
const String _placeholderImageBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

/// Demo for the [DeviceSafetyInfo.setScreenshotOverlayMode] / `clearScreenshotOverlayMode`
/// live-overlay feature, plus the [DeviceSafetyInfo.isScreenshotBlocked] /
/// `toggleScreenshotBlocking` convenience pair.
class ScreenshotOverlaySection extends StatefulWidget {
  const ScreenshotOverlaySection({super.key});

  @override
  State<ScreenshotOverlaySection> createState() =>
      ScreenshotOverlaySectionState();
}

class ScreenshotOverlaySectionState extends State<ScreenshotOverlaySection> {
  bool _blocked = false;
  ScreenshotOverlayMode _selectedMode = ScreenshotOverlayMode.blur;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadBlockedState();
  }

  Future<void> _loadBlockedState() async {
    final blocked = await DeviceSafetyInfo.isScreenshotBlocked;
    if (mounted) setState(() => _blocked = blocked);
  }

  Future<void> _toggleBlocked(bool _) async {
    await DeviceSafetyInfo.toggleScreenshotBlocking();
    final blocked = await DeviceSafetyInfo.isScreenshotBlocked;
    if (mounted) setState(() => _blocked = blocked);
  }

  Future<void> _applyOverlay() async {
    await DeviceSafetyInfo.setScreenshotOverlayMode(
      mode: _selectedMode,
      blurRadius: 16,
      argbColor: _selectedMode == ScreenshotOverlayMode.color
          ? 0xFF6200EE
          : null,
      imageBytes: _selectedMode == ScreenshotOverlayMode.image
          ? base64Decode(_placeholderImageBase64)
          : null,
    );
    if (mounted) {
      setState(() => _status = 'Applied ${_selectedMode.name} overlay');
    }
  }

  Future<void> _clearOverlay() async {
    await DeviceSafetyInfo.clearScreenshotOverlayMode();
    if (mounted) setState(() => _status = 'Overlay cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(context, 'Screenshot Overlay Modes'),
        SwitchTile(
          title: 'Block Screenshots (via isScreenshotBlocked)',
          value: _blocked,
          onChanged: _toggleBlocked,
          icon: Icons.no_photography_outlined,
          subtitle: 'Backed by isScreenshotBlocked / toggleScreenshotBlocking.',
        ),
        DemoCard(
          children: [
            const Text(
              'Live overlay demo',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Shows a real, non-secure blur/color/image view over the screen whenever a '
              'capture/recording is detected — a branded placeholder instead of a plain '
              'black rectangle.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<ScreenshotOverlayMode>(
              value: _selectedMode,
              onChanged: (mode) {
                if (mode != null) setState(() => _selectedMode = mode);
              },
              items: ScreenshotOverlayMode.values
                  .map(
                    (mode) =>
                        DropdownMenuItem(value: mode, child: Text(mode.name)),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _applyOverlay,
                  icon: const Icon(Icons.layers),
                  label: const Text('Apply Overlay'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearOverlay,
                  icon: const Icon(Icons.layers_clear),
                  label: const Text('Clear Overlay'),
                ),
              ],
            ),
            if (_status != null) ...[const SizedBox(height: 8), Text(_status!)],
          ],
        ),
      ],
    );
  }
}
