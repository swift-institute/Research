# Set Protocol Requirements

<!--
---
version: 4.0.0
last_updated: 2026-03-15
status: DECISION
tier: 2
consolidates: [set-protocol-abstraction.md, set-contains-performance-restoration.md, set-insert-error-divergence.md]
---
-->

## Context

swift-set-primitives provides four ordered set variants (`Set.Ordered`, `.Fixed`, `.Static`, `.Small`), each implementing `contains`, `insert`, `remove`, and iteration independently. This document is the consolidated design record for `Set.Protocol` (`__SetProtocol`) — covering why the protocol exists, how `contains` achieves O(1) for ~Copyable elements, what the minimal complete requirements are, and why `insert` cannot be unified.

**Trigger**: During the `Set<String>` → `Set<String>.Ordered` migration in swift-tests, `isDisjoint(with:)` (available on `Swift.Set`) was needed but missing from our set types. This motivated a shared protocol providing `isDisjoint` and other set query operations as default implementations, analogous to `Array.Protocol` in swift-array-primitives.

**Precedent**: `Array.Protocol` (`__ArrayProtocol`) in swift-array-primitives unifies all four array variants behind `subscript` + `Collection.Bidirectional` inheritance. Default implementations for `forEach`, `withElement(at:_:)`, and Property.View integration flow from the protocol. All variants conform with a single empty extension.

---

## §1: Protocol Design

*(from set-protocol-abstraction.md, 2026-03-02)*

### Question

Should we create a `Set.Protocol` that our set types conform to, providing `isDisjoint(with:)` and other set query operations as default implementations?

### Prior Art

**Swift.SetAlgebra** requires:
- `contains(_:) -> Bool` (non-mutating)
- `union(_:) -> Self`, `intersection(_:) -> Self`, `symmetricDifference(_:) -> Self`
- `insert(_:) -> (inserted: Bool, memberAfterInsert: Element)`
- `remove(_:) -> Element?`, `update(with:) -> Element?`
- `init()`, `Equatable`, `ExpressibleByArrayLiteral`

Default implementations: `isSubset(of:)`, `isSuperset(of:)`, `isStrictSubset(of:)`, `isStrictSuperset(of:)`, `isDisjoint(with:)`, `subtract(_:)`, `formUnion(_:)`, `formIntersection(_:)`, `formSymmetricDifference(_:)`, `isEmpty`.

**Rust** `std::collections::HashSet`: `is_disjoint(&self, other: &HashSet) -> bool` — iterates the smaller set, probes the larger. No shared trait; it's a concrete method.

**Array.Protocol** (our precedent): Declared as `__ArrayProtocol` at module scope (hoisted per nested-protocols-in-generic-types research — Swift prohibits protocols inside generic types), aliased via `Array.Protocol`. Requires `subscript` + `Collection.Bidirectional` inheritance. All four array variants conform.

### Constraint Inventory

| Constraint | Description | Affected Variants |
|------------|-------------|-------------------|
| **C1**: `contains` mutating on Small | `Small.contains` was `mutating` (exclusivity workaround for `~Copyable` generics) | Small |
| **C2**: `insert` throws on Fixed/Static | `Fixed.insert` throws `__SetOrderedFixedError`, `Static.insert` throws `__SetOrderedInlineError` | Fixed, Static |
| **C3**: Different error types | Each variant has its own error type for bounds/overflow | All |
| **C4**: ~Copyable unconditional on Static/Small | Static and Small have `deinit`, cannot be Copyable | Static, Small |
| **C5**: Algebra only on Ordered | Set algebra operations (`union`, `intersection`, etc.) currently only exist on `Set.Ordered` | Fixed, Static, Small |
| **C6**: Hoisted protocol requirement | Swift cannot nest protocols in generic types (`Set<Element>`) | All |

**C1 was the critical constraint.** A protocol with `func contains(_:) -> Bool` (non-mutating) could not be satisfied by `Small.contains` (mutating). Small's `contains` called `index(_:)`, which was mutating — a compiler workaround for exclusivity analysis on `~Copyable` generic stored properties.

### Options Evaluated

**Option A: Full Set.Protocol (mirrors SetAlgebra)** — Requires `contains`, `count`, `isEmpty`. Default implementations for `isDisjoint`, `isSubset`, `isSuperset`. **Blocked by C1** (Small's mutating `contains`). Also hit C2 (throwing insert) and C5 (algebra only on Ordered).

**Option B: Minimal Query Protocol (contains-only)** — Only `contains` as requirement, `isDisjoint` and similar pure-query operations as defaults. Same C1 blocker but smaller surface.

**Option C: Protocol with mutating contains** — Accommodate Small by making `contains` mutating in the protocol. All four variants can conform. **Rejected**: forces `var` bindings at every call site, violates user expectations (`contains` is universally non-mutating in Swift), makes generic code awkward.

**Option D: Concrete extensions (no protocol)** — Add `isDisjoint` directly to each concrete type. Pragmatic (ships today, no protocol needed), but code duplication across variants and no generic programming.

**Option E: Fix Small's contains, then Option B** — Fix the root cause (unnecessary `mutating` annotation on Small), then declare `Set.Protocol` per Option B. Best long-term option, dependent on validation.

| Criterion | A: Full | B: Minimal | C: Mutating | D: Concrete | E: Fix + B |
|-----------|---------|------------|-------------|-------------|------------|
| All variants conform | No (Small) | No (Small) | Yes | N/A | Yes |
| isDisjoint as default | Yes | Yes | Yes | Manual | Yes |
| Ergonomic contains | Yes | Yes | No (mutating) | Mixed | Yes |
| Ships today | No | No | Yes | Yes | Maybe |
| Generic set programming | Yes | Yes | Yes (awkward) | No | Yes |
| Code duplication | None | None | None | 4x per operation | None |
| Parallel to Array.Protocol | Full | Partial | Partial | None | Partial |
| Resolves root cause | No | No | No | No | Yes |

### C1 Resolution (2026-03-02)

`Small.index` and `Small.contains` were changed from `mutating` to non-mutating. Build + all 59 tests pass. The `mutating` was legacy — no exclusivity issue exists. `Hash.Table.position(forHash:equals:)` is `borrowing`, `Buffer.Linear.Small` subscript/count/isSpilled are all non-mutating. The closure capture `{ idx in _buffer[idx] == element }` is a pure read.

**C1 is eliminated.** All four variants now have non-mutating `contains`.

### §1 Decision

Option B implemented with ~Copyable support.

`__SetProtocol` declared in Set Primitives Core with `contains` + `forEach` as requirements (later expanded to include `count` — see §3). Default implementations for `isDisjoint(with:)`, `isSubset(of:)`, `isSuperset(of:)`. All four variants conform unconditionally (bare conformance, no `where Element: Copyable`). Static's `contains`/`index` also changed from mutating to non-mutating.

**Experiment**: `swift-institute/Experiments/set-protocol-noncopyable-conformance/` validated three compiler behaviors (F1–F3):

- **F1**: `where Element: ~Copyable` in conformance clause breaks witness matching. Bare `extension T: P {}` works. The struct's `~Copyable` propagates without explicit clause.
- **F2**: Closures consume captured ~Copyable values — no borrowing closure capture. Hash-table-closure pattern (`equals: { idx in buffer[idx] == element }`) cannot be used for `borrowing Element: ~Copyable`. Linear scan was the initial workaround (resolved in §2).
- **F3**: `hashValue` computed property (via `where Self: ~Copyable` extension) not found on generic `T: Hash.Protocol & ~Copyable`. Workaround: call `hash(into:)` directly. (Later found to be experiment-specific — production nested types resolve `hashValue` without issue.)

### Open Questions from §1 (All Resolved)

1. ~~**Should `isDisjoint` accept heterogeneous set types?**~~ **Resolved**: Yes. All defaults use `<Other: Set.Protocol & ~Copyable>` for heterogeneous comparisons.
2. ~~**Should algebra operations move to the protocol?**~~ **Resolved**: Yes. See §3 — algebra as protocol defaults returning `Set.Ordered`, no `associatedtype` needed. `count` added as third requirement, enabling `isStrictSubset`/`isStrictSuperset`/`isEmpty` defaults.
3. ~~**Should `Set.Protocol` inherit from `Sequence.Protocol`?**~~ **Resolved**: No. Three incompatibilities: (a) `Sequence.Protocol` requires `consuming func makeIterator()` — set membership queries must be non-consuming, `forEach` provides borrowing iteration; (b) Set.Protocol conformances are unconditional, but Sequence.Protocol conformances are conditional (`where Element: Copyable`) — inheritance would force unconditional Sequence.Protocol, which doesn't exist; (c) orthogonal concerns — Sequence.Protocol enables lazy composition pipelines, Set.Protocol enables membership queries. Each variant independently conforms to both protocols.

---

## §2: Contains Performance

*(from set-contains-performance-restoration.md, 2026-03-02)*

### Question

What is the optimal architecture for `Set.Protocol.contains` that provides O(1) hash-table lookup as the default for all variants, `~Copyable` element support as first-class (not conditional), and `Copyable` elements getting O(1) without witness ambiguity?

### Root Cause

F2 (from §1): Closures consume captured `~Copyable` values — `borrowing Element` cannot be captured. The old O(1) `contains` relied on `{ idx in buffer[idx] == element }` which captures `element`. All four variants were downgraded to O(n) linear scan. Measurable regression: "Large set operations" test went from 0.29s to 0.79s.

**Key insight**: `index(_ element: Element)` on `Set.Ordered.Static` already uses the closure pattern `{ idx in _buffer[idx] == element }` on a ~Copyable container. It works because `element` is **owned** (not borrowing) and nonescaping closures **borrow** self implicitly. The only difference between `index` (works) and `contains` (doesn't) is parameter convention: `Element` (owned) vs `borrowing Element`.

### Constraint Inventory

| ID | Constraint | Impact |
|----|-----------|--------|
| C1 | Protocol witness: `func contains(_ element: borrowing Element) -> Bool` | Signature is fixed |
| C2 | Closures cannot capture `borrowing` parameters (F2) | `element` must not be captured |
| C3 | Nonescaping closures CAN borrow `self` in non-mutating functions | `buffer[idx]` access works even for ~Copyable self |
| C3a | Extensions of ~Copyable generics get implicit `where Element: Copyable` (F7) | Must use explicit `where Element: ~Copyable` opt-out |
| C4 | `element: Element` (owned) CAN be captured by closures | `index(_ element: Element)` already proves this |
| C5 | Hash.Table stores only Ints (hashes + positions) — element-agnostic | Hash table API is the integration point |
| C6 | Buffer types vary: Ordered/Fixed are class-backed (Copyable ref), Static/Small are inline (~Copyable) | Class-backed: extract ref. Inline: extract pointer or use probe iterator |
| C7 | `element.hashValue` requires owned Element (Hashable) | Must use `hash(into:)` for borrowing elements |

**Key insight**: C2 + C3a together mean closures on ~Copyable containers cannot capture either `borrowing element` (C2) or `self` implicitly (C3a without opt-out). The solution: pass element as a `borrowing Context` parameter (not captured), and capture only Copyable storage handles (pointers, class refs) instead of self.

### Options Evaluated

**Option A: Context-Passing Overload on Hash.Table** — Add `position(forHash:context:equals:)` where the element is passed through as a `borrowing Context` parameter instead of being captured. Single O(1) `contains` per variant, no overloads, no ambiguity.

```swift
extension Hash.Table where Element: ~Copyable {
    public borrowing func position<Context: ~Copyable>(
        forHash hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Index<Element>, borrowing Context) -> Bool
    ) -> Index<Element>?
}
```

**Option B: Probe Iterator on Hash.Table** — Closure-free probing API returning candidate positions. Sidesteps all capture issues. **Rejected**: exposes hash table internals, requires `~Escapable` ProbeSequence, larger API surface.

**Option C: Dual Overloads (Unconstrained O(n) + Copyable O(1))** — Keep O(n) as protocol witness, add Copyable O(1) overload. **Rejected**: call-site ambiguity, ~Copyable elements remain O(n), protocol defaults always use O(n) witness.

**Option D: Single Owned `contains` (Drop `borrowing`)** — Change protocol to `consuming Element`. **Rejected**: destroys the element, fundamentally wrong semantics for a membership query.

| Criterion | A: Context-passing | B: Probe iterator | C: Dual overloads | D: Consuming |
|-----------|-------------------|-------------------|-------------------|--------------|
| O(1) for ~Copyable elements | Yes | Yes | No (O(n)) | Yes |
| O(1) for Copyable elements | Yes | Yes | Yes (overload) | Yes |
| No call-site ambiguity | Yes | Yes | No | Yes |
| Protocol witness is O(1) | Yes | Yes | No (O(n)) | Yes |
| Hash.Table changes | 1 overload | New type + API | None | None |
| Semantic correctness | Yes | Yes | Yes | No (consuming) |
| ~Copyable first-class | Yes | Yes | No | Technically yes |

### Experiment Validation (F7, F8)

- **F7**: Extensions of `~Copyable` generic types get implicit `where Element: Copyable` on ALL extensions — even empty functions. Fix: explicit `& ~Copyable` opt-out on the extension. (Later found to be experiment-specific — production nested types inside `Set<Element>` are not affected.)

- **F8**: ~Copyable container with context-passing lookup **works** when: (a) the extension has explicit `where Element: ~Copyable`, (b) a Copyable storage handle is extracted and captured instead of self, (c) the element is passed as `borrowing Context` parameter. Tested with `NCBuffer<MoveOnlyKey>` — `lookup(20) = true`, `lookup(99) = false`. Build Succeeded.

### §2 Decision

Option A (context-passing overload on Hash.Table).

`position(forHash:context:equals:)` added to `Hash.Table` and `Hash.Table.Static`. All four set variants use O(1) context-passing `contains` as the protocol witness. All 59 tests pass.

**F7/F8 did not apply to production**: The experiment's F7 (implicit `where Element: Copyable` on all extensions) was specific to standalone generic types. Production types are nested inside `Set<Element>` — the generic parameter comes from the outer scope. Extensions of nested types do NOT get implicit Copyable constraints. The closure `{ idx, elem in buffer[idx] == elem }` borrows self directly.

**F3 did not apply**: `element.hashValue` resolves on `borrowing Element` in nested type extensions. All four variants use `element.hashValue` directly.

**Small optimization**: Small uses O(1) hash-table lookup when spilled (via extracted `_heapHashTable!` local to avoid exclusivity conflicts), O(n) linear scan when inline (no hash table in inline mode).

Files changed:
- `Hash.Table+Lookup.swift` — context-passing `position(forHash:context:equals:)` overload
- `Hash.Table.Static+Lookup.swift` — context-passing `position(forHash:context:equals:)` overload
- `Set.Ordered ~Copyable.swift` — O(1) `contains` via `hashTable.position(context:)`
- `Set.Ordered.Fixed.swift` — O(1) `contains` via `hashTable.position(context:)`
- `Set.Ordered.Static.swift` — O(1) `contains` via `_hashTable.position(context:)`
- `Set.Ordered.Small.swift` — O(1) `contains` (spilled) / O(n) (inline)

### Resolved Questions from §2

1. **`hashValue` vs `hash(into:)`**: `element.hashValue` works in nested type extensions — F3 was experiment-specific. Using `element.hashValue` directly.
2. **Hash.Table.Static position type**: Context-passing overload uses `Index<Element>.Bounded<bucketCapacity>`, matching existing API.
3. **Deprecate closure-based API?**: No — it remains useful for cases where element is owned (e.g., `index`, `insert`).

---

## §3: Minimal Complete Requirements

### Question

What is the minimal complete set of primitives for `Set.Protocol` from which all standard set operations can be composed as defaults?

### Current State

**Protocol requirements** (3):

| Requirement | Signature | Constraint |
|------------|-----------|-----------|
| `contains` | `func contains(_ element: borrowing Element) -> Bool` | Unconstrained |
| `forEach` | `func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)` | Unconstrained |
| `count` | `var count: Index<Element>.Count { get }` | Unconstrained |

**Protocol defaults** (10):

| Default | Composed from | Complexity |
|---------|--------------|-----------|
| `isEmpty` | `count` | O(1) |
| `isDisjoint(with:)` | forEach(smaller) + contains(larger) | O(min(n,m)) |
| `isSubset(of:)` | forEach(self) + contains(other) | O(n) |
| `isSuperset(of:)` | forEach(other) + contains(self) | O(m) |
| `isStrictSubset(of:)` | count + isSubset | O(n) |
| `isStrictSuperset(of:)` | count + isSuperset | O(m) |
| `isEqual(to:)` | count + isSubset | O(n) |
| `union(_:)` | forEach(both) → Set.Ordered | O(n+m) |
| `intersection(_:)` | forEach(smaller) + contains(larger) → Set.Ordered | O(min(n,m)) |
| `subtract(_:)` | forEach(self) + contains(other) → Set.Ordered | O(n) |
| `symmetricDifference(_:)` | forEach(both) + contains(both) → Set.Ordered | O(n+m) |

### Compositional Tiers

Standard set operations decompose into tiers based on what primitives they require:

**Tier 0 — Relational queries** (initial):
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
**Blocked by C1**: `insert` signatures diverge across variants (see §4)

Tier 0 → Tier 1 adds one requirement and three defaults.
Tier 1 → Tier 1a adds zero requirements and four defaults (algebra).
Tier 1a → Tier 2 adds one requirement and two defaults but introduces Copyable constraint.
Tier 2 → Tier 3 is blocked by C1 (see §4).

**Key insight**: Non-mutating algebra (Tier 1a) requires NO new protocol requirements. The operations compose from `forEach` + `contains` (Tier 0) and construct `Set.Ordered` results directly. `insert` is only needed on the concrete result type `Set.Ordered`, not on the protocol conformer.

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

All four use only `forEach` and `contains` from the protocol. `insert` is called on the result `Set.Ordered`, not on the conformer.

**Heterogeneous algebra**: This enables algebra across any combination of set types:

```swift
let ordered: Set<String>.Ordered = ["a", "b", "c"]
var fixed: Set<String>.Ordered.Fixed = ["b", "c", "d"]
let result = fixed.intersection(ordered)  // Set<String>.Ordered: ["b", "c"]
```

**Module placement**: Algebra defaults live in Set Ordered Primitives (not Set Primitives Core) because they construct `Set.Ordered` instances and call `insert`. Set Primitives Core only declares the protocol.

**Relationship to existing `.algebra` accessor**: `Set.Ordered` currently has algebra via the `.algebra` accessor pattern (`set.algebra.union(other)`). The protocol defaults provide the same operations as direct methods (`set.union(other)`). For `Set.Ordered`, both paths produce identical results. The concrete `.algebra` implementation accesses `buffer[idx]` directly (bypassing `forEach`), which may be marginally faster. Conformers can override the protocol defaults with optimized concrete implementations.

### Requirement Minimality Analysis

| Requirement | Purpose | Alternatives |
|------------|---------|-------------|
| `contains` | O(1) membership probe | No alternative — fundamental set operation |
| `forEach` | Borrowing iteration | Could use `Sequence.Protocol` inheritance instead. But: sets don't universally conform to `Sequence.Protocol` (Static/Small conform only `where Element: Copyable`). `forEach` in unconstrained extensions is available on all four variants. `forEach` is the minimal iteration primitive. |
| `count` | Cardinality for strict relations + optimization | Could compute via `var c = 0; forEach { _ in c += 1 }`, but O(n) vs O(1). All variants have O(1) count. Requiring it is correct. |

3 requirements is minimal for the proposed defaults. Each serves a distinct, non-redundant purpose.

### Complexity Optimality

| Operation | Proposed complexity | Theoretical optimal | Gap |
|-----------|-------------------|-------------------|-----|
| `contains` | O(1) amortized | O(1) amortized | None |
| `isDisjoint` | O(min(n,m)) | O(min(n,m)) | None — iterates smaller set |
| `isSubset` | O(n) | O(n) | None |
| `isSuperset` | O(m) | O(m) | None |
| `isStrictSubset` | O(n) with count short-circuit | O(n) with count short-circuit | None |
| `isStrictSuperset` | O(m) with count short-circuit | O(m) with count short-circuit | None |
| `isEmpty` | O(1) via count | O(1) | None |
| `union` | O(n+m) | O(n+m) | None |
| `intersection` | O(min(n,m)) | O(min(n,m)) | None — iterates smaller set |
| `subtract` | O(n) | O(n) | None — must iterate self |
| `symmetricDifference` | O(n+m) | O(n+m) | None |

### `forEach` vs Early-Exit Iteration

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

Conformers with `Swift.Sequence` can override with `for element in self { ... return ... }` for true short-circuit. The ceiling is acceptable — algebra operations (which dominate the defaults) are unaffected.

### Completeness vs Set Theory

| Set theory | Symbol | Protocol coverage |
|-----------|--------|------------------|
| Empty set | null | Not on protocol (`init()` is variant-specific) |
| Membership | in | `contains` (requirement) |
| Cardinality | \|A\| | `count` (requirement) |
| Subset | subset | `isSubset` (default) |
| Strict subset | strict subset | `isStrictSubset` (default) |
| Superset | superset | `isSuperset` (default) |
| Strict superset | strict superset | `isStrictSuperset` (default) |
| Disjointness | A intersection B = null | `isDisjoint` (default) |
| Union | union | `union` (default) → `Set.Ordered` |
| Intersection | intersection | `intersection` (default) → `Set.Ordered` |
| Difference | difference | `subtract` (default) → `Set.Ordered` |
| Symmetric diff | symmetric difference | `symmetricDifference` (default) → `Set.Ordered` |
| Equality | A = B | `isEqual` (default), composable: `isSubset(of:) && isSuperset(of:)` |
| Power set | P(A) | Not applicable to runtime types |
| Complement | A-complement | Requires universe — not applicable |

Coverage: 13/13 applicable operations. The only gap is `init()` (empty set construction), which is variant-specific and correctly excluded.

### Constraint Accuracy

**Protocol declaration constraints**:
- `~Copyable` on the protocol: correct — Static/Small are ~Copyable
- `Element: Hash.Protocol & ~Copyable`: correct — elements must be hashable/equatable, may be ~Copyable

**Relational defaults constraint**: `Self: ~Copyable` — allows both Copyable and ~Copyable conformers. No `Element: Copyable` — `forEach` provides `borrowing Element`, `contains` takes `borrowing Element`, no copy needed.

**Algebra defaults constraint**: `Self: ~Copyable, Element: Copyable` — necessary because `Set.Ordered.insert` takes `Element` by value. The `borrowing Element` from `forEach` must be copied to call `insert`.

All constraints are correct and minimal. The Copyable split (relational defaults unconstrained, algebra defaults Copyable-constrained) accurately reflects the underlying requirements.

### Return Type: `Set.Ordered` vs `Self`

| Operation | Result set relationship | `Self` viable? | `Set.Ordered` viable? |
|-----------|----------------------|----------------|----------------------|
| `intersection` | result subset of self | Yes — result fits in self's capacity | Yes |
| `subtract` | result subset of self | Yes — result fits in self's capacity | Yes |
| `union` | result superset of self union other | Only for growable (Ordered, Small) | Yes |
| `symmetricDifference` | result at most \|self\| + \|other\| | Only for growable (Ordered, Small) | Yes |

Returning `Self` for `intersection`/`subtract` requires `init()` + `insert` as protocol requirements (blocked by C1 — see §4) or `copy self` + `remove` (blocked by ~Copyable on Static/Small). Returning `Set.Ordered` is a simplification, not the theoretical ideal. The simplification is justified: (a) it works for all variants uniformly, (b) type information is recoverable, (c) the alternative adds significant protocol complexity.

**Future path**: If C1 is resolved, `intersection` and `subtract` could be upgraded to return `Self`. This is an additive change.

### `remove` Uniformity

Unlike `insert`, `remove` has a uniform signature across all four variants:

| Variant | Signature | Extension constraint |
|---------|-----------|---------------------|
| Ordered | `mutating func remove(_ element: Element) -> Element?` | `where Element: Copyable` |
| Fixed | `mutating func remove(_ element: Element) -> Element?` | `where Element: Copyable` |
| Static | `mutating func remove(_ element: Element) -> Element?` | unconstrained |
| Small | `mutating func remove(_ element: Element) -> Element?` | `where Element: Copyable` |

No error type divergence, no return type divergence. This makes `remove` a candidate for a future refinement protocol (see §4 and §6).

### §3 Decision

Option C — add `count` as a third protocol requirement and provide non-mutating algebra as protocol defaults.

**Rationale**:

1. **Highest leverage**: 1 requirement addition unlocks 8 defaults — 4 relational (`isEmpty`, `isStrictSubset`, `isStrictSuperset`, `isEqual`) and 4 algebra (`union`, `intersection`, `subtract`, `symmetricDifference`).

2. **Zero conformance cost**: All four variants already have `var count: Index<Element>.Count { get }` in unconstrained extensions. No new witnesses, no constraint changes, no conditional conformances.

3. **Preserves read-only character**: The protocol remains a query interface. `count` is non-mutating and element-type-agnostic. Algebra operations return new `Set.Ordered` instances — they don't mutate `self`.

4. **Heterogeneous algebra for all variants**: Every set variant gains `union`, `intersection`, `subtract`, `symmetricDifference` for free. `fixed.intersection(small)` works out of the box.

5. **Correct return type**: Algebra returning `Set.Ordered` (not `Self`) is semantically correct — the result of `fixed.union(other)` may exceed Fixed's capacity.

6. **Natural module split**: Relational defaults in Set Primitives Core. Algebra defaults in Set Ordered Primitives. Each module depends only on what it needs.

7. **C1 does not block**: `insert` error type divergence is irrelevant — algebra operations insert into the concrete result `Set.Ordered` (non-throwing), not into the protocol conformer.

### Implementation Record (2026-03-02)

Option C implemented. `count` added to `__SetProtocol` as third requirement. Four relational defaults (`isEmpty`, `isStrictSubset`, `isStrictSuperset`, `isEqual`) added to Set Primitives Core. Four algebra defaults (`union`, `intersection`, `subtract`, `symmetricDifference`) added to Set Ordered Primitives. All return `Set<Element>.Ordered`. `isDisjoint` and `intersection` optimized to iterate the smaller set (O(min(n,m))). 96 tests pass. Zero conformance changes.

Files:
- `Set Primitives Core/Set.Protocol.swift` — protocol declaration + namespace typealias + `count` requirement
- `Set Primitives Core/Set.Protocol+defaults.swift` — `isDisjoint`, `isSubset`, `isSuperset`, `isEmpty`, `isStrictSubset`, `isStrictSuperset`, `isEqual`
- `Set Ordered Primitives/Set.Protocol+algebra.swift` — `union`, `intersection`, `subtract`, `symmetricDifference` defaults constrained to `where Self: ~Copyable, Element: Copyable`

---

## §4: Insert Error Divergence

*(from set-insert-error-divergence.md, 2026-03-02)*

### Question

Can `insert` signatures be unified across all four set variants? If so, what protocol hierarchy enables mutating algebra as protocol defaults?

### Signature Inventory

**insert** — three dimensions of divergence:

| Variant | Throws | Error type | Return index |
|---------|--------|-----------|-------------|
| Ordered | No | — | `Index<Element>` |
| Fixed | Yes | `__SetOrderedFixedError<Element>` | `Index<Element>` |
| Static | Yes | `__SetOrderedInlineError<Element>` | `Index<Element>.Bounded<capacity>` |
| Small | No | — | `Index<Element>` |

| Dimension | Variants affected | Nature |
|-----------|------------------|--------|
| D1: Throwing vs non-throwing | Fixed, Static throw; Ordered, Small don't | Growable vs bounded storage |
| D2: Error type divergence | Fixed and Static use different error types | Variant-specific overflow semantics |
| D3: Return index type | Static returns `Bounded<capacity>`, others return `Index<Element>` | Compile-time capacity bound |

**remove** — fully uniform: all four variants have `mutating func remove(_ element: Element) -> Element?`. No divergence.

### What C1 Resolution Would Unlock

| Operation | Requires | Current status | C1 resolution enables |
|-----------|----------|---------------|----------------------|
| `formUnion` | `insert` on self | Not available | Default on Set.Growable/Mutable |
| `formSymmetricDifference` | `insert` + `remove` on self | Not available | Default on Set.Growable/Mutable |
| `formSubtract` | `remove` on self | Not available | Already unlockable via `remove` alone |
| `formIntersection` | `remove` on self | Not available | Already unlockable via `remove` alone |
| `intersection` → Self | `init()` + `insert` | Returns `Set.Ordered` | Self-returning on conformers |
| `subtract` → Self | `init()` + `insert` | Returns `Set.Ordered` | Self-returning on conformers |

Key observation: `formSubtract` and `formIntersection` only need `remove` (which is uniform). They don't need C1 resolution at all.

### D1 Analysis: Growable vs Bounded

D1 (throwing vs non-throwing) reflects a genuine architectural difference:
- **Growable** (Ordered, Small): insert always succeeds (storage expands)
- **Bounded** (Fixed, Static): insert may fail (capacity exceeded)

This is not a workaround or legacy — it's the defining characteristic of bounded storage. A protocol that requires non-throwing `insert` cannot accommodate bounded variants. A protocol that requires throwing `insert` forces unnecessary `try` on growable variants.

**Resolution path**: `associatedtype InsertError: Error` with typed throws. Ordered/Small: `InsertError = Never` → `throws(Never)` → non-throwing at call site. Fixed: `InsertError = __SetOrderedFixedError<Element>`.

### D3 Analysis: Bounded Index

Static's `insert` returns `Index<Element>.Bounded<capacity>`, not `Index<Element>`. Resolution: Static provides a second `insert` overload returning `Index<Element>` as the protocol witness. The bounded version remains available for direct Static usage.

### Options Evaluated

**Option A: Two-Tier Refinement (Set.Mutable + Set.Growable)** — `Set.Mutable` with `remove` (all 4 conform), `Set.Growable` with `insert` (only Ordered/Small). Provides `formSubtract`, `formIntersection` on Mutable; `formUnion`, `formSymmetricDifference` on Growable. **Result**: 2 new protocols + 8 conformances for 4 defaults.

**Option B: Single Refinement (Set.Mutable only)** — Only `remove`. Provides `formSubtract`, `formIntersection`. 1 protocol, simpler. No `formUnion`, `formSymmetricDifference`.

**Option C: Accept Divergence (Status Quo)** — Don't create refinement protocols. Non-mutating algebra covers all practical use cases. Mutating algebra as concrete methods on individual variants when needed.

| Criterion | A: Mutable + Growable | B: Mutable only | C: Status quo |
|-----------|----------------------|-----------------|---------------|
| New protocols | 2 | 1 | 0 |
| New conformances | 8 | 4 | 0 |
| New defaults | 4 | 2 | 0 |
| Mutation on Fixed/Static | `formSubtract`, `formIntersection` | Same | None |
| Mutation on Ordered/Small | All 4 form* operations | `formSubtract`, `formIntersection` | None |
| Architectural complexity | High | Medium | None |
| Precedent alignment | No precedent | No precedent | Matches Array.Protocol |

### Value Assessment

The practical demand for mutating protocol defaults is low:

1. **Concrete mutating methods exist**: Each variant already has concrete `insert` and `remove`. Code working with a specific variant type can call them directly.
2. **Generic code over sets is primarily read-only**: The value of `Set.Protocol` is writing functions like `func overlap<A: Set.Protocol, B: Set.Protocol>(_ a: A, _ b: B) -> Bool` — read operations.
3. **Non-mutating algebra covers the generic case**: `fixed.intersection(ordered)` returning `Set.Ordered` is sufficient.
4. **Array.Protocol precedent**: `Array.Protocol` does NOT provide `append`, `remove`, or mutating operations, even though all array variants have them with uniform signatures.

### §4 Decision

Option C — Accept divergence. C1 is a well-understood constraint that correctly reflects the architectural difference between growable and bounded sets.

**Rationale**:

1. **C1 is not a bug**: The insert divergence (throwing vs non-throwing, different error types, bounded vs unbounded index) reflects genuine semantic differences. Growable sets guarantee insertion succeeds. Bounded sets may reject insertions. A protocol that erases this distinction loses safety information.

2. **Non-mutating algebra is implemented**: 4 algebra defaults returning `Set.Ordered` are available on all variants via the protocol.

3. **Mutating operations are concrete**: When working with a known variant type, concrete `insert`/`remove` methods are available with their correct signatures.

4. **Low demand, high cost**: 2 refinement protocols + 8 conformances for 4 defaults that are trivially written at the call site.

5. **Precedent**: Array.Protocol provides read-only access. It does not attempt to unify mutating operations across array variants.

---

## §5: Combined Decision Summary

Four questions have been resolved:

| # | Question | Decision | Section |
|---|----------|----------|---------|
| 1 | Should `Set.Protocol` exist? | Yes — Option B (minimal query protocol), hoisted as `__SetProtocol` | §1 |
| 2 | How to restore O(1) contains with ~Copyable? | Context-passing overload on Hash.Table: `position(forHash:context:equals:)` | §2 |
| 3 | What are the minimal complete requirements? | `contains` + `forEach` + `count` → 10 defaults (3 relational + 4 strict/equality + 4 algebra) | §3 |
| 4 | Can `insert` be unified for mutating algebra? | No — accept divergence; three dimensions (throwing, error type, return index) reflect genuine architectural differences between growable and bounded variants | §4 |

**Final protocol shape**:

```swift
public protocol __SetProtocol: ~Copyable {
    associatedtype Element: Hash.`Protocol` & ~Copyable
    func contains(_ element: borrowing Element) -> Bool
    func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)
    var count: Index<Element>.Count { get }
}
```

3 requirements, 10 defaults (7 relational/equality + 4 algebra returning `Set.Ordered`), unconditional conformance from all four variants, O(1) `contains` for all element types including ~Copyable, heterogeneous algebra across any set type combination.

---

## §6: Open Questions / Future Work

1. **Should `Set.Ordered` override the protocol algebra defaults?** The concrete `.algebra` accessor accesses `buffer[idx]` directly (bypassing `forEach`). With `@inlinable`, the protocol defaults should inline to equivalent code. Benchmark before adding concrete overrides. **Deferred**: needs benchmarking.

2. **Should the `.algebra` accessor be deprecated?** Protocol defaults provide the same operations as direct methods. Keeping both creates two paths to the same result. **Deferred**: depends on Q1 benchmarking. Keep both until data is available.

3. **Set.Mutable refinement protocol**: If demand for generic mutating set operations materializes, Option B from §4 (`Set.Mutable` with `remove` only) is the recommended first step. `remove` is uniform — zero unification issues. Enables `formSubtract` and `formIntersection`. Does not require resolving C1. Additive: compatible with current Set.Protocol. *(from set-insert-error-divergence.md, 2026-03-02)*

4. **Set.Growable refinement protocol**: Should only be pursued if generic `formUnion` across multiple set types becomes a demonstrated need. Depends on `associatedtype InsertError: Error` with typed throws for D1 resolution. *(from set-insert-error-divergence.md, 2026-03-02)*

5. **Self-returning `intersection`/`subtract`**: If C1 is resolved (e.g., unified error type or non-throwing `insert` requirement), these could be upgraded to return `Self` instead of `Set.Ordered`. This is an additive change — the `Set.Ordered`-returning defaults can coexist with `Self`-returning overrides.

6. **`formIntersection` temporary storage**: Any future `formIntersection` default needs temporary storage (can't remove during `forEach` iteration). This is a known constraint of the `forEach`-based composition. *(from set-insert-error-divergence.md, 2026-03-02)*

---

## References

- `Set Primitives Core/Set.Protocol.swift` — protocol declaration + namespace typealias
- `Set Primitives Core/Set.Protocol+defaults.swift` — relational and equality defaults
- `Set Ordered Primitives/Set.Protocol+algebra.swift` — algebra defaults
- `Set.Ordered ~Copyable.swift` — Ordered's borrowing `contains`
- `Set.Ordered.Fixed.swift` — Fixed's borrowing `contains`
- `Set.Ordered.Static.swift` — Static's borrowing `contains`
- `Set.Ordered.Small.swift` — Small's borrowing `contains`
- `Hash.Table+Lookup.swift` — closure-based and context-passing position API
- `Hash.Table.Static+Lookup.swift` — context-passing position API
- `Set.Ordered.Algebra.swift` — existing algebra operations (Ordered-only, via `.algebra` accessor)
- `Set.Ordered.Algebra.Symmetric.swift` — symmetric difference
- `Set.Ordered.Error.swift` — variant-specific error types
- `Array.Protocol.swift` — precedent for primitives protocol design
- Nested protocols research: `swift-institute/Research/nested-protocols-in-generic-types.md`
- ~Copyable conformance experiment: `swift-institute/Experiments/set-protocol-noncopyable-conformance/`
- Hash table context-passing experiment: `swift-institute/Experiments/hash-table-context-passing-lookup/`
- Swift stdlib `SetAlgebra.swift`
