# Apple swift-http-api-proposal: Ownership and Concurrency Patterns

**Date**: 2026-04-02
**Source**: `/Users/coen/Developer/apple/swift-http-api-proposal/Sources/`
**Status**: External prior art analysis
**Relevance**: ~Copyable / ~Escapable API design at Apple's proposed HTTP layer

---

## Overview

Apple's `swift-http-api-proposal` repository is a reference implementation for a new HTTP client and server API targeting Swift 6.2+ (macOS 26.2 / iOS 26.2). It makes heavy use of ~Copyable types, ~Escapable types, lifetime annotations, region-based isolation (`sending`), and `SendableMetatype` — features that are either very new or still under active evolution.

This document catalogues five patterns observed in the codebase, with exact code excerpts and analysis of their implications for the Swift Institute ecosystem.

---

## Pattern 1: `consuming sending` Combination on Closure Parameters

### Observation

Throughout the repository, closure parameters that accept ~Copyable values use the combined modifier `consuming sending`. This appears in protocol requirements, protocol method implementations, closure-typed stored properties, and `@Sendable @escaping` closure parameters.

### Source: `ConcludingAsyncReader.swift:50-52`

```swift
consuming func consumeAndConclude<Return, Failure: Error>(
    body: (consuming sending Underlying) async throws(Failure) -> Return
) async throws(Failure) -> (Return, FinalElement)
```

The `Underlying` associated type is constrained `AsyncReader, ~Copyable, ~Escapable`. The closure receives it as `consuming sending Underlying`.

### Source: `ConcludingAsyncWriter.swift:46-48`

```swift
consuming func produceAndConclude<Return>(
    body: (consuming sending Underlying) async throws -> (Return, FinalElement)
) async throws -> Return
```

Same pattern — the `Underlying` writer (also `~Copyable, ~Escapable`) is passed into the async closure with `consuming sending`.

### Source: `HTTPServerRequestHandler.swift:86-91`

```swift
func handle(
    request: HTTPRequest,
    requestContext: HTTPRequestContext,
    requestBodyAndTrailers: consuming sending RequestReader,
    responseSender: consuming sending HTTPResponseSender<ResponseWriter>
) async throws
```

Here the pattern appears directly on a protocol method's parameters, not inside a closure type. The `RequestReader` is `ConcludingAsyncReader & ~Copyable` and `HTTPResponseSender<ResponseWriter>` is `~Copyable` (with `Sendable` explicitly marked `@available(*, unavailable)`).

### Source: `HTTPServerClosureRequestHandler.swift:50-56`

The same combination appears in a stored closure property:

```swift
private let _handler:
    @Sendable (
        HTTPRequest,
        HTTPRequestContext,
        consuming sending RequestReader,
        consuming sending HTTPResponseSender<ResponseWriter>
    ) async throws -> Void
```

And again in the `init` parameter:

```swift
public init(
    handler:
        @Sendable @escaping (
            HTTPRequest,
            HTTPRequestContext,
            consuming sending RequestReader,
            consuming sending HTTPResponseSender<ResponseWriter>
        ) async throws -> Void
) {
    self._handler = handler
}
```

### Why This Matters

The two modifiers serve orthogonal purposes:

- **`consuming`**: The callee takes ownership of the value. For ~Copyable types, this is the only way to transfer a value into a closure — you cannot copy it, and borrowing would not allow the closure to store or forward it. The outer method is itself `consuming` on `self`, so the entire chain is a one-shot ownership transfer: the protocol value is consumed, and its inner resource is moved into the closure.

- **`sending`**: Satisfies Swift 6's region-based isolation checking. An `async` closure may execute in a different isolation domain than the caller. Without `sending`, the compiler cannot prove that the value does not alias mutable state in the caller's region. `sending` asserts that the value is being transferred to the callee's region exclusively.

The combination `consuming sending` is necessary when:
1. The value is ~Copyable (mandates `consuming` or `borrowing`, and borrowing is insufficient for async closures that outlive the call).
2. The value crosses an isolation boundary (mandates `sending`).

Neither modifier alone is sufficient. `consuming` without `sending` would fail region isolation checking. `sending` without `consuming` would fail ownership checking for ~Copyable types.

### Relationship to Swift Institute

The Swift Institute ecosystem uses ~Copyable types extensively (channels, file descriptors, kernel handles, Storage.Inline, etc.) but has not yet adopted `sending` on closure parameters. The `inout sending` pattern is used in `Mutex.withLock` wrappers (per memory note `inout-sending-mechanism.md`), but the `consuming sending` combination for one-shot transfer into async closures is not present. Any future async streaming or IO callback APIs will need this exact pattern.

---

## Pattern 2: Asymmetric Lifetime Annotations — Readers Borrow, Writers Copy

### Observation

`AsyncReader.read` and `AsyncWriter.write` use different lifetime annotations. The reader uses `@_lifetime(&self)` (borrow), while the writer uses `@_lifetime(self: copy self)` (copy). Both are conditionally compiled only for compilers before 6.3, because Swift 6.3+ infers these lifetimes.

### Source: `AsyncReader.swift:59-66`

```swift
#if compiler(<6.3)
@_lifetime(&self)
#endif
mutating func read<Return, Failure: Error>(
    maximumCount: Int?,
    body: (consuming Span<ReadElement>) async throws(Failure) -> Return
) async throws(EitherError<ReadFailure, Failure>) -> Return
```

The `@_lifetime(&self)` annotation means the return value's lifetime is bounded by the mutable borrow of `self`. In practice: the `Span<ReadElement>` passed to `body` is valid only while `self` is mutably borrowed. Once `read` returns, the borrow ends. This is correct for reads — the data lives inside the reader's buffer, and the caller gets a view into it.

The same annotation appears on the convenience overload at line 96-102 and on `AsyncMapReader.read` at line 74-76:

```swift
#if compiler(<6.3)
@_lifetime(&self)
#endif
mutating func read<Return, Failure>(
    maximumCount: Int?,
    body: (consuming Span<MappedElement>) async throws(Failure) -> Return
) async throws(EitherError<Base.ReadFailure, Failure>) -> Return {
```

### Source: `AsyncWriter.swift:54-59`

```swift
#if compiler(<6.3)
@_lifetime(self: copy self)
#endif
mutating func write<Result, Failure: Error>(
    _ body: (inout OutputSpan<WriteElement>) async throws(Failure) -> Result
) async throws(EitherError<WriteFailure, Failure>) -> Result
```

The `@_lifetime(self: copy self)` annotation means the mutated `self` after the call has the same lifetime as `self` before the call — the write operation does not shorten `self`'s lifetime. This is critical for writers because writes are typically chained: you call `write` multiple times on the same writer. If each `write` consumed a lifetime tick, the writer would become unusable after one call.

The same annotation appears on `write(_ span:)` at line 82-84 and `write(_ element:)` at line 142-144:

```swift
#if compiler(<6.3)
@_lifetime(self: copy self)
#endif
public mutating func write(_ element: consuming WriteElement) async throws(WriteFailure) {
```

### Why This Matters

The asymmetry encodes a fundamental semantic difference:

- **Reads produce borrowed views**. A `Span<ReadElement>` is a non-owning view into the reader's internal buffer. Its lifetime cannot exceed the borrow scope of the reader. The `@_lifetime(&self)` annotation makes this explicit.

- **Writes mutate but preserve identity**. A writer is a destination, not a source. Writing into it changes internal state (buffer position, etc.) but does not change the writer's own lifetime. The `@_lifetime(self: copy self)` annotation expresses that the writer's post-mutation lifetime equals its pre-mutation lifetime — it remains valid for further writes.

The `#if compiler(<6.3)` guard is notable: Apple expects these annotations to become unnecessary as the compiler's lifetime inference matures. They are present only as explicit documentation for older compilers.

### Relationship to Swift Institute

The Swift Institute ecosystem uses `@_lifetime` annotations in several places (notably `Property.View` and span-returning accessors). The reader-borrows / writer-copies asymmetry matches the intuition already present in the IO layer: `File.read` returns data bounded by the file descriptor's lifetime, while `File.write` preserves the descriptor for reuse. However, the ecosystem has not yet adopted the `#if compiler(<6.3)` conditional pattern for forward-compatible lifetime annotations. This is a clean pattern worth adopting: annotate for correctness on current compilers, let inference handle it on future ones.

---

## Pattern 3: `some (Protocol & ~Copyable & ~Escapable)` Opaque Returns

### Observation

The `map` method on `AsyncReader` returns an opaque type that composes a protocol conformance with suppressions of both `Copyable` and `Escapable`:

### Source: `AsyncReader+map.swift:44-48`

```swift
@_lifetime(copy self)
public consuming func map<MappedElement>(
    _ transformation: @escaping (borrowing ReadElement) async -> MappedElement
) -> some (AsyncReader<MappedElement, ReadFailure> & ~Copyable & ~Escapable) {
    return AsyncMapReader(base: self, transformation: transformation)
}
```

The concrete backing type is `AsyncMapReader`, defined in the same file:

```swift
@available(macOS 26.2, iOS 26.2, watchOS 26.2, tvOS 26.2, visionOS 26.2, *)
struct AsyncMapReader<Base: AsyncReader & ~Copyable & ~Escapable, MappedElement: ~Copyable>: AsyncReader, ~Copyable, ~Escapable {
    typealias ReadElement = MappedElement
    typealias ReadFailure = Base.ReadFailure

    var base: Base
    var transformation: (borrowing Base.ReadElement) async -> MappedElement

    @_lifetime(copy base)
    init(
        base: consuming Base,
        transformation: @escaping (borrowing Base.ReadElement) async -> MappedElement
    ) {
        self.base = base
        self.transformation = transformation
    }

    #if compiler(<6.3)
    @_lifetime(&self)
    #endif
    mutating func read<Return, Failure>(
        maximumCount: Int?,
        body: (consuming Span<MappedElement>) async throws(Failure) -> Return
    ) async throws(EitherError<Base.ReadFailure, Failure>) -> Return {
        var buffer = RigidArray<MappedElement>()
        return try await self.base
            .read(maximumCount: maximumCount) { (span) throws(Failure) -> Return in
                guard span.count > 0 else {
                    let emptySpan = InlineArray<0, MappedElement>.zero()
                    return try await body(emptySpan.span)
                }

                buffer.reserveCapacity(span.count)

                for index in span.indices {
                    let transformed = await self.transformation(span[index])
                    buffer.append(transformed)
                }

                return try await body(buffer.span)
            }
    }
}
```

### Why This Matters

The return type `some (AsyncReader<MappedElement, ReadFailure> & ~Copyable & ~Escapable)` does three things simultaneously:

1. **Hides the concrete type** (`AsyncMapReader`) behind an opaque return, preserving API stability.
2. **Preserves the protocol conformance** — callers can use the result as any `AsyncReader`.
3. **Propagates suppression constraints** — the result is neither copyable nor escapable, matching the input reader's constraints.

Without `& ~Copyable & ~Escapable` in the opaque return, the compiler would default to requiring `Copyable` and `Escapable` conformance on the opaque type, which `AsyncMapReader` cannot satisfy (it stores a `~Copyable & ~Escapable` base).

The `@_lifetime(copy self)` on the `consuming` method is also significant: it declares that the returned value's lifetime is a copy of `self`'s lifetime. Since the method is `consuming`, `self` is moved into the result — the "copy" here means the result inherits the same lifetime constraints that `self` had, not that `self` is duplicated.

### Relationship to Swift Institute

The Swift Institute uses `some Protocol` returns in several places but has not yet combined them with `& ~Copyable & ~Escapable`. The rendering witness migration (`rendering-witness-migration.md`) and stream operators would benefit from this pattern: a `map`-like transform on a ~Copyable stream should return `some (StreamProtocol & ~Copyable)` rather than exposing a concrete `MappedStream<Base>` type. This keeps the public API surface minimal while correctly propagating ownership constraints.

---

## Pattern 4: `SendableMetatype` Constraint on Associated Types

### Observation

The `HTTPClient` and `HTTPServer` protocols constrain their associated types with `SendableMetatype`:

### Source: `HTTPClient.swift:25-31`

```swift
/// The type used to write request body data and trailers.
// TODO: Check if we should allow ~Escapable readers https://github.com/apple/swift-http-api-proposal/issues/13
associatedtype RequestWriter: AsyncWriter, ~Copyable, SendableMetatype
where RequestWriter.WriteElement == UInt8

/// The type used to read response body data and trailers.
// TODO: Check if we should allow ~Escapable writers https://github.com/apple/swift-http-api-proposal/issues/13
associatedtype ResponseConcludingReader: ConcludingAsyncReader, ~Copyable, SendableMetatype
where ResponseConcludingReader.Underlying.ReadElement == UInt8, ResponseConcludingReader.FinalElement == HTTPFields?
```

### Source: `HTTPServer.swift:23-29`

```swift
/// The type used to read request body data and trailers.
// TODO: Check if we should allow ~Escapable readers https://github.com/apple/swift-http-api-proposal/issues/13
associatedtype RequestConcludingReader: ConcludingAsyncReader, ~Copyable, SendableMetatype
where RequestConcludingReader.Underlying.ReadElement == UInt8, RequestConcludingReader.FinalElement == HTTPFields?

/// The type used to write response body data and trailers.
// TODO: Check if we should allow ~Escapable writers https://github.com/apple/swift-http-api-proposal/issues/13
associatedtype ResponseConcludingWriter: ConcludingAsyncWriter, ~Copyable, SendableMetatype
where ResponseConcludingWriter.Underlying.WriteElement == UInt8, ResponseConcludingWriter.FinalElement == HTTPFields?
```

Also in `HTTPClientRequestBody.swift:55-56`:

```swift
public struct HTTPClientRequestBody<Writer: AsyncWriter & ~Copyable>: Sendable
where Writer.WriteElement == UInt8, Writer: SendableMetatype {
```

### Why This Matters

`SendableMetatype` is a constraint that ensures the **metatype** (i.e., `T.Type` / `T.self`) is `Sendable`, even when instances of `T` are not. This is distinct from the `Sendable` protocol:

- `Sendable` means instances can cross isolation boundaries.
- `SendableMetatype` means the type object itself (its metatype) can cross isolation boundaries.

For ~Copyable types that are intentionally non-`Sendable` at the instance level (because they represent unique resources that must not be shared), `SendableMetatype` permits type-level operations — passing `Writer.self` across actors, storing metatype references in sendable containers, using the type as a generic parameter in sendable contexts — without requiring that instances be sendable.

This is **not documented in any accepted Swift Evolution proposal** as of this writing. It appears to be an experimental feature or an upcoming proposal that Apple is already using in their reference implementation. The `HTTPResponseSender` explicitly opts out of `Sendable`:

```swift
@available(*, unavailable)
extension HTTPResponseSender: Sendable {}
```

Yet its generic parameter `ResponseWriter` is constrained to `SendableMetatype`, allowing the type to be referenced in `@Sendable` closures without the instances themselves being sendable.

### Relationship to Swift Institute

The Swift Institute ecosystem has several ~Copyable types where the metatype needs to cross isolation boundaries but instances must not: file descriptors, kernel handles, channel endpoints, Storage.Inline containers. Currently these use `@unchecked Sendable` as a workaround in some cases (flagged in `project_unchecked_sendable_audit.md`). `SendableMetatype` could provide a cleaner solution — allowing type-level dispatch and generic instantiation across isolation domains while keeping instance-level isolation strict. This feature should be monitored for stabilization.

---

## Pattern 5: `Sendable & ~Copyable & ~Escapable` Triple Protocol Composition

### Observation

The top-level `HTTPClient` and `HTTPServer` protocols compose three orthogonal capability constraints:

### Source: `HTTPClient.swift:20`

```swift
public protocol HTTPClient<RequestOptions>: Sendable, ~Copyable, ~Escapable {
```

### Source: `HTTPServer.swift:20`

```swift
public protocol HTTPServer<RequestConcludingReader, ResponseConcludingWriter>: Sendable, ~Copyable, ~Escapable {
```

### Contrast: `Middleware.swift:26`

```swift
public protocol Middleware<Input, NextInput>: Sendable {
    /// The input type that this middleware accepts.
    associatedtype Input: ~Copyable, ~Escapable

    /// The type passed to the next middleware in the chain.
    /// Defaults to the same type as `Input` if not specified.
    associatedtype NextInput: ~Copyable, ~Escapable = Input

    func intercept(
        input: consuming Input,
        next: (consuming NextInput) async throws -> Void
    ) async throws
}
```

### Why This Matters

The three constraints in the `HTTPClient` / `HTTPServer` composition are orthogonal:

| Constraint | Meaning | Purpose in HTTP context |
|---|---|---|
| `Sendable` | Instances can cross isolation boundaries | A client/server must be usable from any actor — you create it on `MainActor`, call `perform` from a background task |
| `~Copyable` | Instances cannot be duplicated | A server owns its listening socket; copying would create aliased resource ownership. A client may own a connection pool. |
| `~Escapable` | Instances cannot escape their lexical scope | The client/server's lifetime is bounded by its creating scope — it cannot be stored in a global or escape into an unstructured task |

This triple composition is remarkable because `Sendable` and `~Escapable` are in tension: `Sendable` permits crossing isolation domains (which usually implies the value can be stored somewhere in the destination domain), while `~Escapable` forbids escaping scope. The resolution is that `sending` transfers the value's region without storing it — it moves through the isolation boundary within a scoped operation (like an `async` call) but cannot be captured into long-lived storage.

The `Middleware` protocol takes a different approach: the middleware itself is `Sendable` (and implicitly `Copyable` and `Escapable` — no suppressions), but its associated types `Input` and `NextInput` are `~Copyable, ~Escapable`. This means middleware instances are freely shareable (they are typically stateless interceptors), but the data flowing through the pipeline is uniquely owned and scope-bounded.

This creates a clear architectural split:
- **Infrastructure types** (client, server): `Sendable, ~Copyable, ~Escapable` — shareable across actors, but uniquely owned and scope-bounded.
- **Pipeline types** (middleware): `Sendable` only — freely copyable and escapable, because they are stateless processors.
- **Data types** (readers, writers, request bodies): `~Copyable, ~Escapable` — uniquely owned, scope-bounded, not sendable at the instance level.

### Relationship to Swift Institute

The Swift Institute currently uses `~Copyable` and `Sendable` independently but has not combined them with `~Escapable` in protocol definitions. The five-layer architecture has a natural fit for this triple:

- **L1 Primitives**: Types like `Storage.Inline` and channel endpoints are `~Copyable`. Adding `~Escapable` where appropriate would prevent these from leaking into global state.
- **L3 Foundations**: IO types like `File` are already `~Copyable` (via the file descriptor). An `HTTPClient`-like pattern of `Sendable, ~Copyable, ~Escapable` would enforce that file handles are usable across actors but cannot escape their structured lifetime.
- **Middleware patterns**: The `Middleware` approach of keeping the processor `Sendable` but the payload `~Copyable, ~Escapable` aligns with the witness architecture — witnesses are value types (copyable, sendable) that operate on uniquely-owned data.

---

## Implications for Swift Institute

### 1. `consuming sending` Is the Canonical Transfer Pattern for Async ~Copyable APIs

Any future async API in the ecosystem that accepts a ~Copyable value into an async closure will need `consuming sending`. This includes:
- Async file operations that consume a descriptor
- Channel send/receive with async continuations
- Any callback-based API where a ~Copyable resource is handed to an async closure

The pattern is consistent across Apple's codebase — it appears in protocol requirements, concrete methods, stored closures, and `@Sendable @escaping` parameters.

### 2. Lifetime Annotations Should Be Conditional on Compiler Version

The `#if compiler(<6.3)` pattern for lifetime annotations is a pragmatic approach: annotate explicitly for correctness on current compilers, but expect inference to handle it on newer ones. The ecosystem should adopt this pattern rather than unconditionally annotating (which creates maintenance burden) or unconditionally omitting (which breaks on older compilers).

### 3. Opaque Returns with Constraint Composition Enable Clean Streaming APIs

The `some (Protocol & ~Copyable & ~Escapable)` pattern solves the tension between API encapsulation and constraint propagation. Stream transformation operators (`map`, `filter`, etc.) should return opaque types with explicit constraint suppressions rather than exposing concrete wrapper types.

### 4. `SendableMetatype` Is an Emerging Tool — Monitor but Do Not Adopt Yet

Apple is using `SendableMetatype` in production-quality reference code, but it has no corresponding Swift Evolution proposal. It solves a real problem (metatype sendability for ~Copyable types), and the ecosystem has types that would benefit. However, adopting an undocumented feature in infrastructure packages would violate the stability expectations of L1/L2. Track this for adoption once it stabilizes.

### 5. The Triple `Sendable & ~Copyable & ~Escapable` Defines a New Category of Type

This combination — "can cross isolation boundaries, cannot be duplicated, cannot escape scope" — is the correct constraint set for infrastructure handles: connection pools, server sockets, executor references. The ecosystem should evaluate which existing types fit this category, particularly in the IO and concurrency layers. The `Middleware` contrast (sendable processor, non-copyable/non-escapable data) also maps cleanly onto the witness-based architecture.
