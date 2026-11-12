import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../refreshable.dart';
import '../widgets/check_tile.dart';
import '../widgets/risk_check_tile.dart';
import '../widgets/switch_tile.dart';
import '../widgets/section_header.dart';

/// Core rooted/real-device/screen-lock/store/hooked/debugger/screen-captured checks —
/// available on both platforms.
class DetectionSection extends StatefulWidget {
  const DetectionSection({super.key});

  @override
  State<DetectionSection> createState() => DetectionSectionState();
}

class DetectionSectionState extends State<DetectionSection>
    implements Refreshable {
  bool? _isRootedDevice;
  RiskCheckResult? _rootCheck;
  RiskPolicy _policy = RiskPolicy.standard;
  bool? _isRootedForPolicy;
  RiskCheckResult? _emulatorCheck;
  bool? _isEmulatorForPolicy;
  bool? _isScreenLock;
  bool? _isRealDevice;
  bool? _isInstalledFromStore;
  bool? _isHooked;
  bool? _isDebuggerAttached;
  bool? _isScreenCaptured;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  Future<void> refresh() async {
    if (!mounted) return;
    try {
      final rootCheckFuture = DeviceSafetyInfo.rootCheck;
      final isRootedFuture = DeviceSafetyInfo.isRooted(policy: _policy);
      final emulatorCheckFuture = DeviceSafetyInfo.emulatorCheck;
      final isEmulatorFuture = DeviceSafetyInfo.isEmulator(policy: _policy);
      final results = await Future.wait([
        DeviceSafetyInfo.isRootedDevice,
        DeviceSafetyInfo.isScreenLock,
        DeviceSafetyInfo.isRealDevice,
        DeviceSafetyInfo.isInstalledFromStore,
        DeviceSafetyInfo.isHooked,
        DeviceSafetyInfo.isScreenCaptured,
        DeviceSafetyInfo.isDebuggerAttached,
      ]);
      final rootCheck = await rootCheckFuture;
      final isRootedForPolicy = await isRootedFuture;
      final emulatorCheck = await emulatorCheckFuture;
      final isEmulatorForPolicy = await isEmulatorFuture;
      debugPrint('rootCheck: $rootCheck');
      debugPrint('emulatorCheck: $emulatorCheck');

      if (!mounted) return;
      setState(() {
        _rootCheck = rootCheck;
        _isRootedForPolicy = isRootedForPolicy;
        _emulatorCheck = emulatorCheck;
        _isEmulatorForPolicy = isEmulatorForPolicy;
        _isRootedDevice = results[0];
        _isScreenLock = results[1];
        _isRealDevice = results[2];
        _isInstalledFromStore = results[3];
        _isHooked = results[4];
        _isScreenCaptured = results[5];
        _isDebuggerAttached = results[6];
      });
    } catch (e) {
      debugPrint('Error refreshing detection: $e');
    }
  }

  Future<void> _setPolicy(RiskPolicy policy) async {
    setState(() {
      _policy = policy;
      _isRootedForPolicy = null;
      _isEmulatorForPolicy = null;
    });
    final rooted = await DeviceSafetyInfo.isRooted(policy: policy);
    final emulator = await DeviceSafetyInfo.isEmulator(policy: policy);
    if (!mounted || policy != _policy) return;
    setState(() {
      _isRootedForPolicy = rooted;
      _isEmulatorForPolicy = emulator;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(context, 'Detection'),
        CheckTile(
          title: 'Device is rooted / jailbroken',
          value: _isRootedDevice,
          icon: Icons.security,
          subtitle: 'High-risk root/jailbreak indicators only (native C + platform checks).',
        ),
        RiskCheckTile(
          title: 'Root risk level',
          result: _rootCheck,
          lowExamples: 'stock busybox, unlocked bootloader, …',
          highDescription: 'Strong root/jailbreak indicators',
        ),
        RiskCheckTile(
          title: 'Emulator risk level',
          result: _emulatorCheck,
          lowExamples: '"unknown" / "generic" / "nox" in a build field',
          highDescription: 'Clear emulator/simulator evidence',
        ),
        SwitchTile(
          title: 'Strict policy (root + emulator)',
          value: _policy == RiskPolicy.strict,
          onChanged: (on) =>
              _setPolicy(on ? RiskPolicy.strict : RiskPolicy.standard),
          icon: Icons.tune,
          subtitle: _policy == RiskPolicy.strict
              ? 'RiskPolicy.strict — high-risk AND low-risk signals count '
                    '(busybox, unlocked bootloader, "unknown" build fields, …).'
              : 'RiskPolicy.standard — only clear evidence counts '
                    '(working su, Magisk, emulator hardware, qemu, …).',
        ),
        CheckTile(
          title: 'Rooted (selected policy)',
          value: _isRootedForPolicy,
          icon: Icons.policy,
          subtitle:
              'DeviceSafetyInfo.isRooted(policy: RiskPolicy.${_policy.name})',
        ),
        CheckTile(
          title: 'Emulator (selected policy)',
          value: _isEmulatorForPolicy,
          icon: Icons.policy,
          subtitle:
              'DeviceSafetyInfo.isEmulator(policy: RiskPolicy.${_policy.name})',
        ),
        CheckTile(
          title: 'Real device (not emulator)',
          value: _isRealDevice,
          icon: Icons.phone_android,
          subtitle: 'High-risk emulator indicators only (emulator hardware, qemu, SDK builds).',
        ),
        CheckTile(
          title: 'Screen lock enabled',
          value: _isScreenLock,
          icon: Icons.lock,
          subtitle: 'Secure lockscreen is recommended.',
        ),
        CheckTile(
          title: 'Installed from store',
          value: _isInstalledFromStore,
          icon: Icons.storefront,
          subtitle: 'Sideloaded apps skip store security checks.',
        ),
        CheckTile(
          title: 'Hooking framework detected',
          value: _isHooked,
          icon: Icons.bug_report,
          subtitle: 'Frida / Xposed / Substrate detected via FFI + platform.',
        ),
        CheckTile(
          title: 'Debugger attached',
          value: _isDebuggerAttached,
          icon: Icons.adb,
          subtitle:
              'TracerPid (Android) / sysctl P_TRACED (iOS) + platform check.',
        ),
        CheckTile(
          title: 'Screen is being captured',
          value: _isScreenCaptured,
          icon: Icons.cast,
          subtitle: 'Screen recording or mirroring active.',
        ),
      ],
    );
  }
}
