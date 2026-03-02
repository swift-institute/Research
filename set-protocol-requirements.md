# Set Protocol Requirements

<!--
---
version: 3.0.0
last_updated: 2026-03-02
status: DECISION
tier: 2
---
-->

## Context

`Set.Protocol` (`__SetProtocol`) currently declares two requirements — `contains` and `forEach` — from which three default implementations flow: `isDisjoint(with:)`, `isSubset(of:)`, `isSuperset(of:)`. The protocol was implemented as Option B (minimal query protocol) from `set-protocol-abstraction.md` (v2.0.0), prioritizing shipping over completeness.

**Trigger**: After the O(1) `contains` restoration (`set-contains-performance-restoration.md`, v2.0.0), all protocol defaults achieve optimal complexity — O(n) relational queries with O(1) per probe. This raises the question: is the protocol complete? Can we compose all standard set operations from the current primitives, or are additional requirements needed?

**Precedent**: `Swift.SetAlgebra` requires 7 operations (contains, union, intersection, symmetricDifference, insert, remove, update) and provides 10 defaults. `Array.Protocol` (`__ArrayProtocol`) requires only `subscript` (inheriting `Collection.Bidirectional`) and provides `forEach` and `withElement`.

## Question

What is the minimal complete set of primitives for `Set.Protocol` from which all standard set operations can be composed as defaults?

## Analysis

### Current State

**Protocol requirements** (2):

| Requirement | Signature | Constraint |
|------------|-----------|-----------|
| `contains` | `func contains(_ element: borrowing Element) -> Bool` | Unconstrained |
| `forEach` | `func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)` | Unconstrained |

**Protocol defaults** (3):

| Default | Composed from | Complexity |
|---------|--------------|-----------|
| `isDisjoint(with:)` | forEach(self) + contains(other) | O(n) |
| `isSubset(of:)` | forEach(self) + contains(other) | O(n) |
| `isSuperset(of:)` | forEach(other) + contains(self) | O(m) |

**Standard set operations NOT available** via the protocol:

| Operation | SetAlgebra | Status |
|-----------|-----------|--------|
| `count` | Not in SetAlgebra | Missing — prevents strict relations |
| `isEmpty` | Default via SetAlgebra | Missing — available on all variants |
| `isStrictSubset(of:)` | Default via SetAlgebra | Missing — needs count |
| `isStrictSuperset(of:)` | Default via SetAlgebra | Missing — needs count |
| `union(_:)` | Required by SetAlgebra | Only on Set.Ordered via `.algebra` |
| `intersection(_:)` | Required by SetAlgebra | Only on Set.Ordered via `.algebra` |
| `symmetricDifference(_:)` | Required by SetAlgebra | Only on Set.Ordered via `.algebra` |
| `subtract(_:)` | Default via SetAlgebra | Only on Set.Ordered via `.algebra` |
| `insert(_:)` | Required by SetAlgebra | Copyable-only, error types diverge |
| `remove(_:)` | Required by SetAlgebra | Copyable-only, signature uniform |

### Constraint Inventory

| ID | Constraint | Impact |
|----|-----------|--------|
| C1 | `insert` error types and return types diverge | Ordered/Small: non-throwing, `Index<Element>`. Fixed: `throws(__SetOrderedFixedError)`, `Index<Element>`. Static: `throws(__SetOrderedInlineError)`, `Index<Element>.Bounded<capacity>`. Cannot unify into a single protocol requirement. |
| C2 | `index` return types diverge | Static returns `Index<Element>.Bounded<capacity>?`, others return `Index<Element>?` |
| C3 | Algebra operations only on Ordered | Fixed/Static/Small have no union/intersection/subtract |
| C4 | `insert`/`remove` require `Element: Copyable` | Element must be copied into/out of the set |
| C5 | Algebra returns `Set.Ordered`, not `Self` | Correct: result size is unpredictable for bounded variants |
| C6 | `forEach` provides no early exit | Protocol defaults iterate all elements even after answer is determined |

**C1 scope**: C1 blocks `insert` as a protocol requirement. It does NOT block non-mutating algebra as protocol defaults — algebra operations insert into a **result** `Set.Ordered`, not into `self`. The protocol only needs `forEach` and `contains` from conformers.

**C5 recharacterized**: Returning `Set.Ordered` is not a blocker — it's the correct design. The result of `fixed.union(other)` has unpredictable size; it cannot be a `Fixed` (might exceed capacity). `Set.Ordered` is the natural growable container. Protocol defaults returning a concrete `Set.Ordered` are well-typed.

### Compositional Tiers

Standard set operations decompose into tiers based on what primitives they require:

**Tier 0 — Relational queries** (current):
Primitives: `contains`, `forEach`
Composable: `isDisjoint`, `isSubset`, `isSuperset`

**Tier 1 — Cardinality-aware relations**:
Primitives: + `count`
Composable: + `isStrictSubset`, `isStrictSuperset`, `isEmpty`

**Tier 1a — Non-mutating algebra** (no new requirements):
Primitives: `contains`, `forEach` (already required)
Composable: `union`, `intersection`, `subtract`, `symmetricDifference` → all return `Set.Ordered`
Constraint: `Element: Copyable` on the defaults (to construct result set)
Module: defaults must live in Set Ordered Primitives (needs access to `Set.Ordered` + `insert`)

**Tier 2 — Mutating set difference**:
Primitives: + `remove` (requires `Element: Copyable`)
Composable: + mutating `subtract(_:)`, mutating `formIntersection(_:)`

**Tier 3 — Mutating set union**:
Primitives: + `insert` (requires `Element: Copyable`)
Composable: + mutating `formUnion(_:)`, mutating `formSymmetricDifference(_:)`
**Blocked by C1**: `insert` signatures diverge across variants

Tier 0 → Tier 1 adds one requirement and three defaults.
Tier 1 → Tier 1a adds zero requirements and four defaults (algebra).
Tier 1a → Tier 2 adds one requirement and two defaults but introduces Copyable constraint.
Tier 2 → Tier 3 is blocked by C1.

**Key insight**: Non-mutating algebra (Tier 1a) requires NO new protocol requirements. The operations compose from `forEach` + `contains` (Tier 0) and construct `Set.Ordered` results directly. This was previously mischaracterized as requiring `insert` as a protocol requirement — but `insert` is only needed on the concrete result type `Set.Ordered`, not on the protocol conformer.

### Prior Art

**Swift.SetAlgebra** targets Tier 3. Its requirements (`contains`, `union`, `intersection`, `symmetricDifference`, `insert`, `remove`, `update`, `init()`) provide 10 defaults. However, SetAlgebra assumes:
- All operations are non-throwing (C1 blocks this for Fixed/Static)
- `union`/`intersection`/`symmetricDifference` return `Self` (our variants can't — result size is unpredictable for bounded variants)
- Elements are Copyable (implicit pre-Swift 6)

SetAlgebra requires `union` etc. as protocol requirements precisely because it returns `Self`. Our design returns `Set.Ordered` — a concrete type — which means algebra operations can be protocol **defaults** composed from `forEach` + `contains`, without requiring algebra operations from conformers.

**Array.Protocol** targets a single tier: `subscript` + `Collection.Bidirectional`. It provides `forEach` and `withElement` as defaults. The protocol does NOT attempt to provide mutating operations (`append`, `remove`), even though all array variants have them with uniform signatures. The precedent: primitives protocols unify READ operations, not mutations.

**Rust `HashSet`**: No shared trait. `is_disjoint`, `is_subset`, `is_superset` are concrete methods. `len()` (count) is also concrete. No protocol-level unification.

### Algebra Composition Analysis

Non-mutating algebra operations compose from existing protocol requirements. Each operation iterates one or both sets (`forEach`) and tests membership in the other (`contains`), inserting matches into a new `Set.Ordered`:

| Operation | Algorithm | Protocol primitives used |
|-----------|-----------|------------------------|
| `union` | iterate self, iterate other, insert all | `forEach(self)`, `forEach(other)` |
| `intersection` | iterate self, insert if in other | `forEach(self)`, `contains(other)` |
| `subtract` | iterate self, insert if NOT in other | `forEach(self)`, `contains(other)` |
| `symmetricDifference` | iterate self (insert if not in other), iterate other (insert if not in self) | `forEach(self)`, `forEach(other)`, `contains(self)`, `contains(other)` |

All four use only `forEach` and `contains` from the protocol. `insert` is called on the result `Set.Ordered`, not on the conformer. This means:

```swift
// In Set Ordered Primitives (has access to Set.Ordered + insert)
extension Set.`Protocol` where Self: ~Copyable, Element: Copyable {
    public func union<Other: Set.`Protocol` & ~Copyable>(
        _ other: borrowing Other
    ) -> Set<Element>.Ordered where Other.Element == Element {
        var result = Set<Element>.Ordered()
        self.forEach { element in result.insert(element) }
        other.forEach { element in result.insert(element) }
        return result
    }

    public func intersection<Other: Set.`Protocol` & ~Copyable>(
        _ other: borrowing Other
    ) -> Set<Element>.Ordered where Other.Element == Element {
        var result = Set<Element>.Ordered()
        self.forEach { element in
            if other.contains(element) { result.insert(element) }
        }
        return result
    }

    public func subtract<Other: Set.`Protocol` & ~Copyable>(
        _ other: borrowing Other
    ) -> Set<Element>.Ordered where Other.Element == Element {
        var result = Set<Element>.Ordered()
        self.forEach { element in
            if !other.contains(element) { result.insert(element) }
        }
        return result
    }

    public func symmetricDifference<Other: Set.`Protocol` & ~Copyable>(
        _ other: borrowing Other
    ) -> Set<Element>.Ordered where Other.Element == Element {
        var result = Set<Element>.Ordered()
        self.forEach { element in
            if !other.contains(element) { result.insert(element) }
        }
        other.forEach { element in
            if !self.contains(element) { result.insert(element) }
        }
        return result
    }
}
```

**Heterogeneous algebra**: This enables algebra across any combination of set types:

```swift
let ordered: Set<String>.Ordered = ["a", "b", "c"]
var fixed: Set<String>.Ordered.Fixed = ["b", "c", "d"]
let result = fixed.intersection(ordered)  // Set<String>.Ordered: ["b", "c"]
```

**Module placement**: These defaults must live in Set Ordered Primitives (not Set Primitives Core) because they construct `Set.Ordered` instances and call `insert`. Set Primitives Core only declares the protocol — it has no access to the concrete `insert` implementation.

**Relationship to existing `.algebra` accessor**: `Set.Ordered` currently has algebra via the `.algebra` accessor pattern (`set.algebra.union(other)`). The protocol defaults provide the same operations as direct methods (`set.union(other)`). For `Set.Ordered`, both paths produce identical results. The concrete `.algebra` implementation accesses `buffer[idx]` directly (bypassing `forEach`), which may be marginally faster. Conformers can override the protocol defaults with optimized concrete implementations.

### `remove` Uniformity

Unlike `insert`, `remove` has a uniform signature across all four variants:

| Variant | Signature | Extension constraint |
|---------|-----------|---------------------|
| Ordered | `mutating func remove(_ element: Element) -> Element?` | `where Element: Copyable` |
| Fixed | `mutating func remove(_ element: Element) -> Element?` | `where Element: Copyable` |
| Static | `mutating func remove(_ element: Element) -> Element?` | unconstrained |
| Small | `mutating func remove(_ element: Element) -> Element?` | `where Element: Copyable` |

No error type divergence, no return type divergence. This makes `remove` a candidate for a protocol requirement or refinement protocol, enabling mutating `subtract` and `formIntersection` as defaults.

### Option A: Stay at Tier 0 (no change)

Keep current: `contains` + `forEach` → `isDisjoint`, `isSubset`, `isSuperset`.

**Pros**:
- No changes required
- Protocol is minimal and stable

**Cons**:
- `isStrictSubset`/`isStrictSuperset` not composable from protocol
- `isEmpty` not available as protocol default
- No algebra operations on Fixed/Static/Small
- Consumers writing generic code over `Set.Protocol` cannot check cardinality

**Verdict**: Correct but incomplete.

### Option B: Tier 1 only (add `count`)

Add `count` as a third requirement. No algebra.

```swift
public protocol __SetProtocol: ~Copyable {
    associatedtype Element: Hash.`Protocol` & ~Copyable
    func contains(_ element: borrowing Element) -> Bool
    func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)
    var count: Index<Element>.Count { get }
}
```

New defaults: `isEmpty`, `isStrictSubset(of:)`, `isStrictSuperset(of:)`.

**Conformance impact**: Zero. All four variants already have `var count: Index<Element>.Count { get }` in unconstrained extensions.

**Pros**:
- 1 requirement → 3 defaults (high leverage)
- Completes relational operations
- Zero conformance changes

**Cons**:
- Algebra operations remain Ordered-only
- Misses the opportunity to provide algebra for all variants

**Verdict**: Correct and clean, but leaves algebra on the table.

### Option C: Tier 1 + Tier 1a (add `count` + algebra defaults)

Add `count` to the protocol requirements. Add non-mutating algebra as protocol defaults in Set Ordered Primitives.

**Protocol** (Set Primitives Core):

```swift
public protocol __SetProtocol: ~Copyable {
    associatedtype Element: Hash.`Protocol` & ~Copyable
    func contains(_ element: borrowing Element) -> Bool
    func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)
    var count: Index<Element>.Count { get }
}
```

**Defaults in Set Primitives Core** (`Set.Protocol+defaults.swift`):
- `isEmpty` — from `count`
- `isStrictSubset(of:)` — from `count` + `isSubset`
- `isStrictSuperset(of:)` — from `count` + `isSuperset`

**Defaults in Set Ordered Primitives** (`Set.Protocol+algebra.swift`):
- `union(_:) -> Set.Ordered` — from `forEach` (both)
- `intersection(_:) -> Set.Ordered` — from `forEach` (self) + `contains` (other)
- `subtract(_:) -> Set.Ordered` — from `forEach` (self) + `contains` (other)
- `symmetricDifference(_:) -> Set.Ordered` — from `forEach` (both) + `contains` (both)

**Conformance impact**: Zero. No new requirements beyond `count`. Algebra defaults flow automatically.

**Pros**:
- 1 requirement → 7 defaults (highest leverage of any option)
- Every set variant gains algebra operations (heterogeneous, too)
- Zero conformance changes
- Preserves read-only protocol character (algebra returns new set, doesn't mutate)
- `Element: Copyable` constraint only on algebra defaults, not on protocol itself
- Natural module split: relational defaults in Core, algebra defaults in Ordered Primitives

**Cons**:
- Algebra defaults live in a different module than the protocol declaration
- `Set.Ordered` has two paths to algebra: `.algebra.union(other)` (concrete) and `.union(other)` (protocol default). The concrete path may be marginally faster (direct buffer access vs `forEach` dispatch)
- No mutating algebra (`formUnion`, mutating `subtract`)

**Verdict**: Maximum value for minimum protocol expansion. Completes both relational and algebra operations with a single requirement addition.

### Option D: Tier 1 + Tier 1a + Tier 2 (add `count` + `remove` + algebra)

Everything from Option C, plus `remove` as a protocol requirement enabling mutating `subtract` and `formIntersection`.

**Two approaches for `remove`**:

**D1: Add `remove` directly to `__SetProtocol`**:

```swift
public protocol __SetProtocol: ~Copyable {
    associatedtype Element: Hash.`Protocol` & ~Copyable
    func contains(_ element: borrowing Element) -> Bool
    func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)
    var count: Index<Element>.Count { get }
    mutating func remove(_ element: Element) -> Element?
}
```

Problem: `remove` requires `Element: Copyable` on three of four variants (Ordered, Fixed, Small). The protocol requirement would be unconstrained, but witnesses exist only in Copyable extensions. This forces conformances to become conditional: `extension Set.Ordered: Set.Protocol where Element: Copyable {}` — breaking the current unconditional conformances.

**D2: Refinement protocol `Set.Mutable`**:

```swift
public protocol __SetMutableProtocol: __SetProtocol {
    mutating func remove(_ element: Element) -> Element?
}

extension Set where Element: ~Copyable {
    public typealias Mutable = __SetMutableProtocol
}
```

Each variant conforms conditionally:

```swift
extension Set.Ordered: Set.Mutable where Element: Copyable {}
extension Set.Ordered.Fixed: Set.Mutable where Element: Copyable {}
extension Set.Ordered.Static: Set.Mutable {}  // remove is unconstrained on Static
extension Set.Ordered.Small: Set.Mutable where Element: Copyable {}
```

Defaults on `Set.Mutable`:

```swift
extension Set.Mutable where Self: ~Copyable, Element: Copyable {
    public mutating func subtract<Other: Set.`Protocol` & ~Copyable>(
        _ other: borrowing Other
    ) where Other.Element == Element {
        other.forEach { element in _ = self.remove(element) }
    }

    public mutating func formIntersection<Other: Set.`Protocol` & ~Copyable>(
        _ other: borrowing Other
    ) where Other.Element == Element {
        // Collect elements to remove (can't remove during forEach)
        var toRemove = Set<Element>.Ordered()
        self.forEach { element in
            if !other.contains(element) { toRemove.insert(element) }
        }
        toRemove.forEach { element in _ = self.remove(element) }
    }
}
```

**Pros** (D2):
- Preserves unconditional `Set.Protocol` conformance
- Mutation is opt-in via refinement
- `remove` signature is genuinely uniform
- Enables mutating `subtract` and `formIntersection`

**Cons** (D2):
- Additional protocol + typealias + 4 conformances
- `formIntersection` needs temporary storage (can't remove during iteration)
- Mutating `formUnion` still blocked by C1 (`insert` divergence)
- `Set.Mutable` is a significant architectural addition for 2 defaults

**Verdict**: D2 (refinement) is cleaner than D1 (direct requirement). But the leverage is low — 1 protocol + 4 conformances for 2 mutating defaults. The non-mutating `subtract` from Tier 1a (returning `Set.Ordered`) covers most use cases. Mutating algebra is a future extension if demand materializes.

### Comparison

| Criterion | A: No change | B: + count | C: + count + algebra | D2: + count + algebra + remove |
|-----------|-------------|-----------|---------------------|-------------------------------|
| Requirements added | 0 | 1 | 1 | 1 + refinement protocol |
| Defaults gained | 0 | 3 | 7 | 9 |
| Conformance changes | 0 | 0 | 0 | 4 conditional (Mutable) |
| Relational complete | No | Yes | Yes | Yes |
| Non-mutating algebra | No | No | Yes | Yes |
| Mutating algebra | No | No | No | Partial (subtract, formIntersection) |
| Heterogeneous algebra | No | No | Yes | Yes |
| Protocol character | Read-only | Read-only | Read-only | Read + mutation (refinement) |
| Implementation risk | None | Minimal | Low | Medium |

### Correctness Review of Existing Defaults

The current implementations are logically correct. Two observations:

1. **`isDisjoint` complexity annotation**: Documented as O(min(n,m)) but implementation always iterates `self` (O(n) regardless of relative sizes). Achievable O(min(n,m)) would require checking sizes and iterating the smaller set (enabled by `count` in Tier 1). Not a bug — the documentation overpromises.

2. **No early exit from `forEach`**: All three defaults continue iterating after the answer is determined. The `if disjoint`/`if result` guard skips the O(1) `contains` call but not the iteration itself. This is inherent to `forEach` (no early return). Conformers with `Swift.Sequence` access can override with `for element in self { ... return ... }` for true short-circuit. Not a correctness issue — a performance ceiling of the `forEach`-based composition.

Neither issue affects correctness. Both could be documented more precisely.

### Theoretical Audit

Comparison of proposed Option C against the theoretical ideal implementation.

#### 1. Return Type: `Set.Ordered` vs `Self`

The proposal returns `Set.Ordered` uniformly for all algebra defaults. The theoretical ideal differs per operation:

| Operation | Result set relationship | `Self` viable? | `Set.Ordered` viable? |
|-----------|----------------------|----------------|----------------------|
| `intersection` | result ⊆ self | Yes — result fits in self's capacity | Yes |
| `subtract` | result ⊆ self | Yes — result fits in self's capacity | Yes |
| `union` | result ⊇ self ∪ other | Only for growable (Ordered, Small) | Yes |
| `symmetricDifference` | result ≤ \|self\| + \|other\| | Only for growable (Ordered, Small) | Yes |

**`intersection` and `subtract` could return `Self`**: Since the result is a subset of `self`, it's guaranteed to fit within `self`'s capacity — even for bounded variants. A `Fixed` with capacity 100 intersected with anything produces at most 100 elements. A `Static<8>` subtracted by anything produces at most 8 elements.

**`union` and `symmetricDifference` cannot return `Self` for bounded variants**: `fixed.union(other)` may produce more elements than Fixed's capacity. `static.symmetricDifference(other)` may produce more than `capacity` elements.

**Achieving `Self` return for intersection/subtract**: Requires constructing a new `Self` from scratch inside the default. This needs:
1. `init()` — protocol requirement to create empty instance
2. `insert(_ element: Element)` — protocol requirement to populate it
3. Or: copy `self` then mutate via `remove` — needs `Self: Copyable` + `remove`

Path (1) reintroduces C1 (`insert` error types diverge). Path (2) excludes Static/Small (~Copyable, not copyable).

**Achieving `Self` return for union on growable variants only**: Would require a marker protocol (`Set.Growable`) or conditional defaults, adding complexity for two of four variants.

**Verdict**: Returning `Set.Ordered` is a simplification, not the theoretical ideal. The theoretical ideal is:
- `intersection`, `subtract` → `Self` (result always fits)
- `union`, `symmetricDifference` → `Self` for growable, `Set.Ordered` for bounded

But achieving the ideal requires `init()` + `insert` as protocol requirements (blocked by C1) or `copy self` + `remove` (blocked by ~Copyable on Static/Small). The simplification is justified: (a) it works for all variants uniformly, (b) type information is recoverable by constructing the specific variant from the result, (c) the alternative adds significant protocol complexity.

**Future path**: If C1 is resolved (e.g., unified error type or non-throwing `insert` requirement), `intersection` and `subtract` could be upgraded to return `Self`. This is an additive change — the `Set.Ordered`-returning defaults can coexist with `Self`-returning overrides.

#### 2. Requirement Minimality

**Proposed requirements** (3): `contains`, `forEach`, `count`

| Requirement | Purpose | Alternatives |
|------------|---------|-------------|
| `contains` | O(1) membership probe | No alternative — fundamental set operation |
| `forEach` | Borrowing iteration | Could use `Sequence.Protocol` inheritance instead. But: sets don't universally conform to `Sequence.Protocol` (Static/Small conform only `where Element: Copyable`). `forEach` in unconstrained extensions is available on all four variants. `forEach` is the minimal iteration primitive. |
| `count` | Cardinality for strict relations + optimization | Could compute via `var c = 0; forEach { _ in c += 1 }`, but O(n) vs O(1). All variants have O(1) count. Requiring it is correct. |

Could we use fewer requirements?

- **Without `forEach`**: No iteration → no `isDisjoint`, `isSubset`, `isSuperset`, no algebra. Not viable.
- **Without `contains`**: Could compute via `forEach` (linear scan), but O(n) per probe → O(n²) per relational operation. Not acceptable.
- **Without `count`**: Lose `isStrictSubset`, `isStrictSuperset`, `isEmpty` defaults. Also lose optimization opportunities in `isDisjoint` (iterate smaller set) and `intersection` (iterate smaller set). `count` adds the most value per complexity cost.

**Verdict**: 3 requirements is minimal for the proposed defaults. Each serves a distinct, non-redundant purpose.

#### 3. Complexity Optimality

| Operation | Proposed complexity | Theoretical optimal | Gap |
|-----------|-------------------|-------------------|-----|
| `contains` | O(1) amortized | O(1) amortized | None |
| `isDisjoint` | O(n) | O(min(n,m)) | Yes — iterate smaller set with `count` |
| `isSubset` | O(n) | O(n) | None |
| `isSuperset` | O(m) | O(m) | None |
| `isStrictSubset` | O(n) with count short-circuit | O(n) with count short-circuit | None |
| `isStrictSuperset` | O(m) with count short-circuit | O(m) with count short-circuit | None |
| `isEmpty` | O(1) via count | O(1) | None |
| `union` | O(n+m) | O(n+m) | None |
| `intersection` | O(n) | O(min(n,m)) | Yes — iterate smaller set with `count` |
| `subtract` | O(n) | O(n) | None — must iterate self |
| `symmetricDifference` | O(n+m) | O(n+m) | None |

Two operations have suboptimal complexity:

**`isDisjoint`**: Currently iterates `self` (O(n)). With `count`, could iterate the smaller set (O(min(n,m))). Implementation:

```swift
public func isDisjoint<Other: Set.`Protocol` & ~Copyable>(
    with other: borrowing Other
) -> Bool where Other.Element == Element {
    if count <= other.count {
        var disjoint = true
        forEach { element in
            if disjoint, other.contains(element) { disjoint = false }
        }
        return disjoint
    } else {
        var disjoint = true
        other.forEach { element in
            if disjoint, self.contains(element) { disjoint = false }
        }
        return disjoint
    }
}
```

**`intersection`**: Currently iterates `self` (O(n)). Could iterate the smaller set (O(min(n,m))). The result is correct either way (intersection is commutative). Implementation analogous to `isDisjoint`.

Both optimizations are enabled by `count` — an argument for including it as a requirement.

#### 4. `forEach` vs Early-Exit Iteration

`forEach` provides no early return mechanism. This affects relational defaults:

| Operation | Early exit useful? | Impact |
|-----------|-------------------|--------|
| `isDisjoint` | Yes — stop at first shared element | `forEach` continues after answer found |
| `isSubset` | Yes — stop at first missing element | `forEach` continues after answer found |
| `isSuperset` | Yes — stop at first missing element | `forEach` continues after answer found |
| `union` | No | N/A |
| `intersection` | No | N/A |
| `subtract` | No | N/A |
| `symmetricDifference` | No | N/A |

The `if disjoint`/`if result` guard in current defaults skips the O(1) `contains` call after the answer is determined, but `forEach` still iterates remaining elements (O(n) iterations with O(1) no-op per element). The overhead is proportional to the number of remaining elements after the answer is found.

**Theoretical fix**: Replace `forEach` with `contains(where:)` or a short-circuiting iteration primitive. But this would add a fourth protocol requirement for a marginal improvement that only affects relational operations. Conformers with `Swift.Sequence` can override with `for element in self { ... return ... }` for true early exit.

**Verdict**: The `forEach` ceiling is acceptable. Algebra operations (which dominate the new defaults) are unaffected. Relational operations have a bounded overhead (elements after answer × O(1)). Conformers can override for optimal short-circuit.

#### 5. Completeness vs Set Theory

Standard set theory operations and their protocol coverage:

| Set theory | Symbol | Protocol coverage |
|-----------|--------|------------------|
| Empty set | ∅ | Not on protocol (`init()` is variant-specific) |
| Membership | ∈ | `contains` (requirement) |
| Cardinality | \|A\| | `count` (proposed requirement) |
| Subset | ⊆ | `isSubset` (default) |
| Strict subset | ⊊ | `isStrictSubset` (proposed default) |
| Superset | ⊇ | `isSuperset` (default) |
| Strict superset | ⊋ | `isStrictSuperset` (proposed default) |
| Disjointness | A ∩ B = ∅ | `isDisjoint` (default) |
| Union | ∪ | `union` (proposed default) → `Set.Ordered` |
| Intersection | ∩ | `intersection` (proposed default) → `Set.Ordered` |
| Difference | \ | `subtract` (proposed default) → `Set.Ordered` |
| Symmetric diff | △ | `symmetricDifference` (proposed default) → `Set.Ordered` |
| Equality | A = B | Composable: `isSubset(of:) && isSuperset(of:)` |
| Power set | P(A) | Not applicable to runtime types |
| Complement | Aᶜ | Requires universe — not applicable |

**Coverage**: 12/12 applicable operations (equality composable from existing defaults). The protocol achieves complete coverage of standard set theory operations. The only gap is `init()` (empty set construction), which is variant-specific and correctly excluded.

#### 6. Constraint Accuracy

**Protocol declaration constraints**:

```swift
public protocol __SetProtocol: ~Copyable {
    associatedtype Element: Hash.`Protocol` & ~Copyable
```

- `~Copyable` on the protocol: correct — Static/Small are ~Copyable
- `Element: Hash.Protocol & ~Copyable`: correct — elements must be hashable/equatable, may be ~Copyable

**Relational defaults constraint**:

```swift
extension Set.`Protocol` where Self: ~Copyable {
```

- `Self: ~Copyable`: correct — allows both Copyable and ~Copyable conformers
- No `Element: Copyable`: correct — `forEach` provides `borrowing Element`, `contains` takes `borrowing Element`, no copy needed

**Algebra defaults constraint**:

```swift
extension Set.`Protocol` where Self: ~Copyable, Element: Copyable {
```

- `Element: Copyable`: necessary — `Set.Ordered.insert` takes `Element` by value. The `borrowing Element` from `forEach` must be copied to call `insert`. Without Copyable, this implicit copy is not available.

**Verdict**: All constraints are correct and minimal. The Copyable split (relational defaults unconstrained, algebra defaults Copyable-constrained) accurately reflects the underlying requirements.

## Outcome

**Decision**: Option C — add `count` as a third protocol requirement and provide non-mutating algebra as protocol defaults.

### Implementation Record (2026-03-02)

Option C implemented. `count` added to `__SetProtocol` as third requirement. Three relational defaults (`isEmpty`, `isStrictSubset`, `isStrictSuperset`) added to Set Primitives Core. Four algebra defaults (`union`, `intersection`, `subtract`, `symmetricDifference`) added to Set Ordered Primitives. All return `Set<Element>.Ordered`. All 59 tests pass. Zero conformance changes.

Files:
- `Set Primitives Core/Set.Protocol.swift` — added `var count: Index<Element>.Count { get }` requirement
- `Set Primitives Core/Set.Protocol+defaults.swift` — added `isEmpty`, `isStrictSubset`, `isStrictSuperset`; fixed `isDisjoint` complexity annotation from O(min(n,m)) to O(n)
- `Set Ordered Primitives/Set.Protocol+algebra.swift` — NEW: `union`, `intersection`, `subtract`, `symmetricDifference` defaults constrained to `where Self: ~Copyable, Element: Copyable`

### Rationale

1. **Highest leverage**: 1 requirement addition unlocks 7 defaults — 3 relational (`isEmpty`, `isStrictSubset`, `isStrictSuperset`) and 4 algebra (`union`, `intersection`, `subtract`, `symmetricDifference`).

2. **Zero conformance cost**: All four variants already have `var count: Index<Element>.Count { get }` in unconstrained extensions. No new witnesses, no constraint changes, no conditional conformances.

3. **Preserves read-only character**: The protocol remains a query interface. `count` is non-mutating and element-type-agnostic. Algebra operations return new `Set.Ordered` instances — they don't mutate `self`.

4. **Heterogeneous algebra for all variants**: Every set variant gains `union`, `intersection`, `subtract`, `symmetricDifference` for free. `fixed.intersection(small)` works out of the box. This closes the C3 gap (algebra only on Ordered).

5. **Correct return type**: Algebra returning `Set.Ordered` (not `Self`) is semantically correct — the result of `fixed.union(other)` may exceed Fixed's capacity. `Set.Ordered` is the growable container.

6. **Natural module split**: Relational defaults (using only protocol requirements) live in Set Primitives Core. Algebra defaults (constructing `Set.Ordered`) live in Set Ordered Primitives. Each module depends only on what it needs.

7. **C1 does not block**: `insert` error type divergence is irrelevant — algebra operations insert into the concrete result `Set.Ordered` (non-throwing), not into the protocol conformer.

### Deferred: Mutating Algebra (Option D2)

Mutating operations (`formUnion`, mutating `subtract`, `formIntersection`) require `remove` on the conformer. A `Set.Mutable` refinement protocol could provide these, but the leverage is low (1 protocol + 4 conformances for 2 defaults) and the non-mutating algebra covers most use cases. Defer until demand materializes.

`formUnion` remains blocked by C1 even with a refinement protocol — it needs `insert` on self, which has variant-specific error types. This is a genuine architectural difference (growable vs bounded storage) and should not be papered over.

### Implementation Path

**Phase 1: Relational completion** (Set Primitives Core):
1. Add `var count: Index<Element>.Count { get }` to `__SetProtocol`
2. Add `isEmpty`, `isStrictSubset(of:)`, `isStrictSuperset(of:)` defaults to `Set.Protocol+defaults.swift`
3. Update `isDisjoint` complexity documentation to O(n)

**Phase 2: Algebra defaults** (Set Ordered Primitives):
4. Create `Set.Protocol+algebra.swift` with `union`, `intersection`, `subtract`, `symmetricDifference` defaults
5. All defaults constrained to `where Self: ~Copyable, Element: Copyable`
6. All return `Set<Element>.Ordered`

**Phase 3: Validation**:
7. Build + test swift-set-primitives
8. Verify heterogeneous algebra works (e.g., `Fixed.intersection(Small)`)

### Open Questions

1. **Should `isEmpty` be a requirement or a default?** As a default via `count == .zero`, it's correct and O(1) since all variants have O(1) count. A requirement would allow variants with more efficient emptiness checks, but no variant currently benefits from this. Recommend: default.

2. **Should `isDisjoint` iterate the smaller set?** With `count` available, `isDisjoint` could check `self.count <= other.count` and swap iteration order. This achieves true O(min(n,m)). Requires a second implementation path (iterate other + probe self). Low priority — can be added as an optimization.

3. **Should `Set.Ordered` override the protocol algebra defaults?** The concrete `.algebra` accessor accesses `buffer[idx]` directly (bypassing `forEach`). With `@inlinable`, the protocol defaults should inline to equivalent code. Benchmark before adding concrete overrides.

4. **Should the `.algebra` accessor be deprecated?** Protocol defaults provide the same operations as direct methods. Keeping both creates two paths to the same result. Options: (a) deprecate `.algebra`, (b) keep both (`.algebra` as optimized path, protocol defaults as generic path), (c) have `.algebra` delegate to the protocol defaults. Recommend: keep both initially, evaluate after benchmarking.

5. **Should the protocol provide `isEqual(to:)` for heterogeneous set equality?** `a.isSubset(of: b) && a.isSuperset(of: b)` composes set equality from existing defaults, but iterates twice. A dedicated `isEqual(to:)` could short-circuit via `count != other.count`. Low priority.

## References

- `set-protocol-abstraction.md` — v2.0.0, Option B implementation
- `set-contains-performance-restoration.md` — v2.0.0, O(1) restoration
- `Set.Protocol.swift` — current protocol declaration
- `Set.Protocol+defaults.swift` — current defaults
- `Array.Protocol.swift` — precedent for primitives protocol design
- `Set.Ordered.Algebra.swift` — existing algebra operations (Ordered-only)
- `Set.Ordered.Algebra.Symmetric.swift` — symmetric difference
- `Set.Ordered.Error.swift` — variant-specific error types
- Swift stdlib `SetAlgebra.swift` — standard library set protocol
