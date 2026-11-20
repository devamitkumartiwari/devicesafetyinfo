import 'package:flutter/widgets.dart';

import '../../../../core/utils/screen_block.dart';

/// Blocks screenshots and screen recording while it's in the tree. Nested or simultaneous
/// [SecureScreen]s (and focused secure text fields) share one block, which is released when the
/// last one goes away.
///
/// ```dart
/// SecureScreen(child: PaymentPage())
/// ```
class SecureScreen extends StatefulWidget {
  /// Creates the widget.
  const SecureScreen({super.key, required this.child});

  /// The protected content.
  final Widget child;

  /// How [SecureScreen] blocks and unblocks; set by `DeviceSafety`. Exposed for tests.
  static Future<void> Function(bool block) get blocker => ScreenBlock.blocker;
  static set blocker(Future<void> Function(bool block) value) =>
      ScreenBlock.blocker = value;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    ScreenBlock.acquire();
  }

  @override
  void dispose() {
    ScreenBlock.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
