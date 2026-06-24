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

