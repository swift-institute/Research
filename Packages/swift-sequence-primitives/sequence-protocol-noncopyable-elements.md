# Sequence.Protocol ~Copyable Element Support

<!--
---
version: 2.0.0
last_updated: 2026-02-12
status: DECISION
tier: 2
---
-->

## Context

`Sequence.Protocol` currently declares `associatedtype Element` without `~Copyable` suppression, meaning all conformers must have `Copyable` elements. The protocol's stated purpose is to support `~Copyable` containers — but without `~Copyable` elements, this is an incomplete realization. A `~Copyable` container with `~Copyable` elements cannot conform.

The `suppressed-associated-types` experiment (2026-02-12) discovered that the **`SuppressedAssociatedTypes` feature flag is available in Swift 6.2.3** and enables `associatedtype Element: ~Copyable` in user-defined protocols. A second flag, `SuppressedAssociatedTypesWithDefaults`, adds inference defaulting but is not yet available in 6.2.3.

The `two-tier-borrowing-overloads` experiment (2026-02-12) proved that **`borrowing` closure parameters are transparent at call sites for Copyable elements** — callers write no annotation, can copy, pass by value, and use elements in expressions identically to by-value parameters.

This research analyzes the design implications of adopting `SuppressedAssociatedTypes` in sequence-primitives.

**Trigger**: Protocol's purpose requires ~Copyable element support; experiments confirmed capability and call-site transparency.

## Question

Should `Sequence.Protocol` adopt `SuppressedAssociatedTypes` to enable `~Copyable` elements, and if so, what is the migration path?

## Constraints

1. **Toolchain**: Swift 6.2.3 (Xcode 26 beta) — `SuppressedAssociatedTypes` available, `SuppressedAssociatedTypesWithDefaults` not available.
2. **stdlib**: `IteratorProtocol.Element` remains implicitly `Copyable` regardless of feature flag. A custom iterator protocol is required.
3. **Legacy flag semantics**: With `SuppressedAssociatedTypes`, `Element` is *always* `~Copyable` — no inference defaulting. Writing `where T.Element: ~Copyable` in extensions is an outer-scope error.
4. **`Optional` supports `~Copyable`**: `next() -> Element?` works for `~Copyable` elements. A custom iterator protocol can use the standard `next() -> Element?` pattern.
5. **Borrowing transparency**: `(borrowing T) -> U` closure parameters are transparent at call sites for `Copyable` T. No annotation, no syntax change. (Experiment: `two-tier-borrowing-overloads` V3/V4.)
6. **Downstream conformers**: 15+ buffer types, 3 heap types, 2 vector types, and all consumer packages.

## Analysis

### Option A: Adopt SuppressedAssociatedTypes Now

Enable the feature flag and change `associatedtype Element` to `associatedtype Element: ~Copyable`.

**Required changes**:

| Component | Change |
|-----------|--------|
| `Package.swift` | Add `.enableExperimentalFeature("SuppressedAssociatedTypes")` |
| `Sequence.Protocol` | `associatedtype Element: ~Copyable` |
| `Sequence.Iterator.Protocol` | Replace with custom protocol, `associatedtype Element: ~Copyable` |
| `Sequence.Protocol.Iterator` | Cannot use stdlib `IteratorProtocol` — need custom iterator protocol |
| `Sequence.Drain.Protocol` | `associatedtype Element: ~Copyable` |
| All unconstrained closure parameters | Add `borrowing` to `(Base.Element) -> T` parameters |
| Filter, Drop, Prefix extensions | Already constrain `Element: Copyable` — unchanged |
| All downstream packages | Add feature flag |

**Closure parameter impact** — declaration side only:

```swift
// BEFORE (Element implicitly Copyable)
public func callAsFunction(_ body: (Base.Element) -> Void)

// AFTER (Element always ~Copyable with legacy flag)
public func callAsFunction(_ body: (borrowing Base.Element) -> Void)
```

**Call-site impact** — none:

```swift
// BEFORE AND AFTER — identical call-site syntax
container.forEach { element in
    print(element)       // read: works
    let copy = element   // copy (Copyable): works
    takeInt(element)     // pass by value (Copyable): works
    print(element * 2)   // expression (Copyable): works
}
```

This is confirmed by experiment `two-tier-borrowing-overloads` variants 3 and 4.

**Affected Property.View extensions** (14 closure parameters across 8 files):

| File | Method(s) | Closures |
|------|-----------|----------|
| `Sequence.ForEach+Property.View.swift` | `callAsFunction`, `borrowing`, `consuming` | 3 |
| `Sequence.Map+Property.View.swift` | `callAsFunction` | 1 |
| `Sequence.Reduce+Property.View.swift` | `into`, `from` | 2 |
| `Sequence.Contains+Property.View.swift` | `callAsFunction` | 1 |
| `Sequence.Satisfies+Property.View.swift` | `all`, `any`, `none` | 3 |
| `Sequence.Count+Property.View.swift` | `where` | 1 |
| `Sequence.First+Property.View.swift` | `callAsFunction` | 1 |
| `Sequence.Span+Property.View.swift` | `elements` | 1 |

Extensions already constrained to `Element: Copyable` (Filter, Drop, Prefix) require no changes.

**Advantages**:
- Fulfills the protocol's stated purpose — `~Copyable` containers with `~Copyable` elements can conform
- Unifies the iteration model — no separate "~Copyable element" workarounds needed
- Available today (Swift 6.2.3)
- Makes `drain { }` pattern natively supported through the protocol
- Call-site syntax unchanged — `borrowing` is transparent for Copyable elements
- Custom iterator protocol can use `next() -> Element?` — Optional supports `~Copyable`

**Disadvantages**:
- **Experimental feature flag**: `SuppressedAssociatedTypes` is experimental — could change semantics or be removed.
- **Custom iterator protocol**: Cannot use stdlib `IteratorProtocol` — need parallel hierarchy.
- **Declaration-side changes**: All 14 unconstrained closure parameters need `borrowing` added.
- **Downstream feature flag**: All downstream packages must add the feature flag to their `Package.swift`.
- **No inference defaulting**: Extensions that want `Copyable` Element must add explicit `Element: Copyable` constraint. (Filter/Drop/Prefix already do this.)

### Option B: Wait for SuppressedAssociatedTypesWithDefaults

Defer until the `WithDefaults` variant is available in a released toolchain.

**What WithDefaults adds** (from the Swift Forums pitch and compiler source):

The key difference is **inference defaulting for primary associated types**. When a protocol declares `associatedtype Element: ~Copyable` as a primary associated type (in angle brackets), extensions and generic functions **infer `Element: Copyable` by default** unless explicitly suppressed:

```swift
// Protocol declaration
protocol Seq<Element>: ~Copyable {
    associatedtype Element: ~Copyable  // Declared ~Copyable
}

// Extension WITHOUT explicit suppression:
extension Seq {
    // Element is INFERRED as Copyable here!
    // Closures can take Element by value — implicit copy works.
    func forEach(_ body: (Element) -> Void) { ... }  // No `borrowing` needed
}

// Extension WITH explicit suppression:
extension Seq where Element: ~Copyable {
    // Element is genuinely ~Copyable here.
    // Must use `borrowing` or `consuming`.
    func forEach(_ body: (borrowing Element) -> Void) { ... }
}
```

**Ergonomic improvements over legacy flag**:

| Aspect | Legacy (`SuppressedAssociatedTypes`) | WithDefaults |
|--------|--------------------------------------|-------------|
| Element in plain extensions | Always ~Copyable | Defaults to Copyable |
| Declaration-side closures | Need `borrowing` everywhere | No annotation in default extensions |
| New Copyable-only operations | Must add `Element: Copyable` constraint | Automatic — just write the extension |
| Two-tier overloads | Single tier only (Element is always ~Copyable) | Natural: base extension + `~Copyable` extension |

**Concrete example** — ForEach with WithDefaults:

```swift
// Tier 1: Copyable Element (inferred default) — matches current API exactly
extension Property.View
where Base: Sequence.`Protocol` & ~Copyable, Tag == Sequence.ForEach {
    // Element inferred Copyable — implicit copy, no annotation
    public func callAsFunction(_ body: (Base.Element) -> Void) { ... }
}

// Tier 2: ~Copyable Element — new capability, opt-in
extension Property.View
where Base: Sequence.`Protocol` & ~Copyable, Tag == Sequence.ForEach,
      Base.Element: ~Copyable {
    // Element genuinely ~Copyable — must borrow
    public func callAsFunction(_ body: (borrowing Base.Element) -> Void) { ... }
}
```

This mirrors the existing two-tier overload pattern from [IMPL-025] — Copyable tier adds convenience (implicit copy), ~Copyable tier provides the general case.

**Additional WithDefaults ergonomics**:

1. **stdlib IteratorProtocol**: With `WithDefaults`, stdlib protocols themselves could adopt `~Copyable` associated types. This could eliminate the need for a custom iterator protocol entirely.
2. **No `borrowing` needed on Copyable tier**: Declaration-side closures in default extensions need no annotation.
3. **Gradual adoption**: Packages can adopt at their own pace. Copyable-element packages never need to change.

**Advantages**:
- Declaration-side closures cleaner (no `borrowing` in Copyable-element extensions)
- Natural two-tier overload pattern matching [IMPL-025]
- Potentially eliminates need for custom iterator protocol (if stdlib adopts)

**Disadvantages**:
- Not available in Swift 6.2.3 — timeline uncertain
- Requires development snapshot toolchain for testing
- Primary vs ordinary associated type distinction adds conceptual complexity
- **Blocks protocol from fulfilling its purpose until an uncertain future date**

### Option C: Parallel Protocol Hierarchy

Create a separate `Sequence.NoncopyableProtocol` with `~Copyable` Element, keeping `Sequence.Protocol` unchanged.

**Advantages**:
- No disruption to existing code
- Available today

**Disadvantages**:
- Duplicates the entire protocol + Property.View extension surface
- Violates DRY — 10+ Property.View files duplicated
- Two parallel hierarchies to maintain indefinitely
- Conformers must choose one or implement both
- Would be superseded by WithDefaults anyway

### Comparison

| Criterion | A: Adopt Now | B: Wait for WithDefaults | C: Parallel Hierarchy |
|-----------|-------------|-------------------------|----------------------|
| Available today | Yes | No | Yes |
| Call-site syntax | Unchanged | Unchanged | Unchanged |
| Declaration-side changes | 14 closures add `borrowing` | None initially | Duplication |
| Downstream packages | Add feature flag | None initially | No change |
| Maintenance cost | Low (one-time) | Low | Very high |
| Future WithDefaults migration | Remove `borrowing` from Copyable-tier closures | N/A | Delete parallel hierarchy |
| Fulfills protocol purpose | Yes | No (deferred) | Partially |
| stdlib compatibility | Need custom iterator | Potentially native | Need custom iterator |
| Experimental risk | Medium (flag may change) | Lower (more mature design) | Medium |

## Outcome

**Status**: DECISION

**Decision**: **Option A — Adopt `SuppressedAssociatedTypes` now.**

**Rationale**:

1. **The protocol's purpose demands it**: `Sequence.Protocol` was created specifically to support `~Copyable` types. Currently it supports `~Copyable` containers but not `~Copyable` elements — an incomplete realization. Every day without `Element: ~Copyable` is a day the protocol fails to serve its stated purpose.

2. **Borrowing is transparent**: The `two-tier-borrowing-overloads` experiment proved that `(borrowing Base.Element) -> Void` is indistinguishable from `(Base.Element) -> Void` at call sites for Copyable elements. No caller syntax changes. The "call-site friction" concern was empirically refuted.

3. **The migration is small and one-directional**: 14 closure parameters across 8 files gain `borrowing`. This is a one-time, mechanical change. When `WithDefaults` arrives, the improvement is to *remove* `borrowing` from Copyable-tier closures — an ergonomic gain, not a breaking change. There is no "second migration wave."

4. **Custom iterator is acceptable**: The need for a custom iterator protocol is a real cost, but it's the same cost regardless of timing. `IteratorProtocol.Element` won't gain `~Copyable` until the stdlib itself adopts suppressed associated types, which is independent of our decision.

5. **Closure-based iteration is the primary model**: `Sequence.Protocol` already uses closure-based iteration (`forEach`, `drain`, `map`, `reduce`), not `for-in` loops. The closure model is the natural fit for `~Copyable` elements — each closure either borrows or consumes the element. No iterator return-type awkwardness.

**Migration path**:

| Step | Change | Files |
|------|--------|-------|
| 1 | Add feature flag to `Package.swift` | 1 |
| 2 | Define custom `Sequence.Iterator.Protocol` with `Element: ~Copyable` | 1 (new or modify existing) |
| 3 | Change `Sequence.Protocol` associated types | 1 |
| 4 | Change `Sequence.Drain.Protocol` associated type | 1 |
| 5 | Add `borrowing` to unconstrained closure parameters | 8 |
| 6 | Update downstream `Package.swift` files with feature flag | Per-package |

**When WithDefaults becomes available** (future improvement, not a blocker):

1. Switch feature flag from `SuppressedAssociatedTypes` to `SuppressedAssociatedTypesWithDefaults`
2. Split extensions into Copyable-default tier (remove `borrowing`) and `~Copyable` tier (keep `borrowing`)
3. Downstream packages with Copyable-only elements: no change needed
4. If stdlib adopts: replace custom iterator protocol with `IteratorProtocol`

## References

- [SE-0427: Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) — deferred ~Copyable on associated types
- [Swift Forums: Suppressed Associated Types With Defaults](https://forums.swift.org/t/pitch-suppressed-associated-types-with-defaults/83663) — pitch for inference defaulting
- Experiment: `swift-sequence-primitives/Experiments/suppressed-associated-types/` — feature flag validation
- Experiment: `swift-sequence-primitives/Experiments/two-tier-borrowing-overloads/` — borrowing transparency and two-tier overloads
- Compiler source: `swift/include/swift/Basic/Features.def:460-464` — both feature flag definitions
- Compiler source: `swift/lib/AST/RequirementMachine/ApplyInverses.cpp:56-58` — feature gate
- Compiler source: `swift/lib/Frontend/CompilerInvocation.cpp:1389-1394` — mutual exclusion logic
