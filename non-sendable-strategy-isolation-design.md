# Non-Sendable Strategy with Isolation-Based Thread Safety

<!--
---
version: 1.0.0
last_updated: 2026-03-04
status: RECOMMENDATION
tier: 2
predecessor: sendable-in-rendering-and-snapshot-infrastructure.md
---
-->

## Context

The predecessor research ([sendable-in-rendering-and-snapshot-infrastructure.md](sendable-in-rendering-and-snapshot-infrastructure.md)) recommended removing `Value: Sendable` from `Test.Snapshot.Strategy<Value, Format>` (Option B). That change is implemented — Strategy no longer constrains `Value: Sendable`.

However, Strategy itself remains `Sendable` with `@Sendable` closures:

```swift
// Test.Snapshot.Strategy.swift:63
public struct Strategy<Value, Format>: Sendable, Witness.`Protocol`
    where Format: Sendable {
    public var snapshot: @Sendable (Value) -> Async.Callback<Format>
    public var syncSnapshot: (@Sendable (Value) -> Format)?
}
```

This causes `SendableMetatypes` warnings in generic closures that perform protocol dispatch:

```swift
// Test.Snapshot.Strategy+Description.swift:35
Test.Snapshot.Strategy<String, String>.lines.pullback { String(describing: $0) }
//                                                      ^^^^^^^^^^^^^^^^^^^^^^
// Warning: capture of 'V.Type' (a non-Sendable metatype) in @Sendable closure
```

The `@Sendable` annotation on closures requires all captures to be Sendable. Generic metatypes (`V.Type`) are stateless but not `Sendable` — a known false positive the compiler cannot elide.

Option B did not fix this because the warnings come from `@Sendable` on closures, not from `Value: Sendable` on the struct. Removing `@Sendable` from closures is the only way to eliminate these warnings — but doing so makes Strategy non-Sendable (function values are Sendable only when marked `@Sendable`).

This exploration asks: **Can Strategy be entirely non-Sendable, using isolation instead of sendability for thread safety?**

## Trigger

`SendableMetatypes` warnings on `description()`, `customDescription()`, `debugDescription()`, and any `pullback` closure that performs protocol dispatch on a generic type parameter.

## Architecture Trace

### Strategy Creation Sites

All strategies are created as computed `static var` or `static func` on extensions:

| Strategy | File | Pattern |
|----------|------|---------|
| `.lines`, `.text` | `Test.Snapshot.Strategy+Text.swift` | `SimplyStrategy` (identity) |
| `.data` | `Test.Snapshot.Strategy+Data.swift` | `SimplyStrategy` (identity) |
| `.description()` | `Test.Snapshot.Strategy+Description.swift` | `.lines.pullback { String(describing: $0) }` |
| `.customDescription()` | same | `.lines.pullback { $0.description }` |
| `.debugDescription()` | same | `.lines.pullback { $0.debugDescription }` |
| `.dump` | same | `Strategy(snapshot: { ... Swift.dump ... })` |
| `.svg` | `Test.Snapshot.Strategy+SVG.swift` | `.lines.pullback { String(value, ...) }` |
| `.html` | `Test.Snapshot.Strategy+HTML.swift` | `.lines.pullback { ... try? String(value) ... }` |

These are all computed properties returning fresh instances. No storage. No shared mutable state. Each call site gets its own Strategy value.

### Strategy Consumption Sites

All strategies are consumed by assertion functions that run within a single test:

| Consumer | File | Sync/Async |
|----------|------|------------|
| `assertInlineSnapshot` (4 overloads) | `Test.Snapshot.Inline.assert.swift` | Both |
| `assertSnapshot` (4 overloads) | `Test.Snapshot.assert.swift` | Both |
| `verifyInlineSnapshot` (4 overloads) | same files | Both |
| `Testing.__snapshotInline` (2 overloads) | `Snapshot.swift` | Both |
| `Testing.__snapshotFile` (2 overloads) | `Snapshot.swift` | Both |
| `#snapshot` macro | `Snapshot.swift` | Expands to bridge |

**Critical observation**: In every consumption path, Strategy is created at the call site and consumed within the same function body. There is no path where a Strategy instance is stored, shared, or sent to another isolation domain.

### Composition Sites

| Composition | Parameters | Creates |
|-------------|-----------|---------|
| `pullback` | `@Sendable (NewValue) -> Value` | New Strategy |
| `asyncPullback` | `@Sendable (NewValue) -> Async.Callback<Value>` | New Strategy |
| `redacting` | `[Redaction<Format>]` | New Strategy |

All composition methods return new Strategy values consumed by the same call site. The `@Sendable` on transform closures is the direct cause of `SendableMetatypes` warnings in `pullback`-based strategies.

### Types That Store Strategy

| Type | Sendable? | Usage |
|------|-----------|-------|
| `Faceted<Value>` | Yes (`:Sendable`) | Stores `primary: Strategy` and `facets: [(name, strategy)]` |
| `Diffing<Format>` | Yes (`:Sendable`) | Independent — stored *in* Strategy, not the reverse |
| `Redaction<Format>` | Yes (`:Sendable`) | Independent — composed *into* Strategy via `redacting()` |

`Faceted` is the only external type that stores Strategy. If Strategy becomes non-Sendable, Faceted must also become non-Sendable.

## Analysis

### Question 1: Can Strategy be non-Sendable?

**Yes.** Strategy instances are never sent across isolation boundaries. The complete lifecycle is:

1. Created at test call site (or in static computed property that returns a fresh value)
2. Optionally composed via `pullback` / `redacting`
3. Passed to `assertSnapshot` / `assertInlineSnapshot` as parameter
4. Used to capture value and diff — entirely within the assertion function
5. Discarded

No step involves crossing an isolation boundary. The `Sendable` conformance on Strategy is defensive, not functional.

### Question 2: What would non-`@Sendable` closures look like?

```swift
public struct Strategy<Value, Format>: Witness.`Protocol` where Format: Sendable {
    public var snapshot: (Value) -> Async.Callback<Format>
    public var syncSnapshot: ((Value) -> Format)?

    public init(
        pathExtension: String?,
        diffing: Diffing<Format>,
        asyncSnapshot: @escaping (_ value: Value) -> Async.Callback<Format>
    ) { ... }

    public init(
        pathExtension: String?,
        diffing: Diffing<Format>,
        snapshot: @escaping (_ value: Value) -> Format
    ) { ... }

    public func pullback<NewValue>(
        _ transform: @escaping (_ otherValue: NewValue) -> Value
    ) -> Test.Snapshot.Strategy<NewValue, Format> { ... }

    public func asyncPullback<NewValue>(
        _ transform: @escaping (_ otherValue: NewValue) -> Async.Callback<Value>
    ) -> Test.Snapshot.Strategy<NewValue, Format> { ... }
}
```

Changes:
- Remove `: Sendable` from Strategy
- Remove `@Sendable` from all closure stored properties
- Remove `@Sendable` from all closure parameters (`pullback`, `asyncPullback`, `redacting`)
- Keep `Format: Sendable` (needed for `Diffing<Format>: Sendable` storage, though this could also be relaxed in a future step)

The `description()` family becomes:

```swift
public static func description<V>() -> Test.Snapshot.Strategy<V, String> {
    Test.Snapshot.Strategy<String, String>.lines.pullback { String(describing: $0) }
    // No @Sendable on closure → no SendableMetatypes warning on V.Type capture
}
```

**This eliminates `SendableMetatypes` warnings at source.**

### Question 3: How does `nonisolated(nonsending)` interact with assert functions?

Under `NonisolatedNonsendingByDefault` (SE-0461, enabled in our packages), all free functions including `assertInlineSnapshot` and `assertSnapshot` are implicitly `nonisolated(nonsending)`. This means they **inherit the caller's isolation** — no isolation boundary crossing occurs.

When a `@Test func` calls `assertSnapshot(of: circle, as: .svg)`:
1. The test runs in whatever isolation the `@Test` macro provides (typically the test runner's isolation)
2. `assertSnapshot` inherits that same isolation
3. The Strategy parameter is created and consumed entirely within this inherited isolation
4. No Sendable requirement needed — the value never leaves the isolation domain

This is the same mechanism that makes TCA2's non-Sendable `Store` work: isolation inheritance through the entire call chain.

For packages not using `NonisolatedNonsendingByDefault`, the annotation would need to be explicit:

```swift
public nonisolated(nonsending) func assertSnapshot<Value, Format: Sendable>(
    capturing value: Value,
    as strategy: Test.Snapshot.Strategy<Value, Format>,
    ...
) -> Test.Expectation
```

### Question 4: What about async paths?

The async paths work identically due to `Async.Callback`'s design:

```swift
// Async.Callback stores:
let operation: nonisolated(nonsending) () async -> Value

// And exposes:
public func callAsFunction(
    isolation: isolated (any Actor)? = #isolation
) async -> Value
```

When `strategy.capture(value)` is called:
1. `snapshot(value)` returns an `Async.Callback<Format>`
2. `await callback()` calls `callAsFunction(isolation:)` which inherits the caller's isolation via `#isolation`
3. The callback's `operation` is `nonisolated(nonsending)` — it runs in the inherited isolation

**No isolation boundary is crossed.** The async path is isolation-preserving by design. Non-Sendable Strategy values work correctly because the Strategy, the Value, and the captured Format all remain in the same isolation domain.

This is where our infrastructure has a structural advantage: `Async.Callback` was already designed with `nonisolated(nonsending)` semantics (SE-0431/SE-0420), making it a natural fit for non-Sendable composition.

> **Update (2026-03-22)**: `nonsending-compiler-patterns.md` confirmed that the Swift stdlib's function type conversion lattice allows `nonisolated(nonsending)` ↔ `@concurrent` conversion freely, but crossing to specific actor isolation requires Sendable. Since Strategy's closures and values stay within the caller's isolation domain (never crossing to a specific actor), plain (non-`@Sendable`) closures are type-system-guaranteed safe. This validates the non-Sendable Strategy design from the compiler's own conversion rules.
>
> Additionally, `callAsFunction(isolation:)` uses a pattern the stdlib has since deprecated — a future migration to `nonisolated(nonsending) func callAsFunction()` would further simplify this path (see `callback-isolated-nonsending-design.md` v3.1 note).

### Question 5: Impact on `Witness.Protocol` conformance

`Witness.Protocol` is an empty marker protocol:

```swift
// swift-witness-primitives: Witness.Protocol.swift
extension Witness {
    public protocol `Protocol` {}
}
```

No `Sendable` requirement. Dropping `Sendable` from Strategy has zero impact on the `Witness.Protocol` conformance.

### Question 6: Impact on `Diffing<Format>`

`Diffing<Format>: Sendable` stores `@Sendable` closures (`toBytes`, `fromBytes`, `diff`). It is stored **inside** Strategy, not the reverse. If Strategy becomes non-Sendable:

- **Diffing can stay Sendable.** It's an independent type with genuinely pure closures. Its `@Sendable` annotations are semantically correct — serialization and diffing functions have no mutable state.
- The `Format: Sendable` constraint on Strategy exists because `Diffing<Format>` requires it (implicitly, via Sendable conformance of the struct). If Diffing stays Sendable, this constraint should remain.
- No cascade required. Diffing's closures don't perform protocol dispatch on generic types, so `SendableMetatypes` is not an issue for Diffing.

**However**, if we later want to make `Diffing` non-Sendable too (to remove `Format: Sendable` from Strategy), that's a separate, independent change. It's not required for this design to work.

### Question 7: What does TCA2 actually do?

From PF #355/#356 (Feb/Mar 2026), the TCA2 pattern:

**The problem TCA2 solves**: TCA1's `Store` was `@MainActor` and Sendable, requiring effects to use `@Sendable` closures. This forced `Task.yield()` everywhere, made tests non-deterministic, and prevented synchronous effect execution.

**TCA2's solution**: Make `Store` non-Sendable. Use `nonisolated(nonsending)` to propagate isolation:

```swift
// TCA2: Client stores nonisolated(nonsending) closures, NOT @Sendable
private struct Client {
    var status: nonisolated(nonsending) () async -> Bool
}
```

Key quote from Brandon Williams (PF #356, 20:50):
> "It may surprise users, but we were able to accomplish this while simultaneously *minimizing* how many sendable types are in the library. In fact, a major theme of this upcoming series is going to be about *avoiding* sendability when possible."

**The direct parallel to Strategy:**

| TCA2 Concept | Strategy Equivalent |
|---|---|
| `Client` (struct of closures) | `Strategy` (struct of closures) |
| `Client.status: nonisolated(nonsending) () async -> Bool` | `Strategy.snapshot: (Value) -> Async.Callback<Format>` |
| `Store` non-Sendable, isolation-inherited | Strategy non-Sendable, isolation-inherited |
| `store.send(.action)` synchronous in shared isolation | `strategy.capture(value)` synchronous in shared isolation |
| No `Task.yield`, no `@Sendable`, no locks | No `@Sendable`, no SendableMetatypes, no false positives |

The parallel is strong. TCA2's `Client` IS a "bag of closures that transforms values" — exactly what Strategy is. TCA2 proves this pattern works at production scale.

**One difference**: TCA2 uses `nonisolated(nonsending)` on the closure *type* (like `Async.Callback.operation`), while our Strategy could use plain (non-annotated) closures. Both approaches make the type non-Sendable. The `nonisolated(nonsending)` annotation is more precise (it documents the isolation-inheritance contract), but plain closures achieve the same practical effect when the containing type is non-Sendable and the consuming functions are `nonisolated(nonsending)`.

### Question 8: Practical test ergonomics

**Call-site perspective: identical.**

Before (current):
```swift
@Test func testCircle() {
    #snapshot(circle, as: .svg) {
        """
        <svg>...</svg>
        """
    }
}
```

After (non-Sendable Strategy):
```swift
@Test func testCircle() {
    #snapshot(circle, as: .svg) {
        """
        <svg>...</svg>
        """
    }
}
```

No change. The Strategy is created by the computed `static var svg`, passed to the macro expansion, consumed by the assert function — all in the same isolation domain. The user never sees Sendable or its absence.

The only visible change would be in custom strategy definitions. Currently:

```swift
extension Test.Snapshot.Strategy where Value == MyType, Format == String {
    static var custom: Self {
        .lines.pullback { @Sendable value in value.render() }
        //                 ^^^^^^^^^ required today
    }
}
```

After:

```swift
extension Test.Snapshot.Strategy where Value == MyType, Format == String {
    static var custom: Self {
        .lines.pullback { value in value.render() }
        //                cleaner — no @Sendable needed
    }
}
```

This is an ergonomic improvement.

## Cascading Changes

### Scope of changes

| Component | Change | Package |
|-----------|--------|---------|
| `Strategy<Value, Format>` | Remove `: Sendable`, remove `@Sendable` from closures | swift-test-primitives |
| `Strategy.pullback` | Remove `@Sendable` from transform | swift-test-primitives |
| `Strategy.asyncPullback` | Remove `@Sendable` from transform | swift-test-primitives |
| `Strategy.redacting` | Remove `@Sendable` from local `redact` closure | swift-test-primitives |
| `Faceted<Value>` | Remove `: Sendable` | swift-test-primitives |
| `_verifyInlineSnapshot` (internal) | Remove `@Sendable` from `syncSnapshot` parameter | swift-tests |
| `_verifySnapshot` (internal) | Remove `@Sendable` from `syncSnapshot` parameter | swift-tests |
| `assertSnapshot` signatures | Verify `nonisolated(nonsending)` applies (via default or explicit) | swift-tests |
| `assertInlineSnapshot` signatures | Same | swift-tests |
| `__snapshotInline`, `__snapshotFile` bridges | Same | swift-testing |

### What does NOT change

| Component | Reason |
|-----------|--------|
| `Diffing<Format>: Sendable` | Independent type, closures are genuinely pure, no metatype captures |
| `Redaction<Format>: Sendable` | Independent type, `@Sendable` on `apply` is correct |
| `Test.Snapshot.Recording` | Enum, unrelated |
| `Test.Snapshot.Configuration` | Unrelated |
| Call sites (`#snapshot`, `assertSnapshot`, etc.) | Identical API surface |
| SVG/HTML strategy extensions | Identical — just remove `@Sendable` from pullback closures (implicit from Strategy change) |

## Comparison: Current (Sendable Strategy) vs Proposed (Non-Sendable Strategy)

| Criterion | Sendable Strategy (current) | Non-Sendable Strategy (proposed) |
|-----------|---------------------------|--------------------------------|
| **SendableMetatypes warnings** | Present on all generic pullback closures | **Eliminated** |
| **Closure ceremony** | `@Sendable` required on all closures | Plain closures |
| **Test call-site ergonomics** | Identical | **Identical** |
| **Custom strategy definitions** | Need `@Sendable` on closures | **Cleaner** — no annotation |
| **Async safety** | Enforced via `@Sendable` | **Enforced via isolation inheritance** |
| **Thread safety guarantee** | Sendable (can be sent) | Isolation (never needs to be sent) |
| **`@Test` compatibility** | Works | **Works** (via `nonisolated(nonsending)`) |
| **Future ~Copyable formats** | Blocked (Format: Sendable) | Same (Format: Sendable from Diffing) |
| **Diffing impact** | N/A | **None** (stays Sendable) |
| **Faceted impact** | N/A | Must also become non-Sendable |
| **Migration cost** | N/A | Remove annotations, verify isolation |
| **Ecosystem alignment** | Pre-TCA2 / legacy | **TCA2 / modern Swift concurrency** |
| **Reversibility** | N/A | Can re-add Sendable later if needed |

## Constraints

1. Strategy stores no `Value` instances — only closures parameterized by `Value`
2. Strategy is always created and consumed within a single test function's isolation domain
3. `Async.Callback.operation` is already `nonisolated(nonsending)` — isolation inheritance works through the async capture path
4. `NonisolatedNonsendingByDefault` (SE-0461) makes free functions `nonisolated(nonsending)` by default
5. `Diffing<Format>: Sendable` is independently correct and need not change
6. `Faceted<Value>` stores Strategy values and must cascade
7. `Witness.Protocol` is empty — no Sendable interaction
8. Swift Testing's `@Test` macro dispatches to test runner isolation; `nonisolated(nonsending)` functions inherit this correctly

## Risks

### Risk 1: Package feature flag dependency

If `NonisolatedNonsendingByDefault` is not enabled in swift-tests or swift-testing, the assert functions would need explicit `nonisolated(nonsending)` annotations. Without either, the functions would be `nonisolated` (sending) by default, which would require the Strategy parameter to be Sendable.

**Mitigation**: Verify the feature flag is enabled, or add explicit annotations. The annotation is a one-time cost.

### Risk 2: Third-party code storing Strategy

If downstream consumers store Strategy instances in Sendable types, this is a source-breaking change for them.

**Mitigation**: Strategy is a Layer 1 primitive. Downstream consumers are our own Layer 3 packages (swift-tests, swift-testing, swift-svg-rendering, swift-html-rendering). We control all consumers. External adopters of swift-test-primitives are unlikely to store Strategy in Sendable containers.

### Risk 3: Future need to send Strategy across boundaries

If a future use case requires sending Strategy to another isolation domain (e.g., a parallel snapshot runner), non-Sendable Strategy would block this.

**Mitigation**: No such use case exists or is anticipated. Snapshot testing is fundamentally serial — each test captures, compares, and reports independently. If such a need arose, a `SendableStrategy` wrapper could be introduced without changing the base type.

### Risk 4: Faceted cascade

`Faceted<Value>: Sendable` must become non-Sendable. If Faceted is stored in Sendable containers elsewhere, those break.

**Mitigation**: Search found no usage of Faceted outside of its definition. It is consumed at test call sites, same as Strategy. The cascade is safe.

## Outcome

**Status**: RECOMMENDATION

**Recommended**: Make `Test.Snapshot.Strategy` non-Sendable, using isolation inheritance for thread safety.

### Rationale

1. **Root cause resolution**: The `SendableMetatypes` warnings are caused by `@Sendable` on Strategy's closures. This is the only way to eliminate them. Option B (removing `Value: Sendable`) — already implemented — did not and could not fix these warnings.

2. **Sound architecture**: Strategy instances are never sent across isolation boundaries. Every usage path (traced above) is create-compose-consume within a single test function. `Sendable` is a constraint that provides no safety benefit here — it only causes false-positive warnings.

3. **Isolation inheritance is already in place**: `Async.Callback.operation` is `nonisolated(nonsending)`. The async capture path already inherits isolation. Making Strategy non-Sendable aligns Strategy with the isolation model that `Async.Callback` already uses.

4. **TCA2 validates the pattern**: Point-Free's production-scale TCA2 uses this exact approach — non-Sendable types with `nonisolated(nonsending)` closures, relying on isolation inheritance instead of Sendable. Their `Client` type is structurally identical to Strategy (a struct of closures that transforms values). This is proven at scale.

5. **Ecosystem alignment**: Swift 6.2's `NonisolatedNonsendingByDefault` (SE-0461) and PF's "avoid sendability" direction both point toward isolation-first design. This change positions our infrastructure on the right side of the ecosystem trajectory.

6. **Ergonomic improvement**: Dropping `@Sendable` from strategy closures and `pullback` transforms simplifies custom strategy definitions. No functional change to call sites.

### Suggested Implementation Path

**Phase 1: Verify prerequisites** (experiment)
- Confirm `NonisolatedNonsendingByDefault` is enabled in swift-test-primitives, swift-tests, swift-testing
- If not, determine whether to enable it or use explicit `nonisolated(nonsending)` annotations
- Write a minimal compiler test: non-Sendable Strategy passed to `nonisolated(nonsending)` function

**Phase 2: Core change** (swift-test-primitives)
1. Remove `: Sendable` from `Strategy<Value, Format>`
2. Remove `@Sendable` from `snapshot`, `syncSnapshot`, all init parameters
3. Remove `@Sendable` from `pullback` and `asyncPullback` transform parameters
4. Remove `@Sendable` from `redacting()` local closure
5. Remove `: Sendable` from `Faceted<Value>`
6. Verify `Diffing<Format>` unchanged

**Phase 3: Downstream** (swift-tests, swift-testing)
1. Remove `@Sendable` from internal `_verifySnapshot` / `_verifyInlineSnapshot` `syncSnapshot` parameters
2. Verify assert/verify functions are `nonisolated(nonsending)` (via default or explicit annotation)
3. Verify macro bridge functions compile

**Phase 4: Verify** (swift-svg-rendering, swift-html-rendering)
1. Confirm SVG and HTML strategy extensions compile without `@Sendable`
2. Run full test suites

### What NOT to Do

- Do NOT make `Diffing<Format>` non-Sendable — its closures are genuinely pure; `@Sendable` is correct
- Do NOT make `Redaction<Format>` non-Sendable — same reasoning
- Do NOT add `nonisolated(nonsending)` to Strategy's stored closure types — plain closures are sufficient; the consuming functions handle isolation inheritance
- Do NOT use `@Sendable` + `@preconcurrency` or `nonisolated(unsafe)` as workarounds — they suppress the symptom without addressing the design

## References

- [sendable-in-rendering-and-snapshot-infrastructure.md](sendable-in-rendering-and-snapshot-infrastructure.md) — predecessor research (Option B)
- Point-Free Video #355: "Beyond Basics: Isolation, ~Copyable, ~Escapable" (Feb 23, 2026) — TCA2 Store non-Sendable, isolation inheritance demo
- Point-Free Video #356: "Beyond Basics: Superpowers" (Mar 2, 2026) — SQLiteData non-Sendable C library wrapper, "avoiding sendability" philosophy
- SE-0461: NonisolatedNonsendingByDefault
- SE-0431: `nonisolated(nonsending)` function types
- SE-0430: `sending` parameter and result values
- `swift-test-primitives/.../Test.Snapshot.Strategy.swift` — Strategy definition
- `swift-test-primitives/.../Test.Snapshot.Strategy+Description.swift` — SendableMetatypes trigger site
- `swift-async-primitives/.../Async.Callback.swift` — `nonisolated(nonsending)` operation, `#isolation` callAsFunction
- `swift-tests/.../Test.Snapshot.Inline.assert.swift` — assertInlineSnapshot (all overloads)
- `swift-tests/.../Test.Snapshot.assert.swift` — assertSnapshot (all overloads)
- `swift-testing/.../Snapshot.swift` — macro definition + bridge functions
