import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

/// Shows a [CheckResult] in plain words: the answer, then the evidence.
class ResultView extends StatelessWidget {
  const ResultView(this.result, {super.key});

  final CheckResult? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) {
      return const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Checking...'),
        ),
      );
    }

    // Red for a problem or an error, the app's teal when all is fine, grey when not run.
    final colors = Theme.of(context).colorScheme;
    final (icon, color, answer) = switch (r) {
      CheckResult(status: CheckStatus.unsupported) => (
        Icons.remove_circle_outline,
        colors.outline,
        'Not available on this platform',
      ),
      CheckResult(status: CheckStatus.skipped) => (
        Icons.block,
        colors.outline,
        'Turned off by policy',
      ),
      CheckResult(detected: true) => (
        Icons.warning_amber,
        colors.error,
        'DETECTED',
      ),
      CheckResult(status: CheckStatus.error || CheckStatus.timedOut) => (
        Icons.error_outline,
        colors.error,
        'Could not check (${r.status.name})',
      ),
      CheckResult(level: RiskLevel.low) => (
        Icons.info_outline,
        colors.primary,
        'Not detected (only weak signs found)',
      ),
      _ => (Icons.verified_user, colors.primary, 'Not detected'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    answer,
                    key: const ValueKey('check_answer'),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (r.signals.isEmpty)
              const Text('No signs found.')
            else ...[
              const Text('What was found:'),
              for (final s in r.signals)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${s.id}  (${s.level == RiskLevel.high ? 'high' : 'low'} risk)',
                  ),
                ),
            ],
            if (r.error != null) ...[
              const SizedBox(height: 8),
              Text('Error: ${r.error}'),
            ],
            const SizedBox(height: 8),
            Text(
              'Took ${r.elapsed.inMilliseconds} ms · policy: ${r.policy.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
