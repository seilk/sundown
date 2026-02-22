// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sundown",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SundownCore",
            targets: ["SundownCore"]
        ),
        .executable(
            name: "SundownApp",
            targets: ["SundownApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SundownApp",
            dependencies: ["SundownCore"]
        ),
        .target(
            name: "SundownCore"
        ),
        .testTarget(
            name: "SundownCoreTests",
            dependencies: ["SundownCore"]
        )
    ]
)
