import '../../../core/platform/device_safety_platform.dart';
import '../../../core/platform/generated/device_safety_api.g.dart';
import '../domain/call_activity_repository.dart';

/// Call activity through the platform API.
final class CallRepositoryImpl implements CallRepository {
  /// Creates the repository.
  CallRepositoryImpl(this._platform, this._events);

  final CallHostApi _platform;
  final PlatformEvents _events;

  @override
  Future<bool> isCallActive() => _platform.isCallActive();

  @override
  Stream<CallActivityEvent> changes() => _events.callActivity.map(
    (e) => CallActivityEvent(
      source: switch (e.source) {
        CallSourceMsg.simCall => CallActivitySource.simCall,
        CallSourceMsg.voipCall => CallActivitySource.voipCall,
        CallSourceMsg.callKitObserved => CallActivitySource.callKitObserved,
        CallSourceMsg.audioInterrupted => CallActivitySource.audioInterrupted,
        CallSourceMsg.unknown => CallActivitySource.unknown,
      },
      started: e.started,
      timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestampMs),
    ),
  );
}
