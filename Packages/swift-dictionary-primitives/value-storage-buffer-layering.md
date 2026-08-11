# Value Storage Buffer Layering

<!--
---
version: 1.0.0
last_updated: 2026-02-10
status: RECOMMENDATION
tier: 2
---
-->

## Context

Dictionary.Ordered has pre-existing build failures because its value storage uses `Storage<Value>` — the enum **namespace**, not a concrete type. The methods Dictionary calls (`.create()`, `.pointer()`, `.move()`, `.deinitialize()`, `.shiftLeft()`, `.copy()`, `.count`, `.capacity`) exist on `Storage<Value>.Heap` (the class), not on the `Storage<Value>` enum.

Meanwhile, Set.Ordered, Stack, and Vector have all been migrated to the canonical `memory ← storage ← buffer ← data structure` layering. These types compose `Buffer<Element>.Linear` (and its variants) rather than using raw Storage directly.

This research determines how Dictionary.Ordered should adopt the same pattern.

## Question

How should Dictionary.Ordered's four variants store values, following the `buffer ← data structure` pattern already applied to Set, Stack, and Vector?

## Constraints

1. **Key-value parallelism**: Values are indexed by key positions. `_keys[i]` ↔ `_values[i]` is an invariant.
2. **Cross-domain indexing**: Dictionary looks up keys via `Index<Key>` but accesses values via `Index<Value>`. Requires `.retag(Value.self)` at the boundary.
3. **~Copyable values**: `Value: ~Copyable` must be supported. Replace operations need move + reinitialize, not assignment.
4. **Conditional Copyable**: `Dictionary.Ordered: Copyable where Value: Copyable`. The value buffer type must support this.
5. **No direct buffer-primitives dependency**: Dictionary's Package.swift currently depends on set-primitives, hash-table-primitives, index-primitives. Buffer access is only transitive through Set.

## Established Pattern

Every migrated data structure follows this mapping:

| Data Structure Variant | Buffer Type | Example |
|------------------------|-------------|---------|
| Dynamic (growable) | `Buffer<E>.Linear` | `Set.Ordered.buffer`, `Stack._buffer` |
| Bounded / Fixed | `Buffer<E>.Linear.Bounded` | `Set.Ordered.Fixed.buffer`, `Stack.Bounded._buffer` |
| Static / Inline | `Buffer<E>.Linear.Inline<N>` | `Set.Ordered.Static._buffer`, `Stack.Static._buffer` |
| Small (inline + spill) | `Buffer<E>.Linear.Small<N>` | `Set.Ordered.Small._buffer`, `Stack.Small._buffer` |

Each Buffer variant wraps the corresponding Storage type and provides:
- Typed `count: Index<Element>.Count` and `capacity: Index<Element>.Count`
- Subscript with `_read` / `_modify` accessors
- `append()`, `remove(at:)`, `removeAll()`, `reserveCapacity()`
- Automatic growth (dynamic), throws/returns on overflow (bounded), fixed size (inline)
- Initialization tracking: `Storage.Initialization` ranges (heap) or `Bit.Vector.Static<4>` per-slot bits (inline)

## Analysis

### Option A: Buffer<Value>.Linear for values (full migration)

Replace each Dictionary variant's value storage with the corresponding Buffer variant:

| Dictionary Variant | Current | After |
|-------------------|---------|-------|
| `Ordered` | `_values: Storage<Value>` + `_cachedValuePtr` | `_values: Buffer<Value>.Linear` |
| `Bounded` | `_values: Storage<Value>` + `_cachedValuePtr` | `_values: Buffer<Value>.Linear.Bounded` |
| `Static` | `_values: Storage<Value>.Static<N>` | `_values: Buffer<Value>.Linear.Inline<N>` |
| `Small` | `_inlineValues` + `_heapValues` + `_heapValuePtr` | `_values: Buffer<Value>.Linear.Small<N>` |

**What gets eliminated:**
- `_cachedValuePtr: UnsafeMutablePointer<Value>` — Buffer provides subscript access directly
- Manual `ensureCapacity()` growth logic — Buffer.Linear handles growth internally
- Manual `_spillToHeap()` — Buffer.Linear.Small handles spill internally
- `_heapValues: Storage<Value>?` + `_heapValuePtr` — collapsed into single Buffer.Linear.Small
- `Dictionary.Ordered.Storage+Helpers.swift` — retag helpers replaced by direct buffer subscript + `.retag()`
- CoW `makeUnique()` must be re-evaluated (see Conditional Copyable and CoW section below)

**Operations mapping:**

| Dictionary operation | Current (raw Storage) | After (Buffer) |
|---------------------|----------------------|----------------|
| Read value at key index | `_cachedValuePtr[keyIndex.retag(Value.self)]` | `_values[keyIndex.retag(Value.self)]` |
| Insert new value | Manual `_values.initialize(to:at:)` + `_values.count =` | `_values.append(value)` |
| Remove value (shift left) | `_values.move(at:)` + `_values.shiftLeft(removedAt:)` | `_values.remove(at: keyIndex.retag(Value.self))` |
| Replace value (~Copyable) | `_values.move(at:)` + `_values.initialize(to:at:)` | See ~Copyable replace analysis below |
| Replace value (Copyable) | Same as ~Copyable | `_values[index.retag(Value.self)] = newValue` (via `_modify` subscript) |
| Reserve capacity | Manual `ensureCapacity()` with Int arithmetic | `_values.reserveCapacity(count)` |
| Clear | `_values.deinitialize()` | `_values.removeAll()` |
| Iterate values | Manual typed `while` loop + `_cachedValuePtr[idx.retag()]` | Manual typed `while` loop + `_values[idx.retag()]` |

**~Copyable value replacement:**

Buffer.Linear provides a `_modify` subscript:
```swift
subscript(index: Index<Element>) -> Element {
    _read { yield unsafe storage.pointer(at: index).pointee }
    _modify { yield unsafe &storage.pointer(at: index).pointee }
}
```

The `_modify` accessor yields an `inout` reference. For `~Copyable` values, assignment through `inout` moves the new value in and consumes the old. The Dictionary replace pattern becomes:
```swift
// ~Copyable: move out old, assign new through _modify
var old = _values[valueIndex]   // _read: borrow → but needs consume semantics
_values[valueIndex] = newValue  // _modify: move-assign
```

However, `_read` yields a borrow, not a consume. Moving out requires `_modify` or a dedicated method. Three resolution options:

| # | Approach | Where |
|---|----------|-------|
| A1 | Add `replace(at:with:) -> Element` to Buffer.Linear | buffer-primitives |
| A2 | Use `_modify` to move out via temporary: `swap(&_values[idx], &newValue)` | dictionary-primitives |
| A3 | Accept that ~Copyable replace discards old value (no return) via `_modify` assign | dictionary-primitives |

Option A1 is cleanest — adds a method like `Buffer.Linear.remove(at:)` but replaces instead of shifts. Returns the old value. Zero package-access concerns. Also benefits any future random-access container.

**Advantages:**
- Consistent with Set, Stack, Vector — same layering pattern
- Eliminates `_cachedValuePtr` and all pointer cache invalidation bugs
- Eliminates manual growth, spill, and count-sync logic
- Small variant value properties collapse from 3 (`_inlineValues` + `_heapValues` + `_heapValuePtr`) to 1 (`_values: Buffer<Value>.Linear.Small<N>`); full collapse to 2 stored properties requires follow-up key migration
- Automatic initialization tracking via Bit.Vector.Static (inline) and Storage.Initialization (heap)
- Typed `count` and `capacity` come for free from Buffer

**Disadvantages:**
- Requires adding buffer-primitives dependency to dictionary-primitives
- May need new `replace(at:with:)` method on Buffer.Linear for ~Copyable values
- Buffer.Linear tracks its own count separately from `_keys.count` — potential for desync
- Breaks every method in the current implementation (complete rewrite of mutation paths)

### Option B: Storage<Value>.Heap directly (minimal fix)

Change `_values: Storage<Value>` → `_values: Storage<Value>.Heap` to fix the build, keeping everything else.

**What changes:**
- Type annotation on stored property (enum namespace → concrete class)
- Calls to `.create()`, `.pointer()`, `.move()`, etc. now resolve correctly

**Advantages:**
- Minimal change — fixes build with ~5 line changes
- Preserves existing logic and `_cachedValuePtr` pattern

**Disadvantages:**
- Violates established layering convention (data structure → buffer → storage → memory)
- Dictionary remains the only data structure using raw Storage
- Doesn't fix any of the manual growth, spill, or count management issues
- `_cachedValuePtr` invalidation bugs remain possible
- Static and Small variants still use `Storage.Static` instead of `Buffer.Linear.Inline`

### Option C: Hybrid — Buffer for Dynamic/Bounded, Storage.Inline for Static/Small

Only migrate the heap-backed variants to Buffer. Keep inline variants on Storage.Inline since they have fundamentally different access patterns (no growth, no CoW).

| Dictionary Variant | After |
|-------------------|-------|
| `Ordered` | `_values: Buffer<Value>.Linear` |
| `Bounded` | `_values: Buffer<Value>.Linear.Bounded` |
| `Static` | `_values: Storage<Value>.Inline<N>` (keep) |
| `Small` | `_inlineValues: Storage<Value>.Inline<N>` + `_heapValues: Buffer<Value>.Linear?` (partial) |

**Advantages:**
- Migrates the most impactful variants (dynamic, bounded)
- Inline variants stay simple

**Disadvantages:**
- Inconsistent with Set and Stack, which use `Buffer.Linear.Inline` and `Buffer.Linear.Small` for ALL variants
- Small variant still has manual spill logic instead of delegating to `Buffer.Linear.Small`
- Two different access patterns in the same package

## Bit.Vector / Bitset Consideration

The current Dictionary.Static and Dictionary.Small use `Storage<Value>.Static<capacity>` for inline value storage. This type internally uses `Bit.Vector.Static<4>` (256-bit bitmap) for per-slot initialization tracking. All lifecycle operations (initialize, move, deinitialize) automatically update the bitmap.

With Option A (full Buffer migration):
- `Buffer<Value>.Linear.Inline<N>` wraps `Storage<Value>.Inline<N>` which has `Bit.Vector.Static<4>` — **automatic, zero additional code**
- `Buffer<Value>.Linear.Small<N>` handles inline/heap dispatch, with inline path using the same bit-vector tracking
- Dictionary needs NO direct dependency on bit-vector-primitives — it's transitive through buffer → storage → bit-vector

With Option B (minimal fix):
- Inline variants continue using `Storage.Static` directly — bit-vector tracking still works
- Heap variants use raw `Storage.Heap` — initialization tracking via `Storage.Initialization` ranges

The bit-vector consideration **favors Option A**: using Buffer types provides the correct initialization tracking at every layer without Dictionary needing to know about it.

## Conditional Copyable and CoW

**Verified**: `Buffer.Linear` and `Buffer.Linear.Bounded` have conditional Copyable conformance (`Buffer.swift:599-602`):

```swift
extension Buffer.Linear: Copyable where Element: Copyable {}
extension Buffer.Linear.Bounded: Copyable where Element: Copyable {}
```

`Buffer.Linear.Inline` and `Buffer.Linear.Small` are unconditionally `~Copyable` (commented-out conditional Copyable at lines 611, 616 — due to deinit requirement).

**Compatibility with Dictionary's conditional Copyable:**

| Dictionary Variant | Conditional Copyable | Buffer Type Copyability | Compatible |
|-------------------|---------------------|------------------------|------------|
| `Ordered` | `Copyable where Value: Copyable` | `Buffer<V>.Linear: Copyable where V: Copyable` | ✓ |
| `Bounded` | `Copyable where Value: Copyable` | `Buffer<V>.Linear.Bounded: Copyable where V: Copyable` | ✓ |
| `Static` | Unconditionally ~Copyable | `Buffer<V>.Linear.Inline`: unconditionally ~Copyable | ✓ |
| `Small` | Unconditionally ~Copyable | `Buffer<V>.Linear.Small`: unconditionally ~Copyable | ✓ |

**CoW implications:**

Currently `makeUnique()` checks `isKnownUniquelyReferenced(&_values)` and calls `_values.copy()`. With `Buffer<Value>.Linear`, the CoW pattern needs to operate on the buffer's internal `storage: Storage<Element>.Heap` (a class reference). Buffer.Linear already stores the heap as a reference type — when the struct is copied (allowed for Copyable values), the heap reference is shared. Mutation must check uniqueness and copy if needed.

**Verified**: `Buffer.Linear` already provides `ensureUnique()` (`Buffer.Linear Copyable.swift:28`):

```swift
@discardableResult
public mutating func ensureUnique() -> Bool {
    if !isKnownUniquelyReferenced(&storage) {
        _makeUnique()
        return true
    }
    return false
}
```

`Set.Ordered.makeUnique()` already uses this (`Set.Ordered Copyable.swift:54-56`):
```swift
mutating func makeUnique() {
    buffer.ensureUnique()
    hashTable.ensureUnique()
}
```

Dictionary's CoW becomes: `_values.ensureUnique()` — zero new infrastructure needed.

## Key Storage Consideration (Static and Small)

A secondary question: should Dictionary.Static and Dictionary.Small also migrate key storage?

**Current key storage:**
- `Static`: `InlineArray<capacity, Key?>` + `InlineArray<capacity, Int>` (raw hash table)
- `Small`: Same inline + `Set<Key>.Ordered?` for heap mode

**Set.Ordered pattern:**
- `Static`: `Buffer<Element>.Linear.Inline<N>` + `Hash.Table<Element>.Static<N>`
- `Small`: `Buffer<Element>.Linear.Small<N>` + `Hash.Table<Element>?`

**Recommendation**: Migrate key storage to match Set's pattern in a **separate** follow-up. The value storage migration is the primary blocker (build failures). Key storage migration would additionally:
- Replace `InlineArray<capacity, Key?>` with `Buffer<Key>.Linear.Inline<capacity>` (eliminates optional wrapping)
- Replace `InlineArray<capacity, Int>` with `Hash.Table<Key>.Static<capacity>` (proper hash table with Bit.Vector tracking)
- Eliminate `_count: Int` (Buffer tracks count)

## Comparison

| Criterion | A (Full Buffer) | B (Storage.Heap) | C (Hybrid) |
|-----------|-----------------|-------------------|------------|
| Layering consistency | ✓ matches Set/Stack | ✗ raw Storage | partial |
| Eliminates `_cachedValuePtr` | ✓ | ✗ | partial |
| Automatic growth | ✓ | ✗ manual | partial |
| Small variant simplification | ✓ (3 value props → 1) | ✗ | ✗ |
| Bit.Vector tracking automatic | ✓ | partial | partial |
| Build fix effort | HIGH (rewrite) | LOW (~5 lines) | MEDIUM |
| New Buffer.Linear methods needed | `replace(at:with:)` | none | `replace(at:with:)` |
| Package.swift change | add buffer-primitives | none | add buffer-primitives |
| Count desync risk | low (but possible) | none (manual) | mixed |

## Outcome

**Status**: IN_PROGRESS

**Recommendation**: Option A (Full Buffer Migration)

**Rationale**: Dictionary is the last data structure not following the established buffer layering. Option B fixes the build but leaves Dictionary as an outlier. Option A brings Dictionary in line with Set, Stack, and Vector, eliminating entire categories of manual memory management (pointer caching, growth logic, spill logic, initialization tracking). The `replace(at:with:)` method is a small, well-scoped addition to Buffer.Linear that benefits any future random-access container.

**Implementation order (proposed):**

1. Add `replace(at:with:) -> Element` to `Buffer.Linear` (~Copyable extension) in buffer-primitives
2. Add `swift-buffer-primitives` dependency to dictionary-primitives Package.swift
3. Migrate `Dictionary.Ordered` (dynamic): `Storage<Value>` + `_cachedValuePtr` → `Buffer<Value>.Linear`
4. Migrate `Dictionary.Ordered.Bounded`: same pattern with `Buffer<Value>.Linear.Bounded`
5. Migrate `Dictionary.Ordered.Static`: `Storage<Value>.Static<N>` → `Buffer<Value>.Linear.Inline<N>`, eliminate `_count: Int`
6. Migrate `Dictionary.Ordered.Small`: collapse value storage to `Buffer<Value>.Linear.Small<N>`, eliminate `_heapValues`/`_heapValuePtr`/manual spill
7. Delete `Dictionary.Ordered.Storage+Helpers.swift` (no longer needed)
8. Update all mutation methods to use Buffer API (append, remove, replace, subscript) with `.retag(Value.self)` at key→value boundary per [IMPL-003]
9. Update CoW `makeUnique()` → `_values.ensureUnique()`
10. Run `swift build && swift test`

**Follow-up (separate research):**
- Migrate Static/Small key storage from `InlineArray<Key?>` + raw hash table to `Buffer<Key>.Linear.Inline` + `Hash.Table<Key>.Static`

## References

- Set.Ordered stored properties: `swift-set-primitives/.../Set.swift:45-62`
- Stack stored properties: `swift-stack-primitives/.../Stack.swift:73-76`
- Buffer.Linear definition: `swift-buffer-primitives/.../Buffer.swift` (header + storage)
- Buffer.Linear subscript: `swift-buffer-primitives/.../Buffer.Linear+Subscript.swift:3-16`
- Buffer.Linear conditional Copyable: `swift-buffer-primitives/.../Buffer.swift:599-602`
- Storage.Inline bit-vector tracking: `swift-storage-primitives/.../Storage.swift:166-211` (`_slots: Bit.Vector.Static<4>`)
- Dictionary.Ordered current: `swift-dictionary-primitives/.../Dictionary.Ordered.swift:134-423`
- Cached-value-pointer research (superseded by this): `swift-dictionary-primitives/Research/cached-value-pointer-int-elimination.md`
