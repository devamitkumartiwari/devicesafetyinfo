import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Device-bound keys: a signing key that never leaves the phone's secure hardware.
///
/// ```dart
/// final key = await DeviceSafety.deviceKey.create('session', challenge: serverChallenge);
/// // send key.publicKey (and key.attestationChain) to your server once
///
/// final signature = await DeviceSafety.deviceKey.sign('session', requestBytes);
/// // send the signature with each request; the server verifies it
/// ```
class DeviceKeyPage extends StatefulWidget {
  const DeviceKeyPage({super.key});

  @override
  State<DeviceKeyPage> createState() => _DeviceKeyPageState();
}

class _DeviceKeyPageState extends State<DeviceKeyPage> with StatusMessage {
  static const _alias = 'example.device';

  /// Random bytes; in a real app the server sends the challenge.
  static Uint8List _random() {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => r.nextInt(256)));
  }

  static String _short(List<int> bytes) =>
      '${base64.encode(bytes).substring(0, 20)}...';

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Device-bound key',
      about:
          'Creates a key inside the phone\'s secure chip. It can sign requests but can '
          'never be copied, so your server knows a request came from this phone.',
      code: '''// Once: create the key and register the public key with your server
final key = await DeviceSafety.deviceKey.create('session', challenge: challenge);

// Each request: sign it
final signature = await DeviceSafety.deviceKey.sign('session', requestBytes);''',
      children: [
        FilledButton(
          key: const ValueKey('device_key_create'),
          child: const Text('1. Create key'),
          onPressed: () => run(() async {
            final key = await DeviceSafety.deviceKey.create(
              _alias,
              challenge: _random(),
            );
            return 'Created in ${key.securityLevel.name}. '
                'Public key: ${_short(key.publicKey)}';
          }),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('device_key_sign'),
          child: const Text('2. Sign some data'),
          onPressed: () => run(() async {
            final signature = await DeviceSafety.deviceKey.sign(
              _alias,
              _random(),
            );
            return 'Signature (${signature.length} bytes): ${_short(signature)}';
          }),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          child: const Text('Delete key'),
          onPressed: () => run(() async {
            await DeviceSafety.deviceKey.delete(_alias);
            return 'Deleted';
          }),
        ),
        statusText(),
      ],
    );
  }
}
