/// Where a call was detected.
enum CallActivitySource {
  /// A cellular call (Android, needs READ_PHONE_STATE).
  simCall,

  /// A VoIP call detected from audio (Android).
  voipCall,

  /// A call reported by CallKit (iOS).
  callKitObserved,

  /// An audio session interruption, often a third-party call (iOS).
  audioInterrupted,

  /// Unknown.
  unknown,
}

/// A call starting or ending.
final class CallActivityEvent {
  /// Creates the event.
  const CallActivityEvent({
    required this.source,
    required this.started,
    required this.timestamp,
  });

  /// Where the call was detected.
  final CallActivitySource source;

  /// `true` when a call started, `false` when it ended.
  final bool started;

  /// When it happened.
  final DateTime timestamp;

  @override
  String toString() =>
      'CallActivityEvent(${source.name}, ${started ? 'started' : 'ended'}, $timestamp)';
}

/// Call activity, for pausing sensitive actions while a call (possibly a scam call) is live.
abstract interface class CallRepository {
  Future<bool> isCallActive();
  Stream<CallActivityEvent> changes();
}
