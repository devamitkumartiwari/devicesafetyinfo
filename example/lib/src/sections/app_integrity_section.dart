import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:device_safety_info/device_safety_info.dart';

import '../platform_support.dart';
import '../refreshable.dart';
import '../widgets/demo_card.dart';
import '../widgets/section_header.dart';

/// Google Cloud project number linked to the app in Play Console.
/// `flutter run --dart-define=PLAY_CLOUD_PROJECT_NUMBER=123456789012`
const _cloudProjectNumber = int.fromEnvironment('PLAY_CLOUD_PROJECT_NUMBER');

/// Base URL of the sample verifier in example/server_dotnet, e.g. `http://192.168.1.10:5080`.
/// When empty, the demo uses a local random challenge and only shows the raw token.
const _serverUrl = String.fromEnvironment('INTEGRITY_SERVER_URL');

/// App Integrity demo: Play Integrity (Android), App Attest + DeviceCheck (iOS).
///
/// Tokens are only meaningful once a server verifies them — set `INTEGRITY_SERVER_URL` to run
/// the full round trip against the .NET sample server.
class AppIntegritySection extends StatefulWidget {
  const AppIntegritySection({super.key});

  @override
  State<AppIntegritySection> createState() => AppIntegritySectionState();
}

class AppIntegritySectionState extends State<AppIntegritySection>
    implements Refreshable {
  bool? _playIntegrityAvailable;
  bool? _appAttestSupported;
  bool? _deviceCheckSupported;
  bool _prepared = false;
  String? _keyId; // demo only — a real app persists this (e.g. shared_preferences)
  bool _busy = false;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  Future<void> refresh() async {
    final results = await Future.wait([
      AppIntegrity.isPlayIntegrityAvailable,
      AppIntegrity.isAppAttestSupported,
      AppIntegrity.isDeviceCheckSupported,
    ]);
    if (!mounted) return;
    setState(() {
      _playIntegrityAvailable = results[0];
      _appAttestSupported = results[1];
      _deviceCheckSupported = results[2];
    });
  }

  // ---- server helpers (dart:io only, so the example needs no extra packages) ----

  Future<String> _challenge() async {
    if (_serverUrl.isEmpty) {
      final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      return base64Url.encode(bytes).replaceAll('=', '');
    }
    final json = await _send('GET', '/challenge');
    return json['challenge'] as String;
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
      if (res.statusCode >= 400) {
        throw HttpException('HTTP ${res.statusCode}: $text');
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<void> _verify(String path, Map<String, Object?> body) async {
    if (_serverUrl.isEmpty) {
      _add('No INTEGRITY_SERVER_URL set — skipped server verification.');
      return;
    }
    _add('Server $path → ${jsonEncode(await _send('POST', path, body))}');
  }

  // ---- demo actions ----

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _busy = true);
    _add('▶ $label');
    try {
      await action();
    } on AttestationException catch (e) {
      _add('✖ ${e.code.name}${e.message == null ? '' : ' — ${e.message}'}');
    } catch (e) {
      _add('✖ $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _add(String line) {
    if (!mounted) return;
    setState(() => _log.insert(0, line));
  }

  String _preview(String token) =>
      '${token.length} chars: ${token.substring(0, min(24, token.length))}…';

  Future<void> _playIntegrity() => _run('Play Integrity', () async {
    if (!_prepared) {
      if (_cloudProjectNumber == 0) {
        _add(
          'Set --dart-define=PLAY_CLOUD_PROJECT_NUMBER=<number> '
          '(Play Console → App integrity → linked Cloud project).',
        );
        return;
      }
      await AppIntegrity.preparePlayIntegrity(
        cloudProjectNumber: _cloudProjectNumber,
      );
      _prepared = true;
      _add('Prepared token provider.');
    }
    final challenge = await _challenge();
    String token;
    try {
      token = await AppIntegrity.requestPlayIntegrityToken(
        requestHash: challenge,
      );
    } on AttestationException catch (e) {
      if (e.code != AttestationErrorCode.providerInvalid) rethrow;
      _add('Provider expired — preparing again.');
      await AppIntegrity.preparePlayIntegrity(
        cloudProjectNumber: _cloudProjectNumber,
      );
      token = await AppIntegrity.requestPlayIntegrityToken(
        requestHash: challenge,
      );
    }
    _add('Token ${_preview(token)}');
    await _verify('/android/verify', {'token': token, 'challenge': challenge});
  });

  Future<void> _appAttest() => _run('App Attest', () async {
    if (_keyId == null) {
      final keyId = await AppIntegrity.generateAppAttestKey();
      final challenge = await _challenge();
      final attestation = await AppIntegrity.attestAppAttestKey(
        keyId: keyId,
        challenge: challenge,
      );
      _add('Attestation ${_preview(attestation)}');
      await _verify('/ios/attest', {
        'keyId': keyId,
        'attestation': attestation,
        'challenge': challenge,
      });
      _keyId = keyId;
    }
    final clientData = jsonEncode({
      'action': 'demo',
      'nonce': await _challenge(),
    });
    final assertion = await AppIntegrity.generateAppAttestAssertion(
      keyId: _keyId!,
      clientData: clientData,
    );
    _add('Assertion ${_preview(assertion)}');
    await _verify('/ios/assert', {
      'keyId': _keyId,
      'assertion': assertion,
      'clientData': clientData,
    });
  });

  Future<void> _deviceCheck() => _run('DeviceCheck', () async {
    final token = await AppIntegrity.generateDeviceCheckToken();
    _add('Token ${_preview(token)}');
    await _verify('/ios/devicecheck', {'token': token});
  });

  @override
  Widget build(BuildContext context) {
    final hint = TextStyle(fontSize: 12, color: Theme.of(context).hintColor);
    String yesNo(bool? v) => v == null ? '…' : (v ? 'Yes' : 'No');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(context, 'App Integrity'),
        DemoCard(
          children: [
            Text(
              'Tokens prove nothing on their own — your server must verify them. '
              '${_serverUrl.isEmpty ? 'No INTEGRITY_SERVER_URL set: showing raw tokens only.' : 'Verifying against $_serverUrl.'}',
              style: hint,
            ),
            const SizedBox(height: 8),
            if (isAndroidPlatform) ...[
              Text(
                'Play Integrity library present: ${yesNo(_playIntegrityAvailable)}',
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _busy ? null : _playIntegrity,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Request Play Integrity token'),
              ),
            ] else ...[
              Text('App Attest supported: ${yesNo(_appAttestSupported)}'),
              Text('DeviceCheck supported: ${yesNo(_deviceCheckSupported)}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _appAttest,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: Text(
                      _keyId == null ? 'Attest key + assert' : 'Assert',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _deviceCheck,
                    icon: const Icon(Icons.phonelink_lock_outlined),
                    label: const Text('DeviceCheck token'),
                  ),
                ],
              ),
            ],
            if (_log.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final line in _log.take(12))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    line,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}
