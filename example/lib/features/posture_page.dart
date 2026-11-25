import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';
import '../common/result_view.dart';

/// Device posture: weak settings that make the phone easier to attack.
///
/// ```dart
/// if (await DeviceSafety.posture.screenLock.isDetected()) {
///   showMessage('Please set a screen lock');
/// }
/// ```
class PosturePage extends StatefulWidget {
  const PosturePage({super.key});

  @override
  State<PosturePage> createState() => _PosturePageState();
}

class _PosturePageState extends State<PosturePage> {
  // Each check: a plain name and the call.
  static final _checks = <String, DetectionApi>{
    'No screen lock': DeviceSafety.posture.screenLock,
    'Developer mode on': DeviceSafety.posture.developerMode,
    'Not installed from a store': DeviceSafety.posture.storeInstall,
    'Can install unknown apps': DeviceSafety.posture.unknownSources,
    'Play Protect off': DeviceSafety.posture.playProtect,
    'Installed on external storage': DeviceSafety.posture.externalStorage,
  };

  final _results = <String, CheckResult>{};

  @override
  void initState() {
    super.initState();
    for (final MapEntry(:key, :value) in _checks.entries) {
      value.check(refresh: true).then((r) {
        if (mounted) setState(() => _results[key] = r);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Device posture',
      about:
          'Weak phone settings: no screen lock, developer mode, a sideloaded app, '
          'Play Protect off. Each one is "detected" when the phone is in the risky state.',
      platforms: 'Screen lock and store install on both; the rest Android only',
      code:
          '''final noLock = await DeviceSafety.posture.screenLock.isDetected();
if (noLock) showMessage('Please set a screen lock');''',
      children: [
        for (final name in _checks.keys) ...[
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          ResultView(_results[name]),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
