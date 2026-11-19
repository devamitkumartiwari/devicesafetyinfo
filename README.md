# device_safety_info

[![pub package](https://img.shields.io/pub/v/device_safety_info.svg)](https://pub.dev/packages/device_safety_info)
[![pub points](https://img.shields.io/pub/points/device_safety_info)](https://pub.dev/packages/device_safety_info/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![platform](https://img.shields.io/badge/platform-android%20%7C%20ios-lightgrey.svg)](#platform-support)

Device and app security for Flutter apps (banking, payments, health):

- **Detection** with configurable policies: root/jailbreak, emulator, hooking (Frida, Xposed),
  debugger, device posture, accessibility and notification-listener abuse, VPN/proxy, screen
  capture, known malware.
- **Protection**: screenshot and recording blocking, capture overlay, app-switcher privacy,
  secure clipboard, tapjacking protection, idle timeout.
- **Attestation tokens**: Google Play Integrity, Apple App Attest and DeviceCheck.

Every check returns a typed `CheckResult` with the signals it found. **Your app decides** what a
detection means; the package never closes or uninstalls the app.

> Upgrading from 1.x? See [MIGRATION.md](MIGRATION.md).

## Contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [How checks work](#how-checks-work)
- [Configuration](#configuration)
- [Signal catalogue](#signal-catalogue)
- [Threat stream](#threat-stream)
- [Protection APIs](#protection-apis)
- [Attestation](#attestation)
- [Other tools](#other-tools)
- [Testing your app](#testing-your-app)
- [Android permissions](#android-permissions)
- [Platform support](#platform-support)

## Installation

```yaml
dependencies:
  device_safety_info: ^2.0.0
```

Requirements: **Flutter 3.50+ / Dart 3.14+**, Android `minSdk` 24, iOS 16.

- **iOS uses Swift Package Manager only.** CocoaPods isn't supported (Flutter enables SwiftPM by
  default since 3.50). If your app still has a `Podfile` only for other plugins, that's fine.
- **Android uses built-in Kotlin** (AGP 9+). The plugin applies no Kotlin Gradle plugin.
- The native C checks are compiled by a Dart **build hook** for Android and iOS; there's nothing
  to configure.

## Quick start

```dart
import 'package:device_safety_info/device_safety_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceSafety.initialize(DeviceSafetyConfig(
    accessibilityAllowlist: {'com.google.android.marvin.talkback'},
  ));
  runApp(const MyApp());
}

// Before a sensitive action:
final report = await DeviceSafety.assess();
if (report.detected) {
  for (final flag in report.flags) {
    print('${flag.title}: ${flag.description}');
  }
}

// Or a single check:
final root = await DeviceSafety.root.check();
if (root.detected) blockPayments();
print(root.signals); // e.g. [root.su_executable:/system/xbin/su(high)]
```

## How checks work

Every detection API (`DeviceSafety.root`, `.emulator`, `.hooking`, `.debugger`,
`.posture.screenLock`, `.accessibility`, `.vpn`, `.screen`, `.malware`, ...) has the same shape:

```dart
Future<CheckResult> check({bool refresh = false});
Future<bool> isDetected({bool refresh = false});
```

A `CheckResult` has:

| Field | Meaning |
|---|---|
| `status` | `completed`, `unsupported` (not on this platform), `error`, `timedOut`, or `skipped` (policy `off`) |
| `signals` | every indicator found, each with an `id` and a `RiskLevel` (`low` / `high`) |
| `level` | the highest signal level |
| `detected` | the decision, with your policy already applied |
| `policy`, `error`, `elapsed` | what was applied, why it failed, how long it took |

Detection APIs **never throw**. Results are cached (30 s by default), concurrent calls share one
native call, and every check has a timeout (5 s by default).

`DeviceSafety.assess()` runs many checks in **one platform round trip**, in parallel on the
native side and alongside the native C checks, and returns a `RiskAssessment` (`results`,
`detected`, `flags`, `level`, `failed`).

### Policies

Each signal is **high** (clear evidence, e.g. an executable `su`, Frida in memory) or **low**
(weak evidence that normal devices also show, e.g. stock `busybox`, an unlocked bootloader, a
VPN). The policy decides which count:

| Policy | Detected when |
|---|---|
| `RiskPolicy.standard` (default) | any **high** signal |
| `RiskPolicy.strict` | any signal |
| `RiskPolicy.off` | never; the check doesn't run |

### Fail modes

What a check reports when it errors or times out:

| Fail mode | Error / timeout counts as |
|---|---|
| `FailMode.open` (default) | not detected |
| `FailMode.closed` | detected. Use for security-critical checks an attacker might deliberately break. |

## Configuration

```dart
await DeviceSafety.initialize(DeviceSafetyConfig(
  defaultPolicy: .standard,
  policies: {CheckType.vpn: .strict, CheckType.developerMode: .off},
  signalOverrides: {
    'vpn.active': .high,              // count VPNs under the standard policy
    'emulator.generic_build': .none,  // ignore this signal entirely
  },
  failMode: .open,
  failModes: {CheckType.root: .closed, CheckType.hooking: .closed},
  cacheTtl: Duration(seconds: 30),
  timeout: Duration(seconds: 5),
  accessibilityAllowlist: {'com.google.android.marvin.talkback'},
  notificationListenerAllowlist: {'com.google.android.wearable.app'},
  malwarePackages: {'com.example.known.malware'},
  iocBlocklist: {'evil.example', '*.phishing.example'},
  logger: (message, {error, stackTrace}) => log(message, error: error),
));
```

`initialize` is optional (the defaults apply otherwise) and can be called again at any time; it
clears cached results. Signal overrides match the part of the id before `:`, so
`'malware.installed'` matches `malware.installed:com.example.app`.

## Signal catalogue

| Check (`CheckType`) | High (standard and strict) | Low (strict only) |
|---|---|---|
| `root` (Android) | `root.su_executable`, `root.binary_executable`, `root.manager_file` (Magisk, Superuser), `root.ro_secure_off`, `root.native_files` | `root.su_present`, `root.binary_present`, `root.busybox`, `root.test_keys`, `root.recovery_boot`, `root.verifiedboot_unlocked`, `root.native_su_present` |
| `root` (iOS jailbreak) | `root.jailbreak_<check>` for each failed IOSSecuritySuite check | `root.jailbreak_urlSchemes` |
| `emulator` | `emulator.hardware`, `emulator.qemu`, `emulator.build_name`, `emulator.generic_fingerprint`, `emulator.generic_brand_device`, `emulator.simulator` | `emulator.generic_build` |
| `hooking` | `hooking.frida_maps`, `hooking.frida_port`, `hooking.frida_server`, `hooking.xposed`, `hooking.xposed_class`, `hooking.substrate`, `hooking.shadowhook`, `hooking.dyld_injection`, iOS `hooking.<check>` | |
| `debugger` | `debugger.attached`, `debugger.traced` | `debugger.debuggable_build` |
| `developerMode` | | `developer_mode.enabled`, `developer_mode.adb_enabled` |
| `screenLock` | `screen_lock.none` | |
| `storeInstall` | | `store_install.unknown_installer` |
| `externalStorage` | | `external_storage.installed` |
| `unknownSources` | | `unknown_sources.allowed` |
| `playProtect` | `play_protect.disabled` | `play_protect.unknown` |
| `accessibility` | `accessibility.window_reader:<service>` | `accessibility.service:<service>` |
| `notificationListener` | `notification_listener.untrusted:<listener>` | |
| `vpn` | | `vpn.active`, `vpn.http_proxy` |
| `screenCapture` | `screen_capture.recording`, `screen_capture.mirroring` | `screen_capture.external_display` |
| `malware` | `malware.installed:<package>` | |

Signals whose `source` is `SignalSource.ffi` come from C code (`src/dsi.c`) called through FFI on a
background isolate. It's harder to hook than Java/Kotlin or Swift.

## Threat stream

```dart
DeviceSafety.threats.listen((ThreatEvent e) {
  // e.type: CheckType, e.detail: 'screenshot' / 'capture_started' / 'obscured_touch' /
  // 'vpn_connected' / null for a check that became detected, e.result: the CheckResult
  analytics.log('threat', e.type.name);
});
```

Events fire when a check **becomes** detected, and for live events while the stream is listened
to: screenshots, capture or recording starting, tapjacking touches, VPN connecting.

The package never terminates the app. If you decide to, call `DeviceSafety.terminateApp()`.

## Protection APIs

Action APIs throw typed exceptions (`UnsupportedPlatformException`,
`PermissionMissingException`, `NativeFailureException`).

```dart
// Screenshots and recording
await DeviceSafety.screen.blockScreenshots();           // or wrap a page in SecureScreen
await DeviceSafety.screen.setOverlayMode(.blur);         // shown only while captured
DeviceSafety.screen.onScreenshot.listen((at) => warn());
DeviceSafety.screen.captureChanges.listen((captured) => hideBalance(captured));

const SecureScreen(child: PaymentPage());                // blocks while mounted

// App switcher
await DeviceSafety.appSwitcher.setOverlay(argbColor: 0xFF000000);
await DeviceSafety.appSwitcher.hideFromRecents();        // Android only

// Clipboard
await DeviceSafety.clipboard.copySecure('123456', clearAfter: Duration(seconds: 30));

// Tapjacking (Android)
await DeviceSafety.overlayAttack.blockTouchesWhenObscured();

// Idle timeout
IdleTimeoutGuard(timeout: Duration(minutes: 5), onTimeout: lock, child: app);
```

## Attestation

Tokens prove nothing on the device. **Always verify them on your server**; see
[`example/server_dotnet`](example/server_dotnet) for a reference ASP.NET Core verifier.

```dart
// Android: Play Integrity (the app adds com.google.android.play:integrity)
await DeviceSafety.integrity.preparePlayIntegrity(cloudProjectNumber: 123456789012);
final token = await DeviceSafety.integrity.requestPlayIntegrityToken(requestHash: hash);

// iOS: App Attest (needs the appattest-environment entitlement)
final keyId = await DeviceSafety.integrity.generateAppAttestKey();
final attestation = await DeviceSafety.integrity.attestAppAttestKey(
  keyId: keyId, challenge: serverChallenge);
final assertion = await DeviceSafety.integrity.generateAppAttestAssertion(
  keyId: keyId, clientData: requestJson);
```

Failures throw `AttestationException` with an `AttestationErrorCode` (`notPrepared`,
`providerInvalid`, `network`, `tooManyRequests`, `invalidKey`, `unsupported`, ...).

## Other tools

```dart
DeviceSafety.ioc.isBlocked(uri.host);                   // IOC domain blocklist
await DeviceSafety.ioc.loadRemoteBlocklist(feedUri);
await DeviceSafety.calls.isCallActive();                // pause OTP entry during calls
DeviceSafety.calls.changes.listen(...);
await DeviceSafety.callScreening.requestRole();         // Android call screening role
final status = await DeviceSafety.versionCheck.status(minAppVersion: '2.0.0');
if (status?.urgency == UpdateUrgency.required) forceUpdate(status!.storeLink);
```

## Testing your app

`package:device_safety_info/testing.dart` exports the platform interfaces so your tests can fake
them:

```dart
class RootedDevice extends Fake implements RootHostApi {
  @override
  Future<CheckReportMsg> rootCheck() async => CheckReportMsg(
    signals: [SignalMsg(id: 'root.su_executable', level: SignalLevelMsg.high)],
    supported: true,
  );
}

setUp(() => DeviceSafety.forTesting(
  platform: DeviceSafetyPlatform(root: RootedDevice(), ffi: const FakeNativeChecks()),
));
tearDown(DeviceSafety.resetForTesting);
```

## Android permissions

The plugin declares only `ACCESS_NETWORK_STATE`, `DETECT_SCREEN_CAPTURE` and
`DETECT_SCREEN_RECORDING` (all normal, auto-granted). Add these yourself if you use the feature:

- **SIM call detection** (`DeviceSafety.calls`): `READ_PHONE_STATE`, a dangerous permission your
  app must also request at runtime. **2.0 no longer declares it for you.** Without it, VoIP and
  audio-based detection still work.
  ```xml
  <uses-permission android:name="android.permission.READ_PHONE_STATE" />
  ```
- **Screenshot events on Android 10 to 13** (Android 14+ needs nothing):
  ```xml
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
  ```
- **Malware package detection**: declare each package you check (Android 11+ package visibility):
  ```xml
  <queries>
    <package android:name="com.example.known.malware" />
  </queries>
  ```
- **Unknown sources check**: `REQUEST_INSTALL_PACKAGES` (Google Play asks you to justify it).
  Without it the check reports nothing on Android 8+.
- **Version check / IOC feeds**: `INTERNET`.

## Platform support

| Feature | Android | iOS |
|---|---|---|
| Root / jailbreak, emulator, hooking, debugger | ✅ | ✅ |
| Screen lock, store install | ✅ | ✅ |
| Developer mode, external storage, unknown sources, Play Protect | ✅ | unsupported |
| Accessibility / notification-listener abuse, malware packages | ✅ | unsupported |
| VPN / proxy, screen capture | ✅ | ✅ |
| Recording state | Android 15+ | ✅ (same as capture) |
| Screenshot blocking, capture overlay, app-switcher overlay | ✅ | ✅ |
| Hide from recents, tapjacking protection, call screening role | ✅ | unsupported |
| Secure clipboard, call activity, version check, IOC | ✅ | ✅ |
| Play Integrity | ✅ | — |
| App Attest, DeviceCheck | — | ✅ |

"unsupported" checks return `CheckStatus.unsupported`; unsupported actions throw
`UnsupportedPlatformException`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
