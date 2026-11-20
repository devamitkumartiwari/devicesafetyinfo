// Patrol tests: every detection check answers through the real native code (no fakes).
//
// Expected environment: a normal (not rooted, no Frida) device or emulator.
import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

const _ok = {CheckStatus.completed, CheckStatus.unsupported};

void main() {
  final checks = <String, DetectionApi Function()>{
    'root': () => DeviceSafety.root,
    'emulator': () => DeviceSafety.emulator,
    'hooking': () => DeviceSafety.hooking,
    'debugger': () => DeviceSafety.debugger,
    'developerMode': () => DeviceSafety.posture.developerMode,
    'screenLock': () => DeviceSafety.posture.screenLock,
    'storeInstall': () => DeviceSafety.posture.storeInstall,
    'externalStorage': () => DeviceSafety.posture.externalStorage,
    'unknownSources': () => DeviceSafety.posture.unknownSources,
    'playProtect': () => DeviceSafety.posture.playProtect,
    'accessibility': () => DeviceSafety.accessibility,
    'notificationListeners': () => DeviceSafety.notificationListeners,
    'vpn': () => DeviceSafety.vpn,
    'screenCapture': () => DeviceSafety.screen,
    'malware': () => DeviceSafety.malware,
  };

  for (final MapEntry(:key, :value) in checks.entries) {
    patrolTest('$key answers without error', ($) async {
      await $.pumpWidgetAndSettle(const ExampleApp());
      final r = await value().check(refresh: true);
      expect(_ok, contains(r.status), reason: '$r');
    });
  }

  patrolTest('clean device: not rooted or hooked', ($) async {
    await $.pumpWidgetAndSettle(const ExampleApp());
    expect(await DeviceSafety.root.isDetected(), isFalse);
    expect(await DeviceSafety.hooking.isDetected(), isFalse);
  });

  patrolTest('assess() answers every check and the Quick check page shows it', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const ExampleApp());
    final a = await DeviceSafety.assess(refresh: true);
    expect(a.failed, isEmpty);
    await $(#menu_quick_check).tap();
    await $.pumpAndSettle();
    expect($(#assessment_summary), findsOneWidget);
  });

  patrolTest('strict policy is applied from the Policy page', ($) async {
    await $.pumpWidgetAndSettle(const ExampleApp());
    await $(#menu_settings).scrollTo().tap();
    await $.pumpAndSettle();
    expect($(#policy_root), findsOneWidget);
    await DeviceSafety.initialize(
      DeviceSafetyConfig(policies: {CheckType.root: RiskPolicy.off}),
    );
    expect((await DeviceSafety.root.check()).status, CheckStatus.skipped);
    await DeviceSafety.initialize();
  });
}
