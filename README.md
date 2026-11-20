# device_safety_info

[![pub package](https://img.shields.io/pub/v/device_safety_info.svg)](https://pub.dev/packages/device_safety_info)
[![pub points](https://img.shields.io/pub/points/device_safety_info)](https://pub.dev/packages/device_safety_info/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![platform](https://img.shields.io/badge/platform-android%20%7C%20ios-lightgrey.svg)](#platform-support)

Device and app security for Flutter apps that handle money, health or identity.

- **Detect** a risky environment: root and jailbreak, emulators, hooking frameworks (Frida,
  Xposed, Zygisk), debuggers, a repackaged app, weak device posture, accessibility and
  notification-listener abuse, VPNs and proxies, screen capture and known malware.
- **Protect** sensitive screens: block screenshots and recording, cover the app while the screen
  is captured or in the app switcher, copy one-time codes safely, block tapjacking, lock idle
  sessions.
- **Attest** the app and device to your server with Google Play Integrity, Apple App Attest and
  DeviceCheck.

Every check returns a typed result listing what it found, and **your app decides** what that
means: the package never closes or uninstalls the app.

> **Upgrading from 1.x?** 2.0.0 is a breaking release. [MIGRATION.md](MIGRATION.md) lists every
> 1.x API and its replacement.

## Contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [How checks work](#how-checks-work)
- [Configuration](#configuration)
- [Detection checks](#detection-checks)
- [Signal catalogue](#signal-catalogue)
- [Threat stream](#threat-stream)
- [Protection](#protection)
- [Attestation](#attestation)
- [Other tools](#other-tools)
- [Limits of on-device checks](#limits-of-on-device-checks)
- [Android setup](#android-setup)
- [iOS setup](#ios-setup)
- [Testing your app](#testing-your-app)
- [Example app](#example-app)
- [Platform support](#platform-support)
- [Performance](#performance)

## Installation

```yaml
dependencies:
  device_safety_info: ^2.0.0
```

Requirements:

- **Flutter 3.50+ / Dart 3.14+**
- **Android** `minSdk` 24. The plugin uses built-in Kotlin (AGP 9+) and applies no Kotlin Gradle
  plugin.
- **iOS** 16, with **Swift Package Manager**. CocoaPods isn't supported; Flutter uses SwiftPM by
  default since 3.50.

The native C checks are compiled by a Dart build hook for Android and iOS. There's nothing to
configure.

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

// Before a sensitive action, run every check in one call:
final report = await DeviceSafety.assess();
if (report.detected) {
  for (final flag in report.flags) {
    showWarning(flag.title, flag.description);
  }
}

// Or run one check:
final root = await DeviceSafety.root.check();
if (root.detected) blockPayments();
print(root.signals); // [root.su_executable:/system/xbin/su(high)]
```

## How checks work

### One shape for every check

Every detection API has the same two methods:

```dart
Future<CheckResult> check({bool refresh = false});
Future<bool> isDetected({bool refresh = false});
```

A `CheckResult` tells you what happened and why:

| Field | Meaning |
|---|---|
| `status` | `completed`, `unsupported` (not on this platform), `error`, `timedOut`, or `skipped` (policy `off`) |
| `signals` | every indicator found, each with an `id`, a `RiskLevel` (`low` / `high`) and a `source` |
| `level` | the highest signal level |
| `detected` | the decision, with your policy already applied |
| `policy`, `error`, `elapsed` | what was applied, why it failed, how long it took |

Detection APIs **never throw**. A check that fails reports `CheckStatus.error` or `timedOut`
instead of pretending the device is clean.

### Signals, levels and policies

Each signal is **high** (clear evidence that a normal device doesn't produce, such as an
executable `su` or Frida in memory) or **low** (weak evidence that normal devices also show, such
as a stock `busybox`, an unlocked bootloader or a VPN). The policy decides which count:

| Policy | Detected when |
|---|---|
| `RiskPolicy.standard` (default) | any **high** signal |
| `RiskPolicy.strict` | any signal |
| `RiskPolicy.off` | never; the check doesn't run |

### Fail modes

What a check reports when it errors or times out:

| Fail mode | An error or timeout counts as |
|---|---|
| `FailMode.open` (default) | not detected |
| `FailMode.closed` | detected |

`open` is the default so a flaky platform call never locks honest users out. Under `open`, an
attacker who makes a check *fail* (for example by hooking the platform call so it throws) gets
"not detected". For banking-grade apps, close the security-critical checks:

```dart
failModes: {CheckType.root: .closed, CheckType.hooking: .closed, CheckType.debugger: .closed},
```

Two defences apply in either mode:

- `root`, `hooking` and `debugger` each combine a Kotlin/Swift half with a C half. If the platform
  half fails but the C half found **high** evidence, the check still completes as detected and
  adds `integrity.platform_check_failed`.
- On Android, a root checker that throws adds `root.checker_error:<checker>` (low) instead of
  counting as clean. If every checker throws, the check reports an error.

### Caching and speed

- Results are cached for 30 s by default (`cacheTtl`); pass `refresh: true` to bypass the cache.
  `hooking` and `debugger` are never cached, because Frida or a debugger can attach at any moment.
- Concurrent calls for the same check share one native call.
- Every check has a timeout (5 s by default).
- `DeviceSafety.assess()` runs many checks in **one platform round trip**, in parallel on the
  native side and alongside the C checks.
- Nothing blocking runs on the Flutter UI isolate or the Android main thread.

## Configuration

`initialize` is optional: without it, the defaults below apply. It can be called again at any
time, which clears cached results.

```dart
await DeviceSafety.initialize(DeviceSafetyConfig(
  defaultPolicy: .standard,
  policies: {CheckType.vpn: .strict, CheckType.developerMode: .off},
  signalOverrides: {
    'vpn.active': .high,             // count VPNs under the standard policy
    'emulator.generic_build': .none, // ignore this signal entirely
  },
  failMode: .open,
  failModes: {CheckType.root: .closed, CheckType.hooking: .closed},
  cacheTtl: Duration(seconds: 30),
  timeout: Duration(seconds: 5),
  accessibilityAllowlist: {'com.google.android.marvin.talkback'},
  notificationListenerAllowlist: {'com.google.android.projection.gearhead'},
  trustSystemApps: true,
  malwarePackages: {'com.example.known.malware'},
  iocBlocklist: {'evil.example', '*.phishing.example'},
  expectedSigningCertificates: {'AB:CD:...'}, // tampering check (Android)
  expectedIosTeamId: 'ABCDE12345',            // tampering check (iOS)
  logger: (message, {error, stackTrace}) => log(message, error: error),
));
```

| Option | Default | Purpose |
|---|---|---|
| `defaultPolicy` | `standard` | Policy for checks not listed in `policies` |
| `policies` | empty | Per-check policy |
| `signalOverrides` | empty | Change one signal's level by id; `.none` ignores it |
| `failMode` / `failModes` | `open` | What errors and timeouts count as |
| `cacheTtl` | 30 s | How long results are reused; `Duration.zero` disables caching |
| `timeout` | 5 s | When a check is reported as `timedOut` |
| `accessibilityAllowlist` | empty | Trusted accessibility services (component or package name) |
| `notificationListenerAllowlist` | empty | Trusted notification listeners (component or package name) |
| `trustSystemApps` | `true` | Don't report services and listeners from preinstalled system apps |
| `malwarePackages` | empty | Packages the malware check looks for |
| `iocBlocklist` | empty | Initial IOC domain blocklist |
| `expectedSigningCertificates` | empty | SHA-256 of your Android signing certificates |
| `expectedIosTeamId` | none | Your Apple team id, for re-signed iOS builds |
| `logger` | none | Receives diagnostic messages |

Signal overrides match the part of the id before `:`, so `'malware.installed'` matches
`malware.installed:com.example.app`.

### Allowlists and system apps

The accessibility and notification-listener checks report every enabled service or listener that
isn't allowlisted. Preinstalled system apps (and updates to them) are trusted by default, because
nearly every phone has some; set `trustSystemApps: false` to report them too.

Some legitimate apps are installed from Play rather than preinstalled, so they aren't system apps
and need allowlisting. Common ones are Android Auto (`com.google.android.projection.gearhead`),
Wear OS (`com.google.android.wearable.app`), Galaxy Wearable
(`com.samsung.android.app.watchmanager`) and TalkBack (`com.google.android.marvin.talkback`). The
package doesn't allowlist them for you: a sideloaded app could reuse a package name, so allowlist
only what fits your users.

## Detection checks

| API | `CheckType` | Finds |
|---|---|---|
| `DeviceSafety.root` | `root` | Root (Android) or jailbreak (iOS) |
| `DeviceSafety.emulator` | `emulator` | Emulator or simulator |
| `DeviceSafety.hooking` | `hooking` | Frida, Xposed/LSPosed, Zygisk, Substrate, injected libraries |
| `DeviceSafety.debugger` | `debugger` | An attached debugger |
| `DeviceSafety.tampering` | `tampering` | A repackaged or re-signed app |
| `DeviceSafety.posture.developerMode` | `developerMode` | Developer options or USB debugging on |
| `DeviceSafety.posture.screenLock` | `screenLock` | No secure screen lock |
| `DeviceSafety.posture.storeInstall` | `storeInstall` | Not installed from an official store |
| `DeviceSafety.posture.externalStorage` | `externalStorage` | App installed on external storage |
| `DeviceSafety.posture.unknownSources` | `unknownSources` | The app may install other apps |
| `DeviceSafety.posture.playProtect` | `playProtect` | Google Play Protect off or unknown |
| `DeviceSafety.accessibility` | `accessibility` | Untrusted accessibility services |
| `DeviceSafety.notificationListeners` | `notificationListener` | Untrusted notification listeners |
| `DeviceSafety.vpn` | `vpn` | An active VPN or HTTP proxy |
| `DeviceSafety.screen` | `screenCapture` | Screen recording, mirroring or an external display |
| `DeviceSafety.malware` | `malware` | Installed apps from your malware list |

`CheckType.overlayAttack` exists only for [threat events](#threat-stream); tapjacking is an
event, not a state to poll.

### Assessing everything at once

```dart
final report = await DeviceSafety.assess();            // every detection check
final login = await DeviceSafety.assess(checks: [
  CheckType.root, CheckType.hooking, CheckType.tampering,
]);

report.detected;  // any check detected?
report.flags;     // plain-language title and description per detected check
report.results;   // Map<CheckType, CheckResult>
report.level;     // highest signal level overall
report.failed;    // checks that errored or timed out
```

### Tampering (repackaged apps)

A repackaged app is signed with someone else's key. Configure the certificates you sign with:

```dart
// Find your certificate's SHA-256 once (or copy it from Play Console > App integrity):
print((await DeviceSafety.tampering.signingInfo()).certificateSha256);

await DeviceSafety.initialize(DeviceSafetyConfig(
  expectedSigningCertificates: {'AB:CD:...'}, // Play app signing key (+ upload key for sideloads)
  expectedIosTeamId: 'ABCDE12345',
));
```

Without `expectedSigningCertificates`, the Android check reports `unsupported`.

## Signal catalogue

Every signal id has the form `check.signal`, optionally followed by `:detail` (a path, a
property value, a library or a package name).

| Check | High (standard and strict) | Low (strict only) |
|---|---|---|
| `root` (Android) | `root.su_executable`, `root.binary_executable` (`su`, `magisk`, `ksud`, `apd`, `resetprop` in `PATH`), `root.manager_file` (Magisk, KernelSU, APatch, SuperSU files), `root.manager_app` (root managers and LSPosed installed), `root.mount_marker`, `root.system_rw`, `root.system_overlay` (systemless-root mounts, read-write system partitions), `root.ro_secure_off`, `root.adb_root`, `root.selinux_permissive`, `root.selinux_disabled`, `root.lineage_root_access`, `root.debuggable_user_build`, `root.native_files`, `root.native_mounts` | `root.su_present`, `root.binary_present`, `root.busybox`, `root.cloak_app` (RootCloak, Hide My Applist, Lucky Patcher...), `root.test_keys`, `root.debug_build`, `root.recovery_boot`, `root.verifiedboot_unlocked`, `root.bootloader_unlocked`, `root.mock_location_allowed`, `root.native_su_present`, `root.checker_error` |
| `root` (iOS) | `root.jailbreak_<check>` for each failed IOSSecuritySuite check, `root.native_jailbreak_files` (`/var/jb`, Sileo, Substrate... checked from C) | `root.jailbreak_urlSchemes` |
| `emulator` | `emulator.hardware`, `emulator.qemu`, `emulator.qemu_prop`, `emulator.file` (QEMU pipes; Genymotion, BlueStacks, Nox, MEmu, LDPlayer files), `emulator.build_name`, `emulator.generic_fingerprint`, `emulator.generic_brand_device`, `emulator.simulator` | `emulator.generic_build`, `emulator.x86_only`, `emulator.no_motion_sensors`, `emulator.network_operator` |
| `hooking` | `hooking.frida_maps`, `hooking.frida_threads`, `hooking.frida_fds`, `hooking.frida_port`, `hooking.frida_server`, `hooking.text_patched` (libc code differs from disk: an inline hook), `hooking.framework_mapped` (LSPosed, EdXposed, Riru, Zygisk modules, Shamiko in memory), `hooking.xposed_class`, `hooking.stack_frame`, `hooking.system_library`, `hooking.dyld_injection`, iOS `hooking.<check>` | `hooking.rwx_library` (a library mapped writable and executable outside system and app paths) |
| `debugger` | `debugger.attached`, `debugger.traced` | `debugger.debuggable_build` |
| `tampering` | `tampering.signature_mismatch`, `tampering.signature_unreadable` (Android), `tampering.team_id_mismatch` (iOS) | `tampering.provisioning_profile` (iOS) |
| `developerMode` | | `developer_mode.enabled`, `developer_mode.adb_enabled` |
| `screenLock` | `screen_lock.none` | |
| `storeInstall` | | `store_install.unknown_installer` |
| `externalStorage` | | `external_storage.installed` |
| `unknownSources` | | `unknown_sources.allowed` |
| `playProtect` | `play_protect.disabled` | `play_protect.unknown` |
| `accessibility` | `accessibility.window_reader` (can read other apps' screens) | `accessibility.service` |
| `notificationListener` | `notification_listener.untrusted` | |
| `vpn` | | `vpn.active`, `vpn.http_proxy` |
| `screenCapture` | `screen_capture.recording`, `screen_capture.mirroring` | `screen_capture.external_display` |
| `malware` | `malware.installed` | |
| `root`, `hooking`, `debugger` | | `integrity.native_unavailable` (the C library didn't load), `integrity.platform_check_failed` (reported next to high C evidence), `integrity.layer_mismatch:root_files` (Kotlin and C disagree: one layer is being hooked) |

Signals whose `source` is `SignalSource.ffi` come from C code (`src/dsi.c`) that runs on a
background isolate. On arm64 and x86_64 Android it reads files with direct system calls, so
hooking libc (what most Frida root-bypass scripts do) doesn't hide anything from it, and its
detection strings are stored encoded.

## Threat stream

```dart
DeviceSafety.threats.listen((ThreatEvent e) {
  // e.type: the CheckType
  // e.detail: 'screenshot', 'capture_started', 'recording_started', 'obscured_touch',
  //           'vpn_connected', or null when a check became detected
  // e.result: the CheckResult that triggered it, for detections
  analytics.log('threat', e.type.name);
});
```

Events fire when a check **becomes** detected, and, while the stream is listened to, for live
events: screenshots, capture or recording starting, tapjacking touches and a VPN connecting.

The package never terminates the app. If you decide to, call `DeviceSafety.terminateApp()`.

## Protection

Action APIs throw typed exceptions: `UnsupportedPlatformException`, `PermissionMissingException`
or `NativeFailureException` (all `DeviceSafetyException`).

### Screenshots and screen recording

```dart
await DeviceSafety.screen.blockScreenshots();              // FLAG_SECURE / iOS secure layer
await DeviceSafety.screen.blockScreenshots(block: false);

const SecureScreen(child: PaymentPage());                  // blocks only while mounted

await DeviceSafety.screen.setOverlayMode(.blur);           // cover the app while captured
await DeviceSafety.screen.clearOverlayMode();

DeviceSafety.screen.onScreenshot.listen((at) => warnUser());
DeviceSafety.screen.captureChanges.listen((captured) => hideBalance(captured));
```

### App switcher

```dart
await DeviceSafety.appSwitcher.setOverlay(argbColor: 0xFF000000); // cover in recents
await DeviceSafety.appSwitcher.hideFromRecents();                  // Android only
```

### Clipboard

```dart
await DeviceSafety.clipboard.copySecure('123456', clearAfter: Duration(seconds: 30));
```

The item is marked sensitive (hidden from the Android 13+ clipboard preview, kept off Universal
Clipboard on iOS) and cleared after `clearAfter`.

### Tapjacking (Android)

```dart
await DeviceSafety.overlayAttack.blockTouchesWhenObscured();
DeviceSafety.overlayAttack.obscuredTouches.listen((at) => warnUser());
```

### Idle session timeout

```dart
IdleTimeoutGuard(
  timeout: Duration(minutes: 5),
  onTimeout: () => auth.lock(),
  child: const HomePage(),
);
```

## Attestation

Tokens prove nothing on the device. **Always verify them on your server.**
[`example/server_dotnet`](example/server_dotnet) is a reference ASP.NET Core verifier.

```dart
// Android: Play Integrity (your app adds com.google.android.play:integrity)
await DeviceSafety.integrity.preparePlayIntegrity(cloudProjectNumber: 123456789012);
final token = await DeviceSafety.integrity.requestPlayIntegrityToken(requestHash: hash);

// iOS: App Attest (needs the appattest-environment entitlement)
final keyId = await DeviceSafety.integrity.generateAppAttestKey();
final attestation = await DeviceSafety.integrity.attestAppAttestKey(
  keyId: keyId, challenge: serverChallenge);
final assertion = await DeviceSafety.integrity.generateAppAttestAssertion(
  keyId: keyId, clientData: requestJson);

// iOS: DeviceCheck
final dcToken = await DeviceSafety.integrity.generateDeviceCheckToken();
```

Failures throw `AttestationException` with an `AttestationErrorCode` (`unsupported`,
`notPrepared`, `providerInvalid`, `playServicesUnavailable`, `network`, `tooManyRequests`,
`invalidKey`, `invalidInput`, `serverUnavailable`, `unknown`). After `providerInvalid`, call
`preparePlayIntegrity` again; after `invalidKey`, generate and attest a new key.

### Binding a token to a request

1. Your server issues a random, single-use challenge for the action (login, payment).
2. The app computes `requestHash = base64url(SHA-256(challenge + canonical request body))`,
   requests the token with it, and sends the token with the request.
3. The server decodes the token and checks the request hash, package name, signing certificate
   and timestamp before applying its verdict policy.

A typical policy requires `MEETS_DEVICE_INTEGRITY` for normal use and `MEETS_STRONG_INTEGRITY`
for high-risk actions. Root-hiding modules can spoof the former but not the latter, which is
backed by hardware key attestation. Also consider rejecting an `appRecognitionVerdict` other
than `PLAY_RECOGNIZED`, and the optional environment verdicts (Play Protect, app access risk,
recent device activity). The example server implements all of these.

Play Integrity needs a network connection, so decide what an offline client may do; the
on-device checks still apply there.

## Other tools

```dart
// IOC domain blocklist: exact hosts and *.suffix wildcards
if (DeviceSafety.ioc.isBlocked(uri.host)) return;
await DeviceSafety.ioc.loadRemoteBlocklist(Uri.parse('https://example.com/ioc.txt'));

// Calls: pause OTP entry or payments while a (possibly scam) call is live
if (await DeviceSafety.calls.isCallActive()) pauseSensitiveFlow();
DeviceSafety.calls.changes.listen((e) => e.started ? pause() : resume());

// Android call screening role
await DeviceSafety.callScreening.requestRole();

// App info and store update check
final info = await DeviceSafety.versionCheck.appInfo();
final status = await DeviceSafety.versionCheck.status(minAppVersion: '2.0.0');
if (status?.urgency == UpdateUrgency.required) forceUpdate(status!.storeLink);
```

The store lookups use public endpoints that Apple and Google don't document, so `status()`
returns `null` when they can't be reached or parsed. A `null` result never proves that no update
exists.

## Limits of on-device checks

Every on-device check, this package's included, can eventually be bypassed by someone who
controls the device:

- Magisk's DenyList and Shamiko unmount root from the processes they hide it from.
- Magisk can reinstall itself under a random package name.
- A determined attacker can patch this package's code inside your app.

A clean result is not proof of a clean device. Treat the on-device checks as fast, offline
signals, and a server-verified Play Integrity or App Attest verdict as the authority for
anything valuable.

## Android setup

The plugin declares only `ACCESS_NETWORK_STATE`, `DETECT_SCREEN_CAPTURE` and
`DETECT_SCREEN_RECORDING`, all normal permissions granted at install. Add these to your app's
manifest only for the features you use:

- **SIM call detection** (`DeviceSafety.calls`): `READ_PHONE_STATE`, a dangerous permission your
  app must also request at runtime. Without it, VoIP and audio-based detection still work.
  ```xml
  <uses-permission android:name="android.permission.READ_PHONE_STATE" />
  ```
- **Screenshot events on Android 10 to 13** (Android 14+ needs nothing):
  ```xml
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
  ```
- **Malware package detection**: declare each package you check (Android 11+ package
  visibility):
  ```xml
  <queries>
    <package android:name="com.example.known.malware" />
  </queries>
  ```
- **Unknown sources check**: `REQUEST_INSTALL_PACKAGES`. Google Play asks you to justify it.
  Without it the check reports nothing on Android 8+.
- **Version check and IOC feeds**: `INTERNET`.
- **Play Integrity**: add `implementation("com.google.android.play:integrity:1.6.0")` to your app.
  The plugin compiles against it but doesn't ship it.

## iOS setup

- **Swift Package Manager** is required.
- **App Attest** needs the `com.apple.developer.devicecheck.appattest-environment` entitlement.
- **Jailbreak URL schemes**: iOS only answers `canOpenURL` for schemes your app declares, so add
  them to `Info.plist` or the URL-scheme test (`root.jailbreak_urlSchemes`) never fires:
  ```xml
  <key>LSApplicationQueriesSchemes</key>
  <array>
    <string>sileo</string>
    <string>zbra</string>
    <string>filza</string>
    <string>undecimus</string>
  </array>
  ```
- IOSSecuritySuite runs its jailbreak checks in one call that includes `canOpenURL`, so the `root`
  check briefly runs on the main thread on iOS. The C jailbreak-file check runs on a background
  isolate.

## Testing your app

`package:device_safety_info/testing.dart` exports the platform interfaces, so your tests can fake
the native side:

```dart
import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/testing.dart';
import 'package:flutter_test/flutter_test.dart';

class RootedDevice extends Fake implements RootHostApi {
  @override
  Future<CheckReportMsg> rootCheck() async => CheckReportMsg(
    signals: [SignalMsg(id: 'root.su_executable', level: SignalLevelMsg.high)],
    supported: true,
  );
}

void main() {
  setUp(() => DeviceSafety.forTesting(
    platform: DeviceSafetyPlatform(root: RootedDevice(), ffi: const FakeNativeChecks()),
  ));
  tearDown(DeviceSafety.resetForTesting);

  test('blocks payments on a rooted device', () async {
    expect(await DeviceSafety.root.isDetected(), isTrue);
  });
}
```

## Example app

[`example/`](example) shows every API on seven pages: Overview (`assess()`), All checks, Policy
(change the policy and fail mode per check and see the effect immediately), Protection, Live
events, Tools and App integrity.

It renders in **Material or Cupertino** and starts in your platform's style. Tap the button on
the home page to switch live. Every page is written once against a small adaptive widget layer in
`example/lib/src/ui/adaptive.dart`, which is a reasonable starting point if your app supports
both styles.

To run the App integrity round trip, start the [example server](example/server_dotnet) and pass
its address:

```sh
cd example
flutter run --dart-define=INTEGRITY_SERVER_URL=http://192.168.1.10:5080 \
            --dart-define=PLAY_CLOUD_PROJECT_NUMBER=123456789012
```

## Platform support

| Feature | Android | iOS |
|---|---|---|
| Root / jailbreak, emulator, hooking, debugger | ✅ | ✅ |
| Tampering (re-signed app) | ✅ (needs `expectedSigningCertificates`) | ✅ |
| Screen lock, store install | ✅ | ✅ |
| Developer mode, external storage, unknown sources, Play Protect | ✅ | unsupported |
| Accessibility and notification-listener abuse, malware packages | ✅ | unsupported |
| VPN / proxy, screen capture | ✅ | ✅ |
| Recording state | Android 15+ | ✅ (same as capture) |
| Screenshot blocking, capture overlay, app-switcher overlay | ✅ | ✅ |
| Hide from recents, tapjacking protection, call screening role | ✅ | unsupported |
| Secure clipboard, call activity, version check, IOC blocklist | ✅ | ✅ |
| Play Integrity | ✅ | — |
| App Attest, DeviceCheck | — | ✅ |

Unsupported checks return `CheckStatus.unsupported`; unsupported actions throw
`UnsupportedPlatformException`.

## Performance

Measured in profile mode on a Galaxy S21 FE (Android 16):

| Scenario | Time |
|---|---|
| Assessment of 6 checks, first call | about 108 ms |
| The same, served from the cache | about 0.01 ms |
| All 15 detection checks, uncached, one round trip | about 45 ms |
| One uncached check | about 5 ms |

Method and full numbers, including the 1.x comparison:
[`example/integration_test/PERF_BASELINE.md`](example/integration_test/PERF_BASELINE.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
