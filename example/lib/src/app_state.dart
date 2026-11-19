import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/foundation.dart';

/// Demo-wide state: the configuration edited on the Policy page, and counters.
final class AppState {
  AppState._();

  static final AppState instance = AppState._();

  DeviceSafetyConfig config = DeviceSafetyConfig(
    accessibilityAllowlist: {'com.google.android.marvin.talkback'},
    malwarePackages: {'com.example.fakemalware', 'com.metasploit.stage'},
    iocBlocklist: {'malicious.example', '*.phishing.example'},
  );

  /// Bumped whenever [config] changes, so pages can re-run their checks.
  final ValueNotifier<int> configVersion = ValueNotifier(0);

  final ValueNotifier<int> idleTimeouts = ValueNotifier(0);

  Future<void> apply(DeviceSafetyConfig next) async {
    config = next;
    await DeviceSafety.initialize(next);
    configVersion.value++;
  }
}
