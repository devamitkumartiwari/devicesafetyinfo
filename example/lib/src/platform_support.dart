import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Whether the app is currently running on Android. Centralizes the many
/// `Platform.isAndroid` checks that used to be scattered across the demo screen.
bool get isAndroidPlatform => Platform.isAndroid;

/// Renders [child] only when running on Android; renders nothing (a zero-size box)
/// on every other platform.
class AndroidOnly extends StatelessWidget {
  const AndroidOnly({super.key, required this.child});

  /// The widget to show on Android.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return isAndroidPlatform ? child : const SizedBox.shrink();
  }
}
