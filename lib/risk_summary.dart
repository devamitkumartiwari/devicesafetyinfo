import 'dart:async';

import 'package:device_safety_info/device_safety_info.dart';

// A single active risk signal, in plain language, suitable for showing to an end user before a
// sensitive action (login, payment, viewing account details).
class RiskFlag {
  const RiskFlag({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

// Aggregates a subset of DeviceSafetyInfo's existing checks into a consolidated, human-readable
// risk report. This is a convenience layer only — it runs the same checks already exposed
// individually on [DeviceSafetyInfo], it doesn't add any new detection capability or platform
// channel calls, and it works identically on every platform those checks already support.
class RiskSummary {
  RiskSummary._();

  // Evaluates the underlying checks in parallel and returns only the ones currently indicating
  // risk, as plain-language flags. Deliberately not exhaustive — only includes checks that
  // represent an elevated-risk signal worth surfacing to a user, not purely informational ones
  // (e.g. isInstalledFromStore is omitted; sideloading isn't itself a risk signal worth alarming
  // a user over).
  static Future<List<RiskFlag>> evaluate() async {
    final results = await Future.wait<bool>([
      DeviceSafetyInfo.isRootedDevice,
      DeviceSafetyInfo.isHooked,
      DeviceSafetyInfo.isDebuggerAttached,
      DeviceSafetyInfo.isScreenCaptured,
      DeviceSafetyInfo.isVPNCheck,
      DeviceSafetyInfo.isScreenLock.then((locked) => !locked),
    ]);

    final flags = <RiskFlag>[];
    if (results[0]) {
      flags.add(const RiskFlag(
        id: 'rooted',
        title: 'Device is rooted or jailbroken',
        description: 'Rooted devices can bypass normal app sandboxing protections.',
      ));
    }
    if (results[1]) {
      flags.add(const RiskFlag(
        id: 'hooked',
        title: 'Hooking framework detected',
        description:
            'Tools like Frida or Xposed can intercept or modify app behavior at runtime.',
      ));
    }
    if (results[2]) {
      flags.add(const RiskFlag(
        id: 'debugger',
        title: 'Debugger attached',
        description: 'A debugger can inspect or modify the app while it runs.',
      ));
    }
    if (results[3]) {
      flags.add(const RiskFlag(
        id: 'screen_captured',
        title: 'Screen is being recorded or mirrored',
        description: 'Sensitive on-screen content may be visible to another device or app.',
      ));
    }
    if (results[4]) {
      flags.add(const RiskFlag(
        id: 'vpn',
        title: 'VPN is active',
        description:
            'Network traffic is being routed through a third party. This can be legitimate, but can also be used to mask origin.',
      ));
    }
    if (results[5]) {
      flags.add(const RiskFlag(
        id: 'no_screen_lock',
        title: 'No screen lock configured',
        description:
            'Without a PIN, pattern, or biometric lock, anyone with physical access to the device can use it.',
      ));
    }
    return flags;
  }
}
