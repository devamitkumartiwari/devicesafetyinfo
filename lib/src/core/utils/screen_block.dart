import 'package:flutter/foundation.dart';

/// The shared, reference-counted screenshot block used by widgets (`SecureScreen`, secure text
/// fields). Screenshots stay blocked while at least one holder is active.
abstract final class ScreenBlock {
  /// How the block is applied; set by `DeviceSafety`.
  static Future<void> Function(bool block) blocker = (_) async {};

  static int _active = 0;

  /// Number of active holders.
  @visibleForTesting
  static int get activeCount => _active;

  /// Adds a holder; the first one blocks screenshots.
  static void acquire() {
    if (++_active == 1) _set(true);
  }

  /// Removes a holder; the last one unblocks screenshots.
  static void release() {
    if (_active == 0) return;
    if (--_active == 0) _set(false);
  }

  // Fire-and-forget: widgets can't await, and a failure (e.g. no activity yet) must not break
  // the build.
  static void _set(bool block) {
    blocker(block).catchError((Object _) {});
  }
}
