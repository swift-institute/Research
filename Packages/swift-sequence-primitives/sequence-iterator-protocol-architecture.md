# Sequence and Iterator Protocol Architecture for ~Copyable Elements

<!--
---
version: 1.2.0
last_updated: 2026-02-26
status: RECOMMENDATION
tier: 2
---
-->

## 1. Context and Scope

### Problem

`Sequence.Protocol` was created to support `~Copyable` containers where the standard library's `Sequence` protocol cannot (stdlib requires `Copyable` conformers and elements). The protocol needed to evolve to also support `~Copyable` *elements* — and this evolution triggered a chain of design decisions about protocol shape, iterator primitives, ownership conventions, and unification feasibility.

### Five Call-Site Patterns

The sequence primitives architecture serves five distinct iteration patterns, each with different ownership semantics:

| Pattern | Requires | Ownership | Container After |
|---------|----------|-----------|-----------------|
| `.forEach { }` | `Sequence.Protocol` | Borrowing | Unchanged |
| `.forEach.borrowing { }` | `Sequence.Protocol` | Borrowing | Unchanged |
| `.forEach.consuming { }` | `Sequence.Clearable` | Iterates, then clears | Empty, usable |
| `.drain { }` | `Sequence.Drain.Protocol` | Consuming (per element) | Empty, usable |
| `.consume().forEach { }` | `Sequence.Consume.Protocol` | Consuming (container destroyed) | Destroyed |

### Research Chain

This document consolidates seven research documents that form a dependency chain:

| # | Document | Version | Status at Consolidation | Built On |
|---|----------|---------|------------------------|----------|
| 1 | `sequence-protocol-noncopyable-elements.md` | 2.0.0 | DECISION | — |
| 2 | `iterator-protocol-hierarchy.md` | 1.0.0 | DECISION (partially superseded by #7) | #1 |
| 3 | `sequence-protocol-surface-simplification.md` | 1.1.0 | DECISION | #1, #2 |
| 4 | `sequence-iterator-borrowing-primitive.md` | 1.0.0 | RECOMMENDATION (fully superseded by #7) | #1, #2, #3 |
| 5 | `consuming-vs-borrowing-iteration.md` | 2.0.0 | DECISION | #1, #2, #3 |
| 6 | `ownership-witness-thunking-protocol-conformance.md` | 1.0.0 | DECISION | #5 |
| 7 | `sequence-protocol-unification-feasibility.md` | 2.1.0 | RECOMMENDATION | #1–#6 |

---

## 2. ~Copyable Element Support

**Status**: DECISION — Adopt `SuppressedAssociatedTypes` now.

### Decision

Enable the `SuppressedAssociatedTypes` feature flag and change all sequence protocol associated types from `associatedtype Element` to `associatedtype Element: ~Copyable`.

### Background

`Sequence.Protocol` originally declared `associatedtype Element` without `~Copyable` suppression, meaning all conformers must have `Copyable` elements. The protocol's stated purpose is to support `~Copyable` containers — but without `~Copyable` elements, this is an incomplete realization. A `~Copyable` container with `~Copyable` elements cannot conform.

### Feature Flag Mechanics

The `SuppressedAssociatedTypes` feature flag is available in Swift 6.2.3:

- **Compiler source**: `swift/include/swift/Basic/Features.def:460-464` — both feature flag definitions
- **Feature gate**: `swift/lib/AST/RequirementMachine/ApplyInverses.cpp:56-58`
- **Mutual exclusion**: `swift/lib/Frontend/CompilerInvocation.cpp:1389-1394` — `SuppressedAssociatedTypes` and `SuppressedAssociatedTypesWithDefaults` are mutually exclusive

**Legacy flag semantics**: With `SuppressedAssociatedTypes`, `Element` is *always* `~Copyable` — no inference defaulting. Writing `where T.Element: ~Copyable` in extensions is an outer-scope error.

### Key Enabling Findings

1. **Optional supports ~Copyable**: `next() -> Element?` works for `~Copyable` elements. No custom return type needed for iterators.

2. **Borrowing transparency**: `(borrowing T) -> U` closure parameters are transparent at call sites for `Copyable` T. No annotation, no syntax change. Confirmed by experiment `two-tier-borrowing-overloads` variants 3 and 4:

```swift
// Call sites are IDENTICAL before and after
container.forEach { element in
    print(element)       // read: works
    let copy = element   // copy (Copyable): works
    takeInt(element)     // pass by value (Copyable): works
    print(element * 2)   // expression (Copyable): works
}
```

### Required Changes

| Component | Change |
|-----------|--------|
| `Package.swift` | Add `.enableExperimentalFeature("SuppressedAssociatedTypes")` |
| `Sequence.Protocol` | `associatedtype Element: ~Copyable` |
| `Sequence.Iterator.Protocol` | Replace with custom protocol, `associatedtype Element: ~Copyable` |
| `Sequence.Drain.Protocol` | `associatedtype Element: ~Copyable` |
| All unconstrained closure parameters | Add `borrowing` to `(Base.Element) -> T` parameters |
| Filter, Drop, Prefix extensions | Already constrain `Element: Copyable` — unchanged |
| All downstream packages | Add feature flag |

**Closure parameter impact** — declaration side only (14 closures across 8 files):

```swift
// BEFORE (Element implicitly Copyable)
public func callAsFunction(_ body: (Base.Element) -> Void)

// AFTER (Element always ~Copyable with legacy flag)
public func callAsFunction(_ body: (borrowing Base.Element) -> Void)
```

**Affected Property.View extensions**:

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

### Options Considered

| Criterion | A: Adopt Now | B: Wait for WithDefaults | C: Parallel Hierarchy |
|-----------|-------------|-------------------------|----------------------|
| Available today | Yes | No | Yes |
| Call-site syntax | Unchanged | Unchanged | Unchanged |
| Declaration-side changes | 14 closures add `borrowing` | None initially | Duplication |
| Downstream packages | Add feature flag | None initially | No change |
| Maintenance cost | Low (one-time) | Low | Very high |
| Fulfills protocol purpose | Yes | No (deferred) | Partially |
| stdlib compatibility | Need custom iterator | Potentially native | Need custom iterator |
| Experimental risk | Medium (flag may change) | Lower (more mature design) | Medium |

### Rationale

1. **The protocol's purpose demands it**: Every day without `Element: ~Copyable` is a day the protocol fails to serve its stated purpose.

2. **Borrowing is transparent**: Empirically refuted the "call-site friction" concern.

3. **The migration is small and one-directional**: 14 closure parameters across 8 files gain `borrowing`. When `WithDefaults` arrives, the improvement is to *remove* `borrowing` from Copyable-tier closures — an ergonomic gain, not a breaking change.

4. **Custom iterator is acceptable**: `IteratorProtocol.Element` won't gain `~Copyable` until the stdlib itself adopts suppressed associated types, independent of our decision.

5. **Closure-based iteration is the primary model**: `forEach`, `drain`, `map`, `reduce` — all use closures. The closure model naturally fits `~Copyable` elements (each closure either borrows or consumes the element).

### WithDefaults Future Migration Path

When `SuppressedAssociatedTypesWithDefaults` (SE-0503, accepted) becomes available in a released toolchain:

1. Switch feature flag from `SuppressedAssociatedTypes` to `SuppressedAssociatedTypesWithDefaults`
2. Split extensions into Copyable-default tier (remove `borrowing`) and `~Copyable` tier (keep `borrowing`)
3. Downstream packages with Copyable-only elements: no change needed
4. If stdlib adopts: replace custom iterator protocol with `IteratorProtocol`

**What WithDefaults adds**: inference defaulting for primary associated types. When a protocol declares `associatedtype Element: ~Copyable` as a primary associated type (in angle brackets), extensions **infer `Element: Copyable` by default** unless explicitly suppressed with `where Element: ~Copyable`:

```swift
// Extension WITHOUT explicit suppression:
extension Seq {
    // Element is INFERRED as Copyable — closures need no `borrowing`
    func forEach(_ body: (Element) -> Void) { ... }
}

// Extension WITH explicit suppression:
extension Seq where Element: ~Copyable {
    // Element is genuinely ~Copyable — must use `borrowing`
    func forEach(_ body: (borrowing Element) -> Void) { ... }
}
```

---

## 3. Sequence Protocol Surface

**Status**: DECISION — Keep all six protocols. The protocol surface cannot be simplified.

### Decision

All six sequence-related protocols remain. The `~Copyable` element adoption expanded what each protocol can express, but the protocols were separated by ownership semantics, not by `Copyable` limitations.

### The Six Protocols

| Protocol | Inherits From | Self | Element | Core Method |
|----------|---------------|------|---------|-------------|
| `Sequence.Protocol` | — | `~Copyable` | `~Copyable` | `makeIterator() -> Iterator` |
| `Sequence.Borrowing.Protocol` | — | `~Copyable, ~Escapable` | `~Copyable` | `makeIterator() -> Iterator` (span-based) |
| `Sequence.Drain.Protocol` | — | `~Copyable` | `~Copyable` | `drain(_ body: (consuming Element) -> Void)` |
| `Sequence.Clearable` | `Sequence.Protocol` | `~Copyable` | `~Copyable` | `removeAll()` |
| `Sequence.Consume.Protocol` | — | `~Copyable` | (Copyable) | `consume() -> View<Element, State>` |
| `Sequence.Iterator.Protocol` | — | `~Copyable` | `~Copyable` | `next() -> Element?` |

### 13 Types Conforming to Drain WITHOUT Sequence.Protocol

Buffer.Slab (4 types), Buffer.Arena (2 types), Set.Ordered (4 types), Slab (3 types) — these types support draining but have no iterator. They cannot conform to `Sequence.Protocol`.

### Core Insight

The separation is by ownership semantics, not Copyable limitations:

| Question | Protocol |
|----------|----------|
| Does it have an iterator? | `Sequence.Protocol` |
| Can elements be moved out? | `Drain.Protocol` |
| Can the storage be cleared? | `Clearable` |
| Can the container be destroyed? | `Consume.Protocol` |
| Does it provide span-based access? | `Borrowing.Protocol` |

These are orthogonal capabilities. Supporting `~Copyable` elements in all of them makes each protocol more powerful, but does not make any protocol a subset of another.

### Options Ruled Out

| Option | Why Ruled Out |
|--------|--------------|
| A: Merge Drain → Sequence | 13 types break; no default `drain` for ~Copyable elements; not all sequences are drainable |
| B: Merge Clearable → Sequence | Not all sequences have storage to clear; 35+ forced stubs |
| C: Drain refines Sequence | Same 13 types break |
| D: Sequence refines Drain | Reverses conceptual hierarchy; read-only sequences forced to drain |
| E: Consume merges into Drain | Different ownership of `self` (`mutating` vs `consuming`); different cleanup semantics |

### Gap: Sequence.Consume.Protocol.Element

`Sequence.Consume.Protocol.Element` currently lacks `~Copyable` suppression (`associatedtype Element` without `: ~Copyable`). This should be updated for consistency — but this is an expansion of capability, not a simplification of the protocol surface.

### v1.1.0 Reframing: Sequence.Borrowing.Protocol

The decision to detach `Collection.Protocol` from `Sequence.Protocol` (see `swift-primitives/Research/collection-sequence-protocol-detachment.md`, RECOMMENDATION, 2026-02-23) changed the role of `Sequence.Borrowing.Protocol`:

- **Before**: The primary mechanism for borrowing iteration over collections with `~Copyable` elements.
- **After**: A chunked span access optimization over `Span.Protocol`, NOT a borrowing iteration mechanism. Borrowing iteration is now handled by `Collection.Protocol` via index/subscript (`Collection.ForEach`).

Deletion deferred pending audit of bounded-chunk usage (all current call sites pass `Cardinal(UInt.max)`).

---

## 4. Consuming vs Borrowing Iterator Creation

**Status**: DECISION — Dual-protocol (consuming vs borrowing makeIterator).

### Decision

`Sequence.Protocol` uses `consuming func makeIterator()` for lazy pipeline composition. `Sequence.Borrowing.Protocol` uses `borrowing func makeIterator()` for `~Copyable` container iteration. This mirrors the Swift stdlib's dual-protocol architecture exactly (`Sequence` / `_BorrowingSequence`).

### Stdlib Dual-Protocol Architecture

| Protocol | Ownership | Iterator | Elements | Source |
|----------|-----------|----------|----------|--------|
| `Sequence` | `__consuming func makeIterator()` | Copyable | Single via `next()` | `stdlib/public/core/Sequence.swift:325-346` |
| `_BorrowingSequence` | `borrowing func _makeBorrowingIterator()` | `~Copyable & ~Escapable` | `Span<Element>` chunks | `stdlib/public/core/BorrowingSequence.swift:51-62` |

Critical stdlib observations:
1. The stdlib does NOT add `forEach` as a protocol requirement
2. `forEach` is an extension method that uses `for-in` (which calls consuming `makeIterator`)
3. `_BorrowingSequence` is entirely separate — different method names, different iterator protocol
4. `Span` conforms to `_BorrowingSequence`, using mutation-based extraction (`_nextSpan`)

### Vector Primitives Triple-Iteration Architecture

Vector uses a triple-iteration architecture:
1. `Sequence.Protocol` conformance — `borrowing func makeIterator()` (pre-change)
2. `Property<ForEach, Self>` (owned) — borrowing forEach via index-based traversal
3. `Property<Drain, Self>.View` (pointer-based) — consuming iteration

Vector is Copyable (stores domain + transform), so consuming makeIterator works via implicit copy. Its forEach does NOT go through makeIterator — it uses internal index-based traversal directly.

### Type-Theoretic Grounding

The tension maps to substructural type systems:

- **Consuming iteration** = linear/affine resource use. The sequence is consumed exactly once to produce an iterator stream. Correct for single-pass sequences.
- **Borrowing iteration** = relevant/unrestricted resource use. The sequence is observed without destruction. Correct for re-iterable collections.

A single protocol cannot serve both without a copying escape hatch (which ~Copyable types lack by definition).

### Options Analyzed

| Criterion | A (forEach req) | B (Copyable PView) | C (Dual-protocol) | D (Clearable) |
|-----------|----------------|--------------------|--------------------|---------------|
| Stdlib alignment | Poor | Good | **Best** | Poor |
| ~Copyable support | Yes | No | **Yes** | Partial |
| Semantic correctness | Mixed | Clean | **Cleanest** | Narrow |

**Option A**: Add `borrowing func forEach(...)` as protocol requirement — confirmed by experiment `property-view-consuming-iterator` TEST A. But no stdlib precedent (forEach is extension, not requirement), conflates two iteration modes.

**Option B**: Property.View requires Copyable (drop `& ~Copyable`) — confirmed by experiment TEST 1. But ~Copyable conformers lose forEach via Property.View.

**Option C (chosen)**: Dual-protocol. Element-by-element Property.View extensions constrain to `Sequence.Protocol` (Copyable bases). Span-based Property.View extensions constrain to `Sequence.Borrowing.Protocol & ~Copyable`.

**Option D**: Consuming move + reinitialize for Clearable types — confirmed by experiment TEST E. But limited to types with `init()`.

### Doc 7 Reframing

> **With `nextSpan` as the universal primitive, the two sequence protocols are not "consuming vs borrowing iteration" — they are "consuming vs borrowing iterator CREATION." The iteration model is unified: all iterators lend elements via Span. The only divergence is how the iterator is created.**

The remaining separation is not about two ways of iterating. It is about two ways of producing an iterator — the irreducible consequence of ~Copyable ownership semantics.

---

## 5. Witness Thunking for Ownership Bridging

**Status**: DECISION — Witness thunking is architecturally correct.

### Decision

The ownership mismatch between protocol requirement (`consuming`) and Copyable conformers (`borrowing`) is architecturally correct and should be preserved with explicit documentation. Conformers SHOULD NOT be changed to `consuming`.

### SILGen 4-Stage Pipeline

When a protocol requires `consuming` but a conformer provides `borrowing`, the compiler generates a witness thunk:

1. **Witness table construction** (`SILGenType.cpp:641-683`): `addMethodImplementation()` pairs requirements with witnesses.

2. **Thunk creation** (`SILGenType.cpp:733-924`): `emitProtocolWitness()` creates the thunk function. The thunk's type matches the **requirement's** abstraction, not the witness's.

3. **Argument forwarding** (`SILGenPoly.cpp:2959-3000`): `forwardFunctionArguments()` converts arguments from requirement convention to witness convention. When the witness expects `Direct_Guaranteed` (borrowing) but receives `Direct_Owned` (consuming), it calls `ensurePlusOne()`.

4. **Copy injection** (`ManagedValue.cpp:289-299`): `ensurePlusOne()` checks if the value is already +1. If not, it calls `copy()` which emits a `copy_value` SIL instruction — one reference count increment for reference types, a full value copy for value types.

### SIL Pseudocode

For `Buffer.Linear.makeIterator()`:

```
// Witness thunk: adapts borrowing witness to consuming requirement
sil @witness_thunk_makeIterator :
    $@convention(witness_method) (@owned Buffer.Linear) -> @owned Iterator {
bb0(%0 : $Buffer.Linear):
  %1 = copy_value %0             // bridge: owned → guaranteed
  %2 = begin_borrow %1
  %3 = function_ref @borrowing_makeIterator
  %4 = apply %3(%2)              // call borrowing impl
  end_borrow %2
  destroy_value %1               // destroy the copy
  destroy_value %0               // consume the original (protocol contract)
  return %4
}
```

### Downstream Conformer Inventory

| Category | Count | Pattern |
|----------|-------|---------|
| Copyable, direct pointer/index | 15+ | `borrowing func makeIterator()` — zero-copy |
| Copyable, snapshot-based | 8+ | `borrowing func makeIterator()` — O(n) snapshot for inline storage |
| ~Copyable wrapper (lazy types) | 7 | `consuming func makeIterator()` — ownership transfer |
| Dual-protocol (Sequence + Borrowing) | 6 | `borrowing func makeIterator()` — satisfies both |

Representative conformers:
- **Buffer.Linear** (`Buffer.Linear+Span.swift:48`): Conforms to BOTH `Sequence.Protocol` and `Sequence.Borrowing.Protocol` with a single `borrowing func makeIterator()`.
- **Stack.Small** (`Stack.Small Copyable.swift:71`): Creates O(n) snapshot for safe iteration of inline storage. Still `borrowing` — the snapshot is independent, self is not consumed.
- **Sequence.Map** (`Sequence.Map.Iterator.swift:24`): The ONLY conformer using `consuming func makeIterator()`. Wraps `~Copyable & ~Escapable` base, must transfer ownership.

### Type-Theoretic Grounding: Ownership as Subtyping

In substructural type systems (Walker 2004), for Copyable types:

```
borrowing  ≤  consuming    (for Copyable types)
```

`borrowing` is a submode of `consuming` because any Copyable value can be copied to satisfy a consuming demand. This is the **contraction rule**: a resource that may be used multiple times (Copyable) can always be used exactly once (consuming) by simply copying first.

For ~Copyable types, the modes are **incomparable** — there is no contraction rule. The compiler correctly rejects this.

### The Convention

> **Protocol ownership requirements declare the maximum ownership a caller may demand. Conformers declare the minimum ownership they need. For Copyable types, the compiler bridges the gap via witness thunks. This is the contraction rule from substructural type theory applied to Swift's ownership system.**

- Copyable conformers SHOULD use `borrowing func makeIterator()` — semantically correct for types that do not transfer ownership.
- ~Copyable conformers MUST use `consuming func makeIterator()` — the compiler enforces this; there is no bridge without the contraction rule.

### Cognitive Dimensions Analysis

| Dimension | Keep (chosen) | Update to Consuming | Document + Keep |
|-----------|---------------|--------------------|----- |
| Visibility | Low (mismatch hidden) | High | **High** |
| Consistency | Apparently inconsistent | Consistent | Documented inconsistency |
| Viscosity | Zero changes | Very high (35+ files) | **Low** |
| Role-expressiveness | High (`borrowing` is truthful) | Low (`consuming` lies) | **High** |
| Error-proneness | Low | Medium | **Low** |

### Rust Comparison

Rust traits require exact signature match — no implicit thunking:

```rust
trait Iterator {
    fn next(&mut self) -> Option<Self::Item>;  // exact match required
}
```

A Rust impl with a different receiver convention is a compile error. More explicit but more boilerplate. Swift's implicit bridging is more ergonomic but potentially surprising.

### Why Option B (Update All Conformers to Consuming) Is Fatal

Changing all 35+ conformers from `borrowing` to `consuming` would:

1. **Semantically lie** — collections borrow, they don't transfer ownership
2. **Break dual-protocol conformance** — `Buffer.Linear` conforms to both `Sequence.Protocol` (now consuming) and `Sequence.Borrowing.Protocol` (borrowing). A single `consuming` cannot satisfy both. The compiler would need to thunk in the opposite direction (consuming → borrowing), which is semantically wrong — you cannot borrow from a consumed value.

### Specification Status

| Aspect | Status |
|--------|--------|
| Swift Evolution proposal | None |
| Compiler diagnostics | None emitted |
| Location in compiler | SILGen (not type checker) |
| Stability | Used implicitly throughout stdlib; deeply embedded |
| ~Copyable behavior | Correctly rejected (cannot synthesize copy) |

---

## 6. Iterator Protocol Architecture

This section traces the reasoning chain from the initial parallel design through an intermediate proposal to the current recommendation.

### 6.1 Initial Parallel Design

**Status**: DECISION, now partially SUPERSEDED by Section 6.3.

The decision that iterator protocols should be parallel (not refinement) remains correct. What changed is that the two parallel protocols can now be *unified* into one.

#### The Three Iterator Protocols (at time of analysis)

| Protocol | Method | Yields | Self | Element |
|----------|--------|--------|------|---------|
| `Sequence.Iterator.Protocol` | `next() -> Element?` | Owned element | `~Copyable` | `~Copyable` |
| `Sequence.Iterator.Borrowing.Protocol` | `nextSpan(maximumCount:) -> Span<Element>` | Borrowed span | `~Copyable, ~Escapable` | `~Copyable` |
| `IteratorProtocol` (stdlib) | `next() -> Element?` | Owned element | `Copyable` | `Copyable` |

None of these protocols refined each other. They were three independent protocols with no inheritance relationship.

#### Concrete Iterator Type Inventory

| Iterator | `Sequence.Iterator.Protocol` | `Sequence.Iterator.Borrowing.Protocol` | `IteratorProtocol` | Escapable? |
|----------|------------------------------|---------------------------------------|-------------------|-----------|
| Buffer.Linear.Iterator | needed | yes | yes | yes |
| Buffer.Ring.Iterator | needed | yes | yes | yes |
| Buffer.Linked.Iterator | needed | no | yes | yes |
| Vector.Iterator | needed | no | yes (conditional) | yes (conditional) |
| Swift.Span.Iterator | no | no | no | **no** (~Escapable) |
| Swift.Span.Iterator.Batch | no | yes | no | **no** (~Escapable) |

#### Options B–F Ruled Out

**Option B: Borrowing Refines Non-Borrowing** — Ruled out by Escapable conflict and forced `next()` on batch iterators. `Sequence.Iterator.Protocol` does not suppress `~Escapable`; the parent's requirement wins, forcing all conformers Escapable. `Swift.Span.Iterator.Batch` (which is `~Escapable`) could no longer conform. Additionally, batch iterators deliberately do NOT provide `next()`.

**Option C: Add ~Escapable to Base Iterator Protocol** — Cascades into `Sequence.Protocol` requiring `@_lifetime(borrow self)` on `makeIterator()`. Overly permissive for element-at-a-time iterators. Still forces `next()` on batch iterators.

**Option D: Keep IteratorProtocol** — Same-type constraint `where Iterator.Element == Element` propagates `Copyable` from `IteratorProtocol.Element`, overriding the `~Copyable` suppression.

**Option E: Remove Same-Type Constraint** — `Element` and `Iterator.Element` become unrelated types. Breaks Property.View extensions.

**Option F: Remove Iterator Associated Type Entirely** — Eliminates composability. Algorithms like `map`, `reduce`, `first` need to control iteration flow.

#### Supersession Note

Both blockers that led to the parallel design have been resolved:
1. **Escapable conflict**: Both iterator protocols have since been updated to `~Copyable, ~Escapable`.
2. **Batch iterators lack `next()`**: With `nextSpan` as the universal primitive, `next()` becomes a derived convenience, NOT a protocol requirement. Batch iterators conform naturally.

See Section 6.3 for the unified design.

### 6.2 The withNext Intermediate

**Status**: RECOMMENDATION, now fully SUPERSEDED by Section 6.3.

This section documents the `withNext` closure-based lending proposal — important as prior art and for its experimental findings, but superseded by the `~Escapable` correction.

#### Prior Art Survey

| Source | Status | Relevance |
|--------|--------|-----------|
| [SE-0437: Noncopyable Stdlib Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) | Accepted | Makes `Optional<~Copyable>` work but defers `Sequence`/`IteratorProtocol` generalization |
| [SE-0499: ~Copyable in Simple Stdlib Protocols](https://forums.swift.org/t/accepted-with-modifications-se-0499-support-copyable-escapable-in-simple-standard-library-protocols/83754) | Accepted | Generalizes `Equatable`, `Hashable`, etc. Does NOT cover `IteratorProtocol`/`Sequence` |
| [SE-0503: Suppressed Associated Types With Defaults](https://forums.swift.org/t/accepted-se-0503-suppressed-default-conformances-on-associated-types-with-defaults/84774) | Accepted | Enables `associatedtype Element: ~Copyable` in stdlib protocols |
| [[Pitch] Borrowing Sequence](https://forums.swift.org/t/pitch-borrowing-sequence/84332) | Pitch (pre-review) | Proposes `BorrowingIteratorProtocol` with `nextSpan(maximumCount:)`. Plans to reparent `Sequence` on `BorrowingSequence` |
| [Rust `LendingIterator`](https://docs.rs/lending-iterator/latest/lending_iterator/trait.LendingIterator.html) | Library | GAT-based lending with lifetime-tied items |
| [Niko Matsakis: Giving, Lending, and Async Closures](https://smallcultfollowing.com/babysteps/blog/2023/05/09/giving-lending-and-async-closures/) | Blog | Giving vs lending trait taxonomy |
| [GAT Initiative: Iterable Pattern](https://rust-lang.github.io/generic-associated-types-initiative/design_patterns/iterable.html) | Design pattern | Lending at the sequence level via lifetime-parameterized associated types |

**Rust giving vs lending**:

| Pattern | Rust Term | Items | Can hold multiple? | Algorithm composition |
|---------|-----------|-------|---------------------|----------------------|
| **Giving** | `Iterator` | Owned, independent of `self` | Yes | Full (`collect`, `zip`, `take_two`) |
| **Lending** | `LendingIterator` | Borrowed from `self` | No | Limited (no `collect`, no multi-element) |

Swift has no GATs, so lending must use either `Span` (the stdlib approach) or closures (the `withNext` proposal).

#### The 8 Constraints

| # | Constraint | Impact |
|---|-----------|--------|
| 1 | `next() -> Element?` is a **giving** primitive | For ~Copyable elements, this is a destructive move out of storage |
| 2 | `nextSpan() -> Span<Element>` requires `~Escapable` | Cascades `~Escapable` and `@_lifetime` into all iterators and sequences |
| 3 | Batch iterators (`Span.Iterator.Batch`) have no `next()` | Any refinement that forces `next()` on batch iterators is ruled out |
| 4 | Swift has no GATs | Cannot express `type Item<'self>` — must use closures or Span for lending |
| 5 | `borrowing` closure params are transparent for Copyable | Proven by experiment — no call-site impact |
| 6 | `Sequence.Drain.Protocol` handles consuming iteration | Consuming moves belong to drain, not the base iteration primitive |
| 7 | 13 types conform to Drain without Sequence.Protocol | Consuming iteration is genuinely a separate capability |
| 8 | Closure-based iteration is the primary call-site model | `forEach`, `map`, `reduce`, `contains` — all use closures already |

#### The withNext Proposal

```swift
extension Sequence.Iterator {
    public protocol `Protocol`: ~Copyable {
        associatedtype Element: ~Copyable
        mutating func withNext<R>(_ body: (borrowing Element) -> R) -> R?
    }
}
```

Default `next()` for Copyable elements:
```swift
extension Sequence.Iterator.`Protocol` where Self: ~Copyable, Element: Copyable {
    public mutating func next() -> Element? {
        withNext { $0 }  // implicit copy
    }
}
```

#### Algorithm Composition via withNext

```swift
// forEach
while let _ = iterator.withNext({ body($0) }) { }

// contains(where:)
while let found = iterator.withNext({ predicate($0) }) {
    if found { return true }
}

// reduce(into:_:)
while let _ = iterator.withNext({ combine(&result, $0) }) { }

// map (Copyable elements — copies out)
while let transformed = iterator.withNext({ transform($0) }) {
    result.append(transformed)
}

// first (Copyable elements only)
return iterator.withNext { $0 }
```

#### 5 Options Analyzed

| Criterion | A: `next()` | B: `nextSpan` | C: `withNext` | D: Full ~Escapable | E: Dual |
|-----------|:-----------:|:-------------:|:-------------:|:------------------:|:-------:|
| Works for ~Copyable elements | Move (destructive) | Borrow (in-place) | **Borrow (in-place)** | Borrow (in-place) | Both |
| ~Escapable required | No | **Yes** | **No** | **Yes** | No |
| Non-contiguous storage | Native | Needs buffering | **Native** | Needs buffering | Native |
| Derives `next()` for Copyable | N/A (is `next()`) | Yes | **Yes** | Yes | Explicit |
| Unifies with Borrowing.Protocol | No | **Yes** | No (batch separate) | **Yes** | No |
| Stdlib alignment | Current stdlib | [Pitch] direction | Novel | Future stdlib | Novel |

#### Experimental Validation (13 tests, CONFIRMED)

Experiment: `Experiments/borrowing-iterator-primitive/`

| Risk | Concern | Result |
|------|---------|--------|
| `withNext<R>` in `~Copyable` protocol | Generic method with `(borrowing Element)` where `Element: ~Copyable` | **CONFIRMED** |
| `next()` default derivation | `withNext { $0 }` implicit copy for `Element: Copyable` | **CONFIRMED** |
| Algorithm composition | `forEach`, `contains`, `reduce`, `map`, `count` via `withNext` | **CONFIRMED** |
| ~Copyable container + elements | `NoncopyableBuffer` with `UniqueResource` elements | **CONFIRMED** |
| Multiple iteration | Container survives multiple `forEach` passes | **CONFIRMED** |
| Closure inlining | `@inlinable` `withNext` with closure | **DEFERRED** (needs benchmark) |

**Key implementation findings**:

1. **`associatedtype Iterator: IteratorProtocol & ~Copyable`** is required — without `& ~Copyable` suppression on the associated type, ~Copyable iterators cannot satisfy the protocol witness.

2. **Borrowing operators** (`$0 == 3`, `acc += elem`) in shorthand closures have inference issues with `borrowing` parameters. Resolved by using explicit closure bodies with intermediate `let val = element` copies (for Copyable) or field access (for ~Copyable).

3. **`(ptr + index).pointee`** in `withNext` for raw pointer storage passes the pointee as a borrowed value to the closure. The element is NOT moved — it stays in the buffer.

#### Supersession Note

`withNext` is a `with*`-pattern closure — the pre-`~Escapable` mechanism for scoping borrows. `~Escapable` was designed to replace `with*` patterns with direct values. The correct primitive is `nextSpan`, which returns a `~Escapable` value whose lifetime the compiler tracks. See Section 6.3.

### 6.3 nextSpan as Universal Primitive

**Status**: RECOMMENDATION, CURRENT.

#### The Critical Insight: ~Escapable Replaces with* Patterns

The stdlib demonstrates a clear pattern:

| Before `~Escapable` | After `~Escapable` |
|----------------------|--------------------|
| `withUnsafeBufferPointer { ptr in ... }` | `var span = container.span` |
| `withContiguousMutableStorageIfAvailable { ... }` | `var mutableSpan = container.mutableSpan` |
| `withUnsafeBytes { raw in ... }` | `var rawSpan = container.rawSpan` |

By the same principle:

| Before `~Escapable` | After `~Escapable` |
|----------------------|--------------------|
| `withNext { element in ... }` | `let span = iterator.nextSpan(...)` |

`withNext<R>(_ body: (borrowing Element) -> R) -> R?` scopes a borrow through a closure. `nextSpan(maximumCount:) -> Span<Element>` returns a `~Escapable` value whose lifetime the compiler tracks. The latter is the correct design in a language with `~Escapable`.

#### Stdlib Reparenting Attempt + Revert

The Swift stdlib team attempted to reparent `Sequence` on `BorrowingSequence`:

- **Pitch**: [Borrowing Sequence](https://forums.swift.org/t/pitch-borrowing-sequence/84332)
- **Implementation + revert**: Commit `de749cea18f` — "Don't reparent Sequence with BorrowingSequence"
- **Reasons**: Conditional conformance issues, source compatibility, Escapable conflicts when requiring ALL Sequence conformers to become BorrowingSequence conformers.

**Key distinction from our situation**: The stdlib's problem was about making `Sequence` *refine* `BorrowingSequence`. Our question is different: can we unify the *iterator* protocols while keeping the sequence protocols separate? The stdlib's barriers don't apply to iterator-level unification.

#### Both Blockers from Section 6.1 Resolved

1. **Escapable conflict**: Both iterator protocols have since been updated to `~Copyable, ~Escapable`. The blocker no longer applies.

2. **Batch iterators lack `next()`**: With `nextSpan` as the universal primitive, `next()` becomes a derived convenience, NOT a protocol requirement. Batch iterators conform naturally because they implement `nextSpan` directly.

#### 3 Blockers to FULL Sequence Protocol Unification (Irreducible)

**Blocker 1: makeIterator() Ownership Divergence.** `Sequence.Protocol` requires `consuming func makeIterator()` for lazy pipelines. `Sequence.Borrowing.Protocol` requires `borrowing func makeIterator()` with `@_lifetime(borrow self)`. For ~Copyable types, no bridge exists.

**Blocker 2: Lifetime Annotation Divergence.** `Sequence.Protocol` needs `@_lifetime(copy self)` (iterator independent of self). `Sequence.Borrowing.Protocol` needs `@_lifetime(borrow self)` (iterator tied to self). These cannot coexist in one signature.

**Blocker 3: Property.View Ownership Flow.** Property.View uses `UnsafeMutablePointer<Base>.pointee` (borrowed access). For ~Copyable bases, you cannot call `consuming func makeIterator()` through a borrowed pointee.

#### Non-Contiguous Storage Patterns

For non-contiguous storage, any storage where elements have stable addresses (heap nodes, buffer slots, inline storage) can produce a `Span<Element>` pointing to the element in-place.

Linked list node:
```swift
struct LinkedListIterator<Element: ~Copyable>: ~Copyable, ~Escapable {
    var current: Node<Element>?

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
        guard let node = current else { return Span() }
        current = node.next
        return Span(unsafeBaseAddress: UnsafePointer(&node.value), count: 1)
    }
}
```

**Stored property lvalue requirement**: `Span(_unsafeStart:count:)` tracks lifetime through the pointer argument. The pointer MUST be passed as a stored property lvalue (not a local variable) for the `@_lifetime(&self)` chain to work. Iterators need a stored `elementPtr: UnsafePointer<Element>` property updated before each `Span` construction.

#### Computed Element Patterns

Sequences that compute elements without persistent storage (e.g., `StrideTo`, `squares`) use a heap-allocated single-element buffer. The iterator stores both a `UnsafeMutablePointer<Element>` (for writing) and a `UnsafePointer<Element>` (stored property for Span lifetime chain). Computed values are written to the mutable buffer; the Span returns from the read pointer.

For ~Copyable computed elements: the pattern requires `UnsafeMutablePointer.moveInitialize`/`pointee =` semantics, which works for ~Copyable types.

#### Unified Iterator Protocol Shape

```swift
extension Sequence.Iterator {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable

        /// Returns the next batch of elements as a borrowed span.
        ///
        /// Returns up to `maximumCount` elements. For element-at-a-time
        /// iteration, pass `Cardinal(UInt(1))`. Returns an empty span
        /// when exhausted.
        @_lifetime(&self)
        mutating func nextSpan(maximumCount: Cardinal) -> Span<Element>
    }
}
```

Both sequence protocols reference the same iterator protocol:

```swift
// For reusable containers and lazy pipelines (Copyable types use thunking)
extension Sequence {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype Iterator: Sequence.Iterator.`Protocol` & ~Copyable & ~Escapable
            where Iterator.Element == Element
        @_lifetime(copy self)
        consuming func makeIterator() -> Iterator
    }
}

// For ~Copyable containers that borrow during iteration
extension Sequence.Borrowing {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype Iterator: Sequence.Iterator.`Protocol` & ~Copyable & ~Escapable
            where Iterator.Element == Element
        @_lifetime(borrow self)
        borrowing func makeIterator() -> Iterator
    }
}
```

#### Derived next() and skip(by:)

```swift
extension Sequence.Iterator.`Protocol` where Element: Copyable {
    /// Returns the next element (owned copy), or `nil` if exhausted.
    public mutating func next() -> Element? {
        let span = nextSpan(maximumCount: Cardinal(UInt(1)))
        return span.isEmpty ? nil : span[0]
    }
}

extension Sequence.Iterator.`Protocol` {
    /// Advances past elements without returning them.
    @_lifetime(self: immortal)
    public mutating func skip(by maximumCount: Cardinal) -> Cardinal {
        var remaining = maximumCount
        while remaining > .zero {
            let span = nextSpan(maximumCount: remaining)
            if span.isEmpty { break }
            remaining = remaining.subtract.saturating(Cardinal(UInt(span.count)))
        }
        return maximumCount.subtract.saturating(remaining)
    }
}
```

#### The Reframing

> **With `nextSpan` as the universal primitive, the two sequence protocols are not "consuming vs borrowing iteration" — they are "consuming vs borrowing iterator creation." The iteration model is unified: all iterators lend elements via Span. The only divergence is how the iterator is created.**

#### Cross-Language Parallels

**Rust IntoIterator**: Appears to unify consuming and borrowing through one trait by implementing `IntoIterator` for both `Vec<T>` (consuming) and `&Vec<T>` (borrowing). This works because `&T` is a first-class type in Rust. Swift cannot replicate this — `&T` is not a type, ownership modifiers annotate function parameters, not types.

**Haskell Traversable**: Unifies traversal via higher-kinded types (`traverse :: Applicative f => (a -> f b) -> t a -> f (t b)`). Swift lacks HKTs, so this approach is not available.

#### Performance Characteristics

**Experiment**: `nextspan-performance-overhead` (v4 — 11 isolation variants)

The derived `next()` path (`nextSpan(1)` → `span[0]`) shows 2.5–3.5x overhead vs direct `next()` in release builds. Eleven targeted variants isolated the root cause:

| Variant | Description | Time (ms) | Ratio |
|---------|-------------|-----------|-------|
| V9 | Escapable struct (same shape) | 1.06 | 0.7x |
| V10 | Generic `~Escapable` struct (local) | 1.07 | 0.7x |
| V8 | Custom `~Escapable` struct (local) | 1.07 | 0.7x |
| V5 | Tuple `(ptr, count)` | 1.20 | 0.8x |
| V1 | Direct `next()` — baseline | 1.44 | 1.0x |
| V7 | `@inline(__always)` + Span | 3.27 | 2.3x |
| V4 | Span, no `min()` | 3.71 | 2.6x |
| V2 | Full Span protocol extension | 3.93 | 2.7x |
| V3 | Span, manual `next()` (no protocol ext) | 3.93 | 2.7x |
| V6 | Span + `withUnsafeBufferPointer` | 4.75 | 3.3x |
| V11 | Span via `extracting` (no alignment check) | 5.43 | 3.8x |

**Key finding (v4)**: The overhead is **Span-specific**, NOT `~Escapable`-generic. A custom `~Escapable` struct with identical `(ptr, count)` shape (V8) reaches parity. Even a **generic** `~Escapable` struct (V10) reaches parity. The Swift compiler **can** perform SROA on `~Escapable` types — the issue is specific to `Span`'s initializer chain.

**Compiler source confirmation**: SROA (`SILSROA.cpp`) has NO explicit `~Escapable` check. It bails on address-only types and move-only-with-deinit types only.

**Root cause (SIL analysis)**: The `Span(_unsafeStart:count:)` initializer chain (`Span.swift:157-167`) inlines five overhead sources that the optimizer cannot eliminate in a hot inner loop:

| Source | SIL Impact | Per Call | Absent in `Chunk` |
|--------|-----------|----------|-------------------|
| **Alignment check** | `ptrtoint` + `AND 7` + `cond_fail` | 2 checks | Yes |
| **Triple `mark_dependence`** | 5 `mark_dependence [nonescaping]` instructions | 5 deps | 1 dep |
| **`end_cow_mutation_addr`** | COW mutation tracking on iterator stack alloc | 2 per iter | None |
| **Optional unwrapping** | `unchecked_enum_data` for `UnsafeRawPointer?` | 1 | None |
| **`assumeNonNegative`** | Builtin call on `_count` accessor | 1 | None |

The alignment check is the most impactful: `Span(_unsafeElements:)` verifies `(Int(bitPattern: ptr) & (alignment - 1)) == 0` on **every construction**. In an iterator loop where the pointer advances by `MemoryLayout<Element>.stride`, alignment is invariant after the first call — but the optimizer cannot prove this.

The call chain: `Span(_unsafeStart:count:)` → `_precondition(count >= 0)` → `UnsafeBufferPointer` intermediary → `Span(_unsafeElements:)` → `UnsafeRawPointer` conversion → **alignment check** → `Span(_unchecked:)` → `_overrideLifetime` #1 → `_overrideLifetime` #2.

The internal `Span(_unchecked:count:)` initializer (`Span.swift:79-85`) has none of this overhead — it directly assigns `_pointer` and `_count` — but it is `internal`, not `@_spi`, and not accessible from user code.

**V11 — `extracting` workaround (FAILED)**: Attempted to bypass the `_unsafeStart` chain by storing the full remaining `Span` as iterator state and using `extracting(first:)` / `extracting(droppingFirst:)` to advance. Both use `_unchecked` internally. Result: **3.8x overhead (worse)** — two Span operations per element, each with its own `_overrideLifetime`, `min()`, and `_precondition`. The overhead is distributed across the entire Span machinery, not concentrated in the alignment check alone.

**Conclusion**: This is a **Span initializer overhead problem**, not an architectural issue with `nextSpan` or `~Escapable`. The concept is zero-cost (proven by V8/V10 parity).

#### Architectural Strategy

The public API is timeless now. The overhead is an implementation detail that conformers control and can change invisibly.

**The protocol shape is correct and permanent:**
```swift
protocol Sequence.Iterator.Protocol: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Cardinal) -> Span<Element>
}
```

**Three layers of mitigation, all invisible to API consumers:**

1. **Batch iteration amortizes the cost.** The primary use case — `nextSpan(n)` where n >> 1 — pays the Span construction overhead once per batch, not per element. For batch sizes of 64+, the per-element cost is negligible.

2. **Conformers can override `next()` for element-at-a-time performance.** The default derived `next()` calls `nextSpan(1)` and carries the Span overhead. Conformers that need hot-loop `next()` performance can provide a direct override using pointer arithmetic. This override is a temporary performance escape hatch — removable when the Span initializer improves.

3. **Upstream resolution replaces conformer overrides.** When the stdlib gains a public unchecked Span initializer (or the optimizer learns to hoist loop-invariant alignment checks), conformers delete their `next()` overrides and the derived default takes over. Zero API change, zero call-site change.

**This means `nextSpan` can proceed to implementation now.** The public protocol surface is stable. The Span overhead affects only the derived `next()` hot path, and conformers have a clean escape hatch until it's resolved upstream.

#### Implementation Path

| Step | Change | Scope | Status |
|------|--------|-------|--------|
| 1 | Experiment: validate `nextSpan` for non-contiguous storage | 1 experiment | **DONE** |
| 2 | Experiment: validate computed-element buffering pattern | 1 experiment | **DONE** |
| 3 | Merge `Sequence.Iterator.Borrowing.Protocol` into `Sequence.Iterator.Protocol` | 2 files → 1 | |
| 4 | Add `next()` default extension for Copyable elements | 1 file | |
| 5 | Add `skip(by:)` default extension | 1 file | |
| 6 | Update both sequence protocols to reference unified iterator protocol | 2 files | |
| 7 | Update all downstream iterator conformers | ~15 iterators | |
| 8 | Update Property.View algorithms to use `nextSpan` | ~8 files | |
| 9 | Delete `Sequence.Iterator.Borrowing.Protocol.swift` | 1 file | |
| 10 | Update documentation and research cross-references | Multiple | |

---

## 7. Decision Status Summary

| Decision | Section | Status | Supersedes / Superseded By |
|----------|---------|--------|---------------------------|
| Adopt SuppressedAssociatedTypes | §2 | **CURRENT** | — |
| Parallel iterator protocols | §6.1 | **SUPERSEDED** | By §6.3 (unified via nextSpan) |
| Keep all six sequence protocols | §3 | **CURRENT** | — |
| withNext closure-based lending | §6.2 | **SUPERSEDED** | By §6.3 (nextSpan replaces with* pattern) |
| Dual-protocol consuming/borrowing | §4 | **CURRENT** | Reframed by §6.3 as "iterator creation, not iteration" |
| Witness thunking is correct | §5 | **CURRENT** | — |
| nextSpan as universal iterator primitive | §6.3 | **CURRENT** (RECOMMENDATION → proceed) | Supersedes §6.1 and §6.2. Span init overhead mitigated by conformer `next()` overrides (§6.3 Performance) |

---

## 8. Open Questions and Future Work

1. **WithDefaults migration** (§2): When `SuppressedAssociatedTypesWithDefaults` becomes available, switch feature flags and split extensions into Copyable-default and ~Copyable tiers. No urgent action needed — current architecture is forward-compatible.

2. **Sequence.Consume.Protocol.Element gap** (§3): Add `~Copyable` suppression to `Sequence.Consume.Protocol.Element` for consistency.

3. **Sequence.Borrowing.Protocol deletion/rename** (§3, §6.3): With iterator unification, the "Borrowing" prefix describes `makeIterator()` ownership, not the iteration model. Consider renaming to emphasize the ownership distinction. Deletion deferred pending audit of bounded-chunk usage.

4. **`@_lifetime` on consuming `makeIterator()`** (§6.3): Currently `@_lifetime(copy self)`. With `~Escapable` iterators, verify this correctly expresses that the consumed-and-copied self's storage transfers to the iterator. For Copyable types with borrowing conformers, the thunk copies self — `copy` is correct. For ~Copyable consuming conformers, the iterator takes ownership — needs verification.

5. **Migration scope for nextSpan adoption** (§6.3): Steps 3–10 of the implementation path. The remaining blocker is migration scope, not technical feasibility. The derived `next()` path carries 2.5–3.5x overhead due to Span's `_unsafeStart` initializer chain (see §6.3 Performance Characteristics), but this is mitigated: conformers provide direct `next()` overrides as a temporary escape hatch until the Span initializer improves upstream. The public protocol shape is stable and can proceed to implementation now.

6. **Future stdlib IteratorProtocol.Element ~Copyable** (§6.1): When the stdlib generalizes `IteratorProtocol` for `~Copyable` elements, our custom `Sequence.Iterator.Protocol` can be deprecated. The parallel design makes this future migration trivial.

7. **Span initializer overhead** (§6.3): Span shows 2.5–3.5x overhead in the derived `next()` path due to per-construction alignment checks, triple `mark_dependence`, COW tracking, and optional unwrapping in the `_unsafeStart` initializer chain (`Span.swift:157-167`). The `extracting`-based workaround (V11) is worse (3.8x). Custom `~Escapable` structs with identical shape achieve parity — `~Escapable` does not block SROA. **Mitigated**: conformers override `next()` with direct pointer arithmetic; overrides are removable when the Span initializer improves. Upstream resolution paths: (a) public unchecked Span initializer, (b) optimizer hoisting loop-invariant alignment checks. The internal `Span(_unchecked:count:)` is not available via `@_spi`.

---

## 9. Experimental Validation

| Experiment | Location | Tests | Key Finding | Referenced In |
|------------|----------|-------|-------------|---------------|
| `suppressed-associated-types` | `Experiments/suppressed-associated-types/` | — | `SuppressedAssociatedTypes` feature flag available in Swift 6.2.3 | §2 |
| `two-tier-borrowing-overloads` | `Experiments/two-tier-borrowing-overloads/` | — | `borrowing` closure parameters transparent at call sites for Copyable | §2 |
| `borrowing-iterator-primitive` | `Experiments/borrowing-iterator-primitive/` | 13 | `withNext<R>` compiles in `~Copyable` protocol; all 5 algorithms work | §6.2 |
| `property-view-consuming-iterator` | `Experiments/property-view-consuming-iterator/` | — | TEST A: forEach requirement works; TEST 1b: ~Copyable + pointee fails | §4 |
| `lazy-escapable-patterns` | `Experiments/lazy-escapable-patterns/` | — | Full suppression pattern validated for lazy types | §4 |
| `nextspan-universal-primitive` | `Experiments/nextspan-universal-primitive/` | 10 | `nextSpan` works for 7 storage types: contiguous, scattered heap, linked list, sparse slab, ring buffer, computed elements, tree nodes | §6.3 |
| `nextspan-performance-overhead` | `Experiments/nextspan-performance-overhead/` | 11 variants | Span `_unsafeStart` chain causes 2.5–3.5x overhead (alignment check, triple `mark_dependence`, COW tracking, optional unwrap). `extracting` workaround worse (3.8x). Custom `~Escapable` structs reach parity. Mitigated: conformers override `next()` until Span init improves. | §6.3 |

---

## 10. References

### Swift Evolution

- [SE-0377: borrowing and consuming parameter ownership modifiers](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0377-borrowing-consuming-modifiers.md)
- [SE-0390: Noncopyable structs and enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md)
- [SE-0427: Noncopyable generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
- [SE-0437: Noncopyable Stdlib Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md)
- [SE-0446: Nonescapable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-nonescapable.md)
- [SE-0499: ~Copyable in Simple Stdlib Protocols](https://forums.swift.org/t/accepted-with-modifications-se-0499-support-copyable-escapable-in-simple-standard-library-protocols/83754)
- [SE-0503: Suppressed Associated Types With Defaults](https://forums.swift.org/t/accepted-se-0503-suppressed-default-conformances-on-associated-types-with-defaults/84774)
- [[Pitch] Borrowing Sequence](https://forums.swift.org/t/pitch-borrowing-sequence/84332)

### Swift Compiler Internals

- Feature flag definitions: `swift/include/swift/Basic/Features.def:460-464`
- Feature gate: `swift/lib/AST/RequirementMachine/ApplyInverses.cpp:56-58`
- Mutual exclusion logic: `swift/lib/Frontend/CompilerInvocation.cpp:1389-1394`
- Witness thunk argument forwarding: `SILGenPoly.cpp:2959-3000`
- Copy injection: `ManagedValue.cpp:289-299`
- Witness table construction: `SILGenType.cpp:641-683`
- Thunk creation: `SILGenType.cpp:733-924`
- SROA pass: `lib/SILOptimizer/Transforms/SILSROA.cpp:106-120` — bails on address-only and move-only-with-deinit; no `~Escapable` check
- `shouldExpand`: `lib/SIL/Utils/InstructionUtils.cpp:1481-1509` — expansion decision with `isAddressOnly()` gate
- Span `_unchecked` init: `stdlib/public/core/Span/Span.swift:79-85` — `internal`, no `@_spi`
- Span `_unsafeStart` init chain: `stdlib/public/core/Span/Span.swift:157-167` → `:108-120` — alignment check + double `_overrideLifetime`

### Swift Standard Library Sources

- `stdlib/public/core/Sequence.swift:325-346` — `__consuming func makeIterator()`
- `stdlib/public/core/Sequence.swift:850-858` — `forEach` is extension, NOT requirement
- `stdlib/public/core/BorrowingSequence.swift:51-62` — `_BorrowingSequence` protocol
- `stdlib/public/core/BorrowingSequence.swift:78-93` — `Span` conformance
- `stdlib/public/core/UTF8SpanIterators.swift:37-74` — `~Escapable` iterator with `@lifetime`
- Commit `de749cea18f` — "Don't reparent Sequence with BorrowingSequence"
- [Swift Forums: Suppressed Associated Types With Defaults](https://forums.swift.org/t/pitch-suppressed-associated-types-with-defaults/83663) — pitch for inference defaulting

### Cross-Language

- [Rust `LendingIterator`](https://docs.rs/lending-iterator/latest/lending_iterator/trait.LendingIterator.html) — GAT-based lending with lifetime-tied items
- [Niko Matsakis: Giving, Lending, and Async Closures](https://smallcultfollowing.com/babysteps/blog/2023/05/09/giving-lending-and-async-closures/) — giving vs lending trait taxonomy
- [GAT Initiative: Iterable Pattern](https://rust-lang.github.io/generic-associated-types-initiative/design_patterns/iterable.html) — lending at the sequence level
- Rust `IntoIterator` — `impl IntoIterator for T` and `impl IntoIterator for &T`
- Haskell `Traversable` — higher-kinded type traversal unification

### Type Theory

- Walker, D. (2004) "Substructural Type Systems." *Advanced Topics in Types and Programming Languages*, MIT Press.
- Wadler, P. (1990) "Linear Types Can Change the World."

---

## 11. Changelog

### v1.2.0 (2026-02-26)

Added V11 (`extracting` workaround — FAILED, 3.8x) to §6.3 Performance. Added Architectural Strategy sub-section: the public `nextSpan -> Span` protocol shape is timeless and can proceed to implementation now. Span init overhead is mitigated by conformer `next()` overrides as a temporary escape hatch, removable when the Span initializer improves upstream. Updated §7 (proceed), §8.5, §8.7, §9, §10 (compiler internals references).

### v1.1.0 (2026-02-26)

Added §6.3 Performance Characteristics sub-section with SIL-level root cause analysis. The `nextspan-performance-overhead` experiment (v4, 11 variants) proved `~Escapable` does NOT block SROA — overhead is from Span's `_unsafeStart` initializer chain (per-construction alignment check, triple `mark_dependence`, COW tracking, optional unwrapping). Custom `~Escapable` structs with identical shape achieve parity. `Span(_unchecked:count:)` is `internal`, not available via `@_spi`. Added open question §8.7, updated §7, §8.5, §9.

### v1.0.0 (2026-02-26)

Consolidated from 7 research documents:

| Original Document | Version | Status |
|-------------------|---------|--------|
| `sequence-protocol-noncopyable-elements.md` | 2.0.0 | DECISION |
| `iterator-protocol-hierarchy.md` | 1.0.0 | DECISION |
| `sequence-protocol-surface-simplification.md` | 1.1.0 | DECISION |
| `sequence-iterator-borrowing-primitive.md` | 1.0.0 | RECOMMENDATION |
| `consuming-vs-borrowing-iteration.md` | 2.0.0 | DECISION |
| `ownership-witness-thunking-protocol-conformance.md` | 1.0.0 | DECISION |
| `sequence-protocol-unification-feasibility.md` | 2.1.0 | RECOMMENDATION |

Overall status is RECOMMENDATION because the final section (§6.3, iterator unification via nextSpan) is a recommendation pending migration scope analysis.
