import 'dart:convert';

import 'package:device_safety_info/device_safety_info.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Biometric-approved actions: a fingerprint or face match signs the action.
///
/// ```dart
/// final key = await DeviceSafety.biometric.enroll('payments'); // register key.publicKey
///
/// final signature = await DeviceSafety.biometric.approve(
///   'payments',
///   utf8.encode('pay 500 to Alice'),
///   title: 'Confirm payment',
///   reason: 'Pay 500 to Alice',
/// );
/// // send the signature to your server; it verifies with the public key
/// ```
class BiometricPage extends StatefulWidget {
  const BiometricPage({super.key});

  @override
  State<BiometricPage> createState() => _BiometricPageState();
}

class _BiometricPageState extends State<BiometricPage> with StatusMessage {
  static const _alias = 'example.payments';

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Biometric approval',
      about:
          'Approve a payment with a fingerprint or face. Unlike a simple "is it you?" '
          'prompt, the approval is a signature that only a real biometric match can '
          'make, so it cannot be faked by hacking the app.',
      code:
          '''// Once: create the key and register key.publicKey with your server
final key = await DeviceSafety.biometric.enroll('payments');

// For each payment: ask for a fingerprint and get a signature
final signature = await DeviceSafety.biometric.approve(
  'payments',
  utf8.encode('pay 500 to Alice'),
  title: 'Confirm payment',
  reason: 'Pay 500 to Alice',
);''',
      children: [
        OutlinedButton(
          child: const Text('Is a biometric set up?'),
          onPressed: () => run(() async {
            final ok = await DeviceSafety.biometric.isAvailable();
            return ok ? 'Yes' : 'No: add a fingerprint or face in Settings';
          }),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('bio_enroll'),
          child: const Text('1. Enroll'),
          onPressed: () => run(() async {
            await DeviceSafety.biometric.enroll(_alias);
            return 'Enrolled. Now approve a payment.';
          }),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('bio_approve'),
          child: const Text('2. Approve payment of 500'),
          onPressed: () => run(() async {
            final signature = await DeviceSafety.biometric.approve(
              _alias,
              utf8.encode('pay 500 to Alice'),
              title: 'Confirm payment',
              reason: 'Pay 500 to Alice',
            );
            return 'Approved. Signature: ${signature.length} bytes';
          }),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          child: const Text('Delete key'),
          onPressed: () => run(() async {
            await DeviceSafety.biometric.delete(_alias);
            return 'Deleted';
          }),
        ),
        statusText(),
      ],
    );
  }
}
