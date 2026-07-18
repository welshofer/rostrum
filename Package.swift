// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Rostrum",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "Rostrum", targets: ["Rostrum"])
    ],
    targets: [
        .target(name: "Rostrum"),
        .testTarget(name: "RostrumTests", dependencies: ["Rostrum"]),
    ]
)
