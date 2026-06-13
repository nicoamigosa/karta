// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KartaCore",
    products: [
        .library(name: "KartaCore", targets: ["KartaCore"]),
    ],
    targets: [
        .target(
            name: "KartaCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KartaCoreTests",
            dependencies: ["KartaCore"]
        ),
    ]
)
