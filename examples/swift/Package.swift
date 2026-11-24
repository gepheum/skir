// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "skir-swift-example",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(url: "https://github.com/gepheum/skir-swift-client", branch: "main"),
        .package(url: "https://github.com/vapor/vapor", from: "4.115.0"),
    ],
    targets: [
        // Shared module consumed by executable targets.
        .target(
            name: "MyLib",
            dependencies: [
                .product(name: "SkirClient", package: "skir-swift-client"),
            ],
            path: "Sources",
            exclude: [
                "CallService",
                "Snippets",
                "StartService",
            ]
        ),
        // Showcases how to read and write generated data types.
        .executableTarget(
            name: "Snippets",
            dependencies: ["MyLib"],
            path: "Sources/Snippets"
        ),
        // Starts a SkirRPC service on http://localhost:8787/myapi.
        .executableTarget(
            name: "StartService",
            dependencies: [
                "MyLib",
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources/StartService"
        ),
        // Sends RPCs to the running service.
        .executableTarget(
            name: "CallService",
            dependencies: ["MyLib"],
            path: "Sources/CallService"
        ),
    ]
)
