# IntegrityServer — .NET verification sample

This is a reference **server-side verifier** for `device_safety_info`'s `AppIntegrity` API. It handles:

- **Android:** Google Play Integrity
- **iOS:** Apple App Attest and DeviceCheck

The Flutter plugin only *produces* tokens. A token proves nothing until a server you control verifies it. Never decide trust on the device: an attacker who controls the device can patch any local check.

> **This is a sample, not production code.**
> - Challenges and attested keys are stored in memory, so they're lost on restart and not shared between instances.
> - There's no authentication, rate limiting or HTTPS termination.
>
> Copy the verification logic into your real API, and keep its state in your own database.

## Requirements

- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- **Android:**
  - The app published to a Play Console track (internal testing is enough).
  - A Google Cloud project linked to it.
  - A service-account JSON key for that project.
- **iOS:**
  - An Apple Developer account and Team ID.
  - The App Attest capability on the App ID.
  - For DeviceCheck: a `.p8` key with DeviceCheck enabled.

## Setup

### 1. Android: Play Integrity

1. In **Play Console → your app → Test and release → App integrity**, link a Google Cloud project.
2. In that Cloud project:
   1. Enable the **Google Play Integrity API**.
   2. Create a **service account**.
   3. Download its **JSON key**.
3. Save the key as `IntegrityServer/service-account.json`. It's gitignored.
4. Copy the **Cloud project number** (a number, not the project ID). Pass it to the app:
   ```bash
   flutter run --dart-define=PLAY_CLOUD_PROJECT_NUMBER=123456789012
   ```
5. In the consuming app's `android/app/build.gradle.kts`, add the opt-in dependency:
   ```kotlin
   implementation("com.google.android.play:integrity:1.6.0")
   ```
6. Install the app **from Play**, using an internal testing track. Sideloaded debug builds return `UNRECOGNIZED_VERSION` and weaker device verdicts.

### 2. iOS: App Attest

1. In Xcode, open **Runner → Signing & Capabilities → + Capability → App Attest**. This creates `Runner.entitlements` with `com.apple.developer.devicecheck.appattest-environment`.
   - Use `development` for debug builds and `production` for TestFlight and App Store builds.
2. Set `AppleTeamId`, `BundleId` and `AppleEnvironment` in `appsettings.json` to match. `AppleEnvironment` must equal the entitlement value.
3. Test on a **physical device**. The simulator doesn't support App Attest.

`AppleAppAttestRootCA.pem` comes from <https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem>. Its SHA-256 fingerprint is:

```
1C:B9:82:3B:A2:8B:A6:AD:2D:33:A0:06:94:1D:E2:AE:4F:51:3E:F1:D4:E8:31:B9:F7:E0:FA:7B:62:42:C9:32
```

### 3. iOS: DeviceCheck (optional)

1. In **Apple Developer → Keys**, create a key with **DeviceCheck** enabled and download the `.p8` file.
2. Save it as `IntegrityServer/AuthKey_DeviceCheck.p8`. It's gitignored.
3. Set `DeviceCheckKeyId` in `appsettings.json`.

### 4. Run

```bash
cd example/server_dotnet/IntegrityServer
dotnet run            # listens on http://0.0.0.0:5080
```

Point the example app at the server:

```bash
# Android (USB): forward the device's localhost:5080 to this machine
adb reverse tcp:5080 tcp:5080
flutter run --dart-define=PLAY_CLOUD_PROJECT_NUMBER=123456789012 \
            --dart-define=INTEGRITY_SERVER_URL=http://localhost:5080

# iOS (same Wi-Fi): use this machine's LAN IP
flutter run --dart-define=INTEGRITY_SERVER_URL=http://192.168.1.10:5080
```

To reach the server over plain HTTP from a device on your LAN, iOS may need an `NSAppTransportSecurity` exception during development. In production, always use HTTPS.

## Endpoints

| Method | Path | Body | Purpose |
|---|---|---|---|
| GET | `/challenge` | — | One-time random challenge (5-minute TTL) |
| POST | `/android/verify` | `{ token, challenge }` | Decode and check a Play Integrity token |
| POST | `/ios/attest` | `{ keyId, attestation, challenge }` | Verify the one-time App Attest attestation and store the key |
| POST | `/ios/assert` | `{ keyId, assertion, clientData }` | Verify a per-request assertion. `clientData` must be JSON with a `nonce` from `/challenge` |
| POST | `/ios/devicecheck` | `{ token }` | Validate a DeviceCheck token |
| POST | `/ios/devicecheck/query` | `{ token }` | Read the device's two bits |
| POST | `/ios/devicecheck/update` | `{ token, bit0, bit1 }` | Write the device's two bits |

Responses look like `{ "ok": true|false, "reason": "...", "details": { ... } }`.

```bash
curl -s localhost:5080/challenge
curl -s -X POST localhost:5080/android/verify -H 'content-type: application/json' \
     -d '{"token":"<from app>","challenge":"<from /challenge>"}'
```

## What each verifier checks

### Play Integrity (`PlayIntegrityVerifier.cs`)

1. Google's `decodeIntegrityToken` API decrypts the token and verifies its signature, using the service account.
2. `requestDetails.requestHash` equals the challenge issued for this request.
3. `requestPackageName` (and `appIntegrity.packageName`) equal `PackageName`.
4. `timestampMillis` is no older than `TokenMaxAgeSeconds`.
5. `appIntegrity.appRecognitionVerdict == PLAY_RECOGNIZED`. Optionally, the signing certificate digest is in `AllowedCertificateSha256Digests`.
6. `deviceIntegrity.deviceRecognitionVerdict` contains `RequiredDeviceVerdict`. This is `MEETS_DEVICE_INTEGRITY` by default; use `MEETS_STRONG_INTEGRITY` for high-risk actions.

7. Optional environment policies, all off by default:
   - `RequireLicensed`: `accountDetails.appLicensingVerdict` must be `LICENSED`.
   - `RejectedPlayProtectVerdicts`: e.g. `["HIGH_RISK"]`. Needs environment details enabled in Play Console.
   - `RejectedAppAccessRisks`: e.g. `["UNKNOWN_CONTROLLING", "UNKNOWN_CAPTURING"]`, apps from outside Play that can control or read the screen.
   - `MaxDeviceActivityLevel`: e.g. `"LEVEL_2"`. `recentDeviceActivity` above it means this device asked for unusually many tokens, typical of device farms and token replay.

Every verdict field is returned in `details`, so you can log it or apply your own rules.

**Device verdict cheat sheet** (what a rooted or hooked device typically gets):

| Setup | `deviceRecognitionVerdict` |
|---|---|
| Stock, locked bootloader | `MEETS_DEVICE_INTEGRITY` (+ `MEETS_STRONG_INTEGRITY` with recent security patches) |
| Unlocked bootloader, or root with Magisk/KernelSU | usually `MEETS_BASIC_INTEGRITY` only, or nothing |
| Root hidden with Play Integrity Fix-style modules | can spoof `MEETS_DEVICE_INTEGRITY`, but not `MEETS_STRONG_INTEGRITY` (hardware-backed) |
| Emulator | none |

Require `MEETS_STRONG_INTEGRITY` for your most sensitive actions; it's the verdict that root-hiding modules can't fake.

### App Attest attestation (`AppAttestVerifier.VerifyAttestation`)

These follow Apple's *Validating apps that connect to your server* steps:

1. `fmt == "apple-appattest"`.
2. The `x5c` chain validates to the Apple App Attestation Root CA.
3. `nonce = SHA256(authData ‖ SHA256(challenge))` equals the leaf certificate's `1.2.840.113635.100.8.2` extension.
4. `SHA256(leaf public key) == keyId`.
5. `rpIdHash == SHA256("TEAMID.bundle.id")`.
6. `counter == 0`.
7. The AAGUID matches the environment: `appattestdevelop` or `appattest\0\0\0\0\0\0\0`.
8. `credentialId == keyId`.

If everything passes, the key's public key, counter and receipt are stored.

### App Attest assertion (`AppAttestVerifier.VerifyAssertion`)

1. The ECDSA P-256 signature over `SHA256(authenticatorData ‖ SHA256(clientData))` verifies with the stored public key.
2. `rpIdHash` matches.
3. The counter is **strictly greater** than the stored one. This is replay protection; the stored counter is then updated.
4. The `nonce` inside `clientData` is a valid, unused challenge.

### DeviceCheck (`DeviceCheckClient.cs`)

The server signs an ES256 JWT (`iss` = Team ID, `kid` = key ID) with the `.p8` key. It then calls Apple's `validate_device_token`, `query_two_bits` and `update_two_bits` on the development or production host, depending on `AppleEnvironment`.

## Going to production

- Store attested keys (keyId → public key, counter, receipt) in a database, linked to the user or install.
- Store challenges in a shared store (Redis or a database) when running more than one instance.
- Use **HTTPS**, authenticate callers, and rate-limit `/challenge`.
- Decide the policy per endpoint, and make it fail safely:
  - Allow low-risk reads without attestation.
  - Require a valid verdict or assertion for logins, payments and account changes.
  - Use a step-up (OTP or re-auth) instead of a hard block when the verdict is merely weak.
- Expect some legitimate users to fail: devices without Google Play, rooted enthusiasts, and older iPhones. Track failure rates before you enforce.
- Play Integrity standard requests have a daily quota, about 10,000 per day by default. You can ask Google for more.
