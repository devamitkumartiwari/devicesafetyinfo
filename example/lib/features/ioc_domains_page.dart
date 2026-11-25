import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Blocked domains (IOC list): refuse to open known phishing or malware hosts.
///
/// ```dart
/// await DeviceSafety.initialize(DeviceSafetyConfig(
///   iocBlocklist: {'evil.example', '*.phishing.example'},
/// ));
///
/// if (DeviceSafety.ioc.isBlocked(uri.host)) return; // don't open it
/// ```
class IocDomainsPage extends StatefulWidget {
  const IocDomainsPage({super.key});

  @override
  State<IocDomainsPage> createState() => _IocDomainsPageState();
}

class _IocDomainsPageState extends State<IocDomainsPage> {
  final _host = TextEditingController(text: 'login.phishing.example');
  String? _result;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Blocked domains',
      about:
          'Keep a list of bad domains (phishing, malware servers) and check a link '
          'before opening it. Wildcards like *.phishing.example work.',
      code: '''await DeviceSafety.initialize(DeviceSafetyConfig(
  iocBlocklist: {'evil.example', '*.phishing.example'},
));

if (DeviceSafety.ioc.isBlocked(uri.host)) return; // don't open it''',
      children: [
        Text('This example blocks: malicious.example, *.phishing.example'),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('ioc_host'),
          controller: _host,
          decoration: const InputDecoration(
            labelText: 'Host',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('ioc_check'),
          child: const Text('Check host'),
          onPressed: () => setState(
            () => _result = DeviceSafety.ioc.isBlocked(_host.text.trim())
                ? 'BLOCKED'
                : 'allowed',
          ),
        ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _result!,
              key: const ValueKey('ioc_result'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
      ],
    );
  }
}
