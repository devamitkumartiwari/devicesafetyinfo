import 'package:flutter/widgets.dart';

import 'screenshot_protection.dart';

/// Declaratively blocks screenshots/recording while any [SecureScreen] is mounted anywhere in the
/// tree, and releases blocking once none remain. Ref-counted, so nested or sibling [SecureScreen]s
/// compose correctly — one being disposed never turns off protection another still-mounted
/// instance still needs. Pure Dart sugar over [ScreenshotProtection.on]/[ScreenshotProtection.off];
/// no native code of its own.
class SecureScreen extends StatefulWidget {
  /// Wraps [child], blocking screenshots for as long as this widget is mounted.
  const SecureScreen({super.key, required this.child});

  /// The subtree to protect. Screenshot blocking is engaged for as long as this widget (or any
  /// other mounted [SecureScreen]) is in the tree, not just while it's the visible route.
  final Widget child;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  static int _activeCount = 0;

  @override
  void initState() {
    super.initState();
    _activeCount++;
    if (_activeCount == 1) {
      ScreenshotProtection.on();
    }
  }

  @override
  void dispose() {
    _activeCount--;
    if (_activeCount == 0) {
      ScreenshotProtection.off();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
