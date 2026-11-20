# Contributing

## Toolchain

- Flutter 3.50 or newer (Dart 3.14).
- Android: the example app uses AGP 9.3.1, Gradle 9.5.0 and built-in Kotlin.
- iOS: Swift Package Manager only. CocoaPods isn't supported.

## Checkout folder name (iOS)

Clone the repository into a folder named `device_safety_info`:

```sh
git clone https://github.com/devamitkumartiwari/devicesafetyinfo.git device_safety_info
```

Flutter links a path dependency into the Xcode build under the name of its folder. If the folder
is named `devicesafetyinfo`, SwiftPM sees a package identity that doesn't match the package name
`device_safety_info` and rejects the local override, so the example fails to build for iOS. This
affects only local development of this repository; apps that depend on the published package
aren't affected.

## Windows: Kotlin "different roots" build error

When the pub cache (usually on `C:`) and the checkout are on different drives, Kotlin's incremental
compiler can fail with `Could not close incremental caches … this and base files have different
roots`. Add `kotlin.incremental=false` to `example/android/gradle.properties` locally (don't commit
it), or keep the checkout on the same drive as the pub cache.

## Checks before a pull request

```sh
flutter analyze
flutter test
cd example && flutter build apk --debug
```

Also check before a release:

```sh
# iOS (on a Mac), Swift Package Manager only
cd example && flutter build ios --no-codesign
# lib/ must not depend on material or cupertino
grep -rnE "package:flutter/(material|cupertino)\.dart" lib && echo "fix these imports"
# generated code is up to date
dart run pigeon --input pigeon/device_safety_api.dart && git diff --exit-code
dart run ffigen --config ffigen.yaml && git diff --exit-code   # needs libclang (see below)
dart run tool/gen_signatures.dart --check                     # detection strings (also a unit test)
# Kotlin unit tests (after building the example once)
cd example/android && ./gradlew :device_safety_info:testDebugUnitTest
# C checks on a connected device or emulator (needs the Android NDK)
tool/run_native_tests.sh arm64-v8a   # or x86_64 for the emulator
# end-to-end on a clean device or emulator
cd example && flutter test integration_test/plugin_test.dart -d <device>
# package skill
dart run skills_lint --skills-directory skills --published-skill-name
```

## Detection strings

Paths, package names and markers live in `tool/signatures.json`, the single source for both
Kotlin and C. After editing it run `dart run tool/gen_signatures.dart`; it rewrites
`src/dsi_signatures.g.h`, `android/.../generated/Signatures.g.kt` (both encoded, so the strings
don't appear in the binaries) and the `<queries>` block of the plugin's `AndroidManifest.xml`.

## FFI bindings without a system LLVM

ffigen needs libclang. The Android NDK ships one; on Windows, add these to a temporary copy of
`ffigen.yaml` (`<llvm>` is `<ndk>/toolchains/llvm/prebuilt/windows-x86_64`):

```yaml
llvm-path: ['<llvm>']
compiler-opts:
  - '--target=aarch64-linux-android24'
  - '-isystem<llvm>/lib/clang/<version>/include'
  - '-isystem<llvm>/sysroot/usr/include'
  - '-isystem<llvm>/sysroot/usr/include/aarch64-linux-android'
```

## Device test matrix

Before a release that changes detection, run through [docs/testing.md](docs/testing.md).

## Performance benchmark

See the header of `example/integration_test/perf_test.dart` and the recorded numbers in
`example/integration_test/PERF_BASELINE.md`.
