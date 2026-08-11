# Bounded Index Types for Precondition Elimination

<!--
---
version: 1.1.0
last_updated: 2026-04-16
status: SUPERSEDED
tier: 2
superseded_by: implementation skill [IMPL-050..053]
---
-->

## Context

An implementation skill audit of swift-set-primitives ([IMPL-002], [IMPL-004]) revealed 194 `precondition` calls across 20 primitives packages, of which 136 are index/count bounds checks of the form:

```swift
precondition(index < count, "Index out of bounds")
```

These runtime checks exist because `Index<Element>` (= `Tagged<Element, Ordinal>`) is unbounded: any non-negative ordinal is representable, so subscript access must validate at runtime. The question is whether upgrading to bounded/finite index types can eliminate these preconditions by encoding valid ranges in the type system.

**Trigger**: [RES-001] Design question arose during implementation skill audit of swift-set-primitives, where every subscript and `element(at:)` method requires a bounds-checking precondition.

**Scope**: Primitives-wide per [RES-002a] — affects 20+ packages including set, dictionary, stack, queue, buffer, hash-table, slab, handle, storage, and array primitives.

---

## Question

**Primary**: Can `Index<Element>` be upgraded to support bounded/finite variants that eliminate runtime bounds-checking preconditions?

**Secondary**: What is the path from the current `Ordinal.Finite<N>` infrastructure to `Index<Element>.Bounded<N>` or equivalent, and which precondition categories can be eliminated at each stage?

---

## Prior Art Survey

### Existing Infrastructure: Ordinal.Finite<N>

swift-finite-primitives already provides `Ordinal.Finite<N>` = `Tagged<Finite.Bound<N>, Ordinal>`:

- **Checked construction**: `init?(_ position: Ordinal)` returns `nil` if `position >= N`
- **Total arithmetic**: `successor()`, `predecessor()`, `offset(by:)` all return `Optional`
- **Injection/projection**: `injected<M>()` (upcast to larger bound), `projected<M>()` (downcast with bounds check)
- **Product isomorphism**: `decomposed()`/`composed()` for `Fin(m*n) <-> Fin(m) x Fin(n)`
- **Complement**: `complement()` for `N - 1 - self`

### Existing Research: Architecture.md (swift-index-primitives)

The Affine-Index Architectural Reorganization document proposes `Index<Element>.Bounded<N>` wrapping `Affine.Discrete.Bounded<N>`. Key insight: `Index`, `Ordinal`, and `Finite.Bounded` all implement the same affine arithmetic redundantly. The proposal unifies them under `Affine.Discrete`.

### Existing Research: Index Type Safety Audit (swift-memory-primitives)

Documents that swift-collection-primitives declares but never uses Index_Primitives (0% integration), while swift-array-primitives achieves ~70% type-safe indexing with dual Int/Index<Element> API surface.

### Existing Infrastructure: Finite.Bounded Protocol

`Finite.Bounded.swift` contains a commented-out `Bounded` protocol (Haskell `Bounded` typeclass equivalent) awaiting Swift value-generic constraints (`where N > 0`). This would provide `minBound`/`maxBound` for `Ordinal.Finite<N>`, but Swift cannot yet express the `N > 0` constraint.

### Cross-Language Analysis

| Language | Bounded Index | Precondition Elimination | Mechanism |
|----------|--------------|-------------------------|-----------|
| **Rust** | No native bounded index | Partial via `get()` returning `Option<&T>` | Dual API: `[]` panics, `.get()` returns Option |
| **Haskell** | `Fin n` (dependent types via GHC extensions) | Complete with dependent types | Type-level naturals, `Data.Fin` |
| **Idris** | `Fin n` (first-class dependent type) | Complete | `Fin n` is a value in `[0, n)` by construction |
| **Ada** | `range 0 .. N-1` (subrange types) | Complete at compile time | Subrange types with constraint checks |
| **C++** | `std::span` with `extent` | Partial (static extent eliminates size checks) | Template parameter for static size |

**Key insight**: Languages with value-dependent types (Idris, Haskell with extensions) achieve complete elimination. Languages with value-generic parameters (Ada subranges, C++ static extents) achieve partial elimination — the capacity bound is compile-time, but the *current count* remains runtime. Swift's value generics (`let N: Int`) align with the latter category.

---

## Analysis

### Precondition Taxonomy

The 136 index/count preconditions fall into 6 categories:

| Category | Count | Example | Can Bounded Index Eliminate? |
|----------|-------|---------|------------------------------|
| **A. Subscript bounds** | 48 | `precondition(index < count)` | Partially — capacity yes, count no |
| **B. Non-empty guards** | 32 | `precondition(count > .zero)` | No — runtime occupancy |
| **C. Capacity overflow** | 24 | `guard !isFull else { throw .overflow }` | Already typed throws |
| **D. Raw Int >= 0** | 18 | `precondition(index >= 0)` | Yes — `Ordinal`/`Cardinal` are non-negative by construction |
| **E. Slot validity** | 10 | `precondition(slot < slotCapacity)` | Partially — static capacity yes |
| **F. Range validity** | 4 | `precondition(range.lowerBound <= range.upperBound)` | Yes — `Range<Ordinal.Finite<N>>` |

### Option 1: Status Quo — Runtime Preconditions

**Description**: Keep `Index<Element>` unbounded. All bounds checking via `precondition` or typed throws.

**Advantages**:
- No type system changes needed
- Simple mental model
- Zero migration cost

**Disadvantages**:
- 136 preconditions scattered across 20 packages
- Each is a potential crash site
- Category D (18 checks) is entirely redundant — typed ordinals are already non-negative

**Assessment**: Acceptable for now but leaves significant safety on the table.

---

### Option 2: Index<Element>.Bounded<N> for Static-Capacity Types

**Description**: Introduce `Index<Element>.Bounded<N>` for types with compile-time capacity: `Set.Ordered.Static<capacity>`, `Buffer.Linear.Inline<capacity>`, `Hash.Table.Static<capacity>`, `Vector<Element, N>`, `Array.Inline<Element, capacity>`.

**Type definition** (building on existing infrastructure):

```swift
extension Index where Element: ~Copyable {
    /// A bounded index constrained to [0, N).
    ///
    /// Construction is checked: `init?` returns nil if out of bounds.
    /// All arithmetic returns Optional, making bounds violations
    /// impossible at the type level.
    public typealias Bounded<let N: Int> = Tagged<Element, Ordinal.Finite<N>>
}
```

This reuses `Ordinal.Finite<N>` = `Tagged<Finite.Bound<N>, Ordinal>` by wrapping it with the element phantom type.

**Alternative**: Nest `Finite.Bound<N>` differently:

```swift
// Option 2a: Double-tagged (preserves element phantom type AND finite bound)
public typealias Bounded<let N: Int> = Tagged<Element, Ordinal.Finite<N>>

// Option 2b: Retag to element (loses finite bound information)
// — NOT viable: .retag(Element.self) changes Tag from Finite.Bound<N> to Element
```

Option 2a is correct: `Index<Element>.Bounded<N>` = `Tagged<Element, Ordinal.Finite<N>>`. The element tag provides phantom typing; the `Ordinal.Finite<N>` raw value provides bounds.

**Subscript pattern**:

```swift
// Static-capacity set (capacity known at compile time)
extension Set.Ordered.Static {
    /// Subscript with bounded index — no precondition needed.
    @inlinable
    public subscript(index: Index<Element>.Bounded<capacity>) -> Element {
        // The type guarantees index.rawValue < capacity.
        // Only need: index < currentCount (runtime check, not precondition).
        return _buffer[index.rawValue.map(Ordinal.init)]  // ← zero-cost
    }
}
```

**What this eliminates**:
- Category D (all 18): Non-negativity is structural
- Category A (partial, ~20): For static-capacity types, capacity bound is compile-time
- Category E (partial, ~6): Slot validity within static-capacity hash tables

**What this does NOT eliminate**:
- Count checks (`index < count`): The *current occupancy* is runtime state
- Non-empty guards: Still runtime
- Dynamic-capacity bounds: `Set.Ordered.Fixed` has runtime capacity

**Advantages**:
- Builds directly on existing `Ordinal.Finite<N>` infrastructure
- Zero-cost abstraction (`Tagged` is a wrapper)
- Total arithmetic — `successor()` returns `nil` at bound
- Eliminates ~44 of 136 preconditions

**Disadvantages**:
- Only helps static-capacity types (5 of ~15 collection types)
- Double phantom-type layering (`Tagged<Element, Tagged<Finite.Bound<N>, Ordinal>>`) adds conceptual weight
- Requires Swift value generics to work (already in nightly)

---

### Option 3: Proof-Carrying Index via Existential Witness

**Description**: Instead of encoding bounds in the type, carry a proof token that witnesses "this index is valid for this collection."

```swift
struct ValidIndex<Collection> {
    fileprivate let position: Index<Collection.Element>
    // Only constructible by the collection itself
}

extension Set.Ordered {
    func validIndex(_ index: Index<Element>) -> ValidIndex<Self>? {
        guard index < count else { return nil }
        return ValidIndex(position: index)
    }

    subscript(index: ValidIndex<Self>) -> Element {
        // No bounds check — validity proven by construction
        buffer[index.position]
    }
}
```

**Advantages**:
- Eliminates ALL subscript preconditions (Categories A + E)
- Works for dynamic-capacity types
- No value generics needed

**Disadvantages**:
- Invalidation problem: a `ValidIndex` becomes stale after mutation
- Adds a new type to every collection API
- Cannot store `ValidIndex` across mutations
- ABI cost: each collection needs a `ValidIndex` associated type
- Violates [PATTERN-013]: premature protocol/abstraction before 3+ conformers

**Assessment**: Elegant in theory, fragile in practice. The invalidation problem makes this unsuitable for mutable collections (which is most of our use case).

---

### Option 4: Total Subscript (Optional Return)

**Description**: Add `subscript(safe:)` or make subscript return `Optional`.

```swift
extension Set.Ordered {
    /// Returns the element at the index, or nil if out of bounds.
    @inlinable
    public subscript(checking index: Index<Element>) -> Element? {
        guard index < count else { return nil }
        return buffer[index]
    }
}
```

**Advantages**:
- Pure Swift, no type system extensions
- Forces callers to handle the empty case
- Works for all capacity models

**Disadvantages**:
- Ergonomic cost: every access requires `!` or `guard let`
- Performance: Optional wrapping in tight loops
- Does not eliminate the check — moves it from precondition to `guard`
- Already available via `element(at:)` throwing pattern

**Assessment**: Useful as a supplementary API but not a replacement for the primary subscript. We already have throwing `element(at:)` which serves this role.

---

### Option 5: Hybrid — Bounded for Static, Typed Throws for Dynamic

**Description**: Combine Options 2 and the existing typed-throws pattern:

- **Static capacity** (`Static<N>`, `Inline<N>`, `Vector<E, N>`): Use `Index<Element>.Bounded<N>` subscript. Capacity bound is compile-time; only count check remains (typed throw or precondition).
- **Fixed capacity** (`Fixed`): Use `Index<Element>` subscript with typed throws for bounds. Capacity is runtime-known but immutable after init.
- **Dynamic capacity** (`Ordered`, `Unbounded`): Use `Index<Element>` subscript with typed throws. Capacity changes over time.

```swift
// Static: bounded index, no capacity precondition
extension Set.Ordered.Static {
    subscript(bounded index: Index<Element>.Bounded<capacity>) -> Element { ... }
}

// Fixed: typed throw for bounds
extension Set.Ordered.Fixed {
    func element(at index: Index<Element>) throws(__SetOrderedFixedError) -> Element { ... }
}

// Dynamic: typed throw for bounds
extension Set.Ordered {
    func element(at index: Index<Element>) throws(__SetOrderedError) -> Element { ... }
}
```

**What this eliminates across the ecosystem**:

| Category | Current | After Option 5 |
|----------|---------|----------------|
| A. Subscript bounds (static) | `precondition` (crash) | Type-system (compile-time) |
| A. Subscript bounds (dynamic) | `precondition` (crash) | Typed throw (recoverable) |
| B. Non-empty guards | `precondition` | Typed throw or `.first?` pattern |
| C. Capacity overflow | Typed throw | Typed throw (no change) |
| D. Non-negativity | `precondition` | Eliminated (ordinal is non-negative) |
| E. Slot validity (static) | `precondition` | Type-system |
| F. Range validity | `precondition` | `Range<Ordinal.Finite<N>>` |

**Advantages**:
- Maximal elimination where type system supports it
- Graceful degradation to typed throws where it doesn't
- Builds on existing infrastructure (Ordinal.Finite, typed throws)
- Incremental adoption — each package migrates independently

**Disadvantages**:
- Two subscript patterns for the same conceptual operation
- Bounded subscript only applies to value-generic types
- Migration across 20 packages is significant effort

---

### Comparison

| Criterion | 1: Status Quo | 2: Bounded<N> | 3: Proof Token | 4: Optional | 5: Hybrid |
|-----------|--------------|---------------|----------------|-------------|-----------|
| Preconditions eliminated | 0 | ~44 | ~58 | 0 (moved) | ~62 |
| Works for static capacity | N/A | Yes | Yes | Yes | Yes |
| Works for dynamic capacity | N/A | No | Partially | Yes | Yes (throws) |
| Migration cost | None | Medium | High | Low | Medium-High |
| Type system complexity | None | Medium | High | None | Medium |
| Ergonomic impact | None | Positive | Negative | Negative | Mixed |
| Builds on existing infra | N/A | Ordinal.Finite | New types | None | Ordinal.Finite + throws |
| Swift language requirements | None | Value generics | None | None | Value generics |
| Invalidation risk | N/A | None | High | None | None |

---

## Constraints and Blockers

### Swift Language Limitations

1. **Value-generic constraints** (`where N > 0`): Not yet supported. This blocks:
   - `Finite.Bounded` protocol (min/max bounds for `Ordinal.Finite<N>`)
   - Static guarantee that a bounded index has at least one valid value
   - Currently worked around with `Optional` returns from `max()`

2. **Value-generic conformances**: Cannot write `extension Index.Bounded: SomeProtocol where N > 0`. This limits API expressiveness for bounded types.

3. **Value-generic inference**: Swift's type checker sometimes struggles with nested value generics (`Tagged<Element, Tagged<Finite.Bound<N>, Ordinal>>`). Must be validated empirically.

### Architectural Constraint: Double Tagging

`Index<Element>.Bounded<N>` = `Tagged<Element, Ordinal.Finite<N>>` = `Tagged<Element, Tagged<Finite.Bound<N>, Ordinal>>`.

This double-`Tagged` nesting is novel in the ecosystem. Questions:
- Does `Tagged<A, Tagged<B, C>>` compose correctly with `.map()` and `.retag()`?
- Is the memory layout guaranteed identical to the raw `Ordinal`?
- Can `Index<Element>.Bounded<N>` participate in `Ordinal.Finite<N>`'s arithmetic?

These questions were validated empirically in experiment `Experiments/double-tagged-bounded-index/` (2026-02-10, Swift 6.2.3). All 8 variants CONFIRMED: identical memory layout (8/8/8), `.map()` and `.retag()` compose correctly through the double nesting, and all `Ordinal.Finite<N>` arithmetic (successor, predecessor, offset, distance, injection, projection) is accessible via `.rawValue`.

### Count vs. Capacity Distinction

Even with bounded indices, the **current count** is runtime state. A `Set.Ordered.Static<8>` can hold up to 8 elements, but if only 3 are inserted, index 5 is within the capacity bound but points to uninitialized memory. This means:

- Capacity-bounded subscript (`index < capacity`): Type-system guaranteeable
- Count-bounded subscript (`index < count`): Always requires runtime check

For static types, we can:
- Eliminate the `index < capacity` check via `Bounded<N>`
- Keep the `index < count` check as a typed throw or precondition

This is still a win: we reduce two checks to one, and the remaining check has a clear semantics.

---

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: **Option 5 — Hybrid approach** with phased rollout.

### Rationale

1. **Builds on existing infrastructure**: `Ordinal.Finite<N>` already provides the bounded ordinal with total arithmetic. The only new type needed is the `Index<Element>.Bounded<N>` typealias.

2. **Incremental adoption**: Each package can migrate independently. Static-capacity types get bounded indices; dynamic-capacity types use typed throws. No big-bang migration required.

3. **Eliminates ~62 preconditions**: Of the 136 index/count bounds checks, ~44 can be eliminated via bounded indices for static types, and ~18 (non-negativity) are eliminated by using typed ordinals consistently.

4. **Aligns with existing research**: The Affine-Index Architecture research already proposes `Index<Element>.Bounded<N>`. This recommendation validates that direction with concrete precondition counts.

5. **Pragmatic about language limitations**: Does not depend on value-generic constraints (`where N > 0`). Works with Swift's current value generics.

### Implementation Path

**Phase 0: Experiment** (COMPLETE)

Experiment `Experiments/double-tagged-bounded-index/` (2026-02-10, Swift 6.2.3) validated:
- `Tagged<Element, Tagged<Finite.Bound<N>, Ordinal>>` memory layout: identical to `Ordinal` (8/8/8)
- `.map()` / `.retag()` composition through double-tagged types: works correctly
- Arithmetic delegation: `Ordinal.Finite<N>.successor()`, `predecessor()`, `offset(by:)`, `distance(to:)`, `injected()`, `projected()` all accessible via `.rawValue`
- Practical subscript: reduces 3 preconditions (>=0, <capacity, <count) to 1 (<count only)

All 8 variants CONFIRMED. Phase 0 blocker is resolved.

**Phase 1: Define Index<Element>.Bounded<N>** (swift-index-primitives)

Add the typealias and bridging operations:
```swift
extension Index where Element: ~Copyable {
    public typealias Bounded<let N: Int> = Tagged<Element, Ordinal.Finite<N>>
}
```

Add conversion between `Index<Element>` and `Index<Element>.Bounded<N>`:
```swift
extension Index where Element: ~Copyable {
    /// Narrows an unbounded index to a bounded one, returning nil if out of range.
    func bounded<let N: Int>() -> Index<Element>.Bounded<N>? { ... }
}
```

**Phase 2: Adopt in static-capacity types** (swift-set-primitives, swift-buffer-primitives, swift-hash-table-primitives)

Add bounded subscripts alongside existing unbounded ones:
- `Set.Ordered.Static<capacity>`
- `Buffer.Linear.Inline<capacity>`
- `Hash.Table.Static<capacity>`

**Phase 3: Eliminate Category D preconditions** (all packages)

Replace `precondition(index >= 0)` checks — these are redundant when using `Index<Element>` (which wraps `Ordinal`, a non-negative type). This is independent of bounded indices and can proceed immediately.

**Phase 4: Migrate dynamic-capacity types to typed throws** (where not already done)

Ensure all `precondition(index < count)` in dynamic-capacity types use typed throws instead, making bounds violations recoverable rather than fatal.

### Out of Scope

- **Proof-carrying indices** (Option 3): Too complex, invalidation problem
- **Finite.Bounded protocol**: Blocked on Swift value-generic constraints
- **Collection protocol integration**: Tracked separately in Index Type Safety Audit
- **Affine-Index architectural reorganization**: Tracked in Architecture.md; this research is compatible with either current or proposed architecture

---

## References

### Internal Research
- [Architecture.md](../swift-index-primitives/Research/Architecture.md) — Affine-Index Architectural Reorganization
- [Index Type Safety Audit](../swift-memory-primitives/Research/Index%20Type%20Safety%20Audit.md) — Collection/Array integration audit
- [Finite-Collection Join-Point Integration](finite-collection-join-point-integration.md) — Tier compression via join-point

### Internal Source
- `Ordinal.Finite.swift` — `swift-finite-primitives/Sources/Finite Primitives/`
- `Tagged+Ordinal.Finite.swift` — Bounded ordinal API (successor, predecessor, offset, etc.)
- `Finite.Bounded.swift` — Commented-out Bounded protocol awaiting language support
- `Set.Ordered.Static.swift` — Example of static-capacity type with preconditions

### External
- Norell, U. (2009). "Dependently Typed Programming in Agda." — Fin type in dependent type theory
- Brady, E. (2013). "Idris, a general-purpose dependently typed programming language." — Fin n in practice
- Haskell: `Data.Fin` (GHC dependent types extension) — Bounded naturals
- Ada Reference Manual, Section 3.5 — Subrange types with static constraint checking
- Swift Evolution: SE-0452 "Integer Generic Parameters" — Value generics in Swift
