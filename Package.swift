// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodexHudCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "CodexHudCore",
            targets: ["CodexHudCore"]
        ),
        .executable(
            name: "CodexHudApp",
            targets: ["CodexHudApp"]
        ),
    ],
    targets: [
        .target(
            name: "CodexHudCore"
        ),
        .executableTarget(
            name: "CodexHudApp",
            dependencies: ["CodexHudCore"]
        ),
        .testTarget(
            name: "CodexHudCoreTests",
            dependencies: ["CodexHudCore"]
        ),
    ]
)
