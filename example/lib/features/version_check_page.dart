import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// App version and store update check.
///
/// ```dart
/// final info = await DeviceSafety.versionCheck.appInfo();
/// final status = await DeviceSafety.versionCheck.status(minAppVersion: '2.0.0');
/// if (status != null) print('Store has ${status.storeVersion} (${status.urgency.name})');
/// ```
class VersionCheckPage extends StatefulWidget {
  const VersionCheckPage({super.key});

  @override
  State<VersionCheckPage> createState() => _VersionCheckPageState();
}

class _VersionCheckPageState extends State<VersionCheckPage> {
  String? _result;

  Future<void> _check() async {
    String text;
    try {
      final info = await DeviceSafety.versionCheck.appInfo();
      final status = await DeviceSafety.versionCheck.status(
        minAppVersion: '1.0.0',
      );
      text =
          'This app: ${info.packageName} ${info.version} (${info.buildNumber})\n'
          '${status == null ? 'Store: not found (app not published?)' : 'Store: ${status.storeVersion}, update ${status.urgency.name}'}';
    } on DeviceSafetyException catch (e) {
      text = 'Error: $e';
    }
    if (mounted) setState(() => _result = text);
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Version check',
      about:
          'Reads your app\'s version and compares it with the store, so you can ask '
          'users on old, insecure versions to update.',
      code: '''final info = await DeviceSafety.versionCheck.appInfo();
final status = await DeviceSafety.versionCheck.status(minAppVersion: '2.0.0');
if (status != null) {
  print('Store has \${status.storeVersion} (\${status.urgency.name})');
}''',
      children: [
        FilledButton(
          key: const ValueKey('version_check'),
          onPressed: _check,
          child: const Text('Check for updates'),
        ),
        if (_result != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_result!, key: const ValueKey('version_result')),
            ),
          ),
      ],
    );
  }
}
