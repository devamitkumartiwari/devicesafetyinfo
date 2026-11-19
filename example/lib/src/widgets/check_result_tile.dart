import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

/// Shows one [CheckResult]: detected or not, status, level, policy and every signal.
class CheckResultTile extends StatelessWidget {
  const CheckResultTile({super.key, required this.title, required this.result});

  final String title;
  final CheckResult? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final scheme = Theme.of(context).colorScheme;
    final (color, icon, label) = switch (r) {
      null => (scheme.outline, Icons.hourglass_empty, '...'),
      CheckResult(status: CheckStatus.skipped) => (
        scheme.outline,
        Icons.block,
        'off',
      ),
      CheckResult(status: CheckStatus.unsupported) => (
        scheme.outline,
        Icons.remove_circle_outline,
        'n/a',
      ),
      CheckResult(detected: true) => (
        scheme.error,
        Icons.warning_amber,
        'DETECTED',
      ),
      CheckResult(status: CheckStatus.error || CheckStatus.timedOut) => (
        Colors.orange,
        Icons.error_outline,
        r.status.name,
      ),
      CheckResult(level: RiskLevel.low) => (
        Colors.amber.shade800,
        Icons.info_outline,
        'low',
      ),
      _ => (Colors.green, Icons.verified_user, 'clean'),
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: r == null
            ? null
            : Text(
                '${r.status.name} · policy ${r.policy.name} · ${r.elapsed.inMilliseconds} ms',
              ),
        trailing: Chip(
          side: BorderSide.none,
          label: Text(label),
          backgroundColor: color.withValues(alpha: 0.15),
        ),
        children: [
          if (r != null && r.signals.isEmpty && r.error == null)
            const ListTile(dense: true, title: Text('No signals')),
          if (r != null)
            for (final s in r.signals)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.circle,
                  size: 10,
                  color: s.level == RiskLevel.high
                      ? scheme.error
                      : Colors.amber.shade800,
                ),
                title: Text(s.id),
                subtitle: Text('${s.level.name} · ${s.source.name}'),
              ),
          if (r?.error != null)
            ListTile(dense: true, title: Text('Error: ${r!.error}')),
        ],
      ),
    );
  }
}
