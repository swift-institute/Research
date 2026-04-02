# Apple HTTP: Middleware Chain Isolation

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

How should middleware chains handle isolation when values are `~Copyable & ~Escapable`? The traditional approach (shared mutable context, isolation propagation) breaks with linear types. Apple's Middleware protocol answers: ownership transfer is the synchronization mechanism.

## Pattern

```swift
public protocol Middleware<Input, NextInput>: Sendable {
    associatedtype Input: ~Copyable, ~Escapable
    associatedtype NextInput: ~Copyable, ~Escapable = Input

    func intercept(
        input: consuming Input,
        next: (consuming NextInput) async throws -> Void
    ) async throws
}
```

Key design:

- **Middleware is `Sendable`** — middleware instances are stateless (or use only `Sendable` state). They can be shared across isolation domains, stored in collections, composed freely.
- **Values are linear** — `Input` and `NextInput` are `~Copyable & ~Escapable`. Each middleware stage takes exclusive ownership via `consuming` and passes ownership to the next stage via `consuming`.
- **No shared mutable state** — because values move through the chain rather than being shared, there is no need for isolation propagation, locks, or actors to protect concurrent access.
- **`next` is a plain closure, not `@Sendable`** — the continuation does not cross isolation boundaries; it is called in the same execution context.

## Composition

Middleware chains are built using a result builder (`MiddlewareChainBuilder`) that composes two middlewares into a `ChainedMiddleware`:

```swift
struct ChainedMiddleware<First: Middleware, Second: Middleware>: Middleware
    where First.NextInput == Second.Input
{
    func intercept(input: consuming First.Input,
                   next: (consuming Second.NextInput) async throws -> Void) async throws {
        try await first.intercept(input: input) { transformedInput in
            try await second.intercept(input: transformedInput, next: next)
        }
    }
}
```

The type system enforces that `First.NextInput == Second.Input` — middleware stages must agree on the intermediate type. Ownership flows linearly: `Input -> First -> NextInput -> Second -> NextInput -> ... -> handler`.

## Isolation Implications

This design avoids the isolation propagation problem entirely:

- No `@Sendable` closures in the data path (only the middleware type itself is `Sendable`)
- No actor boundaries between stages
- No `sending` annotations needed on the data — ownership transfer subsumes region transfer
- Isolation only matters at the edges: where the request enters the middleware chain and where the response exits

## Source

`/Users/coen/Developer/apple/swift-http-api-proposal/Sources/Middleware/Middleware.swift`
`/Users/coen/Developer/apple/swift-http-api-proposal/Sources/Middleware/ChainedMiddleware.swift`
