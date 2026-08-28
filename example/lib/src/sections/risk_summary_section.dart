import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../widgets/demo_card.dart';

/// Risk-summary demo. Renders directly under [MalwareCheckSection]'s "Malware & Risk"
/// header — no header of its own, matching the original layout.
class RiskSummarySection extends StatefulWidget {
  const RiskSummarySection({super.key});

  @override
  State<RiskSummarySection> createState() => RiskSummarySectionState();
}

class RiskSummarySectionState extends State<RiskSummarySection> {
  List<RiskFlag>? _riskFlags;

  Future<void> _evaluateRisk() async {
    final flags = await RiskSummary.evaluate();
    if (mounted) setState(() => _riskFlags = flags);
  }

  @override
  Widget build(BuildContext context) {
    return DemoCard(
      children: [
        const Text(
          'Risk summary',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Aggregates rooted/hooked/debugger/screen-capture/VPN/screen-lock checks.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _evaluateRisk,
          icon: const Icon(Icons.assessment_outlined),
          label: const Text('Evaluate Risk'),
        ),
        if (_riskFlags != null) ...[
          const SizedBox(height: 8),
          if (_riskFlags!.isEmpty)
            const Text(
              'No active risk flags.',
              style: TextStyle(color: Colors.green),
            )
          else
            ..._riskFlags!.map(
              (flag) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• ${flag.title}: ${flag.description}'),
              ),
            ),
        ],
      ],
    );
  }
}
