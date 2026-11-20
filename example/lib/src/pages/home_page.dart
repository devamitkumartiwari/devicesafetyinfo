import 'package:flutter/widgets.dart';

import '../sections/app_integrity_section.dart';
import '../sections/checks_section.dart';
import '../sections/fraud_signals_section.dart';
import '../sections/live_events_section.dart';
import '../sections/overview_section.dart';
import '../sections/policy_section.dart';
import '../sections/protection_section.dart';
import '../sections/strong_auth_section.dart';
import '../sections/tools_section.dart';
import '../ui/adaptive.dart';

/// Landing page: one entry per demo page, plus the Material / Cupertino switch.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static final _pages =
      <(String, String, IconData, IconData, Widget Function())>[
        (
          'Overview',
          'DeviceSafety.assess(): every check in one round trip',
          Icons.dashboard,
          CupertinoIcons.square_grid_2x2,
          OverviewSection.new,
        ),
        (
          'All checks',
          'Each detection API with its signals',
          Icons.fact_check,
          CupertinoIcons.checkmark_rectangle,
          ChecksSection.new,
        ),
        (
          'Policy',
          'off / standard / strict and fail mode per check',
          Icons.tune,
          CupertinoIcons.slider_horizontal_3,
          PolicySection.new,
        ),
        (
          'Fraud signals',
          'Remote access, GPS spoofing, cloning, MITM, keyboard',
          Icons.policy,
          CupertinoIcons.exclamationmark_shield,
          FraudSignalsSection.new,
        ),
        (
          'Strong auth',
          'Device key, biometric approval, secure PIN, pinning',
          Icons.key,
          CupertinoIcons.lock_shield,
          StrongAuthSection.new,
        ),
        (
          'Protection',
          'Screenshots, overlay, app switcher, clipboard, tapjacking',
          Icons.shield,
          CupertinoIcons.shield,
          ProtectionSection.new,
        ),
        (
          'Live events',
          'Threat stream and platform events',
          Icons.sensors,
          CupertinoIcons.dot_radiowaves_left_right,
          LiveEventsSection.new,
        ),
        (
          'Tools',
          'IOC domains, malware list, calls, version check',
          Icons.build,
          CupertinoIcons.wrench,
          ToolsSection.new,
        ),
        (
          'App integrity',
          'Play Integrity, App Attest, DeviceCheck',
          Icons.verified,
          CupertinoIcons.checkmark_seal,
          AppIntegritySection.new,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return AdaptivePage(
      title: 'Device Safety Info 2.0',
      actions: const [StyleToggleButton()],
      child: AdaptiveSection(
        header: 'Demos',
        footer: isCupertino
            ? 'Cupertino style. Tap the brush to switch to Material.'
            : 'Material style. Tap the phone icon to switch to Cupertino.',
        children: [
          for (final (title, subtitle, material, cupertino, build) in _pages)
            AdaptiveTile(
              key: ValueKey('menu_${title.replaceAll(' ', '_')}'),
              leading: Icon(adaptiveIcon(material, cupertino)),
              title: title,
              subtitle: subtitle,
              trailing: Icon(
                adaptiveIcon(
                  Icons.chevron_right,
                  CupertinoIcons.chevron_forward,
                ),
                size: isCupertino ? 18 : 24,
              ),
              onTap: () =>
                  pushPage(context, AdaptivePage(title: title, child: build())),
            ),
        ],
      ),
    );
  }
}
