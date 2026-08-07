// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "RCodeBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "RCodeBar",
            path: "Sources/RCodeBar"
        ),
        .testTarget(
            name: "RCodeBarTests",
            dependencies: ["RCodeBar"],
            path: "Tests/RCodeBarTests"
        ),
    ]
)
