# Principles

@Metadata {
    @TitleHeading("Swift Institute")
}

The design principles the ecosystem is built on — what distinguishes it from other Swift package collections, and how each principle shows up in the code you'd write against it.

## Overview

The design principles the ecosystem is built on. Each is illustrable in a short code example.

### Specifications as namespaces

Types mirror the specifications that define them. The RFC or ISO identifier is the namespace. When you read a type name, you know which specification governs its behaviour.

```swift
import RFC_3986
import RFC_4122

let endpoint: RFC_3986.URI    // governed by RFC 3986
let id: RFC_4122.UUID         // governed by RFC 4122
```

### Concrete errors

Throwing functions declare their error type. Callers get exhaustive switches, not catch-all blocks. The error type is part of the API contract, not an afterthought.

```swift
// The concrete error type is visible at the call site.
func parse(_ input: Input) throws(Parse.Error) -> Output
```

### Foundation independence

No Foundation import at any layer. The ecosystem provides its own timestamps, paths, buffers, and string processing, so the same types compile wherever Swift compiles.

| Platform | Status |
|----------|--------|
| Darwin (macOS, iOS, tvOS, watchOS, visionOS) | Supported |
| Linux | Supported |
| Embedded Swift | Coming soon |
| Windows | Coming soon |

Resources with unique ownership — file descriptors, kernel handles, connection state — use `~Copyable` so the compiler tracks their lifecycle rather than deferring to runtime checks.

### Granular composition

There is no umbrella import. Consumers depend on individual packages:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-{concept}-primitives", from: "0.1.0"),
    .package(url: "https://github.com/swift-ietf/swift-rfc-{number}", from: "0.1.0"),
]
```

The ecosystem spans three layers — <doc:Architecture> — each building only on layers below.
