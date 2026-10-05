// swift-tools-version:6.0
import PackageDescription
let package = Package(name: "MarkerAuditProbe", platforms: [.macOS(.v13)], dependencies: [.package(path: "/Users/welshofer/Developer/rostrum/Lectern")], targets: [.executableTarget(name: "MarkerAuditProbe", dependencies: [.product(name: "LecternCore", package: "Lectern")])])
