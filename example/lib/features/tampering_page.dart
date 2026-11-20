import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';
import '../common/result_view.dart';

/// Tampering: detects a repackaged or re-signed copy of your app.
///
/// ```dart
/// // 1. Once, during development: print your signing certificate.
/// print((await DeviceSafety.tampering.signingInfo()).certificateSha256);
///
/// // 2. Put it in the config.
/// await DeviceSafety.initialize(DeviceSafetyConfig(
///   expectedSigningCertificates: {'ab12...'}, // Android
///   expectedIosTeamId: 'ABCDE12345',           // iOS
/// ));
///
/// // 3. Check.
/// if (await DeviceSafety.tampering.isDetected()) blockApp();
/// ```
class TamperingPage extends StatefulWidget {
  const TamperingPage({super.key});

  @override
  State<TamperingPage> createState() => _TamperingPageState();
}

class _TamperingPageState extends State<TamperingPage> {
  CheckResult? _result;
  SigningInfo? _info;

  @override
  void initState() {
    super.initState();
    DeviceSafety.tampering.check(refresh: true).then((r) {
      if (mounted) setState(() => _result = r);
    });
    DeviceSafety.tampering.signingInfo().then((i) {
      if (mounted) setState(() => _info = i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return DemoScaffold(
      title: 'Tampering',
      about:
          'Finds a copy of your app that someone changed and signed again, for example '
          'to add malware. You tell the package your real signing certificate first.',
      code: '''// 1. Print your certificate once:
print((await DeviceSafety.tampering.signingInfo()).certificateSha256);

// 2. Add it to the config:
await DeviceSafety.initialize(DeviceSafetyConfig(
  expectedSigningCertificates: {'ab12...'}, // Android
  expectedIosTeamId: 'ABCDE12345',           // iOS
));

// 3. Check:
if (await DeviceSafety.tampering.isDetected()) blockApp();''',
      children: [
        ResultView(_result),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('This build is signed with'),
            subtitle: SelectableText(
              info == null
                  ? '...'
                  : info.certificateSha256.isNotEmpty
                  ? info.certificateSha256.join('\n')
                  : 'Team id: ${info.teamId ?? 'none'}',
            ),
          ),
        ),
        const Text(
          'Run the example with --dart-define=EXPECTED_SIGNING_CERT=<value above> '
          'to see the check pass.',
        ),
      ],
    );
  }
}
