import '../../../core/platform/action_guard.dart';
import '../domain/call_activity_repository.dart';

export '../domain/call_activity_repository.dart'
    show CallActivityEvent, CallActivitySource;

/// Live call detection, to pause sensitive flows (payments, OTP entry) during a call, a
/// common social-engineering pattern. Android SIM-call detection needs the app to declare and
/// request `READ_PHONE_STATE`; without it only VoIP calls are detected.
final class CallActivityApi {
  /// Created by `DeviceSafety`; apps use `DeviceSafety.calls`.
  CallActivityApi(this._repository);

  final CallRepository _repository;

  /// Whether a call is in progress.
  Future<bool> isCallActive() =>
      guardAction('isCallActive', _repository.isCallActive);

  /// Call start/end events.
  Stream<CallActivityEvent> get changes => _repository.changes();
}
