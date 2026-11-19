import 'dart:async';

import 'package:flutter/widgets.dart';

/// Calls [onTimeout] after [timeout] without any pointer activity (tap, drag, scroll) inside
/// [child]. Use it to lock a banking session after inactivity.
///
/// ```dart
/// IdleTimeoutGuard(
///   timeout: const Duration(minutes: 5),
///   onTimeout: () => auth.lock(),
///   child: const HomePage(),
/// )
/// ```
class IdleTimeoutGuard extends StatefulWidget {
  /// Creates the guard.
  const IdleTimeoutGuard({
    super.key,
    required this.timeout,
    required this.onTimeout,
    required this.child,
  });

  /// How long the user may be inactive.
  final Duration timeout;

  /// Called once when [timeout] passes without activity. The timer restarts on the next
  /// activity.
  final VoidCallback onTimeout;

  /// The guarded content.
  final Widget child;

  @override
  State<IdleTimeoutGuard> createState() => _IdleTimeoutGuardState();
}

class _IdleTimeoutGuardState extends State<IdleTimeoutGuard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant IdleTimeoutGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeout != widget.timeout) _reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reset() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, () => widget.onTimeout());
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _reset(),
    onPointerMove: (_) => _reset(),
    onPointerSignal: (_) => _reset(),
    child: widget.child,
  );
}
