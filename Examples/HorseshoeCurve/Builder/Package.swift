// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HorseshoeDeckBuilder",
    platforms: [.macOS(.v13)],
    dependencies: [.package(name: "Rostrum", path: "../../..")],
    targets: [.executableTarget(
        name: "HorseshoeDeck",
        dependencies: [
            .product(name: "Rostrum", package: "Rostrum"),
            .product(name: "RostrumLayout", package: "Rostrum")
        ])]
)
