// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Move",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Move", path: "Sources/Move")
    ]
)
