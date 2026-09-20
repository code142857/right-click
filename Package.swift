// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RightClickCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "RightClickCore", targets: ["RightClickCore"])],
    targets: [
        .target(name: "RightClickCore", path: "Shared"),
        .testTarget(name: "RightClickCoreTests", dependencies: ["RightClickCore"], path: "Tests")
    ]
)
