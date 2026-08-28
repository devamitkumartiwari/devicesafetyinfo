import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../platform_support.dart';
import '../refreshable.dart';
import '../widgets/section_header.dart';
import '../widgets/stream_tile.dart';

/// Live streams: VPN status, screen-capture state, screenshot count, idle-timeout
/// count, and call activity.
class StreamsSection extends StatefulWidget {
  const StreamsSection({super.key, required this.idleTimeoutCount});

  /// Shared with the app-wide `IdleTimeoutGuard` (which wraps every page, not just this
  /// one) so the count stays correct regardless of which page is open when it fires.
  final ValueNotifier<int> idleTimeoutCount;

  @override
  State<StreamsSection> createState() => StreamsSectionState();
}

class StreamsSectionState extends State<StreamsSection> implements Refreshable {
  bool? _isVPN;
  bool _screenCaptureActive = false;
  int _screenshotCount = 0;
  bool? _isCallActive;
  String _callActivityStatus = 'No calls observed yet';

  final VPNCheck _vpnCheck = VPNCheck();
  late final Stream<VPNState> _vpnStream;

  @override
  void initState() {
    super.initState();
    _vpnStream = _vpnCheck.vpnState;
    _listenVpn();
    _listenScreenCapture();
    _listenScreenshots();
    _listenCallActivity();
    refresh();
  }

  @override
  void dispose() {
    _vpnCheck.dispose();
    super.dispose();
  }

  void _listenVpn() {
    _vpnStream.listen((state) {
      if (mounted) setState(() => _isVPN = state == VPNState.connectedState);
    }, onError: (e) => debugPrint('VPN error: $e'));
  }

  void _listenScreenCapture() {
    DeviceSafetyInfo.onScreenCapturedChanged.listen((capturing) {
      if (mounted) setState(() => _screenCaptureActive = capturing);
    }, onError: (e) => debugPrint('Screen capture error: $e'));
  }

  void _listenScreenshots() {
    DeviceSafetyInfo.onScreenshotTaken.listen((_) {
      if (mounted) setState(() => _screenshotCount++);
    }, onError: (e) => debugPrint('Screenshot error: $e'));
  }

  void _listenCallActivity() {
    DeviceSafetyInfo.onCallActivityChanged.listen((event) {
      if (!mounted) return;
      final source = switch (event.source) {
        CallActivitySource.simCall => 'SIM call',
        CallActivitySource.voipCall => 'VoIP call',
        CallActivitySource.callKitObserved => 'CallKit-observed call',
        CallActivitySource.audioInterrupted =>
          'possible call (audio interrupted)',
        CallActivitySource.unknown => 'call',
      };
      final state = event.state == CallActivityState.started
          ? 'started'
          : 'ended';
      setState(() {
        _callActivityStatus = '$source $state';
        _isCallActive = event.state == CallActivityState.started;
      });
    }, onError: (e) => debugPrint('Call activity stream error: $e'));
  }

  @override
  Future<void> refresh() async {
    final callActive = await DeviceSafetyInfo.isCallActive;
    if (mounted) setState(() => _isCallActive = callActive);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(context, 'Live Streams'),
        StreamTile(
          title: 'VPN status',
          value: _isVPN == true ? 'Connected' : 'Disconnected',
          icon: Icons.vpn_lock,
          color: _isVPN == true ? Colors.orange : Colors.green,
          subtitle: 'Updates instantly on network change.',
        ),
        StreamTile(
          title: 'Screen recording stream',
          value: _screenCaptureActive ? 'Active' : 'Inactive',
          icon: Icons.screen_search_desktop,
          color: _screenCaptureActive ? Colors.red : Colors.green,
          subtitle: 'Real-time recording/mirroring detection.',
        ),
        StreamTile(
          title: 'Screenshots taken',
          value: '$_screenshotCount',
          icon: Icons.screenshot_monitor,
          color: _screenshotCount > 0 ? Colors.orange : Colors.blueGrey,
          subtitle: isAndroidPlatform
              ? 'Android 34+: no permission. 24–33: needs READ_MEDIA_IMAGES.'
              : 'iOS: no permission needed.',
        ),
        ValueListenableBuilder<int>(
          valueListenable: widget.idleTimeoutCount,
          builder: (context, count, _) => StreamTile(
            title: 'Idle timeouts fired',
            value: '$count',
            icon: Icons.timer_outlined,
            color: Colors.blueGrey,
            subtitle: 'IdleTimeoutGuard wraps the whole app — fires after 30s with no touches anywhere.',
          ),
        ),
        StreamTile(
          title: 'Call activity',
          value: _isCallActive == true ? 'Active' : 'Inactive',
          icon: Icons.call,
          color: _isCallActive == true ? Colors.orange : Colors.green,
          subtitle:
              '$_callActivityStatus. Detects SIM or VoIP calls (WhatsApp/Teams/etc.) '
              'without identifying which app.',
        ),
      ],
    );
  }
}
