# device_safety_info (Null-Safety)

A Flutter plugin to detect if a device is jailbroken/rooted, running in an emulator, and to check for other security vulnerabilities like screen capture and hooking frameworks.

## Features

- **Jailbreak/Root Detection**: Checks if the device is jailbroken (iOS) or rooted (Android).
- **Emulator/Simulator Detection**: Determines if the app is running on a simulator/emulator or a real device.
- **App Install Source**: Verifies if the app was installed from the App Store (iOS) or Play Store (Android).
- **Screen Lock**: Checks if a screen lock (passcode, Touch ID, Face ID) is enabled.
- **External Storage**: Detects if the app is running on external storage (Android only).
- **Developer Mode**: Checks if Developer Options are enabled (Android only).
- **VPN Status**: Monitors the device's VPN connection state.
- **App Version Check**: Checks for new versions of the app in the App Store/Play Store.
- **Screen Capture Detection**: Detects if the screen is being captured (recorded or mirrored).
- **Screen Capture Prevention**: Blocks screenshots and screen recordings.
- **Hook Detection**: Detects if the app is being targeted by hooking frameworks like Frida or Cydia Substrate.
- **Hide App in Recents**: Programmatically hide or show the app in the recent apps list (Android only).

## Platform Support

| Feature                      | Android | iOS |
| ---------------------------- | :-----: | :-: |
| Jailbreak/Root Detection     |    ✅    |  ✅  |
| Emulator/Simulator Detection |    ✅    |  ✅  |
| Installed from Store         |    ✅    |  ✅  |
| Screen Lock Enabled          |    ✅    |  ✅  |
| Hooking/Reverse-Engineering  |    ✅    |  ✅  |
| Screen Capture Detection     |    ✅    |  ✅  |
| Screen Capture Prevention    |    ✅    |  ✅  |
| VPN Status Monitoring        |    ✅    |  ✅  |
| App Store Version Check      |    ✅    |  ✅  |
| Exit App on Detection        |    ✅    |  ✅  |
| Developer Mode Enabled       |    ✅    |  ❌  |
| Running on External Storage  |    ✅    |  ❌  |
| Hide App in Recents          |    ✅    |  ❌  |
| Prompt for Uninstall         |    ✅    |  ❌  |


## Getting Started

In your flutter project add the dependency:

```yml
dependencies:
  
  device_safety_info: ^1.0.4
```

## Usage

#### Importing package

```dart
import 'package:device_safety_info/device_safety_info.dart';
```

#### Using it

**Checks whether device is JailBroken (iOS) or Rooted (Android)?**

```dart
bool isRootedDevice = await DeviceSafetyInfo.isRootedDevice;
```

**Checks whether device is a real device or an Emulator/Simulator**

```dart
bool isRealDevice = await DeviceSafetyInfo.isRealDevice;
```

**Checks if the app was installed from the App Store or Google Play**

```dart
bool isInstalledFromStore = await DeviceSafetyInfo.isInstalledFromStore;
```

**Checks whether a screen lock is enabled**

```dart
bool isScreenLock = await DeviceSafetyInfo.isScreenLock;
```

**Checks if the screen is being captured (recorded or mirrored)**
This stream will emit `true` if screen capture is detected.

```dart
DeviceSafetyInfo.onScreenCapturedChanged.listen((bool isCaptured) {
  print('Screen is being captured: $isCaptured');
});

// You can also get the current status directly
bool isScreenCaptured = await DeviceSafetyInfo.isScreenCaptured;
```

**Blocks screenshots and screen recordings (Android & iOS)**
On Android, this uses `FLAG_SECURE`. On iOS, it overlays a view to hide the content when the screen is captured.

```dart
// To block
await DeviceSafetyInfo.blockScreenshots(block: true);

// To unblock
await DeviceSafetyInfo.blockScreenshots(block: false);
```

**Checks for hooking frameworks like Frida or Cydia Substrate (Android & iOS)**
This helps detect if the app is being reverse-engineered.

```dart
// Simple check
bool isHooked = await DeviceSafetyInfo.isHooked;

// Check and exit the app if hooked (works on both platforms)
await DeviceSafetyInfo.checkHooked(exitProcessIfTrue: true);

// Check and prompt for uninstall if hooked (Android only)
await DeviceSafetyInfo.checkHooked(uninstallIfTrue: true);
```

**Hides or shows the app in the recent apps list (Android Only)**

```dart
// To hide
await DeviceSafetyInfo.hideMenu(hide: true);

// To show
await DeviceSafetyInfo.hideMenu(hide: false);
```

**Checks whether the application is running on external storage (Android Only)**

```dart
bool isExternalStorage = await DeviceSafetyInfo.isExternalStorage;
```

**Checks whether Developer Options are enabled on the device (Android Only)**

```dart
bool isDeveloperMode = await DeviceSafetyInfo.isDeveloperMode;
```

**Checks VPN status on device**
For checking VPN status device must be connected to the internet.
For Android, add `<uses-permission android:name="android.permission.INTERNET"/>` to your `AndroidManifest.xml`.

```dart
final vpnCheck = VPNCheck();

vpnCheck.vpnState.listen((state) {
      if (state == VPNState.CONNECTED) {
        if (kDebugMode) {
          print("VPN connected.");
        }
      } else {
        if (kDebugMode) {
          print("VPN disconnected.");
        }
      }
});
```

**Checks if a new app version is available**
Requires an internet connection.
For Android, add `<uses-permission android:name="android.permission.INTERNET"/>` to your `AndroidManifest.xml`.

```dart
appVersionStatus() {
    final newVersion = NewVersionChecker(
      iOSId: '', // Your iOS app ID
      androidId: '', // Your Android app ID
    );
    statusCheck(newVersion);
}

statusCheck(NewVersionChecker newVersion) async {
    try {
      final status = await newVersion.getVersionStatus();

      if (status != null) {
        debugPrint(status.appStoreLink);
        debugPrint(status.localVersion);
        debugPrint(status.storeVersion);
        debugPrint(status.canUpdate.toString());

        if (status.canUpdate) {
         // New version available
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
}
```
