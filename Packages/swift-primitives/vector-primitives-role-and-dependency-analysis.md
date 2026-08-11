# Vector Primitives: Role and Dependency Analysis

<!--
---
version: 1.1.0
last_updated: 2026-02-08
status: SUPERSEDED
---
-->

## SUPERSEDED

This document's analysis of the stored `Vector<Element, N>` role is superseded by `Research/vector-rename-analysis.md` v4.0.0 (DECISION). swift-vector-primitives has been repurposed for the functional vector `Vector<Bound>` (formerly `Range.Lazy<Bound>`). The stored vector types (`Vector<Element, N>`, `Vector<Element, N>.Inline`) have been removed; their functionality overlaps with array-primitives (`Array.Fixed`, `Array.Static`). Git history preserves the original implementation.

## Context

`swift-vector-primitives` (tier 10) is an older package that predates several newer, more specialized packages:

- `swift-bit-vector-primitives` (tier 12) — packed bit storage with heap and static variants
- `swift-storage-primitives` (tier 14) — heap and inline storage building blocks
- `swift-buffer-primitives` (tier 15) — ring, linear, and slab buffer disciplines

The package currently contains:

| Type | Purpose |
|------|---------|
| `Vector<Element, N>` | Heap-allocated fixed-dimension container with CoW |
| `Vector<Element, N>.Inline` | Stack-allocated fixed-dimension container |
| `Vector<Element, N>.Index` | Typealias to `Cyclic.Group<N>` |
| `Vector<Bit, N>` extensions | Bit-specific operations (popcount, setAll, clearAll, etc.) |
| `Vector<Bit, N>.Inline` extensions | Bit-specific operations plus bitwise AND/OR/XOR |

Two packages depend on it:

| Consumer | Usage |
|----------|-------|
| `swift-algebra-linear-primitives` (tier 11) | `Linear.Vector<N>` wraps `Vector<Scalar, N>.Inline` as internal storage |
| `swift-matrix-primitives` (tier 12) | Declared dependency, no source code yet |

The trigger: `Bit.Vector` now exists as a dedicated, more capable package (`swift-bit-vector-primitives`). The `Vector.Bit` specializations in vector-primitives are redundant. This raises the question: what *is* vector-primitives for, and does the current dependency graph make sense?

## Question

What should the role of `swift-vector-primitives` be, given that bit-vector-primitives now handles the bit case, and the primary consumer (algebra-linear-primitives) barely uses the substrate it provides?

## Analysis

### Option A: Eliminate vector-primitives entirely

**Description**: Delete the package. Move what consumers need directly into their own packages.

**Current usage in algebra-linear-primitives**: `Linear.Vector<N>` wraps `Vector<Scalar, N>.Inline`, but the wrapper only uses:

1. `init(_ elements: consuming InlineArray<N, Element>)` — constructor from InlineArray
2. `.elements` — get/set the InlineArray

That's it. Every arithmetic operation, dot product, cross product, projection, distance computation, norm, etc. is implemented directly in algebra-linear-primitives using raw `InlineArray<N, Scalar>` access via `.components`. The `Vector.Inline` substrate provides zero computational value — it's a trivial wrapper around `InlineArray` that adds overhead (Cyclic.Group indexing, span access, borrowing APIs) that `Linear.Vector` never uses.

**What would be lost**:

- `Vector<Element, N>` (heap, CoW) — no current consumer uses this
- `Vector<Element, N>.Inline` — a thin wrapper around InlineArray that Linear.Vector could replace with a direct `InlineArray<N, Scalar>` field
- `Vector.Bit` / `Vector.Bit.Inline` specializations — fully superseded by `Bit.Vector` and `Bit.Vector.Static`
- Cyclic.Group-based indexing — Linear.Vector uses `Int` subscripts, never `Vector.Index`

**Advantages**:
- Eliminates a package that has no clear identity
- Removes 8 transitive dependencies from algebra-linear-primitives (affine, algebra, bit, cyclic, dimension, finite, index, ordinal) — most of which Linear.Vector doesn't need
- Simplifies the tier graph
- Removes redundant Bit.Vector specializations

**Disadvantages**:
- If anyone uses `Vector<Element, N>` directly (outside algebra-linear), they lose it
- The heap-allocated CoW vector *is* a valid data structure, even if currently unused

### Option B: Redefine vector-primitives as a generic fixed-dimension container

**Description**: Strip the bit specializations (done by bit-vector-primitives). Keep `Vector<Element, N>` and `Vector<Element, N>.Inline` as the generic fixed-dimension container primitive. Reduce dependencies to the minimum.

**What vector-primitives would be**: A container type — `N` elements of type `Element`, fixed at compile time, with both heap (CoW) and inline (stack) variants. No algebraic operations. No bit operations. Pure storage with bounded access.

Think of it as: "InlineArray with a type-safe index and a heap variant."

**Dependency reduction**:

| Current dependency | Needed? | Reason |
|--------------------|---------|--------|
| affine-primitives | No | Not used by Vector core |
| algebra-primitives | No | Not used by Vector core |
| bit-primitives | No | Bit specializations move to bit-vector-primitives |
| cyclic-primitives | Yes | `Vector.Index` = `Cyclic.Group<N>` |
| dimension-primitives | No | Not used by Vector core |
| finite-primitives | Maybe | Could be useful for bounded iteration |
| index-primitives | Yes | `Index<T>` coordinate types |
| ordinal-primitives | No | Not used by Vector core |

Minimal dependency set: `cyclic-primitives`, `index-primitives`, possibly `finite-primitives`.

**Advantages**:
- Clear identity: fixed-dimension container with bounded indexing
- Heap variant (CoW) + inline variant — a genuine pair that InlineArray alone doesn't provide
- Dramatically reduced dependency footprint (from 8 to 2-3)
- Could serve as substrate for bit-vector-primitives (bit-vector uses `InlineArray<wordCount, UInt>` today — could use `Vector<UInt, wordCount>.Inline` instead)

**Disadvantages**:
- algebra-linear-primitives still wouldn't gain much from it (see analysis below)
- The "value add" over InlineArray is thin: bounded index + heap variant
- Maintaining a package for a thin wrapper is questionable

### Option C: Make vector-primitives the true generic substrate that bit-vector-primitives and algebra-linear-primitives build on

**Description**: Redesign vector-primitives as the canonical fixed-dimension storage primitive. Both `Bit.Vector` and `Linear.Vector` would use it as their internal substrate, unifying the pattern.

**How bit-vector-primitives would use it**:

Currently `Bit.Vector.Static<let wordCount: Int>` stores `InlineArray<wordCount, UInt>`. It could instead store `Vector<UInt, wordCount>.Inline`, gaining:
- Type-safe bounded indexing
- Span access
- Borrowing-first APIs

However, `Bit.Vector` (heap, ~Copyable) uses `UnsafeMutablePointer<UInt>` — it manages its own memory because it's ~Copyable and needs precise deinit control. `Vector<Element, N>` uses `ManagedBuffer` — a different allocation strategy entirely. These are fundamentally incompatible storage models.

**How algebra-linear-primitives would use it**:

Currently it wraps `Vector<Scalar, N>.Inline` but only touches `.elements` (the InlineArray). For vector-primitives to provide genuine value, Linear.Vector would need to delegate operations *to* the substrate rather than reimplementing them on top. But linear algebra operations (dot, cross, norm, projection) are domain-specific — they don't belong in a generic container.

**The fundamental problem**: A generic container cannot know about dot products. A bit vector needs word-level packed operations, not element-level access. The operations that make each domain useful are orthogonal to what a generic container provides.

**Advantages**:
- Unified storage substrate (one pattern for all fixed-N types)
- Consistency

**Disadvantages**:
- Bit.Vector's heap variant is incompatible with Vector's ManagedBuffer approach
- The substrate provides almost nothing that consumers actually use
- Forces a dependency where InlineArray would suffice
- Adds indirection without adding value

### Option D: Merge vector-primitives functionality into existing packages

**Description**:
- `Vector.Bit` / `Vector.Bit.Inline` → already superseded, delete
- `Vector<Element, N>.Inline` → the wrapper adds nothing over `InlineArray<N, Element>`; algebra-linear-primitives should use InlineArray directly
- `Vector<Element, N>` (heap, CoW) → move to a new or existing container package if valuable, or delete

**Advantages**:
- No package exists without a clear purpose
- Each domain owns its storage choices
- Minimal dependency graphs

**Disadvantages**:
- Heap-allocated fixed-dimension CoW container is lost (though nothing uses it)

## Comparison

| Criterion | A: Eliminate | B: Generic container | C: Shared substrate | D: Merge into others |
|-----------|-------------|---------------------|--------------------|--------------------|
| Clear identity | N/A (gone) | Yes: fixed-N container | Yes: universal substrate | N/A (distributed) |
| Dependency reduction | Maximum | Significant (8→2-3) | None (adds deps) | Maximum |
| Value to bit-vector | None | Minimal (Static only) | Low (heap incompatible) | None |
| Value to algebra-linear | None | Minimal (InlineArray suffices) | Low (ops are domain-specific) | None |
| Maintenance burden | None | Low | High | None |
| Heap CoW vector preserved | No | Yes | Yes | Optional |
| Bit specialization cleanup | Yes | Yes | Yes | Yes |

### The algebra-linear dependency problem

Examining `Linear.Vector<N>` at `/Users/coen/Developer/swift-primitives/swift-algebra-linear-primitives/Sources/Algebra Linear Primitives/Linear.Vector.swift:20-39`:

```swift
public struct Vector<let N: Int> {
    @usableFromInline
    internal var _storage: Vector_Primitives.Vector<Scalar, N>.Inline

    @inlinable
    public var components: InlineArray<N, Scalar> {
        get { _storage.elements }
        set { _storage.elements = newValue }
    }

    @inlinable
    public init(_ components: consuming InlineArray<N, Scalar>) {
        self._storage = Vector_Primitives.Vector<Scalar, N>.Inline(components)
    }
}
```

Every operation in `Linear+Arithmatic.swift` and `Linear.Vector.swift` accesses `components` (the InlineArray), never `_storage` directly. The Vector.Inline wrapper is invisible to all linear algebra logic. Replacing `_storage` with `var _components: InlineArray<N, Scalar>` would:

1. Remove the vector-primitives dependency entirely
2. Remove 8 transitive dependencies
3. Change zero external behavior
4. Simplify the type

This strongly suggests the dependency is wrong today, regardless of what happens to vector-primitives.

### The bit-vector overlap

`Vector.Bit.swift` and `Vector.Bit.Inline.swift` provide: popcount, setAll, clearAll, toggleAll, isAllZeros, isAllOnes, flipped, and/or/xor.

`Bit.Vector` and `Bit.Vector.Static` provide all of the above plus: word-level unsafe access, property-based semantic accessors (`bits.set.all()`, `bits.clear.all()`), non-mutating iteration over set bits (`ones.forEach`), and correct handling of non-word-aligned capacities.

The bit-vector-primitives implementations are strictly more capable and more correct. The Vector.Bit specializations are redundant.

## Outcome

**Status**: RECOMMENDATION

### Primary recommendation

**Option D (merge/eliminate) + fix the algebra-linear dependency**.

Concretely:

1. **Remove the `Vector.Bit` and `Vector.Bit.Inline` specializations** from vector-primitives. These are fully superseded by `Bit.Vector` and `Bit.Vector.Static` in bit-vector-primitives.

2. **Fix algebra-linear-primitives**: Replace `Vector_Primitives.Vector<Scalar, N>.Inline` with `InlineArray<N, Scalar>` directly. Remove the vector-primitives dependency. This is a mechanical change — every operation already goes through `.components` which is the InlineArray.

3. **Evaluate whether `Vector<Element, N>` (heap, CoW) has independent value**. It's a valid data structure: fixed-dimension, heap-allocated, copy-on-write, ~Copyable-aware. But nothing currently uses it. Two paths:
   - **If no use case emerges**: deprecate and remove vector-primitives entirely.
   - **If a use case exists** (e.g., large fixed-dimension data like embeddings, signal processing buffers): keep it as a minimal package with reduced dependencies (cyclic + index only).

4. **Fix matrix-primitives dependency**: matrix-primitives declares a dependency on vector-primitives but has no source code. When implemented, it should depend on algebra-linear-primitives (which provides `Linear.Matrix`), not on vector-primitives directly.

### On the "generic vector that bit-vector would use" idea

After thorough analysis: this is not viable. The two domains have fundamentally different storage strategies:

| Aspect | Generic Vector | Bit Vector |
|--------|---------------|------------|
| Element granularity | Per-element (`Scalar`) | Per-bit (packed into `UInt` words) |
| Heap storage | ManagedBuffer (ARC) | UnsafeMutablePointer (~Copyable, manual) |
| Inline storage | InlineArray<N, Element> | InlineArray<wordCount, UInt> |
| Index type | `Cyclic.Group<N>` (element index) | `Bit.Index` (bit position within words) |
| Iteration | Element-by-element | Word-by-word with bit intrinsics |
| Capacity semantics | N elements | N bits (N/64 words) |

A shared substrate would be an abstraction that neither domain benefits from. Bit vectors pack data into words — they don't store N elements of a type. The generic parameter `N` means "N elements" in one case and "N bits" (not N words) in the other. These are categorically different.

## References

- `swift-vector-primitives/Sources/Vector Primitives/` — current implementation
- `swift-bit-vector-primitives/Sources/Bit Vector Primitives/` — superseding bit vector implementation
- `swift-algebra-linear-primitives/Sources/Algebra Linear Primitives/Linear.Vector.swift` — primary consumer
- `swift-algebra-linear-primitives/Sources/Algebra Linear Primitives/Linear+Arithmatic.swift` — operations that bypass Vector substrate
- `swift-storage-primitives/Sources/Storage Primitives Core/` — alternative storage patterns
- `swift-buffer-primitives/Sources/Buffer Primitives Core/` — composed buffer types

## Changelog

### v1.1.0 (2026-02-08)

- **Status changed**: IN_PROGRESS → SUPERSEDED. swift-vector-primitives has been repurposed for the functional vector `Vector<Bound>` (formerly `Range.Lazy<Bound>`). The stored vector types analyzed in this document have been removed. See `Research/vector-rename-analysis.md` v4.0.0.

### v1.0.0 (2026-02-04)

- Initial analysis of vector-primitives role given overlapping packages.
