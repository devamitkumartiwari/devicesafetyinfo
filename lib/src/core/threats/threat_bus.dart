import 'dart:async';

import '../result/check_result.dart';
import '../result/check_type.dart';

/// Something risky happened: a check became detected, or a live event fired (a screenshot,
/// screen capture starting, an overlay attack, a VPN connecting).
final class ThreatEvent {
  /// Creates an event.
  ThreatEvent(this.type, {this.result, this.detail, DateTime? at})
    : at = at ?? DateTime.now();

  /// The check this event relates to.
  final CheckType type;

  /// The result that triggered the event, when it came from a check.
  final CheckResult? result;

  /// Short machine-readable detail for live events, e.g. `screenshot` or `recording_started`.
  final String? detail;

  /// When the event happened.
  final DateTime at;

  @override
  String toString() =>
      'ThreatEvent(${type.name}${detail == null ? '' : ', $detail'}, $at)';
}

/// Broadcasts [ThreatEvent]s. The package never terminates or uninstalls the app by itself;
/// listen here and decide what to do.
final class ThreatBus {
  final StreamController<ThreatEvent> _controller =
      StreamController<ThreatEvent>.broadcast(sync: false);
  final Map<CheckType, bool> _lastDetected = {};

  /// Every threat event.
  Stream<ThreatEvent> get events => _controller.stream;

  /// Emits an event when [result] is detected and the previous result for the same check
  /// wasn't (so repeated checks don't re-announce an ongoing condition).
  void onResult(CheckResult result) {
    final was = _lastDetected[result.type] ?? false;
    _lastDetected[result.type] = result.detected;
    if (result.detected && !was) {
      _emit(ThreatEvent(result.type, result: result));
    }
  }

  /// Emits a live event.
  void emit(CheckType type, String detail) =>
      _emit(ThreatEvent(type, detail: detail));

  /// Forgets the last detected state, so the next detected result emits again.
  void reset() => _lastDetected.clear();

  void _emit(ThreatEvent e) {
    if (!_controller.isClosed) _controller.add(e);
  }

  /// Closes the stream. Only used by tests and `DeviceSafety.forTesting`.
  Future<void> close() => _controller.close();
}
