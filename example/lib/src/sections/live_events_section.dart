import 'dart:async';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../widgets/section_header.dart';
import '../widgets/stream_tile.dart';

/// The threat stream and the raw platform event streams.
class LiveEventsSection extends StatefulWidget {
  const LiveEventsSection({super.key});

  @override
  State<LiveEventsSection> createState() => _LiveEventsSectionState();
}

class _LiveEventsSectionState extends State<LiveEventsSection> {
  final List<ThreatEvent> _threats = [];
  final List<StreamSubscription<Object?>> _subs = [];
  bool? _captured;
  bool? _recording;
  bool? _vpn;
  int _clipboardChanges = 0;
  CallActivityEvent? _lastCall;

  @override
  void initState() {
    super.initState();
    void onError(Object e) => debugPrint('stream error: $e');
    _subs.addAll([
      DeviceSafety.threats.listen((e) => setState(() => _threats.insert(0, e))),
      DeviceSafety.screen.captureChanges.listen(
        (v) => setState(() => _captured = v),
        onError: onError,
      ),
      DeviceSafety.screen.recordingChanges.listen(
        (v) => setState(() => _recording = v),
        onError: onError,
      ),
      DeviceSafety.vpn.changes.listen(
        (v) => setState(() => _vpn = v),
        onError: onError,
      ),
      DeviceSafety.clipboard.changes.listen(
        (_) => setState(() => _clipboardChanges++),
        onError: onError,
      ),
      DeviceSafety.calls.changes.listen(
        (e) => setState(() => _lastCall = e),
        onError: onError,
      ),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  String _bool(bool? v) => v == null ? '-' : (v ? 'yes' : 'no');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamTile(
          title: 'Screen captured',
          value: _bool(_captured),
          icon: Icons.cast,
          color: Colors.red,
        ),
        StreamTile(
          title: 'Screen recording',
          value: _bool(_recording),
          icon: Icons.videocam,
          color: Colors.deepOrange,
        ),
        StreamTile(
          title: 'VPN active',
          value: _bool(_vpn),
          icon: Icons.vpn_lock,
          color: Colors.blue,
        ),
        StreamTile(
          title: 'Clipboard changes',
          value: '$_clipboardChanges',
          icon: Icons.paste,
          color: Colors.teal,
        ),
        StreamTile(
          title: 'Last call event',
          value: _lastCall == null
              ? '-'
              : (_lastCall!.started ? 'started' : 'ended'),
          subtitle: _lastCall?.source.name,
          icon: Icons.call,
          color: Colors.green,
        ),
        ValueListenableBuilder(
          valueListenable: AppState.instance.idleTimeouts,
          builder: (context, n, _) => StreamTile(
            title: 'Idle timeouts (30 s)',
            value: '$n',
            icon: Icons.timer,
            color: Colors.purple,
          ),
        ),
        sectionHeader(context, 'Threat stream (take a screenshot to try it)'),
        if (_threats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No threats yet'),
          ),
        for (final t in _threats)
          ListTile(
            leading: const Icon(Icons.warning_amber),
            title: Text(t.detail ?? '${t.type.name} detected'),
            subtitle: Text('${t.type.name} · ${t.at.toIso8601String()}'),
          ),
      ],
    );
  }
}
