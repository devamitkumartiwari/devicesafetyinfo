import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Your Google Cloud project number (Play Console → App integrity).
/// `flutter run --dart-define=PLAY_CLOUD_PROJECT_NUMBER=123456789012`
const _cloudProjectNumber = int.fromEnvironment('PLAY_CLOUD_PROJECT_NUMBER');

/// Optional: the sample server in example/server_dotnet, e.g. `http://192.168.1.10:5080`.
/// Without it the page only shows the token.
const _serverUrl = String.fromEnvironment('INTEGRITY_SERVER_URL');

/// App integrity: Google Play Integrity (Android), App Attest and DeviceCheck (iOS).
///
/// ```dart
/// // Android
/// await DeviceSafety.integrity.preparePlayIntegrity(cloudProjectNumber: 123456789012);
/// final token = await DeviceSafety.integrity.requestPlayIntegrityToken(requestHash: challenge);
///
/// // iOS
/// final token = await DeviceSafety.integrity.generateDeviceCheckToken();
///
/// // Send the token to YOUR server. Only the server can verify it.
/// ```
class AppIntegrityPage extends StatefulWidget {
  const AppIntegrityPage({super.key});

  @override
  State<AppIntegrityPage> createState() => _AppIntegrityPageState();
}

class _AppIntegrityPageState extends State<AppIntegrityPage>
    with StatusMessage {
  String? _appAttestKeyId; // a real app stores this

  /// A one-time challenge: from the server if set, otherwise random.
  Future<String> _challenge() async {
    if (_serverUrl.isEmpty) {
      final bytes = List.generate(32, (_) => Random.secure().nextInt(256));
      return base64Url.encode(bytes).replaceAll('=', '');
    }
    return (await _send('GET', '/challenge'))['challenge'] as String;
  }

  /// Sends the token to the sample server and returns its answer.
  Future<String> _verify(String path, Map<String, Object?> body) async {
    if (_serverUrl.isEmpty) return '(no INTEGRITY_SERVER_URL: not verified)';
    return 'Server says: ${jsonEncode(await _send('POST', path, body))}';
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, Uri.parse('$_serverUrl$path'));
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode >= 400) throw HttpException('HTTP ${res.statusCode}');
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  static String _short(String token) =>
      '${token.length} chars: ${token.substring(0, min(20, token.length))}...';

  Future<String> _playIntegrity() async {
    if (_cloudProjectNumber == 0) {
      return 'Run with --dart-define=PLAY_CLOUD_PROJECT_NUMBER=<your number>';
    }
    await DeviceSafety.integrity.preparePlayIntegrity(
      cloudProjectNumber: _cloudProjectNumber,
    );
    final challenge = await _challenge();
    final token = await DeviceSafety.integrity.requestPlayIntegrityToken(
      requestHash: challenge,
    );
    final verdict = await _verify('/android/verify', {
      'token': token,
      'challenge': challenge,
    });
    return 'Token ${_short(token)}\n$verdict';
  }

  Future<String> _appAttest() async {
    final keyId = _appAttestKeyId ??= await DeviceSafety.integrity
        .generateAppAttestKey();
    final challenge = await _challenge();
    final attestation = await DeviceSafety.integrity.attestAppAttestKey(
      keyId: keyId,
      challenge: challenge,
    );
    final verdict = await _verify('/ios/attest', {
      'keyId': keyId,
      'attestation': attestation,
      'challenge': challenge,
    });
    return 'Attestation ${_short(attestation)}\n$verdict';
  }

  Future<String> _deviceCheck() async {
    final token = await DeviceSafety.integrity.generateDeviceCheckToken();
    final verdict = await _verify('/ios/devicecheck', {'token': token});
    return 'Token ${_short(token)}\n$verdict';
  }

  @override
  Widget build(BuildContext context) {
    final android = defaultTargetPlatform == TargetPlatform.android;
    return DemoScaffold(
      title: 'App integrity',
      about:
          'Asks Google or Apple to vouch that this is your real app on a real device. '
          'You get a token that YOUR SERVER must verify; the app cannot check it itself.',
      code: '''// Android: Play Integrity
await DeviceSafety.integrity.preparePlayIntegrity(cloudProjectNumber: 123456789012);
final token = await DeviceSafety.integrity
    .requestPlayIntegrityToken(requestHash: challenge);

// iOS: DeviceCheck (App Attest is also available)
final token = await DeviceSafety.integrity.generateDeviceCheckToken();

// Send the token to your server to verify.''',
      children: [
        if (android)
          FilledButton(
            key: const ValueKey('play_integrity'),
            child: const Text('Get Play Integrity token'),
            onPressed: () => run(_playIntegrity),
          )
        else ...[
          FilledButton(
            child: const Text('Get App Attest attestation'),
            onPressed: () => run(_appAttest),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            child: const Text('Get DeviceCheck token'),
            onPressed: () => run(_deviceCheck),
          ),
        ],
        statusText(),
      ],
    );
  }
}
