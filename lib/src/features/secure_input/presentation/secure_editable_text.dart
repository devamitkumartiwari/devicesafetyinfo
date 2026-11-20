import 'package:flutter/widgets.dart';

import '../domain/secure_input_config.dart';
import 'secure_field_guard.dart';

/// A bare text field (no decoration) for secrets, with [SecureInputConfig] applied: no
/// suggestions, autocorrect, IME learning, autofill or clipboard menu, and screenshots blocked
/// while focused. Wrap it in your own decoration, or apply the config to a Material
/// `TextField` / `CupertinoTextField` with `SecureFieldGuard` instead.
class SecureEditableText extends StatefulWidget {
  /// Creates the field.
  const SecureEditableText({
    super.key,
    required this.controller,
    this.focusNode,
    this.config = const SecureInputConfig(),
    required this.style,
    required this.cursorColor,
    this.backgroundCursorColor = const Color(0xFF9E9E9E),
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  /// The text.
  final TextEditingController controller;

  /// Focus; one is created if `null`.
  final FocusNode? focusNode;

  /// The secure settings.
  final SecureInputConfig config;

  /// Text style.
  final TextStyle style;

  /// Cursor color.
  final Color cursorColor;

  /// Color of the cursor's background while it's being dragged (iOS).
  final Color backgroundCursorColor;

  /// Text alignment.
  final TextAlign textAlign;

  /// Whether to take focus when first shown.
  final bool autofocus;

  /// Called on each change.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits.
  final ValueChanged<String>? onSubmitted;

  @override
  State<SecureEditableText> createState() => _SecureEditableTextState();
}

class _SecureEditableTextState extends State<SecureEditableText> {
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return SecureFieldGuard(
      config: c,
      child: EditableText(
        controller: widget.controller,
        focusNode: _focus,
        style: widget.style,
        cursorColor: widget.cursorColor,
        backgroundCursorColor: widget.backgroundCursorColor,
        textAlign: widget.textAlign,
        autofocus: widget.autofocus,
        obscureText: c.obscureText,
        keyboardType: c.keyboardType,
        autocorrect: c.autocorrect,
        enableSuggestions: c.enableSuggestions,
        enableIMEPersonalizedLearning: c.enableIMEPersonalizedLearning,
        enableInteractiveSelection: c.enableInteractiveSelection,
        smartDashesType: c.smartDashesType,
        smartQuotesType: c.smartQuotesType,
        autofillHints: c.autofillHints,
        contextMenuBuilder: null,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
