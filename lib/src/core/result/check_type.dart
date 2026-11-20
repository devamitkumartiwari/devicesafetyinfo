/// Every detection check in the package. Used to set per-check policies and fail modes, to
/// choose checks for `DeviceSafety.assess`, and to label results and threat events.
enum CheckType {
  /// Rooted (Android) or jailbroken (iOS) device.
  root,

  /// Emulator (Android) or simulator (iOS).
  emulator,

  /// Hooking or instrumentation frameworks (Frida, Xposed/LSPosed, Substrate).
  hooking,

  /// A debugger attached to the app process.
  debugger,

  /// Developer options or USB debugging enabled (Android).
  developerMode,

  /// No secure screen lock (PIN, pattern, password or biometric) configured.
  screenLock,

  /// The app wasn't installed from an official store.
  storeInstall,

  /// The app is installed on external storage (Android).
  externalStorage,

  /// The app may install other apps ("install unknown apps" granted, Android).
  unknownSources,

  /// Google Play Protect is disabled or its state is unknown (Android).
  playProtect,

  /// An enabled accessibility service that isn't on the allowlist (Android).
  accessibility,

  /// An enabled notification listener that isn't on the allowlist (Android).
  notificationListener,

  /// A VPN or HTTP proxy is active.
  vpn,

  /// The screen is being recorded, mirrored or shown on an external display.
  screenCapture,

  /// A touch arrived while another app's window covered this one (Android). Reported only
  /// through `DeviceSafety.threats`.
  overlayAttack,

  /// An app from the configured malware package list is installed (Android).
  malware,

  /// The app was repackaged or re-signed: an unexpected signing certificate (Android) or
  /// provisioning profile (iOS).
  tampering,

  /// A remote-control app (AnyDesk, TeamViewer QuickSupport, ...) is installed or can control
  /// the device (Android).
  remoteAccess,

  /// A mock-location app is selected or the location is spoofed (Android).
  locationSpoofing,

  /// The app runs in a cloned / dual-app space or a work profile (Android).
  appCloning,

  /// User-installed CA certificates allow HTTPS interception (Android).
  mitm;

  /// Stable string id sent to the platform side (the enum name).
  String get id => name;

  /// Looks up a check by [id]; `null` if unknown.
  static CheckType? fromId(String id) {
    for (final t in values) {
      if (t.name == id) return t;
    }
    return null;
  }
}
