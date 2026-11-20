# device_safety_info

[![pub package](https://img.shields.io/pub/v/device_safety_info.svg)](https://pub.dev/packages/device_safety_info)
[![pub points](https://img.shields.io/pub/points/device_safety_info)](https://pub.dev/packages/device_safety_info/score)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![platform](https://img.shields.io/badge/platform-android%20%7C%20ios-lightgrey.svg)](docs/advanced.md#platform-support)

Security checks and protections for Flutter apps that handle money, health or identity.
Find rooted phones, hacking tools and scam setups, protect sensitive screens, and prove the
device to your server.

Every check tells you **what it found**. **Your app decides** what to do about it. The package
never closes or uninstalls your app.

> **Upgrading from 1.x?** 2.0 is a breaking release. See [MIGRATION.md](MIGRATION.md).

## Install

```yaml
dependencies:
  device_safety_info: ^2.0.0
```

```dart
import 'package:device_safety_info/device_safety_info.dart';
```

Needs **Flutter 3.50+**, **Android** minSdk 24, and **iOS** 16 with Swift Package Manager.

## Quick start

**1. Check everything before a sensitive action** (a login or a payment):

```dart
final report = await DeviceSafety.assess();
if (report.detected) {
  for (final flag in report.flags) {
    showWarning(flag.title, flag.description); // plain-language text for the user
  }
}
```

**2. Or check one thing:**

```dart
if (await DeviceSafety.root.isDetected()) {
  blockPayments();
}
```

**3. (Optional) Change settings at startup.** You can skip this. Without it, safe defaults are
used.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceSafety.initialize(DeviceSafetyConfig(
    accessibilityAllowlist: {'com.google.android.marvin.talkback'}, // trust TalkBack
  ));
  runApp(const MyApp());
}
```

### Reading a result

Every check has `isDetected()` (a simple yes/no) and `check()` (the full result):

```dart
final result = await DeviceSafety.root.check();
result.detected; // true = risky. This is the answer to use.
result.signals;  // what was found, e.g. [root.su_executable:/system/xbin/su(high)]
result.level;    // none, low (weak sign) or high (strong sign)
result.status;   // completed, unsupported (not on this platform), error or timedOut
```

Checks **never throw**. By default only strong (high) signs count as detected. To change that,
see [Settings](#settings-how-strict-checks-are).

## Features

Each feature below has one sentence, one example, and a page in the
[example app](#example-app).

| Group | Features |
|---|---|
| [Device checks](#device-checks) | [Root / jailbreak](#root--jailbreak) · [Emulator](#emulator--simulator) · [Hooking](#hooking-frida-xposed) · [Debugger](#debugger) · [Tampering](#tampering) · [Device posture](#device-posture) · [Accessibility](#accessibility-services) · [Notification listeners](#notification-listeners) · [VPN](#vpn--proxy) · [Malware](#malware-apps) |
| [Fraud signals](#fraud-signals) | [Remote access](#remote-access-apps) · [GPS spoofing](#gps-spoofing) · [App cloning](#app-cloning) · [HTTPS interception](#https-interception) · [Keyboard](#third-party-keyboard) |
| [Protect your screens](#protect-your-screens) | [Screenshots](#screenshots--recording) · [App switcher](#app-switcher) · [Clipboard](#secure-clipboard) · [Tapjacking](#tapjacking) · [Idle timeout](#idle-timeout) · [Secure text fields](#secure-text-fields) |
| [Prove device & user](#prove-device--user) | [Certificate pinning](#certificate-pinning) · [Device-bound key](#device-bound-key) · [Biometric approval](#biometric-approval) · [App integrity](#app-integrity) |
| [Live events & tools](#live-events--tools) | [Live threats](#live-threats) · [Blocked domains](#blocked-domains) · [Phone calls](#phone-calls) · [Version check](#version-check) |
| [Settings](#settings-how-strict-checks-are) | Policies, allowlists |

---

## Device checks

All device checks work the same way: `check()` or `isDetected()`.

### Root / jailbreak

Finds a rooted Android phone or a jailbroken iPhone. Root lets other apps read your app's data.

```dart
if (await DeviceSafety.root.isDetected()) blockPayments();
```

Android ✅ iOS ✅ · [example](example/lib/features/root_page.dart)

### Emulator / simulator

Finds an emulator or simulator. Fraud farms run many fake devices on them.

```dart
if (await DeviceSafety.emulator.isDetected()) blockSignUp();
```

Android ✅ iOS ✅ · [example](example/lib/features/emulator_page.dart)

### Hooking (Frida, Xposed)

Finds tools that change your app's code while it runs (Frida, Xposed, Zygisk).

```dart
if (await DeviceSafety.hooking.isDetected()) blockPayments();
```

Android ✅ iOS ✅ · [example](example/lib/features/hooking_page.dart)

### Debugger

Finds a debugger attached to your app. It is expected while you run from your IDE.

```dart
if (await DeviceSafety.debugger.isDetected()) blockPayments();
```

Android ✅ iOS ✅ · [example](example/lib/features/debugger_page.dart)

### Tampering

Finds a copy of your app that someone changed and signed again. Tell the package your real
certificate first:

```dart
// 1. Once: print your certificate (Android) and put it in the config.
print((await DeviceSafety.tampering.signingInfo()).certificateSha256);

await DeviceSafety.initialize(DeviceSafetyConfig(
  expectedSigningCertificates: {'ab12...'}, // Android
  expectedIosTeamId: 'ABCDE12345',           // iOS
));

// 2. Check.
if (await DeviceSafety.tampering.isDetected()) blockApp();
```

Android ✅ iOS ✅ · [example](example/lib/features/tampering_page.dart)

### Device posture

Weak phone settings. Each check is "detected" when the phone is in the risky state.

```dart
await DeviceSafety.posture.screenLock.isDetected();     // no screen lock
await DeviceSafety.posture.developerMode.isDetected();  // developer options on
await DeviceSafety.posture.storeInstall.isDetected();   // not installed from a store
await DeviceSafety.posture.unknownSources.isDetected(); // can install unknown apps
await DeviceSafety.posture.playProtect.isDetected();    // Play Protect off
await DeviceSafety.posture.externalStorage.isDetected(); // app on an SD card
```

Screen lock and store install: Android ✅ iOS ✅. The rest: Android only ·
[example](example/lib/features/posture_page.dart)

### Accessibility services

Finds apps that can read and tap the screen. Banking malware uses them. Trust the ones your users
need:

```dart
await DeviceSafety.initialize(DeviceSafetyConfig(
  accessibilityAllowlist: {'com.google.android.marvin.talkback'},
));
if (await DeviceSafety.accessibility.isDetected()) warnUser();
```

Android only · [example](example/lib/features/accessibility_page.dart)

### Notification listeners

Finds apps that can read every notification, including SMS codes.

```dart
if (await DeviceSafety.notificationListeners.isDetected()) warnUser();
```

Trusted apps go in `notificationListenerAllowlist`. Android only ·
[example](example/lib/features/notification_listeners_page.dart)

### VPN / proxy

Finds an active VPN or HTTP proxy. It's a weak sign by default, because many honest users run a
VPN.

```dart
final result = await DeviceSafety.vpn.check();
if (result.signals.isNotEmpty) showVpnNotice();
```

Android ✅ iOS ✅ · [example](example/lib/features/vpn_page.dart)

### Malware apps

Finds installed apps from your own list of known malware.

```dart
await DeviceSafety.initialize(DeviceSafetyConfig(
  malwarePackages: {'com.example.known.malware'},
));
if (await DeviceSafety.malware.isDetected()) blockPayments();
```

Each package must also be listed under `<queries>` in your manifest
([Android setup](docs/advanced.md#android-setup)). Android only ·
[example](example/lib/features/malware_page.dart)

---

## Fraud signals

These checks find scam setups rather than a hacked phone. They are Android only. On iOS they
report `unsupported`.

### Remote access apps

Finds remote-control apps (AnyDesk, TeamViewer QuickSupport...) used in fake support-call scams.

```dart
if (await DeviceSafety.remoteAccess.isDetected()) warnUser();
```

[example](example/lib/features/remote_access_page.dart)

### GPS spoofing

Finds a fake-location app or a fake location fix.

```dart
if (await DeviceSafety.locationSpoofing.isDetected()) rejectLocation();
```

[example](example/lib/features/gps_spoofing_page.dart)

### App cloning

Finds your app running in a cloner (Parallel Space, dual apps) or another user profile.

```dart
if (await DeviceSafety.appCloning.isDetected()) warnUser();
```

[example](example/lib/features/app_cloning_page.dart)

### HTTPS interception

Finds user-installed certificates that let a proxy read HTTPS traffic. Pair it with
[certificate pinning](#certificate-pinning).

```dart
if (await DeviceSafety.mitm.isDetected()) warnUser();
```

[example](example/lib/features/mitm_page.dart)

### Third-party keyboard

Finds a third-party keyboard that could log typing. Gboard, SwiftKey and system keyboards are
trusted.

```dart
if (await DeviceSafety.keyboard.isDetected()) useSecureField();
```

[example](example/lib/features/keyboard_page.dart)

---

## Protect your screens

Actions throw a `DeviceSafetyException` when they can't run (for example
`UnsupportedPlatformException`).

### Screenshots & recording

Stop screenshots and screen recording, or blur the app while it is recorded.

```dart
await DeviceSafety.screen.blockScreenshots();     // whole app
const SecureScreen(child: PaymentPage());          // only while this page is open
await DeviceSafety.screen.setOverlayMode(.blur);  // blur while recorded
DeviceSafety.screen.onScreenshot.listen((_) => warnUser());
```

Android ✅ iOS ✅ · [example](example/lib/features/screenshot_page.dart)

### App switcher

Hide your app's content in the recent-apps screen.

```dart
await DeviceSafety.appSwitcher.setOverlay(argbColor: 0xFF000000);
await DeviceSafety.appSwitcher.hideFromRecents(); // Android only
```

Android ✅ iOS ✅ · [example](example/lib/features/app_switcher_page.dart)

### Secure clipboard

Copy a code that is hidden from clipboard previews and cleared after a delay.

```dart
await DeviceSafety.clipboard.copySecure('123456', clearAfter: const Duration(seconds: 30));
```

Android ✅ iOS ✅ · [example](example/lib/features/clipboard_page.dart)

### Tapjacking

Ignore taps while another app draws over yours to trick the user.

```dart
await DeviceSafety.overlayAttack.blockTouchesWhenObscured();
```

Android only · [example](example/lib/features/tapjacking_page.dart)

### Idle timeout

Log out when nobody touches the app for a while.

```dart
IdleTimeoutGuard(
  timeout: const Duration(minutes: 5),
  onTimeout: () => logOut(),
  child: const HomePage(),
);
```

Android ✅ iOS ✅ · [example](example/lib/features/idle_timeout_page.dart)

### Secure text fields

For PINs and passwords: no keyboard suggestions or learning, no autofill or copy, and no
screenshots while the field is focused.

```dart
const pin = SecureInputConfig.pin(); // or .password(), .otp()

SecureFieldGuard(
  config: pin,
  child: TextField(
    obscureText: pin.obscureText,
    keyboardType: pin.keyboardType,
    autocorrect: pin.autocorrect,
    enableSuggestions: pin.enableSuggestions,
    enableIMEPersonalizedLearning: pin.enableIMEPersonalizedLearning,
    enableInteractiveSelection: pin.enableInteractiveSelection,
    autofillHints: pin.autofillHints,
  ),
);
```

On iOS you can also block third-party keyboards in your app. Add this to your `AppDelegate`:

```swift
import device_safety_info

override func application(
  _ application: UIApplication,
  shouldAllowExtensionPointIdentifier id: UIApplication.ExtensionPointIdentifier
) -> Bool {
  DeviceSafetyInfoPlugin.shouldAllowExtension(id)
}
```

```dart
await DeviceSafety.keyboard.blockCustomKeyboards(true);
```

Android ✅ iOS ✅ · [example](example/lib/features/secure_text_field_page.dart)

---

## Prove device & user

### Certificate pinning

Only talk to your real server, even if a proxy certificate is installed on the phone.

```dart
// Once: get your server's pin.
print(await DeviceSafety.pinning.spkiPinOf(Uri.https('api.example.com')));

// Then make requests with a pinned client (current pin + backup pin).
final client = DeviceSafety.pinning.createHttpClient(PinningConfig({
  'api.example.com': {'<pin>', '<backup pin>'},
}));
```

It works with `package:http` and dio too ([details](docs/advanced.md#certificate-pinning)).
Android ✅ iOS ✅ · [example](example/lib/features/pinning_page.dart)

### Device-bound key

A signing key that never leaves the phone's secure chip, so your server knows a request came
from this phone.

```dart
// Once: create the key and send key.publicKey to your server.
final key = await DeviceSafety.deviceKey.create('session', challenge: serverChallenge);

// Each request: sign it. Your server verifies the signature.
final signature = await DeviceSafety.deviceKey.sign('session', requestBytes);
```

Android ✅ iOS ✅ · [example](example/lib/features/device_key_page.dart)

### Biometric approval

Approve an action with a fingerprint or face. The result is a signature your server verifies, so
it can't be faked by hacking the app.

```dart
// Once: create the key and send key.publicKey to your server.
final key = await DeviceSafety.biometric.enroll('payments');

// For each payment:
final signature = await DeviceSafety.biometric.approve(
  'payments',
  utf8.encode('pay 500 to Alice'),
  title: 'Confirm payment',
  reason: 'Pay 500 to Alice',
);
```

iOS needs `NSFaceIDUsageDescription` in `Info.plist`. Android 10+ ✅ iOS ✅ ·
[example](example/lib/features/biometric_page.dart)

### App integrity

Ask Google or Apple to vouch for your app and device. **Your server must verify the token.**
The app can't check it itself.

```dart
// Android: Play Integrity
await DeviceSafety.integrity.preparePlayIntegrity(cloudProjectNumber: 123456789012);
final token = await DeviceSafety.integrity.requestPlayIntegrityToken(requestHash: challenge);

// iOS: DeviceCheck (App Attest is also available)
final token = await DeviceSafety.integrity.generateDeviceCheckToken();
```

A sample server is in [`example/server_dotnet`](example/server_dotnet). See also the
[full guide](docs/advanced.md#attestation). Android ✅ iOS ✅ ·
[example](example/lib/features/app_integrity_page.dart)

---

## Live events & tools

### Live threats

One stream for what happens while the app runs: screenshots, screen recording, a VPN connecting,
covered taps, and checks that become detected.

```dart
DeviceSafety.threats.listen((event) {
  print('${event.type.name}: ${event.detail}');
});
```

Android ✅ iOS ✅ · [example](example/lib/features/threats_page.dart)

### Blocked domains

Refuse to open known phishing or malware domains.

```dart
await DeviceSafety.initialize(DeviceSafetyConfig(
  iocBlocklist: {'evil.example', '*.phishing.example'},
));
if (DeviceSafety.ioc.isBlocked(uri.host)) return; // don't open it
```

Android ✅ iOS ✅ · [example](example/lib/features/ioc_domains_page.dart)

### Phone calls

Many scams happen while the victim is on a call. Warn the user during a call.

```dart
if (await DeviceSafety.calls.isCallActive()) showWarning('Never share codes with callers.');
DeviceSafety.calls.changes.listen((e) => e.started ? pause() : resume());
```

Android ✅ iOS ✅ · [example](example/lib/features/calls_page.dart)

### Version check

Compare your app's version with the store and ask users on old versions to update.

```dart
final status = await DeviceSafety.versionCheck.status(minAppVersion: '2.0.0');
if (status?.urgency == UpdateUrgency.required) forceUpdate(status!.storeLink);
```

`status` is `null` when the store can't be reached. Android ✅ iOS ✅ ·
[example](example/lib/features/version_check_page.dart)

---

## Settings: how strict checks are

Each check finds **high** (strong) and **low** (weak) signs. The policy decides what counts:

| Policy | Detected when |
|---|---|
| `standard` (default) | a high sign is found |
| `strict` | any sign is found |
| `off` | never (the check doesn't run) |

```dart
await DeviceSafety.initialize(DeviceSafetyConfig(
  policies: {CheckType.vpn: .strict, CheckType.developerMode: .off},
  failModes: {CheckType.root: .closed}, // if the root check errors, treat it as detected
));
```

For every option (allowlists, cache, timeouts, signal overrides), see the
[advanced guide](docs/advanced.md#configuration). [Example](example/lib/features/settings_page.dart).

## Platform setup

Most features need no setup. Some need a line in your app:

| Feature | What to add |
|---|---|
| Malware apps (Android) | each package under `<queries>` in `AndroidManifest.xml` |
| SIM call detection (Android) | `READ_PHONE_STATE` permission (request it at runtime) |
| Play Integrity (Android) | `implementation("com.google.android.play:integrity:1.6.0")` |
| Biometric approval (iOS) | `NSFaceIDUsageDescription` in `Info.plist` |
| App Attest (iOS) | the `appattest-environment` entitlement |
| Blocking keyboards (iOS) | the `AppDelegate` override in [Secure text fields](#secure-text-fields) |

The full list is in the advanced guide: [Android setup](docs/advanced.md#android-setup) and
[iOS setup](docs/advanced.md#ios-setup).

## Testing your app

Fake the platform side in your widget and unit tests:

```dart
import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/testing.dart';

setUp(() => DeviceSafety.forTesting(
  platform: DeviceSafetyPlatform(ffi: const FakeNativeChecks()),
));
tearDown(DeviceSafety.resetForTesting);
```

To fake a rooted device, see [Testing your app](docs/advanced.md#testing-your-app).

## Example app

[`example/`](example) has one small page per feature. Each page starts with the code to copy.

```sh
cd example
flutter run
```

## Good to know

- On-device checks can be bypassed by a skilled attacker who controls the phone. For anything
  valuable, also verify [App integrity](#app-integrity) on your server
  ([why](docs/advanced.md#limits-of-on-device-checks)).
- Results are cached for 30 seconds. Pass `refresh: true` to run a check again.
- Checks that don't exist on a platform return `unsupported` instead of a wrong answer.

## Learn more

- [Advanced guide](docs/advanced.md): how checks work, every option, every signal, platform
  setup, limits, performance
- [MIGRATION.md](MIGRATION.md): upgrading from 1.x
- [CHANGELOG.md](CHANGELOG.md)
- [Device test matrix](docs/testing.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
