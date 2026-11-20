---
name: device-safety-info
description: >-
  Set up and use the device_safety_info Flutter package (2.x): root, jailbreak,
  emulator, hooking and debugger detection with off/standard/strict policies,
  fail modes, risk assessment, fraud signals (remote access, GPS spoofing, app
  cloning, MITM certificates, keyboards), the threat stream, screenshot,
  clipboard and secure-input protection, certificate pinning, hardware-bound
  keys, biometric-approved actions, and Play Integrity / App Attest tokens
  verified on a server. Use when adding device security checks to a Flutter app
  or migrating from 1.x.
---

# device_safety_info

Everything goes through `DeviceSafety` from
`package:device_safety_info/device_safety_info.dart`. Requires Flutter 3.50+ /
Dart 3.14+; iOS builds with Swift Package Manager only.

## Set up

1. Add `device_safety_info: ^2.0.0` to `dependencies`.
2. In `main()`, after `WidgetsFlutterBinding.ensureInitialized()`, call
   `DeviceSafety.initialize(DeviceSafetyConfig(...))`. It is optional; the
   defaults are the standard policy, fail open, a 30 s cache and a 5 s timeout.
3. Add Android permissions only for features the app uses (see the package
   README): `READ_PHONE_STATE` for SIM call detection, `<queries>` entries for
   malware packages, `INTERNET` for the version check and pinned requests.
4. iOS: add `NSFaceIDUsageDescription` to `Info.plist` when using
   `DeviceSafety.biometric`. Biometric approval on Android needs Android 10+.

## Choose policies

- Signals are `high` (clear evidence) or `low` (weak evidence that normal
  devices also show).
- `RiskPolicy.standard` detects high signals, `.strict` detects any signal,
  `.off` skips the check. Set `defaultPolicy` and per-check `policies`.
- `signalOverrides` change one signal's level by id (the part before `:`),
  e.g. `{'vpn.active': RiskLevel.high}` or `{'emulator.generic_build':
  RiskLevel.none}`.
- `failModes: {CheckType.root: FailMode.closed}` makes errors and timeouts
  count as detected. Use it for checks an attacker could break on purpose
  (root, hooking, debugger, tampering).
- For the tampering (repackaged app) check, set `expectedSigningCertificates`
  (Android SHA-256 digests; `DeviceSafety.tampering.signingInfo()` shows the
  current one) and `expectedIosTeamId`. Without them it reports `unsupported`
  on Android.
- Allowlist trusted accessibility services and notification listeners, or they
  are reported. Preinstalled system apps are trusted by default
  (`trustSystemApps: true`); set it to `false` to report them too.
- Allowlist your own remote-support or MDM tool (`remoteAccessAllowlist`) and
  any company keyboard (`keyboardAllowlist`).

## Check

- Before a sensitive action, prefer one call: `final report = await
  DeviceSafety.assess();`, then `report.detected`, `report.flags` (plain
  language) and `report.results`.
- Single checks: `await DeviceSafety.root.check()` returns a `CheckResult`
  (`status`, `signals`, `level`, `detected`); `isDetected()` returns a bool.
- Detection never throws. Treat `CheckStatus.unsupported` as "not applicable on
  this platform" and `error` / `timedOut` according to the fail mode.
- Never block on low-risk signals alone without the user being able to
  proceed; budget phones and custom ROMs show some of them.

## React

- The package never closes the app. Listen to `DeviceSafety.threats` for
  detections and live events (screenshot, capture, tapjacking, VPN) and decide
  what to do; `DeviceSafety.terminateApp()` exists only as an explicit opt-in.
- Wrap sensitive pages in `SecureScreen`, or use
  `DeviceSafety.screen.blockScreenshots()` / `setOverlayMode(...)`.
- Copy one-time codes with `DeviceSafety.clipboard.copySecure(text,
  clearAfter: ...)`.
- For PIN, password and OTP fields apply `SecureInputConfig.pin()` /
  `.password()` / `.otp()` to the `TextField` and wrap it in
  `SecureFieldGuard`, or use `SecureEditableText`.
- Pin your API with `DeviceSafety.pinning.createHttpClient(PinningConfig({host:
  {currentPin, backupPin}}))` (two pins per host, leaf SPKI SHA-256 base64);
  pass it to `IOClient` or dio's `IOHttpClientAdapter`.
- During a call or with `remoteAccess` detected, pause OTP entry and payments:
  this is the typical "support call" scam.

## Verify on a server

Device-side checks can be bypassed on a compromised device. For anything that
matters, also send `DeviceSafety.integrity` tokens (Play Integrity on Android,
App Attest or DeviceCheck on iOS) to the backend and verify them there; the
repository's `example/server_dotnet` is a reference verifier. Bind tokens to
the request with a server-issued nonce or a request hash.

For logins and payments, register a `DeviceSafety.deviceKey.create(...)`
public key (Android: verify its attestation chain) and have the app sign a
server nonce with `sign`. For approvals, use `DeviceSafety.biometric.enroll`
once and `approve(alias, nonce + payload, title:, reason:)` per action; verify
the DER ECDSA/SHA-256 signature on the server. On
`BiometricException(enrollmentChanged)`, re-verify the user before enrolling
again.

## Test

Import `package:device_safety_info/testing.dart`, implement the generated host
APIs with `Fake`, and call `DeviceSafety.forTesting(platform:
DeviceSafetyPlatform(...))`; reset with `DeviceSafety.resetForTesting()`.

## Migrate from 1.x

Follow the package's MIGRATION.md. Key changes: booleans became
`CheckResult`s, `isRealDevice` / `isScreenLock` / `isInstalledFromStore`
flipped meaning (they are now risk checks), exit/uninstall options were
removed, and `READ_PHONE_STATE` must be declared by the app.
