# Buffer Algebraic Structure

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
tier: 3
---
-->

## Context

During the refactoring of `swift-pointer-primitives` to model `Pointer<T>` and `Pointer<T>.Mutable` as Tagged typealiases (confirmed by the `tagged-mutable-ambiguity` experiment), a broader design question arose: **Can this algebraic modeling be extended to buffer types?**

The current primitives architecture models scalar pointer types algebraically:

| Type | Definition | Algebraic Role |
|------|-----------|----------------|
| `Memory.Address` | `Tagged<Memory, Ordinal>` | Affine point (position) |
| `Memory.Address.Mutable` | `Tagged<Memory.Mutable, Ordinal>` | Affine point (mutable position) |
| `Memory.Address.Offset` | `Tagged<Memory, Affine.Discrete.Vector>` | Affine displacement vector |
| `Memory.Address.Count` | `Tagged<Memory, Cardinal>` | Affine magnitude |
| `Pointer<T>` | `Tagged<T, Memory.Address>` | Typed affine point |
| `Pointer<T>.Mutable` | `Tagged<T, Memory.Address.Mutable>` | Typed mutable affine point |

However, buffer types remain ad-hoc structs:

```swift
// Memory.Address.Buffer: stores (_start: Memory.Address, _count: Memory.Address.Count)
// Pointer<T>.Buffer: stores (_base: UnsafeBufferPointer<Pointee>)
```

**Trigger**: User question during pointer refactoring: "Should we perhaps first also make Buffer a Tagged typealias in memory-primitives?" and "Are buffers similar to Memory.Address in that they should obey (affine?) arithmetic?"

**Precedent risk**: HIGH — Buffer types appear in memory-primitives, pointer-primitives, and all collection types. This decision affects the algebraic foundation of the entire primitives layer.

**Constraints**:
- Must support `~Copyable` element types
- Must not import Foundation ([PRIM-FOUND-001])
- Must follow [API-NAME-001] Nest.Name pattern
- Must maintain zero-cost abstraction (no runtime overhead vs current structs)
- `Tagged<Tag, RawValue>` has no constraint on `RawValue` — composite types are permitted

**Dependencies**: This research builds on the confirmed `address-as-tagged-ordinal` experiment (memory-primitives) and the `tagged-mutable-ambiguity` experiment (pointer-primitives).

---

## Question

Should memory buffer types (`Memory.Address.Buffer`, `Pointer<T>.Buffer`) be modeled as Tagged typealiases backed by an affine interval primitive, rather than as ad-hoc structs storing `(start, count)`?

**Sub-questions**:
1. What algebraic structure do buffers exhibit? Are they affine intervals, regions, or something else?
2. If buffers are intervals, what operations should the interval type support?
3. Does a Tagged typealias for buffers provide algebraic operations "for free" (as it does for scalar pointers)?
4. What are the costs of the additional abstraction layer?
5. Should buffer mutability follow the same phantom-tag pattern as scalar pointers?

---

## Prior Art Survey

### Swift Standard Library

Swift's `UnsafeBufferPointer<Element>` and `UnsafeMutableBufferPointer<Element>` model typed contiguous memory regions:

```swift
struct UnsafeBufferPointer<Element>: ~Escapable {
    let _position: UnsafePointer<Element>?
    let count: Int
}
```

**Key characteristics**:
- Stores a base pointer and count — two values, not one
- Provides `Collection` conformance (indexed access)
- `baseAddress` returns `Optional<UnsafePointer<Element>>`
- No algebraic operations on the buffer-as-interval (no union, intersection, containment)
- Buffer pointer arithmetic is element-strided, not byte-strided

`UnsafeRawBufferPointer` is the untyped equivalent, storing `(_position: UnsafeRawPointer?, count: Int)`.

**Observation**: The stdlib treats buffers as opaque containers, not as algebraic objects. No interval arithmetic exists.

### Swift `Span<Element>` (SE-0447)

`Span` is a safe, non-escapable view into contiguous memory:

```swift
struct Span<Element: ~Copyable>: Copyable, ~Escapable {
    // Internal: pointer + count
}
```

**Key characteristics**:
- `~Escapable` — lifetime-bound to source
- Provides `extracting(_:)` for sub-span creation (analogous to interval intersection/restriction)
- No algebraic operations on the span-as-interval
- Conceptually a "read-only interval view" into memory

### C++ `std::span<T>`

C++20's `std::span<T>` stores `(pointer, size)`:

```cpp
template<class T, size_t Extent = dynamic_extent>
class span {
    pointer data_;
    size_type size_;
};
```

- `subspan<Offset, Count>()` — compile-time sub-interval extraction
- No algebraic interval operations
- Used as a lightweight, non-owning view

### C++ mp-units: Affine Space Design

The mp-units library (P3045, proposed for C++ standardization) provides the most rigorous affine space modeling in a production library:

- **`quantity`** — displacement vector (can be added, subtracted, scaled)
- **`quantity_point`** — absolute position relative to an origin

**Critical insight**: mp-units explicitly separates points from vectors but does NOT model intervals as a first-class algebraic type. Intervals would be a pair of `quantity_point` values or a `quantity_point` with a `quantity` magnitude — but mp-units leaves this as application-level composition.

### Rust: Slices and Ranges

Rust models contiguous memory views as built-in slice types:

```rust
&[T]        // immutable slice
&mut [T]    // mutable slice
Range<usize> // start..end
```

**Key characteristics**:
- Slices are fat pointers: `(pointer, length)` — same two-value structure
- `Range<T>` is a struct with `start: T` and `end: T`
- Slices support sub-slicing but no interval algebra
- `PhantomData<T>` provides zero-cost phantom typing (analogous to `Tagged`)

Rust does not model slices as algebraic intervals. Slices are opaque views.

### Haskell: `Data.Vector`

Haskell's vector library stores `(ForeignPtr, offset, length)` — three values:

```haskell
data Vector a = Vector {-# UNPACK #-} !Int    -- offset
                       {-# UNPACK #-} !Int    -- length
                       {-# UNPACK #-} !(ForeignPtr a)
```

- `slice :: Int -> Int -> Vector a -> Vector a` — sub-interval extraction
- No algebraic interval operations on the vector-as-interval
- Emphasizes fusion and stream processing over interval manipulation

### Interval Arithmetic Libraries

Several libraries model intervals as algebraic objects:

**Haskell `Data.IntervalMap`**:
- `Interval a = Interval { low :: a, high :: a }`
- Supports union, intersection, containment, overlap testing
- Used for interval trees, scheduling, computational geometry

**C++ Boost.ICL (Interval Container Library)**:
- `interval<T>` with closed/open/half-open variants
- Full interval algebra: union (`+`), intersection (`&`), difference (`-`)
- Interval sets and interval maps
- Models the "interval" concept with rich algebraic structure

**Key finding**: Interval arithmetic is well-studied but typically applied to *value-space* intervals (numeric ranges for scheduling, geometry, constraint solving). Application to *memory regions* as typed algebraic objects is uncommon in the literature.

### Region-Based Memory Management (Tofte & Talpin, 1997)

Tofte and Talpin formalized region-based memory management where:
- Memory is partitioned into **regions** (contiguous blocks)
- Values are allocated within regions
- Regions are deallocated atomically (no individual frees)

**Algebraic structure of regions**:
- Regions have a natural containment ordering (sub-region ⊆ region)
- Region operations: allocate-within, deallocate-region
- No arithmetic on regions (no "add two regions")

**Connection to buffers**: A buffer *is* a named region with a start address and extent. However, Tofte-Talpin regions are about *lifetime management*, not *interval arithmetic*. The algebraic structure is lattice-theoretic (containment), not affine (position + displacement).

### Affine Types for Resource Management (Tov & Pucella, POPL 2011)

The Alms language provides practical affine types:
- Affine types forbid duplication (use at most once)
- Applied to resource management: file handles, channels, memory buffers
- Buffers are affine *values* (ownership tracking) — the type system governs *how many times* a buffer can be used, not the *algebraic structure* of the buffer's extent

**Key distinction**: "Affine types" in the Tov-Pucella sense refers to **resource usage tracking** (linear/affine logic). "Affine space" in our context refers to the **geometric/algebraic structure** of position + displacement. These are different uses of the word "affine."

---

## Theoretical Grounding

### Affine Space Theory

An **affine space** (A, V, +) consists of:
- A set of **points** A
- A **vector space** V (the associated displacement space)
- A **free and transitive group action** +: A × V → A

With the derived operation:
- −: A × A → V (displacement between points)

**Axioms**:
1. ∀a ∈ A, ∀v ∈ V: (a + v₁) + v₂ = a + (v₁ + v₂)
2. ∀a ∈ A: a + 0 = a
3. ∀a, b ∈ A: ∃! v ∈ V such that a + v = b

In the primitives architecture:
- **Points** = `Tagged<Tag, Ordinal>` (positions)
- **Vectors** = `Tagged<Tag, Affine.Discrete.Vector>` (displacements)
- **Magnitudes** = `Tagged<Tag, Cardinal>` (unsigned distances)

These satisfy the affine axioms and this structure is already implemented in `Tagged+Affine.swift`.

### What Algebraic Structure Do Intervals Have?

An **interval** [a, a+n) in an affine space is defined by:
- A **start point** a ∈ A
- A **magnitude** n ∈ ℕ (or equivalently an **end point** b = a + n)

**Interval operations and their algebraic properties**:

| Operation | Signature | Algebraic Property |
|-----------|-----------|-------------------|
| Translate | I + v → I' | Group action of V on Intervals |
| Length | I → ℕ | Homomorphism to magnitudes |
| Contains | I × A → Bool | Characteristic function |
| Overlap | I × I → Bool | Symmetric relation |
| Intersection | I × I → I? | Partial operation (may be empty) |
| Union | I × I → I? | Partial operation (may have gap) |
| Sub-interval | I × (offset, count) → I | Restriction/slicing |

**Critical observation**: Intervals do NOT form a group or vector space. They are not closed under most operations. The key operations are:

1. **Translation by a vector** (free action): [a, a+n) + v = [a+v, a+v+n)
2. **Sub-interval extraction** (restriction): [a, a+n).extracting(offset: k, count: m) = [a+k, a+k+m)

These are the operations that buffers actually use in practice.

### Category-Theoretic Perspective

From a category-theoretic viewpoint:

**As a functor**: If we define an interval type `Interval<P, M>` parameterized by point type P and magnitude type M, it acts as a **bifunctor**:
- Covariant in P (translating the start point)
- Invariant in M (the count is preserved under translation)

**As a product type**: An interval is fundamentally a **product** (P × M) — a pair of a point and a magnitude. In the Tagged framework:
- `Tagged<Tag, P × M>` where P = Ordinal, M = Cardinal

**Problem**: Tagged wraps a *single* RawValue. For a product, we need `RawValue = SomeStruct { start: Ordinal, count: Cardinal }`.

This is structurally different from scalar `Tagged<Tag, Ordinal>` where RawValue is atomic. The phantom typing still works (Tag distinguishes interval domains), but the "free algebraic operations" from `Tagged+Affine.swift` do NOT automatically extend to intervals because the arithmetic operators are defined for `RawValue == Ordinal` and `RawValue == Affine.Discrete.Vector`, not for composite RawValues.

### Type-Theoretic Analysis

**Current buffer typing**:

```
Γ ⊢ buf : Memory.Address.Buffer
────────────────────────────────── (T-BufStart)
Γ ⊢ buf.start : Memory.Address

Γ ⊢ buf : Memory.Address.Buffer
────────────────────────────────── (T-BufCount)
Γ ⊢ buf.count : Memory.Address.Count
```

**Hypothetical Tagged buffer typing**:

```
Γ ⊢ buf : Tagged<Memory, Interval>
────────────────────────────────────────── (T-TagBufStart)
Γ ⊢ buf.rawValue.start : Ordinal

Γ ⊢ buf : Tagged<Memory, Interval>
────────────────────────────────────────── (T-TagBufCount)
Γ ⊢ buf.rawValue.count : Cardinal
```

**Observation**: The Tagged version adds one level of indirection (`rawValue`) without providing additional type safety — the phantom tag `Memory` already exists on the struct version's stored properties (`_start: Memory.Address` already carries the `Memory` tag).

---

## Systematic Literature Review

### Research Questions

**RQ1**: Do existing type-safe memory systems model buffer/region extents as algebraic interval types?

**RQ2**: What interval operations are meaningful for memory buffers in practice?

**RQ3**: Does modeling buffers as algebraic intervals provide measurable benefits (type safety, reduced bugs, ergonomics)?

### Search Strategy

**Databases**: ACM Digital Library, arXiv, Semantic Scholar, Swift Forums, Rust RFCs, C++ proposals

**Keywords**: ("buffer" OR "memory region" OR "slice") AND ("algebraic" OR "interval" OR "affine") AND ("type" OR "type system" OR "formal")

**Date range**: 2000–2026

### Inclusion/Exclusion Criteria

**Include**:
- Language/type system designs that model memory regions algebraically
- Libraries providing typed interval arithmetic
- Papers on region-based memory management with formal treatment
- Production implementations of typed buffer abstractions

**Exclude**:
- Numerical interval arithmetic (e.g., verified floating-point)
- Application-level scheduling/geometry interval trees
- Memory allocator implementations without type-level modeling
- Concurrent memory models (store buffers, TSO/PSO)

### Search Results and Screening

| # | Source | Title | Include | Reason |
|---|--------|-------|---------|--------|
| 1 | Tofte & Talpin (1997) | Region-Based Memory Management | Yes | Foundational region typing |
| 2 | Tov & Pucella (2011) | Practical Affine Types | Yes | Affine resource management |
| 3 | Wadler (1990) | Linear Types Can Change the World | Yes | Linear/affine foundations |
| 4 | mp-units (2024) | Quantities and Units Library (P3045) | Yes | Affine space in production |
| 5 | Boost.ICL | Interval Container Library | Yes | Interval algebra library |
| 6 | SE-0447 | Span: Safe Access to Contiguous Storage | Yes | Swift buffer design |
| 7 | SE-0437 | Non-Copyable Standard Library Primitives | Yes | ~Copyable patterns |
| 8 | Rust RFC 2307 | Concrete NonZero Types | Partial | Phantom typing for memory |
| 9 | Cyclone (Jim et al., 2002) | Cyclone: A Safe Dialect of C | Yes | Region types for C |
| 10 | Linear Haskell (Bernardy et al., 2018) | Linear Haskell | Partial | Linear types for buffers |

### Data Extraction

| Source | Models buffers as intervals? | Algebraic ops on buffers? | Phantom typing? | Key finding |
|--------|------------------------------|---------------------------|-----------------|-------------|
| Tofte-Talpin | Regions (containment lattice) | No arithmetic | No | Regions are lifetime scopes, not intervals |
| Tov-Pucella | Affine values (use-count) | No | No | "Affine" = usage tracking, not geometry |
| Wadler | Linear values | No | No | Linearity governs duplication, not extent |
| mp-units | Points + vectors (no intervals) | No interval type | Yes (units) | Intervals left to application layer |
| Boost.ICL | Yes (interval algebra) | Union, intersection, diff | No | Value-space intervals, not memory regions |
| SE-0447 | Span = (ptr, count) | extracting() only | No | No algebraic interval structure |
| Cyclone | Regions with type params | No arithmetic | Yes (region params) | Regions as lifetime scopes with phantom types |

### Synthesis of Findings

**Finding 1**: No existing system models memory buffers as algebraic interval types with operations like union, intersection, or containment testing. Every production system (Swift, Rust, C++, Haskell) treats buffers as opaque `(pointer, count)` pairs.

**Finding 2**: The word "affine" in type theory literature refers to *usage tracking* (use at most once), not to *affine geometry* (position + displacement). The swift-primitives architecture uniquely applies affine *geometry* to memory types via `Tagged+Affine.swift`.

**Finding 3**: Interval algebra libraries (Boost.ICL, Haskell `Data.IntervalMap`) operate on *value-space* intervals (numbers, timestamps), not on *memory address* intervals. Memory buffers have additional constraints (alignment, ownership, aliasing) that value-space intervals do not.

**Finding 4**: The operations that buffers actually need — sub-region extraction (`extracting()`), translation (rebasing), and bounds checking — are a strict subset of full interval algebra. Union and intersection are semantically questionable for memory regions (what does it mean to "union" two buffers?).

**Finding 5**: Phantom typing for memory regions exists in Cyclone (region type parameters) but is applied to *lifetime scoping*, not to *interval arithmetic*. Swift's `Tagged<Tag, Ordinal>` approach to phantom typing is novel in its application to affine geometry.

---

## Formal Semantics

### Typing Rules for Buffer Operations

#### Current System (Ad-hoc Struct)

**Buffer construction**:
```
Γ ⊢ start : Tagged<Memory, Ordinal>
Γ ⊢ count : Tagged<Memory, Cardinal>
───────────────────────────────────────────── (T-BufInit)
Γ ⊢ Memory.Address.Buffer(start, count) : Memory.Address.Buffer
```

**Sub-buffer extraction**:
```
Γ ⊢ buf : Memory.Address.Buffer
Γ ⊢ offset : Tagged<Memory, Cardinal>
Γ ⊢ count : Tagged<Memory, Cardinal>
offset + count ≤ buf.count
─────────────────────────────────────────── (T-BufExtract)
Γ ⊢ buf.extracting(offset, count) : Memory.Address.Buffer
```

**Element access**:
```
Γ ⊢ buf : Memory.Address.Buffer
Γ ⊢ idx : Index<Memory>
idx < buf.count
──────────────────────────────────── (T-BufSubscript)
Γ ⊢ buf[idx] : UInt8
```

#### Hypothetical System (Tagged Interval)

**Define the interval type**:
```
Interval ≡ struct { start: Ordinal, count: Cardinal }
```

**Buffer construction**:
```
Γ ⊢ start : Ordinal
Γ ⊢ count : Cardinal
──────────────────────────────────────────────── (T-IntBufInit)
Γ ⊢ Tagged<Memory, Interval>(start, count) : Tagged<Memory, Interval>
```

**Sub-buffer extraction**:
```
Γ ⊢ buf : Tagged<Memory, Interval>
Γ ⊢ offset : Cardinal
Γ ⊢ count : Cardinal
offset + count ≤ buf.rawValue.count
────────────────────────────────────────────────── (T-IntBufExtract)
Γ ⊢ buf.extracting(offset, count) : Tagged<Memory, Interval>
```

### Soundness Argument

**Claim**: Both systems preserve memory safety equivalently.

**Argument**:

1. Memory safety depends on the invariant: all accesses are within bounds of a valid allocation.

2. In the struct system:
   - `buf._start` is a `Memory.Address` (Tagged<Memory, Ordinal>)
   - `buf._count` is a `Memory.Address.Count` (Tagged<Memory, Cardinal>)
   - Bounds checking: `index < buf._count`
   - The phantom tag `Memory` is already carried by the stored properties

3. In the Tagged interval system:
   - `buf.rawValue.start` is an `Ordinal`
   - `buf.rawValue.count` is a `Cardinal`
   - Bounds checking: `index < buf.rawValue.count`
   - The phantom tag `Memory` is carried by the outer `Tagged` wrapper

4. Both systems enforce the same bounds-checking invariant. The Tagged interval adds one level of wrapping but does not introduce or eliminate any safety properties.

5. The phantom tag in the interval system is redundant: `Tagged<Memory, Interval>` carries tag `Memory`, but `Interval.start` is an untagged `Ordinal`. In the struct system, `_start: Memory.Address` already carries `Memory` as part of its own Tagged wrapping.

**Conclusion**: The two systems are safety-equivalent. Neither is safer than the other. ∎

### Algebraic Operations Comparison

**Operations that come "for free" in each system**:

| Operation | Struct Buffer | Tagged Interval |
|-----------|--------------|-----------------|
| Equality (==) | Via Hashable conformance | Via Tagged conditional Equatable |
| Hashing | Via Hashable conformance | Via Tagged conditional Hashable |
| Point arithmetic (start ± vector) | Via start property: `buf.start + offset` | Requires custom extension (no auto-derivation) |
| Sub-interval | Custom method | Custom method (same work) |
| Bounds checking | Custom method | Custom method (same work) |
| Translation | Custom method | Could be derived IF interval algebra existed |

**Critical finding**: Unlike scalar `Tagged<Tag, Ordinal>` where affine arithmetic comes for free via `Tagged+Affine.swift`, a `Tagged<Tag, Interval>` does NOT get interval operations for free. Every operation must be manually implemented in an extension `where RawValue == Interval`, which is the same amount of work as implementing methods on a struct.

---

## Analysis

### Option A: Tagged Interval Typealias

**Description**: Define `Affine.Discrete.Interval` as a value type in affine-primitives, then model buffers as Tagged typealiases:

```swift
// In affine-primitives:
extension Affine.Discrete {
    public struct Interval: Hashable, Sendable {
        public let start: Ordinal
        public let count: Cardinal
    }
}

// In memory-primitives:
extension Tagged where Tag == Memory, RawValue == Ordinal {
    public typealias Buffer = Tagged<Memory, Affine.Discrete.Interval>
}

// In pointer-primitives:
extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public typealias Buffer = Tagged<Tag, Affine.Discrete.Interval>
}
```

**Advantages**:
- Algebraic consistency: all memory types are Tagged typealiases
- Interval type reusable across domains (not just memory)
- Interval translation operation definable once in affine-primitives
- Conceptual elegance: buffer ≡ tagged interval

**Disadvantages**:
- Double indirection: `buf.rawValue.start` vs `buf.start`
- Loss of phantom typing on components: `buf.rawValue.start` is `Ordinal`, not `Memory.Address` — the `Memory` tag is only on the outer wrapper
- No "free" operations: interval algebra must be manually implemented (unlike scalar affine operations)
- New type in affine-primitives for uncertain benefit
- `Buffer.Mutable` pattern: would need `Tagged<Memory.Mutable, Affine.Discrete.Interval>`, but mutable and immutable buffers share the same interval structure — mutability is about *access rights*, not *address representation*
- Buffer types store additional semantic content beyond interval: empty-buffer sentinel, alignment guarantees, typed element access

### Option B: Ad-hoc Structs (Current Approach)

**Description**: Keep buffers as structs nested in Tagged extensions:

```swift
// Memory.Address.Buffer
extension Tagged where Tag == Memory, RawValue == Ordinal {
    public struct Buffer: Hashable, @unchecked Sendable {
        @usableFromInline internal let _start: Memory.Address
        @usableFromInline internal let _count: Memory.Address.Count
    }
}

// Pointer<T>.Buffer
extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public struct Buffer: Copyable, @unchecked Sendable {
        @usableFromInline internal let _base: UnsafeBufferPointer<Tag>
    }
}
```

**Advantages**:
- Stored properties carry their own phantom types: `_start: Memory.Address` preserves `Memory` tag
- Direct access: `buf.start` without `rawValue` indirection
- Freedom to store domain-specific data (empty-buffer sentinel pointer, stdlib buffer pointer)
- Different buffer types can have different internal representations
- No new types needed in affine-primitives
- Matches every production system surveyed (Swift stdlib, Rust, C++, Haskell)

**Disadvantages**:
- Breaks the "everything is Tagged" aesthetic
- Buffer types are ad-hoc — each must be manually implemented
- No algebraic identity: buffer ≠ tagged interval, just a struct

### Option C: Hybrid — Interval Primitive Without Tagged Wrapping

**Description**: Define `Affine.Discrete.Interval` as a reusable value type but do NOT make buffers Tagged typealiases. Instead, buffers are structs that *use* interval primitives internally:

```swift
// In affine-primitives:
extension Affine.Discrete {
    public struct Interval: Hashable, Sendable {
        public let start: Ordinal
        public let count: Cardinal
    }
}

// In memory-primitives (still a struct):
extension Tagged where Tag == Memory, RawValue == Ordinal {
    public struct Buffer: Hashable, @unchecked Sendable {
        @usableFromInline internal let _interval: Tagged<Memory, Affine.Discrete.Interval>
    }
}
```

**Advantages**:
- Interval type exists for reuse
- Buffers retain struct flexibility
- Can expose interval operations via delegation

**Disadvantages**:
- Worst of both worlds: adds a new type AND keeps the struct wrapper
- Triple indirection: `buf._interval.rawValue.start`
- Over-engineering without clear benefit

### Comparison Table

| Criterion | A: Tagged Interval | B: Ad-hoc Struct | C: Hybrid |
|-----------|-------------------|------------------|-----------|
| Algebraic consistency | High | Low | Medium |
| Implementation work | High (new type + extensions) | Low (already done) | High |
| Phantom type preservation | Partial (lost on components) | Full (on stored properties) | Partial |
| Access ergonomics | Poor (`rawValue.start`) | Good (`start`) | Poor |
| Free operations | None (manual extensions) | None (manual methods) | None |
| Prior art support | None found | Universal | None found |
| Zero-cost abstraction | Yes | Yes | Yes |
| Domain-specific flexibility | Low (one interval fits all) | High (per-domain structs) | Medium |
| YAGNI compliance | Low | High | Low |

---

## Empirical Validation (Cognitive Dimensions)

| Dimension | A: Tagged Interval | B: Ad-hoc Struct | Assessment |
|-----------|-------------------|------------------|------------|
| **Visibility** | Medium — interval type discoverable but semantics unclear | High — Buffer.start, Buffer.count directly visible | Struct better |
| **Consistency** | High with scalar types (all Tagged) | Medium — scalars are Tagged, buffers are structs | Interval better internally, but false consistency |
| **Viscosity** | Medium — changing interval affects all domains | Low — each buffer independently modifiable | Struct better |
| **Role-expressiveness** | Low — "Tagged interval" doesn't clearly say "memory buffer" | High — "Buffer" clearly says "memory buffer" | Struct better |
| **Error-proneness** | Medium — rawValue access required | Low — direct property access | Struct better |
| **Abstraction** | Over-abstraction — interval algebra unused | Appropriate — buffers are simple containers | Struct better |

**Key cognitive insight**: The consistency argument ("all memory types should be Tagged") is a form of **premature generalization**. Scalars are Tagged because the affine operations (position ± vector → position) come for free. Intervals do NOT get free operations from Tagged — they require the same manual implementation as struct methods. The "consistency" is syntactic, not semantic.

---

## Outcome

**Status**: IN_PROGRESS

**Preliminary recommendation**: **Option B — Ad-hoc Structs**

**Rationale**:

1. **No algebraic benefit**: The primary motivation for Tagged typealiases on scalar types is that affine arithmetic comes for free via `Tagged+Affine.swift`. For intervals, no operations come for free — every buffer operation requires the same manual implementation regardless of whether the buffer is a struct or a Tagged typealias. The algebraic motivation that drives the scalar design does not extend to composites.

2. **Phantom type dilution**: In a `Tagged<Memory, Interval>`, the `Memory` tag applies to the outer wrapper, but the inner `Interval.start` is an untagged `Ordinal`. In the struct `Memory.Address.Buffer`, the stored `_start: Memory.Address` carries its own `Memory` tag, providing deeper type safety.

3. **Universal precedent**: No surveyed system — Swift stdlib, Rust, C++, Haskell, mp-units, Cyclone — models buffers as algebraic intervals. Every production system uses `(pointer, count)` structs.

4. **Semantic mismatch**: Buffers are not pure intervals. They carry domain-specific semantics: empty-buffer sentinels (page-aligned null), alignment guarantees, typed element access. A generic `Affine.Discrete.Interval` cannot encode these constraints.

5. **YAGNI**: Interval algebra operations (union, intersection) are meaningless for memory buffers. You cannot "union" two non-contiguous memory regions into a single buffer. The operations buffers actually need (sub-buffer extraction, bounds checking) are simple enough to implement directly.

6. **"Affine" disambiguation**: The word "affine" applies to buffers in the *resource management* sense (ownership/lifetime — use at most once) via Swift's `~Copyable`, NOT in the *geometric* sense (position + displacement). Conflating these two meanings would create conceptual confusion.

**Remaining question**: Should an `Affine.Discrete.Interval` type be created in affine-primitives for *other* purposes (value-space intervals for scheduling, geometry, index ranges)? This is a separate question from whether memory buffers should be modeled as Tagged intervals.

---

## References

- Tofte, M. & Talpin, J.-P. (1997). Region-Based Memory Management. *Information and Computation*, 132(2), 109–176.
- Tov, J. A. & Pucella, R. (2011). Practical Affine Types. *POPL '11*, 447–458. https://dl.acm.org/doi/10.1145/1926385.1926436
- Wadler, P. (1990). Linear Types Can Change the World! *IFIP TC 2 Working Conference*.
- Bernardy, J.-P. et al. (2018). Linear Haskell: Practical Linearity in a Higher-Order Polymorphic Language. *POPL '18*.
- Jim, T. et al. (2002). Cyclone: A Safe Dialect of C. *USENIX Annual Technical Conference*.
- SE-0447: Span — Safe Access to Contiguous Storage. Swift Evolution.
- SE-0437: Non-Copyable Standard Library Primitives. Swift Evolution.
- mp-units: The Quantities and Units Library for C++. P3045R4. https://mpusz.github.io/mp-units/2.3/users_guide/framework_basics/the_affine_space/
- Boost.ICL: Interval Container Library. https://www.boost.org/doc/libs/release/libs/icl/
- Kitchenham, B. (2004). Procedures for Performing Systematic Reviews. Keele University Technical Report.
- `address-as-tagged-ordinal` experiment. swift-memory-primitives.
- `tagged-mutable-ambiguity` experiment. swift-pointer-primitives.
- `storage-primitives-design` research. swift-primitives (IN_PROGRESS).

### Deferral

**Date**: 2026-03-15

**Reason**: The analysis reached a preliminary recommendation (Option B: ad-hoc structs, not Tagged intervals) with strong evidence from prior art survey, formal semantics, and cognitive dimensions analysis. The core finding -- that Tagged typealiases provide no "free" algebraic operations for composite types like intervals, unlike scalar types -- resolves the original design question. The remaining open question (whether `Affine.Discrete.Interval` should exist for value-space intervals independent of buffer modeling) is a separate concern with no immediate consumer.

**Resume when**: A concrete use case for value-space interval types emerges in the primitives ecosystem, or when the theoretical analysis is needed as a reference for new buffer type designs.
