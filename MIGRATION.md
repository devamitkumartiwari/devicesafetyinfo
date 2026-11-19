# Migrating from 1.x to 2.0

2.0 is a breaking release. Everything is reached through `DeviceSafety`, detection returns a
`CheckResult` instead of a `bool`, and you choose policies instead of the plugin deciding.

## 1. Toolchain

| 1.x | 2.0 |
|---|---|
| Flutter 3.24+ / Dart 3.13+ | **Flutter 3.50+ / Dart 3.14+** |
| CocoaPods or SwiftPM on iOS | **SwiftPM only.** Remove the plugin from any `Podfile`; run `flutter config --enable-swift-package-manager` if you disabled it. |
| Kotlin Gradle plugin applied by the plugin | Built-in Kotlin (AGP 9+). Nothing to do in your app. |
| Plugin declared `READ_PHONE_STATE` | **Not declared any more.** Add it to your manifest (and request it) if you rely on SIM call detection. |
| `ffiPlugin` + CMake | Dart build hook. Nothing to do. |

## 2. Initialization (new, optional)

```dart
await DeviceSafety.initialize(DeviceSafetyConfig(
  defaultPolicy: .standard,                 // same behavior as 1.6's default
  accessibilityAllowlist: {'com.google.android.marvin.talkback'},
));
```

## 3. Booleans become results

Every 1.x `Future<bool>` detection getter has a 2.0 `DetectionApi`:

```dart
// 1.x
if (await DeviceSafetyInfo.isRootedDevice) block();

// 2.0
if (await DeviceSafety.root.isDetected()) block();
// or, with details:
final r = await DeviceSafety.root.check();
if (r.detected) block(reason: r.signals);
```

Note that 1.x's "positive" checks (`isRealDevice`, `isScreenLock`, `isInstalledFromStore`)
become risk checks in 2.0, so their meaning **flips**: `isDetected()` is `true` for the risky
state (an emulator, no screen lock, not from a store).

## 4. Member-by-member

### `DeviceSafetyInfo` (removed)

| 1.x | 2.0 |
|---|---|
| `DeviceSafetyInfo.channel` | removed (no raw channel access) |
| `isRootedDevice` | `DeviceSafety.root.isDetected()` |
| `rootCheck` | `DeviceSafety.root.check()` (`CheckResult`; signals are typed) |
| `isRooted(policy:)` | set `policies: {CheckType.root: ...}` in the config, then `DeviceSafety.root.isDetected()` |
| `isRealDevice` | `!(await DeviceSafety.emulator.isDetected())` |
| `emulatorCheck` | `DeviceSafety.emulator.check()` |
| `isEmulator(policy:)` | config policy + `DeviceSafety.emulator.isDetected()` |
| `isHooked` | `DeviceSafety.hooking.isDetected()` |
| `checkHooked(exitProcessIfTrue:, uninstallIfTrue:)` | `DeviceSafety.hooking.check()`; exit/uninstall removed. Listen to `DeviceSafety.threats` and call `DeviceSafety.terminateApp()` yourself if you must. |
| `isDebuggerAttached` | `DeviceSafety.debugger.isDetected()` |
| `checkFridaByMaps()` | removed; part of `DeviceSafety.hooking` (signal `hooking.frida_maps`) |
| `checkRootFilesNative()` | removed; part of `DeviceSafety.root` (signal `root.native_files`) |
| `isDeveloperMode` | `DeviceSafety.posture.developerMode.isDetected()` (low risk: needs `strict` or an override to count) |
| `isScreenLock` | `!(await DeviceSafety.posture.screenLock.isDetected())` |
| `isInstalledFromStore` | `(await DeviceSafety.posture.storeInstall.check()).signals.isEmpty` |
| `isExternalStorage` | `DeviceSafety.posture.externalStorage.check()` |
| `isUnknownSourcesEnabled` | `DeviceSafety.posture.unknownSources.check()` |
| `playProtectStatus` | `DeviceSafety.posture.playProtect.check()` (signals `play_protect.disabled` / `play_protect.unknown`) |
| `enabledAccessibilityServices` | `DeviceSafety.accessibility.enabledServices()` |
| `isAnyAccessibilityServiceEnabled` | `DeviceSafety.accessibility.check()` with `accessibilityAllowlist` |
| `enabledNotificationListeners` | `DeviceSafety.notificationListeners.enabledListeners()` |
| `isAnyNotificationListenerEnabled` | `DeviceSafety.notificationListeners.check()` with `notificationListenerAllowlist` |
| `isVPNCheck` | `DeviceSafety.vpn.check()` (low risk by default; use `strict` or `signalOverrides: {'vpn.active': .high}`) |
| `isScreenCaptured` | `DeviceSafety.screen.check()` |
| `onScreenCapturedChanged` | `DeviceSafety.screen.captureChanges` |
| `onScreenshotTaken` (`Stream<void>`) | `DeviceSafety.screen.onScreenshot` (`Stream<DateTime>`) |
| `blockScreenshots({block})` | `DeviceSafety.screen.blockScreenshots(block:)` |
| `isScreenshotBlocked` | `DeviceSafety.screen.isScreenshotBlocked()` |
| `toggleScreenshotBlocking()` | `blockScreenshots(block: !(await isScreenshotBlocked()))` |
| `setScreenshotOverlayMode(mode:, ...)` | `DeviceSafety.screen.setOverlayMode(mode, ...)` |
| `clearScreenshotOverlayMode()` | `DeviceSafety.screen.clearOverlayMode()` |
| `setRecentsOverlay({argbColor})` | `DeviceSafety.appSwitcher.setOverlay(argbColor:)` |
| `clearRecentsOverlay()` | `DeviceSafety.appSwitcher.clearOverlay()` |
| `hideMenu({hide})` | `DeviceSafety.appSwitcher.hideFromRecents(hide:)` (throws on iOS instead of silently doing nothing) |
| `onOverlayAttackDetected` | `DeviceSafety.overlayAttack.obscuredTouches` |
| `blockTouchesWhenObscured({block})` | `DeviceSafety.overlayAttack.blockTouchesWhenObscured(block:)` |
| `copyToClipboard(text, ...)` | `DeviceSafety.clipboard.copySecure(text, sensitive:, clearAfter:)` |
| `clearClipboard()` | `DeviceSafety.clipboard.clear()` |
| `onClipboardChanged` | `DeviceSafety.clipboard.changes` |
| `isCallActive` | `DeviceSafety.calls.isCallActive()` |
| `onCallActivityChanged` | `DeviceSafety.calls.changes` (`CallActivityEvent.started` replaces `state`) |
| `isCallScreeningRoleAvailable` | `DeviceSafety.callScreening.isRoleAvailable()` |
| `isCallScreeningRoleHeldByThisApp` | `DeviceSafety.callScreening.isRoleHeld()` |
| `openCallScreeningRoleSettings()` | `DeviceSafety.callScreening.requestRole()` |

### Other 1.x classes

| 1.x | 2.0 |
|---|---|
| `RiskSummary.evaluate()` → `List<RiskFlag>` | `DeviceSafety.assess()` → `RiskAssessment` (`.flags`, `.results`, `.detected`); one platform round trip |
| `RiskFlag(id:, ...)` | `RiskFlag(type: CheckType, ...)` |
| `RiskCheckResult` | `CheckResult` (`highRiskSignals` / `lowRiskSignals` → `high` / `low`, typed `RiskSignal`s) |
| `RiskPolicy.standard` / `.strict` | unchanged, plus `RiskPolicy.off`; set in `DeviceSafetyConfig` |
| `RiskLevel` | unchanged |
| `VPNCheck.isVpnActive` / `isVPNActive()` / `VPNCheck()` stream | `DeviceSafety.vpn.check()` / `DeviceSafety.vpn.changes` |
| `ScreenCapture.isScreenCaptured()` | `DeviceSafety.screen.check()` |
| `ScreenRecordingDetector.isSupported` | `DeviceSafety.screen.isRecordingDetectionSupported()` |
| `ScreenRecordingDetector.onScreenRecordingChanged` | `DeviceSafety.screen.recordingChanges` |
| `onScreenRecordingStarted` / `Stopped` | `recordingChanges.where((r) => r)` / `.where((r) => !r)` |
| `MalwarePackageDetector.isPackageInstalled(p)` | `(await DeviceSafety.malware.installedOf([p])).isNotEmpty` |
| `MalwarePackageDetector.scanKnownMalware(list)` | `malwarePackages` in the config + `DeviceSafety.malware.check()` |
| `IOCDomainBlocker.isBlocked / updateBlocklist / loadRemoteBlocklist` | `DeviceSafety.ioc.isBlocked / updateBlocklist / loadRemoteBlocklist` (a failed download now throws) |
| `NewVersionChecker(...).getVersionStatus()` | `DeviceSafety.versionCheck.status(...)` (`androidPlayStoreCountry` → `androidPlayStoreLocale`; `appStoreLink` → `storeLink`) |
| `NewVersionChecker.getLocalVersion()` | `DeviceSafety.versionCheck.localVersion()` |
| `AppIntegrity.*` (1.7.0, unreleased) | `DeviceSafety.integrity.*`; availability getters became methods (`isPlayIntegrityAvailable()`) |
| `AttestationException` / `AttestationErrorCode` | unchanged (now part of the sealed `DeviceSafetyException`) |
| `SecureScreen`, `IdleTimeoutGuard`, `ScreenshotOverlayMode`, `CallActivityEvent`, `CallActivitySource` | unchanged names |
| `PlayProtectStatus` | removed; read `DeviceSafety.posture.playProtect.check()` signals |

### Imports

Every top-level library except the barrel was removed:

```dart
// 1.x
import 'package:device_safety_info/vpn_check.dart';
import 'package:device_safety_info/risk_summary.dart';
// 2.0
import 'package:device_safety_info/device_safety_info.dart';
```

## 5. Errors

1.x silently returned `false` when a check failed. 2.0 makes failures visible:

- Detection: `CheckResult.status` is `error` or `timedOut`; `detected` follows the fail mode
  (`open` = not detected, as in 1.x; `closed` = detected).
- Actions: throw `UnsupportedPlatformException`, `PermissionMissingException` or
  `NativeFailureException` (all `DeviceSafetyException`).

## 6. Tests

Replace mocked `MethodChannel` handlers with fakes from `package:device_safety_info/testing.dart`
and `DeviceSafety.forTesting(...)`; see the README's "Testing your app".
