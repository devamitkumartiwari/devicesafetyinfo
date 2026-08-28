import 'dart:async';

import '../core/device_safety_channels.dart';

/// What kind of call activity was detected. This can NEVER identify which specific app is
/// calling — that's not achievable on either platform; only that a call-like state exists.
enum CallActivitySource {
  /// Android only — confirmed native/cellular call via TelephonyManager.
  simCall,

  /// Android only — inferred from system-wide audio routing state (AudioManager mode / active
  /// recording & playback configurations). Generic across any VoIP app; app identity unavailable.
  voipCall,

  /// iOS only — CXCallObserver (CallKit) fired. Could be the native Phone app or any
  /// CallKit-integrated VoIP app; iOS's API cannot distinguish the two. Does NOT mean "confirmed
  /// VoIP" the way [voipCall] does on Android — some VoIP apps never route calls through CallKit
  /// at all and are invisible to this signal (a confirmed real gap, not a hypothetical one).
  callKitObserved,

  /// iOS only — the audio session lost focus to something else. Likely a call, but could also be
  /// Siri, an alarm, or another app taking audio focus — lower confidence than [callKitObserved].
  audioInterrupted,

  /// The native event payload didn't match any known source string.
  unknown,
}

/// Whether a [CallActivityEvent] represents a call starting or ending.
enum CallActivityState { started, ended }

/// An event from DeviceSafetyInfo.onCallActivityChanged. See [CallActivitySource] for exactly
/// what each value can and cannot prove.
class CallActivityEvent {
  /// What kind of call activity this is, and how confidently it can be attributed.
  final CallActivitySource source;

  /// Whether the call started or ended.
  final CallActivityState state;

  /// When this event occurred, as reported by the native platform.
  final DateTime timestamp;

  /// Builds a [CallActivityEvent] directly — useful for constructing a fake one in tests.
  const CallActivityEvent({
    required this.source,
    required this.state,
    required this.timestamp,
  });

  /// Builds a [CallActivityEvent] from the raw map delivered over the platform channel.
  factory CallActivityEvent.fromMap(Map<Object?, Object?> map) {
    final rawSource = map['source'] as String?;
    final source = CallActivitySource.values.firstWhere(
      (s) => s.name == rawSource,
      orElse: () => CallActivitySource.unknown,
    );
    final state = map['state'] == 'started'
        ? CallActivityState.started
        : CallActivityState.ended;
    final millis = map['timestamp'] as int?;
    return CallActivityEvent(
      source: source,
      state: state,
      timestamp: millis != null
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : DateTime.now(),
    );
  }
}

/// Phone-call activity detection. Internal implementation detail — reached only through
/// DeviceSafetyInfo's forwarding members, which carry the full docs.
class CallActivity {
  CallActivity._();

  static Stream<CallActivityEvent>? _onCallActivityChanged;

  static Stream<CallActivityEvent> get onCallActivityChanged {
    _onCallActivityChanged ??= DeviceSafetyChannels.callActivity
        .receiveBroadcastStream()
        .map(
          (event) => CallActivityEvent.fromMap(event as Map<Object?, Object?>),
        );
    return _onCallActivityChanged!;
  }

  static Future<bool> get isCallActive async {
    final result = await DeviceSafetyChannels.method.invokeMethod<bool>(
      'isCallActive',
    );
    return result ?? false;
  }
}
