# Stream Isolation-Preserving Operators

<!--
---
version: 1.0.0
last_updated: 2026-02-25
status: RECOMMENDATION
tier: 2
trigger: Experiment stream-isolation-preservation confirmed concrete operator types preserve isolation
---
-->

## Context

Our `Async.Stream` at `/Users/coen/Developer/swift-foundations/swift-async/` provides 40+ composable operators. Every operator breaks caller isolation — 100% breakage rate (documented in `stream-isolation-propagation.md`). The root cause is the stored `@Sendable () async -> Element?` closure in `Iterator`.

The experiment `stream-isolation-preservation` (2026-02-25) discovered that **concrete operator types compiled with `NonisolatedNonsendingByDefault` preserve caller isolation** — including with `@unchecked Sendable` conformance, with sync closures, and even after late type erasure. This opens a path to isolation-preserving stream operators with no language changes required.

This research analyzes the design space, surveys prior art, and recommends an architecture.

## Question

What is the optimal architecture for isolation-preserving async sequence operators that can coexist with and compose into the existing `Async.Stream` type-erased system?

## Prior Art Survey

### Swift Evolution

The isolation preservation story for async sequences is built on a chain of proposals:

| Proposal | Contribution |
|----------|-------------|
| SE-0298 | Original `AsyncSequence` — no isolation awareness |
| SE-0338 | Forced nonisolated async to hop to generic executor — *created* the isolation break |
| SE-0414 | Region-based isolation, `sending` keyword |
| SE-0420 | `isolated` parameters, `#isolation` macro |
| SE-0421 | `next(isolation:)` — the direct fix for SE-0338's break in async iteration |
| SE-0431 | `@isolated(any)` function types — closures capturing isolation context |
| SE-0461 | `nonisolated(nonsending)` default, `@concurrent` — eliminates executor hops for nonisolated async |

**SE-0421** is the most directly relevant. It added `next(isolation actor: isolated (any Actor)?) async throws(Failure) -> Element?` to `AsyncIteratorProtocol`. The compiler's `for await` desugaring automatically passes `#isolation` via an internal `CurrentContextIsolationExpr` AST node (verified in `swiftlang/swift/lib/Sema/TypeCheckStmt.cpp:3590-3598`). The stdlib's concrete operator types (`AsyncMapSequence`, `AsyncFilterSequence`, etc.) all forward the `isolation` parameter through to their base iterators.

**SE-0461** changes the default for nonisolated async functions from "hop to generic executor" to "inherit caller isolation." Under `NonisolatedNonsendingByDefault`, concrete operator types' `next()` methods are nonsending — they inherit the caller's isolation and call stored transforms in that isolation context. This is what our experiment confirmed.

**Compiler behavior** (from Swift source analysis): The `for await` loop prefers `next(isolation:)` when the deployment target supports typed throws (Swift 6.0+). The iterator variable itself is marked `nonisolated(unsafe)` as a workaround — the comment in `TypeCheckStmt.cpp:3515-3524` notes this is temporary and that `next()` should inherit caller isolation.

**Active issues**: Bug #83812 reports that `nonisolated(nonsending)` closures called from `nonisolated(nonsending)` functions may not always inherit the caller actor. This could affect closure-based type-erased operators but does NOT affect concrete types (where the transform is stored as a property and called directly from `next()`).

**MPSCAsyncChannel PR (#384)**: Apple's swift-async-algorithms is migrating from `isolated (any Actor)?` parameters to `nonisolated(nonsending)`, citing "more aggressive optimizer optimizations." This suggests the ecosystem is moving toward SE-0461's nonsending default as the preferred isolation mechanism over SE-0421's explicit parameter.

**Share operator discussion**: The AsyncAlgorithms forum thread (posts 49-51) identifies the fundamental tension: multi-consumer operators like `share` need to run in a specific isolation domain, but creating types "polymorphic over isolation" is not currently possible in Swift. Franz Busch notes this remains the central open problem.

### Kotlin Flow: Context Preservation Invariant

Kotlin enforces a strict **context preservation invariant**: code inside a `flow { }` builder must emit in the same coroutine context as its collector. Violations throw `IllegalStateException` at runtime. The escape hatch is `flowOn()`, which creates a channel boundary between upstream (new context) and downstream (collector context).

Design rationale from Roman Elizarov: UI applications need widgets touched only from the main thread; server-side programs carry diagnostic context. The invariant is strict precisely because relaxing it leads to subtle, hard-to-debug threading bugs.

**Mapping to Swift**: Kotlin's context preservation invariant maps to SE-0421's `#isolation` forwarding. Kotlin enforces at runtime; Swift enforces at compile time (Sendable + isolation checking). Kotlin's `flowOn()` maps to the boundary between concrete operators (isolation-preserving) and `Async.Stream` (type-erased, isolation-breaking).

### Rust: Send/!Send Split

Rust's `Stream` trait has no inherent `Send` bound, but executors impose it: `tokio::spawn` requires `Send` (work-stealing executor migrates tasks); `tokio::task::spawn_local` allows `!Send` (pinned to a single OS thread via `LocalSet`).

Key insight from matklad: work-stealing executors force defensive thread-safety on all async code, even when not needed. Thread-per-core executors (`glommio`, `monoio`) allow `!Send` futures by guaranteeing stable thread identity.

**Mapping to Swift**: Swift's actor isolation is analogous to `!Send` — an actor-isolated value cannot cross boundaries. The split between `Async.Stream` (Sendable, concurrent) and concrete operators (isolation-preserving) mirrors Rust's `spawn` vs `spawn_local` split.

### ReactiveX / Combine: Scheduler Operators

All reactive frameworks use explicit scheduler operators:
- `observeOn()` / `receive(on:)` — sets downstream scheduler
- `subscribeOn()` / `subscribe(on:)` — sets upstream scheduler

Context changes are manual and opt-in. No enforcement — programmer discipline required.

**Mapping to Swift**: SE-0421 eliminates the need for explicit scheduler operators — isolation is preserved by default through `#isolation` forwarding. The `Async.Stream` type erasure boundary is the implicit equivalent of an `observeOn()` insertion.

### Synthesis

| Framework | Default Behavior | Boundary Mechanism | Enforcement |
|-----------|-----------------|-------------------|-------------|
| **Kotlin Flow** | Emit in collector's context | `flowOn()` | Runtime exception |
| **Rust** | `Send` required for work-stealing | `spawn` vs `spawn_local` | Compile-time |
| **ReactiveX/Combine** | Runs on subscription thread | `observeOn()`/`receive(on:)` | None |
| **Swift (SE-0421)** | Stays in caller's isolation | Type erasure to `Async.Stream` | Compile-time |
| **Our proposal** | Concrete types preserve; erasure is boundary | `.eraseToStream()` | Compile-time |

All mature frameworks recognize the same fundamental pattern: **context preservation is the default; context changes are explicit boundaries**. Our concrete operator approach aligns perfectly with this consensus.

## Experiment Results

Full results in `swift-institute/Experiments/stream-isolation-preservation/`.

### Key Findings

| Test | Approach | Isolation | Why |
|------|----------|-----------|-----|
| A | stdlib `AsyncMapSequence` | **BROKEN** | Compiled without `NonisolatedNonsendingByDefault` |
| B2 | Non-Sendable, bare `() async ->` | **PRESERVED** | Nonsending closure created in @MainActor context |
| C | `@Sendable () async ->` | **BROKEN** | @Sendable severs isolation |
| G | **Our concrete Map/Filter** | **PRESERVED** | Nonsending `next()` calls stored nonsending transform |
| H | **Our concrete + @unchecked Sendable** | **PRESERVED** | @unchecked Sendable doesn't affect closure execution |
| I | Type-erased, sync `map()` | **BROKEN** | Closure literal in sync nonisolated function has no isolation |
| J | Type-erased, async `map()` | **PRESERVED** | Nonsending async `map()` inherits caller isolation |
| K | Concrete with sync closures | **PRESERVED** | Transform called from nonsending `next()` |
| L | Concrete → non-Sendable erasure | **PRESERVED** | Closures already bound to isolation at creation |
| M | Concrete → @Sendable erasure | **PRESERVED** | Same — isolation survives even Sendable erasure |

### Critical Discoveries

1. **Concrete types preserve isolation for BOTH sync and async closures** (G, H, K). The mechanism: `next()` is nonsending under the feature, inherits caller isolation, and calls the stored transform (also nonsending) within that isolation context.

2. **`@unchecked Sendable` does NOT break isolation** (H). Only `@Sendable` on the *closure type itself* breaks isolation. The struct's Sendable conformance is irrelevant to closure execution semantics.

3. **Late erasure preserves isolation** (L, M). Once closures are bound to an isolation context at concrete operator creation, they retain that context through any subsequent type erasure — even into `@Sendable` wrappers.

4. **Sync `map()` methods break isolation** (I). Closure literals inside sync nonisolated functions are "born" without isolation context. This rules out type-erased operators with sync builder methods.

5. **Async `map()` methods preserve isolation** (J). Making operator methods async (nonsending) fixes the closure creation problem. But this has an ergonomic cost: `await stream.map { }`.

## Analysis

### Option A: Concrete Operator Types (Recommended)

Build concrete `AsyncSequence`-conforming operator types as extensions on `AsyncSequence`, mirroring stdlib's pattern but compiled with `NonisolatedNonsendingByDefault`.

```swift
// Usage — isolation preserved through entire chain:
let pipeline = source
    .isolatedMap { process($0) }       // ConcreteMap<Source, String>
    .isolatedFilter { $0.isValid }     // ConcreteFilter<ConcreteMap<...>>

// Erase when needed (explicit boundary):
let stream = Async.Stream(pipeline)    // isolation still preserved (Test M)
let merged = Async.Stream.merge(stream, other)  // concurrent — isolation breaks here
```

**Advantages**:
- Preserves isolation for sync AND async closures
- Works with `@unchecked Sendable` — concrete types can cross boundaries
- Late erasure preserves isolation — no forced trade-off
- No language changes required
- Aligns with stdlib pattern and SE-0421 design intent
- `some AsyncSequence<Element>` handles type explosion via opaque return types
- Matches Kotlin's context preservation invariant (isolation preserved by default)

**Disadvantages**:
- Type explosion for deeply nested chains (mitigated by `some AsyncSequence`)
- Duplicate operator set (concrete + type-erased)
- Naming question: how to distinguish from type-erased operators

**Feasibility**: Fully achievable today. No blockers.

### Option B: Type-Erased Stream with Async Operators

Make `IsolatedStream` type-erased but with async operator methods (`await stream.map { }`).

**Advantages**: Single type, no type explosion.

**Disadvantages**: Ergonomic cost (`await` required for every operator). Experiment shows sync operator methods break isolation (Test I). Limited to the async closure subset.

**Feasibility**: Achievable but poor ergonomics.

### Option C: Modify Existing Async.Stream

Change `Iterator._next` from `@Sendable () async -> Element?` to `() async -> Element?`.

**Advantages**: Single type, no duplication.

**Disadvantages**: Stream can no longer be `Sendable`. Breaks all multi-stream operators (merge, zip, combineLatest, share). Breaks the fundamental design contract.

**Feasibility**: Destructive. Not viable.

### Option D: Wait for Language Features

Wait for `~Escapable` closures or `@isolated(any)` improvements to enable isolation-preserving type erasure.

**Advantages**: Potentially cleaner long-term solution.

**Disadvantages**: Unknown timeline. May never materialize. SE-0431 (`@isolated(any)`) has known limitations. No proposal for `~Escapable` closures exists.

**Feasibility**: Speculative. Cannot plan against it.

### Comparison

| Criterion | A: Concrete | B: Async Ops | C: Modify Stream | D: Wait |
|-----------|-------------|-------------|-------------------|---------|
| Isolation (sync closures) | Preserved | Broken | Preserved | Unknown |
| Isolation (async closures) | Preserved | Preserved | Preserved | Unknown |
| Sendable support | @unchecked | No | No | Unknown |
| Composability with Async.Stream | Full | Full | Breaks multi-stream | N/A |
| Ergonomics | Good | Poor (await) | Good | Unknown |
| Available today | Yes | Yes | Destructive | No |
| Prior art alignment | Kotlin, stdlib | — | — | — |

## Recommendation

### Architecture

**Option A: Concrete operator types** on `AsyncSequence`, compiled with `NonisolatedNonsendingByDefault`.

```
Concrete operators (isolation-preserving)
    ↓ compose freely
    ↓ return concrete types: ConcreteMap<ConcreteFilter<Source>>
    ↓ opaque: some AsyncSequence<Element>
    ↓
    ├─→ for await (consume directly — full isolation)
    │
    └─→ Async.Stream(pipeline)  ← explicit erasure boundary
         ↓
         Async.Stream operators (type-erased, concurrent)
         merge, combineLatest, share, debounce, etc.
```

### Naming

The concrete operators should use the SAME names as stdlib (`map`, `filter`, `compactMap`, etc.) because they are extensions on `AsyncSequence` — the concrete return types distinguish them from `Async.Stream`'s type-erased operators. No `isolated` prefix needed.

```swift
// These return concrete types (our operators):
source.map { $0.name }           // → ConcreteMap<Source, String>
source.filter { $0.isValid }     // → ConcreteFilter<Source>

// These return Async.Stream (existing operators):
stream.map { $0.name }           // → Async.Stream<String>
stream.filter { $0.isValid }     // → Async.Stream<Bool>
```

The distinction is natural: `AsyncSequence` extensions return concrete types; `Async.Stream` methods return `Async.Stream`.

### Operator Set

Linear operators that can be implemented as concrete types:

| Category | Operators |
|----------|-----------|
| Transforms | `map`, `compactMap`, `flatMap` (sequential) |
| Filters | `filter` |
| Stateful | `scan`, `reduce` |
| Subsequence | `prefix(count)`, `prefix(while:)`, `drop(count)`, `drop(while:)`, `first()`, `first(where:)`, `last()`, `last(where:)` |
| Deduplication | `distinctUntilChanged`, `distinctUntilChanged(by:)` |
| Sequential composition | `concat` |
| Generators | `unfold`, `generate` |

Operators that MUST remain type-erased (inherently concurrent):

| Category | Operators |
|----------|-----------|
| Multi-stream | `merge`, `zip`, `combineLatest`, `withLatestFrom`, `sample` |
| Temporal | `debounce`, `throttle`, `delay`, `timeout`, `buffer.time` |
| Sharing | `share`, `multicast`, `replay` |
| Concurrent flatMap | `flatMap` (concurrent), `flatMapLatest` |

### Implementation Path

1. Create concrete operator types in swift-async (or new module)
2. Implement as extensions on `AsyncSequence` with `where Element: Sendable`
3. Use `@unchecked Sendable` conformance (confirmed safe by experiment)
4. Forward `isolation` via `next(isolation: #isolation)` per SE-0421
5. Existing `Async.Stream` operators remain unchanged
6. Add `Async.Stream.init<S: AsyncSequence>(_ sequence: S)` for erasure

### Stateful Operators

Stateful operators (scan, prefix, drop, etc.) currently use actors. For isolation preservation, state should be stored directly in the concrete iterator struct (which is consumed by a single `for await` — single-consumer guarantee). No actor needed. No executor hop.

```swift
struct ConcreteScan<Base: AsyncSequence, Result: Sendable>: AsyncSequence
    where Base.Element: Sendable
{
    struct Iterator: AsyncIteratorProtocol {
        var base: Base.AsyncIterator
        var state: Result
        let accumulator: (Result, Base.Element) -> Result

        mutating func next() async -> Result? {
            guard let element = try? await base.next(isolation: #isolation) else {
                return nil
            }
            state = accumulator(state, element)
            return state
        }
    }
}
```

State lives in the iterator struct. No actor. No hop. Single-consumer invariant enforced by `mutating func next()`.

## Outcome

**Status**: RECOMMENDATION

**Finding**: Concrete operator types compiled with `NonisolatedNonsendingByDefault` preserve caller isolation for both sync and async closures, with `@unchecked Sendable` support, and survive late type erasure. This is the "best of all worlds" architecture.

**Recommended architecture**: Concrete `AsyncSequence` operator types for ~20 linear operators. Existing `Async.Stream` type-erased operators for ~20 concurrent operators. Explicit erasure boundary via `Async.Stream(pipeline)`.

**Next steps**:
1. Design concrete operator type naming and module placement
2. Implement linear operator set
3. Verify isolation preservation with integration tests
4. Document the two-tier architecture (concrete = isolation-preserving, erased = concurrent)

## References

### Swift Evolution
- [SE-0298](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0298-asyncsequence.md): Async/Await: Sequences
- [SE-0338](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md): Clarify Execution of Non-Actor-Isolated Async Functions
- [SE-0421](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0421-generalize-async-sequence.md): Generalize AsyncSequence and AsyncIteratorProtocol
- [SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md): Run Nonisolated Async Functions on Caller's Actor

### Swift Forums
- [Pitch: Generalize AsyncSequence](https://forums.swift.org/t/pitch-generalize-asyncsequence-and-asynciteratorprotocol/69283)
- [SE-0461 Review](https://forums.swift.org/t/se-0461-run-nonisolated-async-functions-on-the-callers-actor-by-default/77987)
- [AsyncAlgorithms Share operator](https://forums.swift.org/t/kickoff-of-a-new-season-of-development-for-asyncalgorithms-share/81447/49)
- [NonisolatedNonsendingByDefault conformance trap](https://forums.swift.org/t/the-nonisolatednonsendingbydefault-conformance-trap/84724)
- [Parameter isolation vs nonisolated(nonsending)](https://forums.swift.org/t/parameter-isolation-vs-nonisolated-nonsending-different-suspension-behavior-with-task-executor-preference/84824)
- [MPSCAsyncChannel nonsending PR](https://github.com/apple/swift-async-algorithms/pull/384)

### Swift Compiler Source
- `swiftlang/swift/lib/Sema/TypeCheckStmt.cpp:3407-3440` — `for await` overload selection
- `swiftlang/swift/lib/Sema/TypeCheckStmt.cpp:3515-3524` — iterator `nonisolated(unsafe)` workaround
- `swiftlang/swift/lib/Sema/TypeCheckStmt.cpp:3590-3598` — `CurrentContextIsolationExpr` creation
- `swiftlang/swift/stdlib/public/Concurrency/AsyncMapSequence.swift` — concrete operator reference
- `swiftlang/swift/stdlib/public/Concurrency/AsyncFilterSequence.swift` — concrete operator reference

### Experiment
- `swift-institute/Experiments/stream-isolation-preservation/` — 13 test variants

### Prior Art
- [Execution context of Kotlin Flows](https://elizarov.medium.com/execution-context-of-kotlin-flows-b8c151c9309b) (Roman Elizarov)
- [Non-Send Futures When?](https://matklad.github.io/2023/12/10/nsfw.html) (matklad)
- [Structured Asynchrony with Algebraic Effects](https://www.microsoft.com/en-us/research/publication/structured-asynchrony-algebraic-effects/) (Leijen, 2017)
- [Asynchronous Effects](https://dl.acm.org/doi/10.1145/3434305) (Ahman & Pretnar, POPL 2021)
