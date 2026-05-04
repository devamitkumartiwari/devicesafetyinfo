// swift-tools-version: 5.9
// Enables Swift Package Manager support for Flutter 3.19+.
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
            from: "1.9.0"
        ),
    ],
    targets: [
        .target(
            name: "device_safety_info",
            dependencies: [
                .product(name: "IOSSecuritySuite", package: "IOSSecuritySuite")
            ],
            path: "Classes"
        )
    ]
)
