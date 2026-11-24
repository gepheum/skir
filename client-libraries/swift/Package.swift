// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SkirClient",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15),
    ],
    products: [
        .library(
            name: "SkirClient",
            targets: ["SkirClient"]
        ),
    ],
    targets: [
        .target(
            name: "SkirClient",
            path: "Sources/SkirClient"
        ),
        .testTarget(
            name: "SkirClientTests",
            dependencies: ["SkirClient"],
            path: "Tests/SkirClientTests"
        ),
    ]
)
