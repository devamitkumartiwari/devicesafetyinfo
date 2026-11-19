import 'dart:async';

/// Stream helpers used to keep platform event streams from flooding listeners.
extension DeviceSafetyStreamUtils<T> on Stream<T> {
  /// Emits a value only after [duration] passes without a newer one, and never the same value
  /// twice in a row. Used for state streams that can flap (screen capture, VPN).
  Stream<T> settled(Duration duration) {
    late StreamController<T> controller;
    StreamSubscription<T>? sub;
    Timer? timer;
    var hasLast = false;
    T? last;

    void emit(T value) {
      if (hasLast && value == last) return;
      hasLast = true;
      last = value;
      controller.add(value);
    }

    controller = StreamController<T>(
      onListen: () {
        sub = listen(
          (value) {
            timer?.cancel();
            timer = Timer(duration, () => emit(value));
          },
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            controller.close();
          },
        );
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () async {
        timer?.cancel();
        await sub?.cancel();
      },
    );
    return controller.stream;
  }
}
