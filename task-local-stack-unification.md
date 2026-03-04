# Task-Local Stack Unification

<!--
---
version: 3.0.0
last_updated: 2026-03-04
status: IMPLEMENTED
tier: 2
---
-->

## Context

During Phase 3 implementation of the L1 Key Bridge (from `dependency-witness-store-coherence.md` v2.1), the `_l1Apply` closure-chain mechanism for write-through felt architecturally wrong — a runtime mechanism bridging what should be a structural relationship. The closure chain accumulates `@Sendable` closures per L1-key write, replays them in a conditional `Dependency.Scope.with` wrapper, and introduces an opaque field (`_l1Apply`) on `__DependencyValues`. This prompted investigation of whether the two @TaskLocal stacks could be structurally unified.

**Trigger**: [RES-011] Implementation blocked by architectural dissatisfaction.
**Scope**: Ecosystem-wide (L1 `swift-dependency-primitives`, L3 `swift-witnesses`, L3 `swift-dependencies`).
**Parent research**: `dependency-witness-store-coherence.md` (v2.1, RECOMMENDATION).

## Question

Can the two @TaskLocal stacks — L1's `Dependency.Scope._current` and L3's `Witness.Context._current` — be unified into a single @TaskLocal variable, and what is the value of doing so?

## Constraints

| ID | Constraint | Source |
|----|-----------|--------|
| C1 | L1 MUST NOT import L3 | [ARCH-LAYER-001] |
| C2 | L1's `Dependency.Key` must remain independently usable at L1/L2 | Existing conformances |
| C3 | L3's features (mode enum, preparation store, ~Copyable, cycle detection) must be preserved | Witness.Context API |
| C4 | Effect.Context (L1) delegates to `Dependency.Scope` — must continue working | Effect.Context.swift |
| C5 | No breaking changes to existing public APIs | Stability |

## Evaluation Criteria

| ID | Criterion | Weight |
|----|-----------|--------|
| E1 | Eliminates bridging mechanisms (`_l1Apply`) | High |
| E2 | Single mental model (one dependency system, not two) | High |
| E3 | Layer architecture compliance (C1) | Non-negotiable |
| E4 | Performance (reads, scope pushes) | Medium |
| E5 | Implementation complexity (files changed, risk) | Medium |
| E6 | API stability (C5) | High |

## Analysis

### Why Two Stacks Exist

The split is a consequence of the layer architecture, not a deliberate design. L1 defined `Dependency.Scope` with its own `@TaskLocal` because it had no access to L3. L3 defined `Witness.Context` with its own `@TaskLocal` because it needed features L1 doesn't have (mode enum, preparation store, ~Copyable values). The result: two independent scoping mechanisms that happen to manage the same conceptual thing — task-scoped dependency overrides.

**Current architecture:**

```
@TaskLocal #1: Dependency.Scope._current
├── values: [ObjectIdentifier: any Sendable]     (40 bytes/entry)
├── isTestContext: Bool
└── Readers: L1/L2 code, Effect.Context

@TaskLocal #2: Witness.Context._current
├── values._storage: [ObjectIdentifier: UnsafeRawPointer]  (8 bytes/entry, CoW)
├── values._preparedRef: Preparation.Store?
├── mode: Mode (.live | .preview | .test)
└── Readers: L3 code, withDependencies
```

Phase 1 already breached the stack boundary: `Witness.Context.with(mode:)` pushes onto **both** @TaskLocals (L3 for values/mode, L1 for `isTestContext`). Phase 3's `_l1Apply` would further bridge them. These are symptoms of a split that shouldn't exist.

### The Structural Problem with Bridging

The `_l1Apply` mechanism has several deficiencies:

1. **Opaque**: A closure chain is uninspectable — you can't query what keys were set, merge two chains, or test equality.
2. **Allocates per write**: Each L1-key set creates a new closure capturing the previous chain. For n writes, the chain is O(n) closures.
3. **Leaks into API**: `__DependencyValues._l1Apply` is a public field of type `(@Sendable (inout Dependency_Primitives.Dependency.Values) -> Void)?`. This is implementation leakage.
4. **Conditional nesting**: Every `withDependencies` overload gains `if let l1Apply { wrap } else { direct }` branching. Four overloads × conditional = structural noise.
5. **Double Result-wrapping**: With L1 writes, the operation is wrapped in both `Witness.Context.with` and `Dependency.Scope.with`, each doing their own Result-wrapping for typed throws. Two layers of wrapping for what should be one scope push.

These are symptoms. The disease is: **two @TaskLocal stacks representing one logical scope**.

### Options

#### Option A: Two Stacks + Closure Bridge (Phase 3 as planned)

Keep both @TaskLocals. Bridge L1 writes via `_l1Apply` closure chain on `__DependencyValues`. `withDependencies` conditionally wraps in `Dependency.Scope.with`.

This is the approach from `dependency-witness-store-coherence.md` v2.1 Phase 3 (Option C).

**Implementation**: Already partially coded (4 files modified). Needs `Dependency.Scope` name disambiguation fix in `withDependencies.swift`.

#### Option B: Two Stacks + Value Bridge

Replace the closure chain with a `Dependency.Values` struct:

```swift
// On __DependencyValues:
public var _l1Overrides: Dependency_Primitives.Dependency.Values? = nil

// L1-key subscript setter:
set {
    _witnessValues[K.self] = newValue
    if _l1Overrides == nil { _l1Overrides = .init() }
    _l1Overrides![K.self] = newValue
}

// In withDependencies:
if let overrides = depValues._l1Overrides {
    try Dependency.Scope.with({ $0.merge(overrides) }, operation: operation)
}
```

Same conditional wrapping pattern as Option A, but data instead of closures.

**Pros over A**: Inspectable, no per-write allocation, composable, mergeable.
**Cons**: Still two stacks. Still conditional nesting. Still leaks bridging field into API. Requires `merge` method on `Dependency.Values`.

#### Option C: L1 Opaque Slot — Single @TaskLocal

**Core idea**: Add an opaque attachment point to L1's `Dependency.Values`. L3 stores its entire `Witness.Context` there. Delete L3's @TaskLocal. All scope pushes go through `Dependency.Scope.with`.

**L1 change** — one field added to `Dependency.Values`:

```swift
// Dependency.Values (L1):
public struct Values: Sendable {
    private var storage: [ObjectIdentifier: any Sendable] = [:]
    private var _isTestContext: Bool = false

    /// Opaque slot for higher-layer context.
    ///
    /// L3 stores its `Witness.Context` (values + mode + preparation store)
    /// here. L1 never reads or interprets this field — it just carries it
    /// through @TaskLocal scope inheritance.
    public var _layerContext: (any Sendable)? = nil
}
```

**L3 change** — delete `Witness.Context._current: @TaskLocal`, read/write through L1's scope:

```swift
// Witness.Context (L3):
extension Witness.Context {
    // REMOVED: @TaskLocal private static var _current

    /// Reads the current L3 context from L1's unified scope.
    @usableFromInline
    internal static var _current: Witness.Context {
        if let ctx = Dependency.Scope.current._layerContext as? Witness.Context {
            return ctx
        }
        return Witness.Context(values: .init(), mode: .live)
    }

    /// Pushes a modified L3 context through L1's unified scope.
    public static func with<T, E: Error>(
        _ modify: (inout Witness.Values) -> Void,
        operation: () throws(E) -> T
    ) throws(E) -> T {
        var context = _current
        modify(&context.values)
        return try Dependency.Scope.with({ l1Values in
            l1Values._layerContext = context
        }, operation: operation)
    }

    /// Mode-changing variant: sets both L3 mode and L1 isTestContext in one push.
    public static func with<T, E: Error>(
        mode: Mode,
        _ modify: ((inout Witness.Values) -> Void)? = nil,
        operation: () throws(E) -> T
    ) throws(E) -> T {
        var context = _current
        context.mode = mode
        modify?(&context.values)
        return try Dependency.Scope.with({ l1Values in
            l1Values.isTestContext = (mode == .test)
            l1Values._layerContext = context
        }, operation: operation)
    }
}
```

**withDependencies simplification** — no more `_l1Apply`, no conditional wrapping:

```swift
@inlinable
public func withDependencies<T, E: Error>(
    _ modify: (inout __DependencyValues) -> Void,
    operation: () throws(E) -> T
) throws(E) -> T {
    try Dependency.Scope.with({ l1Values in
        // Extract L3 context from unified scope
        var context = (l1Values._layerContext as? Witness.Context)
            ?? Witness.Context(values: .init(), mode: .live)

        // Build wrapper exposing both stores
        var depValues = __DependencyValues(
            _witnessValues: context.values,
            _l1Values: l1Values
        )
        modify(&depValues)

        // Write back
        context.values = depValues._witnessValues
        l1Values = depValues._l1Values
        l1Values._layerContext = context
    }, operation: operation)
}
```

**`__DependencyValues` simplification** — holds both stores, no `_l1Apply`:

```swift
public struct __DependencyValues: Sendable {
    public var _witnessValues: Witness.Values
    public var _l1Values: Dependency_Primitives.Dependency.Values

    // L3 key subscript
    public subscript<K: Witness.Key>(key: K.Type) -> K.Value where K.Value: Copyable {
        get { Witness.Context[key] }
        set { _witnessValues[key] = newValue }
    }

    // L1 key subscript — writes directly to L1 values
    public subscript<K: __DependencyKey>(key: K.Type) -> K.Value where K.Value: Copyable {
        get { _l1Values[K.self] }
        set { _l1Values[K.self] = newValue }
    }
}
```

No closure chain. No conditional wrapping. L1-key writes go directly to L1's dict. L3-key writes go to L3's dict. Both are in the same @TaskLocal scope.

##### Size analysis

`Witness.Context` is a struct: `Witness.Values` (1 reference `_Storage` + 1 optional reference `_preparedRef` = 2 words) + `Mode` (1 byte, padded to 1 word) = 3 words. Swift's existential inline buffer is 3 words. **`Witness.Context` fits inline** — no heap allocation for the `any Sendable` box.

##### Scope push count

| Scenario | Current (two stacks) | Option C (unified) |
|----------|:---:|:---:|
| Value-only override | 1 push (L3) | 1 push (L1) |
| Mode-changing override | 2 pushes (L3 + L1) | 1 push (L1) |
| `withDependencies` with L1 keys | 2 pushes (L3 + conditional L1) | 1 push (L1) |
| Pure L1 code (no L3) | 1 push (L1) | 1 push (L1) — unchanged |

Mode-changing scopes go from 2 pushes to 1. This is a performance improvement.

##### Read path cost

| Reader | Current | Option C |
|--------|---------|----------|
| L1 code (`Dependency.Scope.current[K.self]`) | @TaskLocal read + dict lookup | **Unchanged** |
| L3 code (`Witness.Context[K.self]`) | @TaskLocal read + dict lookup | @TaskLocal read + existential downcast + dict lookup |
| L3 reading L1 key | @TaskLocal read (L3) + miss + @TaskLocal read (L1) + dict lookup | @TaskLocal read + downcast (miss) + dict lookup |

L3 reads gain one existential downcast (~5ns — type metadata pointer comparison). L1 reads are completely unchanged. L3 reading L1 keys is faster (one @TaskLocal read instead of two).

##### Effect.Context compatibility

`Effect.Context` delegates entirely to `Dependency.Scope` (verified: `Effect.Context.swift`). It doesn't use `Witness.Context._current` at all. Effect.Context is **completely unaffected** by this change.

##### `_layerContext` as `any Sendable`

This field is layer-compliant: L1 doesn't import L3. L1 just carries an `(any Sendable)?` it never inspects. L3 stores and extracts its own type via a cast. The field name is underscore-prefixed, signaling internal infrastructure. The type `any Sendable` creates no dependency from L1 to L3.

However, `_layerContext` is a single slot. If multiple higher layers needed opaque storage, they'd conflict. Currently only L3 uses it. If this became a concern, the slot could become `[ObjectIdentifier: any Sendable]` keyed by module identifier — but this is speculative and not needed now.

#### Option D: Unified Dictionary — Single Storage

Go further than Option C: replace L3's `_Storage` (UnsafeRawPointer dict) with L1's `[ObjectIdentifier: any Sendable]` dict. Both L1 and L3 keys stored in one dictionary. L3 stores `Ownership.Shared<V>` as existential.

```swift
// L3 writes:
l1Values.storage[ObjectIdentifier(K.self)] = Ownership.Shared(value)

// L3 reads:
if let box = l1Values.storage[ObjectIdentifier(K.self)] as? Ownership.Shared<K.Value> {
    return box.value
}
```

**Pros**: Truly single store. No `_layerContext` at all. One dict for everything.
**Cons**: L3 loses UnsafeRawPointer storage optimization (40 bytes/entry vs 8). L3's `Preparation.Store` fallback and `Mode` need to be stored somewhere else (special keys? fields on `Dependency.Values`?). Much larger refactor — changes L3's entire storage model. The existential cast per read is the same cost as Option C's downcast.

This is the most radical option. It could be a future evolution from Option C, but attempting it now is premature — Option C already solves the problem.

### Comparison

| Criterion | A: Closure Bridge | B: Value Bridge | C: Opaque Slot | D: Unified Dict |
|-----------|:---:|:---:|:---:|:---:|
| E1: Eliminates bridging | No (`_l1Apply`) | Partial (data bridge) | **Yes** | **Yes** |
| E2: Single mental model | No (two stacks) | No (two stacks) | **Yes** (one stack) | **Yes** (one dict) |
| E3: Layer compliance | Yes | Yes | **Yes** | **Yes** |
| E4: Performance | Baseline | Baseline | **Better** (fewer pushes) | Better (fewer pushes) |
| E5: Complexity (risk) | Medium (4 files) | Medium (4 files) | Medium (5 files) | High (8+ files) |
| E6: API stability | Yes | Yes | **Yes** (1 additive L1 field) | No (L3 storage model change) |

### Prior Art

Per [RES-021] for Tier 2:

**SwiftUI `@Environment`**: Single store, single @TaskLocal-equivalent (view tree propagation). No layered split because SwiftUI is one module.

**pointfreeco/swift-dependencies**: Single store, single @TaskLocal. Our ecosystem split was a consequence of the layer architecture.

**Algebraic effects (OCaml 5, Koka)**: Single handler stack. No concept of "two handler stacks."

**Reader monad (Haskell)**: Single environment. Can be layered via type composition (`ReaderT (r1, r2) m a`), but lookup traverses all layers.

**Option C's opaque slot** follows the Reader monad pattern: L1's scope is the environment, L3's context is composed into it via a typed slot. The single @TaskLocal is the single environment. Layer separation is maintained through type erasure at the boundary.

### Theoretical Grounding

Option C implements a form of **open recursion through type erasure**. L1 defines a generic attachment point (`any Sendable`) that higher layers populate with their own types. This is analogous to:

- **Extension points in framework design**: A base class providing `userInfo: [String: Any]` for subclass-specific data.
- **Existential quantification**: L1 knows `∃T: Sendable. _layerContext = T` but not what `T` is. L3 knows `T = Witness.Context`.

The key property: **L1's behavior is independent of `_layerContext`'s contents**. L1 never reads it. It's purely carried through @TaskLocal scope inheritance for L3's benefit.

### Design Questions (v2.0)

These questions were posed in the handoff document to work from first principles before committing to an implementation.

#### Q1: What is the correct semantic model for a layered dependency system?

**Answer: One Reader effect over a layered environment, approximated by two coordinated @TaskLocals.**

Dependency injection is a Reader effect (Wadler & Blott 1989, Plotkin & Pretnar 2009). In algebraic effects theory, the Reader effect has three components:
- A **handler** that provides the environment
- An **ask** operation that reads the environment
- A **local** combinator that modifies the environment for a sub-computation

In our system:
- `Dependency.Scope.with` / `Witness.Context.with` / `withDependencies` = `local`
- `Dependency.Scope.current` / `Witness.Context.current` = `ask`
- The @TaskLocal variables = handler installation mechanism

The environment is a **product type**: (L1 fields: `[ObjectIdentifier: any Sendable]` + `isTestContext: Bool`) × (L3 fields: `[ObjectIdentifier: UnsafeRawPointer]` + `Mode` + `Preparation.Store?`). A single `local` push should establish a new environment frame containing both components.

The layer constraint prevents the handler from being a single @TaskLocal over this product type (L1 cannot reference L3's types in the product). So we approximate with two @TaskLocals that must be **pushed atomically** from `local` call sites.

**Key insight**: The two @TaskLocals are NOT two independent Reader effects. They are ONE Reader effect over a layered environment, implemented as two coordinated @TaskLocals because of the layer constraint. This has three consequences:

1. **All `withDependencies` pushes must coordinate both stacks** — they are the `local` combinator over the full environment.
2. **A push of L3 only** (via `Witness.Context.with` directly) is valid — it implicitly inherits L1's current environment via @TaskLocal inheritance.
3. **A push of L1 only** (via `Dependency.Scope.with` directly) is valid — it implicitly inherits L3's current environment.

The prior art confirms this model: SwiftUI `@Environment`, pointfreeco/swift-dependencies, OCaml 5 algebraic effects, and Haskell's `ReaderT` all use a single environment/handler stack. Our two-stack architecture is an implementation artifact, not a semantic feature.

#### Q2: Given the layer constraint (L1 can't import L3), is a single @TaskLocal even possible without existentials?

**Answer: No — but the existential cost is negligible, and L1 already uses the same pattern.**

For a single @TaskLocal at L1 to carry L3's context, L3's data must be type-erased into something L1 can store. The options:

| Mechanism | Existential? | Sendable? | Safe? |
|-----------|:---:|:---:|:---:|
| `any Sendable` (Option C) | Yes | Yes | Yes |
| `UnsafeRawPointer` | No | Yes | No (manual lifetime) |
| Callback/function pointer | No | Needs `nonisolated(unsafe)` | Fragile (init ordering) |
| Generic @TaskLocal | N/A — `@TaskLocal` requires concrete type at declaration | — | — |

The v2.0.0 analysis concluded that Option C's existential downcast violated constraint C2 (no new existentials). A subsequent collaborative discussion re-evaluated this: **L1 is already entirely existential-based** (`[ObjectIdentifier: any Sendable]`). Every L1 key read already does an `as? K.Value` downcast. Adding one more key (`_ContextKey`) that stores `Witness.Context` in the same dictionary adds zero new existential categories. The constraint was misapplied.

The **dictionary-key approach** (implemented) resolves this: store `Witness.Context` in L1's existing dictionary under an internal `_ContextKey: Dependency.Key` defined in L3. No new `_layerContext` field. No new existential pattern. Same mechanism L1 already uses for every key.

#### Q3: Is "always push both stacks" semantically sound?

**Answer: Yes. The extra L1 push is not observable and costs ~1 allocation.**

Trace through the cases:

**Case 1: No L1 keys written.** `withDependencies { $0[SomeWitnessKey.self] = .mock } operation: { ... }` pushes L1 with inherited values (no modifications). L1 readers inside `operation` see the same values as outside. The push creates a new @TaskLocal frame with `Dependency.Values` copied from parent (shallow: one dict reference + one bool). This is NOT observable — L1's API exposes `current` (the values), not scope identity. Cost: one @TaskLocal linked-list node allocation (~16 bytes).

**Case 2: Nested scoping.** Two nested `withDependencies` calls. Each pushes both stacks. Inner push inherits outer's L1 values via @TaskLocal inheritance, which starts from `Dependency.Scope.current` (= the frame pushed by the outer call). Inner push inherits outer's L3 values via `Witness.Context.with` inheriting `_current`. Both correct by @TaskLocal semantics.

**Case 3: L1 code pushes its own scope inside the operation.** `Dependency.Scope.with { ... }` inside a `withDependencies` operation. This pushes a new L1 frame on top of the one `withDependencies` pushed. L3 values unaffected (separate @TaskLocal). Same behavior as current architecture.

**Case 4: Effect.Context inside the operation.** `Effect.Context.with { ... }` delegates to `Dependency.Scope.with`. Same as Case 3. Completely unaffected.

**Observable difference analysis**: `Dependency.Values` is a struct containing `storage: [ObjectIdentifier: any Sendable]` (reference type, CoW) and `_isTestContext: Bool`. Copying it copies the dict reference (O(1)) and the bool. If no L1 keys are written, the dict reference points to the same backing storage as the parent frame. Any code reading `Dependency.Scope.current[K.self]` gets the same result whether or not the extra frame exists.

**Conclusion**: "Always push both" produces identical behavior to "conditionally push L1." The only cost is one trivial allocation per `withDependencies` call, regardless of whether L1 keys were written.

#### Q4: What is the right relationship between `Witness.Context.with(mode:)` and `withDependencies(mode:)`?

**Answer: Non-mode `withDependencies` gets one L1 push (clean). Mode `withDependencies` gets a double L1 push (correct but redundant). Optimizable later with an L3-only entry point.**

Current architecture (Phase 1 committed):
- `Witness.Context.with` (non-mode, line 159) pushes L3 only
- `Witness.Context.with(mode:)` (line 182) pushes **both** L3 and L1 (for `isTestContext`)
- `withTest` / `withPreview` (lines 277, 304) push both L3 and L1

Under "always push both," `withDependencies` wraps the operation in `Dependency.Scope.with` unconditionally. This produces:

| `withDependencies` overload | L3 pushes | L1 pushes | Notes |
|:---|:---:|:---:|:---|
| Non-mode (lines 65-82) | 1 | **1** | `Witness.Context.with` (L3 only) + explicit L1. Clean. |
| Mode (lines 135-155) | 1 | **2** | `Witness.Context.with(mode:)` (L3+L1) + explicit L1. Redundant. |
| Async variants | Same pattern | Same pattern | |

The double L1 push in the mode variant works correctly because `Dependency.Scope.with` reads `_current` (which is the mode-pushed L1 frame), then replaces values with `l1Values` (which was captured before the mode push but has `isTestContext` set explicitly). The inner push supersedes the outer. Values are identical. No observable difference.

**Cost of the redundant push**: one @TaskLocal frame allocation (~16 bytes) per mode-changing `withDependencies` call. This is negligible — mode changes happen at test-run granularity, not per-operation.

**Optimization path** (defer until profiling justifies): Add a public-but-underscore-prefixed entry point on `Witness.Context` that pushes L3 without pushing L1:

```swift
// In Witness.Context (swift-witnesses):
/// Infrastructure: pushes L3 context only. Caller handles L1.
@inlinable
public static func _withContextOnly<T, E: Error>(
    _ modify: (inout Context) -> Void,
    operation: () throws(E) -> T
) throws(E) -> T {
    var context = _current
    modify(&context)
    return try $_current.withValue(context) {
        do throws(E) {
            return Result<T, E>.success(try operation())
        } catch {
            return Result<T, E>.failure(error)
        }
    }.get()
}
```

This would let `withDependencies(mode:)` do exactly 1 L3 push + 1 L1 push. But the method exposes `Context` (values + mode) as a mutable `inout`, which is a wider API surface. **Defer until needed.**

**Recommendation for now**: Accept the double L1 push. It's correct, trivially cheap, and avoids widening L3's API surface.

#### Q5: Is there a design where L1 doesn't need its own @TaskLocal at all?

**Answer: No. L1 must retain its @TaskLocal for standalone operation.**

L2 packages (RFC 4122, IEEE 754, RFC 6238) import only L1. They read `Dependency.Scope.current[K.self]` without L3 being loaded. If L1 had no @TaskLocal, there would be no storage at all for these packages.

Alternatives explored:

**Callback registration**: L3 registers a function pointer at static initialization that L1 calls to read the unified scope.

```swift
// L1:
public nonisolated(unsafe) var _dependencyResolver:
    (@Sendable (ObjectIdentifier) -> (any Sendable)?)? = nil
```

Problems:
1. **Initialization ordering**: Swift has no guaranteed module initialization order. If L2 code reads a dependency before L3's initializer runs, the resolver is nil. The fallback to own @TaskLocal would still be needed — defeating the purpose.
2. **Mutable static state**: `nonisolated(unsafe)` is a strict concurrency violation flag. The resolver must be set once before any reads, but there's no language-level guarantee of this ordering.
3. **Performance**: Every L1 read gains a function pointer call + nil check on the miss path.
4. **Still uses existentials**: The resolver returns `(any Sendable)?` — same existential it was trying to avoid.

**L3-owned @TaskLocal with L1 reading via indirection**: L3 owns the only @TaskLocal. L1's `Dependency.Scope.current` becomes a computed property that reads from L3's @TaskLocal via a registered function pointer. Same problems as above, plus L1's own `Dependency.Scope.with` would need to know how to push L3's @TaskLocal — which requires importing L3.

**Conclusion**: Two @TaskLocals is structurally necessary given the layer constraint and L1's standalone requirement. The right solution is coordinated pushing (from `withDependencies`), not @TaskLocal elimination.

#### Option E: Always Push Both Stacks

**Core idea**: `withDependencies` always pushes both @TaskLocals. `__DependencyValues` holds `_l1Values: Dependency.Values` directly (replacing `_l1Apply` closure chain). L1-key writes go into the struct. No existentials. No conditional branching.

**`__DependencyValues` change** — replace `_l1Apply` with `_l1Values`:

```swift
public struct __DependencyValues: Sendable {
    public var _witnessValues: Witness.Values
    public var _l1Values: Dependency_Primitives.Dependency.Values

    @inlinable
    public init(
        _witnessValues: Witness.Values = Witness.Values(),
        _l1Values: Dependency_Primitives.Dependency.Values = .init()
    ) {
        self._witnessValues = _witnessValues
        self._l1Values = _l1Values
    }

    // L3 key subscript — unchanged
    @inlinable
    public subscript<K: Witness.Key>(key: K.Type) -> K.Value where K.Value: Copyable {
        get { Witness.Context[key] }
        set { _witnessValues[key] = newValue }
    }

    // L1 key subscript — direct struct access, no closure chain
    @inlinable
    public subscript<K: __DependencyKey>(key: K.Type) -> K.Value where K.Value: Copyable {
        get { _l1Values[K.self] }
        set { _l1Values[K.self] = newValue }
    }
}
```

**`withDependencies` change** — always push both, no conditional:

```swift
@inlinable
public func withDependencies<T, E: Error>(
    _ modify: (inout __DependencyValues) -> Void,
    operation: () throws(E) -> T
) throws(E) -> T {
    var l1Values = Dependency.Scope.current
    return try Witness.Context.with({ witnessValues in
        var depValues = __DependencyValues(
            _witnessValues: witnessValues,
            _l1Values: l1Values
        )
        modify(&depValues)
        witnessValues = depValues._witnessValues
        l1Values = depValues._l1Values
    }, operation: {
        try Dependency.Scope.with({ $0 = l1Values }, operation: operation)
    })
}
```

The `var l1Values` is captured by two non-escaping closures: the modify closure writes to it, the operation closure reads from it. Both run sequentially within `Witness.Context.with` (modify before operation). The `Dependency.Scope.with({ $0 = l1Values })` replaces L1's values entirely with the (potentially modified) captured values.

**Mode-changing variant**:

```swift
@inlinable
public func withDependencies<T, E: Error>(
    mode: __DependencyContext.Mode,
    _ modify: ((inout __DependencyValues) -> Void)? = nil,
    operation: () throws(E) -> T
) throws(E) -> T {
    var l1Values = Dependency.Scope.current
    l1Values.isTestContext = (mode == .test)
    return try Witness.Context.with(mode: mode, { witnessValues in
        if let modify {
            var depValues = __DependencyValues(
                _witnessValues: witnessValues,
                _l1Values: l1Values
            )
            modify(&depValues)
            witnessValues = depValues._witnessValues
            l1Values = depValues._l1Values
        }
    }, operation: {
        try Dependency.Scope.with({ $0 = l1Values }, operation: operation)
    })
}
```

`Witness.Context.with(mode:)` pushes L3 (with mode) and L1 (with `isTestContext`). Then `Dependency.Scope.with({ $0 = l1Values })` pushes L1 again with the complete `l1Values` (which includes `isTestContext` + any key overrides). The second L1 push starts from the mode-pushed frame, then replaces values entirely. Since `l1Values.isTestContext` was set explicitly to `(mode == .test)`, and the mode-pushed frame has the same `isTestContext`, the replacement is idempotent for mode. L1 key overrides from `modify` are added.

##### Correctness of the `l1Values` capture

`l1Values` is initialized from `Dependency.Scope.current` **before** any pushes by `withDependencies`. This captures the inherited L1 environment. Then `modify` may add key overrides to `l1Values`. Then the explicit L1 push installs `l1Values` as the new frame.

For mode-changing variants, `Witness.Context.with(mode:)` pushes an intermediate L1 frame (with `isTestContext`). The explicit L1 push reads `_current` (the intermediate frame), then replaces values with `l1Values`. Since `l1Values` already has `isTestContext` set, and the intermediate frame's storage dict equals `l1Values.storage` (both derived from the same parent), the replacement is correct.

For non-mode variants, `Witness.Context.with` (non-mode) pushes only L3. The explicit L1 push reads `_current` (the parent frame, unchanged), then replaces with `l1Values` (derived from the same parent + modifications). Correct.

##### What the `Witness.Values` L1-key subscript becomes

The `Witness.Values` L1-key subscript (added in Phase 2/3 work, `Witness.Values.swift` lines 216-236) remains useful for direct L3 callers who read L1 keys through `Witness.Context[K.self]`. It is NOT used by `__DependencyValues` in Option E — the L1-key subscript on `__DependencyValues` reads/writes `_l1Values` directly.

This is semantically correct: within a `withDependencies` scope, L1-key reads from `__DependencyValues` should reflect the values being built (which are in `_l1Values`), not the already-pushed L1 scope (which `Witness.Values`'s fallback to `Dependency.Scope.current` would read).

##### Push count

| Scenario | Current (conditional) | Option E (always push) |
|:---|:---:|:---:|
| L3-only keys | 1 push (L3) | 1 L3 + **1 L1** |
| L1-only keys | 1 L3 + 1 L1 (conditional) | 1 L3 + 1 L1 |
| Mixed keys | 1 L3 + 1 L1 (conditional) | 1 L3 + 1 L1 |
| Mode change, no keys | 1 L3 + 1 L1 (from mode) | 1 L3 + **2 L1** |
| Mode change + L1 keys | 1 L3 + 2 L1 (mode + conditional) | 1 L3 + 2 L1 |

The only differences: (1) L3-only keys gain a no-op L1 push; (2) mode changes without L1 keys gain a redundant L1 push. Both differences are not observable and cost ~16 bytes each.

##### Files changed

| File | Change |
|------|--------|
| `swift-dependencies/.../Dependency.Values.swift` | Replace `_l1Apply` with `_l1Values`, simplify L1-key subscript |
| `swift-dependencies/.../withDependencies.swift` | Remove conditional branching, always push L1 |

Two files. No L1 changes. No L3 changes (beyond what Phase 1/2 already did). `Witness.Values` L1-key subscript and `Witness.Context` L1-key subscript remain unchanged.

### Comparison (Updated)

| Criterion | A: Closure Bridge | B: Value Bridge | C: Opaque Slot | D: Unified Dict | **E: Always Push Both** |
|-----------|:---:|:---:|:---:|:---:|:---:|
| E1: Eliminates bridging | No (`_l1Apply`) | Partial (data bridge) | **Yes** | **Yes** | **Yes** |
| E2: Single mental model | No (two stacks) | No (two stacks) | **Yes** (one stack) | **Yes** (one dict) | Partial (two stacks, coordinated) |
| E3: Layer compliance | Yes | Yes | **Yes** | **Yes** | **Yes** |
| E4: Performance | Baseline | Baseline | **Better** (fewer pushes) | Better (fewer pushes) | Baseline (+1 trivial push) |
| E5: Complexity (risk) | Medium (4 files) | Medium (4 files) | Medium (5 files) | High (8+ files) | **Low (2 files)** |
| E6: API stability | Yes | Yes | **Yes** (1 additive field) | No (storage change) | **Yes** (no L1 change) |
| No new existentials | Yes | Yes | **No** (`as? Witness.Context`) | **No** | **Yes** |

## Outcome

**Status**: IMPLEMENTED (2026-03-04)

### Implemented: Dictionary-Key Approach (via Collaborative Discussion)

Option E (Always Push Both) was implemented first but was then superseded by a better design discovered through a [collaborative Claude-ChatGPT discussion](/tmp/tasklocal-unification-transcript.md). The key insight from ChatGPT: **store `Witness.Context` in L1's existing `[ObjectIdentifier: any Sendable]` dictionary under an internal `Dependency.Key` conformance defined in L3** — no new `_layerContext` field on L1, no separate @TaskLocal.

The existential constraint (C2) that blocked Option C was misapplied: L1 is already entirely existential-based (`[ObjectIdentifier: any Sendable]`). Using L1's existing dictionary for one more key — `_ContextKey` — adds zero new existential categories. The `as? Witness.Context` downcast uses the same pattern L1 already uses for every key read (`as? K.Value`).

#### What Was Implemented

**L3 (`swift-witnesses/Witness.Context.swift`)**:

1. **Internal `_ContextKey: Dependency.Key`** — stores `Witness.Context` in L1's dictionary:
   ```swift
   internal enum _ContextKey: Dependency.Key {
       static var liveValue: Witness.Context { .init(values: .init(), mode: .live) }
       static var testValue: Witness.Context { liveValue }  // mode managed by _withScope
   }
   ```

2. **Computed `_current`** — reads from L1's dictionary (deleted `@TaskLocal`):
   ```swift
   private static var _current: Witness.Context {
       Dependency.Scope.current[_ContextKey.self]
   }
   ```

3. **`_withScope` bridge** — single entry point routing through `Dependency.Scope.with`:
   ```swift
   public static func _withScope<T, E: Error>(
       mode: Mode? = nil,
       _ modify: (inout Witness.Values, inout Dependency.Values) -> Void,
       operation: () throws(E) -> T
   ) throws(E) -> T {
       try Dependency.Scope.with({ l1Values in
           var context = l1Values[_ContextKey.self]
           if let mode { context.mode = mode; l1Values.isTestContext = (mode == .test) }
           modify(&context.values, &l1Values)
           l1Values[_ContextKey.self] = context
       }, operation: operation)
   }
   ```

4. **All 8 scoping methods** (`with`, `with(mode:)`, `withTest`, `withPreview` × sync/async) refactored to thin delegates to `_withScope`.

**L3 (`swift-dependencies/withDependencies.swift`)**:

All 4 overloads simplified to call `_withScope`. No double push, no `var l1Values` capture dance, no explicit closure type annotations:

```swift
public func withDependencies<T, E: Error>(
    _ modify: (inout __DependencyValues) -> Void,
    operation: () throws(E) -> T
) throws(E) -> T {
    try Witness.Context._withScope({ witnessValues, l1Values in
        var depValues = __DependencyValues(_witnessValues: witnessValues, _l1Values: l1Values)
        modify(&depValues)
        witnessValues = depValues._witnessValues
        l1Values = depValues._l1Values
    }, operation: operation)
}
```

#### Benefits over Option E

| Aspect | Option E (Always Push Both) | **Dictionary-Key (Implemented)** |
|--------|:---:|:---:|
| @TaskLocal count | 2 | **1** |
| Mental model | Two coordinated stacks | **Single stack** |
| Pushes per scope | 1 L3 + 1 L1 (minimum 2) | **1 (always)** |
| Mode-change pushes | 1 L3 + 2 L1 | **1** |
| L1 code changes | None | **None** |
| New existentials | None | None (reuses existing dict) |
| Double Result-wrapping | Yes (L3 + L1 each wrap) | **No** (single wrap in L1) |
| `var l1Values` capture | Required | **Eliminated** |

#### Benefits over Option C (original)

The dictionary-key approach is a refinement of Option C that avoids its specific downsides:

| Aspect | Option C (Opaque Slot) | **Dictionary-Key (Implemented)** |
|--------|:---:|:---:|
| L1 API change | New `_layerContext` field | **None** (uses existing dict) |
| Single-slot limitation | Only one layer can attach | **No limit** (any key can be stored) |
| Existential pattern | New category (`any Sendable` field) | **Same pattern** as existing keys |

#### Comparison (Final)

| Criterion | A: Closure | B: Value | C: Opaque Slot | D: Unified Dict | E: Always Push Both | **F: Dictionary-Key** |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|
| E1: Eliminates bridging | No | Partial | **Yes** | **Yes** | **Yes** | **Yes** |
| E2: Single mental model | No | No | **Yes** | **Yes** | Partial | **Yes** |
| E3: Layer compliance | Yes | Yes | **Yes** | **Yes** | **Yes** | **Yes** |
| E4: Performance | Baseline | Baseline | Better | Better | Baseline | **Best** (1 push always) |
| E5: Complexity (risk) | Medium | Medium | Medium | High | **Low** | **Low** |
| E6: API stability | Yes | Yes | Yes (1 field) | No | **Yes** | **Yes** (zero L1 change) |
| No new existentials | Yes | Yes | No | No | Yes | **Yes** (reuses existing) |

### Risks

1. **`Witness.Context` size exceeding inline buffer**: Currently 3 words (fits Swift's existential inline buffer — no heap allocation). If `Witness.Context` grows beyond 3 words, introduce a Copyable stored wrapper. Currently not a concern.

2. **~5ns existential downcast per L3 read**: `_current` reads `_ContextKey` from L1's dictionary, which involves `as? Witness.Context`. This is a type metadata pointer comparison — negligible in dependency resolution context.

### Implementation History

1. Option E (Always Push Both) was implemented first based on the v2.0.0 recommendation
2. A [collaborative Claude-ChatGPT discussion](/tmp/tasklocal-unification-transcript.md) (3 rounds) identified the dictionary-key approach as strictly superior
3. Dictionary-key approach implemented, replacing Option E entirely
4. Committed: `swift-witnesses` `07d5e0a`, `swift-dependencies` `b8dc901`

### Relationship to Parent Research Phases

| Phase | Status | Impact |
|:------|:-------|:-------|
| Phase 1: Mode Propagation | **Done** | Subsumed — `_withScope` handles mode + `isTestContext` in a single push. |
| Phase 2: Protocol Refinement | **Done** | Independent. `Witness.Key: Dependency.Key` is orthogonal to the stack question. |
| Phase 3: L1 Key Bridge | **Superseded** | `_l1Apply` closure chain and conditional wrapping eliminated entirely. `_withScope`'s two-`inout` contract provides full L1-key fidelity. |

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-03-04 | Initial analysis: Options A-D, recommended Option C (L1 Opaque Slot) |
| 2.0.0 | 2026-03-04 | Design Questions analysis (Q1-Q5). Added Option E (Always Push Both). Revised recommendation from Option C to Option E — Option C violates no-existentials constraint; Option E achieves same goals without new existentials. |
| 3.0.0 | 2026-03-04 | **IMPLEMENTED.** Collaborative Claude-ChatGPT discussion (3 rounds) discovered dictionary-key approach: store `Witness.Context` in L1's existing dictionary under `_ContextKey: Dependency.Key`. Supersedes both Option C and Option E. Single @TaskLocal, zero L1 change, single push per scope. Committed to swift-witnesses + swift-dependencies. |

## References

### Parent Research
- `dependency-witness-store-coherence.md` v3.0 — Phased approach (B + D + C), all phases complete/superseded

### Collaborative Discussion
- `/tmp/tasklocal-unification-transcript.md` — Full 3-round Claude-ChatGPT transcript
- `/tmp/tasklocal-unification-converged.md` — Converged action plan

### Source Files (Post-Implementation)
- `swift-dependency-primitives/.../Dependency.Scope.swift` — L1 @TaskLocal (unchanged — single source of truth)
- `swift-dependency-primitives/.../Dependency.Values.swift` — L1 storage (unchanged — carries `Witness.Context` via existing dict)
- `swift-dependency-primitives/.../Dependency.Key.swift` — L1 protocol (`Value: ~Copyable & Sendable`)
- `swift-witnesses/.../Witness.Context.swift` — `_ContextKey`, `_withScope`, computed `_current` (no own @TaskLocal)
- `swift-witnesses/.../Witness.Values.swift` — L3 storage (UnsafeRawPointer, CoW, ~Copyable), L1-key subscript
- `swift-witnesses/.../Witness.Key.swift` — L3 protocol (`: Dependency.Key, __WitnessKeyTest`)
- `swift-effect-primitives/.../Effect.Context.swift` — Pure delegation to `Dependency.Scope` (unaffected)
- `swift-dependencies/.../withDependencies.swift` — 4 overloads, all using `Witness.Context._withScope`
- `swift-dependencies/.../Dependency.Values.swift` — `__DependencyValues` with `_witnessValues` + `_l1Values`

### Theoretical
- Wadler, P. & Blott, S. (1989). "How to make ad-hoc polymorphism less ad hoc." — Dictionary-passing style (Reader effect basis)
- Plotkin, G. & Pretnar, M. (2009). "Handlers of Algebraic Effects." — Single handler stack, `local` combinator
- SwiftUI `@Environment` / `EnvironmentKey` — single store, single protocol (no layer split)
- pointfreeco/swift-dependencies — single store, single `DependencyKey` protocol
