import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../widgets/check_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/stream_tile.dart';

/// Demo for the standalone [ScreenRecordingDetector]: capability support plus a live
/// started/stopped indicator, distinct from the screen-capture/mirroring stream shown
/// in the Live Streams section.
class ScreenRecordingSection extends StatefulWidget {
  const ScreenRecordingSection({super.key});

  @override
  State<ScreenRecordingSection> createState() => ScreenRecordingSectionState();
}

class ScreenRecordingSectionState extends State<ScreenRecordingSection> {
  bool? _isSupported;
  bool _isRecording = false;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _checkSupport();
    _subscription = ScreenRecordingDetector.onScreenRecordingChanged.listen((
      recording,
    ) {
      if (mounted) setState(() => _isRecording = recording);
    }, onError: (e) => debugPrint('Screen recording stream error: $e'));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkSupport() async {
    final supported = await ScreenRecordingDetector.isSupported;
    if (mounted) setState(() => _isSupported = supported);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(context, 'Screen Recording Detection'),
        CheckTile(
          title: 'Screen-recording detection supported',
          value: _isSupported,
          icon: Icons.videocam_outlined,
          subtitle:
              'Android: API 35+ recording-session callback. iOS: shares the '
              'screen-capture signal, so it always reports supported.',
        ),
        StreamTile(
          title: 'Screen recording',
          value: _isRecording ? 'Recording' : 'Not recording',
          icon: Icons.fiber_manual_record,
          color: _isRecording ? Colors.red : Colors.green,
          subtitle:
              'Distinct from the mirroring/external-display check above — see '
              'ScreenRecordingDetector doc comment.',
        ),
      ],
    );
  }
}
