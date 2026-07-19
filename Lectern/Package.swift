// swift-tools-version:6.0
import PackageDescription

// LecternCore — the UI-free, fully-testable core of the Lectern demo app.
// Depends on Rostrum (the sibling package one directory up). The SwiftUI app
// target (Lectern/, Liquid Glass UI + live providers) is built in Xcode and
// consumes this package; everything provable headlessly lives here.
let package = Package(
    name: "LecternCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "LecternCore", targets: ["LecternCore"]),
    ],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .target(
            name: "LecternCore",
            dependencies: [.product(name: "Rostrum", package: "Rostrum")]),
        .testTarget(
            name: "LecternCoreTests",
            dependencies: ["LecternCore"],
            resources: [.copy("Fixtures")]),
    ]
)
