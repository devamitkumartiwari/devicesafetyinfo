import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// Safe settings for fields that take secrets (passwords, PINs, one-time codes).
///
/// Turns off what leaks typed text: autocorrect and suggestions (the keyboard stores words),
/// IME personalized learning (Android `IME_FLAG_NO_PERSONALIZED_LEARNING`), autofill, and
/// selection with its copy/cut/paste menu. Apply it to any text field:
///
/// ```dart
/// const c = SecureInputConfig.pin();
/// SecureFieldGuard(
///   config: c,
///   child: TextField(               // or CupertinoTextField
///     obscureText: c.obscureText,
///     keyboardType: c.keyboardType,
///     autocorrect: c.autocorrect,
///     enableSuggestions: c.enableSuggestions,
///     enableIMEPersonalizedLearning: c.enableIMEPersonalizedLearning,
///     enableInteractiveSelection: c.enableInteractiveSelection,
///     smartDashesType: c.smartDashesType,
///     smartQuotesType: c.smartQuotesType,
///     autofillHints: c.autofillHints,
///   ),
/// )
/// ```
///
/// or use `SecureEditableText`, which applies it for you.
@immutable
final class SecureInputConfig {
  /// Custom settings. The defaults suit passwords.
  const SecureInputConfig({
    this.obscureText = true,
    this.keyboardType = TextInputType.visiblePassword,
    this.blockScreenshotsWhileFocused = true,
    this.allowClipboard = false,
  });

  /// A password: obscured, no clipboard.
  const SecureInputConfig.password({
    bool blockScreenshotsWhileFocused = true,
    bool allowClipboard = false,
  }) : this(
         blockScreenshotsWhileFocused: blockScreenshotsWhileFocused,
         allowClipboard: allowClipboard,
       );

  /// A numeric PIN: obscured, number keyboard, no clipboard.
  const SecureInputConfig.pin({bool blockScreenshotsWhileFocused = true})
    : this(
        keyboardType: TextInputType.number,
        blockScreenshotsWhileFocused: blockScreenshotsWhileFocused,
      );

  /// A one-time code: visible, number keyboard. Pasting is off by default, so a code can't be
  /// fed in from a clipboard another app controls; pass [allowClipboard] to allow it.
  const SecureInputConfig.otp({
    bool blockScreenshotsWhileFocused = true,
    bool allowClipboard = false,
  }) : this(
         obscureText: false,
         keyboardType: TextInputType.number,
         blockScreenshotsWhileFocused: blockScreenshotsWhileFocused,
         allowClipboard: allowClipboard,
       );

  /// Whether the text is hidden.
  final bool obscureText;

  /// The keyboard to show.
  final TextInputType keyboardType;

  /// Block screenshots and screen recording while the field has focus.
  final bool blockScreenshotsWhileFocused;

  /// Allow selection and the copy/cut/paste menu.
  final bool allowClipboard;

  /// Always `false`.
  bool get autocorrect => false;

  /// Always `false`.
  bool get enableSuggestions => false;

  /// Always `false`: the keyboard must not learn from what's typed.
  bool get enableIMEPersonalizedLearning => false;

  /// Selection (and with it the clipboard menu) only when [allowClipboard].
  bool get enableInteractiveSelection => allowClipboard;

  /// Always disabled.
  SmartDashesType get smartDashesType => SmartDashesType.disabled;

  /// Always disabled.
  SmartQuotesType get smartQuotesType => SmartQuotesType.disabled;

  /// Always `null` (no autofill).
  Iterable<String>? get autofillHints => null;

  @override
  bool operator ==(Object other) =>
      other is SecureInputConfig &&
      other.obscureText == obscureText &&
      other.keyboardType == keyboardType &&
      other.blockScreenshotsWhileFocused == blockScreenshotsWhileFocused &&
      other.allowClipboard == allowClipboard;

  @override
  int get hashCode => Object.hash(
    obscureText,
    keyboardType,
    blockScreenshotsWhileFocused,
    allowClipboard,
  );
}
