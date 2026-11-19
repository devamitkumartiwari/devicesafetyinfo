import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../widgets/check_result_tile.dart';
import '../widgets/demo_card.dart';

/// Runs DeviceSafety.assess() and shows the flags and every result.
class OverviewSection extends StatefulWidget {
  const OverviewSection({super.key});

  @override
  State<OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<OverviewSection> {
  RiskAssessment? _assessment;
  Duration? _took;

  @override
  void initState() {
    super.initState();
    AppState.instance.configVersion.addListener(_run);
    _run();
  }

  @override
  void dispose() {
    AppState.instance.configVersion.removeListener(_run);
    super.dispose();
  }

  Future<void> _run({bool refresh = false}) async {
    final sw = Stopwatch()..start();
    final a = await DeviceSafety.assess(refresh: refresh);
    if (!mounted) return;
    setState(() {
      _assessment = a;
      _took = sw.elapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = _assessment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DemoCard(
          children: [
            Text(
              a == null
                  ? 'Assessing...'
                  : a.detected
                  ? '${a.flags.length} risk(s) detected'
                  : 'No risks detected',
              key: const ValueKey('assessment_summary'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_took != null)
              Text(
                'Took ${_took!.inMilliseconds} ms (cached results are reused).',
              ),
            if (a != null)
              for (final f in a.flags)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber),
                  title: Text(f.title),
                  subtitle: Text(f.description),
                ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('assess_refresh'),
              onPressed: () => _run(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Re-run without cache'),
            ),
          ],
        ),
        if (a != null)
          for (final MapEntry(:key, :value) in a.results.entries)
            CheckResultTile(title: key.name, result: value),
      ],
    );
  }
}
