import 'package:flutter/services.dart';

/// The single MethodChannel and every EventChannel this plugin uses, all under one name-scoped
/// roof so no two features can accidentally declare conflicting channel identifiers. Channel
/// routing is name-based, so every feature referencing these constants is equivalent to declaring
/// its own identical channel — this purely removes the duplication.
class DeviceSafetyChannels {
  DeviceSafetyChannels._();

  static const MethodChannel method = MethodChannel('device_safety_info');

  static const EventChannel screenCapture = EventChannel(
    'device_safety_info/screen_capture_events',
  );
  static const EventChannel screenshot = EventChannel(
    'device_safety_info/screenshot_events',
  );
  static const EventChannel screenRecording = EventChannel(
    'device_safety_info/screen_recording_events',
  );
  static const EventChannel overlay = EventChannel(
    'device_safety_info/overlay_events',
  );
  static const EventChannel clipboard = EventChannel(
    'device_safety_info/clipboard_events',
  );
  static const EventChannel callActivity = EventChannel(
    'device_safety_info/call_activity_events',
  );
  static const EventChannel connectivity = EventChannel(
    'device_safety_info/connectivity_events',
  );
}
