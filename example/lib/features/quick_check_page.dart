import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Quick check: every check in one call, with plain-language results.
///
/// ```dart
/// final report = await DeviceSafety.assess();
/// if (report.detected) {
///   for (final flag in report.flags) {
///     print('${flag.title}: ${flag.description}');
///   }
/// }
/// ```
class QuickCheckPage extends StatefulWidget {
  const QuickCheckPage({super.key});

  @override
  State<QuickCheckPage> createState() => _QuickCheckPageState();
}

class _QuickCheckPageState extends State<QuickCheckPage> {
  RiskAssessment? _report;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _report = null);
    final report = await DeviceSafety.assess(refresh: true);
    if (mounted) setState(() => _report = report);
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return DemoScaffold(
      title: 'Quick check',
      about:
          'Runs every check at once. Use it before a payment or login. Each problem '
          'comes with a title and description you can show to the user.',
      code: '''final report = await DeviceSafety.assess();
if (report.detected) {
  for (final flag in report.flags) {
    print('\${flag.title}: \${flag.description}');
  }
}''',
      children: [
        Card(
          child: ListTile(
            key: const ValueKey('assessment_summary'),
            leading: report == null
                ? const CircularProgressIndicator()
                : Icon(
                    report.detected ? Icons.warning_amber : Icons.verified_user,
                    color: report.detected
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
            title: Text(
              report == null
                  ? 'Checking...'
                  : report.detected
                  ? '${report.flags.length} problem(s) found'
                  : 'No problems found',
            ),
          ),
        ),
        if (report != null)
          for (final flag in report.flags)
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.report,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(flag.title),
                subtitle: Text(flag.description),
              ),
            ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _run,
          icon: const Icon(Icons.refresh),
          label: const Text('Run again'),
        ),
      ],
    );
  }
}
