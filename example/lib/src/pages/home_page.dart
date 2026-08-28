import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../sections/actions_section.dart';
import '../sections/android_posture_section.dart';
import '../sections/banking_defenses_section.dart';
import '../sections/danger_zone_section.dart';
import '../sections/detection_section.dart';
import '../sections/ioc_domain_section.dart';
import '../sections/malware_check_section.dart';
import '../sections/overlay_clipboard_section.dart';
import '../sections/risk_summary_section.dart';
import '../sections/screen_recording_section.dart';
import '../sections/screenshot_overlay_section.dart';
import '../sections/streams_section.dart';
import '../refreshable.dart';
import 'feature_page.dart';

class _FeatureMenuGroup {
  const _FeatureMenuGroup(this.label, this.items);
  final String label;
  final List<_FeatureMenuItem> items;
}

class _FeatureMenuItem {
  const _FeatureMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.open,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final void Function(BuildContext context) open;
}

/// The app's landing page: a grouped menu of every demo feature. Selecting an item
/// pushes a dedicated [FeaturePage] for that feature, rather than showing everything
/// on one long scrolling screen.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.idleTimeoutCount});

  /// Shared with [StreamsSection], which is only mounted while its own page is open —
  /// this keeps the idle-timeout counter alive and visible regardless of which page
  /// the [IdleTimeoutGuard] (wrapping the whole app) fires on.
  final ValueNotifier<int> idleTimeoutCount;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _checkAppVersion() async {
    final checker = NewVersionChecker(
      iOSId: '',
      androidId: '',
      minAppVersion: '1.0.0',
    );
    try {
      final status = await checker.getVersionStatus();
      if (!mounted) return;
      final message = switch (status?.urgency) {
        UpdateUrgency.required =>
          'Update required: ${status?.storeVersion} (local ${status?.localVersion} is below the minimum)',
        UpdateUrgency.optional =>
          'New version available: ${status?.storeVersion}',
        UpdateUrgency.none || null => 'App is up to date',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint('Version check error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Version check failed')));
      }
    }
  }

  void _open(BuildContext context, String title, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeaturePage(title: title, child: page),
      ),
    );
  }

  void _openRefreshable<T extends State<StatefulWidget>>(
    BuildContext context,
    String title,
    StatefulWidget Function(GlobalKey<T> key) build,
  ) {
    final key = GlobalKey<T>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeaturePage(
          title: title,
          onRefresh: () async {
            final state = key.currentState;
            if (state is Refreshable) await (state as Refreshable).refresh();
          },
          child: build(key),
        ),
      ),
    );
  }

  List<_FeatureMenuGroup> _groups(BuildContext context) => [
    _FeatureMenuGroup('Device Integrity', [
      _FeatureMenuItem(
        title: 'Detection',
        subtitle: 'Root, jailbreak, hooking, and debugger checks',
        icon: Icons.security,
        open: (ctx) => _openRefreshable<DetectionSectionState>(
          ctx,
          'Detection',
          (key) => DetectionSection(key: key),
        ),
      ),
      _FeatureMenuItem(
        title: 'Android Posture',
        subtitle: 'Developer mode, accessibility, Play Protect, and more',
        icon: Icons.android,
        open: (ctx) => _openRefreshable<AndroidPostureSectionState>(
          ctx,
          'Android Posture',
          (key) => AndroidPostureSection(key: key),
        ),
      ),
    ]),
    _FeatureMenuGroup('Screenshot & Recording', [
      _FeatureMenuItem(
        title: 'Screenshot Overlay',
        subtitle: 'Block screenshots, blur/color/image live overlay',
        icon: Icons.blur_on,
        open: (ctx) =>
            _open(ctx, 'Screenshot Overlay', const ScreenshotOverlaySection()),
      ),
      _FeatureMenuItem(
        title: 'Screen Recording',
        subtitle: 'Live screen-recording session detection',
        icon: Icons.videocam_outlined,
        open: (ctx) =>
            _open(ctx, 'Screen Recording', const ScreenRecordingSection()),
      ),
      _FeatureMenuItem(
        title: 'Protection Actions',
        subtitle: 'Recents overlay, hide-in-recents, block obscured touches',
        icon: Icons.toggle_on_outlined,
        open: (ctx) => _open(ctx, 'Protection Actions', const ActionsSection()),
      ),
    ]),
    _FeatureMenuGroup('Live Signals', [
      _FeatureMenuItem(
        title: 'Live Streams',
        subtitle: 'VPN, screen capture, screenshots, call activity',
        icon: Icons.podcasts,
        open: (ctx) => _openRefreshable<StreamsSectionState>(
          ctx,
          'Live Streams',
          (key) => StreamsSection(
            key: key,
            idleTimeoutCount: widget.idleTimeoutCount,
          ),
        ),
      ),
      _FeatureMenuItem(
        title: 'Overlay & Clipboard',
        subtitle: 'Overlay-attack count and clipboard demo',
        icon: Icons.content_paste,
        open: (ctx) =>
            _open(ctx, 'Overlay & Clipboard', const OverlayClipboardSection()),
      ),
    ]),
    _FeatureMenuGroup('Network & Defenses', [
      _FeatureMenuItem(
        title: 'IOC Domain Check',
        subtitle: 'Check a host against your own blocklist',
        icon: Icons.public_off,
        open: (ctx) => _open(ctx, 'IOC Domain Check', const IocDomainSection()),
      ),
      _FeatureMenuItem(
        title: 'Banking Defenses',
        subtitle: 'Call-screening role settings shortcut',
        icon: Icons.account_balance_outlined,
        open: (ctx) =>
            _open(ctx, 'Banking Defenses', const BankingDefensesSection()),
      ),
      _FeatureMenuItem(
        title: 'Malware Check',
        subtitle: 'Check installed packages against a list you supply',
        icon: Icons.bug_report_outlined,
        open: (ctx) => _open(ctx, 'Malware Check', const MalwareCheckSection()),
      ),
    ]),
    _FeatureMenuGroup('Utilities', [
      _FeatureMenuItem(
        title: 'Risk Summary',
        subtitle: 'Aggregated, plain-language risk flags',
        icon: Icons.summarize_outlined,
        open: (ctx) => _open(ctx, 'Risk Summary', const RiskSummarySection()),
      ),
      _FeatureMenuItem(
        title: 'Danger Zone',
        subtitle: 'Destructive check-hooked demo actions',
        icon: Icons.warning_amber_outlined,
        open: (ctx) => _open(ctx, 'Danger Zone', const DangerZoneSection()),
      ),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final groups = _groups(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Safety Info'),
        actions: [
          IconButton(
            tooltip: 'Check for updates',
            onPressed: _checkAppVersion,
            icon: const Icon(Icons.system_update),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: groups.length,
          itemBuilder: (context, groupIndex) {
            final group = groups[groupIndex];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    groupIndex == 0 ? 20 : 24,
                    20,
                    8,
                  ),
                  child: Text(
                    group.label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                ...group.items.map(
                  (item) => Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        child: Icon(item.icon),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(item.subtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => item.open(context),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
