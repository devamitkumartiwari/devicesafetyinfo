import 'dart:convert';
import 'dart:io';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Certificate pinning: only talk to your real server, even if a proxy is trusted.
///
/// ```dart
/// // Once: get your server's pin.
/// print(await DeviceSafety.pinning.spkiPinOf(Uri.https('api.example.com')));
///
/// // Then use a pinned HttpClient.
/// final client = DeviceSafety.pinning.createHttpClient(PinningConfig({
///   'api.example.com': {'<pin>', '<backup pin>'},
/// }));
/// ```
class PinningPage extends StatefulWidget {
  const PinningPage({super.key});

  @override
  State<PinningPage> createState() => _PinningPageState();
}

class _PinningPageState extends State<PinningPage> with StatusMessage {
  final _host = TextEditingController(text: 'www.google.com');
  String? _pin;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  /// A pin that matches nothing, to show a blocked request.
  static final _wrongPin = base64.encode(List.filled(32, 2));

  Future<String> _request(String pin) async {
    final host = _host.text.trim();
    final client = DeviceSafety.pinning.createHttpClient(
      PinningConfig({
        host: {pin},
      }),
    );
    try {
      final response = await (await client.getUrl(Uri.https(host))).close();
      await response.drain<void>();
      return 'Allowed: HTTP ${response.statusCode}';
    } on PinningException catch (e) {
      return 'Blocked (pin did not match): $e';
    } on SocketException catch (e) {
      return 'Network error: ${e.message}';
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Certificate pinning',
      about:
          'Makes HTTPS requests only to a server with the key you expect. A proxy with '
          'an installed certificate can then no longer read your API traffic.',
      code: '''// Once: get your server's pin
print(await DeviceSafety.pinning.spkiPinOf(Uri.https('api.example.com')));

// Then make requests with a pinned client
final client = DeviceSafety.pinning.createHttpClient(PinningConfig({
  'api.example.com': {'<pin>', '<backup pin>'},
}));''',
      children: [
        TextField(
          key: const ValueKey('pin_host'),
          controller: _host,
          decoration: const InputDecoration(
            labelText: 'Host',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('pin_fetch'),
          child: const Text('1. Get the pin'),
          onPressed: () => run(() async {
            _pin = await DeviceSafety.pinning.spkiPinOf(
              Uri.https(_host.text.trim()),
            );
            return 'Pin: $_pin';
          }),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('pin_right'),
          child: const Text('2. Request with the right pin'),
          onPressed: () => run(() async {
            if (_pin == null) return 'Tap "Get the pin" first';
            return _request(_pin!);
          }),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('pin_wrong'),
          child: const Text('3. Request with a wrong pin'),
          onPressed: () => run(() => _request(_wrongPin)),
        ),
        statusText(),
      ],
    );
  }
}
