// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Rostrum",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "Rostrum", targets: ["Rostrum"]),
        .library(name: "RostrumLayout", targets: ["RostrumLayout"])
    ],
    targets: [
        .target(name: "Rostrum"),
        .target(name: "RostrumLayout", dependencies: ["Rostrum"]),
        .testTarget(name: "RostrumLayoutTests", dependencies: ["RostrumLayout", "Rostrum"]),
        .executableTarget(
            name: "ClimateDeck",
            dependencies: ["Rostrum"],
            path: "Examples/ClimateDeck"),
        .executableTarget(
            name: "FlexDeck",
            dependencies: ["Rostrum"],
            path: "Examples/FlexDeck"),
        .executableTarget(
            name: "SunflowerDeck",
            dependencies: ["Rostrum"],
            path: "Examples/SunflowerDeck"),
        .executableTarget(
            name: "ReadmeSnippets",
            dependencies: ["Rostrum"],
            path: "Examples/ReadmeSnippets"),
        .executableTarget(
            name: "rostrum-gen",
            path: "Tools/rostrum-gen"),
        .executableTarget(
            name: "design-audit",
            dependencies: ["Rostrum"],
            path: "Tools/design-audit"),
        .executableTarget(
            name: "rostrum-benchmark",
            dependencies: ["Rostrum"],
            path: "Tools/rostrum-benchmark"),
        .executableTarget(
            name: "pptx-tool",
            dependencies: ["Rostrum"],
            path: "Tools/pptx-tool"),
        .testTarget(
            name: "RostrumTests",
            dependencies: ["Rostrum"],
            resources: [.copy("Fixtures")]),
    ]
)
