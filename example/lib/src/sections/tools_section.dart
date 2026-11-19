import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/demo_card.dart';
import '../widgets/section_header.dart';

/// IOC domains, malware packages, calls, call screening and version check.
class ToolsSection extends StatefulWidget {
  const ToolsSection({super.key});

  @override
  State<ToolsSection> createState() => _ToolsSectionState();
}

class _ToolsSectionState extends State<ToolsSection> {
  final _host = TextEditingController(text: 'login.phishing.example');
  String? _iocResult;
  String? _malware;
  String? _call;
  String? _version;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _guard(
    void Function(String) set,
    Future<String> Function() f,
  ) async {
    String text;
    try {
      text = await f();
    } on DeviceSafetyException catch (e) {
      text = e.toString();
    }
    if (mounted) setState(() => set(text));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionHeader(context, 'IOC domain blocklist'),
        DemoCard(
          children: [
            Text(
              '${DeviceSafety.ioc.length} entries (set in DeviceSafetyConfig.iocBlocklist)',
            ),
            TextField(
              key: const ValueKey('ioc_host'),
              controller: _host,
              decoration: const InputDecoration(labelText: 'Host'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('ioc_check'),
              onPressed: () => setState(
                () => _iocResult = DeviceSafety.ioc.isBlocked(_host.text)
                    ? 'BLOCKED'
                    : 'allowed',
              ),
              child: const Text('Check host'),
            ),
            if (_iocResult != null)
              Text(_iocResult!, key: const ValueKey('ioc_result')),
          ],
        ),
        sectionHeader(context, 'Malware packages'),
        DemoCard(
          children: [
            Text(
              'Configured: ${DeviceSafety.config.malwarePackages.join(', ')}',
            ),
            FilledButton(
              onPressed: () => _guard((t) => _malware = t, () async {
                final r = await DeviceSafety.malware.check(refresh: true);
                return '${r.status.name}: ${r.signals.isEmpty ? 'none installed' : r.signals.map((s) => s.id).join(', ')}';
              }),
              child: const Text('Scan'),
            ),
            if (_malware != null) Text(_malware!),
          ],
        ),
        sectionHeader(context, 'Calls'),
        DemoCard(
          children: [
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _guard(
                    (t) => _call = t,
                    () async =>
                        'Call active: ${await DeviceSafety.calls.isCallActive()}',
                  ),
                  child: const Text('Call active?'),
                ),
                OutlinedButton(
                  onPressed: () => _guard((t) => _call = t, () async {
                    final s = DeviceSafety.callScreening;
                    return 'Screening role available: ${await s.isRoleAvailable()}, held: ${await s.isRoleHeld()}';
                  }),
                  child: const Text('Screening role'),
                ),
                OutlinedButton(
                  onPressed: () => _guard((t) => _call = t, () async {
                    await DeviceSafety.callScreening.requestRole();
                    return 'Role requested';
                  }),
                  child: const Text('Request role'),
                ),
              ],
            ),
            if (_call != null) Text(_call!),
          ],
        ),
        sectionHeader(context, 'Version check'),
        DemoCard(
          children: [
            FilledButton(
              key: const ValueKey('version_check'),
              onPressed: () => _guard((t) => _version = t, () async {
                final info = await DeviceSafety.versionCheck.appInfo();
                final status = await DeviceSafety.versionCheck.status(
                  minAppVersion: '1.0.0',
                );
                return '${info.packageName} ${info.version} (${info.buildNumber}) · '
                    '${status == null ? 'store not reachable / app not published' : 'store ${status.storeVersion}, ${status.urgency.name}'}';
              }),
              child: const Text('Check for updates'),
            ),
            if (_version != null)
              Text(_version!, key: const ValueKey('version_result')),
          ],
        ),
      ],
    );
  }
}
