## 1.5.3

* **Breaking:** `REQUEST_INSTALL_PACKAGES` is no longer declared by the plugin's own
  `AndroidManifest.xml`, so it no longer merges into every consuming app by default —
  previously every integrator paid the Play Console sensitive-permission review cost for
  this permission whether or not they used `isUnknownSourcesEnabled`, and had to know to
  opt out via `tools:node="remove"` if they didn't want it. Apps that call
  `isUnknownSourcesEnabled` must now add `<uses-permission android:name=
  "android.permission.REQUEST_INSTALL_PACKAGES" />` to their own `AndroidManifest.xml` (see
  README's [Permissions (Android)](README.md#permissions-android) section). Apps that don't
  use the feature need no manifest change. Without the permission,
  `isUnknownSourcesEnabled` already degraded to `false` via the existing
  `SecurityException` catch in `UnknownSourcesCheck.kt`, so no native code changed.

## 1.5.2

* **Fix:** `blockScreenshots(true)` crashed on iOS with `CALayerInvalid` ("layer ... is a part of
  cycle in its layer tree") on the very first call, a guaranteed, 100%-reproducible crash on real
  devices and simulators alike. `ScreenshotProtectionHandler.enableScreenshotBlocking()` added the
  secure `UITextField` as a subview of the key window, then re-parented the window's own `CALayer`
  into that field's secure sublayer — but since the field already lived inside the window's view
  hierarchy, its secure sublayer was already a descendant of `window.layer`, so the re-parent made
  the window layer its own ancestor, an illegal CoreAnimation cycle. The secure field is now hosted
  in its own separate `UIWindow` so its layer tree never overlaps the target window's before the
  re-parent happens.

## 1.5.1

* **Fix:** `isRootedDevice()` crashed with a fatal `NoSuchMethodError` on real Android 7.0/7.1
  (API 24/25) devices — the exact floor this package's README lists as the minimum supported
  version (#19). `ShellExecutor.kt` called `Process.destroyForcibly()` and
  `Process.waitFor(long, TimeUnit)` unconditionally; both were added in API 26. Since
  `isRootedDevice()` typically runs unconditionally at app startup, this was a guaranteed,
  100%-reproducible crash on API 24/25 hardware, not an edge case. Both calls are now guarded by
  `Build.VERSION.SDK_INT`, with a polling-based bounded wait on API 24/25 so the 200ms timeout
  behavior is preserved instead of falling back to an unbounded `waitFor()`. Thanks to
  [@Enrrique-Rojas](https://github.com/Enrrique-Rojas) for the detailed report and diagnosis!

## 1.5.0

**Internal restructuring — feature modules, not a rewrite.** `lib/`, the Android Kotlin plugin, and
the iOS Swift plugin are now organized as one vertical slice per feature (root detection, screen
capture, screenshot, clipboard, overlay-attack, call activity, VPN, etc.) instead of a handful of
large files implementing everything inline. This is purely structural — every existing top-level
import (e.g. `package:device_safety_info/vpn_check.dart`) and every existing `DeviceSafetyInfo`
member keeps its exact signature and behavior; nothing here is a breaking change. `compileSdk`
(and the example app's `targetSdk`) are bumped to 37.

**New — screenshot overlay modes:**
* `DeviceSafetyInfo.setScreenshotOverlayMode(mode: ScreenshotOverlayMode, ...)` /
  `clearScreenshotOverlayMode()` show a real, visible blur/color/image overlay over the active
  screen whenever a capture or recording is detected — a branded "content hidden" placeholder
  instead of the plain black rectangle `blockScreenshots` alone produces. FLAG_SECURE (Android) and
  the iOS secure-layer trick prevent the OS from rendering anything at all *into* a capture, so this
  overlay is a visible, on-screen-only effect, shown reactively while a capture/recording is active.
  Android blur requires API 31+ (degrades to a translucent scrim below that); iOS blur uses a system
  material blur style. Android + iOS.
* `DeviceSafetyInfo.isScreenshotBlocked` / `toggleScreenshotBlocking()` — convenience query/toggle
  alongside the existing `blockScreenshots`.

**New — screen-recording detection:**
* `ScreenRecordingDetector.isSupported` / `onScreenRecordingChanged` (plus
  `onScreenRecordingStarted`/`onScreenRecordingStopped` convenience filters) detect an active
  screen-recording *session*, distinct from `isScreenCaptured`/`onScreenCapturedChanged` (which
  covers screen mirroring/external-display capture). Android: backed by the real
  `WindowManager.addScreenRecordingCallback` API, API 35+ only — `isSupported` reports `false`
  below that rather than guessing. iOS has no API distinguishing "recording" from
  "mirroring/AirPlay" — both surface through the same `UIScreen.isCaptured` signal
  `isScreenCaptured` already uses, so `isSupported` is always `true` there and the two streams
  report identically; this is documented on `ScreenRecordingDetector` itself.
* **Fix:** declared the `android.permission.DETECT_SCREEN_RECORDING` manifest permission this
  feature requires (missing in the initial implementation), and made registration fail soft —
  some OEM builds deny it at runtime even when declared (observed on a Samsung device), which
  previously crashed with an uncaught `SecurityException` instead of delivering a
  `permission_denied` stream error like the plugin's other permission-gated streams do.

**New — `SecureScreen` widget**: a declarative, ref-counted wrapper (`SecureScreen(child: ...)`)
that engages `blockScreenshots` while mounted and releases it once no `SecureScreen` remains in the
tree — pure Dart, no native code of its own. Nested/sibling `SecureScreen`s compose correctly.

**`NewVersionChecker`/`VersionStatus` hardening:**
* **Fix:** `VersionStatus.canUpdate` no longer throws on a non-purely-numeric version segment
  (e.g. `"1.2.3-beta"`) — version comparison now degrades unparseable segments to `0` instead of
  crashing.
* **New:** `NewVersionChecker(minAppVersion: ...)` + `VersionStatus.urgency`
  (`UpdateUrgency.none`/`optional`/`required`) — force/required-update support. The threshold is
  always developer-supplied (your own remote config, or hardcoded), never scraped from the store,
  since anything parsed out of store HTML/metadata is one layout change away from breaking.
* **New:** `NewVersionChecker(iOSAppStoreId: ...)` — an optional numeric App Store ID fallback,
  retried when the bundle-ID-keyed lookup returns no results (a reported failure mode even for
  live, published apps).
* **Fix:** both store lookups now fail soft (return `null`) on any unexpected response shape,
  instead of letting a `TypeError`/`FormatException` escape `getVersionStatus()`.
* **Fix:** `simpleHttpGet` now has a 10s timeout; a hung store endpoint could previously hang
  `getVersionStatus()` indefinitely.
* Deliberately not implemented: release-notes/"what's new" extraction — this field is unreliable
  and inconsistently formatted across both stores; documented as a known limitation in the README
  instead of shipping a frequently-broken scraper for it.

## 1.4.1

* **Fix:** iOS builds failing under Flutter's Swift Package Manager integration with
  `product 'device-safety-info' ... not found in package 'device_safety_info'` (#17). Flutter's
  generated `FlutterGeneratedPluginSwiftPackage` requests each plugin's SPM library product by its
  pubspec name with underscores replaced by hyphens (`device-safety-info`), but `Package.swift`
  declared the product with an underscore. The product name now matches the convention used by
  every other Flutter plugin. Thanks to [@jey-avono](https://github.com/jey-avono) for reporting
  and diagnosing this!

## 1.4.0

**New checks — Android banking-malware defenses** (added in response to advisory coverage of
Android banking trojans like TrickMo/PhantomCall):
* **New:** Notification Listener enumeration — `enabledNotificationListeners` /
  `isAnyNotificationListenerEnabled` surface which apps currently hold notification-listener access
  (the mechanism banking trojans commonly abuse to intercept OTP/SMS notifications). Android only.
* **New:** Unknown-sources / sideloading check — `isUnknownSourcesEnabled`. On Android 8+ this can only
  answer "has *this app* been granted install rights" (not "has some other app"), a real API limitation
  documented in the getter's own doc comment. Requires `REQUEST_INSTALL_PACKAGES` (query-only, never
  installs anything) — strip it via `tools:node="remove"` in your manifest if you don't use this check.
* **New:** Call-screening role — `isCallScreeningRoleAvailable`, `isCallScreeningRoleHeldByThisApp`,
  `openCallScreeningRoleSettings()`. Android's `RoleManager.getRoleHolders()` (which would reveal which
  app holds the role) is a privileged system API unavailable to third-party apps — these three cover
  what's actually achievable: capability check, self-check, and a settings deep-link so the user can
  review the current holder themselves. Android only, API 29+.
* **New:** Call activity detection — `onCallActivityChanged` stream + `isCallActive` getter detect when
  *any* call (native SIM or a VoIP call from WhatsApp/Teams/Skype/Meet/imo/etc.) starts or ends, without
  identifying which app is calling (not achievable on either platform). Android: `TelephonyManager` (SIM,
  needs `READ_PHONE_STATE`) + system-wide `AudioManager` routing state (any VoIP app, generically). iOS:
  `CXCallObserver` (CallKit) + `AVAudioSession` interruption notifications. Detect-only, like every other
  stream in this plugin — no lockdown/navigation policy is embedded. Native listeners only run while the
  stream has an active subscriber.

**Dependency removal** (eliminates consumer version-conflict risk from this plugin's own
`dependencies:`):
* Removed `connectivity_plus`, `package_info_plus`, and `http` — replaced with a native
  `device_safety_info/connectivity_events` EventChannel, a native `getPackageInfo` MethodChannel call,
  and a minimal `dart:io HttpClient`-based helper (`lib/src/http/simple_http_get.dart`) respectively.
  `VPNCheck`, `NewVersionChecker`, and `IOCDomainBlocker` are unaffected from the outside.

**Toolchain modernization** (Flutter 3.47 plugin-template baseline):
* **Breaking (iOS):** minimum iOS version raised `13.0` → `16.0`.
* **Fix (iOS — Swift Package Manager):** `Package.swift` moved from the flat `ios/Package.swift` to
  `ios/device_safety_info/Package.swift` — the path Flutter's tooling actually scans for plugin SPM
  support (`Plugin.pluginSwiftPackageManifestPath` in `flutter_tools`). The previous flat location was
  never discovered by Flutter's build system, so SPM support was silently non-functional despite being
  present; only the CocoaPods path was ever exercised. The native C FFI source now lives in its own SPM
  target (`device_safety_ffi`) since SwiftPM doesn't support mixed Swift+C sources in one target.
* **Dependency:** Android toolchain baseline bumped to match the Flutter 3.47 plugin template — Gradle
  `8.14` → `9.3.1`, Android Gradle Plugin `8.12.1` → `9.1.0`, Kotlin `2.2.20` → `2.4.0`.
* **Dependency:** `flutter_lints` `any` → `^6.0.0`.
* Removed the plugin's Kotlin-level (`android/src/test/kotlin`) unit test in favor of relying solely on
  the Dart-level test suite (`test/device_safety_info_test.dart`) — one less native test dependency
  (`kotlin-test`, `mockito-core`) to keep in sync, and this plugin's actual public surface is the Dart API.

## 1.3.0
* **Fix (Android — 16 KB page size):** `libdevice_safety_ffi.so` is now linked with
  `-Wl,-z,max-page-size=16384` / `common-page-size=16384`, fixing Google Play Console's "native library
  not 16 KB compatible" warning for `arm64-v8a` and `x86_64`.
* **Fix (Android — build):** the plugin module now declares its own self-contained `buildscript`
  classpath and explicitly applies the Kotlin Android Gradle plugin, instead of relying on transitive
  application via Flutter's Gradle plugin — that assumption didn't hold under all AGP/Gradle
  declarative-`plugins{}` configurations, causing Kotlin sources to silently not compile and
  `cannot find symbol DeviceSafetyInfoPlugin` build failures (#14).
* **New:** Overlay Attack Detection — `onOverlayAttackDetected` stream and `blockTouchesWhenObscured()`
  detect/block touches delivered while another app is drawing an overlay on top of yours (tapjacking).
  Android only; throws `PlatformException('UNSUPPORTED_PLATFORM', ...)` on iOS, where app sandboxing
  makes cross-app overlays structurally impossible.
* **New:** Clipboard Protection — `copyToClipboard()` (with `sensitive` + `autoClear` options),
  `clearClipboard()`, and `onClipboardChanged` stream. Android: `ClipDescription.EXTRA_IS_SENSITIVE`
  (API 33+). iOS: `UIPasteboard` `.expirationDate`/`.localOnly`. Android + iOS.
* **New:** `IOCDomainBlocker` — lightweight IOC/C2 domain-reputation lookup (`isBlocked`,
  `updateBlocklist`, `loadRemoteBlocklist`) to wire into your own HTTP client or WebView guard.
  Pure Dart, no native dependency. Android + iOS.
* **New:** Malware Package Detection — `MalwarePackageDetector.isPackageInstalled()` /
  `scanKnownMalware()` check specific package names against a list you supply. Android only.
  Requires declaring each package name in your app's own `<queries>` manifest block (Android 11+
  package visibility filtering) — this plugin deliberately doesn't request the broader
  `QUERY_ALL_PACKAGES` permission, which Google Play gates behind manual approval and would be
  merged into every app depending on this plugin.
* **New:** Accessibility Abuse Detection — `DeviceSafetyInfo.enabledAccessibilityServices` /
  `isAnyAccessibilityServiceEnabled` read `Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES`. Android
  only, no new permission.
* **New:** Play Protect Status — `DeviceSafetyInfo.playProtectStatus` reads the `package_verifier_user_consent`
  OS setting Play Protect's toggle controls. Android only, no new permission or dependency. (SafetyNet's
  Verify Apps API, the old documented way to read this, was fully retired in January 2025.)
* **New:** Idle Session Timeout — `IdleTimeoutGuard` widget fires a callback after a period of no
  touch activity anywhere in the wrapped subtree. Pure Dart, no native code, Android + iOS.
* **New:** Risk Summary — `RiskSummary.evaluate()` aggregates the rooted/hooked/debugger/screen-capture/VPN/
  screen-lock checks into a list of plain-language `RiskFlag`s. Pure Dart, no new platform channel calls.

## 1.2.0
* **Fix (Android — ANR):** `isRootedDevice` and `isHooked` now run on a background thread pool — eliminates main-thread shell spawning and ANR risk.
* **Fix (Android — Performance):** `SystemPropsChecker` now reads system properties via `android.os.SystemProperties` reflection (zero-cost cache read) before falling back to `getprop` shell spawn — worst-case latency for 4 property checks drops from ~800 ms to near-zero.
* **Fix (Android):** `ShellExecutor` migrated from `Runtime.exec()` to `ProcessBuilder` — stdout is now drained concurrently with `waitFor`, eliminating a race condition where `readLine()` blocked after the timeout expired.
* **Fix (Android):** API-34 `ScreenCaptureCallback` executor was never shut down on `stopScreenshotDetection()` — fixed resource leak.
* **New (Android):** 30-second TTL result cache for `isRootedDevice` and `isHooked` — repeated polls within the window return immediately without spawning any processes.
* **Dependency (Android):** Kotlin updated `1.9.22` → `2.2.0`; Android Gradle Plugin `8.2.2` → `8.12.1`.
* **Dependency (iOS SPM):** `swift-tools-version` bumped `5.9` → `6.0` (compiles in Swift 5 language mode — no source changes needed).
* **Dependency (iOS SPM):** IOSSecuritySuite minimum version raised from `1.9.0` to `1.9.11`.
* **Dependency (Dart):** Dart SDK floor raised to `>=3.5.0`; Flutter floor raised to `>=3.24.0` — this also fixes the "Swift Package Manager not supported" flag on pub.dev (pub.dev requires Flutter ≥ 3.19.0 to recognise SPM support). `flutter_lints` pinned to `^6.0.0`.

## 1.1.0
* **New:** `onScreenshotTaken` stream — fires when the user takes a screenshot. Android API 34+: uses `Activity.ScreenshotCallback` (no permission needed). Android API 24–33: uses `MediaStore` `ContentObserver` (host app must hold `READ_MEDIA_IMAGES` at runtime). iOS: `UIApplication.userDidTakeScreenshotNotification` (no permission needed).
* **New:** `setRecentsOverlay({int argbColor})` — shows a solid-color overlay over the app thumbnail in the recent-apps switcher. Automatically shown on background, hidden on foreground. Android + iOS.
* **New:** `clearRecentsOverlay()` — removes the recents overlay.
* **Fix:** `blockScreenshots()` now works on iOS via the `UITextField.isSecureTextEntry` layer trick — the key window's `CALayer` is re-parented into the text field's secure sublayer, which the system protects from screenshots and recordings.
* **New:** `dart:ffi` native C/C++ layer — Frida `/proc/self/maps` scan + port scan (27042/27043), root `stat()` check, and debugger `TracerPid` check all run below the JVM/Swift runtime, making them significantly harder to hook
* **New:** Swift Package Manager (SPM) support via `Package.swift` — Flutter 3.19+ projects can now resolve the plugin without CocoaPods
* **New:** `isDebuggerAttached` API — detects attached debuggers via native sysctl (iOS) and TracerPid (Android)
* **New:** `isHooked` now implemented on iOS via `IOSSecuritySuite.amIReverseEngineered()`
* **New:** `checkFridaByMaps()` and `checkRootFilesNative()` exposed as standalone public APIs
* **Fix:** `isRootedDevice` now combines native C `stat()` check with JVM-level check — false negatives from hooked `File.exists()` no longer silently bypass detection
* **Fix:** `isVPNCheck` and `isRootedDevice` were returning `true` as default on null/error — corrected to `false`
* **Fix:** `ScreenCaptureDetector` was flagging HDMI monitors and Chromecast as screen captures — fixed with `FLAG_PRESENTATION` check
* **Fix:** `ro.debuggable=1` was incorrectly flagging all developer/debug builds as rooted — removed from root detection
* **Fix:** `com.google.android.packageinstaller` was listed as a trusted store — it is the APK sideload installer; removed
* **Fix:** iOS `#if TARGET_OS_SIMULATOR` C macro silently had no effect in Swift — corrected to `#if targetEnvironment(simulator)`
* **Fix:** iOS `UIScreen.main.isCaptured` deprecated in iOS 16 — replaced with scene-based API with fallback
* **Fix:** `blockScreenshots`/`hideMenu` returned success silently when `Activity` was null — now returns `error("NO_ACTIVITY")`
* **Fix:** `exitProcess(0)` was called before `result.success()` — Dart Future now resolves before process exits
* **Fix:** `DisplayListener` was not unregistered on engine detach — memory leak fixed
* **Fix:** `VPNCheck` stream now emits initial VPN state immediately on creation
* **Fix:** `ShellExecutor` timeout increased from 50 ms to 200 ms; stderr now drained to prevent process hangs
* **Fix:** Production `print()` calls replaced with `debugPrint()` throughout
* **Fix:** Podspec metadata (version, description, homepage, author) updated from placeholder values
* **Removed:** `ro.debuggable` false-positive root indicator
* **Removed:** `com.google.android.packageinstaller` from trusted stores
* **Removed:** Unused `LaunchModeVersion` enum
* **Removed:** Dead pre-API-17 code path in `DevelopmentModeCheck` (minSdk is 24)

## 1.0.3
* @magnus-lpa thank you for contributing screen lock issue in iOS
* @UADACID thank you for pointing out 16KB issue in Android fixed


## 1.0.2
> Note: This release has breaking changes.
> On Android plugin now requires the following:
> - Android Gradle Plugin >=8.12.1
> - Gradle wrapper >=8.13
> - Kotlin 2.2.0


## 1.0.1
* Android isRealDevice check issue fixed


## 1.0.0
* Dependency updated
* iOS issue fixed
* Application is installed from store check feature added
* Local and store version check feature added


## 0.0.9
* Dependency updated
* iOS issue fixed
* @jiazeh thank you for contributing
* AndroidManifest.xml issue fixed


## 0.0.8
* iOS issue fixed


## 0.0.7
* Dependency updated
* iOS issue fixed


## 0.0.6
* Dependency updated
* VPN module modification


## 0.0.5
* Dependency updated
* AGP version updated
* Kotlin version updated
* Code refactoring


## 0.0.4
* Dependency updated
* AGP version updated
* Kotlin version updated
* Code refactoring


## 0.0.3
* VPN detection issue fixed in iOS


## 0.0.2
* Example project and documentation updated


## 0.0.1
* Flutter JailBreak, Rooted, Emulator/Simulator, External storage, VPN Detector, Application Update Checker and Screen Lock  detection.

