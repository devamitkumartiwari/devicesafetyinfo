import 'package:flutter/widgets.dart';

import '../../../core/utils/screen_block.dart';
import '../domain/secure_input_config.dart';

/// Blocks screenshots and screen recording while [child] (any text field) has focus, when
/// [SecureInputConfig.blockScreenshotsWhileFocused] is set. Shares the block with
/// `SecureScreen`, so it never unblocks a screen that is protected anyway.
class SecureFieldGuard extends StatefulWidget {
  /// Creates the guard.
  const SecureFieldGuard({
    super.key,
    this.config = const SecureInputConfig(),
    required this.child,
  });

  /// The settings; only [SecureInputConfig.blockScreenshotsWhileFocused] is used here.
  final SecureInputConfig config;

  /// The field.
  final Widget child;

  @override
  State<SecureFieldGuard> createState() => _SecureFieldGuardState();
}

class _SecureFieldGuardState extends State<SecureFieldGuard> {
  bool _holding = false;

  void _hold(bool hold) {
    if (hold == _holding) return;
    _holding = hold;
    hold ? ScreenBlock.acquire() : ScreenBlock.release();
  }

  @override
  void didUpdateWidget(SecureFieldGuard old) {
    super.didUpdateWidget(old);
    if (!widget.config.blockScreenshotsWhileFocused) _hold(false);
  }

  @override
  void dispose() {
    _hold(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (focused) =>
        _hold(focused && widget.config.blockScreenshotsWhileFocused),
    child: widget.child,
  );
}
