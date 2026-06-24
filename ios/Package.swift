// swift-tools-version: 6.0
// Enables Swift Package Manager support for Flutter 3.24+.
// CocoaPods (device_safety_info.podspec) remains the fallback for older toolchains.
import PackageDescription

let package = Package(
    name: "device_safety_info",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "device_safety_info", targets: ["device_safety_info"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/securing/IOSSecuritySuite",
            from: "1.9.11"
        ),
    ],
    targets: [
        .target(
            name: "device_safety_info",
            dependencies: [
                .product(name: "IOSSecuritySuite", package: "IOSSecuritySuite")
            ],
            path: "Classes",
            swiftSettings: [
                // Keep Swift 5 language mode: the @_silgen_name FFI pattern and
                // NSObject-based plugin registration are Swift 5 idiomatic. Swift 6
                // strict-concurrency checking would require a larger migration.
                .swiftLanguageVersion(.v5)
            ]
        )
    ]
)
