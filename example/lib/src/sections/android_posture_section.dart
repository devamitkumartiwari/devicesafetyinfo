import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../platform_support.dart';
import '../refreshable.dart';
import '../widgets/check_tile.dart';
import '../widgets/stream_tile.dart';

/// Android-only device-posture checks: dev-mode, external-storage, accessibility,
/// Play Protect, notification-listener, unknown-sources, and call-screening rows.
///
/// Renders nothing on iOS.
class AndroidPostureSection extends StatefulWidget {
  const AndroidPostureSection({super.key});

  @override
  State<AndroidPostureSection> createState() => AndroidPostureSectionState();
}

class AndroidPostureSectionState extends State<AndroidPostureSection>
    implements Refreshable {
  bool? _isExternalStorage;
  bool? _isDeveloperMode;
  bool? _isAnyAccessibilityServiceEnabled;
  PlayProtectStatus? _playProtectStatus;
  bool? _isAnyNotificationListenerEnabled;
  bool? _isUnknownSourcesEnabled;
  bool? _isCallScreeningRoleAvailable;
  bool? _isCallScreeningRoleHeldByThisApp;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  Future<void> refresh() async {
    if (!isAndroidPlatform || !mounted) return;
    try {
      final results = await Future.wait([
        DeviceSafetyInfo.isExternalStorage,
        DeviceSafetyInfo.isDeveloperMode,
      ]);
      if (!mounted) return;
      setState(() {
        _isExternalStorage = results[0];
        _isDeveloperMode = results[1];
      });

      final anyAccessibility =
          await DeviceSafetyInfo.isAnyAccessibilityServiceEnabled;
      final protectStatus = await DeviceSafetyInfo.playProtectStatus;
      final anyNotificationListener =
          await DeviceSafetyInfo.isAnyNotificationListenerEnabled;
      final unknownSources = await DeviceSafetyInfo.isUnknownSourcesEnabled;
      final roleAvailable = await DeviceSafetyInfo.isCallScreeningRoleAvailable;
      final roleHeld = await DeviceSafetyInfo.isCallScreeningRoleHeldByThisApp;
      if (!mounted) return;
      setState(() {
        _isAnyAccessibilityServiceEnabled = anyAccessibility;
        _playProtectStatus = protectStatus;
        _isAnyNotificationListenerEnabled = anyNotificationListener;
        _isUnknownSourcesEnabled = unknownSources;
        _isCallScreeningRoleAvailable = roleAvailable;
        _isCallScreeningRoleHeldByThisApp = roleHeld;
      });
    } catch (e) {
      debugPrint('Error refreshing Android posture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AndroidOnly(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckTile(
            title: 'Developer mode enabled',
            value: _isDeveloperMode,
            icon: Icons.developer_mode,
            subtitle: 'Android-only. Developer options expose debug surfaces.',
          ),
          CheckTile(
            title: 'App on external storage',
            value: _isExternalStorage,
            icon: Icons.sd_storage,
            subtitle: 'Android-only. External storage can be tampered with.',
          ),
          CheckTile(
            title: 'Accessibility service enabled',
            value: _isAnyAccessibilityServiceEnabled,
            icon: Icons.accessibility_new,
            subtitle: 'Android-only. A common abuse vector for screen-reading malware.',
          ),
          StreamTile(
            title: 'Play Protect status',
            value: switch (_playProtectStatus) {
              PlayProtectStatus.enabled => 'Enabled',
              PlayProtectStatus.disabled => 'Disabled',
              _ => 'Unknown',
            },
            icon: Icons.shield_outlined,
            color: _playProtectStatus == PlayProtectStatus.disabled
                ? Colors.red
                : Colors.green,
            subtitle: 'Android-only. Reads the underlying OS setting directly.',
          ),
          CheckTile(
            title: 'Notification listener enabled',
            value: _isAnyNotificationListenerEnabled,
            icon: Icons.notifications_active_outlined,
            subtitle: 'Android-only. Banking trojans commonly abuse this to steal OTP/SMS notifications.',
          ),
          CheckTile(
            title: 'Sideloading permitted (this app)',
            value: _isUnknownSourcesEnabled,
            icon: Icons.system_security_update_warning,
            subtitle:
                'Android-only. Only answers "can THIS app sideload" — '
                'cannot detect whether some other app has that right. See doc comment.',
          ),
          CheckTile(
            title: 'Call-screening role available',
            value: _isCallScreeningRoleAvailable,
            icon: Icons.phone_callback_outlined,
            subtitle: 'Android-only, API 29+. Device capability only.',
          ),
          CheckTile(
            title: 'Call-screening role held by this app',
            value: _isCallScreeningRoleHeldByThisApp,
            icon: Icons.phone_in_talk_outlined,
            subtitle:
                'Cannot detect a malicious app holding it instead — '
                'see "Open Call-Screening Settings" below.',
          ),
        ],
      ),
    );
  }
}
