// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KartaCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "KartaCore", targets: ["KartaCore"]),
        .library(name: "KartaPresentation", targets: ["KartaPresentation"]),
    ],
    targets: [
        .target(
            name: "KartaCore"
        ),
        .target(
            name: "KartaPresentation",
            dependencies: ["KartaCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KartaCoreTests",
            dependencies: ["KartaCore"]
        ),
        .testTarget(
            name: "KartaPresentationTests",
            dependencies: ["KartaPresentation", "KartaCore"]
        ),
    ]
)
