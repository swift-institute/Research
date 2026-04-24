# Bitset Architecture: The Ideal Model

<!--
---
version: 1.0.0
last_updated: 2026-02-09
status: DECISION
tier: 2
depends_on: [bitset-naming-literature-study, bit-vector-type-organization, bit-vector-primitives-reducibility]
---
-->

## Context

The swift-set-primitives package contains `Set<Bit>.Vector` — four bitset types that provide set-theoretic operations over packed bit storage. Prior research ([bitset-naming-literature-study](bitset-naming-literature-study.md)) established that the package should be named `swift-bitset-primitives` with type name `Bitset`. This document determines the *architecture* — specifically, how `Bitset` should relate to `Bit.Vector` from swift-bit-vector-primitives.

### The Design Space

The 2×2 matrix (after rhalbersma/bit_set) defines the complete space:

|  | Fixed-capacity | Variable-capacity |
|---|---|---|
| **Sequence of booleans** | `Bit.Vector.Static<N>`, `Bit.Vector.Inline<N>`, `Bit.Vector.Bounded` | `Bit.Vector.Dynamic` |
| **Set of integers** | `Bitset.Static<N>`, `Bitset.Fixed` | `Bitset`, `Bitset.Small<N>` |

Same representation (packed `UInt` words), different semantics:

| Semantic | Count means | Iteration covers | Growth means | Primary operations |
|----------|------------|-----------------|-------------|-------------------|
| Sequence | Number of positions | All positions (dense) | Append more positions | subscript, append, remove |
| Set | Cardinality (popcount) | Members only (sparse) | Expand universe | contains, insert, union, intersection |

### The Question

What is the principled architectural relationship between `Bitset` and `Bit.Vector`?

## Prior Art Survey

### Pattern 1: Composition — BitSet wraps BitVec

**Rust `bit-set` / `bit-vec`** (contain-rs):

```rust
// bit-set crate, src/lib.rs
pub struct BitSet<B = u32> {
    bit_vec: BitVec<B>,  // Single field — pure composition
}
```

`bit-set` depends on `bit-vec` via `Cargo.toml`. Exposes the inner vector via `get_ref() -> &BitVec<B>` and `into_bit_vec() -> BitVec<B>`. Set algebra operations (`union`, `intersection`, `difference`, `symmetric_difference`) internally manipulate BitVec's words.

**Rust `std::collections::BitSet`** (removed in 1.3.0): Same architecture. Both lived in a single `bit.rs` module. RFC 580 noted: "Technically, BitSet is a synonym of BitVec(tor), but it has Set in its name and can be interpreted as a set-like 'view' into the underlying bit array/vector."

**rhalbersma/bit_set** (modern C++):

```cpp
template<std::size_t N, std::unsigned_integral Block>
class bit_set {
    bit::array<N, Block> m_bits{};  // Wraps bit::array
};
```

Explicitly fills the 2×2 matrix with four types, set types composing sequence types.

**Assessment**: Composition creates a subordinate relationship — BitVec is "more fundamental" than BitSet. Forces leaky abstraction (`get_ref()`) because set algebra needs word-level access to the underlying vector. Works when both types live in the same module or crate; awkward across package boundaries.

### Pattern 2: Shared Kernel — Both types independently compose a Word primitive

**Apple swift-collections** (`BitCollections` module):

```swift
// BitSet.swift
public struct BitSet {
    @usableFromInline internal var _storage: [_Word]
}

// BitArray.swift
public struct BitArray {
    @usableFromInline internal var _storage: [_Word]
    @usableFromInline internal var _count: UInt
}
```

**Neither type wraps the other.** Both store `[_Word]` directly, where `_Word` is a shared internal type wrapping `UInt` with bit-level operations (`contains(bit:)`, `insert(bit:)`, `remove(bit:)`, `nonzeroBitCount`, set-bit iteration).

The shared kernel lives in `Sources/BitCollections/Shared/`:
- `_Word.swift` — word-level primitive
- `Range+Utilities.swift` — range helpers
- `UInt+Tricks.swift` — bit manipulation utilities

**Critical historical fact**: The [original GSoC PR #83](https://github.com/apple/swift-collections/pull/83) proposed BitSet composing BitArray. The [shipped code](https://github.com/apple/swift-collections/tree/main/Sources/BitCollections) uses a different architecture — the maintainer (Karoy Lorentey) moved from composition to shared kernel. This represents a *deliberate architectural evolution* by one of the most experienced Swift library designers.

**Assessment**: The shared kernel pattern treats both types as equals — neither is subordinate. Each type owns its storage and optimizes independently for its semantics. The shared primitive (`_Word`) captures exactly the right abstraction level: word-level bit manipulation that both types need.

### Pattern 3: Standalone / Monolithic — One type serves both roles

**Java `java.util.BitSet`**: Single `long[]`-backed type with both sequence operations (`get`, `set`, `clear`, `flip`) and set operations (`and`, `or`, `xor`, `andNot`, `nextSetBit`). No separate bit-vector type in Java's standard library.

**C++ `std::bitset<N>`**: Single fixed-size type with both `operator[]` (sequence) and bitwise operators (set algebra). Completely independent from `std::vector<bool>`.

**.NET `System.Collections.BitArray`**: Single `int[]`-backed type with `And()`, `Or()`, `Xor()`, `Not()`. Named "Array" but provides set operations.

**Boost `dynamic_bitset`**: Dynamic-size counterpart to `std::bitset`. Wraps `std::vector<Block>` internally but is architecturally standalone.

**Assessment**: Monolithic types conflate two semantics in one interface. Works in ecosystems with a single type, but produces naming confusion (Java's "BitSet" supports sequence ops; .NET's "BitArray" supports set ops). Inappropriate when both types exist independently.

### Pattern 4: Bit-Vector Only — No BitSet type

**`bitvec` crate** (ferrilab): Provides `BitSlice`, `BitArray`, `BitVec`, `BitBox` — all sequence-oriented. [Issue #83](https://github.com/ferrilab/bitvec/issues/83) requested a BitSet API; the response was to add `iter_ones()` and `iter_zeros()` instead. Proves a comprehensive bit-vector library does NOT necessarily need a bitset type.

**Assessment**: If the bit-vector provides ones-iteration and bitwise operators, a separate bitset type adds primarily *semantic clarity* (count = cardinality, insert/contains vocabulary) rather than new capability.

### Summary

| Pattern | Examples | Relationship | Production prevalence |
|---------|----------|-------------|----------------------|
| Composition | Rust `bit-set`/`bit-vec`, `rhalbersma/bit_set` | BitSet wraps BitVec | Rare |
| Shared Kernel | Swift Collections | Both compose `_Word` | Moderate |
| Monolithic | Java, C++, .NET, Boost | Single type | Dominant |
| No BitSet | `bitvec` crate | Only sequence types | Moderate |

**Composition is the rarest pattern in shipped production code.** Swift Collections is the most relevant precedent, and it *evolved away from composition toward shared kernel*.

## Analysis

### What Bitset and Bit.Vector Actually Share

At the implementation level, both types perform the same word-level operations:

| Operation | Bit.Vector usage | Bitset usage |
|-----------|-----------------|--------------|
| `word \| mask` | Set bit at index | Insert member |
| `word & ~mask` | Clear bit at index | Remove member |
| `word & mask != 0` | Read bit at index | Test membership |
| `word.nonzeroBitCount` | Popcount (statistic) | Count (cardinality) |
| `word &= word &- 1` | Ones iteration | Member iteration |
| `wordA \| wordB` | *Not used* | Union |
| `wordA & wordB` | *Not used* | Intersection |
| `wordA & ~wordB` | *Not used* | Difference |
| `wordA ^ wordB` | *Not used* | Symmetric difference |
| `wordA & ~wordB == 0` | *Not used* | Subset test |
| `wordA & wordB == 0` | *Not used* | Disjointness test |

**Key observation**: The word-level binary operations (OR, AND, XOR, AND-NOT) are *exclusively* set operations. They have no meaning in the sequence domain. This is the deepest argument for why bitset cannot simply wrap bit-vector — the operations that define a bitset's identity do not exist on the underlying type.

### What They DON'T Share

| Concept | Bit.Vector | Bitset |
|---------|-----------|--------|
| Count | Number of bit positions | Number of set bits (popcount) |
| Growth | Append (add position at end) | Expand universe (grow word array to accommodate member) |
| Iteration | All positions, dense | Set bits only, sparse (Wegner/Kernighan) |
| Empty | No positions | No members (all bits zero) |
| Full | *Not meaningful* | All bits in universe are set |
| First/last | First/last boolean value | Min/max member |
| Subscript | `vector[i] -> Bool` | *Not natural* (use `contains`) |
| Append/remove | Natural (sequence ops) | *Not natural* (use `insert`/`remove` by member) |
| Union/intersection | *Not natural* | Primary operations |

The semantic gap is profound. These are different abstractions over the same representation.

### The Shared Kernel in Our Architecture

In the Swift Institute primitives architecture, the shared kernel already exists:

**`Bit.Pack<UInt>` (swift-bit-pack-primitives, tier 11)**:
- `Bit.Pack<UInt>.Location` — word index + bit offset + precomputed mask
- `Bit.Pack<UInt>.Words` — word count for a given bit count
- `Bit.Pack<UInt>.Bits` — unused bits in last word (slack)
- `Bit.Index.location(bitsPerWord:)` — convenience method

**`Bit.Index` (swift-bit-index-primitives, tier 10)**:
- `Bit.Index` — typed bit position (`Tagged<Bit, Ordinal>`)
- `Bit.Index.Count` — typed bit count
- `Affine.Discrete.Ratio<UInt, Bit>.bitsPerWord` — word-to-bit conversion ratio

This is exactly the `_Word`-equivalent from swift-collections, but decomposed into the primitives architecture: the layout witness (`Bit.Pack`), the typed index (`Bit.Index`), and the conversion ratio (`Affine.Discrete.Ratio`).

Both `Bit.Vector.Dynamic` and `Bitset` should compose these same primitives for bit addressing, while each owning their own `ContiguousArray<UInt>` / `InlineArray<N, UInt>` storage.

### Why Composition (Bitset wraps Bit.Vector) Is Wrong

1. **Forces API bloat on Bit.Vector.** Bitset needs word-level bulk access (`withUnsafeWords`) for O(n/64) set algebra. Bit.Vector.Dynamic does not expose this, and shouldn't — its minimal API serves sequence semantics. Adding word-level access purely to serve a consumer inverts the dependency.

2. **Semantic mismatch on count.** Bit.Vector.Dynamic's `_count` tracks the number of bit positions (sequence length). Bitset's count is popcount (cardinality). Wrapping would require ignoring the vector's count — using a type while disregarding its primary semantic property.

3. **Growth model mismatch.** Bit.Vector.Dynamic grows via `append` (extend the sequence). Bitset grows by expanding the universe (ensure enough words to represent a member at index N). These are fundamentally different growth triggers.

4. **Leaky abstraction.** Composition forces exposing the inner type for performance (Rust's `get_ref()`, Rust's `into_bit_vec()`). This couples the bitset's interface to the vector's, undermining the separation that motivated the split.

5. **Precedent rejects it.** Swift Collections started with composition and moved away from it. The contain-rs model requires `get_ref()` and `get_mut()` — exactly the leaky abstraction that demonstrates the problem.

### Why Shared Kernel (Bit.Pack) Is Right

1. **Already exists.** `Bit.Pack<UInt>` is the layout witness that both type families need. No new infrastructure required.

2. **Neither type is subordinate.** Bit.Vector and Bitset are siblings, not parent-child. Both compose `Bit.Pack` for addressing, both own their storage.

3. **Bit.Vector's API stays minimal.** No word-level access methods need to be added. Bit.Vector serves sequence semantics; Bitset serves set semantics. Each is complete in itself.

4. **Same tier, no coupling.** Both at tier 12, both depending downward on tier 11 (`Bit.Pack`). No lateral dependency between them.

5. **Matches the most principled precedent.** Swift Collections' shipped architecture uses exactly this pattern — shared kernel, independent storage, independent optimization.

6. **Word-level binary operations are self-contained.** Union (OR), intersection (AND), difference (AND-NOT), symmetric difference (XOR) are simple `for i in 0..<wordCount { result[i] = lhs[i] OP rhs[i] }` loops. They don't need any infrastructure beyond raw `UInt` bitwise operators and `ContiguousArray` iteration. Pushing them into a shared kernel would over-abstract what are trivially simple operations.

## Outcome

**Status**: DECISION

### The Ideal Model

```
                    Bit (tier 9)
                      │
                   Bit.Index (tier 10)
                      │
                   Bit.Pack (tier 11)  ← shared layout witness
                   ╱         ╲
        Bit.Vector (tier 12)   Bitset (tier 12)  ← siblings, not parent-child
        sequence of bits       set of integers
```

**Architecture**: Shared Kernel pattern. Both `Bit.Vector.*` and `Bitset.*` independently compose `Bit.Pack<UInt>` for bit-to-word addressing. Neither wraps the other. Each owns its storage (`ContiguousArray<UInt>` or `InlineArray<N, UInt>`) directly.

### Package Structure

```
swift-bitset-primitives (new, tier 12)
├── Dependencies:
│   ├── swift-bit-primitives        (tier 9)  — Bit, Bit.Index
│   ├── swift-bit-pack-primitives   (tier 11) — Bit.Pack<UInt>.Location
│   └── swift-ordinal-primitives    (tier 4)  — Ordinal (if needed for typed indices)
├── Products:
│   ├── "Bitset Primitives"
│   └── "Bitset Primitives Test Support"
└── Targets:
    ├── Bitset Primitives
    ├── Bitset Primitives Test Support
    └── Bitset Primitives Tests
```

**Does NOT depend on** `swift-bit-vector-primitives`. The shared infrastructure flows through `swift-bit-pack-primitives`.

### Type Family

| Type | Storage | Copyable | Capacity | Growth | Composes |
|------|---------|:--------:|----------|--------|----------|
| `Bitset` | `ContiguousArray<UInt>` | Yes | Variable | Universe expands on insert | `Bit.Pack<UInt>` |
| `Bitset.Fixed` | `ContiguousArray<UInt>` | Yes | Fixed at init | Throws on out-of-bounds insert | `Bit.Pack<UInt>` |
| `Bitset.Static<N>` | `InlineArray<N, UInt>` | Yes | Compile-time (`N × UInt.bitWidth`) | Throws on overflow | `Bit.Pack<UInt>` |
| `Bitset.Small<N>` | `InlineArray<N, UInt>` + `ContiguousArray<UInt>?` | Yes | Inline, spills to heap | Auto-spill | `Bit.Pack<UInt>` |

### Semantic Contract

Every `Bitset` variant provides:

**Core set operations**:
- `contains(_ member:) -> Bool` — O(1) membership test
- `insert(_ member:) -> Bool` — O(1) amortized insertion, returns whether new
- `remove(_ member:) -> Bool` — O(1) removal, returns whether was present

**Cardinality**:
- `count: Int` — number of members (= popcount), **not** universe size
- `isEmpty: Bool` — no members
- `capacity: Int` — current universe size (maximum representable member + 1)

**Set algebra** (via `.algebra` accessor, per project convention):
- `union(_ other:) -> Bitset` — word-level OR
- `intersection(_ other:) -> Bitset` — word-level AND
- `subtract(_ other:) -> Bitset` — word-level AND-NOT
- `symmetric.difference(_ other:) -> Bitset` — word-level XOR

**Mutating algebra** (via `form(_:)` pattern):
- `form { $0.union(other) }` — mutate in place

**Set relations** (via `.relation` accessor):
- `isSubset(of:) -> Bool` — `(self & ~other) == 0`
- `isSuperset(of:) -> Bool` — `other.relation.isSubset(of: self)`
- `isDisjoint(with:) -> Bool` — `(self & other) == 0`

**Extremes**:
- `min: Int?` — smallest member (first set bit)
- `max: Int?` — largest member (last set bit)

**Iteration**:
- `forEach(_ body:)` — iterates members in ascending order
- `makeIterator() -> Iterator` — sparse iteration via Wegner/Kernighan (`word &= word &- 1`)
- Iteration is O(popcount), NOT O(universe size)

**Conformances**:
- `Sendable`, `Equatable`, `Hashable`
- `Sequence` (over `Int` members, NOT `Bool` values)
- `CustomStringConvertible` (where `Element: Copyable`)

### What Bitset Does NOT Provide

- `subscript(index) -> Bool` — use `contains` instead (set vocabulary, not sequence vocabulary)
- `append` / `removeLast` — meaningless for sets (use `insert` / `remove` by member)
- Dense iteration — all positions are not meaningful; iterate members only
- `Bit` values — bitset members are `Int` (or `Bit.Index`), not `Bit`/`Bool`

### Implementation Pattern

Every method follows the same pattern using `Bit.Pack<UInt>.Location`:

```swift
// Membership test
@inlinable
public func contains(_ member: Int) -> Bool {
    let loc = Bit.Index(Ordinal(UInt(member))).location(bitsPerWord: .bitsPerWord)
    guard Int(bitPattern: loc.word.position) < _storage.count else { return false }
    return (_storage[Int(bitPattern: loc.word.position)] & loc.mask) != 0
}

// Set algebra (word-level bulk operation)
@inlinable
public func union(_ other: Bitset) -> Bitset {
    // ... ensure result has enough words ...
    for i in 0..<minWords {
        result[i] |= other._storage[i]
    }
    // ... copy remaining words from longer operand ...
}
```

### Relationship to Existing Bit.Vector

`Bit.Vector` remains unchanged. No methods added, no API modifications. The types are architectural siblings:

| Aspect | Bit.Vector.Dynamic | Bitset |
|--------|-------------------|--------|
| Abstraction | Sequence of booleans | Set of integers |
| Storage | `ContiguousArray<UInt>` | `ContiguousArray<UInt>` |
| Shared kernel | `Bit.Pack<UInt>` | `Bit.Pack<UInt>` |
| Count | Positions | Cardinality |
| Iteration | Dense (all positions) | Sparse (members only) |
| Growth | Append | Universe expansion |
| Set algebra | No | Yes |
| Tier | 12 | 12 |
| Depends on other | No | No |

### Migration Path

1. Create `swift-bitset-primitives/` with `Package.swift`
2. Implement `Bitset` (dynamic) with full set algebra using `Bit.Pack<UInt>`
3. Implement `Bitset.Fixed`, `Bitset.Static<N>`, `Bitset.Small<N>`
4. Create tests
5. Remove `Set Bit Vector Primitives` target from `swift-set-primitives`
6. Remove `Set<Bit>.Vector` type declarations from `Set Primitives Core`
7. Update `Set Primitives` exports
8. Build and verify both packages

### Theoretical Justification

CS literature treats "bit array", "bit vector", "bitset", and "bitmap" as synonyms for the same *representation* (Wikipedia: "Bit array"). The distinction is *interface*, not representation:

- **Bit vector**: indexable sequence → `get(i)`, `set(i, v)`, `append(v)`
- **Bitset**: membership set → `contains(i)`, `insert(i)`, `union(other)`

This matches the concept of *abstract data types* — same representation, different operations, different semantics. A shared kernel (the representation's addressing scheme) with independent interfaces is the textbook-correct architecture.

The evolution of Swift Collections confirms this empirically: the most experienced Swift library designers started with composition and converged on shared kernel. Our architecture reaches the same conclusion from first principles, with `Bit.Pack<UInt>` as the kernel.

## References

### Prior Art (Composition)
- Rust `bit-set` crate: [github.com/contain-rs/bit-set](https://github.com/contain-rs/bit-set/blob/master/src/lib.rs) — BitSet wraps BitVec
- Rust `bit-vec` crate: [github.com/contain-rs/bit-vec](https://github.com/contain-rs/bit-vec/blob/master/src/lib.rs)
- Rust RFC 580: [rust-lang.github.io/rfcs/0580](https://rust-lang.github.io/rfcs/0580-rename-collections.html) — "BitSet is a synonym of BitVec(tor)"
- rhalbersma/bit_set: [github.com/rhalbersma/bit_set](https://github.com/rhalbersma/bit_set) — 2×2 matrix design

### Prior Art (Shared Kernel)
- Swift Collections `BitCollections`: [github.com/apple/swift-collections](https://github.com/apple/swift-collections/tree/main/Sources/BitCollections)
- Swift Collections PR #83: [github.com/apple/swift-collections/pull/83](https://github.com/apple/swift-collections/pull/83) — original composition proposal
- Swift Forums review: [forums.swift.org/t/51396](https://forums.swift.org/t/bit-array-and-bit-set-api-review-the-end-of-a-gsoc-project/51396)

### Prior Art (Monolithic)
- Java `BitSet`: [OpenJDK source](https://github.com/openjdk-mirror/jdk7u-jdk/blob/master/src/share/classes/java/util/BitSet.java)
- C++ `std::bitset`: [cppreference.com](https://en.cppreference.com/w/cpp/utility/bitset.html)
- .NET `BitArray`: [reference source](https://github.com/microsoft/referencesource/blob/main/mscorlib/system/collections/bitarray.cs)
- Boost `dynamic_bitset`: [boost.org](https://www.boost.org/doc/libs/latest/libs/dynamic_bitset/doc/html/dynamic_bitset/reference/boost/dynamic_bitset.html)

### Prior Art (No BitSet)
- `bitvec` crate: [docs.rs/bitvec](https://docs.rs/bitvec/latest/bitvec/) — no BitSet type
- `fixedbitset` crate: [docs.rs/fixedbitset](https://docs.rs/fixedbitset/latest/fixedbitset/) — standalone hybrid

### Theory
- Wikipedia "Bit array": [en.wikipedia.org](https://en.wikipedia.org/wiki/Bit_array) — synonyms listed
- Lemire et al., "Roaring Bitmaps", arXiv 1402.6407: [arxiv.org](https://arxiv.org/pdf/1402.6407) — density-dependent representation
- Arthur O'Dwyer, "Bit vectors": [quuxplusone.github.io](https://quuxplusone.github.io/blog/2022/11/05/bit-vectors/) — C++ design critique

### Project References
- Prior research: [bitset-naming-literature-study](bitset-naming-literature-study.md)
- Prior research: [bit-vector-type-organization](bit-vector-type-organization.md)
- Prior research: [bit-vector-primitives-reducibility](bit-vector-primitives-reducibility.md)
- Bit.Pack source: `/Users/coen/Developer/swift-primitives/swift-bit-pack-primitives/Sources/Bit Pack Primitives/`
- Bit.Vector source: `/Users/coen/Developer/swift-primitives/swift-bit-vector-primitives/Sources/Bit Vector Primitives/`
- Current Set<Bit>.Vector: `/Users/coen/Developer/swift-primitives/swift-set-primitives/Sources/Set Bit Vector Primitives/`
