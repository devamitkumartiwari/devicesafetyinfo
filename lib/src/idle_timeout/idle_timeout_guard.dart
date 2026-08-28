import 'dart:async';

import 'package:flutter/widgets.dart';

/// Wraps part of the widget tree and calls [onTimeout] after [timeout] has elapsed with no pointer
/// activity anywhere inside it — a session-idle guard for triggering a lock screen, logout, etc.
/// Pure Dart, no native code; works identically on every platform Flutter supports.
class IdleTimeoutGuard extends StatefulWidget {
  /// Wraps [child], calling [onTimeout] after [timeout] elapses with no pointer activity.
  const IdleTimeoutGuard({
    super.key,
    required this.timeout,
    required this.onTimeout,
    required this.child,
  });

  /// How long to wait with no pointer activity before calling [onTimeout].
  final Duration timeout;

  /// Called once [timeout] elapses with no pointer activity anywhere in [child].
  final VoidCallback onTimeout;

  /// The wrapped subtree whose pointer activity resets the idle timer.
  final Widget child;

  @override
  State<IdleTimeoutGuard> createState() => _IdleTimeoutGuardState();
}

class _IdleTimeoutGuardState extends State<IdleTimeoutGuard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void didUpdateWidget(covariant IdleTimeoutGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeout != widget.timeout) _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, widget.onTimeout);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerSignal: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
