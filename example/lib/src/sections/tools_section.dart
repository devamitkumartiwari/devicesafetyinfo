import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/widgets.dart';

import '../ui/adaptive.dart';

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

  Widget _result(String? text, {Key? key}) => text == null
      ? const SizedBox.shrink()
      : SectionContent(child: Text(text, key: key));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveSection(
          header: 'IOC domain blocklist',
          footer:
              '${DeviceSafety.ioc.length} entries (set in DeviceSafetyConfig.iocBlocklist).',
          children: [
            SectionContent(
              child: AdaptiveTextField(
                key: const ValueKey('ioc_host'),
                controller: _host,
                label: 'Host',
              ),
            ),
            SectionContent(
              child: AdaptiveButton(
                key: const ValueKey('ioc_check'),
                label: 'Check host',
                onPressed: () => setState(
                  () => _iocResult = DeviceSafety.ioc.isBlocked(_host.text)
                      ? 'BLOCKED'
                      : 'allowed',
                ),
              ),
            ),
            _result(_iocResult, key: const ValueKey('ioc_result')),
          ],
        ),
        AdaptiveSection(
          header: 'Malware packages',
          footer:
              'Configured: ${DeviceSafety.config.malwarePackages.join(', ')}',
          children: [
            SectionContent(
              child: AdaptiveButton(
                key: const ValueKey('malware_scan'),
                label: 'Scan',
                onPressed: () => _guard((t) => _malware = t, () async {
                  final r = await DeviceSafety.malware.check(refresh: true);
                  return '${r.status.name}: ${r.signals.isEmpty ? 'none installed' : r.signals.map((s) => s.id).join(', ')}';
                }),
              ),
            ),
            _result(_malware),
          ],
        ),
        AdaptiveSection(
          header: 'Calls',
          children: [
            SectionContent(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AdaptiveButton(
                    label: 'Call active?',
                    onPressed: () => _guard(
                      (t) => _call = t,
                      () async =>
                          'Call active: ${await DeviceSafety.calls.isCallActive()}',
                    ),
                  ),
                  AdaptiveButton(
                    label: 'Screening role',
                    filled: false,
                    onPressed: () => _guard((t) => _call = t, () async {
                      final s = DeviceSafety.callScreening;
                      return 'Screening role available: ${await s.isRoleAvailable()}, held: ${await s.isRoleHeld()}';
                    }),
                  ),
                  AdaptiveButton(
                    label: 'Request role',
                    filled: false,
                    onPressed: () => _guard((t) => _call = t, () async {
                      await DeviceSafety.callScreening.requestRole();
                      return 'Role requested';
                    }),
                  ),
                ],
              ),
            ),
            _result(_call),
          ],
        ),
        AdaptiveSection(
          header: 'Version check',
          children: [
            SectionContent(
              child: AdaptiveButton(
                key: const ValueKey('version_check'),
                label: 'Check for updates',
                onPressed: () => _guard((t) => _version = t, () async {
                  final info = await DeviceSafety.versionCheck.appInfo();
                  final status = await DeviceSafety.versionCheck.status(
                    minAppVersion: '1.0.0',
                  );
                  return '${info.packageName} ${info.version} (${info.buildNumber}) · '
                      '${status == null ? 'store not reachable / app not published' : 'store ${status.storeVersion}, ${status.urgency.name}'}';
                }),
              ),
            ),
            _result(_version, key: const ValueKey('version_result')),
          ],
        ),
      ],
    );
  }
}
