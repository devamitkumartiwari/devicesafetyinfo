import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../ui/adaptive.dart';

/// Device-bound keys, biometric approval, a secure PIN field and certificate pinning.
class StrongAuthSection extends StatefulWidget {
  const StrongAuthSection({super.key});

  @override
  State<StrongAuthSection> createState() => _StrongAuthSectionState();
}

class _StrongAuthSectionState extends State<StrongAuthSection> {
  static const _deviceAlias = 'example.device';
  static const _bioAlias = 'example.payments';

  final _pin = TextEditingController();
  final _host = TextEditingController(text: 'www.google.com');

  String? _deviceKey;
  String? _biometric;
  String? _pinning;
  String? _serverPin;

  @override
  void initState() {
    super.initState();
    _refreshBiometric();
  }

  @override
  void dispose() {
    _pin.dispose();
    _host.dispose();
    super.dispose();
  }

  Future<void> _run(
    void Function(String) set,
    Future<String> Function() f,
  ) async {
    String text;
    try {
      text = await f();
    } on DeviceSafetyException catch (e) {
      text = e.toString();
    } on Exception catch (e) {
      text = e.toString();
    }
    if (mounted) setState(() => set(text));
  }

  static Uint8List _nonce() {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => r.nextInt(256)));
  }

  static String _short(Uint8List bytes) {
    final b = base64.encode(bytes);
    return b.length <= 24 ? b : '${b.substring(0, 24)}...';
  }

  void _refreshBiometric() => _run((t) => _biometric = t, () async {
    final available = await DeviceSafety.biometric.isAvailable();
    if (!available) return 'No strong biometric enrolled on this device';
    final state = await DeviceSafety.biometric.keyState(_bioAlias);
    return 'Available. Key "$_bioAlias": ${state.name}';
  });

  Widget _result(String? text, Key key) => text == null
      ? const SizedBox.shrink()
      : SectionContent(child: Text(text, key: key));

  Widget _buttons(List<Widget> children) => SectionContent(
    child: Wrap(spacing: 8, runSpacing: 8, children: children),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveSection(
          header: 'Device-bound key',
          footer:
              'An EC P-256 key in StrongBox / TEE / Secure Enclave. Register the public key '
              '(and, on Android, the attestation chain) with your server, then sign requests.',
          children: [
            _buttons([
              AdaptiveButton(
                key: const ValueKey('device_key_create'),
                label: 'Create',
                onPressed: () => _run((t) => _deviceKey = t, () async {
                  final k = await DeviceSafety.deviceKey.create(
                    _deviceAlias,
                    challenge: _nonce(),
                  );
                  return '${k.securityLevel.name} '
                      '(hardware: ${k.securityLevel.isHardwareBacked}), '
                      'attestation chain: ${k.attestationChain.length} certs\n'
                      'public key ${_short(k.publicKey)}';
                }),
              ),
              AdaptiveButton(
                key: const ValueKey('device_key_sign'),
                label: 'Sign a nonce',
                filled: false,
                onPressed: () => _run((t) => _deviceKey = t, () async {
                  final sig = await DeviceSafety.deviceKey.sign(
                    _deviceAlias,
                    _nonce(),
                  );
                  return 'Signature (${sig.length} bytes DER): ${_short(sig)}';
                }),
              ),
              AdaptiveButton(
                label: 'Delete',
                filled: false,
                onPressed: () => _run((t) => _deviceKey = t, () async {
                  await DeviceSafety.deviceKey.delete(_deviceAlias);
                  return 'Deleted';
                }),
              ),
            ]),
            _result(_deviceKey, const ValueKey('device_key_result')),
          ],
        ),
        AdaptiveSection(
          header: 'Biometric approval',
          footer:
              'Approving signs the payment with a key that only a fingerprint or face match '
              'unlocks. Adding a new fingerprint invalidates the key.',
          children: [
            _buttons([
              AdaptiveButton(
                key: const ValueKey('bio_enroll'),
                label: 'Enroll',
                onPressed: () => _run((t) => _biometric = t, () async {
                  final k = await DeviceSafety.biometric.enroll(_bioAlias);
                  return 'Enrolled (${k.securityLevel.name}), '
                      'public key ${_short(k.publicKey)}';
                }),
              ),
              AdaptiveButton(
                key: const ValueKey('bio_approve'),
                label: 'Approve payment',
                filled: false,
                onPressed: () => _run((t) => _biometric = t, () async {
                  final payload = utf8.encode(
                    '${base64.encode(_nonce())}|pay 500 to Alice',
                  );
                  final sig = await DeviceSafety.biometric.approve(
                    _bioAlias,
                    payload,
                    title: 'Confirm payment',
                    reason: 'Pay 500 to Alice',
                  );
                  return 'Approved. Signature ${sig.length} bytes: ${_short(sig)}';
                }),
              ),
              AdaptiveButton(
                label: 'Key state',
                filled: false,
                onPressed: _refreshBiometric,
              ),
              AdaptiveButton(
                label: 'Delete',
                filled: false,
                onPressed: () => _run((t) => _biometric = t, () async {
                  await DeviceSafety.biometric.delete(_bioAlias);
                  return 'Deleted';
                }),
              ),
            ]),
            _result(_biometric, const ValueKey('bio_result')),
          ],
        ),
        AdaptiveSection(
          header: 'Secure PIN field',
          footer:
              'SecureInputConfig.pin(): no suggestions, keyboard learning, autofill or '
              'clipboard; screenshots are blocked while the field is focused.',
          children: [
            SectionContent(
              child: AdaptiveTextField(
                key: const ValueKey('secure_pin'),
                controller: _pin,
                label: 'PIN',
                secure: const SecureInputConfig.pin(),
              ),
            ),
          ],
        ),
        AdaptiveSection(
          header: 'Certificate pinning',
          footer:
              'Fetch the host\'s pin, then request it with that pin (succeeds) and with a '
              'wrong one (fails before any request bytes are sent).',
          children: [
            SectionContent(
              child: AdaptiveTextField(
                key: const ValueKey('pin_host'),
                controller: _host,
                label: 'Host',
              ),
            ),
            _buttons([
              AdaptiveButton(
                key: const ValueKey('pin_fetch'),
                label: 'Get pin',
                onPressed: () => _run((t) => _pinning = t, () async {
                  final pin = await DeviceSafety.pinning.spkiPinOf(
                    Uri.https(_host.text.trim()),
                  );
                  _serverPin = pin;
                  return 'Pin: $pin';
                }),
              ),
              AdaptiveButton(
                key: const ValueKey('pin_right'),
                label: 'Request (right pin)',
                filled: false,
                onPressed: () => _run(
                  (t) => _pinning = t,
                  () => _request(_serverPin ?? _fakePin(1)),
                ),
              ),
              AdaptiveButton(
                key: const ValueKey('pin_wrong'),
                label: 'Request (wrong pin)',
                filled: false,
                onPressed: () =>
                    _run((t) => _pinning = t, () => _request(_fakePin(2))),
              ),
            ]),
            _result(_pinning, const ValueKey('pin_result')),
          ],
        ),
      ],
    );
  }

  static String _fakePin(int fill) => base64.encode(List.filled(32, fill));

  Future<String> _request(String pin) async {
    final host = _host.text.trim();
    final client = DeviceSafety.pinning.createHttpClient(
      PinningConfig({
        host: {pin, _fakePin(9)},
      }),
    );
    try {
      final req = await client.getUrl(Uri.https(host));
      final res = await req.close();
      await res.drain<void>();
      return 'HTTP ${res.statusCode} with pin ${pin.substring(0, 8)}...';
    } on PinningException catch (e) {
      return 'Blocked: $e';
    } on SocketException catch (e) {
      return 'Network error: ${e.message}';
    } finally {
      client.close(force: true);
    }
  }
}
