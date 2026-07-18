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
        .executableTarget(
            name: "ClimateDeck",
            dependencies: ["Rostrum"],
            path: "Examples/ClimateDeck"),
        .executableTarget(
            name: "FlexDeck",
            dependencies: ["Rostrum"],
            path: "Examples/FlexDeck"),
        .executableTarget(
            name: "rostrum-gen",
            path: "Tools/rostrum-gen"),
        .testTarget(name: "RostrumTests", dependencies: ["Rostrum"]),
    ]
)
