# device_safety_info

Flutter security plugin: root/jailbreak, hook, and tamper detection; overlay-attack, clipboard,
malware-package, and accessibility-abuse protection; IOC domain blocking; VPN, screen-capture, and
session-idle monitoring; and app-update checks.

## Getting Started

In your flutter project add the dependency:

```yml
dependencies:
  device_safety_info: ^1.3.0
```

## Features

| Feature | Android | iOS | Description |
| :--- | :---: | :---: | :--- |
| **Root/Jailbreak Detection** | ✅ | ✅ | Check if the device is rooted or jailbroken. |
| **Real Device Check** | ✅ | ✅ | Distinguish between physical devices and emulators. |
| **Hook Detection** | ✅ | ✅ | Detect frameworks like Frida, Xposed, or Cydia Substrate. |
| **Debugger Detection** | ✅ | ✅ | Check if a debugger is attached to the process. |
| **Screen Lock Status** | ✅ | ✅ | Check if PIN, Pattern, or Biometrics are enabled. |
| **VPN Detection** | ✅ | ✅ | Real-time monitoring of VPN connection status. |
| **Store Install Check** | ✅ | ✅ | Verify if installed from Google Play / App Store. |
| **Screenshot Detection** | ✅ | ✅ | Listen for real-time screenshot events. |
| **Screen Capture Status** | ✅ | ✅ | Detect if the screen is being recorded or mirrored. |
| **Block Screenshots** | ✅ | ✅ | Prevent screenshots and screen recordings in-app. |
| **Recents Overlay** | ✅ | ✅ | Add a custom color overlay in the app switcher. |
| **External Storage Check** | ✅ | ❌ | Check if app is on external storage. |
| **Developer Mode** | ✅ | ❌ | Check if Developer Options are enabled. |
| **Hide from Recents** | ✅ | ❌ | Completely hide the app from the recent apps list. |
| **Version Checker** | ✅ | ✅ | Check for newer app versions on the store. |
| **Overlay Attack Detection** | ✅ | ❌ | Detect/block touches while another app is drawing over yours (tapjacking). Not applicable on iOS — app sandboxing makes cross-app overlays structurally impossible. |
| **Clipboard Protection** | ✅ | ✅ | Copy sensitive text with an auto-clearing, preview-hidden clipboard entry; listen for clipboard changes. |
| **IOC / C2 Domain Blocking** | ✅ | ✅ | Look up a host against a blocklist you supply, for wiring into your own HTTP client or WebView. |
| **Malware Package Detection** | ✅ | ❌ | Check if a specific package is installed, to match against a known-malware list you supply. Requires a manifest declaration — see below. Not applicable on iOS. |
| **Accessibility Abuse Detection** | ✅ | ❌ | List currently-enabled Accessibility services, a common abuse vector for screen-reading/auto-clicking malware. Not applicable on iOS — no public API. |
| **Play Protect Status** | ✅ | ❌ | Read whether Google Play Protect scanning is enabled. Android/Google Play concept only. |
| **Idle Session Timeout** | ✅ | ✅ | Widget wrapper that fires a callback after a period of no touch activity anywhere in the app. |
| **Risk Summary** | ✅ | ✅ | Aggregates several checks above into a single list of plain-language risk flags. |

## Usage

#### Importing package

```dart
import 'package:device_safety_info/device_safety_info.dart';
```

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
```

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
  if (state == VPNState.CONNECTED) {
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
    );

    final status = await newVersion.getVersionStatus();
    if (status != null && status.canUpdate) {
        print("New version: ${status.storeVersion} (Local: ${status.localVersion})");
        print("Update Link: ${status.appStoreLink}");
    }
}
```

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
