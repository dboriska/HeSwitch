// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeSwitch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "HeSwitch",
            targets: ["HeSwitch"]
        )
    ],
    targets: [
        .target(
            name: "HeSwitch",
            path: "Sources/HeSwitch",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "HeSwitchTests",
            dependencies: ["HeSwitch"],
            path: "Tests/HeSwitchTests"
        )
    ]
)
