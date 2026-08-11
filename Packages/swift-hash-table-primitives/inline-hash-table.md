# Inline Hash Table

<!--
---
version: 1.0.0
last_updated: 2026-01-30
status: DECISION
---
-->

## Context

The hash-table-primitives package provides `Hash.Table<Element>`, a heap-allocated open-addressed hash table using linear probing. For small, fixed-capacity use cases, a stack-allocated inline variant would avoid heap allocation overhead and provide O(1) lookup for inline collections.

**Trigger**: [RES-001] Design question arose during implementation — pattern selection for inline hash table storage.

**Scope**: Package-specific (hash-table-primitives), with cross-package implications.

### Consumer Types

Four types would benefit from `Hash.Table.Static`:

| Type | Package | Current Approach |
|------|---------|------------------|
| `Dictionary.Ordered.Static<capacity>` | dictionary-primitives | `_hashTable` field declared but **unused** — O(n) linear search |
| `Dictionary.Ordered.Small<inlineCapacity>` | dictionary-primitives | Linear search in inline mode |
| `Set.Ordered.Static<capacity>` | set-primitives | O(n) linear search |
| `Set.Ordered.Small<inlineCapacity>` | set-primitives | O(n) linear search in inline mode |

**Critical finding**: `Dictionary.Ordered.Static` declares `_hashTable: InlineArray<capacity, Int>` at line 262 but the `index(of:)` method at line 344-351 uses linear search, completely bypassing the hash table.

## Question

How should `Hash.Table.Static<capacity>` be designed to provide fixed-capacity, stack-allocated hash table storage while:
1. Enabling O(1) average-case lookup for inline collections
2. Maintaining API consistency with `Hash.Table`
3. Following established inline storage patterns
4. Supporting position updates (critical for removal shifting)

## Analysis

### Prior Art: Existing Inline Storage Patterns

#### Storage.Static<N> (storage-primitives)

**Location**: `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Sources/Storage Primitives/Storage.swift:98-138`

**Design**:
- Compile-time capacity via value generic parameter
- 64-byte slots using `InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>`
- Unconditionally `~Copyable`
- Throws on construction if element stride > 64 bytes

**Key insight**: 64-byte slots support arbitrary element types. Hash tables store `Int` pairs — this overhead is unnecessary.

#### Array.Static<N> (array-primitives)

**Location**: `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Primitives Core/Array.swift:155-186`

**Design**:
- Wraps `Storage<Element>.Inline<capacity>`
- Tracks `count: Index.Count` separately
- Unconditionally `~Copyable`
- Has deinit for cleanup

#### Hash.Table (heap variant)

**Location**: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table.swift`

**Design**:
- Open-addressed with linear probing
- Stores `(hashValue, position)` pairs
- Layout: `[hashes...][positions...]` in single allocation
- Sentinels: `empty = 0`, `deleted = Int.min`
- Hash values 0 and Int.min normalized to 1
- Power-of-two bucket capacity for fast modulo
- ~70% load factor target

**Header fields**:
- `count: Index<Element>.Count` — active elements
- `occupied: Index<Bucket>.Count` — occupied buckets (including deleted)
- `capacity: Index<Bucket>.Count` — total buckets

**Critical operation**: `decrementPositions(after:)` — when an element is removed and others shift left, all stored positions greater than the removed position must decrement.

### Option A: Dual Arrays (Match Heap Layout)

Store hashes and positions in separate `InlineArray`s, mirroring the heap variant.

**Structure**:
```swift
public struct Inline<let bucketCapacity: Int>: ~Copyable {
    var _hashes: InlineArray<bucketCapacity, Int>
    var _positions: InlineArray<bucketCapacity, Int>
    var _count: Index<Element>.Count
    var _occupied: Index<Bucket>.Count
}
```

**Advantages**:
- Exact API parity with `Hash.Table`
- Same algorithmic complexity
- Can share code via protocol or generic functions
- Supports tombstone deletion (deleted vs empty distinction)

**Disadvantages**:
- 2× memory: `bucketCapacity × 16` bytes
- May be overkill for small capacities where deletion is rare

**Memory per bucket capacity**:
| Buckets | Payload bytes | With header (~16 bytes) |
|---------|---------------|-------------------------|
| 8 | 128 | ~144 |
| 16 | 256 | ~272 |
| 32 | 512 | ~528 |
| 64 | 1024 | ~1040 |

### Option B: Single Array (Positions Only)

Store only positions, deriving empty/occupied from position sentinel values.

**Structure**:
```swift
public struct Inline<let bucketCapacity: Int>: ~Copyable {
    var _buckets: InlineArray<bucketCapacity, Int>  // -1 = empty, else = position
    var _count: Index<Element>.Count
}
```

**Advantages**:
- 50% memory savings: `bucketCapacity × 8` bytes
- Simpler structure
- Matches current (unused) `Dictionary.Ordered.Static._hashTable` design

**Disadvantages**:
- Cannot distinguish deleted vs empty without additional encoding
- Requires full rehash on removal OR "shift-and-fix" approach
- Hash value not stored — must recompute from element on collision

**Sentinel encoding option**:
```swift
// -1 = empty, Int.min = deleted, else = position (0 to capacity-1)
```

This works because positions are 0-indexed non-negative integers less than capacity.

### Option C: Interleaved Pairs

Store `(hash, position)` tuples in a single array.

**Structure**:
```swift
public struct Inline<let bucketCapacity: Int>: ~Copyable {
    var _buckets: InlineArray<bucketCapacity, (Int, Int)>  // (hash, position)
    var _count: Index<Element>.Count
    var _occupied: Index<Bucket>.Count
}
```

**Advantages**:
- Cache-friendly: hash and position accessed together
- Same functionality as Option A

**Disadvantages**:
- Different memory layout from heap variant
- Tuple access slightly more verbose

### Comparison Matrix

| Criterion | Option A (Dual Arrays) | Option B (Positions Only) | Option C (Interleaved) |
|-----------|------------------------|---------------------------|------------------------|
| Memory efficiency | 2x payload | 1x payload | 2x payload |
| API parity with heap | High | Medium | High |
| Deletion support | Full (tombstones) | Limited | Full (tombstones) |
| Implementation complexity | Low | Medium (rehash on delete) | Low |
| Cache behavior | Two arrays | Single array | Single array |

### Deletion Strategy Analysis

**Why deletion matters**: When removing element at position P from an ordered collection:
1. Elements at positions > P shift left
2. All stored positions > P must decrement

**Option A/C approach** (with tombstones):
1. Mark bucket as deleted (hash = `Int.min`)
2. Call `decrementPositions(after: P)`
3. Tombstones accumulate until rehash

**Option B approach** (positions only):
1. Remove position from bucket
2. Must rehash remaining elements OR probe chain breaks
3. No tombstone accumulation

**Verdict**: For inline storage where capacity is small and deletions are common, Option B's simpler approach may work. But tombstone support (Option A/C) provides more robust handling.

### Capacity Parameter Semantics

**Question**: Should the generic parameter represent bucket count or element count?

**Analysis**:

| Interpretation | Pros | Cons |
|----------------|------|------|
| Bucket count | Predictable memory, direct | Users must understand load factor |
| Element count | User-friendly | Internal bucket count varies |

**Challenge**: Swift value generics don't support arithmetic. Cannot write:
```swift
InlineArray<(elementCapacity * 10) / 7, Int>  // Invalid
```

**Verdict**: Use **bucket count** as the generic parameter. Document effective element capacity (~70% of bucket count). Require power-of-two for fast modulo.

### Effective Element Capacity Table

| Bucket capacity | Max elements (~70%) |
|-----------------|---------------------|
| 8 | 5 |
| 16 | 11 |
| 32 | 22 |
| 64 | 44 |
| 128 | 89 |

### API Surface

Following the heap variant, `Hash.Table.Static` should provide:

**Core operations**:
```swift
func position(forHash:equals:) -> Index<Element>?
mutating func insert(hash:position:equals:) -> Bool
mutating func remove(forHash:equals:) -> Index<Element>?
```

**Position updates** (critical for ordered collection removal):
```swift
mutating func decrementPositions(after position: Index<Element>)
mutating func updatePosition(forHash:equals:newPosition:)
```

**Properties**:
```swift
var count: Index<Element>.Count { get }
var occupied: Index<Bucket>.Count { get }
var bucketCapacity: Index<Bucket>.Count { get }
var isEmpty: Bool { get }
var shouldGrow: Bool { get }  // Useful for detecting spill threshold
```

**Iteration**:
```swift
func forEach(_ body: (hash: Int, position: Index<Element>) -> Void)
```

### Copyability

**Analysis**:
- `InlineArray<N, Int>` is `Copyable`
- The `Element` phantom type may be `~Copyable`
- Heap variant is conditionally Copyable: `Copyable where Element: Copyable`

**Verdict**: Match heap variant — conditionally Copyable for API consistency.

```swift
extension Hash.Table.Static: Copyable where Element: Copyable {}
extension Hash.Table.Static: Sendable where Element: Sendable {}
```

### Overflow Handling

**Question**: What happens when insertion exceeds capacity?

**Options**:
1. **Trap**: `preconditionFailure("Hash table overflow")`
2. **Return Bool**: `insert(...) -> Bool` returns `false` on overflow
3. **Throw**: `insert(...) throws(Error)` with `.overflow` case

**Heap variant behavior**: Grows automatically, never overflows.

**Recommendation**: Return `Bool` — caller can check `shouldGrow` before insertion or handle `false` return.

### Dependencies

Following the minimal dependency principle for inline storage:

**Required**:
- `Index_Primitives` — for `Index<Element>`, `Index<Bucket>`
- `Ordinal_Primitives` / `Cardinal_Primitives` — for typed arithmetic

**Optional** (match heap if needed):
- `Hash_Primitives` — for `Hash.Protocol` (only if providing convenience methods)

**Not required**:
- `Property_Primitives` — keep minimal for inline storage

## Recommendation

### Recommended Design: Option A (Dual Arrays)

**Rationale**:
1. **API parity**: Same operations as `Hash.Table`, enabling shared documentation and mental model
2. **Full deletion support**: Tombstones prevent probe chain corruption
3. **decrementPositions(after:)**: Critical for ordered collection removal
4. **Proven design**: Matches heap variant that's already tested

The 2× memory cost is acceptable:
- Inline storage is for small capacities (≤64 elements typically)
- 64 buckets = 1KB, reasonable for stack allocation
- Simplicity and correctness outweigh memory savings

### Implementation Sketch

```swift
extension Hash.Table {
    /// A fixed-capacity hash table with inline storage.
    ///
    /// `Hash.Table.Static` stores hash-position pairs directly in the struct,
    /// avoiding heap allocation. Use for small, bounded collections.
    ///
    /// ## Bucket Capacity
    ///
    /// The `bucketCapacity` parameter specifies the number of hash buckets.
    /// MUST be a power of two. Effective element capacity is ~70% of bucket count:
    ///
    /// | Buckets | Max elements |
    /// |---------|--------------|
    /// | 8       | ~5           |
    /// | 16      | ~11          |
    /// | 32      | ~22          |
    /// | 64      | ~44          |
    ///
    /// ## Memory Layout
    ///
    /// Size: `bucketCapacity × 16 + 16` bytes (hashes + positions + header).
    ///
    /// ## Limitations
    ///
    /// - Cannot grow: check `shouldGrow` to detect overflow risk
    /// - Use `Hash.Table` for dynamic sizing
    public struct Inline<let bucketCapacity: Int>: ~Copyable {
        /// Hash values for each bucket. 0 = empty, Int.min = deleted.
        @usableFromInline
        var _hashes: InlineArray<bucketCapacity, Int>

        /// Element positions for each bucket.
        @usableFromInline
        var _positions: InlineArray<bucketCapacity, Int>

        /// Number of active elements.
        @usableFromInline
        var _count: Index<Element>.Count

        /// Number of occupied buckets (including deleted).
        @usableFromInline
        var _occupied: Index<Bucket>.Count

        /// Creates an empty inline hash table.
        ///
        /// - Precondition: `bucketCapacity` must be a power of two.
        @inlinable
        public init() {
            precondition(
                bucketCapacity > 0 && (bucketCapacity & (bucketCapacity - 1)) == 0,
                "bucketCapacity must be a power of two"
            )
            _hashes = .init(repeating: Self.empty)
            _positions = .init(repeating: 0)
            _count = .zero
            _occupied = .zero
        }

        // MARK: - Sentinels (match heap variant)

        @inlinable
        public static var empty: Int { 0 }

        @inlinable
        public static var deleted: Int { Int.min }

        @inlinable
        public static func normalize(_ hashValue: Int) -> Int {
            let hash = hashValue == 0 ? 1 : hashValue
            return hash == Int.min ? 1 : hash
        }
    }
}

extension Hash.Table.Static: Copyable where Element: Copyable {}
extension Hash.Table.Static: Sendable where Element: Sendable {}
```

### Migration Path for Consumers

1. **Dictionary.Ordered.Static**: Replace unused `_hashTable` with `Hash.Table<Key>.Inline<capacity>`
2. **Dictionary.Ordered.Small**: Use `Hash.Table<Key>.Inline` in inline mode
3. **Set.Ordered.Static**: Add `Hash.Table<Element>.Inline<capacity>` for O(1) lookup
4. **Set.Ordered.Small**: Use `Hash.Table<Element>.Inline` in inline mode

### File Organization

Following one-type-per-file convention:

```
swift-hash-table-primitives/Sources/
├── Hash Table Primitives Core/
│   ├── Hash.Table.swift              (existing)
│   ├── Hash.Table.Static.swift       (new - type definition)
├── Hash Table Primitives/
│   ├── Hash.Table+Lookup.swift       (existing)
│   ├── Hash.Table+Insertion.swift    (existing)
│   ├── Hash.Table+Removal.swift      (existing)
│   ├── Hash.Table.Static+Lookup.swift     (new)
│   ├── Hash.Table.Static+Insertion.swift  (new)
│   ├── Hash.Table.Static+Removal.swift    (new)
│   ├── Hash.Table.Static+Position.swift   (new - decrementPositions)
```

## Open Questions

1. **Should `Hash.Table.Static` share a protocol with `Hash.Table`?**
   - Pro: Generic algorithms could work with both
   - Con: Protocol overhead, may complicate `~Copyable` handling
   - Tentative: No protocol initially, add if pattern emerges

2. **Should we provide helper typealiases for common sizes?**
   ```swift
   extension Hash.Table {
       typealias Inline8 = Inline<8>
       typealias Inline16 = Inline<16>
       typealias Inline32 = Inline<32>
   }
   ```
   - Deferred: Add if usage patterns show demand

3. **Should inline hash table track load factor for diagnostics?**
   - The `shouldGrow` property (occupied > 70% capacity) provides this
   - No additional tracking needed

## Outcome

**Status**: DECISION

**Decision**: Implemented Option A (dual arrays, matching heap layout).

**Implementation**:
- Type defined in `Hash.Table.swift` (nested inside `Hash.Table` to avoid ~Copyable constraint issues)
- Operations in separate extension files in Hash Table Primitives Core
- 14 tests added covering all operations

**Files created**:
- `Hash.Table.swift` — type definition added as nested struct
- `Hash.Table.Static+Properties.swift` — count, isEmpty, capacity, shouldGrow, isFull
- `Hash.Table.Static+Lookup.swift` — position, index, contains
- `Hash.Table.Static+Insertion.swift` — insert, insert(__unchecked:)
- `Hash.Table.Static+Removal.swift` — remove, removeAll, rehash
- `Hash.Table.Static+PositionUpdates.swift` — decrementPositions, updatePosition
- `Hash.Table.Static+ForEach.swift` — forEachOccupied, forEachPosition
- `Hash.Table.Static.Tests.swift` — 14 tests

**Remaining work** (separate tasks):
1. Migrate `Dictionary.Ordered.Static` to use `Hash.Table.Static`
2. Update `Set.Ordered.Static` to use `Hash.Table.Static`
3. Update `Dictionary.Ordered.Small` and `Set.Ordered.Small` inline modes

## References

- `Storage.Static<N>`: `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Sources/Storage Primitives/Storage.swift:98-138`
- `Array.Static<N>`: `/Users/coen/Developer/swift-primitives/swift-array-primitives/Sources/Array Primitives Core/Array.swift:155-186`
- `Hash.Table`: `/Users/coen/Developer/swift-primitives/swift-hash-table-primitives/Sources/Hash Table Primitives Core/Hash.Table.swift`
- `Dictionary.Ordered.Static` (unused hash table): `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.swift:251-297`
- `Dictionary.Ordered.Static.index(of:)` (linear search): `/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered ~Copyable.swift:344-351`
- `Set.Ordered.Static`: `/Users/coen/Developer/swift-primitives/swift-set-primitives/Sources/Set Primitives Core/Set.swift:87-122`
