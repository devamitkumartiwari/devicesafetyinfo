import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../refreshable.dart';
import '../widgets/check_tile.dart';
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
      final results = await Future.wait([
        DeviceSafetyInfo.isRootedDevice,
        DeviceSafetyInfo.isScreenLock,
        DeviceSafetyInfo.isRealDevice,
        DeviceSafetyInfo.isInstalledFromStore,
        DeviceSafetyInfo.isHooked,
        DeviceSafetyInfo.isScreenCaptured,
        DeviceSafetyInfo.isDebuggerAttached,
      ]);

      if (!mounted) return;
      setState(() {
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
          subtitle: 'Root/jailbreak detected via native C + platform checks.',
        ),
        CheckTile(
          title: 'Real device (not emulator)',
          value: _isRealDevice,
          icon: Icons.phone_android,
          subtitle: 'Emulators are often used for tampering.',
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
