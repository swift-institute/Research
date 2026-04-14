# Apple HTTP: withClient Scoped Pattern

<!--
---
version: 1.0.0
last_updated: 2026-04-02
status: REFERENCE
tier: 3
trigger: Apple swift-http-api-proposal — answered research gap
---
-->

## Context

The `withClient` scoped resource pattern was an open question: how to combine typed throws, `~Copyable` return types, and borrowing access to a resource that must be cleaned up after use. Apple's `DefaultHTTPClient.withClient` answers this fully.

## Pattern

```swift
public static func withClient<Return: ~Copyable, Failure: Error>(
    poolConfiguration: HTTPConnectionPoolConfiguration,
    body: (borrowing DefaultHTTPClient) async throws(Failure) -> Return
) async throws(Failure) -> Return
```

Key elements:

- **Typed throws**: `throws(Failure)` — the caller's error type flows through without erasure. No `any Error` anywhere.
- **`~Copyable` return**: `Return: ~Copyable` — the body can return a non-copyable value, enabling move-only resource handoff from within the scoped block.
- **`borrowing` client parameter**: The body borrows the client — it cannot store it, move it out, or extend its lifetime beyond the closure. The client is guaranteed to be alive for the duration of `body` and cleaned up after.
- **`static` entry point**: No ambient client instance. The connection pool is created, used, and torn down within the scope. `DefaultHTTPClient.shared` exists separately for the common case.

## Design Implications

This pattern composes three Swift features that are individually well-understood but rarely combined:

1. Generic typed throws (`<Failure: Error>` + `throws(Failure)`) — caller error type is preserved
2. `~Copyable` generic return — enables returning linear types from scoped blocks
3. `borrowing` parameter convention — prevents escape of the scoped resource

The combination eliminates the need for `Result`-based workarounds or two-phase initialization patterns.

## Source

`https://github.com/apple/swift-http-api-proposal/blob/main/Sources/HTTPClient/DefaultHTTPClient.swift:96-123`
