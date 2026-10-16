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
        .library(name: "RostrumLayout", targets: ["RostrumLayout"]),
        // The lectern.deck/1 Deck IR alone (Foundation only): one definition for
        // every renderer — LecternCore (.pptx) and DeckMonkey (.key).
        .library(name: "LecternIR", targets: ["LecternIR"]),
    ],
    targets: [
        .target(name: "Rostrum"),
        .target(name: "RostrumLayout", dependencies: ["Rostrum"]),
        .target(name: "LecternIR"),
        .testTarget(name: "LecternIRTests", dependencies: ["LecternIR"]),
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
            name: "native-fidelity",
            dependencies: ["Rostrum", "RostrumLayout"],
            path: "Tools/native-fidelity",
            exclude: ["README.md", "run.py", "test_pack.py"]),
        .executableTarget(
            name: "pptx-tool",
            dependencies: ["Rostrum"],
            path: "Tools/pptx-tool"),
        .executableTarget(
            name: "rostrum-bench",
            dependencies: ["Rostrum"],
            path: "Tools/rostrum-bench",
            exclude: ["run.py", "corpus.json"]),
        .testTarget(
            name: "RostrumTests",
            dependencies: ["Rostrum"],
            resources: [.copy("Fixtures")]),
    ]
)
