import 'package:material_ui/material_ui.dart';

import 'features/accessibility_page.dart';
import 'features/app_cloning_page.dart';
import 'features/app_integrity_page.dart';
import 'features/app_switcher_page.dart';
import 'features/biometric_page.dart';
import 'features/calls_page.dart';
import 'features/clipboard_page.dart';
import 'features/debugger_page.dart';
import 'features/device_key_page.dart';
import 'features/emulator_page.dart';
import 'features/gps_spoofing_page.dart';
import 'features/hooking_page.dart';
import 'features/idle_timeout_page.dart';
import 'features/ioc_domains_page.dart';
import 'features/keyboard_page.dart';
import 'features/malware_page.dart';
import 'features/mitm_page.dart';
import 'features/notification_listeners_page.dart';
import 'features/pinning_page.dart';
import 'features/posture_page.dart';
import 'features/quick_check_page.dart';
import 'features/remote_access_page.dart';
import 'features/root_page.dart';
import 'features/screenshot_page.dart';
import 'features/secure_text_field_page.dart';
import 'features/settings_page.dart';
import 'features/tampering_page.dart';
import 'features/tapjacking_page.dart';
import 'features/threats_page.dart';
import 'features/version_check_page.dart';
import 'features/vpn_page.dart';

/// One demo: its key id, title, one-line subtitle, icon and page.
typedef Demo = ({
  String id,
  String title,
  String subtitle,
  IconData icon,
  Widget page,
});

/// Every demo, grouped like the README.
const Map<String, List<Demo>> demos = {
  'Start here': [
    (
      id: 'quick_check',
      title: 'Quick check',
      subtitle: 'Run every check in one call',
      icon: Icons.bolt,
      page: QuickCheckPage(),
    ),
  ],
  'Device checks': [
    (
      id: 'root',
      title: 'Root / jailbreak',
      subtitle: 'Rooted Android or jailbroken iPhone',
      icon: Icons.lock_open,
      page: RootPage(),
    ),
    (
      id: 'emulator',
      title: 'Emulator / simulator',
      subtitle: 'Not a real phone',
      icon: Icons.computer,
      page: EmulatorPage(),
    ),
    (
      id: 'hooking',
      title: 'Hooking (Frida, Xposed)',
      subtitle: 'Tools that change the app while it runs',
      icon: Icons.phishing,
      page: HookingPage(),
    ),
    (
      id: 'debugger',
      title: 'Debugger',
      subtitle: 'A debugger is attached',
      icon: Icons.bug_report,
      page: DebuggerPage(),
    ),
    (
      id: 'tampering',
      title: 'Tampering',
      subtitle: 'A re-signed copy of your app',
      icon: Icons.content_copy,
      page: TamperingPage(),
    ),
    (
      id: 'posture',
      title: 'Device posture',
      subtitle: 'Screen lock, developer mode, sideloading',
      icon: Icons.phone_android,
      page: PosturePage(),
    ),
    (
      id: 'accessibility',
      title: 'Accessibility services',
      subtitle: 'Apps that can read and tap the screen',
      icon: Icons.accessibility_new,
      page: AccessibilityPage(),
    ),
    (
      id: 'notification_listeners',
      title: 'Notification listeners',
      subtitle: 'Apps that can read your SMS codes',
      icon: Icons.notifications,
      page: NotificationListenersPage(),
    ),
    (
      id: 'vpn',
      title: 'VPN / proxy',
      subtitle: 'Traffic goes through a VPN or proxy',
      icon: Icons.vpn_lock,
      page: VpnPage(),
    ),
    (
      id: 'malware',
      title: 'Malware apps',
      subtitle: 'Known bad apps installed',
      icon: Icons.coronavirus,
      page: MalwarePage(),
    ),
  ],
  'Fraud signals': [
    (
      id: 'remote_access',
      title: 'Remote access apps',
      subtitle: 'AnyDesk, TeamViewer... used in scams',
      icon: Icons.screen_share,
      page: RemoteAccessPage(),
    ),
    (
      id: 'gps_spoofing',
      title: 'GPS spoofing',
      subtitle: 'Fake location',
      icon: Icons.location_off,
      page: GpsSpoofingPage(),
    ),
    (
      id: 'app_cloning',
      title: 'App cloning',
      subtitle: 'Running in a cloned or dual-app space',
      icon: Icons.copy_all,
      page: AppCloningPage(),
    ),
    (
      id: 'mitm',
      title: 'HTTPS interception',
      subtitle: 'User-installed certificates',
      icon: Icons.http,
      page: MitmPage(),
    ),
    (
      id: 'keyboard',
      title: 'Third-party keyboard',
      subtitle: 'A keyboard that could log typing',
      icon: Icons.keyboard,
      page: KeyboardPage(),
    ),
  ],
  'Protect your screens': [
    (
      id: 'screenshot',
      title: 'Screenshots & recording',
      subtitle: 'Block screenshots, blur while recorded',
      icon: Icons.screenshot_monitor,
      page: ScreenshotPage(),
    ),
    (
      id: 'app_switcher',
      title: 'App switcher',
      subtitle: 'Hide the app in recent apps',
      icon: Icons.layers,
      page: AppSwitcherPage(),
    ),
    (
      id: 'clipboard',
      title: 'Secure clipboard',
      subtitle: 'Copy codes that clear themselves',
      icon: Icons.content_paste,
      page: ClipboardPage(),
    ),
    (
      id: 'tapjacking',
      title: 'Tapjacking',
      subtitle: 'Ignore taps while another app covers yours',
      icon: Icons.touch_app,
      page: TapjackingPage(),
    ),
    (
      id: 'idle_timeout',
      title: 'Idle timeout',
      subtitle: 'Log out after inactivity',
      icon: Icons.timer,
      page: IdleTimeoutPage(),
    ),
    (
      id: 'secure_text_field',
      title: 'Secure text fields',
      subtitle: 'PIN and password fields',
      icon: Icons.password,
      page: SecureTextFieldPage(),
    ),
  ],
  'Prove device & user': [
    (
      id: 'pinning',
      title: 'Certificate pinning',
      subtitle: 'Only talk to your real server',
      icon: Icons.https,
      page: PinningPage(),
    ),
    (
      id: 'device_key',
      title: 'Device-bound key',
      subtitle: 'Sign requests with a hardware key',
      icon: Icons.key,
      page: DeviceKeyPage(),
    ),
    (
      id: 'biometric',
      title: 'Biometric approval',
      subtitle: 'Approve payments with a fingerprint',
      icon: Icons.fingerprint,
      page: BiometricPage(),
    ),
    (
      id: 'app_integrity',
      title: 'App integrity',
      subtitle: 'Play Integrity, App Attest, DeviceCheck',
      icon: Icons.verified,
      page: AppIntegrityPage(),
    ),
  ],
  'Live events & tools': [
    (
      id: 'threats',
      title: 'Live threats',
      subtitle: 'Screenshots, recording, VPN as they happen',
      icon: Icons.sensors,
      page: ThreatsPage(),
    ),
    (
      id: 'ioc_domains',
      title: 'Blocked domains',
      subtitle: 'Refuse known phishing hosts',
      icon: Icons.dangerous,
      page: IocDomainsPage(),
    ),
    (
      id: 'calls',
      title: 'Phone calls',
      subtitle: 'Warn during calls (scam protection)',
      icon: Icons.call,
      page: CallsPage(),
    ),
    (
      id: 'version_check',
      title: 'Version check',
      subtitle: 'Is a newer version in the store?',
      icon: Icons.system_update,
      page: VersionCheckPage(),
    ),
  ],
  'Settings': [
    (
      id: 'settings',
      title: 'Policy',
      subtitle: 'Choose how strict each check is',
      icon: Icons.tune,
      page: SettingsPage(),
    ),
  ],
};

/// The list of demos.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Safety Info')),
      body: ListView(
        children: [
          for (final MapEntry(key: group, value: items) in demos.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                group,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            for (final demo in items)
              ListTile(
                key: ValueKey('menu_${demo.id}'),
                leading: Icon(demo.icon),
                title: Text(demo.title),
                subtitle: Text(demo.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => demo.page)),
              ),
          ],
        ],
      ),
    );
  }
}
