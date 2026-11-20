import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/widgets.dart';

import '../app_state.dart';
import '../ui/adaptive.dart';
import '../widgets/check_result_tile.dart';

/// Every detection API, called individually.
class ChecksSection extends StatefulWidget {
  const ChecksSection({super.key});

  @override
  State<ChecksSection> createState() => _ChecksSectionState();
}

class _ChecksSectionState extends State<ChecksSection> {
  static final _apis = <(String, DetectionApi Function())>[
    ('Root / jailbreak', () => DeviceSafety.root),
    ('Emulator / simulator', () => DeviceSafety.emulator),
    ('Hooking (Frida, Xposed)', () => DeviceSafety.hooking),
    ('Debugger', () => DeviceSafety.debugger),
    ('Developer mode', () => DeviceSafety.posture.developerMode),
    ('Screen lock', () => DeviceSafety.posture.screenLock),
    ('Store install', () => DeviceSafety.posture.storeInstall),
    ('External storage', () => DeviceSafety.posture.externalStorage),
    ('Unknown sources', () => DeviceSafety.posture.unknownSources),
    ('Play Protect', () => DeviceSafety.posture.playProtect),
    ('Accessibility services', () => DeviceSafety.accessibility),
    ('Notification listeners', () => DeviceSafety.notificationListeners),
    ('VPN / proxy', () => DeviceSafety.vpn),
    ('Screen capture', () => DeviceSafety.screen),
    ('Malware packages', () => DeviceSafety.malware),
    ('Tampering (re-signed app)', () => DeviceSafety.tampering),
  ];

  final Map<String, CheckResult> _results = {};

  @override
  void initState() {
    super.initState();
    AppState.instance.configVersion.addListener(_runAll);
    _runAll();
  }

  @override
  void dispose() {
    AppState.instance.configVersion.removeListener(_runAll);
    super.dispose();
  }

  Future<void> _runAll() async {
    await Future.wait([
      for (final (title, api) in _apis)
        api().check(refresh: true).then((r) {
          if (mounted) setState(() => _results[title] = r);
        }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveSection(
      header: 'Detection APIs',
      footer: 'Each check runs on its own, bypassing the cache. Tap a row for its signals.',
      children: [
        for (final (title, _) in _apis)
          CheckResultTile(title: title, result: _results[title]),
      ],
    );
  }
}
