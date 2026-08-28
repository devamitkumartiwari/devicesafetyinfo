import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../platform_support.dart';
import '../widgets/demo_card.dart';
import '../widgets/section_header.dart';
import '../widgets/stream_tile.dart';

/// Overlay-attack count (Android-only) plus the clipboard copy/clear demo.
class OverlayClipboardSection extends StatefulWidget {
  const OverlayClipboardSection({super.key});

  @override
  State<OverlayClipboardSection> createState() =>
      OverlayClipboardSectionState();
}

class OverlayClipboardSectionState extends State<OverlayClipboardSection> {
  int _overlayAttackCount = 0;
  int _clipboardChangeCount = 0;

  final TextEditingController _clipboardController = TextEditingController(
    text: '123456',
  );

  @override
  void initState() {
    super.initState();
    if (isAndroidPlatform) _listenOverlayAttacks();
    _listenClipboardChanges();
  }

  @override
  void dispose() {
    _clipboardController.dispose();
    super.dispose();
  }

  void _listenOverlayAttacks() {
    DeviceSafetyInfo.onOverlayAttackDetected.listen((_) {
      if (mounted) setState(() => _overlayAttackCount++);
    }, onError: (e) => debugPrint('Overlay attack stream error: $e'));
  }

  void _listenClipboardChanges() {
    DeviceSafetyInfo.onClipboardChanged.listen((_) {
      if (mounted) setState(() => _clipboardChangeCount++);
    }, onError: (e) => debugPrint('Clipboard stream error: $e'));
  }

  Future<void> _copySensitiveToClipboard() async {
    await DeviceSafetyInfo.copyToClipboard(
      _clipboardController.text,
      sensitive: true,
      autoClear: const Duration(seconds: 30),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied — clears automatically in 30s')),
      );
    }
  }

  Future<void> _clearClipboard() async {
    await DeviceSafetyInfo.clearClipboard();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Clipboard cleared')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(context, 'Overlay & Clipboard'),
        AndroidOnly(
          child: StreamTile(
            title: 'Overlay attacks detected',
            value: '$_overlayAttackCount',
            icon: Icons.layers,
            color: _overlayAttackCount > 0 ? Colors.red : Colors.green,
            subtitle:
                "Touches received while obscured by another app's overlay.",
          ),
        ),
        StreamTile(
          title: 'Clipboard changes',
          value: '$_clipboardChangeCount',
          icon: Icons.content_paste,
          color: Colors.blueGrey,
          subtitle: 'Fires for changes from any app, not just this one.',
        ),
        DemoCard(
          children: [
            const Text(
              'Clipboard demo',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _clipboardController,
              decoration: const InputDecoration(
                labelText: 'Text to copy',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _copySensitiveToClipboard,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy (sensitive, 30s auto-clear)'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearClipboard,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear Clipboard'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
