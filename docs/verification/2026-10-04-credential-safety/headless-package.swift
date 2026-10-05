// swift-tools-version:6.0
import PackageDescription
let package = Package(name: "LecternCredentialRegression", platforms: [.macOS("26.0")],
    dependencies: [.package(name: "LecternCore", path: "/path/to/user/Developer/rostrum/Lectern")],
    targets: [
        .target(name: "Lectern", dependencies: [.product(name: "LecternCore", package: "LecternCore")]),
        .testTarget(name: "CredentialTests", dependencies: ["Lectern", .product(name: "LecternCore", package: "LecternCore")])])
