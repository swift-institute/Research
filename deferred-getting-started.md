# Getting Started

@Metadata {
    @TitleHeading("Swift Institute")
}

Add a package, import it, write code.

## Add a dependency

Each package is a standalone Swift package. Add it to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/swift-primitives/swift-{concept}-primitives",
        from: "0.1.0"
    ),
],
targets: [
    .executableTarget(
        name: "MyProject",
        dependencies: [
            .product(name: "{Concept} Primitives", package: "swift-{concept}-primitives"),
        ]
    ),
]
```

## Import

Primitives products publish Swift modules under their concept name:

```swift
import Clock_Primitives
```

Types inside follow the `Nest.Name` convention — `File.Directory.Walk` instead of `FileDirectoryWalk`. Methods do the same: `dir.walk.files()` instead of `dir.walkFiles()`. See <doc:Swift-Primitives> for the patterns used across the layer.

## Platform support

| Platform | Status |
|----------|--------|
| Darwin (macOS, iOS, tvOS, watchOS, visionOS) | Supported |
| Linux | Supported |
| Embedded Swift | Coming soon |
| Windows | Coming soon |

See <doc:Architecture> for how the layers relate, <doc:Platform> for platform specifics, or <doc:FAQ> for common questions.
