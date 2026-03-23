// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacUtils",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MacUtilsCore",
            targets: ["MacUtilsCore"]
        ),
        .executable(
            name: "MacUtils",
            targets: ["MacUtilsApp"]
        )
    ],
    targets: [
        .target(
            name: "MacUtilsCore",
            path: "Sources/MacUtilsCore"
        ),
        .executableTarget(
            name: "MacUtilsApp",
            dependencies: ["MacUtilsCore"],
            path: "MacUtils",
            exclude: ["App/Info.plist", "App/MacUtils.entitlements"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("Vision"),
                .linkedFramework("ImageIO"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]
        ),
        .testTarget(
            name: "MacUtilsCoreTests",
            dependencies: ["MacUtilsCore"],
            path: "Tests/MacUtilsCoreTests"
        )
    ]
)
