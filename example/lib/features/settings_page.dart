import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';
import '../common/result_view.dart';

/// Settings: how strict each check is.
///
/// ```dart
/// await DeviceSafety.initialize(DeviceSafetyConfig(
///   defaultPolicy: .standard,             // only strong evidence counts
///   policies: {CheckType.vpn: .strict},   // any evidence counts
///   failModes: {CheckType.root: .closed}, // an error counts as detected
/// ));
/// ```
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // The checks shown here; every CheckType works the same way.
  static const _types = [
    CheckType.root,
    CheckType.emulator,
    CheckType.vpn,
    CheckType.developerMode,
  ];

  RiskAssessment? _report;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final report = await DeviceSafety.assess(checks: _types, refresh: true);
    if (mounted) setState(() => _report = report);
  }

  /// Applies a new config. initialize can be called again at any time.
  Future<void> _setPolicy(CheckType type, RiskPolicy policy) async {
    final config = DeviceSafety.config;
    await DeviceSafety.initialize(
      config.copyWith(policies: {...config.policies, type: policy}),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Policy',
      about:
          'Each check finds "high" (strong) and "low" (weak) signs. The policy decides '
          'what counts: standard = only high, strict = any, off = don\'t run.',
      code: '''await DeviceSafety.initialize(DeviceSafetyConfig(
  defaultPolicy: .standard,             // only strong evidence counts
  policies: {CheckType.vpn: .strict},   // any evidence counts
  failModes: {CheckType.root: .closed}, // an error counts as detected
));''',
      children: [
        for (final type in _types) ...[
          Text(type.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          SegmentedButton<RiskPolicy>(
            key: ValueKey('policy_${type.name}'),
            segments: const [
              ButtonSegment(value: RiskPolicy.off, label: Text('off')),
              ButtonSegment(
                value: RiskPolicy.standard,
                label: Text('standard'),
              ),
              ButtonSegment(value: RiskPolicy.strict, label: Text('strict')),
            ],
            selected: {DeviceSafety.config.policyFor(type)},
            onSelectionChanged: (s) => _setPolicy(type, s.single),
          ),
          ResultView(_report?.results[type]),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
