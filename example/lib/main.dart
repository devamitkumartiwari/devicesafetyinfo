import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import 'src/sections/actions_section.dart';
import 'src/sections/android_posture_section.dart';
import 'src/sections/banking_defenses_section.dart';
import 'src/sections/danger_zone_section.dart';
import 'src/sections/detection_section.dart';
import 'src/sections/ioc_domain_section.dart';
import 'src/sections/malware_check_section.dart';
import 'src/sections/overlay_clipboard_section.dart';
import 'src/sections/risk_summary_section.dart';
import 'src/sections/screen_recording_section.dart';
import 'src/sections/screenshot_overlay_section.dart';
import 'src/sections/streams_section.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Safety Info',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const DeviceSafetyHome(),
    );
  }
}

class DeviceSafetyHome extends StatefulWidget {
  const DeviceSafetyHome({super.key});
  @override
  State<DeviceSafetyHome> createState() => _DeviceSafetyHomeState();
}

class _DeviceSafetyHomeState extends State<DeviceSafetyHome> {
  final _detectionKey = GlobalKey<DetectionSectionState>();
  final _postureKey = GlobalKey<AndroidPostureSectionState>();
  final _streamsKey = GlobalKey<StreamsSectionState>();

  bool _loading = false;

  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await Future.wait([
        _detectionKey.currentState?.refresh() ?? Future.value(),
        _postureKey.currentState?.refresh() ?? Future.value(),
        _streamsKey.currentState?.refresh() ?? Future.value(),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkAppVersion() async {
    // minAppVersion is illustrative only — supply it from your own remote config, not the store.
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

  @override
  Widget build(BuildContext context) {
    return IdleTimeoutGuard(
      timeout: const Duration(seconds: 30),
      onTimeout: () => _streamsKey.currentState?.recordIdleTimeout(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Device Safety Info'),
          actions: [
            IconButton(
              tooltip: 'Version Check',
              onPressed: _checkAppVersion,
              icon: const Icon(Icons.system_update),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _refreshAll,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                DetectionSection(key: _detectionKey),
                AndroidPostureSection(key: _postureKey),
                StreamsSection(key: _streamsKey),
                const ActionsSection(),
                const ScreenshotOverlaySection(),
                const ScreenRecordingSection(),
                const OverlayClipboardSection(),
                const IocDomainSection(),
                const BankingDefensesSection(),
                const MalwareCheckSection(),
                const RiskSummarySection(),
                const DangerZoneSection(),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _loading ? null : _refreshAll,
          icon: const Icon(Icons.search),
          label: const Text('Re-check'),
        ),
      ),
    );
  }
}
