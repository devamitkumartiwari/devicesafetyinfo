import 'package:device_safety_info/device_safety_info.dart';
import 'package:flutter/foundation.dart';

/// Which widget set the example renders with.
enum UiStyle { material, cupertino }

/// Demo-wide state: the UI style, the configuration edited on the Policy page, and counters.
final class AppState {
  AppState._();

  static final AppState instance = AppState._();

  DeviceSafetyConfig config = DeviceSafetyConfig(
    accessibilityAllowlist: {'com.google.android.marvin.talkback'},
    // Apps users commonly have that legitimately read notifications. They're installed from
    // Play, so they aren't covered by trustSystemApps.
    notificationListenerAllowlist: {
      'com.google.android.projection.gearhead', // Android Auto
      'com.google.android.wearable.app', // Wear OS
      'com.samsung.android.app.watchmanager', // Galaxy Wearable
    },
    malwarePackages: {'com.example.fakemalware', 'com.metasploit.stage'},
    iocBlocklist: {'malicious.example', '*.phishing.example'},
    // Pass your certificate to try the tampering check:
    //   flutter run --dart-define=EXPECTED_SIGNING_CERT=<sha-256>
    // DeviceSafety.tampering.signingInfo() returns this build's certificate. Without it the
    // Android check reports "unsupported".
    expectedSigningCertificates: {if (_expectedCert.isNotEmpty) _expectedCert},
  );

  static const _expectedCert = String.fromEnvironment('EXPECTED_SIGNING_CERT');

  /// Cupertino on Apple platforms, Material elsewhere; switchable at runtime.
  final ValueNotifier<UiStyle> uiStyle = ValueNotifier(
    switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => UiStyle.cupertino,
      _ => UiStyle.material,
    },
  );

  void toggleStyle() => uiStyle.value = uiStyle.value == UiStyle.material
      ? UiStyle.cupertino
      : UiStyle.material;

  /// Bumped whenever [config] changes, so pages can re-run their checks.
  final ValueNotifier<int> configVersion = ValueNotifier(0);

  final ValueNotifier<int> idleTimeouts = ValueNotifier(0);

  Future<void> apply(DeviceSafetyConfig next) async {
    config = next;
    await DeviceSafety.initialize(next);
    configVersion.value++;
  }
}
