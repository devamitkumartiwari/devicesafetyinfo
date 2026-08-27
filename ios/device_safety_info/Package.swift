// swift-tools-version: 6.0
// The path Flutter's tooling actually scans for SPM plugin support is
// ios/<plugin_name>/Package.swift — verified against flutter_tools' plugins.dart
// (Plugin.pluginSwiftPackageManifestPath). CocoaPods (../device_safety_info.podspec)
// remains the fallback for older toolchains.
import PackageDescription

let package = Package(
    name: "device_safety_info",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "device-safety-info", targets: ["device_safety_info"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/securing/IOSSecuritySuite",
            from: "1.9.11"
        ),
        // Local package Flutter's tooling synthesizes at build time, wrapping Flutter.xcframework
        // — resolves `import Flutter`. Not present outside a real Flutter build (e.g. bare
        // `swift build` from this directory won't find it; that's expected).
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        // SwiftPM doesn't support mixed Swift+C source files in a single target — the C source
        // (linked via @_silgen_name, no header/import needed) lives in its own target so the
        // Swift target above can stay pure-Swift.
        .target(
            name: "device_safety_ffi",
            path: "Sources/device_safety_ffi"
        ),
        .target(
            name: "device_safety_info",
            dependencies: [
                .product(name: "IOSSecuritySuite", package: "IOSSecuritySuite"),
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "device_safety_ffi",
            ],
            path: "Sources/device_safety_info",
            swiftSettings: [
                // Keep Swift 5 language mode: the @_silgen_name FFI pattern and
                // NSObject-based plugin registration are Swift 5 idiomatic. Swift 6
                // strict-concurrency checking would require a larger migration.
                .swiftLanguageVersion(.v5)
            ]
        ),
    ]
)
