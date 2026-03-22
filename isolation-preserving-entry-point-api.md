# Isolation-Preserving AsyncSequence Operator Entry Point API

<!--
---
version: 2.0.0
last_updated: 2026-02-25
status: DECISION
tier: 2
trigger: Concrete operator types (Async.Map, Async.Filter, Async.CompactMap, Async.FlatMap) compile and pass 79 tests, but stdlib overload resolution prevents direct .map/.filter access — need an alternative entry point API
---
-->

## Context

We implemented four concrete `AsyncSequence` operator types in `swift-async` at `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Sequence/`:

- `Async.Map<Base, Output>`
- `Async.Filter<Base>`
- `Async.CompactMap<Base, Output>`
- `Async.FlatMap<Base, Segment>`

These types preserve caller isolation under `NonisolatedNonsendingByDefault` — closures run on the actor that created the pipeline, not on the cooperative pool. They use `next(isolation: #isolation)` forwarding per SE-0421, store nonsending closures (not `@Sendable`), and have conditional `@unchecked Sendable` conformance. All 79 tests pass.

The types are correct. The problem is **how users reach them**.

### The Overload Resolution Problem

Extension methods on `AsyncSequence` (`.map`, `.filter`, etc.) lose overload resolution to the stdlib. When a user writes `source.map { $0 * 2 }`, the compiler picks `AsyncMapSequence` (stdlib) instead of `Async.Map` (ours).

**Root cause**: The stdlib's methods are `@preconcurrency`, which suppresses `@Sendable` diagnostics at the call site. Both overloads become equally viable, and the stdlib wins — it's defined in `_Concurrency`, which defines `AsyncSequence` itself.

**Stdlib signatures** (from `MacOSX26.2.sdk/.../arm64e-apple-macos.swiftinterface`):

```swift
@preconcurrency @inlinable public __consuming func map<Transformed>(
    _ transform: @escaping @Sendable (Self.Element) async -> Transformed
) -> AsyncMapSequence<Self, Transformed>
```

**Our signatures**:

```swift
@inlinable public func map<Output>(
    _ transform: @escaping (Element) async -> Output
) -> Async.Map<Self, Output>
```

Key attributes on stdlib: `@preconcurrency`, `@inlinable`, `__consuming`. No `@_disfavoredOverload`. The `@preconcurrency` attribute makes the `@Sendable` vs non-`@Sendable` distinction invisible to the overload resolver, and the stdlib's defining-module priority wins the tiebreak.

### Constraint

Type-identity test assertions were removed to get a green build. They must be reinstated once the entry point API is determined:

- `Async.Map Tests.swift` — returns concrete `Async.Map` type
- `Async.Filter Tests.swift` — returns concrete `Async.Filter` type
- `Async.CompactMap Tests.swift` — returns concrete `Async.CompactMap` type
- `Async.FlatMap Tests.swift` — returns concrete `Async.FlatMap` type
- `Async.Sequence.Isolation Tests.swift` — concrete types distinct from stdlib types

## Question

What entry point API should users use to access the isolation-preserving `AsyncSequence` operators?

## Prior Art

### Internal: Namespace Accessor Pattern in swift-async

The `Async.Stream` type already uses namespace accessors extensively:

```swift
// Instance accessor: property on stream returns intermediate struct
stream.buffer.count(5)      // Async.Stream<Element>.Buffer → .count()
stream.buffer.time(.seconds(1))
stream.drop(3)              // Async.Stream<Element>.Drop → callAsFunction()
stream.drop.while { $0 < 0 }
stream.prefix(3)
stream.prefix.while { $0 > 0 }
```

Pattern structure:

```swift
extension Async.Stream {
    public struct Buffer: Sendable {
        let base: Async.Stream<Element>
    }
    public var buffer: Buffer { Buffer(base: self) }
}

extension Async.Stream.Buffer {
    public func count(_ count: Int) -> Async.Stream<[Element]> { ... }
    public func time(_ duration: Duration) -> Async.Stream<[Element]> { ... }
}
```

These accessors serve a different purpose (grouping related operations), but the structural pattern — a property returning an intermediate type with chaining methods — is directly applicable.

### External: apple/swift-async-algorithms

The async-algorithms package does NOT define custom `map`/`filter` overloads. It avoids name collisions entirely by using unique names (`debounce`, `throttle`, `compacted`, `chunked`). When it extends `AsyncSequence`, it uses direct methods with distinctive signatures — no accessor patterns.

This confirms: the community has not solved the `@preconcurrency` overload resolution problem. Libraries that need custom behavior use distinct names.

### Cross-Language: Kotlin, Rust, Combine

All frameworks use explicit opt-in for context changes:

| Framework | Default | Boundary Mechanism |
|-----------|---------|-------------------|
| Kotlin Flow | Collector's context preserved | `flowOn()` changes upstream context |
| Rust | `Send` required for `tokio::spawn` | `spawn_local` for `!Send` |
| Combine | Subscription thread | `receive(on:)` changes scheduler |

The pattern: **context preservation is default; context change is explicit**. Our situation is inverted — the stdlib breaks isolation by default, so we need an explicit opt-in to preservation.

## Analysis

### Option A: Namespace Accessor with Wrapper Type (Recommended)

A computed property `.isolated` on `AsyncSequence` returns `Async.Isolated<Self>`, a transparent wrapper that provides isolation-preserving operators as methods. Each operator returns `Async.Isolated<ConcreteType<...>>`, enabling natural chaining with one `.isolated` at the entry point.

```swift
// Enter isolation-preserving mode:
let pipeline = source.isolated
    .map { $0 * 2 }
    .filter { $0 > 4 }
    .compactMap { expensive($0) }

// Consume directly — isolation preserved:
for await value in pipeline { ... }

// Or type-erase when needed — explicit boundary:
let stream = Async.Stream(pipeline)
```

**Architecture**:

```swift
// Entry point on any AsyncSequence
extension AsyncSequence {
    public var isolated: Async.Isolated<Self> {
        Async.Isolated(base: self)
    }
}

// Transparent wrapper — forwards AsyncSequence conformance
extension Async {
    public struct Isolated<Base: AsyncSequence>: AsyncSequence {
        public typealias Element = Base.Element

        @usableFromInline
        let base: Base

        @usableFromInline
        init(base: Base) { self.base = base }

        @inlinable
        public func makeAsyncIterator() -> Base.AsyncIterator {
            base.makeAsyncIterator()
        }
    }
}

// Operators on Isolated — reach through base, wrap result
extension Async.Isolated {
    @inlinable
    public func map<Output>(
        _ transform: @escaping (Base.Element) async -> Output
    ) -> Async.Isolated<Async.Map<Base, Output>> {
        .init(base: .init(base: self.base, transform: transform))
    }

    @inlinable
    public func filter(
        _ isIncluded: @escaping (Base.Element) async -> Bool
    ) -> Async.Isolated<Async.Filter<Base>> {
        .init(base: .init(base: self.base, isIncluded: isIncluded))
    }

    // compactMap, flatMap analogous
}

// Conditional Sendable
extension Async.Isolated: @unchecked Sendable
    where Base: Sendable, Base.Element: Sendable {}
```

**Type nesting** is clean — only one `Isolated` at the outermost level:

```
source.isolated                     → Async.Isolated<Source>
  .map { }                          → Async.Isolated<Async.Map<Source, O>>
  .filter { }                       → Async.Isolated<Async.Filter<Async.Map<Source, O>>>
  .compactMap { }                   → Async.Isolated<Async.CompactMap<Async.Filter<...>, U>>
```

Each operator on `Async.Isolated` reaches through `self.base` to construct the concrete type, then wraps the result back in `Isolated`. The inner types are bare `Async.Map`, `Async.Filter`, etc.

**Isolation preservation**: The closure literal is created at the user's call site (e.g., `@MainActor` function), not inside the `map` method. The method just passes it through to `Async.Map`'s init. This is the same pattern as experiment Tests G/H/K, which confirmed isolation preservation.

**Advantages**:
- Matches the existing accessor pattern in the codebase (`.buffer.count`, `.drop.while`)
- Completely sidesteps overload resolution — no name collision with stdlib
- One `.isolated` at the start, then natural chaining
- Explicit opt-in — users consciously choose isolation preservation
- Follows [API-NAME-001] (`Async.Isolated` is `Nest.Name`)
- Follows [API-NAME-002] (no compound identifiers — `.isolated.map` is accessor + method)
- Zero runtime cost — `Isolated` is a transparent forwarding wrapper
- `some AsyncSequence<Element>` hides type complexity in API signatures

**Disadvantages**:
- Requires `.isolated` at the start of every pipeline
- Adds one type wrapper layer in the type system (visible in debugger)
- Each operator must be defined twice: once on `Async.Isolated`, once in the existing `AsyncSequence` extension (which remains for the case where overload resolution is later fixed)

### Option B: Protocol-Based Chaining

Define a refinement protocol `IsolatedAsyncSequence: AsyncSequence`. Place operators on `extension IsolatedAsyncSequence`. All concrete types (`Async.Map`, `Async.Filter`, etc.) conform. Swift's overload resolution prefers more-specific protocol extensions, so operators on `IsolatedAsyncSequence` should win over stdlib's operators on `AsyncSequence` for conforming types.

```swift
protocol IsolatedAsyncSequence: AsyncSequence {}

extension IsolatedAsyncSequence {
    func map<O>(_ t: @escaping (Element) async -> O) -> Async.Map<Self, O> { ... }
    func filter(_ p: @escaping (Element) async -> Bool) -> Async.Filter<Self> { ... }
}

extension Async.Map: IsolatedAsyncSequence {}
extension Async.Filter: IsolatedAsyncSequence {}
```

Entry point is still `.isolated` → `Async.Isolated<Self>: IsolatedAsyncSequence`. After that, chaining through protocol extensions returns bare concrete types (no re-wrapping).

```swift
source.isolated           → Async.Isolated<Source> (: IsolatedAsyncSequence)
  .map { }                → Async.Map<Async.Isolated<Source>, O> (: IsolatedAsyncSequence)
  .filter { }             → Async.Filter<Async.Map<...>> (: IsolatedAsyncSequence)
```

**Advantages over Option A**:
- No re-wrapping in `Async.Isolated` at each step — cleaner types
- Operators defined once on the protocol, not on the wrapper
- New concrete types automatically get chaining by conforming to the protocol

**Disadvantages vs Option A**:
- Requires verifying that protocol specificity reliably wins over stdlib (`@preconcurrency` could interfere)
- Nested protocols in enums: `Async` is `public enum Async {}` — Swift 5.10+ allows nesting protocols in non-generic types, but this needs verification with the Swift 6.2 toolchain
- More conceptual overhead (protocol + wrapper vs just wrapper)

**Assessment**: Potentially cleaner but introduces compiler behavior risk. Should be explored as an enhancement if the experiment confirms protocol specificity wins.

### Option C: Compound Method Names

Use distinct method names: `source.isolatedMap { }`, `source.isolatedFilter { }`.

```swift
extension AsyncSequence {
    func isolatedMap<O>(_ transform: ...) -> Async.Map<Self, O> { ... }
    func isolatedFilter(_ predicate: ...) -> Async.Filter<Self> { ... }
}
```

**Advantages**: Simple, no ambiguity.

**Disadvantages**: Violates [API-NAME-002] — compound identifiers forbidden. `isolatedMap` is `isolated` + `Map`. Does not chain naturally (`source.isolatedMap { }.isolatedFilter { }` is verbose). Grows linearly with operator count.

**Assessment**: Rejected per convention.

### Option D: Direct Construction

Users construct concrete types directly:

```swift
let mapped = Async.Map(base: source) { $0 * 2 }
let filtered = Async.Filter(base: mapped) { $0 > 4 }
```

**Advantages**: No ambiguity. Types already support this.

**Disadvantages**: No chaining ergonomics. Deeply nested for multi-step pipelines:

```swift
Async.Filter(base: Async.Map(base: source) { $0 * 2 }) { $0 > 4 }
```

**Assessment**: Available as an escape hatch but not viable as the primary API.

### Option E: Compiler Attributes (`@_disfavoredOverload`)

Force our overloads to win using `@_disfavoredOverload` on the stdlib or other underscored attributes.

**Assessment**: Not viable. We cannot modify the stdlib. `@_disfavoredOverload` on OUR overloads would make them always lose (opposite of desired). No official attribute exists to boost overload priority. Filing a Swift Evolution proposal is possible but has an unknown timeline.

### Option F: Additional Parameters to Disambiguate

Add a parameter (e.g., `isolation: isolated (any Actor)? = #isolation`) to our `map` to create a distinct overload signature.

```swift
extension AsyncSequence {
    func map<O>(
        isolation: isolated (any Actor)? = #isolation,
        _ transform: @escaping (Element) async -> O
    ) -> Async.Map<Self, O> { ... }
}
```

**Assessment**: Swift treats default-parameter overloads as LESS specific than no-parameter overloads. The stdlib overload (fewer parameters, all else equal) would win. This goes the wrong direction.

### Comparison

| Criterion | A: Accessor | B: Protocol | C: Compound | D: Direct | E: Attrs | F: Params |
|-----------|-------------|-------------|-------------|-----------|----------|-----------|
| Convention compliance | [API-NAME-001] ✓ [API-NAME-002] ✓ | ✓ | [API-NAME-002] ✗ | ✓ | N/A | ✓ |
| Chaining ergonomics | Good (one `.isolated`, then chain) | Good (natural chaining) | Poor (prefix every call) | Poor (nested construction) | N/A | Does not resolve |
| Overload resolution | Sidesteps entirely | Relies on specificity (needs verification) | Sidesteps (unique names) | Sidesteps (explicit) | Not viable | Makes worse |
| Existing pattern match | `.buffer.count`, `.drop.while` | Protocol extensions (stdlib pattern) | None in codebase | Init pattern | N/A | N/A |
| Type complexity | One `Isolated` wrapper | Clean (protocol inheritance) | Bare concrete types | Bare concrete types | N/A | N/A |
| Implementation cost | Low (~30 lines for wrapper + forwarding) | Medium (protocol + conformances + verification) | Low but rejected | Zero (already works) | N/A | N/A |

## Decision (v2.0): Sync-Closure Overloads + Direct `next(isolation:)`

Option A (accessor) was superseded after implementation revealed a simpler, frictionless approach.

### Mechanism

Two discoveries eliminated the need for wrappers or accessors:

**1. Sync-closure overloads win overload resolution.** The stdlib takes `@Sendable (Element) async -> Output`. Our overloads take `(Element) -> Output` (sync). A sync closure is a more specific match than an async one — no implicit sync→async conversion needed. The `@preconcurrency` attribute only erases `@Sendable` scoring, not sync/async conversion scoring. Verified by experiment (`sync-overload-resolution/`).

**2. Direct `next(isolation:)` implementation defeats the conformance trap.** The `NonisolatedNonsendingByDefault` conformance trap causes `next()` to hop to the cooperative pool when `AsyncIteratorProtocol` is from `_Concurrency` (compiled without the feature). The fix: implement `next(isolation actor: isolated (any Actor)? = #isolation)` directly on our iterators. The `isolated actor` parameter forces execution on the caller's actor, and we forward `actor` (not `#isolation`) to the base iterator.

> **Compiler validation (2026-03-22)**: `nonsending-compiler-patterns.md` confirmed this conformance trap is a known, tested behavior in the compiler test suite (`test/Concurrency/attr_execution/nonisolated_nonsending_by_default.swift:12-24`). The compiler generates witness thunks that mediate between `nonisolated(nonsending)` implementations and `@concurrent` protocol requirements (`test/Concurrency/attr_execution/protocols_silgen.swift:21-168`). Our `next(isolation:)` approach bypasses the trap by using the SE-0421 protocol requirement directly — which is the stdlib's own pattern for concrete iterator types like `AsyncMapSequence`.

### Architecture

Each concrete type stores a `Transform` (or `Predicate`) enum with `.sync` and `.async` cases:

```swift
extension Async {
    struct Map<Base: AsyncSequence, Output>: AsyncSequence {
        enum Transform {
            case sync((Base.Element) -> Output)
            case async((Base.Element) async -> Output)
        }

        let transform: Transform

        struct Iterator: AsyncIteratorProtocol {
            mutating func next(
                isolation actor: isolated (any Actor)? = #isolation
            ) async -> Output? {
                guard let element = try? await baseIterator.next(isolation: actor) else {
                    return nil
                }
                switch transform {
                case .sync(let f): return f(element)          // inline, no hop
                case .async(let f): return await f(element)   // nonsending, inherits actor
                }
            }
        }
    }
}
```

Two overloads on `AsyncSequence`:

```swift
extension AsyncSequence {
    // Sync — wins overload resolution over stdlib's async @Sendable variant
    func map<O>(_ transform: @escaping (Element) -> O) -> Async.Map<Self, O>

    // Async — available for explicit async closures
    func map<O>(_ transform: @escaping (Element) async -> O) -> Async.Map<Self, O>
}
```

### User Experience

Completely invisible — no wrappers, no accessors, no prefixes:

```swift
source.map { $0 * 2 }              // → Async.Map (our type, isolation preserved)
  .filter { $0 > 5 }               // → Async.Filter (our type, isolation preserved)
  .compactMap { transform($0) }    // → Async.CompactMap (our type, isolation preserved)

// Async closures at entry: falls through to stdlib (acceptable)
source.map { await fetch($0) }     // → AsyncMapSequence (stdlib)
```

### Overload Resolution Behavior

| Closure Type | First Step (on `AsyncSequence`) | Chaining (on our concrete types) |
|-------------|--------------------------------|----------------------------------|
| Sync `{ $0 * 2 }` | Our sync overload wins | Our sync overload wins |
| Async `{ await f($0) }` | Stdlib wins (async closures equally match; stdlib has module priority) | Stdlib wins (same `AsyncSequence` extension priority) |

For v1, sync closures (the 90%+ common case) transparently use our types. Async closures fall through to stdlib. A future enhancement using an internal `_IsolatedAsyncSequence` protocol could win async closures in chains via protocol specificity.

### Test Results

31 tests, 0 failures:
- Type identity: `source.map { $0 * 2 }` returns `Async.Map<Produce<Int>, Int>` (not `AsyncMapSequence`)
- Chained type identity: `source.filter { }.map { }.compactMap { }` returns `Async.CompactMap<Async.Map<Async.Filter<Produce<Int>>, Int>, Int>`
- Isolation: sync closures in map, filter, and chained pipelines all run on `@MainActor`
- Async closures: functional correctness preserved through `.async` enum path
- Late erasure: `Async.Stream(pipeline)` correctly consumes concrete pipeline

### Key Decisions

1. **Sync-closure overloads**: Added alongside existing async overloads. Sync wins for sync closures; async exists for explicit use.
2. **Transform enum**: `.sync` and `.async` cases avoid two concrete types per operator. Branch in `next()` is eliminated by specialization.
3. **Direct `next(isolation:)`**: All iterators implement `next(isolation actor: isolated (any Actor)? = #isolation)` instead of bare `next()`. Passes `actor` (not `#isolation`) to base, defeating the conformance trap.
4. **No wrappers**: No `Async.Isolated`, no `.isolated` accessor, no protocol. Just overloads.

## References

### Internal
- `stream-isolation-preserving-operators.md` — Architecture recommendation (concrete types)
- `stream-isolation-propagation.md` — 100% isolation breakage audit
- `nonsending-adoption-audit.md` — `@Sendable` → nonsending migration inventory
- `swift-institute/Experiments/stream-isolation-preservation/` — 13-test isolation experiment
- `swift-institute/Experiments/sync-overload-resolution/` — Overload resolution verification

### Swift Evolution
- [SE-0421](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0421-generalize-async-sequence.md) — `next(isolation:)` on `AsyncIteratorProtocol`
- [SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md) — `NonisolatedNonsendingByDefault`

### Swift Forums
- [The NonisolatedNonsendingByDefault conformance trap](https://forums.swift.org/t/the-nonisolatednonsendingbydefault-conformance-trap/84724)
