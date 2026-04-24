# Resource Management — Post-Refactor Assessment

<!--
---
version: 2.0.0
last_updated: 2026-02-12
status: RECOMMENDATION
predecessor: v1.0.0 (Stack Migration Assessment)
applies_to: [swift-pool-primitives, swift-slab-primitives, swift-cache-primitives]
normative: false
---
-->

## Context

Buffer-primitives, storage-primitives, and memory-primitives were refactored and now compile and pass tests. This assessment audits the three resource management data structure packages — Pool, Slab, and Cache — for correctness, convention compliance, and integration with the refactored stack. The v1.0.0 assessment was written pre-refactor; this v2.0.0 reflects the current state of all source files as of 2026-02-12.

## Summary

The resource management tier has undergone substantial maturation since v1.0.0. **Slab** has been completely rewritten atop `Buffer<Element>.Slab.Bounded` and `Buffer<Element>.Slab.Inline`, eliminating all raw pointer management and the process-global sentinel. It now features three variants (dynamic `Slab`, static `Slab.Static<wordCount>`, and phantom-typed `Slab.Indexed<Tag>`) across four modules. **Pool** remains architecturally mature, composing `Array_Primitives.Array.Bounded` and `Ownership.Slot` for resource storage with a sophisticated two-phase lock/effect pattern. **Cache** is the simplest, delegating storage to stdlib `Dictionary` and focusing on compute-once concurrency coordination. Convention compliance is generally strong: no Foundation imports, no raw unsafe pointers, proper `Nest.Name` patterns. The primary issues are (1) pervasive untyped `throws` in Cache, (2) multiple types per file in both Slab's `Slab.swift` and Cache's `Cache.swift`, (3) a phantom `Buffer_Primitives` re-export in Pool's `exports.swift` that does not match its Package.swift dependencies, (4) raw `Int` usage in Pool's internal counters and state init, and (5) `__`-prefixed module-level types in Cache that work around Swift generic limitations but violate naming conventions.

---

## Pool Primitives (swift-pool-primitives)

### Current State

One module: **Pool Primitives** (28 source files + `exports.swift`).

Public types:
- `Pool` — root namespace enum
- `Pool.Bounded<Resource: ~Copyable & Sendable>` — fixed-capacity resource pool (`final class: @unchecked Sendable`)
- `Pool.Bounded.Fill` — eager fill operations
- `Pool.Bounded.Shutdown` — graceful shutdown operations
- `Pool.Bounded.Acquire` — acquire accessor namespace
- `Pool.Bounded.TimeoutAcquire` — timeout-aware acquire
- `Pool.Bounded.TryAcquire` — non-blocking acquire
- `Pool.Bounded.CallbackAcquire` — callback-based acquire (embedded-compatible)
- `Pool.ID` — unique resource checkout identifier
- `Pool.Scope` — unique pool instance identifier
- `Pool.Capacity` — validated capacity value
- `Pool.Error` — operational errors
- `Pool.Lifecycle` — lifecycle namespace
- `Pool.Lifecycle.State` — typealias to `Async.Lifecycle.State`
- `Pool.Lifecycle.Error` — lifecycle errors (shutdown, cancelled, timeout, exhausted, creationFailed)
- `Pool.Lifecycle.Precedence` — error precedence resolution
- `Pool.Metrics` — runtime statistics
- `Pool.Acquire<Resource>` — effect type for acquisition
- `Pool.Release<Resource>` — effect type for release

Internal types:
- `Pool.Bounded.State` — synchronized state (`~Copyable`)
- `Pool.Bounded.Slot` — slot bookkeeping
- `Pool.Bounded.Slot.State` — slot state machine (empty/creating/available/out/disposing)
- `Pool.Bounded.Entry` — typealias to `Ownership.Slot<Resource>`
- `Pool.Bounded.Checkout` — ownership token (`~Copyable`)
- `Pool.Bounded.Waiter` — waiter namespace
- `Pool.Bounded.Waiter.Metadata` — waiter metadata
- `Pool.Bounded.Waiter.Entry` — typealias to `Async.Waiter.Entry`
- `Pool.Bounded.Waiter.Flagged` — typealias for reaping
- `Pool.Bounded.Flag` — typealias to `Async.Waiter.Flag`
- `Pool.Bounded.Effect` — lock/unlock effect enum
- `Pool.Bounded.Policy` — eager/lazy policy
- `Pool.Bounded.Creation` — lazy creation closures
- `Pool.Bounded.Creator` — typealias to `Ownership.Shared<Creation>`
- `Pool.Bounded.Destructor` — typealias to `Ownership.Shared<...>`

### Dependencies

**Package.swift** (line 21-28):
- `swift-async-primitives`
- `swift-stack-primitives`
- `swift-array-primitives`
- `swift-dimension-primitives`
- `swift-ownership-primitives`
- `swift-effect-primitives`
- `swift-index-primitives`
- `swift-collection-primitives`

**exports.swift** re-exports:
- `Async_Primitives`, `Buffer_Primitives`, `Array_Primitives`, `Dimension_Primitives`, `Ownership_Primitives`, `Effect_Primitives`, `Index_Primitives`, `Collection_Primitives`

Note: `Buffer_Primitives` is re-exported but is NOT a direct dependency in Package.swift. It flows transitively through `swift-array-primitives` or `swift-stack-primitives`. Similarly, `Stack_Primitives` is a Package.swift dependency but is NOT re-exported in exports.swift.

### Storage Mechanism

Pool uses a layered composition of primitives from the refactored stack:

1. **Resource storage**: `entries: Array_Primitives.Array<Entry>.Bounded` — fixed-capacity array of `Entry` instances, backed by `Buffer.Linear.Bounded` which uses `Storage.Heap`. Fully on the new stack.
2. **Individual resource slots**: `Entry = Ownership.Slot<Resource>` — heap-allocated atomic single-value slot for `~Copyable & Sendable` resources. Uses `UnsafeMutablePointer` internally (atomic move-in/move-out pattern), correctly encapsulated within `Ownership.Slot`.
3. **Available index tracking**: `available: Stack<Slot.Index>.Bounded` — fixed-capacity LIFO stack from `swift-stack-primitives`.
4. **Waiter queue**: `waiters: Async.Waiter.Queue.Unbounded<Outcome, Metadata>` — from `swift-async-primitives`.
5. **Slot bookkeeping**: `slots: [Slot]` — stdlib `Array` of small `Copyable` structs (one `Index` + one `State` enum).
6. **Synchronization**: `_state: Async.Mutex<State>`, `shutdownGate: Async.Gate` — from `swift-async-primitives`.
7. **Closure wrappers**: `Creator = Ownership.Shared<Creation>`, `Destructor = Ownership.Shared<...>` — from `swift-ownership-primitives`.

### Findings

| # | Severity | File:Line | Finding | Convention |
|---|----------|-----------|---------|------------|
| 1 | MEDIUM | `exports.swift:5` | Re-exports `Buffer_Primitives` which is not a direct dependency in `Package.swift`. Flows transitively through `swift-array-primitives`. This works but is fragile — if `swift-array-primitives` changes its re-export policy, this breaks. Should either add `swift-buffer-primitives` as an explicit dependency or remove the re-export. | Dependency hygiene |
| 2 | MEDIUM | `Pool.Bounded.State.swift:31` | `var slots: [Slot]` uses stdlib `Array<Slot>`. Pragmatically fine for small Copyable bookkeeping data, but inconsistent with the rest of the storage model which uses `Array_Primitives.Array.Bounded`. | Consistency |
| 3 | MEDIUM | `Pool.Bounded.State.swift:35` | `var next: UInt64` — raw counter for ID generation. Could be `Index<Pool.ID>.Ordinal` or similar typed wrapper. | Raw Int / [CONV-*] |
| 4 | MEDIUM | `Pool.Bounded.State.swift:49-57` | `var outstanding: Int`, `var creating: Int`, `var disposing: Int` — raw `Int` counters. These are internal bookkeeping, but the convention calls for typed wrappers like `Count` for quantities. | Raw Int / [CONV-*] |
| 5 | MEDIUM | `Pool.Bounded.State.swift:61` | `init(capacity: Int) throws` — untyped `throws`. The only throwing path is `Stack.Bounded.init(capacity:)`. Should be `throws(SomeError)` per [API-ERR-001]. | [API-ERR-001] |
| 6 | LOW | `Pool.Bounded.State.swift:240` | `try! available.push(index)` — force-try. The invariant comment explains why overflow is impossible (capacity == slot count, each index pushed at most once). Acceptable as a documented invariant, but `try!` is a runtime trap if the invariant is ever violated. | Safety |
| 7 | MEDIUM | `Pool.Metrics.swift:23-32` | `var checkedOut: Int`, `var available: Int`, `var waiters: Int`, `var peakCheckedOut: Int` — raw `Int` for public metrics. These are exposed to consumers and could benefit from typed wrappers. | Raw Int / [CONV-*] |
| 8 | LOW | `Pool.Capacity.swift:6` | `public let value: Int` — the internal representation of capacity is raw `Int`. Acceptable because `Pool.Capacity` itself IS the typed wrapper, and `value` is `@_spi(Internal)`. | Acceptable |
| 9 | LOW | `Pool.Bounded.Fill.swift:203` | `func batch(...) throws(Error) -> Int` — returns raw `Int` for count of filled resources. Could be a typed `Count`. | Raw Int / [CONV-*] |
| 10 | LOW | `Pool.Bounded.swift:77,104` | `State(capacity: capacity.value)` calls a `throws` initializer but is NOT wrapped in `try`. This compiles because `Async.Mutex.init` accepts an `@autoclosure () throws -> Value` and is itself `rethrows`, making the call site non-throwing when the mutex init is not marked throwing. However, the `State.init` IS marked `throws`, creating a silent error-swallowing path. If `Stack.Bounded.init(capacity:)` threw, the error would be silently converted to a trap inside the mutex init. | Error path correctness |
| 11 | LOW | `Pool.Bounded.State.swift:65` | `self.slots = (0..<capacity).map { Slot(index: Slot.Index($0)) }` — uses stdlib `Array.init` via `map` on a `Range`. This is the idiomatic way to create the bookkeeping array but means the slot array is always a heap-allocated stdlib `Array` even when capacity is small. | Consistency |
| 12 | LOW | `Pool.Bounded.Creation.swift:13` | `let create: @Sendable () async throws -> Resource` — untyped `throws` on the creation closure. This is a user-provided closure so the error type is genuinely unknown. Acceptable — the pool wraps it as `.creationFailed` in `Pool.Lifecycle.Error`. | Acceptable (user closure) |

### ~Copyable Status

Excellent. `Resource: ~Copyable & Sendable` is propagated throughout the entire type hierarchy. Key observations:

- `Pool.Bounded<Resource: ~Copyable & Sendable>` — correct constraint at class level.
- All extensions use `where Resource: ~Copyable & Sendable` — no constraint poisoning.
- `Pool.Bounded.State: ~Copyable` — correctly ~Copyable because it contains `Async.Waiter.Queue.Unbounded` which is ~Copyable.
- `Pool.Bounded.Checkout: ~Copyable` — pure ownership token.
- `Entry = Ownership.Slot<Resource>` — handles ~Copyable resource storage via heap indirection.
- `consuming` on destructors, `move.in/move.out` on entries — correct ownership protocol.
- No constraint propagation issues detected.

---

## Slab Primitives (swift-slab-primitives)

### Current State

Four modules:
- **Slab Primitives Core** (4 source files + `exports.swift`) — core types and ~Copyable operations
- **Slab Dynamic Primitives** (2 source files + `exports.swift`) — Copyable operations for `Slab` and `Slab.Indexed`
- **Slab Static Primitives** (1 source file + `exports.swift`) — Copyable operations for `Slab.Static`
- **Slab Primitives** (`exports.swift` only) — umbrella module re-exporting all three

Public types (all in Slab Primitives Core):
- `Slab<Element: ~Copyable>: ~Copyable` — heap-backed dynamic slab with bitmap occupancy
- `Slab.Static<let wordCount: Int>: ~Copyable` — inline (stack-allocated) slab
- `Slab.Indexed<Tag: ~Copyable>: ~Copyable` — phantom-typed wrapper providing `Index<Tag>` instead of `Index<Element>`
- `Slab.Error` — typed error enum (full, vacant, occupied)

### Dependencies

**Package.swift** (line 33-41):
- `swift-standard-library-extensions`
- `swift-index-primitives`
- `swift-finite-primitives`
- `swift-bit-primitives`
- `swift-ownership-primitives`
- `swift-property-primitives`
- `swift-collection-primitives`
- `swift-sequence-primitives`
- `swift-buffer-primitives`

**Slab Primitives Core exports.swift** re-exports:
- `Index_Primitives`, `Finite_Primitives`, `Property_Primitives`, `Buffer_Slab_Primitives`

### Storage Mechanism

Post-refactor, Slab is fully built on the buffer-primitives stack:

1. **`Slab<Element>`** stores `_buffer: Buffer<Element>.Slab.Bounded` — a heap-backed, bitmap-tracked, fixed-capacity slab buffer from `swift-buffer-primitives`. This replaces the pre-refactor raw `UnsafeMutablePointer` allocation entirely.

2. **`Slab.Static<wordCount>`** stores `_buffer: Buffer<Element>.Slab.Inline<wordCount>` — an inline (stack-allocated) slab buffer with compile-time capacity.

3. **`Slab.Indexed<Tag>`** stores `_base: Slab<Element>` — zero-cost phantom-typed wrapper that delegates to the underlying `Slab` with `Index` retagging.

All raw pointer management, the `_emptySlabSentinel` global, and the platform-specific `posix_memalign`/`Darwin`/`Glibc` imports from v1.0.0 have been eliminated. The migration to the buffer stack is complete.

### Findings

| # | Severity | File:Line | Finding | Convention |
|---|----------|-----------|---------|------------|
| 1 | HIGH | `Slab.swift:26-94` | File contains FOUR type declarations: `Slab<Element>`, `Slab.Static<wordCount>`, `Slab.Indexed<Tag>`, and `Slab.Error`. Comment on line 46 says "PATTERN-022: must remain in same file" — this is a documented exception. However, [API-IMPL-005] requires one type per file. The tension is that `Slab.Static` and `Slab.Indexed` are nested types declared inside `Slab`'s body, and Swift requires nested type declarations in the same struct body. `Slab.Error` is also nested. This is a language constraint, not a convention violation — nested types MUST be declared in the enclosing type's body. **Not actionable unless types are extracted to be non-nested.** | [API-IMPL-005] (language constraint) |
| 2 | LOW | `Slab.swift:100-103` | `Slab`, `Slab.Static`, and `Slab.Indexed` all declare `@unchecked Sendable` conformance. This is correct because the underlying `Buffer.Slab` types manage their own memory safely, but the `@unchecked` annotation means the compiler does not verify Sendability. | Sendability |
| 3 | LOW | `Slab ~Copyable.swift:154-162` | The `drain` property uses `unsafe` keyword for `Property.View` construction. This is the standard pattern for property views with `~Copyable` types. | Acceptable |
| 4 | LOW | `Slab.Static Copyable.swift:44`, `Slab.Indexed Copyable.swift:41` | `Sequence.Drain.Protocol` conformance is declared on types (`Slab.Static`, `Slab.Indexed`) outside their defining module (`Slab Primitives Core`). These are in `Slab Static Primitives` and `Slab Dynamic Primitives` respectively. This is a deliberate split to avoid `~Copyable` constraint poisoning from `Sequence.Drain.Protocol`'s `associatedtype Element` (which implies `Copyable`). Correctly architected. | Acceptable (documented) |
| 5 | LOW | `Slab Primitives Core/Slab.swift:28` | `_buffer` is `package var` not `@usableFromInline internal var`. Package-level access is used so the Dynamic and Static modules can access the buffer. This is correct for the multi-module architecture. | Acceptable |

### ~Copyable Status

Excellent. The entire Slab hierarchy supports `~Copyable` elements:

- `Slab<Element: ~Copyable>: ~Copyable` — core type.
- `Slab.Static<let wordCount: Int>: ~Copyable` — inline variant.
- `Slab.Indexed<Tag: ~Copyable>: ~Copyable` — phantom-typed variant; `Tag` can also be `~Copyable`.
- All extensions in `Slab ~Copyable.swift`, `Slab.Static ~Copyable.swift`, and `Slab.Indexed ~Copyable.swift` constrain `Element: ~Copyable` (and `Tag: ~Copyable` where applicable).
- `consuming` parameter on `insert` operations — correct ownership transfer.
- Drain conformances correctly split into separate modules where `Element: Copyable` is required.
- No constraint propagation issues detected.

---

## Cache Primitives (swift-cache-primitives)

### Current State

One module: **Cache Primitives** (5 source files + `exports.swift`).

Public types:
- `Cache<Key: Hashable & Sendable, Value: Sendable>: Sendable` — compute-once cache with in-flight coordination
- `Cache.Error` — error enum (computeFailed, cancelled)
- `Cache.Evict` — typealias to `__CacheEvict<Key, Value>` — eviction effect
- `Cache.Compute<E>` — typealias to `__CacheCompute<Key, Value, E>` — computation effect
- `__CacheEvict<Key, V>` — module-level effect struct (hoisted due to Swift generic limitations)
- `__CacheEvict.Reason` — eviction reason enum
- `__CacheCompute<Key, Value, E>` — module-level effect struct (hoisted due to Swift generic limitations)

Internal types:
- `Cache.Storage` — reference wrapper (`Ownership.Mutable<Async.Mutex<State>>.Unchecked`)
- `Cache.State` — synchronized state containing `[Key: Entry]`
- `Cache.Action` — action enum for two-phase lock pattern
- `Cache.Entry` — reference-type entry (`final class: @unchecked Sendable`)
- `Cache.Entry.State` — state machine enum (empty/computing/ready/failed)
- `Cache.Entry.Waiters` — reference-type waiter queue wrapper (`final class: @unchecked Sendable`)

### Dependencies

**Package.swift** (line 21-28):
- `swift-async-primitives`
- `swift-ownership-primitives`
- `swift-effect-primitives`
- `swift-dictionary-primitives`
- `swift-index-primitives`
- `swift-time-primitives`
- `swift-collection-primitives`

**exports.swift** re-exports:
- `Async_Primitives`, `Reference_Primitives`, `Effect_Primitives`, `Dictionary_Primitives`, `Index_Primitives`, `Time_Primitives`, `Collection_Primitives`

Note: `exports.swift` re-exports `Reference_Primitives` but the Package.swift lists `swift-ownership-primitives` as the dependency, not `swift-reference-primitives`. `Reference_Primitives` presumably flows transitively through `swift-ownership-primitives`. Similarly, `Ownership_Primitives` is imported in source files but not re-exported.

### Storage Mechanism

Cache has no direct memory management. Storage is entirely mediated through higher-level abstractions:

1. **Cache state**: `Async.Mutex<State>` wrapped in `Ownership.Mutable<...>.Unchecked` for reference semantics.
2. **Entry storage**: `state.entries: [Key: Entry]` — stdlib `Dictionary<Key, Entry>`.
3. **Entry**: `final class` with a `State` enum. No manual memory management.
4. **Waiters**: `Async.Waiter.Queue.Unbounded<Outcome, Void>` wrapped in `final class Waiters` to make `State` enum Copyable.

No dependency on memory-primitives, storage-primitives, or buffer-primitives. This is correct — Cache's concerns are concurrency coordination, not memory management.

### Findings

| # | Severity | File:Line | Finding | Convention |
|---|----------|-----------|---------|------------|
| 1 | HIGH | `Cache.swift:84` | `func withLock<T>(_ body: (inout sending State) throws -> sending T) rethrows -> sending T` — untyped `throws`/`rethrows`. The body parameter and return use existential error. Should be `throws(E)` for typed throws per [API-ERR-001]. However, this mirrors the `Async.Mutex.withLock` signature, so fixing it requires the upstream primitive to use typed throws first. | [API-ERR-001] |
| 2 | HIGH | `Cache.swift:152-153` | `public func value(for:compute:) async throws -> Value` — untyped `throws`. This is the primary public API. The function can throw `Cache.Error.computeFailed` or `Cache.Error.cancelled`, but the signature erases the error type to `any Error`. Should be `throws(Cache.Error)`. | [API-ERR-001] |
| 3 | HIGH | `Cache.swift:209` | `func waitForValue(entry:) async throws -> Value` — untyped `throws`. Should be `throws(Cache.Error)`. | [API-ERR-001] |
| 4 | HIGH | `Cache.swift:278-279` | `func computeAndPublish(key:entry:compute:) async throws -> Value` — untyped `throws`. Should be `throws(Cache.Error)`. | [API-ERR-001] |
| 5 | HIGH | `Cache.swift:506-507` | `public func value(for:if:compute:) async throws -> Value?` — untyped `throws`. Should be `throws(Cache.Error)`. | [API-ERR-001] |
| 6 | HIGH | `Cache.swift:152` | `compute: @Sendable () async throws -> Value` — the user-provided compute closure uses untyped `throws`. The error is captured as `any Swift.Error` in `Result<Value, any Swift.Error>` on line 281 and stored as `any Error` in `Cache.Entry.State.failed`. This existential error storage infects the entire error handling chain. | [API-ERR-001] |
| 7 | HIGH | `Cache.swift:54-104` | `Cache.swift` contains the primary `Cache` struct plus three nested type declarations in extensions: `Storage` (line 74), `State` (line 95), and `Action` (line 111). While these are defined in `extension Cache { }` blocks (not nested struct bodies), the file contains four type declarations. `Storage`, `State`, and `Action` should each be in their own file (`Cache.Storage.swift`, `Cache.State.swift`, `Cache.Action.swift`). | [API-IMPL-005] |
| 8 | MEDIUM | `Cache.Entry.swift:20-33,69-84,95-106` | `Cache.Entry.swift` contains three type declarations: `Entry` (class), `State` (enum inside extension `Cache.Entry`), and `Waiters` (class inside extension `Cache.Entry`). `State` and `Waiters` are nested types defined via extensions, not inside the class body. Could be split to `Cache.Entry.State.swift` and `Cache.Entry.Waiters.swift`. | [API-IMPL-005] |
| 9 | MEDIUM | `Cache.Entry.swift:83` | `case failed(any Error)` — existential error in the entry state machine. This is where the error type erasure originates. The `any Error` stored here propagates to `Waiters.Outcome = Result<Value, any Error>` (line 97) and eventually to the public API. | [API-ERR-001] |
| 10 | MEDIUM | `Cache.Error.swift:23` | `case computeFailed(any Swift.Error)` — the `Cache.Error` enum itself stores `any Swift.Error` in its `computeFailed` case. This means even the typed error contains an existential. The entire error chain is existential from compute closure through storage through public API. | [API-ERR-001] |
| 11 | MEDIUM | `Cache.Evict.swift:37` | `public struct __CacheEvict<Key, V>` — the `__` prefix and module-level hoisting violate [API-NAME-001] naming conventions. The type should be `Cache.Evict` (nested), but Swift cannot define a generic nested type inside a generic type with different generic parameters. The comment on line 19 documents this as a Swift language limitation. The `V` generic parameter name (instead of `Value`) on line 37 is also inconsistent with the rest of the codebase. | [API-NAME-001] (language constraint) |
| 12 | MEDIUM | `Cache.Compute.swift:66` | `public struct __CacheCompute<Key, Value, E>` — same `__` prefix and module-level hoisting issue as `__CacheEvict`. Documented Swift limitation. | [API-NAME-001] (language constraint) |
| 13 | MEDIUM | `Cache.Evict.swift:37` | `__CacheEvict` uses `V` as generic parameter name instead of `Value`. The typealias on line 94 maps it: `Evict = __CacheEvict<Key, Value>`. The `V` is presumably to avoid shadowing the outer `Cache<Key, Value>.Value`, but creates an inconsistency. | Naming consistency |
| 14 | LOW | `Cache.swift:113` | `case throwError(any Swift.Error)` — the internal `Action` enum's `throwError` case uses existential. Consequence of finding #6. | [API-ERR-001] |
| 15 | LOW | `Cache.swift:281` | `let result: Result<Value, any Swift.Error>` — existential in local variable. Consequence of finding #6. | [API-ERR-001] |
| 16 | LOW | `Cache.swift:368` | `public var count: Int` — raw `Int` for count. Could be `Index<Key>.Count` or similar. | Raw Int / [CONV-*] |
| 17 | LOW | `exports.swift:5` | Re-exports `Reference_Primitives` which is not a direct dependency in Package.swift. Flows transitively through `swift-ownership-primitives`. Same fragility concern as Pool finding #1. | Dependency hygiene |
| 18 | LOW | `Cache.swift:213-214` | `withCheckedThrowingContinuation` — uses stdlib throwing continuation. This is correct for the untyped-throws design but would need to change if the error chain is typed. | Acceptable (given current design) |

### ~Copyable Status

Cache does NOT support `~Copyable` values. `Value: Sendable` (which implies `Copyable`) is required. This is appropriate because:

- Cache values are shared across multiple waiters via `Result<Value, any Error>`.
- `Cache.Entry.State.ready(Value)` stores the value by copy.
- Waiters receive the value by copy from the resumption.

There are no constraint propagation issues because `~Copyable` is not used anywhere in the Cache type hierarchy.

The `Async.Waiter.Queue.Unbounded` inside `Entry.Waiters` is `~Copyable`, which is why `Waiters` is a `final class` — to make the `State` enum `Copyable` for pattern matching. This is a correct and documented workaround.

---

## Cross-Cutting Concerns

### Storage Stack Integration

| Package | Pre-Refactor Storage | Post-Refactor Storage | Migration Complete? |
|---------|---------------------|----------------------|-------------------|
| **Pool** | `Array_Primitives.Array.Bounded` + `Ownership.Slot` | Same (was already on stack) | Yes (was already done) |
| **Slab** | Raw `UnsafeMutablePointer` + `_emptySlabSentinel` | `Buffer<Element>.Slab.Bounded` + `Buffer<Element>.Slab.Inline` | **Yes — fully migrated** |
| **Cache** | stdlib `Dictionary` + `Ownership.Mutable.Unchecked` | Same (no migration needed) | N/A |

### Unsafe Pointer Usage

None. All three packages have zero occurrences of `UnsafeMutableBufferPointer`, `UnsafeBufferPointer`, `UnsafeMutablePointer`, `UnsafePointer`, `UnsafeRawPointer`, `UnsafeMutableRawPointer`, or `ManagedBuffer` in their source directories. The only raw pointer management is encapsulated within `Ownership.Slot` (used by Pool) and `Buffer.Slab` (used by Slab), both of which are in lower-tier packages.

### Foundation Imports

None. All three packages have zero `import Foundation` statements.

### Error Handling Compliance

| Package | Typed Throws? | Notes |
|---------|--------------|-------|
| **Pool** | **Mostly yes** | All public APIs use `throws(Pool.Lifecycle.Error)`, `throws(Pool.Error)`, or `throws(Fill.Error)`. Internal `State.init(capacity:)` has untyped `throws`. User-provided closures (create, compute) naturally have untyped throws. |
| **Slab** | **Yes** | All throwing operations use `throws(Slab<Element>.Error)`. Clean. |
| **Cache** | **No** | All public throwing APIs use untyped `throws`. Entire error chain is existential (`any Error` / `any Swift.Error`). This is the most significant convention violation in the tier. |

### One Type Per File Compliance

| Package | Compliant? | Notes |
|---------|-----------|-------|
| **Pool** | **Yes** | 28 source files, each containing one primary type declaration. Extensions in separate files are fine. |
| **Slab** | **Partially** | `Slab.swift` contains `Slab`, `Slab.Static`, `Slab.Indexed`, and `Slab.Error` — all nested types that must be in the enclosing struct body (language constraint). All other files are compliant. |
| **Cache** | **No** | `Cache.swift` has `Cache` + `Storage` + `State` + `Action` in extension blocks. `Cache.Entry.swift` has `Entry` + `State` + `Waiters` in extension blocks. Only `Storage`, `State`, `Action` are extractable — the nested class types could be split. |

### Naming Convention Compliance

| Package | Compliant? | Notes |
|---------|-----------|-------|
| **Pool** | **Yes** | All types follow `Nest.Name` pattern. `Pool.Bounded`, `Pool.Lifecycle.Error`, `Pool.Bounded.Slot.State`, etc. No compound identifiers. Accessor pattern (`pool.acquire.timeout(...)`, `pool.fill(...)`, `pool.shutdown.wait()`) follows [API-NAME-002]. |
| **Slab** | **Yes** | `Slab`, `Slab.Static`, `Slab.Indexed`, `Slab.Error` follow pattern. |
| **Cache** | **Mostly** | `Cache`, `Cache.Entry`, `Cache.Error` follow pattern. `__CacheEvict` and `__CacheCompute` violate [API-NAME-001] but are documented Swift language workarounds for generic nesting limitations. |

### Raw `Int` Usage

| Package | Instances | Severity |
|---------|-----------|----------|
| **Pool** | `Pool.Capacity.value: Int` (SPI), `Pool.Metrics.*: Int` (4 fields), `State.outstanding/creating/disposing: Int`, `State.next: UInt64`, `Fill.batch -> Int` | MEDIUM — internal counters are acceptable, but public `Metrics` fields expose raw `Int` |
| **Slab** | None — uses `Index<Element>`, `Index<Element>.Count`, `Index<Tag>`, `Index<Element>.Bounded<wordCount>` throughout | Clean |
| **Cache** | `Cache.count: Int` | LOW |

---

## Recommendations

### Priority 1: Cache Typed Throws (HIGH)

The entire Cache error chain needs typed throws. This is the most significant convention violation.

**Scope**: Requires either:
- (a) Making `Cache` generic over error type: `Cache<Key, Value, E: Error>` — heavy API change.
- (b) Keeping `Cache.Error` but threading `throws(Cache.Error)` through all APIs. The `computeFailed(any Swift.Error)` case would remain existential (user errors are heterogeneous), but the cache's own error type would be typed.
- (c) Accepting the current design as a documented exception because the compute closure's error type is genuinely unknown at the cache level.

**Recommendation**: Option (b) — type the cache's own throw signatures as `throws(Cache.Error)` while keeping the inner `computeFailed(any Swift.Error)` existential. This gives consumers typed catch sites while acknowledging that user computation errors are heterogeneous.

### Priority 2: Cache File Organization (MEDIUM)

Extract `Cache.Storage`, `Cache.State`, and `Cache.Action` from `Cache.swift` into separate files. Extract `Cache.Entry.State` and `Cache.Entry.Waiters` from `Cache.Entry.swift` into separate files.

### Priority 3: Dependency Hygiene (MEDIUM)

- Pool: Either add `swift-buffer-primitives` as an explicit Package.swift dependency, or remove the `@_exported import Buffer_Primitives` from `exports.swift`.
- Cache: Either add `swift-reference-primitives` as an explicit dependency, or remove the `@_exported import Reference_Primitives` from `exports.swift`.

### Priority 4: Pool State.init Error Path (LOW)

`Pool.Bounded.State.init(capacity: Int) throws` uses untyped `throws` and is called without `try` in `Pool.Bounded.init`. The error path is currently dead (capacity is validated by `Pool.Capacity`), but the annotation creates a silent error-swallowing path. Options:
- Remove `throws` from `State.init` and use `precondition` instead (since capacity is pre-validated).
- Or type it as `throws(Stack.Bounded.Error)` (whatever the stack throws) and add `try` to callers.

### Priority 5: Pool Metrics Typed Counts (LOW)

Consider replacing `Pool.Metrics`' raw `Int` fields with typed wrappers. This is a public API surface. Low priority because metrics are read-only observation data, not indices or offsets.

### No Action Required

- **Slab**: Fully migrated, clean. The multi-type-per-file in `Slab.swift` is a language constraint for nested types. The multi-module architecture for `~Copyable` constraint avoidance is correct.
- **Pool storage architecture**: Already on the refactored stack. No migration needed.
- **`__CacheEvict` / `__CacheCompute` naming**: Swift language limitation. Document and accept.
