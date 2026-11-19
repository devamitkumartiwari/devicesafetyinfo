import 'package:material_ui/material_ui.dart';

import '../sections/app_integrity_section.dart';
import '../sections/checks_section.dart';
import '../sections/live_events_section.dart';
import '../sections/overview_section.dart';
import '../sections/policy_section.dart';
import '../sections/protection_section.dart';
import '../sections/tools_section.dart';
import 'feature_page.dart';

/// Landing page: one entry per demo page.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static final _pages = <(String, String, IconData, Widget Function())>[
    (
      'Overview',
      'DeviceSafety.assess(): every check in one round trip',
      Icons.dashboard,
      OverviewSection.new,
    ),
    (
      'All checks',
      'Each detection API with its signals',
      Icons.fact_check,
      ChecksSection.new,
    ),
    (
      'Policy',
      'off / standard / strict and fail mode per check',
      Icons.tune,
      PolicySection.new,
    ),
    (
      'Protection',
      'Screenshots, overlay, app switcher, clipboard, tapjacking',
      Icons.shield,
      ProtectionSection.new,
    ),
    (
      'Live events',
      'Threat stream and platform events',
      Icons.sensors,
      LiveEventsSection.new,
    ),
    (
      'Tools',
      'IOC domains, malware list, calls, version check',
      Icons.build,
      ToolsSection.new,
    ),
    (
      'App integrity',
      'Play Integrity, App Attest, DeviceCheck',
      Icons.verified,
      AppIntegritySection.new,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Safety Info 2.0')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final (title, subtitle, icon, build) in _pages)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: ListTile(
                key: ValueKey('menu_${title.replaceAll(' ', '_')}'),
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FeaturePage(title: title, child: build()),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
