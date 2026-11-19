import 'package:flutter/widgets.dart';

/// Blocks screenshots and screen recording while it's in the tree. Nested or simultaneous
/// [SecureScreen]s share one block, which is released when the last one is disposed.
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
  static Future<void> Function(bool block) blocker = (_) async {};

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  static int _activeCount = 0;

  @override
  void initState() {
    super.initState();
    if (++_activeCount == 1) _set(true);
  }

  @override
  void dispose() {
    if (--_activeCount == 0) _set(false);
    super.dispose();
  }

  // Fire-and-forget: a widget can't await, and a failure (e.g. no activity yet) must not
  // break the build.
  void _set(bool block) {
    SecureScreen.blocker(block).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
