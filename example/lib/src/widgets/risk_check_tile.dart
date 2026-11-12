import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

/// Shows a tiered [RiskCheckResult] (from [DeviceSafetyInfo.rootCheck] or
/// [DeviceSafetyInfo.emulatorCheck]): the risk level, the suggested handling for that level,
/// and every individual signal that was found.
class RiskCheckTile extends StatelessWidget {
  const RiskCheckTile({
    super.key,
    required this.title,
    required this.result,
    required this.lowExamples,
    required this.highDescription,
  });

  /// e.g. 'Root risk level'.
  final String title;

  /// `null` while the check is still running.
  final RiskCheckResult? result;

  /// Short examples of low-risk signals, e.g. 'stock busybox, unlocked bootloader'.
  final String lowExamples;

  /// What a high result means, e.g. 'Strong root/jailbreak indicators'.
  final String highDescription;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final (
      Color color,
      String label,
      String advice,
      IconData icon,
    ) = switch (r?.level) {
      null => (Colors.orange, '—', 'Checking…', Icons.help_outline),
      RiskLevel.none => (
        Colors.green,
        'None',
        'No indicators found.',
        Icons.verified_user,
      ),
      RiskLevel.low => (
        Colors.amber.shade800,
        'Low',
        'Weak indicators only ($lowExamples). '
            'Suggested: allow, log signals, step-up auth for sensitive actions.',
        Icons.warning_amber,
      ),
      RiskLevel.high => (
        Colors.red,
        'High',
        '$highDescription. Suggested: block.',
        Icons.gpp_bad,
      ),
    };

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(advice),
              trailing: Chip(
                side: BorderSide.none,
                label: Text(label),
                backgroundColor: color.withValues(alpha: 0.18),
              ),
            ),
            if (r != null && r.signals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in r.highRiskSignals)
                      _signal(context, s, high: true),
                    for (final s in r.lowRiskSignals)
                      _signal(context, s, high: false),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _signal(BuildContext context, String signal, {required bool high}) {
    final color = high ? Colors.red : Colors.amber.shade800;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              high ? 'HIGH' : 'LOW',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              signal,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
