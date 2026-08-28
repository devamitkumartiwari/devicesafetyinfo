import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../platform_support.dart';
import '../widgets/demo_card.dart';
import '../widgets/section_header.dart';

/// Android-only call-screening-settings shortcut — the practical mitigation for
/// banking-trojan call interception, since the role holder can't be read programmatically.
class BankingDefensesSection extends StatefulWidget {
  const BankingDefensesSection({super.key});

  @override
  State<BankingDefensesSection> createState() => BankingDefensesSectionState();
}

class BankingDefensesSectionState extends State<BankingDefensesSection> {
  Future<void> _openCallScreeningSettings() async {
    await DeviceSafetyInfo.openCallScreeningRoleSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(context, 'Banking Malware Defenses'),
        AndroidOnly(
          child: DemoCard(
            children: [
              const Text(
                'Call-screening role',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'There is no public API to detect a malicious app holding this role — '
                'this opens the OS role picker so the user can review it themselves.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _openCallScreeningSettings,
                icon: const Icon(Icons.settings_phone_outlined),
                label: const Text('Open Call-Screening Settings'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
