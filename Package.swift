// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodexHudCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(
            name: "CodexHudCore",
            targets: ["CodexHudCore"]
        ),
        .executable(
            name: "CodexHudApp",
            targets: ["CodexHudApp"]
        ),
        .executable(
            name: "CodexHudAutomation",
            targets: ["CodexHudAutomation"]
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
        .executableTarget(
            name: "CodexHudAutomation",
            dependencies: ["CodexHudCore"]
        ),
        .testTarget(
            name: "CodexHudCoreTests",
            dependencies: ["CodexHudCore"]
        ),
    ]
)
