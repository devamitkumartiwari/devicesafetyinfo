# device_safety_info

[![pub package](https://img.shields.io/pub/v/device_safety_info.svg)](https://pub.dev/packages/device_safety_info)
[![pub points](https://img.shields.io/pub/points/device_safety_info)](https://pub.dev/packages/device_safety_info/score)
[![pub likes](https://img.shields.io/pub/likes/device_safety_info)](https://pub.dev/packages/device_safety_info/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![platform](https://img.shields.io/badge/platform-android%20%7C%20ios-lightgrey.svg)](#)

A device-security toolkit for Flutter apps: root/jailbreak, hooking, and debugger detection;
screenshot and screen-recording protection; clipboard, overlay-attack, and malware defenses; VPN
and app-update checks — all as plain data and streams you compose into your own UI, with zero
required third-party dependencies.

## Table of Contents

- [Installation](#installation)
- [Why this package](#why-this-package)
- [Usage](#usage)
  1. [Basic Security Checks](#1-basic-security-checks)
  2. [Advanced Security Actions](#2-advanced-security-actions)
  3. [Screenshot & Recording Management](#3-screenshot--recording-management)
  4. [App Switcher (Recents) Security](#4-app-switcher-recents-security)
  5. [VPN Monitoring](#5-vpn-monitoring)
  6. [App Version Checker](#6-app-version-checker)
  7. [Overlay Attack Detection](#7-overlay-attack-detection-android-only)
  8. [Clipboard Protection](#8-clipboard-protection)
  9. [IOC / C2 Domain Blocking](#9-ioc--c2-domain-blocking)
  10. [Malware Package Detection](#10-malware-package-detection-android-only)
  11. [Accessibility Abuse Detection](#11-accessibility-abuse-detection-android-only)
  12. [Play Protect Status](#12-play-protect-status-android-only)
  13. [Idle Session Timeout](#13-idle-session-timeout)
  14. [Risk Summary](#14-risk-summary)
  15. [Notification Listener Check](#15-notification-listener-check-android-only)
  16. [Unknown Sources / Sideloading Check](#16-unknown-sources--sideloading-check-android-only)
  17. [Call-Screening Role](#17-call-screening-role-android-only-api-29)
  18. [Call Activity Detection](#18-call-activity-detection)
- [Permissions (Android)](#permissions-android)
- [Features at a Glance](#features-at-a-glance)
- [Platform Support](#platform-support)
- [Contributing](#contributing)
- [License](#license)

## Installation

```yaml
dependencies:
  device_safety_info: ^1.5.2
```

```dart
import 'package:device_safety_info/device_safety_info.dart';
```

## Why this package

- **Primitives, not opinions.** Every feature is a `Future`, a `Stream`, or a small data class —
  the only widgets shipped (`IdleTimeoutGuard`, `SecureScreen`) are behavior-only wrappers, never
  visual chrome. You build the UI; this package supplies the signal.
- **No required third-party dependencies.** Root/hook detection runs through native FFI and
  platform channels this package owns end-to-end — not `package_info_plus`, not `http`, not a
  security-suite wrapper you also have to trust and keep updated.
- **Honest about platform limits.** Where a check is structurally impossible on a platform (e.g.
  overlay-attack detection on iOS, due to app sandboxing) it throws a clearly-coded exception
  instead of silently returning a value that looks like "checked, all clear." Where a signal is
  best-effort (store-version scraping, sideloading detection), the docs say so plainly.
- **Modular by feature.** Internally organized as one vertical slice per feature across Dart,
  Android, and iOS — a change to, say, clipboard behavior only touches clipboard files.

## Usage

### 1. Basic Security Checks
These simple getters provide quick boolean checks for common security states.

```dart
// Checks whether device JailBroken or Rooted
// iOS: Uses IOSSecuritySuite. Android: Uses Native FFI + Root files check.
bool isRooted = await DeviceSafetyInfo.isRootedDevice;

// Checks whether device is Real or Emulator/Simulator
bool isReal = await DeviceSafetyInfo.isRealDevice;

// Checks for hooking frameworks (Frida, Xposed, Cydia Substrate, etc.)
// Uses native scan of process memory maps for high reliability.
bool isHooked = await DeviceSafetyInfo.isHooked;

// Checks whether a debugger is attached to the process
// Uses native C checks (TracerPid/P_TRACED) to bypass simple debugger hooks.
bool isDebugger = await DeviceSafetyInfo.isDebuggerAttached;

// Checks for screen lock (PIN/Pattern/Biometrics)
bool isScreenLock = await DeviceSafetyInfo.isScreenLock;

// Checks if app is installed from Official Store (Play Store / App Store)
bool isStore = await DeviceSafetyInfo.isInstalledFromStore;

// (Android Only) Checks if app is installed on external storage
bool isExternal = await DeviceSafetyInfo.isExternalStorage;

// (Android Only) Checks if Development Options are enabled
bool isDeveloperMode = await DeviceSafetyInfo.isDeveloperMode;
```

### 2. Advanced Security Actions
For Root and Hook detection, you can take immediate action like closing the app.

```dart
// Check for hooks and optionally exit or uninstall
bool hooked = await DeviceSafetyInfo.checkHooked(
  exitProcessIfTrue: true, // Closes the app immediately if hooked
  uninstallIfTrue: false,  // (Android Only) Triggers uninstallation
);
```

### 3. Screenshot & Recording Management
Protect your app's sensitive data from being captured.

```dart
// --- Detection ---

// Check if screen is currently being captured/recorded/mirrored
bool isCaptured = await DeviceSafetyInfo.isScreenCaptured;

// Listen to real-time screen capture status changes
DeviceSafetyInfo.onScreenCapturedChanged.listen((isCaptured) {
  print("Screen capture status changed: $isCaptured");
});

// Listen to screenshot events
// iOS: Uses UIApplication.userDidTakeScreenshotNotification
// Android: Uses API 34 ScreenCaptureCallback or ContentObserver
DeviceSafetyInfo.onScreenshotTaken.listen((_) {
  print("User took a screenshot!");
});

// --- Prevention ---

// Block screenshots and screen recordings
// Android: Uses FLAG_SECURE. iOS: Uses a secure UITextField layer trick.
await DeviceSafetyInfo.blockScreenshots(block: true);

// Convenience query/toggle alongside blockScreenshots.
bool isBlocked = await DeviceSafetyInfo.isScreenshotBlocked;
await DeviceSafetyInfo.toggleScreenshotBlocking();

// Or declaratively: blocks screenshots for as long as this widget (or any other
// mounted SecureScreen) is in the tree. Pure Dart, no native code of its own.
SecureScreen(child: MySensitiveScreen());

// --- Live overlay modes ---
//
// FLAG_SECURE / the iOS secure-layer trick make the OS render nothing at all into a
// capture, so no overlay content can ever appear *inside* a screenshot or recording —
// these show a real, visible overlay over the app's own on-screen content instead,
// reactively, only while a capture/recording is actually happening.

// Blur the screen whenever a capture/recording is detected.
// Android requires API 31+ for a true blur; degrades to a translucent scrim below that.
await DeviceSafetyInfo.setScreenshotOverlayMode(
  mode: ScreenshotOverlayMode.blur,
  blurRadius: 16,
);

// Or a solid color / custom image instead:
await DeviceSafetyInfo.setScreenshotOverlayMode(
  mode: ScreenshotOverlayMode.color,
  argbColor: 0xFF6200EE,
);
await DeviceSafetyInfo.setScreenshotOverlayMode(
  mode: ScreenshotOverlayMode.image,
  imageBytes: myBrandedPlaceholderBytes,
);

await DeviceSafetyInfo.clearScreenshotOverlayMode();

// --- Screen recording detection ---
//
// Distinct from isScreenCaptured/onScreenCapturedChanged above, which covers screen
// mirroring/external-display capture. Android: backed by the real recording-session
// callback, API 35+ only — isSupported reports false below that rather than guessing.
// iOS has no API distinguishing "recording" from "mirroring/AirPlay" — both surface
// through the same signal isScreenCaptured already uses, so isSupported is always true
// there and the two streams report identically.

bool canDetectRecording = await ScreenRecordingDetector.isSupported;

ScreenRecordingDetector.onScreenRecordingChanged.listen(
  (isRecording) => print("Screen recording: $isRecording"),
  onError: (e) => print("Screen recording detection unavailable: $e"), // see caveat below
);
```

> **Known limitation**: `isSupported` reflects Android *OS version* support only (API 35+) — it
> cannot know ahead of time whether a given device's manufacturer actually grants the underlying
> `DETECT_SCREEN_RECORDING` permission to third-party apps at runtime, even though it's declared in
> the plugin's manifest. On at least one Samsung device, the OS enforces this through an internal
> Knox-branded `WindowManagerService` path that denies it regardless. When that happens, the stream
> delivers a `permission_denied` error via `onError` instead of values — always attach one, as shown
> above.

### 4. App Switcher (Recents) Security
Control how your app appears in the recent apps / multitasking view.

```dart
// Add a solid color overlay when the app is in the background.
// This prevents sensitive data from being visible in the app switcher.
await DeviceSafetyInfo.setRecentsOverlay(argbColor: 0xFF000000); // Opaque Black

// Clear the overlay
await DeviceSafetyInfo.clearRecentsOverlay();

// (Android Only) Completely hide the app from the Recents menu
await DeviceSafetyInfo.hideMenu(hide: true);
```

### 5. VPN Monitoring
Monitor VPN connectivity in real-time.

```dart
final vpnCheck = VPNCheck();

vpnCheck.vpnState.listen((state) {
  if (state == VPNState.connectedState) {
    print("VPN is now connected.");
  } else {
    print("VPN is now disconnected.");
  }
});
```

### 6. App Version Checker
Check if there's a new version available on the store.

```dart
void checkVersion() async {
    final newVersion = NewVersionChecker(
      iOSId: 'your.bundle.id',
      androidId: 'your.package.name',

      // Optional: numeric App Store ID, tried as a fallback lookup if the bundle-ID
      // lookup above returns no results (a real failure mode even for live apps).
      iOSAppStoreId: '123456789',

      // Optional: a developer-supplied minimum version, e.g. from your own remote
      // config. Never scraped from the store — see the caveat below.
      minAppVersion: '2.0.0',
    );

    final status = await newVersion.getVersionStatus();
    if (status == null) return; // Store unreachable or unparseable — see caveat below.

    switch (status.urgency) {
      case UpdateUrgency.required:
        // localVersion is below minAppVersion — block further use until updated.
        print("Update required: ${status.storeVersion}");
        break;
      case UpdateUrgency.optional:
        print("New version available: ${status.storeVersion} (Local: ${status.localVersion})");
        break;
      case UpdateUrgency.none:
        break; // Already up to date.
    }
    print("Update Link: ${status.appStoreLink}");
}
```

> **Known limitation**: both lookups are best-effort parsing of endpoints neither store publishes
> as a stable, documented API (the iTunes lookup JSON shape, and the Play Store listing HTML).
> Both have changed unannounced in the past. `getVersionStatus()` fails soft — it returns `null`
> rather than throwing when a response doesn't parse as expected — but a `null` result (or
> `UpdateUrgency.none`) should never be treated as proof no update exists, only as "couldn't
> determine." This package deliberately does not attempt to extract release notes/"what's new"
> text, since that field is one of the most fragile and inconsistently formatted parts of both
> stores' responses.

### 7. Overlay Attack Detection (Android only)
Detect or block touches while another app is drawing an overlay on top of yours (tapjacking /
overlay-phishing). Not applicable on iOS — app sandboxing makes cross-app overlays structurally
impossible, so calls throw a `PlatformException('UNSUPPORTED_PLATFORM', ...)` there rather than
silently doing nothing.

```dart
// --- Detection ---

// Fires whenever a touch is delivered while the window is obscured by another app's overlay.
DeviceSafetyInfo.onOverlayAttackDetected.listen((_) {
  print("Touch received while obscured by another app's overlay!");
});

// --- Prevention ---

// Drop touches outright while the window is obscured (OS-level protection).
await DeviceSafetyInfo.blockTouchesWhenObscured(block: true);
```

### 8. Clipboard Protection
Protect sensitive copied text (OTPs, card numbers) from other apps reading it, and react to
clipboard changes from any app.

```dart
// Copy sensitive text: hides it from the system clipboard preview (Android API 33+, marks the
// pasteboard item local-only on iOS) and auto-clears it after the given duration.
await DeviceSafetyInfo.copyToClipboard(
  '123456',
  sensitive: true,
  autoClear: const Duration(seconds: 30),
);

// Clear the clipboard immediately.
await DeviceSafetyInfo.clearClipboard();

// Listen for clipboard changes, from any app.
DeviceSafetyInfo.onClipboardChanged.listen((_) {
  print("Clipboard contents changed.");
});
```

### 9. IOC / C2 Domain Blocking
A lightweight domain-reputation lookup you wire into your own HTTP client (e.g. an `http`/`Dio`
interceptor) or WebView navigation guard. This is a client-side lookup utility only — it does not
intercept network traffic itself, and it does not ship a maintained threat-intel feed; you supply
or point at your own list.

```dart
// Supply your own list. Entries starting with `*.` match subdomains only (like a TLS wildcard
// certificate) — list the bare domain too if it should also be blocked.
IOCDomainBlocker.updateBlocklist(['evil.com', '*.evil.com']);

// Or load a newline-separated list from a remote feed ('#' lines are treated as comments).
await IOCDomainBlocker.loadRemoteBlocklist(Uri.parse('https://example.com/ioc-feed.txt'));

// Check a host before making a request or navigating a WebView to it.
if (IOCDomainBlocker.isBlocked(uri.host)) {
  // refuse the request / navigation
}
```

### 10. Malware Package Detection (Android only)
Checks whether a specific package is installed, for matching against a known-malware/stalkerware
list you supply. **Requires a manifest declaration** — on Android 11+ (API 30+), package visibility
filtering means you must declare every package name you want to check in your own
`AndroidManifest.xml`, or the check always reports "not installed" even if it actually is (see
[Permissions](#permissions-android) below). This plugin deliberately doesn't request the broader
`QUERY_ALL_PACKAGES` permission — that permission is subject to Google Play's manual approval
process and would be merged into every app depending on this plugin, most of which wouldn't qualify.

```dart
// Add the package name(s) you want to check to your AndroidManifest.xml <queries> block first.
final isInstalled = await MalwarePackageDetector.isPackageInstalled('com.example.known.malware');

// Or check a list at once — returns only the ones found installed.
final found = await MalwarePackageDetector.scanKnownMalware([
  'com.example.known.malware',
  'com.example.known.spyware',
]);
```

### 11. Accessibility Abuse Detection (Android only)
Lists currently-enabled Accessibility services. Malware that abuses the Accessibility API (to read
screen content or auto-click on the user's behalf) shows up here the same way a legitimate screen
reader would — matching malicious against legitimate services is left to you.

```dart
final services = await DeviceSafetyInfo.enabledAccessibilityServices; // raw component names
final anyEnabled = await DeviceSafetyInfo.isAnyAccessibilityServiceEnabled;
```

### 12. Play Protect Status (Android only)
Reads whether Google Play Protect scanning is enabled. There is no public "Play Protect API" —
this reads the underlying OS setting Play Protect's toggle controls directly.

```dart
final status = await DeviceSafetyInfo.playProtectStatus; // PlayProtectStatus.enabled/disabled/unknown
```

### 13. Idle Session Timeout
Fires a callback after a period with no touch activity anywhere in the wrapped widget tree — pure
Dart, no native code, identical behavior on every platform. `timeout` accepts any `Duration` you
choose — there's no fixed or default value baked into the plugin.

```dart
IdleTimeoutGuard(
  timeout: const Duration(seconds: 30), // e.g. for quick testing
  // timeout: const Duration(minutes: 5),  // a typical session length
  // timeout: const Duration(minutes: 15), // a more lenient session length
  onTimeout: () => logOutUser(),
  child: const MyApp(),
);
```

### 14. Risk Summary
Aggregates several of the checks above (rooted, hooked, debugger, screen capture, VPN, missing
screen lock) into a single list of plain-language risk flags, for showing a consolidated warning
before a sensitive action.

```dart
final flags = await RiskSummary.evaluate();
for (final flag in flags) {
  print('${flag.title}: ${flag.description}');
}
```

### 15. Notification Listener Check (Android only)
Lists apps currently granted notification-listener access — the mechanism banking trojans like
TrickMo and Antidot/PhantomCall commonly abuse to intercept OTP and SMS notifications. Same
"surface the raw list, you judge good vs. bad" shape as Accessibility Abuse Detection above.

```dart
final listeners = await DeviceSafetyInfo.enabledNotificationListeners; // raw component names
final anyEnabled = await DeviceSafetyInfo.isAnyNotificationListenerEnabled;
```

### 16. Unknown Sources / Sideloading Check (Android only)
Checks whether install-unknown-apps ("sideloading") rights are currently granted. **Important
caveat, read before using**: on Android 8.0+ (the vast majority of active devices), this can only
answer *"has THIS app been granted install rights"* — it cannot detect whether some *other*
(potentially malicious) app has sideloading rights, because that per-app grant isn't readable
across app boundaries. A `false` result here is **not** evidence the device is free of sideloaded
malware. Only on Android 7.x does this reflect the old device-wide toggle. Requires
`REQUEST_INSTALL_PACKAGES` — see [Permissions](#permissions-android) below.

```dart
final canSideload = await DeviceSafetyInfo.isUnknownSourcesEnabled;
```

### 17. Call-Screening Role (Android only, API 29+)
Android's `RoleManager.getRoleHolders()` — the API that would reveal *which app* currently holds
the call-screening role — is a privileged system API third-party apps can't call. PhantomCall
abuses this role to silently block a bank's fraud-team calls, so the best available mitigation is
pointing the user at the OS role picker to review it themselves.

```dart
final available = await DeviceSafetyInfo.isCallScreeningRoleAvailable; // device capability
final heldByMe = await DeviceSafetyInfo.isCallScreeningRoleHeldByThisApp; // only meaningful if
                                                                            // your app screens calls
await DeviceSafetyInfo.openCallScreeningRoleSettings(); // opens the OS picker
```

### 18. Call Activity Detection
Detects when any call — a native SIM call or a VoIP call from WhatsApp/Teams/Skype/Meet/imo/etc.
— starts or ends. Like every other stream in this plugin, this is detect-only: no app is
identified (not achievable on either platform) and no lockdown/navigation policy is applied for
you. Native listeners only run while the stream has an active subscriber.

```dart
DeviceSafetyInfo.onCallActivityChanged.listen((event) {
  print('${event.source}: ${event.state}'); // e.g. CallActivitySource.simCall, .started
});

final isActive = await DeviceSafetyInfo.isCallActive; // point-in-time, no subscription needed
```

Android distinguishes `simCall` (via `TelephonyManager`, needs `READ_PHONE_STATE`) from `voipCall`
(inferred from system-wide audio routing state — works for any app, generically, with no per-app
cooperation needed). iOS reports `callKitObserved` (via CallKit's `CXCallObserver` — only sees
calls the calling app routed through CallKit) or `audioInterrupted` (a lower-confidence fallback
for VoIP apps that don't integrate CallKit, via `AVAudioSession` interruption notifications).

## Permissions (Android)

Add these to your `AndroidManifest.xml` if you use the respective features:

- **VPN & Version Check**:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  ```
- **Screenshot Detection**:
    - **Android 14+ (API 34+)**: No extra permission required.
    - **Android 13 (API 33)**: Requires `READ_MEDIA_IMAGES`.
    - **Android 10-12 (API 29-32)**: Requires `READ_EXTERNAL_STORAGE`.

  ```xml
  <!-- Required for screenshot detection on Android 10-12 -->
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
  <!-- Required for screenshot detection on Android 13 -->
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
  ```
- **Malware Package Detection**: not a runtime permission, but a required manifest declaration.
  Without it, `MalwarePackageDetector.isPackageInstalled()` always reports `false` for that package,
  even if it's actually installed (Android 11+ package visibility filtering):
  ```xml
  <queries>
    <package android:name="com.example.known.malware" />
    <!-- one <package> entry per package name you intend to check -->
  </queries>
  ```
- **Unknown Sources Check**: a normal-protection permission, auto-granted with no runtime
  prompt — but Google Play treats it as a restricted permission requiring justification in Play
  Console's Permissions Declaration form, since it's the same permission that gates actually
  installing packages (this plugin only ever queries it). If you don't use
  `isUnknownSourcesEnabled`, remove it to skip that review step entirely — this requires the
  `xmlns:tools` namespace on your `<manifest>` root (see `example/android/app/src/main/AndroidManifest.xml`
  for a working example of both):
  ```xml
  <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
  <!-- Or, if you don't use isUnknownSourcesEnabled: -->
  <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" tools:node="remove" />
  ```
- **Call Activity Detection (SIM-call signal)**: a **dangerous** runtime permission — this plugin
  cannot request it for you (no `permission_handler`-style dependency), so your app must request
  runtime grant itself. Without it, `onCallActivityChanged`/`isCallActive` silently degrade to
  VoIP-only detection rather than crashing:
  ```xml
  <uses-permission android:name="android.permission.READ_PHONE_STATE" />
  ```

## Features at a Glance

### Device Integrity & Tamper Detection

| Feature | Android | iOS | Description |
| :--- | :---: | :---: | :--- |
| **Root/Jailbreak Detection** | ✅ | ✅ | Check if the device is rooted or jailbroken. |
| **Real Device Check** | ✅ | ✅ | Distinguish between physical devices and emulators. |
| **Hook Detection** | ✅ | ✅ | Detect frameworks like Frida, Xposed, or Cydia Substrate. |
| **Debugger Detection** | ✅ | ✅ | Check if a debugger is attached to the process. |
| **Screen Lock Status** | ✅ | ✅ | Check if PIN, Pattern, or Biometrics are enabled. |
| **Store Install Check** | ✅ | ✅ | Verify if installed from Google Play / App Store. |
| **Developer Mode** | ✅ | ❌ | Check if Developer Options are enabled. |
| **External Storage Check** | ✅ | ❌ | Check if the app is installed on external storage. |

### Screenshot & Screen Recording Protection

| Feature | Android | iOS | Description |
| :--- | :---: | :---: | :--- |
| **Screenshot Detection** | ✅ | ✅ | Listen for real-time screenshot events. |
| **Screen Capture Status** | ✅ | ✅ | Detect if the screen is being recorded or mirrored. |
| **Block Screenshots** | ✅ | ✅ | Prevent screenshots and screen recordings in-app. |
| **Screenshot Overlay Modes** | ✅ | ✅ | Live blur/color/image overlay over the active screen whenever a capture/recording is detected — a branded placeholder instead of a plain black rectangle. |
| **Screen Recording Detection** | ✅ | ✅ | Detect an active screen-recording *session*, distinct from mirroring/external-display capture. Android needs API 35+; iOS shares the screen-capture signal — see the caveat in [§3](#3-screenshot--recording-management). |
| **SecureScreen widget** | ✅ | ✅ | Declarative, ref-counted widget that blocks screenshots while mounted. Pure Dart, no native code. |

### App Switcher & Privacy

| Feature | Android | iOS | Description |
| :--- | :---: | :---: | :--- |
| **Recents Overlay** | ✅ | ✅ | Add a custom color overlay in the app switcher. |
| **Hide from Recents** | ✅ | ❌ | Completely hide the app from the recent apps list. |
| **Clipboard Protection** | ✅ | ✅ | Copy sensitive text with an auto-clearing, preview-hidden clipboard entry; listen for clipboard changes. |
| **Overlay Attack Detection** | ✅ | ❌ | Detect/block touches while another app draws over yours (tapjacking). Not applicable on iOS — app sandboxing makes cross-app overlays structurally impossible. |

### Network, Updates & Malware Defenses

| Feature | Android | iOS | Description |
| :--- | :---: | :---: | :--- |
| **VPN Detection** | ✅ | ✅ | Real-time monitoring of VPN connection status. |
| **Version Checker** | ✅ | ✅ | Check for newer app versions on the store, with optional force/minimum-version enforcement. |
| **IOC / C2 Domain Blocking** | ✅ | ✅ | Look up a host against a blocklist you supply, for wiring into your own HTTP client or WebView. |
| **Malware Package Detection** | ✅ | ❌ | Check if a specific package is installed, to match against a known-malware list you supply. Requires a manifest declaration. |
| **Accessibility Abuse Detection** | ✅ | ❌ | List currently-enabled Accessibility services, a common abuse vector for screen-reading/auto-clicking malware. |
| **Notification Listener Check** | ✅ | ❌ | List apps with notification-listener access — a common OTP/SMS-theft vector for banking trojans. |
| **Unknown Sources Check** | ✅ | ❌ | Check whether this app has been granted install-unknown-apps rights. See caveats in [§16](#16-unknown-sources--sideloading-check-android-only). |
| **Call-Screening Role** | ✅ | ❌ | Check the call-screening role's availability/self-held status, and open the OS picker to review the current holder. Android 10+ (API 29+). |
| **Play Protect Status** | ✅ | ❌ | Read whether Google Play Protect scanning is enabled. |

### Session & Risk Utilities

| Feature | Android | iOS | Description |
| :--- | :---: | :---: | :--- |
| **Idle Session Timeout** | ✅ | ✅ | Widget wrapper that fires a callback after a period of no touch activity anywhere in the app. |
| **Risk Summary** | ✅ | ✅ | Aggregates several checks above into a single list of plain-language risk flags. |
| **Call Activity Detection** | ✅ | ✅ | Detect when any call — native or VoIP (WhatsApp/Teams/Skype/etc.) — starts or ends, without identifying which app. |

## Platform Support

| | Android | iOS |
| :--- | :---: | :---: |
| Minimum version | API 24 (Android 7.0) | iOS 16.0 |
| Language | Kotlin | Swift |

## Contributing

Issues and pull requests are welcome at the
[issue tracker](https://github.com/devamitkumartiwari/devicesafetyinfo/issues). Before opening a
PR for a new check or feature, please open an issue first to discuss the approach — this package
deliberately favors primitives over opinionated UI and avoids adding third-party dependencies, so
it helps to align on shape before writing code.

## License

MIT — see [LICENSE](LICENSE).
