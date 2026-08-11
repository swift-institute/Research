# Set Discipline Boundary Analysis

<!--
---
version: 1.0.0
last_updated: 2026-02-14
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute primitives architecture establishes a strict four-layer dependency chain:

```
Memory (Tier 13) → Storage (Tier 14) → Buffer (Tier 15) → Data Structure (Tier 16+)
```

`set-primitives` sits at the top of this chain, composing `Buffer.Linear` (and its variants) with `Hash.Table` to present a consumer-facing ordered set abstraction. The question: does `set-primitives` contain ONLY set-discipline semantics, or has buffer-level or hash-table-level concern leaked upward?

**Trigger**: [RES-012] Discovery — proactive design audit to verify layering discipline.

**Scope**: Package-specific (swift-set-primitives).

## Question

What semantics belong SOLELY to the set abstraction layer, and does `set-primitives` currently contain anything that properly belongs to the buffer layer or hash-table layer?

---

## Prior Art Survey

### Source 1: Formal ADT Theory (Liskov & Guttag; NIST)

The formal ADT specification for Set:

```
Operations: newset, add(S, x), delete(S, x), member(S, x)

Axioms:
  member(newset, x)       = false                          (empty has no members)
  member(add(S, x), y)    = true          if x = y         (just-added is present)
  member(add(S, x), y)    = member(S, y)  if x ≠ y        (non-interference)
  delete(newset, x)       = newset                         (deleting from empty is identity)
  delete(add(S, x), y)    = S             if x = y         (delete cancels add)
  delete(add(S, x), y)    = add(delete(S, y), x)  if x ≠ y (delete commutes past unrelated add)
  add(add(S, x), x)       = add(S, x)                     (idempotence / uniqueness)
```

The ADT mentions NO implementation concerns: no hash table, no buffer, no contiguous memory, no capacity, no growth policy, no ordering of elements. The set is purely the **membership-test contract with uniqueness and idempotent insertion**.

The critical axiom is the final one: `add(add(S, x), x) = add(S, x)`. This is the **uniqueness invariant** — the single axiom that distinguishes a set from a bag/multiset. Everything else (membership test, delete semantics) follows from this.

### Source 2: Mathematical Set Theory

Classical set theory provides the algebraic operations that a set ADT SOLELY owns:

| Operation | Definition | Notation |
|-----------|-----------|----------|
| Union | A ∪ B = {x : x ∈ A or x ∈ B} | A ∪ B |
| Intersection | A ∩ B = {x : x ∈ A and x ∈ B} | A ∩ B |
| Difference | A \ B = {x : x ∈ A and x ∉ B} | A − B |
| Symmetric Difference | A △ B = (A \ B) ∪ (B \ A) | A △ B |
| Subset | A ⊆ B iff ∀x ∈ A, x ∈ B | A ⊆ B |
| Superset | A ⊇ B iff B ⊆ A | A ⊇ B |
| Disjoint | A and B disjoint iff A ∩ B = ∅ | |
| Equality | A = B iff A ⊆ B and B ⊆ A | |

These are EXCLUSIVELY set-discipline operations. No other data structure (array, buffer, hash table, tree) defines union/intersection/difference as fundamental operations on its type.

### Source 3: Rust `HashSet<T>` vs `BTreeSet<T>`

Rust cleanly separates set discipline from implementation strategy:

**Set-specific operations** (shared by both `HashSet` and `BTreeSet`):
- `insert()`, `remove()`, `contains()` — core membership management
- `union()`, `intersection()`, `difference()`, `symmetric_difference()` — set algebra (return iterators)
- `is_subset()`, `is_superset()`, `is_disjoint()` — set relations
- Uniqueness invariant — `insert()` returns `bool` indicating whether element was new

**Implementation-specific operations** (differ between variants):
- `HashSet`: `reserve()`, `capacity()`, `shrink_to_fit()` — hash table capacity concerns
- `BTreeSet`: No capacity API (tree grows organically)
- `HashSet`: `get_or_insert()`, `entry()` — hash-table ergonomics
- `BTreeSet`: `range()`, `first()`, `last()`, `pop_first()`, `pop_last()` — ordering-dependent

**Key insight**: Both types implement the same set-discipline interface. The underlying data structure (hash table vs B-tree) is an implementation detail that leaks only through performance-related APIs.

### Source 4: C++ STL `std::set` / `std::unordered_set`

C++ separates set semantics from implementation differently:

- `std::set` (red-black tree): `insert`, `erase`, `find`, `count`, `contains` (C++20), `lower_bound`, `upper_bound`, `equal_range`
- `std::unordered_set` (hash table): same core API plus `bucket_count()`, `load_factor()`, `rehash()`

**Set-discipline**: `insert` returns `pair<iterator, bool>` (the bool is the uniqueness signal), `count()` always returns 0 or 1 (never >1). These are the set's uniqueness invariant made explicit.

**Tree-discipline leak in `std::set`**: `lower_bound`, `upper_bound`, `equal_range` expose ordered-tree internals.
**Hash-discipline leak in `std::unordered_set`**: `bucket_count`, `load_factor`, `max_load_factor`, `rehash` expose hash table internals.

### Source 5: Haskell `Data.Set`

Haskell's `Data.Set` (balanced binary tree implementation) provides the cleanest separation:

**Pure set discipline**:
- `member`, `notMember` — membership test
- `insert`, `delete` — mutation
- `union`, `intersection`, `difference` — set algebra
- `isSubsetOf`, `isProperSubsetOf`, `disjoint` — set relations
- `null`, `size` — observation
- `filter`, `partition` — set-specific filtering
- `map` (with caveat: may reduce size due to uniqueness) — functor with uniqueness

**Key insight**: `Data.Set.map` is NOT a standard functor map because it may shrink the set (if the mapping function produces duplicates). This is uniquely set-discipline: the uniqueness invariant interacts with transformation in a way that arrays/buffers never experience.

### Source 6: Swift stdlib `Set<Element>`

Swift's `Set` wraps `_NativeSet` (hash table) and adds:

- `SetAlgebra` protocol conformance: `union`, `intersection`, `symmetricDifference`, `subtracting`, `formUnion`, `formIntersection`, `formSymmetricDifference`, `subtract`
- `isSubset(of:)`, `isSuperset(of:)`, `isStrictSubset(of:)`, `isStrictSuperset(of:)`, `isDisjoint(with:)`
- `insert(_:)` returns `(inserted: Bool, memberAfterInsert: Element)` — uniqueness signal
- `contains(_:)` — O(1) membership test
- Value semantics commitment
- `Equatable`, `Hashable`, `Encodable`, `Decodable`, `ExpressibleByArrayLiteral`

---

## Analysis

### What is SOLELY Set Discipline

#### A. The Uniqueness Invariant

The set's foundational contribution: **no element appears more than once**. This is the single axiom that separates a set from a bag/multiset/array. Every `insert` operation must check for prior membership and reject duplicates. The `(inserted: Bool, index:)` return type is the set making its uniqueness decision observable.

| Invariant | Explanation |
|-----------|-------------|
| **Uniqueness** | `insert(x)` after `insert(x)` does not increase count. `add(add(S,x),x) = add(S,x)`. |
| **Idempotent insertion** | Re-inserting an existing element is a no-op that returns the existing index. |
| **Membership as primary query** | `contains(_:)` is the set's defining operation — not subscript, not iteration. |

Neither `Buffer.Linear` nor `Hash.Table` independently enforce uniqueness. The buffer stores elements without deduplication. The hash table maps hash values to positions but does not own the equality check. The **set layer** is where `hashValue` lookup + `==` comparison are composed into the uniqueness decision.

#### B. Set Algebra Operations

These operations are EXCLUSIVELY set-discipline. No buffer, storage, or hash table defines them:

| Operation | What it provides | Why not in Buffer or Hash.Table |
|-----------|-----------------|-------------------------------|
| `algebra.union(_:)` | A ∪ B — elements in either set | Buffer has `append`/concatenation, not deduplicating union |
| `algebra.intersection(_:)` | A ∩ B — elements in both sets | No buffer or hash table concept |
| `algebra.subtract(_:)` | A \ B — elements in A not in B | No buffer or hash table concept |
| `algebra.symmetric.difference(_:)` | A △ B — elements in exactly one set | No buffer or hash table concept |
| `form(_:)` | Mutating algebra application | Set-level mutation pattern |

#### C. Coordinated Dual-Structure Management

The set's unique architectural contribution is **coordinating two independent lower-layer structures**:

| Concern | What the set coordinates |
|---------|------------------------|
| **Insert**: buffer.append + hashTable.insert | Atomically extends both structures |
| **Remove**: hashTable.remove + buffer.remove + hashTable.positions.decrement | Three-step coordinated removal maintaining consistency |
| **Clear**: buffer.removeAll + hashTable.remove.all | Synchronized reset of both structures |
| **CoW**: buffer.ensureUnique + hashTable.ensureUnique | Coordinated uniqueness check across both stores |
| **Spill (Small)**: _buildHashTable on transition from inline to heap | Constructs hash table index over existing buffer contents |

No single lower-layer component can own this coordination. The buffer does not know about the hash table. The hash table does not know about the buffer. The set is the sole owner of their synchronized lifecycle.

#### D. Semantic Contracts

| Contract | Explanation |
|----------|-------------|
| **Insertion-order preservation** | This is an *ordered set* commitment — elements iterate in the order they were first inserted. Neither buffer (which preserves append order but has no uniqueness) nor hash table (which has no ordering commitment) provides this combined guarantee. |
| **Bounds-checked access as default** | `precondition(index < count)` on every subscript. The buffer provides unchecked access. |
| **Capacity-independent equality** | Two sets with the same elements are equal regardless of capacity or hash table size. |
| **Value semantics commitment** | Buffer provides CoW mechanism; set commits to `var b = a; b.insert(x)` not affecting `a`. |

#### E. Protocol/Interface Conformance

| Conformance | What it provides | Why not in Buffer or Hash.Table |
|-------------|-----------------|-------------------------------|
| `Sequence.Protocol` | `makeIterator()` in insertion order | Set owns the traversal contract for its elements |
| `Sequence.Drain.Protocol` | `.drain { }` pattern | Set-level consumption with hash table cleanup |
| `Sequence.Clearable` | `removeAll()` | Coordinated clear across buffer + hash table |
| `Swift.Sequence` (Copyable) | for-in, map, filter interop | Buffer should not carry stdlib coupling |
| `Hash.Protocol` (Equatable + Hashable) | Element-wise equality, set hashing | Capacity-independent identity |
| `@unchecked Sendable` | Thread-safety declaration | Type-level commitment |
| Conditional `Copyable` | CoW as user-facing guarantee | Type-level commitment |

#### F. Type-Level Invariants

| Invariant | What it adds |
|-----------|-------------|
| `Set.Ordered` — dynamic growth | Unbounded ordered set with CoW |
| `Set.Ordered.Fixed` — fixed capacity | Set with overflow errors as typed throws |
| `Set.Ordered.Static<capacity>` — inline storage | "Never heap-allocates" promise to user |
| `Set.Ordered.Small<inlineCapacity>` — SmallVec | Inline with automatic spill to heap |
| Conditional Copyable | `Copyable where Element: Copyable` |
| Conditional Sendable | `@unchecked Sendable where Element: Sendable` |

#### G. Consumer-Facing Ergonomics

| Feature | What it adds |
|---------|-------------|
| Variant taxonomy | Coherent `Set.Ordered`/`Fixed`/`Static`/`Small` family |
| Iterator types | `Set.Ordered.Iterator`, `Set.Ordered.Fixed.Iterator`, etc. |
| `Set.Ordered.Indexed<Tag>` | Phantom-typed index access for cross-domain safety |
| `Set.Ordered.Fixed.Indexed<Tag>` | Same for Fixed variant |
| Error types | `__SetOrderedError`, `__SetOrderedFixedError`, `__SetOrderedInlineError` with `CustomStringConvertible` |
| `description` | Human-readable set representation |
| `init(_ elements: S)` | Sequence-based initialization with deduplication |
| `init(reservingCapacity:)` | Pre-sized initialization |
| Property.View patterns | `.drain { }`, `.consume().forEach { }` |
| `first` / `last` accessors | Insertion-order endpoints |

### What Buffer.Linear and Hash.Table Own (Set Merely Delegates)

| Concern | Owned by Buffer.Linear |
|---------|----------------------|
| Memory allocation/deallocation | Creates/destroys `Storage.Heap` |
| Capacity tracking | `Header.capacity` |
| Count tracking | `Header.count` |
| Growth policy | `Buffer.Growth.Policy` |
| CoW mechanism | `ensureUnique()` |
| Element init/move/deinit lifecycle | Via `Storage` |
| Raw pointer access | `pointer(at:)` |
| Contiguous memory guarantee | `Span.Protocol` |
| Unchecked subscript | Direct pointer arithmetic |
| `span` / `mutableSpan` | Safe memory view |

| Concern | Owned by Hash.Table |
|---------|-------------------|
| Hash bucket management | Bucket array, collision resolution |
| Position lookup by hash | `position(forHash:equals:)` |
| Position insertion | `insert(__unchecked:position:hashValue:)` |
| Position removal | `remove(hashValue:equals:)` |
| Position adjustment | `positions.decrement(after:)` |
| Hash table growth/rehashing | Internal to Hash.Table |
| `isEmpty` / `isFull` / `count` | Hash table metadata |

---

## Audit: Current set-primitives

### Audit Methodology

For each file in `set-primitives`, classify every public API member as:
- **SET**: Solely set discipline (uniqueness enforcement, set algebra, coordinated dual-structure management, protocol conformance, ergonomics)
- **DELEGATE**: Pure delegation to buffer or hash table (thin wrapper calling `buffer.foo` or `hashTable.foo`)
- **CONTESTED**: Could belong to either layer

### Findings

#### Pure Set Discipline (correctly placed)

| Item | Category | Files |
|------|----------|-------|
| `insert(_:) -> (inserted: Bool, index:)` | **Uniqueness enforcement** | All variant `~Copyable.swift` / `Copyable.swift` files |
| `remove(_:) -> Element?` | **Coordinated removal** (hash table remove + buffer remove + position decrement) | All variant files |
| `contains(_:) -> Bool` | **Membership test** | All variant files |
| `index(_:) -> Index?` | **Membership query** (hash lookup + equality check) | All variant files |
| `algebra.union(_:)` | **Set algebra** | `Set.Ordered.Algebra.swift` |
| `algebra.intersection(_:)` | **Set algebra** | `Set.Ordered.Algebra.swift` |
| `algebra.subtract(_:)` | **Set algebra** | `Set.Ordered.Algebra.swift` |
| `algebra.symmetric.difference(_:)` | **Set algebra** | `Set.Ordered.Algebra.Symmetric.swift` |
| `form(_:)` | **Mutating algebra** | `Set.Ordered.Algebra.swift` |
| `clear(keepingCapacity:)` | **Coordinated clear** (buffer + hash table) | All variant files |
| `makeUnique()` | **Coordinated CoW** (buffer + hash table) | `Set.Ordered Copyable.swift`, `Set.Ordered.Fixed.swift` |
| `_buildHashTable()` | **Spill coordination** | `Set.Ordered.Small.swift` |
| `Sequence.Protocol` conformance | **Protocol** | All variant `Copyable.swift` files |
| `Swift.Sequence` conformance | **Protocol** | `Set.Ordered.Iterator.swift`, `Set.Ordered.Fixed Copyable.swift` |
| `Sequence.Drain.Protocol` conformance | **Protocol** | All `+Sequence.Drain.swift` files |
| `Sequence.Clearable` conformance | **Protocol** | All variant `Copyable.swift` files |
| `Hash.Protocol` (Equatable + Hashable) | **Algebraic identity** | `Set.Ordered Copyable.swift`, `Set.Ordered.Fixed Copyable.swift` |
| Conditional `Copyable` | **Type invariant** | `Set.swift` |
| `@unchecked Sendable` | **Type invariant** | `Set.swift` |
| `Set.Ordered.Iterator` / `Fixed.Iterator` / `Static.Iterator` / `Small.Iterator` | **Iterator types** | Multiple files |
| `Set.Ordered.Indexed<Tag>` | **Phantom indexing** | `Set.Ordered.Indexed.swift` |
| `Set.Ordered.Fixed.Indexed<Tag>` | **Phantom indexing** | `Set.Ordered.Fixed.Indexed.swift` |
| `init(_ elements: S)` | **Deduplicating init** | `Set.Ordered Copyable.swift` |
| `init(reservingCapacity:)` | **Ergonomics** | `Set.Ordered Copyable.swift` |
| Error types + descriptions | **Typed error hierarchy** | `Set.Ordered.Error.swift` |
| `description` | **Ergonomics** | `Set.Ordered Copyable.swift` |
| `first` / `last` | **Insertion-order access** | All variant files |
| `withElement(at:_:)` | **Bounds-checked ~Copyable access** | All variant `~Copyable.swift` / `.swift` files |
| `forEach(_:)` (borrowing) | **Traversal contract** | All variant files |
| `drain(_:)` | **Consuming traversal with hash table cleanup** | All variant files |
| `consume()` | **Ownership transfer** | All `+Sequence.Consume.swift` files |
| `drain` (Property.View accessor) | **Ergonomics** | All `+Sequence.Drain.swift` files |
| Bounded index `Index<Element>.Bounded<capacity>` on Static | **Type-level bounds safety** | `Set.Ordered.Static.swift` |
| Variant namespace (`Set.Ordered`/`Fixed`/`Static`/`Small`) | **Architecture** | `Set.swift` |
| `element(at:)` (throwing) | **Safe bounds-checked access** | All variant files |
| Bounds-checked subscript (`precondition(index < count)`) | **Safety contract** | All variant files |

#### Pure Delegation (correctly placed — thin wrappers are the point)

| Item | Delegates to | Verdict |
|------|-------------|---------|
| `var count` -> `buffer.count` / `_buffer.count` | Buffer.Linear.Header | **OK** — Set surface for buffer state |
| `var isEmpty` -> `buffer.isEmpty` / `_hashTable.isEmpty` | Buffer or Hash.Table | **OK** |
| `var capacity` -> `buffer.capacity` / `_buffer.capacity` | Buffer.Linear.Header | **OK** |
| `var isFull` -> `buffer.count >= maximumCapacity` / `_hashTable.isFull` | Buffer + maximumCapacity / Hash.Table | **OK** |
| `reserve(_:)` -> `buffer.reserveCapacity(_:)` | Buffer.Linear | **OK** |
| `withSpan(_:)` -> `buffer.span` | Buffer.Linear | **OK** |
| `withMutableSpan(_:)` -> `buffer.mutableSpan` | Buffer.Linear | **OK** |
| `withUnsafeBufferPointer` -> `buffer.span.withUnsafeBufferPointer` | Buffer.Linear | **OK** (behind `@_spi(Unsafe)`) |
| `withUnsafeMutableBufferPointer` -> `buffer.mutableSpan.withUnsafeMutableBufferPointer` | Buffer.Linear | **OK** (behind `@_spi(Unsafe)`) |
| `var underestimatedCount` -> `Int(bitPattern: count)` | Passthrough | **OK** |
| `removeAll()` -> `clear(keepingCapacity: false)` | Self | **OK** — Sequence.Clearable adapter |

#### Contested / Observations

| Item | Issue | Assessment |
|------|-------|------------|
| `isSpilled` on `Set.Ordered.Small` | Exposes buffer implementation detail (inline vs heap). | **CONTESTED** — a user reasonably wants to know if they have spilled. This is a valid consumer-facing diagnostic property. The SmallVec pattern's value proposition depends on knowing when you have spilled. Keep it, but note it as an intentional abstraction puncture. |
| `withMutableSpan(_:)` | Warning: "Modifying elements through this span may invalidate the hash table. Only use for in-place updates that preserve element identity/hash." | **CONTESTED** — this is a valid escape hatch but exposes the dual-structure invariant to the user. The warning is appropriate. The alternative (not providing it) would force users through unsafe buffer pointer access. Acceptable with the documented contract. |
| `buffer` / `hashTable` as `public var` on `Set.Ordered` and `Set.Ordered.Fixed` | Stored properties are `public`, exposing the buffer and hash table directly. | **LEAK** — users can directly manipulate `buffer` and `hashTable`, bypassing the set's uniqueness invariant and coordinated management. This allows inserting duplicates into the buffer without updating the hash table, or corrupting the hash table without corresponding buffer changes. See recommendation below. |
| `Algebra` stores `Buffer<Element>.Linear` directly | The `Algebra` struct captures the buffer (not the set), reading elements directly from `buffer[index]`. | **MINOR** — this is an implementation choice to avoid consuming the set. Since Algebra only reads and creates new sets (using `insert` which enforces uniqueness), correctness is preserved. |
| `symmetric.difference` uses linear scan instead of hash lookup | The "check if element is in self" loop in `Algebra.Symmetric.difference` iterates over `buffer` with O(n) linear comparison instead of using hash table lookup. | **BUG** — this is O(n*m) instead of the expected O(n+m). The `Algebra` struct only stores the buffer, not the hash table, so it cannot use `contains()`. See recommendation below. |
| Algebra only on `Set.Ordered` | `Set.Ordered.Fixed`, `Static`, and `Small` have no algebra operations. | **MISSING** — set algebra is a core set-discipline operation. At minimum, union/intersection/difference/symmetric-difference should be available on all variants (producing `Set.Ordered` as the return type). |
| `description` only on `Set.Ordered` (Copyable) | Other variants lack `CustomStringConvertible`. | **MINOR** — low priority ergonomics gap. |

### What's MISSING from Set (things that are solely set discipline but not yet present)

| Missing | Category | Priority |
|---------|----------|----------|
| `isSubset(of:)` | Set relation | High — fundamental set operation |
| `isSuperset(of:)` | Set relation | High — fundamental set operation |
| `isDisjoint(with:)` | Set relation | High — fundamental set operation |
| `isStrictSubset(of:)` | Set relation | Medium |
| `isStrictSuperset(of:)` | Set relation | Medium |
| Algebra on `Fixed`/`Static`/`Small` | Set algebra | Medium — core set discipline, currently only on `Ordered` |
| `filter(_:) -> Set.Ordered` | Set-specific filter (preserving uniqueness) | Medium |
| `map(_:) -> Set.Ordered` (with caveat: may reduce size) | Set functor | Low — tricky semantics (uniqueness after transform) |
| `SetAlgebra`-style protocol conformance | Protocol | Low — Swift's `SetAlgebra` requires `Equatable` on `Self`, not elements |
| `update(with:)` / `replace-or-insert` | Idempotent mutation | Low |
| `RangeReplaceableCollection`-style APIs | Protocol | Low — complex with set uniqueness |
| `Codable where Element: Codable` | Serialization | Low for primitives |
| `ExpressibleByArrayLiteral` | Syntax sugar | Low |

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: set-primitives is well-layered with two actionable issues

The current `set-primitives` package is **overwhelmingly correct** in its separation of concerns. The set layer's primary contribution — the **uniqueness invariant** and **coordinated dual-structure management** (buffer + hash table) — is cleanly implemented. Every `insert` checks membership before appending. Every `remove` coordinates hash table removal, buffer removal, and position decrement. Set algebra operations exist and are correctly placed.

However, the audit identified two issues that warrant attention.

### Specific Recommendations

#### 1. Restrict `buffer` and `hashTable` visibility on `Set.Ordered` and `Set.Ordered.Fixed` (High Priority)

`Set.Ordered` declares:
```swift
public var buffer: Buffer<Element>.Linear
public var hashTable: Hash.Table<Element>
```

And `Set.Ordered.Fixed` declares:
```swift
public var buffer: Buffer<Element>.Linear.Bounded
public var hashTable: Hash.Table<Element>
```

These should be `package` (or at minimum `public private(set)`) rather than fully `public`. Direct mutation of either stored property bypasses the set's uniqueness invariant and coordinated lifecycle management. A user calling `set.buffer.append(element)` can introduce duplicates. A user calling `set.hashTable.remove(...)` without updating the buffer corrupts the data structure.

The `Static` and `Small` variants correctly use `package var _buffer` and `package var _hashTable` — the dynamic variants should follow the same pattern.

**Recommendation**: Change to `package var` on both `Ordered` and `Ordered.Fixed`, matching the convention of `Static` and `Small`.

#### 2. Fix `Algebra.Symmetric.difference` performance (Medium Priority)

The current `symmetric.difference` implementation is O(n*m):

```swift
// In Set.Ordered.Algebra.Symmetric.difference:
var selfIndex: Index<Element> = .zero
while selfIndex < end {
    if buffer[selfIndex] == element {  // O(n) linear scan
        found = true
        break
    }
    selfIndex += .one
}
```

The `Algebra` struct stores only `Buffer<Element>.Linear`, not the hash table, so it cannot call `contains()` with O(1) lookup. Two options:

- **Option A**: Have `Algebra` store a reference to the full `Set.Ordered` (or at least both the buffer and hash table) so it can use O(1) containment checks.
- **Option B**: Reconstruct a temporary `Set.Ordered` from the buffer to leverage `contains()`.

Option A is preferred for correctness and performance.

#### 3. Add Set Relations: `isSubset`, `isSuperset`, `isDisjoint` (Medium Priority)

These are core set-discipline operations present in every major set implementation (Rust, C++, Haskell, Swift stdlib). They are mathematically fundamental and belong solely to the set layer. Currently absent from all variants.

#### 4. Extend Algebra to All Variants (Low Priority)

Currently `algebra` is only available on `Set.Ordered`. The `Fixed`, `Static`, and `Small` variants should also support set algebra operations. The return type can be `Set.Ordered` (heap-allocated) since algebra operations produce new sets of unpredictable size.

#### 5. `isSpilled` is acceptable (No Action)

`Set.Ordered.Small.isSpilled` exposes a buffer detail, but it is a *diagnostic* property that users legitimately need. The SmallVec pattern's value proposition depends on knowing when you have spilled. Keep it.

#### 6. `withMutableSpan` warning is sufficient (No Action)

The documented warning about hash table invalidation is the correct approach. Removing `withMutableSpan` entirely would be too restrictive. The `@_spi(Unsafe)` annotation on `withUnsafeBufferPointer`/`withUnsafeMutableBufferPointer` shows the right graduation: safe but dangerous gets a warning, truly unsafe gets `@_spi`.

### Summary Table

| Layer | Concern Count | Assessment |
|-------|:---:|---|
| Pure set discipline | 35+ distinct APIs | Correctly placed |
| Pure delegation | 11 passthrough properties/methods | Correctly placed — thin wrapping is the design intent |
| Buffer/hash-table concern leaked into set | **0** | Clean separation |
| Set concern leaked downward (buffer doing set work) | **0** | Clean separation |
| Visibility issue | 2 stored properties (`buffer`, `hashTable`) | `public` should be `package` |
| Performance issue | 1 (`symmetric.difference` is O(n*m)) | `Algebra` needs hash table access |
| Set discipline missing | 5-8 items | Future work, not a layering violation |

### Architectural Note: Set as Composition Layer

The most significant observation from this audit is that `set-primitives` demonstrates a **composition pattern** distinct from `array-primitives`. Where `Array` wraps a single `Buffer.Linear`, `Set.Ordered` composes TWO independent primitives (`Buffer.Linear` + `Hash.Table`) and owns their synchronized lifecycle. This dual-structure coordination is the set layer's defining architectural contribution. No single lower-level primitive can provide it.

```
Set.Ordered
  |-- Buffer.Linear     (element storage, ordered by insertion)
  |-- Hash.Table         (O(1) position lookup by hash value)
  |
  +-- Set layer owns: uniqueness enforcement, coordinated insert/remove/clear,
      set algebra, insertion-order preservation, dual-CoW management
```

This composition pattern is a strong argument for the set layer's existence: it is not merely a "thin wrapper" but a genuine **coordination layer** that provides invariants impossible to express in either component alone.

---

## References

- Liskov & Guttag, "Abstraction and Specification in Program Development": Set ADT axioms
- NIST Dictionary of Algorithms and Data Structures: [Abstract Data Type](https://xlinux.nist.gov/dads/HTML/abstractDataType.html)
- [Set (abstract data type) — Wikipedia](https://en.wikipedia.org/wiki/Set_(abstract_data_type))
- [Rust `HashSet` — Rust by Example](https://doc.rust-lang.org/rust-by-example/std/hash/hashset.html)
- [Rust `BTreeSet` — std::collections](https://doc.rust-lang.org/std/collections/struct.BTreeSet.html)
- [Haskell `Data.Set` — Hackage](https://hackage.haskell.org/package/containers/docs/Data-Set.html)
- [C++ `std::unordered_set` — cppreference](https://en.cppreference.com/w/cpp/container/unordered_set.html)
- [C++ `std::set` — cppreference](https://en.cppreference.com/w/cpp/container/set.html)
- [Stanford: The Set Data Model (Chapter 7)](http://infolab.stanford.edu/~ullman/focs/ch07.pdf)
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-discipline-boundary-analysis.md`
