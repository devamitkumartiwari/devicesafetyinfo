import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../widgets/check_result_tile.dart';

/// Edits the policy and fail mode per check and shows the effect immediately.
class PolicySection extends StatefulWidget {
  const PolicySection({super.key});

  @override
  State<PolicySection> createState() => _PolicySectionState();
}

class _PolicySectionState extends State<PolicySection> {
  RiskAssessment? _assessment;

  DeviceSafetyConfig get _config => AppState.instance.config;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final a = await DeviceSafety.assess(refresh: true);
    if (mounted) setState(() => _assessment = a);
  }

  Future<void> _setPolicy(CheckType type, RiskPolicy policy) async {
    await AppState.instance.apply(
      _config.copyWith(policies: {..._config.policies, type: policy}),
    );
    await _refresh();
  }

  Future<void> _setFailMode(CheckType type, bool closed) async {
    await AppState.instance.apply(
      _config.copyWith(
        failModes: {
          ..._config.failModes,
          type: closed ? FailMode.closed : FailMode.open,
        },
      ),
    );
    await _refresh();
  }

  Future<void> _setDefault(RiskPolicy policy) async {
    await AppState.instance.apply(
      _config.copyWith(defaultPolicy: policy, policies: const {}),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final types = [
      for (final t in CheckType.values)
        if (t != CheckType.overlayAttack) t,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Default policy (resets per-check policies)'),
              const SizedBox(height: 8),
              SegmentedButton<RiskPolicy>(
                segments: [
                  for (final p in RiskPolicy.values)
                    ButtonSegment(value: p, label: Text(p.name)),
                ],
                selected: {_config.defaultPolicy},
                onSelectionChanged: (s) => _setDefault(s.single),
              ),
            ],
          ),
        ),
        for (final t in types)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Text('fail closed'),
                      Switch(
                        value: _config.failModeFor(t) == FailMode.closed,
                        onChanged: (v) => _setFailMode(t, v),
                      ),
                    ],
                  ),
                  SegmentedButton<RiskPolicy>(
                    key: ValueKey('policy_${t.name}'),
                    segments: [
                      for (final p in RiskPolicy.values)
                        ButtonSegment(value: p, label: Text(p.name)),
                    ],
                    selected: {_config.policyFor(t)},
                    onSelectionChanged: (s) => _setPolicy(t, s.single),
                  ),
                  CheckResultTile(
                    title: 'Result',
                    result: _assessment?.results[t],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
