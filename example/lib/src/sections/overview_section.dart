import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/widgets.dart';

import '../app_state.dart';
import '../ui/adaptive.dart';
import '../widgets/check_result_tile.dart';

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
        AdaptiveSection(
          header: 'Summary',
          footer: _took == null
              ? null
              : 'Took ${_took!.inMilliseconds} ms (cached results are reused).',
          children: [
            AdaptiveTile(
              key: const ValueKey('assessment_summary'),
              leading: Icon(
                a?.detected ?? false
                    ? adaptiveIcon(
                        Icons.warning_amber,
                        CupertinoIcons.exclamationmark_triangle_fill,
                      )
                    : adaptiveIcon(
                        Icons.verified_user,
                        CupertinoIcons.checkmark_shield_fill,
                      ),
                color: a?.detected ?? false
                    ? StatusColors.danger
                    : StatusColors.ok,
              ),
              title: a == null
                  ? 'Assessing...'
                  : a.detected
                  ? '${a.flags.length} risk(s) detected'
                  : 'No risks detected',
            ),
            if (a != null)
              for (final f in a.flags)
                AdaptiveTile(
                  leading: Icon(
                    adaptiveIcon(
                      Icons.report,
                      CupertinoIcons.exclamationmark_circle,
                    ),
                    color: StatusColors.danger,
                  ),
                  title: f.title,
                  subtitle: f.description,
                ),
            SectionContent(
              child: AdaptiveButton(
                key: const ValueKey('assess_refresh'),
                icon: adaptiveIcon(Icons.refresh, CupertinoIcons.refresh),
                label: 'Re-run without cache',
                onPressed: () => _run(refresh: true),
              ),
            ),
          ],
        ),
        if (a != null)
          AdaptiveSection(
            header: 'Results',
            children: [
              for (final MapEntry(:key, :value) in a.results.entries)
                CheckResultTile(title: key.name, result: value),
            ],
          ),
      ],
    );
  }
}
