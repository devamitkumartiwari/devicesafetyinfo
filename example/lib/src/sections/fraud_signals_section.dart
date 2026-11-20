import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/widgets.dart';

import '../app_state.dart';
import '../ui/adaptive.dart';
import '../widgets/check_result_tile.dart';

/// The fraud-environment checks: remote control, GPS spoofing, cloning, MITM, keyboard.
class FraudSignalsSection extends StatefulWidget {
  const FraudSignalsSection({super.key});

  @override
  State<FraudSignalsSection> createState() => _FraudSignalsSectionState();
}

class _FraudSignalsSectionState extends State<FraudSignalsSection> {
  static final _apis = <(String, String, DetectionApi Function())>[
    (
      'Remote access',
      'AnyDesk, TeamViewer QuickSupport, RustDesk... (high when it controls the screen)',
      () => DeviceSafety.remoteAccess,
    ),
    (
      'GPS spoofing',
      'Mock location app selected, or a mock fix',
      () => DeviceSafety.locationSpoofing,
    ),
    (
      'App cloning',
      'Parallel Space, Dual Messenger, Secure Folder, work profile',
      () => DeviceSafety.appCloning,
    ),
    (
      'MITM certificates',
      'User-installed CA (high with a VPN or proxy)',
      () => DeviceSafety.mitm,
    ),
    (
      'Keyboard',
      'Third-party default keyboard (high with an accessibility service)',
      () => DeviceSafety.keyboard,
    ),
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
      for (final (title, _, api) in _apis)
        api().check(refresh: true).then((r) {
          if (mounted) setState(() => _results[title] = r);
        }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveSection(
          header: 'Fraud signals',
          footer:
              'What scammers and fraud farms rely on. Android only; iOS shows n/a. '
              'Tap a row for its signals.',
          children: [
            for (final (title, _, _) in _apis)
              CheckResultTile(title: title, result: _results[title]),
          ],
        ),
        AdaptiveSection(
          header: 'What each check looks for',
          children: [
            for (final (title, what, _) in _apis)
              AdaptiveTile(title: title, subtitle: what),
          ],
        ),
        AdaptiveSection(
          children: [
            SectionContent(
              child: AdaptiveButton(
                key: const ValueKey('fraud_refresh'),
                label: 'Run again',
                filled: false,
                onPressed: _runAll,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
