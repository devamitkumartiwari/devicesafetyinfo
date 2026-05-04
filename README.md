# device_safety_info

Flutter JailBreak, Rooted, Emulator/Simulator, External storage, VPN detection, and App Security features.

## Getting Started

In your flutter project add the dependency:

```yml
dependencies:
  device_safety_info: ^1.1.0
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

## Permissions (Android)

Add these to your `AndroidManifest.xml` if you use the respective features:

- **VPN & Version Check**:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  ```
- **Screenshot Detection (for Android 10-13)**:
  ```xml
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
  ```
  *(Note: Android 14+ uses the new system API and doesn't require extra storage permissions).*
