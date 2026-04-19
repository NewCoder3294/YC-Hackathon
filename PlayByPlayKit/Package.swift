// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PlayByPlayKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "PlayByPlayKit", targets: ["PlayByPlayKit"]),
    ],
    targets: [
        .target(name: "PlayByPlayKit"),
        .testTarget(name: "PlayByPlayKitTests", dependencies: ["PlayByPlayKit"]),
    ]
)
