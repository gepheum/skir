# skir-swift-client

Runtime library for [Skir](https://skir.build)-generated Swift code.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/gepheum/skir-swift-client", branch: "main"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "SkirClient", package: "skir-swift-client"),
        ]
    ),
]
```
