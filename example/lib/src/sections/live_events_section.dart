import 'dart:async';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/widgets.dart';

import '../app_state.dart';
import '../ui/adaptive.dart';

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

  Widget _row(
    String title,
    String value,
    IconData material,
    IconData cupertino,
    Color color, {
    String? subtitle,
  }) => AdaptiveTile(
    leading: Icon(adaptiveIcon(material, cupertino), color: color),
    title: title,
    subtitle: subtitle,
    trailing: AdaptiveChip(label: value, color: color),
  );

  String _bool(bool? v) => v == null ? '-' : (v ? 'yes' : 'no');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveSection(
          header: 'Platform events',
          children: [
            _row(
              'Screen captured',
              _bool(_captured),
              Icons.cast,
              CupertinoIcons.tv,
              StatusColors.danger,
            ),
            _row(
              'Screen recording',
              _bool(_recording),
              Icons.videocam,
              CupertinoIcons.videocam,
              StatusColors.warning,
            ),
            _row(
              'VPN active',
              _bool(_vpn),
              Icons.vpn_lock,
              CupertinoIcons.lock_shield,
              const Color(0xFF1565C0),
            ),
            _row(
              'Clipboard changes',
              '$_clipboardChanges',
              Icons.paste,
              CupertinoIcons.doc_on_clipboard,
              const Color(0xFF00838F),
            ),
            _row(
              'Last call event',
              _lastCall == null
                  ? '-'
                  : (_lastCall!.started ? 'started' : 'ended'),
              Icons.call,
              CupertinoIcons.phone,
              StatusColors.ok,
              subtitle: _lastCall?.source.name,
            ),
            ValueListenableBuilder(
              valueListenable: AppState.instance.idleTimeouts,
              builder: (context, n, _) => _row(
                'Idle timeouts (30 s)',
                '$n',
                Icons.timer,
                CupertinoIcons.timer,
                const Color(0xFF6A1B9A),
              ),
            ),
          ],
        ),
        AdaptiveSection(
          header: 'Threat stream',
          footer: 'Take a screenshot to try it.',
          children: [
            if (_threats.isEmpty) const AdaptiveTile(title: 'No threats yet'),
            for (final t in _threats.take(30))
              AdaptiveTile(
                leading: Icon(
                  adaptiveIcon(
                    Icons.warning_amber,
                    CupertinoIcons.exclamationmark_triangle,
                  ),
                  color: StatusColors.danger,
                ),
                title: t.detail ?? '${t.type.name} detected',
                subtitle: '${t.type.name} · ${t.at.toIso8601String()}',
              ),
          ],
        ),
      ],
    );
  }
}
