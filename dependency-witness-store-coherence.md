# Dependency/Witness Store Coherence

<!--
---
version: 2.1.0
last_updated: 2026-03-03
status: RECOMMENDATION
tier: 2
---
-->

## Context

During the ecosystem-wide `Dependency.Key` adoption audit (2026-03-03), five packages were migrated to use L1's `Dependency.Key` (`swift-dependency-primitives`): RFC 4122, RFC 9562, IEEE 754, RFC 6238, and the IO lanes. This migration exposed an architectural issue: **L1 and L3 maintain separate @TaskLocal stores for dependency resolution. Values written to one store are invisible to the other.**

A subsequent investigation (this document, v2.0.0) systematically analyzed the architecture, enumerated all conforming types, mapped the dependency chain, and evaluated five options for store coherence.

**Trigger**: [RES-001] Post-implementation observation during ecosystem audit.
**Scope**: Ecosystem-wide (L1 swift-dependency-primitives, L3 swift-witnesses, L3 swift-dependencies).

## Question

**How should L1's `Dependency.Scope` and L3's `Witness.Context` achieve store coherence — specifically, eliminating the dual scope push for test mode and enabling cross-store value visibility — while preserving the five-layer architecture, L3's `~Copyable` support, and the distinct API surfaces?**

## Constraints

Per [RES-004] step 5:

| ID | Constraint | Source |
|----|-----------|--------|
| C1 | L1 primitives MUST NOT import L3 foundations | [ARCH-LAYER-001] |
| C2 | L1's `Dependency.Key` must remain independently usable at L2 | Existing L2 conformances |
| C3 | L3's `Witness.Context` features (mode enum, cycle detection, preparation store) must be preserved | Witness.Context API |
| C4 | L3's `~Copyable` value support must be preserved | `Witness.Values` supports `~Copyable` via `Ownership.Shared` |
| C5 | The effect system (`Effect.Context`) must continue working unchanged | Effect.Context delegates to L1's `Dependency.Scope` |
| C6 | No breaking changes to existing conformances (18 production L1 keys, 8+ L3 keys) | Stability |

## Evaluation Criteria

| ID | Criterion | Weight |
|----|-----------|--------|
| E1 | Eliminates dual scope push for test mode | High |
| E2 | Cross-store value visibility (L1-written values visible in L3 and vice versa) | Medium |
| E3 | Name coherence (`Dependency.Key` unambiguous) | Low |
| E4 | Layer architecture compliance (C1) | Non-negotiable |
| E5 | API stability (C6) | High |
| E6 | Implementation complexity (files changed, risk) | Medium |
| E7 | Performance impact on miss path | Low |

## Analysis

### Current Architecture

Three operational contexts exist, backed by two @TaskLocal stores:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         @TaskLocal Store #1                        │
│                    Dependency.Scope._current                       │
│              [ObjectIdentifier: any Sendable]                      │
│                                                                    │
│  Readers:                                                          │
│    L2 standards:  Dependency.Scope.current[K.self]                 │
│    L1 effects:    Effect.Context.current[K.self]  (delegates)      │
│    L3 tests:      Dependency.Scope.with({ $0.isTestContext = ... })│
│                                                                    │
│  Mode: Boolean isTestContext                                       │
├─────────────────────────────────────────────────────────────────────┤
│                         @TaskLocal Store #2                        │
│                    Witness.Context._current                        │
│              [ObjectIdentifier: UnsafeRawPointer]                  │
│                                                                    │
│  Readers:                                                          │
│    L3 deps:       withDependencies { ... }  (delegates)            │
│    L3 witnesses:  Witness.Context.current[K.self]                  │
│    L3 testing:    Witness.Context.with(mode: .test) { ... }        │
│    L3 traits:     Test.Trait.Collection subscript                  │
│                                                                    │
│  Mode: enum Mode { case live, preview, test }                      │
│  Extra: Preparation.Store fallback, ~Copyable support              │
└─────────────────────────────────────────────────────────────────────┘
```

#### Dependency Chain

```
L1: Dependency_Primitives  (standalone)
         ↑
    Witness_Primitives      (re-exports Dependency_Primitives via public import)
         ↑
L3: swift-witnesses         (Witness.Context, Witness.Values, Witness.Key)
         ↑
    swift-dependencies      (Dependency.Key = Witness.Key, withDependencies)
```

**Critical fact**: `Witness_Primitives` already re-exports `Dependency_Primitives`. This means L3 code in `swift-witnesses` can reference L1's `Dependency.Key` protocol and `Dependency.Scope` without additional imports. The re-export happens at `swift-witness-primitives/Sources/Witness Primitives/Witness.Protocol.swift:13`.

#### Protocol Comparison

| Aspect | L1 `Dependency.Key` | L3 `Witness.Key` |
|--------|---------------------|-------------------|
| Defined in | `swift-dependency-primitives` | `swift-witnesses` |
| Requirements | `liveValue`, `testValue` | `liveValue` (inherits `testValue`, `previewValue` from `__WitnessKeyTest`) |
| Default chain | `testValue → liveValue` | `testValue → previewValue → liveValue` |
| Value constraint | `Value: Sendable` (implicitly `Copyable`, but `SuppressedAssociatedTypes` enabled — relaxation to `~Copyable` is a 1-line change) | `Value: ~Copyable & Sendable` |
| Mode selection | Boolean `isTestContext` | Enum `Mode` |
| Relationship | Independent | Independent (aliased as `Dependency.Key` in swift-dependencies) |

#### Conformance Census

**L1 `Dependency.Key` conformances** (18 production):

| Type | Package | Layer | Value |
|------|---------|-------|-------|
| `RFC_4122.Hash` | swift-rfc-4122 | L2 | Hashing implementation |
| `RFC_4122.Random` | swift-rfc-4122 | L2 | Random byte source |
| `RFC_6238.HMAC` | swift-rfc-6238 | L2 | HMAC implementation |
| `IEEE_754.Exceptions.ExceptionState` | swift-ieee-754 | L2 | FP exception flags |
| `Effect.Yield.Handler.Key` | swift-effects | L3 | Task yield handler |
| `Effect.Exit.Handler.Key` | swift-effects | L3 | Process exit handler |
| `IO.Lane` | swift-io | L3 | Event loop lane |
| `IO.Blocking.Lane` | swift-io | L3 | Blocking lane |
| `Test.Snapshot.CounterKey` | swift-tests | L3 | Snapshot counter |
| `Test.Snapshot.Configuration.Key` | swift-tests | L3 | Snapshot config |
| + 8 test-only fixtures | various | — | — |

**L3 `Witness.Key` conformances** (8+ production):

| Type | Package | Layer | Value |
|------|---------|-------|-------|
| `Test.Trait.TimeLimit` | swift-tests | L3 | Duration? |
| `Test.Trait.Tag` | swift-tests | L3 | Ordered string set |
| `Test.Trait.Bug` | swift-tests | L3 | Bug info |
| `Test.Trait.Enabled` | swift-tests | L3 | Enable/disable |
| `Test.Trait.Exclusive` | swift-tests | L3 | Mutex trait |
| `Test.Trait.Serialized` | swift-tests | L3 | Serial execution |
| `Test.Trait.Timed` | swift-tests | L3 | Benchmark config |
| `Test.Trait.Snapshot` | swift-tests | L3 | Snapshot trait |
| `ClockKey` | swift-dependencies | L3 | Clock.Any |

#### The Dual Scope Push

Full test mode requires two separate pushes at two different call sites:

```swift
// Testing.Main:134 — pushes L3 store
let result = await Witness.Context.with(mode: .test) {
    await runner.run(plan)
}

// Test.Runner:430-431 — pushes L1 store (inside each test body)
try await Dependency.Scope.with(
    { $0.isTestContext = true },
    operation: entry.body.run
)
```

These are at different nesting levels: `Testing.Main` wraps the entire run, `Test.Runner` wraps each individual test body. The L1 push is nested inside the L3 push.

### Prior Art Survey

Per [RES-021] for Tier 2:

**SwiftUI `@Environment`**: Single `EnvironmentValues` store, single `EnvironmentKey` protocol, single `@TaskLocal`-like mechanism (view tree propagation). SwiftUI does not have a layer separation problem because the entire framework is one module.

**pointfreeco/swift-dependencies**: Single store, single `DependencyKey` protocol, single `@TaskLocal`. Their `withDependencies` writes to one store. No layer split. Our ecosystem introduced the split because L1 primitives cannot import L3.

**Algebraic effects (OCaml 5, Koka)**: Effect handlers use a single handler stack. When you install a handler, all code in scope sees it. There is no concept of "two handler stacks" — the runtime maintains one. Our two-store architecture is anomalous by comparison.

**Reader monad / implicit parameters**: Haskell's `ReaderT` and Scala's implicit parameters use a single environment. The environment can be layered (via type composition), but lookup traverses all layers.

**Conclusion**: The prior art uniformly uses a single resolution path. Our two-store split is a consequence of the layer architecture, not a deliberate design choice. The recommended approach should restore single-path resolution while respecting layer boundaries.

### Options

#### Option A: Status Quo

Both stores remain independent. L2 uses L1's store, L3 uses L3's store. No changes.

**Pros**: Zero risk. No implementation work.
**Cons**: Dual scope push persists. Invisible boundary remains. Name shadowing confusion continues. Grows worse as more L2 packages adopt L1's `Dependency.Key`.

#### Option B: Mode Propagation Only

When `Witness.Context.with(mode:)` is called, it wraps the operation in `Dependency.Scope.with` to synchronize `isTestContext`:

```swift
// In Witness.Context (swift-witnesses):
public static func with<T, E: Error>(
    mode: Mode,
    _ modify: ((inout Witness.Values) -> Void)? = nil,
    operation: () throws(E) -> T
) throws(E) -> T {
    var context = _current
    context.mode = mode
    modify?(&context.values)
    return try $_current.withValue(context) {
        // NEW: Propagate mode to L1 store
        try Dependency.Scope.with(
            { $0.isTestContext = (mode == .test) },
            operation: operation
        )
    }
}
```

All 6 mode-accepting overloads (`with(mode:)`, `withTest`, `withPreview` — sync and async) get this propagation. The 2 mode-free overloads (`with(_:operation:)`) do not need it — they inherit the mode from the parent scope, and the parent's `Dependency.Scope.with` is already active via @TaskLocal inheritance.

**Downstream cleanup**: `Test.Runner.runWithTraits` (line 430) can remove its explicit `Dependency.Scope.with({ $0.isTestContext = true })` — the outer `Witness.Context.with(mode: .test)` from `Testing.Main` now activates L1's store automatically.

**Pros**: Eliminates dual scope push. Minimal change (6 method bodies). No API changes. No performance impact (one extra @TaskLocal push per mode change, O(1)). No storage format changes.
**Cons**: Does not solve cross-store value visibility. Does not solve name shadowing.

#### Option C: Mode Propagation + L1 Key Bridge

Extends Option B with read-through and write-through for L1 keys.

**Phase 1** (= Option B): Mode propagation. Eliminates dual scope push.

**Phase 2**: Add subscript overloads so L3 APIs can read/write L1 keys:

```swift
// In Witness.Values (swift-witnesses):
// Note: Dependency.Key here is L1's protocol, available via Witness_Primitives re-export.
public subscript<K: Dependency.Key>(key: K.Type) -> K.Value where K.Value: Copyable {
    get {
        let id = ObjectIdentifier(K.self)
        // 1. Check own storage (L3 overrides take priority)
        if let ptr = unsafe _storage.dict[id] {
            return unsafe Unmanaged<Ownership.Shared<K.Value>>.fromOpaque(ptr)
                .takeUnretainedValue()
                .value
        }
        // 2. Fall back to L1 store
        return Dependency.Scope.current[K.self]
    }
    set {
        // Store in own storage (consistent with Witness.Key behavior)
        _ensureUnique()
        let id = ObjectIdentifier(K.self)
        if let oldPtr = unsafe _storage.dict[id] {
            unsafe Unmanaged<AnyObject>.fromOpaque(oldPtr).release()
        }
        let box = Ownership.Shared(newValue)
        let ptr = unsafe UnsafeRawPointer(Unmanaged.passRetained(box).toOpaque())
        unsafe _storage.set(ptr, for: id)
    }
}
```

```swift
// In Witness.Context (swift-witnesses):
public static subscript<K: Dependency.Key>(key: K.Type) -> K.Value where K.Value: Copyable {
    _current.values[K.self]
}
```

**Write-through for `withDependencies`**: When `withDependencies` writes an L1 key, the override must also appear in `Dependency.Scope._current` so that L1/L2 code inside the operation can read it. Implementation:

```swift
// In withDependencies (swift-dependencies):
@inlinable
public func withDependencies<T, E: Error>(
    _ modify: (inout __DependencyValues) -> Void,
    operation: () throws(E) -> T
) throws(E) -> T {
    var l1Apply: ((inout Dependency.Values) -> Void)? = nil

    return try Witness.Context.with({ witnessValues in
        var depValues = __DependencyValues(_witnessValues: witnessValues)
        modify(&depValues)
        witnessValues = depValues._witnessValues
        l1Apply = depValues._l1Apply
    }, operation: {
        if let l1Apply {
            try Dependency.Scope.with(l1Apply, operation: operation)
        } else {
            try operation()
        }
    })
}
```

Where `__DependencyValues` gains a tracked collection of L1-key modifications:

```swift
// In __DependencyValues:
var _l1Apply: ((inout Dependency.Values) -> Void)? = nil

public subscript<K: __DependencyKey>(key: K.Type) -> K.Value where K.Value: Copyable {
    get { _witnessValues[K.self] }  // Uses Witness.Values L1-key subscript
    set {
        _witnessValues[K.self] = newValue  // Store in L3 for L3 readers
        let captured = _l1Apply
        _l1Apply = { values in
            captured?(&values)
            values[K.self] = newValue  // Store in L1 for L1/L2 readers
        }
    }
}
```

**Disambiguation**: In `swift-witnesses`, `Dependency.Key` unambiguously refers to L1's protocol (imported via `Witness_Primitives`). In `swift-dependencies`, L1's protocol is available as `__DependencyKey` (the workaround typealias). The L1-key subscript and the existing `Witness.Key` subscript are on different protocols, so the compiler resolves them unambiguously.

**Pros**: Full cross-store visibility. L1 values visible in L3 (read fallback). L3-written L1 values visible in L1 (write-through). Unified `withDependencies` API for all key types.
**Cons**: More complex implementation. Two subscript overloads on `Witness.Values`. Closure-chaining pattern for L1 write-through. Performance: one extra `Dependency.Scope.current` read on L1-key miss (O(1) @TaskLocal + dictionary lookup).

#### Option D: Protocol Refinement (`Witness.Key: Dependency.Key`)

Make `Witness.Key` refine L1's `Dependency.Key`.

**Prerequisite**: Relax L1's associated type constraint (1-line change, backwards compatible):

```swift
// In Dependency.Key (swift-dependency-primitives, L1):
public protocol Key: Sendable {
    associatedtype Value: ~Copyable & Sendable  // was: Value: Sendable
    static var liveValue: Value { get }
    static var testValue: Value { get }
}
```

This is a constraint relaxation, not a tightening. All existing conformances have `Copyable` values, which satisfy `~Copyable & Sendable`. The `SuppressedAssociatedTypes` feature flag is **already enabled** in `swift-dependency-primitives` (Package.swift:48).

L1's `Dependency.Values` subscript adds a `where` guard (backwards compatible — all existing call sites use Copyable values):

```swift
// In Dependency.Values (swift-dependency-primitives, L1):
public subscript<K: Dependency.Key>(key: K.Type) -> K.Value
    where K.Value: Copyable {
    get { ... }   // unchanged
    set { ... }   // unchanged
}
```

Then at L3:

```swift
// In swift-witnesses:
extension Witness {
    public protocol Key<Value>: Dependency.Key, __WitnessKeyTest {
        static var liveValue: Value { get }
    }
}
```

**Protocol diamond**: Both `Dependency.Key` and `__WitnessKeyTest` declare `associatedtype Value: ~Copyable & Sendable`. The `= Self` default comes from `__WitnessKeyTest`. Swift unifies identical associated types from multiple parent protocols. The constraints are identical after the L1 relaxation. **Verified by experiment** `protocol-diamond-noncopyable-refinement` (8 variants, ALL CONFIRMED — Swift 6.2.4).

**Default chain compatibility**:
- `Dependency.Key` default: `testValue { liveValue }`
- `Witness.Key where Value: Copyable` default: `testValue { previewValue }`, `previewValue { liveValue }`
- For types conforming to `Witness.Key`: the more specific `Witness.Key` default wins → `testValue → previewValue → liveValue`
- For types conforming only to `Dependency.Key`: `testValue → liveValue` (unchanged)
- For `~Copyable` `Witness.Key` conformers: `Dependency.Key`'s unconstrained default `testValue { liveValue }` applies (an improvement — previously no default existed for `~Copyable` testValue)

**What this enables**:
- Every `Witness.Key` conformer is automatically a `Dependency.Key` conformer
- L1's store can accept Witness.Key types (they satisfy `K: Dependency.Key`)
- The `Dependency.Key` typealias in swift-dependencies becomes semantically accurate: `Witness.Key` IS-A `Dependency.Key`
- Name shadowing resolves: `Dependency.Key` at L1 and `Witness.Key` at L3 form a proper hierarchy, not two unrelated protocols

**What this does NOT solve**:
- L1-only keys (RFC_4122.Hash, etc.) still don't conform to `Witness.Key` — they only have `Dependency.Key`
- L3's `Witness.Values` subscript requires `K: Witness.Key`, so L1-only keys still can't be resolved through L3's API without the bridge subscript (Option C Phase 2)

**Pros**: Eliminates name shadowing. Creates proper protocol hierarchy. Enables Witness.Key types in L1's store. Backwards compatible (constraint relaxation + `where` guard). Improves ~Copyable default chain.
**Cons**: L1 API change (non-breaking but touches protocol definition). Does not solve L1-only key resolution via L3 API (still needs bridge).

#### Option E: Unified Store at L1

Replace both stores with a single, more capable store at L1. `Dependency.Values` gains mode support, preparation store, `~Copyable` values, and pointer-backed storage. `Witness.Values` becomes a thin wrapper.

**Pros**: Single store. Complete coherence. No fallback logic.
**Cons**: Massively pushes complexity into L1. Mode enum, preparation store, `~Copyable` support, `Ownership.Shared` boxing — none of this belongs at L1. Violates the principle that primitives are minimal. Turns `swift-dependency-primitives` into a foundation-weight package. The largest change in this analysis by far.

### Comparison

| Criterion | A: Status Quo | B: Mode Prop | C: Mode + Bridge | D: Refinement | E: Unified L1 |
|-----------|:---:|:---:|:---:|:---:|:---:|
| E1: Dual scope push | No | **Yes** | **Yes** | **Yes** | **Yes** |
| E2: Cross-store visibility | No | No | **Yes** | Partial (L3→L1 only) | **Yes** |
| E3: Name coherence | No | No | No | **Yes** | **Yes** |
| E4: Layer compliance | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** |
| E5: API stability | **Yes** | **Yes** | **Yes** | **Yes** (relaxation, non-breaking) | No (L1 breaking) |
| E6: Complexity (files) | 0 | ~8 | ~15 | ~4 | ~30+ |
| E7: Performance | Baseline | +1 TaskLocal push | +1 dict lookup on miss | Baseline | Baseline |
| C4: ~Copyable preserved | **Yes** | **Yes** | **Yes** | **Yes** (SuppressedAssociatedTypes) | **Yes** |

### Performance Analysis

**Option B** adds one `@TaskLocal` push/pop per mode-changing scope. Swift's `@TaskLocal` uses a singly-linked list of overrides — push is O(1) (allocate node, prepend), pop is O(1) (restore previous head). This is comparable to a function call. In the test execution path, mode changes happen at the run level (once) and occasionally at the suite level. The overhead is negligible.

**Option C** adds one `Dependency.Scope.current` read (= @TaskLocal read + dictionary lookup) per L1-key miss in L3's store. @TaskLocal read is O(1). Dictionary lookup on an empty or small dictionary is O(1). For the common case (keys not explicitly overridden), this adds ~20ns per resolution. For keys that ARE overridden in L3's store (the hit path), there is zero overhead — the existing storage check short-circuits.

## Outcome

**Status**: RECOMMENDATION

### Recommended Approach: B + D + C (Three Phases)

With `SuppressedAssociatedTypes` already enabled in `swift-dependency-primitives`, Option D is unblocked. The revised recommendation combines mode propagation (B), protocol refinement (D), and the L1 key bridge (C) in three phases of increasing scope.

**Phase 1: Mode Propagation** — Implement immediately. Low risk, high value. Solves E1.

Changes:
1. `Witness.Context` — 6 mode-accepting method bodies gain `Dependency.Scope.with` wrapping (`Witness.Context.swift` lines 170-185, 229-245, 260-274, 285-299, 314-328, 339-353)
2. `Test.Runner` — Remove explicit `Dependency.Scope.with({ $0.isTestContext = true })` from `runWithTraits` (`Test.Runner.swift` line 430)
3. `Testing.Main` — No change needed (already pushes mode, which now propagates)

Files touched: 2 (Witness.Context.swift, Test.Runner.swift)
Solves: E1 (dual scope push)

**Phase 2: Protocol Refinement** — Implement after Phase 1 validation. Solves E3, improves E2.

Protocol diamond verified: experiment `protocol-diamond-noncopyable-refinement` (8 variants, ALL CONFIRMED — Swift 6.2.4). Default chain, `= Self` default, `~Copyable` values, `where K.Value: Copyable` subscript guard, and IS-A resolution all work correctly.

Changes:
1. `Dependency.Key` (L1) — Relax `associatedtype Value: Sendable` to `associatedtype Value: ~Copyable & Sendable` (`Dependency.Key.swift` line 55)
2. `Dependency.Values` (L1) — Add `where K.Value: Copyable` to subscript (`Dependency.Values.swift` line 55)
3. `Witness.Key` (L3) — Add `: Dependency.Key` to protocol declaration (`Witness.Key.swift` line 70)
4. `Dependency.Key` typealias (L3) — Verify the typealias `Dependency.Key = Witness.Key` remains correct (it does — `Witness.Key` IS-A `Dependency.Key` now)

Files touched: 3 (Dependency.Key.swift, Dependency.Values.swift, Witness.Key.swift)
Solves: E3 (name coherence — `Witness.Key` IS-A `Dependency.Key`, the typealias is no longer a shadow but a narrowing)
Improves: E2 (Witness.Key types can now be stored in L1's store via their Dependency.Key conformance)

**Phase 3: L1 Key Bridge** — Implement after Phase 2. Solves E2 fully.

Changes:
1. `Witness.Values` — Add L1-key subscript with read fallback to `Dependency.Scope.current` (`Witness.Values.swift`)
2. `Witness.Context` — Add L1-key subscript (`Witness.Context.swift`)
3. `__DependencyValues` — Add `__DependencyKey` subscript with write-through tracking (`Dependency.Values.swift` in swift-dependencies)
4. `withDependencies` — Apply L1 modifications via `Dependency.Scope.with` wrapping (all 4 overloads in `withDependencies.swift`)

Files touched: 4
Solves: E2 (full cross-store visibility — L1-only keys resolvable through L3's API, L3-written L1 keys visible to L1/L2 code)

### Cumulative Effect

| After Phase | E1 Dual Push | E2 Visibility | E3 Naming |
|-------------|:---:|:---:|:---:|
| Phase 1 | Solved | — | — |
| Phase 2 | Solved | Partial (L3→L1) | Solved |
| Phase 3 | Solved | Full | Solved |

### What This Changes at L1

Phase 1: Nothing at L1.
Phase 2: Two backwards-compatible changes:
- `Dependency.Key.Value` constraint relaxed from `Sendable` to `~Copyable & Sendable` (relaxation, all existing conformances still valid)
- `Dependency.Values` subscript gains `where K.Value: Copyable` (all existing call sites use Copyable values)

L1's `Dependency.Scope` API, storage format, and effect system integration are unchanged across all phases.

### What This Does NOT Change

- L1's `Dependency.Scope` store and API — unchanged
- L1's `Dependency.Values` storage format (`[ObjectIdentifier: any Sendable]`) — unchanged
- Effect system (`Effect.Context` → `Dependency.Scope`) — unchanged
- All existing conformances — unchanged (relaxation is backwards compatible)
- L3's `Witness.Values` storage format — unchanged (still pointer-backed CoW)

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-03-03 | Initial observation from ecosystem audit |
| 2.0.0 | 2026-03-03 | Full investigation: dependency chain analysis, conformance census, 5 options analyzed, phased recommendation |
| 2.1.0 | 2026-03-03 | Corrected Option D: `SuppressedAssociatedTypes` already enabled in L1, unblocking `~Copyable` relaxation. Option D is feasible and non-breaking. Revised recommendation to 3-phase approach (B + D + C). Protocol diamond verified by experiment (8/8 CONFIRMED). |

## References

### Research Documents
- `handler-witness-conceptual-identity.md` — Witnesses as degenerate handlers (DECISION: keep separate types, shared substrate)
- `protocol-witness-effects-capability-abstraction.md` — Witnesses for capability abstraction
- `dependencies-ecosystem-adoption-audit.md` — L1 Dependency.Key adoption audit
- `witnesses-ecosystem-adoption-audit.md` — L3 Witness.Key adoption audit

### Source Files
- `swift-dependency-primitives/Sources/Dependency Primitives/Dependency.Scope.swift` — L1 store (@TaskLocal, `Dependency.Values`)
- `swift-dependency-primitives/Sources/Dependency Primitives/Dependency.Values.swift` — L1 storage (`[ObjectIdentifier: any Sendable]`, `isTestContext`)
- `swift-dependency-primitives/Sources/Dependency Primitives/Dependency.Key.swift` — L1 key protocol
- `swift-witness-primitives/Sources/Witness Primitives/Witness.Protocol.swift:13` — `public import Dependency_Primitives` (re-export)
- `swift-witnesses/Sources/Witnesses/Witness.Context.swift` — L3 store (@TaskLocal, mode enum)
- `swift-witnesses/Sources/Witnesses/Witness.Values.swift` — L3 storage (UnsafeRawPointer, CoW, ~Copyable)
- `swift-witnesses/Sources/Witnesses/Witness.Key.swift` — L3 key protocol
- `swift-dependencies/Sources/Dependencies/Dependency.Key.swift:48` — `Dependency.Key = Witness.Key` (typealias)
- `swift-dependencies/Sources/Dependencies/withDependencies.swift` — L3 → Witness.Context delegation
- `swift-tests/Sources/Tests Performance/Test.Runner.swift:430` — L1 scope push (`isTestContext = true`)
- `swift-testing/Sources/Testing/Testing.Main.swift:134` — L3 scope push (`mode: .test`)
- `swift-effect-primitives/Sources/Effect Primitives/Effect.Context.swift` — Effect.Context delegates to `Dependency.Scope`

### Experiments
- `swift-institute/Experiments/protocol-diamond-noncopyable-refinement/` — **8/8 CONFIRMED** (Swift 6.2.4): protocol diamond with shared `~Copyable` associated type, `= Self` default, default chain resolution, IS-A subscript resolution

### Ecosystem Research
- `witness-noncopyable-nonescapable-support.md` — Confirms `SuppressedAssociatedTypes` already enabled; `~Copyable` witness values feasible
- `protocol-abstraction-for-phantom-typed-wrappers.md` — Phase 2 uses `SuppressedAssociatedTypes` for `~Copyable` associated types
- `swift-sequence-primitives/Experiments/suppressed-associated-types/` — Verified: `associatedtype Element: ~Copyable` compiles with SuppressedAssociatedTypes

### Prior Art
- SwiftUI `@Environment` / `EnvironmentKey` — single store, single protocol
- pointfreeco/swift-dependencies — single store, single `DependencyKey` protocol
- Wadler, P. & Blott, S. (1989). "How to make ad-hoc polymorphism less ad hoc." POPL 1989 — Dictionary-passing style
- Plotkin, G. & Pretnar, M. (2009). "Handlers of Algebraic Effects." ESOP 2009 — Single handler stack
