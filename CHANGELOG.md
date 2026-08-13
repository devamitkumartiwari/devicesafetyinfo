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

