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
aren't affected. CI checks the repo out under the right name.

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

CI also runs the iOS build on macOS and fails if `lib/` imports `material.dart` or `cupertino.dart`.

## Performance benchmark

See the header of `example/integration_test/perf_test.dart` and the recorded numbers in
`example/integration_test/PERF_BASELINE.md`.
