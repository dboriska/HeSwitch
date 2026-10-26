// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeSwitch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "HeSwitch",
            targets: ["HeSwitch"]
        )
    ],
    targets: [
        .executableTarget(
            name: "HeSwitch",
            path: "Sources/HeSwitch"
        ),
        .testTarget(
            name: "HeSwitchTests",
            dependencies: ["HeSwitch"],
            path: "Tests/HeSwitchTests"
        )
    ]
)
