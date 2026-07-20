// swift-tools-version:6.0
import PackageDescription

// LecternCore — the UI-free, fully-testable core of the Lectern demo app.
// Depends on Rostrum (the sibling package one directory up). The SwiftUI app
// targets (Lectern/, Liquid Glass UI + live providers, macOS + iOS/iPadOS) are
// built in Xcode and consume this package; everything provable headlessly lives
// here. Platform floors match Rostrum's; the apps themselves deploy at 26.0.
let package = Package(
    name: "LecternCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
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
