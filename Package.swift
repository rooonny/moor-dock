// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Moor",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "DockGeometry"),
        .executableTarget(name: "Moor", dependencies: ["DockGeometry"]),
        .testTarget(name: "DockGeometryTests", dependencies: ["DockGeometry"]),
    ]
)
