# device_safety_info: advanced guide

The [README](../README.md) shows how to use each feature. This page has the details: how results
and policies work, every configuration option, every signal, platform setup, and the limits of
on-device checks.

## Contents

- [How checks work](#how-checks-work)
- [Configuration](#configuration)
- [Detection details](#detection-details)
- [Signal catalogue](#signal-catalogue)
- [Threat stream](#threat-stream)
- [Protection details](#protection-details) (exceptions, certificate pinning)
- [Strong authentication](#strong-authentication)
- [Attestation](#attestation)
- [Other tools](#other-tools)
- [Limits of on-device checks](#limits-of-on-device-checks)
- [Android setup](#android-setup)
- [iOS setup](#ios-setup)
- [Testing your app](#testing-your-app)
- [Platform support](#platform-support)
- [Performance](#performance)

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
  remoteAccessAllowlist: {'com.teamviewer.host.market'}, // your own support tool
  keyboardAllowlist: {'com.corp.securekeyboard'},
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
| `remoteAccessAllowlist` | empty | Remote-control apps (package names) not to report, e.g. your MDM or support tool |
| `keyboardAllowlist` | empty | Keyboards (package names) not to report; system keyboards, Gboard and SwiftKey are already trusted |
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

## Detection details

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

### Fraud signals

`remoteAccess`, `locationSpoofing`, `appCloning`, `mitm` and `keyboard` target account-takeover
and fraud-farm setups rather than a compromised OS. They are Android checks; on iOS they report
`unsupported`, because apps can't see other apps, the trust store or the active keyboard there.

- A remote-control app that is merely installed is low risk (IT staff use them). Its
  accessibility service being enabled is high risk: that's what lets the other side tap and type.
- `location.mock_fix` reads the last known location only if your app already holds a location
  permission; the package never asks for one.
- Cloned spaces from phone makers (Samsung Dual Messenger, Xiaomi Second Space, Secure Folder)
  are low risk; running inside another app's container is high risk.
- Pair `mitm` with [certificate pinning](#certificate-pinning), which protects your own traffic
  whatever CA is installed.

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
| `remoteAccess` | `remote_access.control_service:<package>` | `remote_access.app_installed:<package>` |
| `locationSpoofing` | `location.mock_app_selected:<package>`, `location.mock_fix` | `location.mock_app_installed:<package>` |
| `appCloning` | `clone.virtual_container:<host>` | `clone.secondary_user`, `clone.work_profile`, `clone.cloner_installed:<package>` |
| `mitm` | `mitm.user_ca_with_proxy` | `mitm.user_ca:<certificate name>` |
| `keyboard` | `keyboard.third_party:<package>` (with an accessibility service) | `keyboard.third_party:<package>` |
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
  //           'vpn_connected', 'pin_mismatch:<host>', or null when a check became detected
  // e.result: the CheckResult that triggered it, for detections
  analytics.log('threat', e.type.name);
});
```

Events fire when a check **becomes** detected, and, while the stream is listened to, for live
events: screenshots, capture or recording starting, tapjacking touches and a VPN connecting. A
failed [pin check](#certificate-pinning) always emits `CheckType.mitm` with
`pin_mismatch:<host>`.

The package never terminates the app. If you decide to, call `DeviceSafety.terminateApp()`.

## Protection details

Action APIs throw typed exceptions: `UnsupportedPlatformException`, `PermissionMissingException`,
`NativeFailureException`, and for the features below `BiometricException` and
`PinningException` (all `DeviceSafetyException`).

### Certificate pinning

`DeviceSafety.pinning` creates a `dart:io` `HttpClient` that checks the server's public key
during the TLS handshake, before any request bytes are sent. A proxy with a trusted CA can then
no longer read your API traffic.

```dart
final pins = PinningConfig({
  // base64 SHA-256 of the leaf certificate's SubjectPublicKeyInfo: current key + backup key
  'api.example.com': {'fk9XHhHbogE9XGaAfesn/HnyYWU7bGalXhRCxlOPYMI=', 'BACKUP...='},
});

final http = IOClient(DeviceSafety.pinning.createHttpClient(pins));   // package:http
dio.httpClientAdapter = IOHttpClientAdapter(                           // dio
  createHttpClient: () => DeviceSafety.pinning.createHttpClient(pins),
);
```

- A mismatch throws `PinningException` and emits a `pin_mismatch:<host>` threat event.
- Plain HTTP to a pinned host is refused. Hosts that aren't listed get normal TLS validation.
- Each host needs at least two pins, so you can change keys without locking users out. Renew
  certificates with the same key (for example certbot `--reuse-key`), or ship the new pin in an
  app update before you switch.
- Only the leaf key can be pinned (Dart exposes only the peer certificate), and the client
  never uses a proxy.

Get a server's pin:

```sh
openssl s_client -connect api.example.com:443 </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary | base64
```

or in a debug build, `await DeviceSafety.pinning.spkiPinOf(Uri.https('api.example.com'))`.

## Strong authentication

### Device-bound keys

A session token can be copied to another device; a key in secure hardware can't.
`DeviceSafety.deviceKey` creates an EC P-256 key in StrongBox or the TEE (Android) or the Secure
Enclave (iOS), and signs with it.

```dart
// At login: create the key and register it with your server.
final key = await DeviceSafety.deviceKey.create('session', challenge: serverChallenge);
key.publicKey;          // DER SubjectPublicKeyInfo
key.securityLevel;      // strongBox, tee, secureEnclave or software
key.attestationChain;   // Android: X.509 chain proving the key lives in secure hardware

// For each sensitive request: sign a server nonce plus the request.
final signature = await DeviceSafety.deviceKey.sign('session', utf8.encode(nonce + body));
```

Signatures are DER-encoded ECDSA with SHA-256 (`SHA256withECDSA` in Java/Kotlin,
`ECDsa.VerifyData(..., DSASignatureFormat.Rfc3279DerSequence)` in .NET). On Android, verify the
attestation chain on your server up to Google's root and read the key description extension: it
states the security level, the challenge, and the device's verified-boot state.

### Biometric-approved actions

A plain "authenticate" call returns `true`, which a hooking tool can fake. Here the approval is a
**signature** made by a key the OS releases only after a strong fingerprint or face match, which
your server verifies.

```dart
final key = await DeviceSafety.biometric.enroll('payments');   // register key.publicKey

try {
  final signature = await DeviceSafety.biometric.approve(
    'payments',
    utf8.encode('$serverNonce|$paymentJson'),
    title: 'Confirm payment',
    reason: 'Pay 500 to Alice',
  );
  await api.confirmPayment(paymentJson, signature);
} on BiometricException catch (e) {
  switch (e.code) {
    case .enrollmentChanged: // a fingerprint or face was added: re-verify, then enroll again
    case .cancelled:
    case .lockedOut:
    case .notEnrolled:
    case .unavailable:
    case .keyMissing:
    case .failed:
  }
}
```

Adding a fingerprint or face permanently invalidates the key, so someone who adds their own
finger to an unlocked phone can't approve anything. `keyState('payments')` reports `valid`,
`invalidated` or `missing`. Android 10+ (strong biometrics), and iOS with Face ID or Touch ID.

## Attestation

Tokens prove nothing on the device. **Always verify them on your server.**
[`example/server_dotnet`](../example/server_dotnet) is a reference ASP.NET Core verifier.

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

The plugin declares `ACCESS_NETWORK_STATE`, `DETECT_SCREEN_CAPTURE`, `DETECT_SCREEN_RECORDING`
and `USE_BIOMETRIC`, all normal permissions granted at install, and `<queries>` entries for the
root, remote-access, mock-location and cloner apps it looks for. Add these to your app's manifest
only for the features you use:

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
- **Version check, IOC feeds and pinned requests**: `INTERNET`.
- **Mock location fix** (`location.mock_fix`): only checked when your app already holds
  `ACCESS_FINE_LOCATION` or `ACCESS_COARSE_LOCATION`.
- **Play Integrity**: add `implementation("com.google.android.play:integrity:1.6.0")` to your app.
  The plugin compiles against it but doesn't ship it.

## iOS setup

- **Swift Package Manager** is required.
- **App Attest** needs the `com.apple.developer.devicecheck.appattest-environment` entitlement.
- **Biometric approval** needs `NSFaceIDUsageDescription` in `Info.plist`:
  ```xml
  <key>NSFaceIDUsageDescription</key>
  <string>Face ID confirms payments.</string>
  ```
- **Blocking third-party keyboards** needs the `AppDelegate` override shown in
  [Secure text fields](../README.md#secure-text-fields).
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

## Platform support

| Feature | Android | iOS |
|---|---|---|
| Root / jailbreak, emulator, hooking, debugger | ✅ | ✅ |
| Tampering (re-signed app) | ✅ (needs `expectedSigningCertificates`) | ✅ |
| Screen lock, store install | ✅ | ✅ |
| Developer mode, external storage, unknown sources, Play Protect | ✅ | unsupported |
| Accessibility and notification-listener abuse, malware packages | ✅ | unsupported |
| Remote access, GPS spoofing, app cloning, MITM certificates, keyboard check | ✅ | unsupported |
| Blocking third-party keyboards | — | ✅ (`AppDelegate` line) |
| Device-bound keys | ✅ (StrongBox / TEE, attestation) | ✅ (Secure Enclave) |
| Biometric-approved actions | Android 10+ | ✅ |
| Secure text fields, certificate pinning | ✅ | ✅ |
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
| All 15 detection checks, uncached, one round trip (before the five fraud checks were added) | about 45 ms |
| One uncached check | about 5 ms |

Method and full numbers, including the 1.x comparison:
[`example/integration_test/PERF_BASELINE.md`](../example/integration_test/PERF_BASELINE.md).

