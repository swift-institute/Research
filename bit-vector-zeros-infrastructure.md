# Bit Vector Zeros Infrastructure

<!--
---
version: 1.0.0
last_updated: 2026-02-12
status: RECOMMENDATION
tier: 2
---
-->

## Context

`Storage<Element>.Pool.Inline<capacity>.allocate()` in swift-storage-primitives (tier 14) needs to find the first unallocated (zero) slot in a bitmap. The current implementation uses a raw `for i in 0..<capacity` loop with per-iteration typed index construction:

```swift
// Storage.Pool.Inline ~Copyable.swift:72-80
for i in 0..<capacity {
    let elementIndex = (try! Index<Element>.Count(i)).map(Ordinal.init)
    let bitIndex = elementIndex.retag(Bit.self)
    if !_slots[bitIndex] {
        _slots[bitIndex] = true
        _allocated += .one
        return Index<Element>.Bounded<capacity>(elementIndex)!
    }
}
fatalError("Unreachable: _allocated < capacity but no unset bit found")
```

This violates:

- **[IMPL-033]**: Raw `for i in 0..<capacity` loop instead of iteration infrastructure. The intent is "find first zero bit." The mechanism is a manual per-bit linear scan.
- **[IMPL-002]**: `try! Index<Element>.Count(i)` constructs a typed index from raw `Int` each iteration. The typed arithmetic machinery exists to avoid this.
- **[IMPL-000]**: The ideal expression is `_slots.zeros.first` — but no zeros infrastructure exists.

Meanwhile, the sibling operation `deinitialize.all()` correctly uses `.ones.forEach`:

```swift
// Storage.Pool.Inline ~Copyable.swift:140-142
unsafe base.pointee._slots.ones.forEach { bitIndex in
    unsafe base.pointee._pointer(at: bitIndex.retag(Element.self)).deinitialize(count: .one)
}
```

The asymmetry is clear: **set-bit scanning has infrastructure; zero-bit scanning does not.**

## Question

What API shape should zero-bit scanning infrastructure take in `Bit.Vector` and `Bit.Vector.Static<N>`, and how should it mirror the existing ones infrastructure?

## Analysis

### Inventory of Existing Ones/Pop API Surface

#### Tag Types

| Tag | Location | Purpose |
|-----|----------|---------|
| `Bit.Vector.Ones` | `Bit.Vector.Ones.swift:13` | Empty enum, used as tag for Property patterns and namespace for View/Static |
| `Bit.Vector.Pop` | `Bit.Vector.Pop.swift:13` | Empty enum, used as Property<Pop, Self>.View tag |
| `Bit.Vector.Set` | `Bit.Vector.Set.swift:13` | Empty enum for set operations |
| `Bit.Vector.Clear` | `Bit.Vector.Clear.swift:13` | Empty enum for clear operations |

#### Bit.Vector (~Copyable, heap-allocated)

| Accessor | Pattern | Return type | File |
|----------|---------|-------------|------|
| `.ones` | Custom view (NOT Property.View) | `Ones.View` | `Bit.Vector+ones.swift:20` |
| `.pop` | `Property<Pop, Self>.View` | `Property<Pop, Self>.View` | `Bit.Vector+pop.swift:17` |
| `.set` | `Property<Set, Self>.View` | `Property<Set, Self>.View` | `Bit.Vector+set.swift:18` |
| `.clear` | `Property<Clear, Self>.View` | `Property<Clear, Self>.View` | `Bit.Vector+clear.swift:16` |
| `.popcount` | Computed property | `Bit.Index.Count` | `Bit.Vector.swift:117` |

`Ones.View` is a custom struct (not `Property<Tag, Base>.View`) because `Bit.Vector` is `~Copyable` and the view must capture the word pointer safely for non-mutating contexts (including `deinit`). It conforms to both `Sequence.Protocol` and `Swift.Sequence`.

**`Ones.View.Iterator` algorithm** (`Bit.Vector.Ones.View.Iterator.swift:53-73`):
1. Scan words from index 0 upward, skipping words where `_currentWord == 0`
2. For non-zero words: `trailingZeroBitCount` finds lowest set bit position
3. Wegner/Kernighan clears it: `_currentWord &= _currentWord &- 1`
4. Compute global index: `wordIndex * bitsPerWord + bitPosition`
5. Guard: `globalIndex < _capacity` — stops at logical capacity
6. Complexity: O(popcount) total across all `next()` calls

**`Pop.first()` algorithm** (`Bit.Vector+pop.swift:38-56`):
1. Same word scan as Ones.View.Iterator
2. Additionally clears the bit in the **backing storage** (not just the iterator copy)
3. Returns the global bit index, or `nil` if no set bits

#### Bit.Vector.Static<let wordCount: Int> (Copyable, InlineArray)

| Accessor | Pattern | Return type | File |
|----------|---------|-------------|------|
| `.ones` | Direct property | `Ones.Static<wordCount>` | `Bit.Vector.Static+ones.swift:19` |
| `.set` | `Property<Bit.Vector.Set, Self>.View` | `Property<...>.View` | `Bit.Vector.Static+set.swift:16` |
| `.clear` | `Property<Bit.Vector.Clear, Self>.View` | `Property<...>.View` | `Bit.Vector.Static+clear.swift:16` |
| `.popcount` | Computed property | `Bit.Index.Count` | `Bit.Vector.Static.swift:85` |

`Ones.Static<wordCount>` is a custom struct that **copies the InlineArray** from the static vector (stack storage cannot be safely pointed into). Conforms to `Sequence.Protocol` and `Swift.Sequence`.

**`Ones.Static.Iterator` algorithm** (`Bit.Vector.Ones.Static.Iterator.swift:40-55`):
- Same Wegner/Kernighan algorithm as `Ones.View.Iterator`
- **No capacity guard** — iterates all set bits in the full `wordCount * bitWidth` range
- This is safe because only bits within logical range are ever set

**Static has NO `.pop` accessor.**

#### Bit.Vector.Dynamic (Copyable, Array-backed)

| Accessor | Pattern | Return type | File |
|----------|---------|-------------|------|
| `.ones` | `Property<Bit.Vector.Ones, Self>.View` | `Property<...>.View` | `Bit.Vector.Dynamic+ones.swift:28` |

Reuses the `Bit.Vector.Ones` tag. Custom `forEach` implementation using `enumerated()` + Wegner. `_read` only (no `_modify`).

#### Bit.Vector.Bounded, Bit.Vector.Inline

Neither has `.ones` today. Out of scope for this initial zeros infrastructure.

### Option A: `.zeros` Mirroring `.ones` (Full Sequence)

Add `Zeros.View`, `Zeros.Static<N>`, `Zeros.View.Iterator`, `Zeros.Static.Iterator` — exact structural mirrors of the `.ones` family. Both conform to `Sequence.Protocol` and `Swift.Sequence`.

**Algorithm**: Identical to the ones iterator, except:
- Initialize `_currentWord` with `~word` instead of `word`
- When advancing to next word: `_currentWord = ~_words[_wordIndex]` instead of `_currentWord = _words[_wordIndex]`
- Skip condition: `_currentWord == 0` (meaning `~word == 0`, i.e., `word == ~0` — all bits set)
- Same Wegner/Kernighan extraction on the complemented word
- Same capacity guard in `Zeros.View.Iterator` (critical — see invariant analysis below)

**`.zeros.first` comes for free** via `Swift.Sequence.first` default implementation, which calls `makeIterator().next()`.

**Consumer transformation**:
```swift
// Before:
for i in 0..<capacity {
    let elementIndex = (try! Index<Element>.Count(i)).map(Ordinal.init)
    let bitIndex = elementIndex.retag(Bit.self)
    if !_slots[bitIndex] { ... }
}

// After:
let bitIndex = _slots.zeros.first!
```

**Pros**:
- Complete symmetry with `.ones`
- `.zeros.forEach { }` enables iterating all free slots (useful for diagnostics, debugging, bulk operations)
- `.zeros.first` solves the immediate consumer need
- Follows every established convention — file organization, naming, Sequence.Protocol conformance
- No new patterns introduced

**Cons**:
- `.zeros.forEach` on `Bit.Vector.Static` has the padding-zero concern (see invariant analysis)
- More files than a minimal approach

### Option B: `.zeros.first` Only (Query-Only)

Add a single method that returns the first zero-bit index. No iteration, no Sequence conformance.

**Approach**: On `Bit.Vector`, add a computed property or method:
```swift
extension Bit.Vector {
    public var firstZero: Bit.Index? { ... }
}
```

**Pros**:
- Minimal surface area — exactly what the consumer needs
- No padding-zero concern (single result, consumer validates)

**Cons**:
- `firstZero` is a **compound identifier** — violates [API-NAME-002]
- No `.zeros.forEach` for future consumers
- Asymmetric with `.ones` infrastructure
- Every future zero-scanning need requires a new ad-hoc method

### Option C: `.pop.zero()` or `.claim.first()` (Mutating Find-and-Set)

Combine find-first-zero with set-to-one in a single atomic operation.

**Cons**:
- Mixes bit-vector concerns with pool-level semantics (counting, bounded index construction)
- `.pop` semantically means "remove" (find set bit, clear it). The complement would be "claim" (find clear bit, set it). Different semantic domain.
- `zero()` as a method name on Pop is confusing
- Over-abstracts — the pool already has the three-step sequence (find, set, count) and owns the semantics

**Rejected**: The bit vector should provide the query; the pool owns the mutation semantics.

### Comparison

| Criterion | Option A: Full .zeros | Option B: .firstZero | Option C: Mutating |
|-----------|----------------------|---------------------|--------------------|
| [API-NAME-002] compliance | `.zeros.first` — nested, clean | `firstZero` — compound, violation | `.claim.first()` — nested but wrong domain |
| Symmetry with `.ones` | Exact mirror | No mirror | Partial |
| Consumer need (allocate) | `_slots.zeros.first!` | `_slots.firstZero!` | `_slots.claim.first()!` |
| Future consumers (diagnostics) | `.zeros.forEach { }` | N/A | N/A |
| Files added | 8 (mirrors ones exactly) | 1-2 | 2-3 |
| New patterns introduced | None | Ad-hoc method | New tag/accessor |
| Convention compliance | Full | [API-NAME-002] violation | Semantic mismatch |

### Trailing-Zeros-Beyond-Capacity Invariant

**Critical concern**: `Bit.Vector.Static<1>` has 64 bits of storage but `Storage.Pool.Inline<16>` uses only 16. Bits 16-63 are always zero. Does `.zeros.first` return a valid result?

**Analysis**:

For `Bit.Vector` (has `capacity` field): `Zeros.View.Iterator` includes `guard globalIndex < _capacity else { return nil }`, matching `Ones.View.Iterator`. Padding zeros are filtered out. **No concern.**

For `Bit.Vector.Static` (no capacity field, capacity = `wordCount * bitWidth`): `Zeros.Static.Iterator` iterates ALL zero bits in the full storage, including padding. This mirrors `Ones.Static.Iterator`, which iterates all set bits without a capacity bound.

**Why this is safe for `.zeros.first`**:

The consumer (`Storage.Pool.Inline.allocate()`) calls `.zeros.first` only after verifying `_allocated < slotCapacity`. This guarantees at least one zero bit exists in `[0, capacity)`. Since bits are set sequentially from index 0 upward (allocation), and only bits in `[0, capacity)` are ever set, any zero bit in `[0, capacity)` has a lower index than any padding zero in `[capacity, wordCount*bitWidth)`. Therefore `.zeros.first` (which returns the lowest-indexed zero) always returns a valid index within logical capacity.

**The invariant**: Callers of `.zeros.first` on `Bit.Vector.Static` MUST ensure at least one zero exists within the logical range. This parallels the implicit invariant on `.ones.first` on `Bit.Vector.Static` — callers must know that set bits are within logical range.

**For `.zeros.forEach`**: Iterates ALL zero bits including padding. Callers must filter by logical capacity if needed. This is documented behavior, not a bug. For `Bit.Vector` (with capacity), `Zeros.View` handles this automatically.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option A — full `.zeros` infrastructure mirroring `.ones`.

**Rationale**: Option A is the only option that follows all conventions. It provides exact symmetry with `.ones`, satisfies the immediate consumer need via `.zeros.first`, and enables future zero-bit iteration via `.zeros.forEach`. The file count (8 files) is a feature, not a cost — it follows [API-IMPL-005] (one type per file) and makes each component independently testable.

## Implementation Plan

### New Tag Type

**File**: `Bit.Vector.Zeros.swift`

```swift
extension Bit.Vector {
    public enum Zeros: Sendable {}
}
```

Mirrors `Bit.Vector.Ones.swift:12-14` exactly.

### Zeros.View (for Bit.Vector)

**File**: `Bit.Vector.Zeros.View.swift`

```swift
extension Bit.Vector.Zeros {
    @safe
    public struct View: Copyable, @unchecked Sendable {
        @usableFromInline let _words: UnsafeMutablePointer<UInt>
        @usableFromInline let _wordCount: Index_Primitives.Index<UInt>.Count
        @usableFromInline let _capacity: Bit.Index.Count

        @inlinable
        package init(
            words: UnsafeMutablePointer<UInt>,
            wordCount: Index_Primitives.Index<UInt>.Count,
            capacity: Bit.Index.Count
        ) {
            unsafe self._words = words
            self._wordCount = wordCount
            self._capacity = capacity
        }
    }
}
```

Mirrors `Bit.Vector.Ones.View.swift` exactly — same fields, same init signature.

### Zeros.View.Iterator

**File**: `Bit.Vector.Zeros.View.Iterator.swift`

```swift
extension Bit.Vector.Zeros.View {
    @safe
    public struct Iterator: IteratorProtocol {
        @usableFromInline let _words: UnsafeMutablePointer<UInt>
        @usableFromInline let _wordCount: Index_Primitives.Index<UInt>.Count
        @usableFromInline let _capacity: Bit.Index.Count
        @usableFromInline var _wordIndex: Index_Primitives.Index<UInt>
        @usableFromInline var _currentWord: UInt  // stores ~word (complemented)

        @inlinable
        package init(view: Bit.Vector.Zeros.View) {
            unsafe self._words = view._words
            self._wordCount = view._wordCount
            self._capacity = view._capacity
            self._wordIndex = .zero
            if view._wordCount > .zero {
                unsafe self._currentWord = ~view._words[.zero]  // KEY DIFFERENCE: complement
            } else {
                self._currentWord = 0
            }
        }

        @inlinable
        public mutating func next() -> Bit.Index? {
            while _currentWord == 0 {
                let next = _wordIndex.successor.saturating()
                guard next < _wordCount else { return nil }
                _wordIndex = next
                unsafe _currentWord = ~_words[_wordIndex]  // KEY DIFFERENCE: complement
            }

            let bitPosition = _currentWord.trailingZeroBitCount
            _currentWord &= _currentWord &- 1  // Wegner: clear lowest set bit of complemented word

            let wordAsCount = Index_Primitives.Index<UInt>.Count(_wordIndex)
            let baseBitCount = wordAsCount * .bitsPerWord
            let globalIndex = baseBitCount.map(Ordinal.init) + Bit.Index.Count(Cardinal(UInt(bitPosition)))

            guard globalIndex < _capacity else { return nil }
            return globalIndex
        }
    }
}
```

Identical to `Ones.View.Iterator` except two lines marked `KEY DIFFERENCE`: the word is complemented (`~`) on read. The Wegner/Kernighan extraction and capacity guard are unchanged.

### Zeros.View + Sequence.Protocol

**File**: `Bit.Vector.Zeros.View+Sequence.Protocol.swift`

```swift
extension Bit.Vector.Zeros.View: Sequence.`Protocol` {
    public typealias Element = Bit.Index

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(view: self)
    }
}

extension Bit.Vector.Zeros.View: Swift.Sequence {
    @inlinable
    public var underestimatedCount: Int { 0 }
}
```

Mirrors `Bit.Vector.Ones.View+Sequence.Protocol.swift` exactly.

### Accessor on Bit.Vector

**File**: `Bit.Vector+zeros.swift`

```swift
extension Bit.Vector {
    @inlinable
    public var zeros: Zeros.View {
        unsafe Zeros.View(words: _words, wordCount: _wordCount, capacity: capacity)
    }
}
```

Mirrors `Bit.Vector+ones.swift:20-22` exactly.

### Zeros.Static (for Bit.Vector.Static)

**File**: `Bit.Vector.Zeros.Static.swift`

```swift
extension Bit.Vector.Zeros {
    @safe
    public struct Static<let wordCount: Int>: Copyable, Sendable {
        @usableFromInline let _storage: InlineArray<wordCount, UInt>

        @inlinable
        package init(storage: InlineArray<wordCount, UInt>) {
            self._storage = storage
        }
    }
}

extension Bit.Vector.Zeros.Static: Sequence.`Protocol` {
    public typealias Element = Bit.Index

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: _storage)
    }
}

extension Bit.Vector.Zeros.Static: Swift.Sequence {
    @inlinable
    public var underestimatedCount: Int { 0 }
}
```

Mirrors `Bit.Vector.Ones.Static.swift` exactly.

### Zeros.Static.Iterator

**File**: `Bit.Vector.Zeros.Static.Iterator.swift`

```swift
extension Bit.Vector.Zeros.Static {
    @safe
    public struct Iterator: IteratorProtocol {
        @usableFromInline let _storage: InlineArray<wordCount, UInt>
        @usableFromInline var _wordIndex: Int
        @usableFromInline var _currentWord: UInt  // stores ~word (complemented)

        @inlinable
        package init(storage: InlineArray<wordCount, UInt>) {
            self._storage = storage
            self._wordIndex = 0
            if wordCount > 0 {
                self._currentWord = ~storage[0]  // KEY DIFFERENCE: complement
            } else {
                self._currentWord = 0
            }
        }

        @inlinable
        public mutating func next() -> Bit.Index? {
            while _currentWord == 0 {
                _wordIndex += 1
                guard _wordIndex < wordCount else { return nil }
                _currentWord = ~_storage[_wordIndex]  // KEY DIFFERENCE: complement
            }

            let bitPosition = _currentWord.trailingZeroBitCount
            _currentWord &= _currentWord &- 1

            let wordCount = Index_Primitives.Index<UInt>.Count(Cardinal(UInt(_wordIndex)))
            let baseBitCount = wordCount * .bitsPerWord
            return baseBitCount.map(Ordinal.init) + Bit.Index.Count(Cardinal(UInt(bitPosition)))
        }
    }
}
```

Mirrors `Ones.Static.Iterator` exactly, except two lines with `~` complement. No capacity guard — matches `Ones.Static.Iterator` behavior.

### Accessor on Bit.Vector.Static

**File**: `Bit.Vector.Static+zeros.swift`

```swift
extension Bit.Vector.Static {
    @inlinable
    public var zeros: Bit.Vector.Zeros.Static<wordCount> {
        Bit.Vector.Zeros.Static<wordCount>(storage: _storage)
    }
}
```

Mirrors `Bit.Vector.Static+ones.swift:19-21` exactly.

### Dynamic Zeros

**File**: `Bit.Vector.Dynamic+zeros.swift`

```swift
extension Bit.Vector.Dynamic {
    @inlinable
    public var zeros: Property<Bit.Vector.Zeros, Self>.View {
        mutating _read {
            yield unsafe Property<Bit.Vector.Zeros, Self>.View(&self)
        }
    }
}

extension Property.View where Tag == Bit.Vector.Zeros, Base == Bit.Vector.Dynamic {
    @inlinable
    public func forEach(_ body: (Bit.Index) -> Void) {
        let storage = unsafe base.pointee._storage
        let count = unsafe base.pointee._count
        let countInt = Int(clamping: count)
        let bitsPerWord = UInt.bitWidth

        for (wordIndex, word) in storage.enumerated() {
            var inverted = ~word
            while inverted != 0 {
                let bitIndex = inverted.trailingZeroBitCount
                let globalIndex = wordIndex * bitsPerWord + bitIndex
                if globalIndex < countInt {
                    body(Bit.Index(__unchecked: (), Ordinal(UInt(globalIndex))))
                }
                inverted &= inverted &- 1
            }
        }
    }
}
```

Mirrors `Bit.Vector.Dynamic+ones.swift` exactly, with `~word` complement and renamed local.

### Complete File Manifest

| # | New file | Mirrors | Contents |
|---|----------|---------|----------|
| 1 | `Bit.Vector.Zeros.swift` | `Bit.Vector.Ones.swift` | `enum Zeros: Sendable {}` |
| 2 | `Bit.Vector.Zeros.View.swift` | `Bit.Vector.Ones.View.swift` | `Zeros.View` struct |
| 3 | `Bit.Vector.Zeros.View+Sequence.Protocol.swift` | `Bit.Vector.Ones.View+Sequence.Protocol.swift` | Sequence conformances |
| 4 | `Bit.Vector.Zeros.View.Iterator.swift` | `Bit.Vector.Ones.View.Iterator.swift` | `~word` + Wegner + capacity guard |
| 5 | `Bit.Vector.Zeros.Static.swift` | `Bit.Vector.Ones.Static.swift` | `Zeros.Static<wordCount>` + Sequence |
| 6 | `Bit.Vector.Zeros.Static.Iterator.swift` | `Bit.Vector.Ones.Static.Iterator.swift` | `~word` + Wegner, no capacity guard |
| 7 | `Bit.Vector+zeros.swift` | `Bit.Vector+ones.swift` | `.zeros` accessor |
| 8 | `Bit.Vector.Static+zeros.swift` | `Bit.Vector.Static+ones.swift` | `.zeros` accessor |
| 9 | `Bit.Vector.Dynamic+zeros.swift` | `Bit.Vector.Dynamic+ones.swift` | `Property.View` + `forEach` |

All files go in: `swift-bit-vector-primitives/Sources/Bit Vector Primitives/`

### Consumer Transformation

**Storage.Pool.Inline.allocate()** — Before:

```swift
for i in 0..<capacity {
    let elementIndex = (try! Index<Element>.Count(i)).map(Ordinal.init)
    let bitIndex = elementIndex.retag(Bit.self)
    if !_slots[bitIndex] {
        _slots[bitIndex] = true
        _allocated += .one
        return Index<Element>.Bounded<capacity>(elementIndex)!
    }
}
fatalError("Unreachable: _allocated < capacity but no unset bit found")
```

**Storage.Pool.Inline.allocate()** — After:

```swift
let bitIndex = _slots.zeros.first!  // safe: guard _allocated < slotCapacity passed
_slots[bitIndex] = true
_allocated += .one
return Index<Element>.Bounded<capacity>(bitIndex.retag(Element.self))!
```

**Lines**: 10 → 4. **Violations fixed**: [IMPL-033] (no raw loop), [IMPL-002] (no per-iteration Int→typed construction).

The force-unwrap on `.zeros.first!` is safe because the preceding guard `_allocated < slotCapacity` guarantees at least one zero bit exists within the logical capacity. The force-unwrap on `.Bounded<capacity>(...)!` is safe because the bit index is within `[0, capacity)` (proven by the invariant analysis above).

### Test Plan

Test file: `Bit Vector Primitives Tests/Bit.Vector.Zeros Tests.swift`

| Test | Verifies |
|------|----------|
| `zeros_first_allClear` | `.zeros.first` on all-zero vector returns index 0 |
| `zeros_first_someSet` | `.zeros.first` skips set bits, returns first clear |
| `zeros_first_allSet` | `.zeros.first` returns nil when all bits set |
| `zeros_forEach_allClear` | `.zeros.forEach` visits all bit positions |
| `zeros_forEach_someSet` | `.zeros.forEach` visits only clear positions |
| `zeros_forEach_empty` | `.zeros.forEach` on empty vector is no-op |
| `static_zeros_first` | `Bit.Vector.Static.zeros.first` finds first zero |
| `static_zeros_first_allOnes` | Returns padding position (documents invariant) |
| `static_zeros_forEach_count` | Count of zeros = capacity - popcount |
| `view_zeros_capacityBound` | `Zeros.View` respects capacity, doesn't return padding indices |
| `dynamic_zeros_forEach` | `Bit.Vector.Dynamic` zeros forEach works |

### Bounded and Inline: Future Work

`Bit.Vector.Bounded` and `Bit.Vector.Inline` do not have `.ones` today. Adding `.zeros` without `.ones` would be asymmetric. These variants should get both `.ones` and `.zeros` in a future pass, following the same patterns established here. Not in scope for this change.

## References

- `Bit.Vector.Ones.View.Iterator.swift` — canonical ones iteration algorithm
- `Bit.Vector.Ones.Static.Iterator.swift` — canonical static ones iteration
- `Storage.Pool.Inline ~Copyable.swift:66-82` — consumer: allocate() with raw loop
- `Storage.Arena.Inline ~Copyable.swift:126-128` — consumer: deinitialize.all() using .ones.forEach
- Wegner, P. (1960). "A technique for counting ones in a binary computer." — The x & (x-1) trick
- [IMPL-033] Implementation skill — iteration must use highest-level abstraction
- [IMPL-002] Implementation skill — typed arithmetic over raw Int
- [IMPL-000] Implementation skill — call-site-first design
- [API-NAME-002] Naming skill — no compound identifiers
- [INFRA-108] Existing infrastructure — bit vector bulk operations catalog
