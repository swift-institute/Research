# Array Discipline Boundary Analysis

<!--
---
version: 1.0.0
last_updated: 2026-02-13
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute primitives architecture establishes a strict four-layer dependency chain:

```
Memory (Tier 13) → Storage (Tier 14) → Buffer (Tier 15) → Data Structure (Tier 16+)
```

`array-primitives` sits at the top of this chain, wrapping `Buffer.Linear` (and its variants) to present a consumer-facing array abstraction. The question: does `array-primitives` contain ONLY array-discipline semantics, or has buffer-level concern leaked upward?

**Trigger**: [RES-012] Discovery — proactive design audit to verify layering discipline.

**Scope**: Package-specific (swift-array-primitives).

## Question

What semantics belong SOLELY to the array abstraction layer, and does `array-primitives` currently contain anything that properly belongs to the buffer layer?

---

## Prior Art Survey

### Source 1: Rust `Vec<T>` vs `RawVec` (Rustonomicon)

Rust provides the clearest architectural separation. `RawVec` owns allocation, capacity, growth, and deallocation. `Vec<T>` adds:

- The `len` field and the `len <= cap` invariant enforcement
- Element destructor orchestration in `Drop`
- Slice coercion (`Deref<Target=[T]>`) — all safe slice methods
- All trait implementations: `Clone`, `Eq`, `Ord`, `Hash`, `FromIterator`, `Extend`, `IntoIterator`, `Debug`, `From<[T; N]>`
- Safe public API preventing access to uninitialized memory

**Key**: In our architecture, `Buffer.Linear` is smarter than `RawVec` — it already tracks count, handles element lifecycle, and provides CoW. This means our Array layer is *thinner* than Rust's `Vec`, which is correct.

### Source 2: C++ STL (Stepanov)

Stepanov's STL separates iterators (traversal), containers (storage + access), and algorithms (operations over iterators). `std::vector` adds beyond its allocator:

- **SequenceContainer** concept conformance (position-based insert/erase API)
- **RandomAccessIterator** coordinate structure — O(1) access as a *semantic guarantee*
- Initializer-list construction
- `at()` bounds-checked access (vs `operator[]` unchecked)
- Equality/ordering comparisons
- Iterator invalidation rules as semantic contract

### Source 3: Abstract Data Type Theory (Liskov & Guttag)

The formal ADT specification for Array:

```
Operations: new(n), get(a,i), set(a,i,v), length(a)

Axioms:
  get(set(a,i,v), i) = v                     (read-after-write)
  get(set(a,i,v), j) = get(a,j)  where i≠j  (non-interference)
  length(set(a,i,v)) = length(a)             (set preserves length)
  length(new(n)) = n
```

The ADT mentions NO implementation concerns: no contiguous memory, no capacity, no growth, no pointers. The array is purely the **indexed read-write contract with preservation laws**.

### Source 4: Haskell (Functional Programming)

Arrays as algebraic structures:

- **Representable functor**: `Array i a ≅ (i → a)` — tabulate/index adjunction
- **Functor**: `fmap` preserves length and index structure
- **Foldable/Traversable**: collapse and effectful traversal preserving shape
- **Density invariant**: every index in `[lo..hi]` maps to exactly one element
- **Monoid under concatenation**: `[] ++ xs ++ ys` with identity `[]`

### Source 5: Swift stdlib (`Array` vs `_ArrayBuffer`)

Swift's `_ArrayBuffer` provides ManagedBuffer storage, count/capacity, CoW mechanism, pointer access, and NSArray bridging. `Array<Element>` adds:

- Full Collection protocol hierarchy
- `ExpressibleByArrayLiteral`
- Conditional `Equatable`/`Hashable`/`Codable`/`Sendable`
- Value semantics as a type-level commitment
- Higher-order methods (via Collection)
- `ArraySlice` for range subscripting

---

## Analysis

### What is SOLELY Array Discipline

#### A. Protocol/Interface Conformance

The array's primary contribution: making the indexed-contiguous-storage a **citizen of the type system's protocol hierarchy**. The buffer provides mechanisms; the array provides contracts.

| Conformance | What it provides | Why not in Buffer |
|-------------|-----------------|-------------------|
| `Collection.Protocol` | Multi-pass indexed traversal contract | Buffer disciplines vary (Ring, Slab, Linked); only Array commits to the Collection contract |
| `Collection.Access.Random` | O(1) subscript as semantic *guarantee* | Buffer provides O(1) as implementation *fact*; Array elevates it to obligation |
| `Swift.Collection` | Interop with all stdlib algorithms | Buffer should not carry stdlib coupling |
| `Swift.BidirectionalCollection` | Reverse traversal | Same |
| `Swift.RandomAccessCollection` | Distance in O(1), all random-access algorithms | Same |
| `Sequence.Protocol` | `makeIterator()` contract | Same |
| `Collection.Indexed` (deleted 2026-06) | `startIndex`/`endIndex`/`index(after:)` | The index *navigation* contract is Array's (now via `Collection.Protocol`) |
| `Collection.Bidirectional` | `index(before:)` | Same |
| `ExpressibleByArrayLiteral` | `[1, 2, 3]` syntax | Contested (see below) |

#### B. Semantic Contracts

| Contract | Explanation |
|----------|-------------|
| **Density invariant** | Every index in `[startIndex, endIndex)` maps to an initialized element. No gaps. (A slab has gaps, a ring wraps around, even a linear buffer has uninitialized trailing capacity — the array hides this.) |
| **Ordering preservation** | Insertion order maintained; mutations restore density. |
| **Value semantics commitment** | Buffer provides CoW *mechanism*; array commits to `var b = a; b.append(x)` not affecting `a`. |
| **Capacity independence of identity** | Two arrays with the same elements are equal regardless of capacity. The buffer has no equality concept. |
| **Bounds-checked access as default** | `precondition(index < count)` on every subscript. Buffer provides unchecked access for performance. |
| **Safe access alternatives** | `element(at:) -> Element?` returning Optional. |

#### C. Type-Level Invariants

| Invariant | What it adds |
|-----------|-------------|
| `Array.Fixed` — all-initialized | Buffer.Linear.Bounded tracks partial init; Array.Fixed eliminates partial initialization from the type contract. |
| `Array.Bounded<N>` — compile-time dimension | `Algebra.Z<N>` indices make OOB a type error, not runtime error. |
| `Array.Static<capacity>` — inline commitment | Promise to the user: "this never heap-allocates." |
| Conditional Copyable | `Copyable where Element: Copyable` as a user-facing guarantee. |
| Conditional Sendable | `@unchecked Sendable where Element: Sendable`. |

#### D. Algebraic Structure (not yet implemented but canonically Array's)

| Property | Array owns it |
|----------|---------------|
| Functor (`map`) | Structure-preserving transformation |
| Foldable (`reduce`/`fold`) | Collapse to summary value |
| Traversable | Effectful transformation preserving shape |
| Monoid under `+` | Concatenation with `[]` as identity |
| Equatable/Hashable | Element-wise, capacity-independent |

#### E. Consumer-Facing Ergonomics

| Feature | What it adds |
|---------|-------------|
| Variant taxonomy | Coherent `Array`/`Fixed`/`Static`/`Small`/`Bounded`/`Inline` family |
| Iterator type | `Array.Iterator`, `Array.Fixed.Iterator` wrapping buffer internals |
| Initializer patterns | `Array.Fixed(count:initializingWith:)` |
| `removeAll(keepingCapacity:)` | Boolean flag as user convenience |
| Property.View patterns | `.forEach { }`, `.forEach.borrowing { }`, `.drain { }`, `.forEach.consuming { }` |
| Phantom-typed indexing | `Array.Indexed<Tag>`, `Array.Fixed.Indexed<Tag>`, `Array.Static.Indexed<Tag>`, `Array.Small.Indexed<Tag>` |
| Error descriptions | `CustomStringConvertible` for `Array.Static.Error` |

### What Buffer.Linear Owns (Array Merely Delegates)

| Concern | Owned by Buffer.Linear |
|---------|----------------------|
| Memory allocation/deallocation | Creates/destroys `Storage.Heap` |
| Capacity tracking | `Header.capacity` |
| Count tracking | `Header.count` |
| Growth policy | `Buffer.Growth.Policy` |
| CoW mechanism | `ensureUnique()` |
| Element init/move/deinit lifecycle | Via `Storage` |
| Initialization state tracking | `Storage.Initialization` |
| Raw pointer access | `pointer(at:)` |
| Contiguous memory guarantee | `Span.Protocol` |
| Header state machine | `isEmpty`, `isFull` |
| Unchecked subscript | Direct pointer arithmetic |

---

## Audit: Current array-primitives

### Audit Methodology

For each file in `array-primitives`, classify every public API member as:
- **ARRAY**: Solely array discipline (protocol conformance, semantic contract, type invariant, ergonomics)
- **DELEGATE**: Pure delegation to buffer (thin wrapper calling `_buffer.foo`)
- **CONTESTED**: Could belong to either layer

### Findings

#### Pure Array Discipline (correctly placed)

| Item | Category | Files |
|------|----------|-------|
| `Collection.Protocol` conformance | Protocol | All variant `~Copyable.swift` files |
| `Collection.Access.Random` conformance | Protocol | All variant files |
| `Collection.Indexed` (`startIndex`/`endIndex`/`index(after:)`; deleted 2026-06) | Protocol | All `~Copyable.swift` |
| `Collection.Bidirectional` (`index(before:)`) | Protocol | All `~Copyable.swift` |
| `Swift.Sequence`/`Collection`/`BidirectionalCollection`/`RandomAccessCollection` | Protocol | `Array.Dynamic.swift`, `Array.Fixed Copyable.swift` |
| `Array.Iterator` / `Array.Fixed.Iterator` | Iterator type | `Array.Dynamic.swift`, `Array.Fixed ~Copyable.swift` |
| `Sequence.Protocol` (`makeIterator()`) | Protocol | Multiple files |
| Bounds-checked subscript (`precondition(index < count)`) | Safety contract | All `Copyable.swift` and `~Copyable.swift` |
| `element(at:) -> Element?` | Safe access | All `Copyable.swift` |
| `element(at:offsetBy:) -> Element?` | Safe access | All `Copyable.swift` |
| `withElement(at:_:)` | ~Copyable access | All `~Copyable.swift` |
| `Array.Fixed(count:initializingWith:)` | Initializer pattern | `Array.Fixed.swift` |
| `Array.Fixed(\_\_unchecked:count:initializingWith:)` | Initializer pattern | `Array.Fixed.swift` |
| Conditional `Copyable`/`Sendable` | Type invariant | `Array.swift` |
| `Array.Bounded<N>` with `Algebra.Z<N>` index | Type-level dimension | `Array.Bounded.Index.swift` |
| `Array.Indexed<Tag>` phantom wrappers | Phantom indexing | All `Indexed.swift` files |
| Property.View patterns (`.forEach`, `.drain`) | Ergonomics | All `~Copyable.swift` |
| `ExpressibleByArrayLiteral` | Syntax sugar | `Array+ExpressibleByArrayLiteral.swift` |
| `Array.Static.Error` description | Ergonomics | `Array Static.swift` |
| `Collection.Remove.Last` / `Collection.Clearable` | Protocol | `Array Static.swift` |
| Variant taxonomy and namespace | Architecture | `Array.swift` |

#### Pure Delegation (correctly placed — thin wrappers are the point)

| Item | Delegates to | Verdict |
|------|-------------|---------|
| `var count` → `_buffer.count` | Buffer.Linear.Header | **OK** — Array surface for buffer state |
| `var isEmpty` → `_buffer.isEmpty` | Buffer.Linear.Header | **OK** |
| `var capacity` → `_buffer.capacity` | Buffer.Linear.Header | **OK** |
| `var isFull` → `_buffer.isFull` | Buffer.Linear.Header | **OK** |
| `append(_:)` → `_buffer.append(_:)` | Buffer.Linear | **OK** |
| `removeLast()` → `_buffer.removeLast()` | Buffer.Linear | **OK** |
| `removeAll()` → `_buffer.removeAll()` | Buffer.Linear | **OK** |
| `var span` → `_buffer.span` | Buffer.Linear | **OK** |
| `var mutableSpan` → `_buffer.mutableSpan` | Buffer.Linear | **OK** |
| `withUnsafeBufferPointer` → `_buffer.withUnsafeBufferPointer` | Buffer.Linear | **OK** |
| `withUnsafeMutableBufferPointer` → `_buffer.withUnsafeMutableBufferPointer` | Buffer.Linear | **OK** |
| subscript `_read`/`_modify` → `_buffer[index]` | Buffer.Linear | **OK** — Array adds the precondition |

#### Contested / Observations

| Item | Issue | Assessment |
|------|-------|------------|
| `ExpressibleByArrayLiteral` on `Buffer.Linear` | Buffer.Linear already conforms to `ExpressibleByArrayLiteral`. Array re-implements it. | **MINOR** — both conformances are valid. Buffer needs it for ergonomic direct use. Array needs it for its own type. No action needed; these are on different types. |
| `isSpilled` on `Array.Small` | Exposes buffer implementation detail (inline vs heap). | **CONTESTED** — a user reasonably wants to know if they've spilled. This is a valid consumer-facing diagnostic property. Keep it, but consider whether it leaks buffer abstraction. |
| `Array.Static.Error.overflow` | The error `.overflow` is about exceeding inline buffer capacity. | **OK** — this is array-discipline: "you tried to add an element to a full fixed-capacity array." The array owns the semantic; the buffer implements the check. |
| `removeAll(keepingCapacity:)` | Array adds the `keepingCapacity` parameter that buffer doesn't have. | **ARRAY** — this is consumer ergonomics. The buffer's `removeAll` always keeps capacity; the array adds the option to release. |
| `Array.Small.Iterator` wraps `Buffer.Linear.Small.Iterator` | Thin wrapper adding no logic. | **OK** — provides type identity at the Array level. |
| `Array.Static` delegates `Iterator` as typealias to `Buffer.Linear.Inline.Iterator` | Exposes buffer iterator type directly. | **MINOR LEAK** — the public `Iterator` type reveals `Buffer<Element>.Linear.Inline<capacity>.Iterator` as the concrete type. Consider wrapping like `Array.Small.Iterator` does for consistency. |

### What's MISSING from Array (things that are solely array discipline but not yet present)

| Missing | Category | Priority |
|---------|----------|----------|
| `Equatable where Element: Equatable` | Algebraic | High — capacity-independent equality is core array semantics |
| `Hashable where Element: Hashable` | Algebraic | High — follows from Equatable |
| `map(_:)` returning Array (not lazy) | Functor | Medium — stdlib Collection provides lazy map; eager map is array-specific |
| `RangeReplaceableCollection` | Protocol | Low — complex to implement with ~Copyable |
| Concatenation (`+` operator) | Monoid | Low |
| `Codable where Element: Codable` | Serialization | Low for primitives |
| `CustomStringConvertible` / `CustomDebugStringConvertible` | Ergonomics | Low |
| `insert(at:)` / `remove(at:)` for all variants | SequenceContainer | Medium — Array.Dynamic doesn't expose position-based insert |
| `Array.Fixed.Error` description (like Static has) | Ergonomics | Low |

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: array-primitives is well-layered

The current `array-primitives` package is **overwhelmingly correct** in its separation of concerns. Every public API member falls cleanly into one of:

1. **Protocol conformance** — solely array discipline
2. **Semantic contract** (bounds checking, safe access, type invariants) — solely array discipline
3. **Pure delegation** — thin wrappers with array-level preconditions added

### Specific Recommendations

#### 1. Wrap `Array.Static.Iterator` (Minor)

`Array.Static` exposes `Buffer<Element>.Linear.Inline<capacity>.Iterator` as a public typealias. For consistency with `Array.Small.Iterator` (which wraps), consider creating a thin `Array.Static.Iterator` wrapper. This is cosmetic, not functional.

#### 2. Add `Equatable` / `Hashable` (Medium Priority)

These are core array-discipline semantics (capacity-independent element-wise comparison). Currently absent from all variants.

#### 3. `isSpilled` is acceptable

`Array.Small.isSpilled` exposes a buffer detail, but it's a *diagnostic* property that users legitimately need. The SmallVec pattern's value proposition depends on knowing when you've spilled. Keep it.

#### 4. No buffer concerns have leaked upward

The audit found **zero instances** of array-primitives doing work that properly belongs to the buffer layer. All storage management, growth, CoW, element lifecycle, and contiguous-memory operations are handled by `Buffer.Linear` and its variants. Array's `_buffer` stored property is the only coupling, and it's correctly `package`-scoped.

### Summary Table

| Layer | Concern Count | Assessment |
|-------|:---:|---|
| Pure array discipline | 25+ distinct APIs | Correctly placed |
| Pure delegation | 12 passthrough properties/methods | Correctly placed — thin wrapping is the design intent |
| Buffer concern leaked into array | **0** | Clean separation |
| Array concern missing | 5–9 items | Future work, not a layering violation |

---

## References

- Rustonomicon, "Implementing Vec": `RawVec` / `Vec` separation
- Stepanov & McJones, "Elements of Programming" (2009): coordinate structures
- Liskov & Guttag, "Abstraction and Specification in Program Development": ADT axioms
- Haskell `Data.Array`, `Data.Vector`: Functor/Foldable/Traversable hierarchy
- Swift stdlib `Array.swift`, `_ArrayBuffer.swift`: buffer/array split
- cppreference, "SequenceContainer" named requirement
- `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/theoretical-buffer-primitives-design.md`
