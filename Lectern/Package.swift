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
        // Explicit `name:` so this resolves by the dependency's declared
        // identity rather than by the checkout directory's name — SwiftPM's
        // default for `.package(path:)` — which breaks in a git worktree
        // whose folder isn't literally named "rostrum" or "Rostrum".
        .package(name: "Rostrum", path: ".."),
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
