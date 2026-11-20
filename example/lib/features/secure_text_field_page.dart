import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../common/demo_scaffold.dart';

/// Secure text fields for PINs, passwords and one-time codes.
///
/// ```dart
/// const pin = SecureInputConfig.pin(); // also .password() and .otp()
///
/// SecureFieldGuard(            // blocks screenshots while focused
///   config: pin,
///   child: TextField(
///     obscureText: pin.obscureText,
///     keyboardType: pin.keyboardType,
///     autocorrect: pin.autocorrect,
///     enableSuggestions: pin.enableSuggestions,
///     enableIMEPersonalizedLearning: pin.enableIMEPersonalizedLearning,
///     enableInteractiveSelection: pin.enableInteractiveSelection,
///     autofillHints: pin.autofillHints,
///   ),
/// );
/// ```
class SecureTextFieldPage extends StatefulWidget {
  const SecureTextFieldPage({super.key});

  @override
  State<SecureTextFieldPage> createState() => _SecureTextFieldPageState();
}

class _SecureTextFieldPageState extends State<SecureTextFieldPage> {
  static const _pin = SecureInputConfig.pin();
  final _controller = TextEditingController();
  bool _blockKeyboards = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    return DemoScaffold(
      title: 'Secure text fields',
      about:
          'Keyboards learn and sync what you type. Turn that off for PINs and passwords: '
          'no suggestions, no keyboard learning, no autofill or copy, and no screenshots '
          'while the field is focused.',
      code: '''const pin = SecureInputConfig.pin(); // or .password(), .otp()

SecureFieldGuard(
  config: pin,
  child: TextField(
    obscureText: pin.obscureText,
    keyboardType: pin.keyboardType,
    autocorrect: pin.autocorrect,
    enableSuggestions: pin.enableSuggestions,
    enableIMEPersonalizedLearning: pin.enableIMEPersonalizedLearning,
    enableInteractiveSelection: pin.enableInteractiveSelection,
    autofillHints: pin.autofillHints,
  ),
);''',
      children: [
        SecureFieldGuard(
          config: _pin,
          child: TextField(
            key: const ValueKey('secure_pin'),
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'PIN',
              border: OutlineInputBorder(),
            ),
            obscureText: _pin.obscureText,
            keyboardType: _pin.keyboardType,
            autocorrect: _pin.autocorrect,
            enableSuggestions: _pin.enableSuggestions,
            enableIMEPersonalizedLearning: _pin.enableIMEPersonalizedLearning,
            enableInteractiveSelection: _pin.enableInteractiveSelection,
            autofillHints: _pin.autofillHints,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          key: const ValueKey('block_keyboards'),
          title: const Text('Block third-party keyboards'),
          subtitle: Text(
            isIos
                ? 'Applies to the next keyboard shown. Needs the AppDelegate override (see README).'
                : 'iOS only. On Android, see the "Third-party keyboard" check.',
          ),
          value: _blockKeyboards,
          onChanged: isIos
              ? (on) async {
                  await DeviceSafety.keyboard.blockCustomKeyboards(on);
                  if (mounted) setState(() => _blockKeyboards = on);
                }
              : null,
        ),
      ],
    );
  }
}
