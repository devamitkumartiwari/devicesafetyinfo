import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/widgets.dart';

import '../app_state.dart';
import '../ui/adaptive.dart';
import '../widgets/check_result_tile.dart';

/// Edits the policy and fail mode per check and shows the effect immediately.
class PolicySection extends StatefulWidget {
  const PolicySection({super.key});

  @override
  State<PolicySection> createState() => _PolicySectionState();
}

class _PolicySectionState extends State<PolicySection> {
  RiskAssessment? _assessment;

  static const _policies = {
    RiskPolicy.off: 'off',
    RiskPolicy.standard: 'standard',
    RiskPolicy.strict: 'strict',
  };

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

  Future<void> _apply(DeviceSafetyConfig next) async {
    await AppState.instance.apply(next);
    await _refresh();
  }

  Future<void> _setPolicy(CheckType type, RiskPolicy policy) =>
      _apply(_config.copyWith(policies: {..._config.policies, type: policy}));

  Future<void> _setFailMode(CheckType type, bool closed) => _apply(
    _config.copyWith(
      failModes: {
        ..._config.failModes,
        type: closed ? FailMode.closed : FailMode.open,
      },
    ),
  );

  Future<void> _setDefault(RiskPolicy policy) =>
      _apply(_config.copyWith(defaultPolicy: policy, policies: const {}));

  @override
  Widget build(BuildContext context) {
    final types = [
      for (final t in CheckType.values)
        if (t != CheckType.overlayAttack) t,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveSection(
          header: 'Default policy',
          footer: 'Changing the default resets the per-check policies below.',
          children: [
            SectionContent(
              child: AdaptiveSegmented<RiskPolicy>(
                key: const ValueKey('policy_default'),
                segments: _policies,
                selected: _config.defaultPolicy,
                onChanged: _setDefault,
              ),
            ),
          ],
        ),
        for (final t in types)
          AdaptiveSection(
            header: t.name,
            children: [
              SectionContent(
                child: AdaptiveSegmented<RiskPolicy>(
                  key: ValueKey('policy_${t.name}'),
                  segments: _policies,
                  selected: _config.policyFor(t),
                  onChanged: (p) => _setPolicy(t, p),
                ),
              ),
              AdaptiveSwitchTile(
                key: ValueKey('failclosed_${t.name}'),
                title: 'Fail closed',
                subtitle: 'Errors and timeouts count as detected',
                value: _config.failModeFor(t) == FailMode.closed,
                onChanged: (v) => _setFailMode(t, v),
              ),
              CheckResultTile(title: 'Result', result: _assessment?.results[t]),
            ],
          ),
      ],
    );
  }
}
