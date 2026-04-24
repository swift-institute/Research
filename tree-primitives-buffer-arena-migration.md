# Tree Primitives Buffer.Arena Migration

<!--
---
version: 1.1.0
last_updated: 2026-03-10
status: DEFERRED
research_tier: 2
applies_to: [swift-tree-primitives, swift-buffer-primitives]
normative: false
---
-->

## Context

swift-tree-primitives contains two tree families — `Tree.N<Element, let n: Int>` (fixed-branching) and `Tree.Unbounded<Element>` (dynamic-branching) — each with four variants: growable, Bounded, Inline, Small. All six heap-backed variants (excluding Inline) currently hand-roll arena-style storage using a `ManagedBuffer<Header, Node>` subclass with manually managed auxiliary buffers for tokens (`UInt32`) and free-list links (`Int`). This is ~500 lines of infrastructure per family that duplicates what `Buffer<Node>.Arena` now provides.

`Buffer.Arena` was implemented in buffer-primitives with 171 tests passing. It provides: `Storage<Element>.Heap`-backed element array, `UnsafeMutablePointer<Meta>` for per-slot token+nextFree, generation-based stale-reference detection (odd=occupied, even=free), LIFO free-list, automatic growth, and validated `Position` handles.

**Trigger**: [RES-001] — The design decision of how to migrate tree-primitives to Buffer.Arena cannot be made without systematic analysis of alternatives.

**Scope**: [RES-002a] — Cross-package (tree-primitives consuming buffer-primitives), so primitives-wide scope applies.

---

## Question

How should `Tree.N` and `Tree.Unbounded` be refactored to use `Buffer<Node>.Arena` as their underlying storage, and what design decisions must be resolved at each integration point?

### Sub-questions

- Q1: Can Tree.N collapse to a single `_buffer: Buffer<Node>.Arena` field?
- Q2: Does deinit order matter when switching from tree-order to linear deinit?
- Q3: What is the right index type conversion strategy (Int vs Index<Node>)?
- Q4: Should -1 sentinels migrate to Optional<Index<Node>>?
- Q5: How should Inline and Small variants be handled?
- Q6: How should CoW work post-migration?
- Q7: Does Tree.Unbounded require special handling?

---

## Prior Art Survey [RES-021]

### Arena Allocation in Tree Data Structures

The use of arena/pool allocators for tree storage is well-established:

- **ECS (Entity Component System)** architectures in game engines (Unity DOTS, Bevy) use generational arenas (slot maps) as the canonical storage for entities. Entities are indices into arenas; components stored separately. The tree parent/child relationship is stored as index links — identical to Tree.N's `parentIndex`/`childIndices` pattern.

- **Rust's `indextree`** crate stores tree nodes in a `Vec<Node<T>>` with index-based links (parent, first_child, last_child, prev_sibling, next_sibling). No generation tracking — dangling indices are the caller's problem.

- **Rust's `thunderdome`** and **`slotmap`** crates provide generational arenas with `(index, generation)` handles, directly analogous to `Buffer.Arena.Position`. These are commonly used as backing storage for trees and graphs.

- **Bonwick slab allocator** (1994): The canonical reference for fixed-slot typed allocation with free-list reuse. Buffer.Arena's design directly descends from this lineage.

### Composition vs Independent Implementation

The `storage-pool-architecture.md` research (DECISION) previously chose independent implementation for `Storage.Pool` over composing `Memory.Pool`, due to fundamental mismatches in ownership model, pointer types, and API surface. However, `Buffer.Arena` was specifically designed as a higher-level discipline intended for composition — its API (insert/remove/isValid/Position) matches the operations Tree.N needs.

The `memory-pool-arena-buffer-usage-analysis.md` research (RECOMMENDATION) found that Memory.Pool and Memory.Arena have zero consumers outside their own tests, while Buffer-layer types are the intended consumer interface.

### Theoretical Grounding [RES-022]

The migration is a **composition** refactoring: Tree.N's arena storage IS-A `Buffer<Node>.Arena` (same invariants, same operations). This is not an approximation — the token parity oracle, LIFO free-list, and generation-based validation are identical in both implementations. The refactoring replaces duplicated mechanism with delegation.

---

## Analysis

### Inventory: Current vs Target

| Aspect | Tree.N (Current) | Buffer.Arena |
|--------|-------------------|--------------|
| Element storage | `ManagedBuffer<Header, Node>` | `Storage<Element>.Heap` |
| Tokens | `UnsafeMutablePointer<UInt32>?` (separate alloc) | Packed in `Meta.token` |
| Free-list | `UnsafeMutablePointer<Int>?` (separate alloc) | Packed in `Meta.nextFree` (UInt32) |
| Free-list sentinel | `-1` (Int) | `UInt32.max` |
| Index type | `Int` throughout | `Index<Element>` (typed) |
| Position handle | `Tree.Position(index: Int, token: UInt32)` | `Buffer<Element>.Arena.Position(index: UInt32, token: UInt32)` |
| Growth | Manual `ensureCapacity` → create new Storage, move elements | `ensureCapacity()` built-in with doubling policy |
| Deinit | Post-order tree traversal | Linear `meta[0..<highWater]` scan |
| CoW | `isKnownUniquelyReferenced` + `_copyAllElements` | Not supported (Arena is ~Copyable) |
| Stored properties | 4: `_storage`, `_cachedPtr`, `_tokens`, `_nextFree` | 3: `header`, `storage`, `_meta` |

---

### Q1: Stored Property Mapping

**Current Tree.N layout** (4 stored properties):

```swift
var _storage: Storage              // ManagedBuffer<Header, Node> (reference type)
var _cachedPtr: UnsafeMutablePointer<Node>  // Cached from _storage._nodesPointer
var _tokens: UnsafeMutablePointer<UInt32>?  // Cached from _storage._tokens
var _nextFree: UnsafeMutablePointer<Int>?   // Cached from _storage._nextFree
```

**Buffer.Arena layout** (3 stored properties):

```swift
var header: Header                          // Value type: occupied, highWater, capacity, freeHeadRaw
var storage: Storage<Element>.Heap          // ManagedBuffer (reference type)
var _meta: UnsafeMutablePointer<Meta>       // Token + nextFree per slot (8 bytes each)
```

#### Option A: Single `_arena: Buffer<Node>.Arena` field

Tree.N collapses to:

```swift
struct N<Element: ~Copyable, let n: Int>: ~Copyable {
    var _arena: Buffer<Node>.Arena
    var _rootIndex: Int   // -1 if empty (or UInt32.max to match arena convention)
}
```

**Advantages**:
- Maximum code elimination — all arena operations delegate to `_arena`
- Single point of maintenance for arena invariants
- Header fields (`count`, `capacity`, `freeHead`) live inside `_arena.header`

**Disadvantages**:
- Tree.N needs `rootIndex` stored outside the arena (Arena's Header has no field for this)
- Pointer access to node storage requires going through `_arena.storage` — one extra indirection vs current `_cachedPtr`
- Tree navigation code (`_cachedPtr[index].childIndices[slot]`) must change to access through arena's storage API

**Performance concern**: Tree.N caches `_cachedPtr` to avoid repeated `withUnsafeMutablePointerToElements` calls. Buffer.Arena's `storage` is a `Storage<Element>.Heap` (ManagedBuffer wrapper). Accessing element storage requires `storage.withUnsafeMutablePointerToElements`. For hot navigation paths (traversals), this indirection matters.

**Resolution**: Buffer.Arena already holds `storage: Storage<Element>.Heap` which internally caches the elements pointer. The tree can access elements via `_arena.storage._nodesPointer` or equivalent accessor. The performance delta is a single struct field dereference (`_arena.storage` instead of `_cachedPtr`) — likely negligible after inlining. Profile before adding a cache.

#### Option B: Arena + cached pointer

```swift
struct N<Element: ~Copyable, let n: Int>: ~Copyable {
    var _arena: Buffer<Node>.Arena
    var _rootIndex: Int
    var _cachedElements: UnsafeMutablePointer<Node>  // Perf cache, mirrors _arena.storage
}
```

This adds back the pointer-caching pattern but still delegates all arena logic to Buffer.Arena. Risk: the cached pointer can go stale on growth. Must update on every `_arena.grow(to:)`.

#### Recommendation: Option A (single field + rootIndex)

Start with Option A. Profile. Add cached pointer only if hot-path benchmarks show measurable regression. Buffer.Arena's storage is `@inlinable` and the compiler should inline through the indirection.

**Decision criteria**: If Tree.N.insert takes >5% regression on a 1M-node benchmark, add the cached pointer.

---

### Q2: Deinit Ordering

**Current behavior** (Tree.N.Storage.deinit, line 210–264):

Post-order tree traversal using explicit stack. Visits children before parents. ~40 lines of traversal logic.

**Buffer.Arena behavior** (Buffer.Arena.deinit, line 837–851):

Linear iteration: `for i in 0..<highWater { if meta[i].token & 1 == 1 { storage.deinitialize(at: i) } }`

#### Analysis: Does deinit order matter for Tree.N.Node?

Node layout:

```swift
struct Node: ~Copyable {
    var element: Element          // Owned
    var childIndices: InlineArray<n, Int>  // Value type (Ints)
    var childCount: Int           // Value type
    var parentIndex: Int          // Value type
}
```

The only owned resource is `element: Element`. The `childIndices` are plain `Int` values — they are indices into the arena, not owned references. Deinitializing a parent before its children does not cause use-after-free because the parent does not own the child nodes; the *arena* owns all nodes.

**For `Element: Copyable`**: Trivially correct. Deinitializing Ints, Strings, Arrays — order doesn't matter.

**For `Element: ~Copyable`**: Still correct. Each node's `element` is independently owned. Deinitializing node A's element does not affect node B's element, regardless of parent/child relationship. The only concern would be if element destructors accessed sibling/parent elements through the tree — but elements have no reference to the tree.

**Edge case: `Element` has a deinit that accesses the tree**: Impossible. Elements are stored inside the arena. The element's deinit cannot access the arena (it has no reference to it). This is a consequence of value-semantic containment.

#### Recommendation: Linear deinit is correct

Tree-order deinit was a premature safety measure. Buffer.Arena's linear deinit over `meta[0..<highWater]` is correct for Tree.N.Node because:

1. Child indices are value types (Int), not owned references
2. Each element is independently owned
3. Element deinits cannot access sibling/parent elements

**Code savings**: ~40 lines of post-order traversal logic per tree family deleted.

---

### Q3: Index Type Reconciliation

**Current**: Tree.N uses `Int` everywhere — `rootIndex`, `parentIndex`, `childIndices: InlineArray<n, Int>`, `freeHead`, slot indices.

**Buffer.Arena**: Uses `Index<Element>` (`Tagged<Element, Ordinal>`) for slot access and `UInt32` for meta/position internals.

#### Option A: Full adoption of Index<Node> throughout

Change all tree internals:

```swift
var rootIndex: Index<Node>?            // was: Int (-1 sentinel)
var parentIndex: Index<Node>?          // was: Int (-1 sentinel)
var childIndices: InlineArray<n, Index<Node>?>  // was: InlineArray<n, Int>
```

**Cost**: Massive surface change. InlineArray<n, Int> → InlineArray<n, Index<Node>?> changes Node layout, all navigation code, and all traversal logic. `Index<Node>?` is 9 bytes (UInt + 1-byte tag) vs 8 bytes for Int — but InlineArray requires Copyable elements, and Index<Node> is Copyable, so this works. However, Optional<Index<Node>> may not be layout-compatible with InlineArray's requirements cleanly.

**Benefit**: Full typed arithmetic integration. No Int↔Index boundary.

#### Option B: Int externally, convert at Arena boundary

Tree.N keeps `Int` for all tree navigation. Converts to `Index<Node>` only when calling Arena methods:

```swift
// In insert:
let position = _arena.insert(node)  // Returns Buffer<Node>.Arena.Position
// Convert position.slotIndex (Index<Node>) back to Int for tree storage
let index = Int(position.index)     // UInt32 → Int
```

**Cost**: Conversion at every Arena call boundary. Multiple `Int(...)` and `Index<Node>(Ordinal(UInt(...)))` boilerplate.

**Benefit**: Minimal changes to tree-specific navigation code. `InlineArray<n, Int>` unchanged. No Node layout change.

#### Option C: Hybrid — tree navigation uses Int, Arena calls use Index<Node>

Same as Option B but made explicit as the intended long-term pattern:

- Tree.N public API continues to use `Tree.Position` (which has `index: Int` + `token: UInt32`)
- Internal navigation uses `Int` (childIndices, parentIndex)
- Arena calls convert at boundary

**Conversion costs at boundary**:

```swift
// Int → Index<Node>: one Ordinal + Index init
let slot = Index<Node>(Ordinal(UInt(intIndex)))
// Index<Node> → Int: one rawValue extraction
let intIndex = Int(slot.rawValue.rawValue)
```

These are zero-cost after inlining (phantom type change + `UInt` ↔ `Int` bit pattern).

#### Recommendation: Option C (Hybrid)

Rationale:

1. **InlineArray<n, Int>** is deeply embedded in Node layout and all navigation code. Changing it to `InlineArray<n, Index<Node>?>` is a high-risk, high-cost change with no functional benefit — the typed safety of `Index<Node>` is internal to Tree.N, not exposed to users. Users interact via `Tree.Position`.

2. **Conversion is zero-cost** after inlining. The `Index<Node>` phantom type is compile-time only.

3. **Sentinel pattern preservation**: Keeping Int allows `-1` sentinel (see Q4) without layout changes.

4. **Incremental migration**: Option C can later evolve to Option A if we decide the typed safety benefits justify the surface area change.

---

### Q4: Sentinel Values

**Current**: `-1` used for:
- `header.rootIndex` — no root
- `node.parentIndex` — node is root
- `node.childIndices[slot]` — empty child slot
- `header.freeHead` — empty free-list

**Buffer.Arena**: `UInt32.max` for empty free-list head.

#### Option A: Migrate to Optional<Index<Node>>

```swift
var rootIndex: Index<Node>?
var parentIndex: Index<Node>?
var childIndices: InlineArray<n, Index<Node>?>
```

**Node size impact**: `Optional<Index<Node>>` is 9 bytes (UInt64 for Ordinal + 1-byte discriminator, no niche optimization for tagged types). For a binary tree (n=2): `childIndices` goes from 16 bytes (`InlineArray<2, Int>`) to 18 bytes (`InlineArray<2, Optional<Index<Node>>>`). With alignment padding, this likely rounds to 24 bytes. That's a 50% increase in child storage per node.

For n=4 (quad tree): 32 bytes → 36+padding ≈ 40 bytes. Still significant.

**InlineArray constraint**: `InlineArray` requires `Copyable` elements. `Optional<Index<Node>>` is Copyable, so this works. But `InlineArray(repeating: nil)` requires the `nil` literal, which should work.

#### Option B: Keep -1 sentinels with Int

No layout changes. The `-1` sentinel is well-understood in this codebase and has extensive test coverage.

**Concern**: `-1` as `Int` is not representable in `UInt32` (Buffer.Arena's internal type). But since we chose Option C for Q3 (Int externally, convert at boundary), the sentinel values never cross into Arena land. The Arena manages its own free-list head with `UInt32.max`; Tree.N manages its own root/parent/child sentinels with `-1`.

#### Option C: Use UInt32.max as sentinel (align with Arena)

Replace `-1` with `UInt32.max` in tree navigation. This aligns sentinel semantics with Arena but changes the sentinel convention throughout all tree code.

**Problem**: `InlineArray<n, Int>` would use `Int(UInt32.max)` = `4294967295` as sentinel. This is less readable than `-1` and still requires explicit sentinel checks (`childIndex != Int(UInt32.max)`). No improvement.

#### Recommendation: Option B (keep -1 sentinels)

Rationale:

1. Node layout unchanged — no risk of regressions from size changes
2. Sentinel values are internal to Tree.N, never cross into Arena land (Q3 Option C establishes the boundary)
3. `-1` is idiomatic for "absent index" in systems code
4. If/when we do Option A of Q3 in the future, we can revisit sentinels at that time

---

### Q5: Variant Mapping

| Current | Target | Status |
|---------|--------|--------|
| `Tree.N` (growable) | `Buffer<Node>.Arena` | Direct mapping — Arena supports growth |
| `Tree.N.Bounded` | `Buffer<Node>.Arena.Bounded` | Direct mapping — Arena.Bounded is fixed-capacity |
| `Tree.N.Inline` | N/A | Buffer.Arena.Inline does not exist |
| `Tree.N.Small` | N/A | Buffer.Arena.Small does not exist |
| `Tree.Unbounded` (growable) | `Buffer<Node>.Arena` | Direct mapping (same as Tree.N) |
| `Tree.Unbounded.Bounded` | `Buffer<Node>.Arena.Bounded` | Direct mapping |

#### Analysis: Inline and Small

**Tree.N.Inline** (`Tree.N.Inline.swift`):
- Uses `InlineArray<capacity, InlineNode>` for nodes
- Uses `InlineArray<capacity, UInt32>` for tokens
- Uses `InlineArray<capacity, Int>` for free-list links
- Zero heap allocation
- Unconditionally `~Copyable` (has deinit)

**Tree.N.Small** (`Tree.N.Small.swift`):
- Inline storage for ≤ `inlineCapacity` nodes
- Spills to heap (`Tree.N.Storage`) when exceeded
- Once spilled, never returns to inline

**Buffer.Arena.Inline** does not exist in buffer-primitives. Neither does `Buffer.Arena.Small`.

#### Option A: Defer Inline/Small — keep hand-rolled

Migrate only the heap-backed variants (N, N.Bounded, Unbounded, Unbounded.Bounded). Leave Inline and Small unchanged.

**Risk**: Inline/Small continue to duplicate arena logic. But they don't duplicate *Buffer.Arena* logic — they use InlineArray, not ManagedBuffer. The duplication is between Inline/Small and the heap variants, not between Inline/Small and Buffer.Arena.

#### Option B: Implement Buffer.Arena.Inline and Buffer.Arena.Small first

Build the inline/small arena variants in buffer-primitives, then migrate all tree variants.

**Risk**: Scope explosion. Buffer.Arena.Inline/Small are standalone features worth their own research. Coupling them to this migration creates a dependency chain that blocks the core migration.

#### Option C: Delete Inline and Small as premature optimization

**Risk**: Breaking change if anyone uses them. Need usage analysis.

#### Recommendation: Option A (defer Inline/Small)

Rationale:

1. **Decoupling**: The core migration (4 heap-backed variants) is independently valuable and testable
2. **Inline/Small are structurally different**: They use InlineArray, not ManagedBuffer. Buffer.Arena.Inline would need its own design research
3. **No blocking dependency**: Inline/Small can be migrated later when Buffer.Arena.Inline exists
4. **Scope control**: This migration is already substantial (6 heap-backed variants across 2 families)

---

### Q6: Copy-on-Write Semantics

**Current Tree.N CoW** (`where Element: Copyable`):

```swift
mutating func makeUnique() {
    if !isKnownUniquelyReferenced(&_storage) {
        let newStorage = Storage.create(minimumCapacity: capacity)
        _storage._copyAllElements(to: newStorage)
        _replaceStorage(newStorage)
    }
}
```

CoW is possible because `Storage` is a `class` (reference type), and `isKnownUniquelyReferenced` can check the refcount.

**Buffer.Arena**: Unconditionally `~Copyable`. Cannot conform to Copyable even when Element is Copyable (because Arena has a deinit managing `_meta`). The comment in Buffer.swift line 1114–1115 confirms:

```swift
// Cannot conform to Copyable: Arena has deinit (manages _meta allocation lifecycle).
// extension Buffer.Arena: Copyable where Element: Copyable {}
```

#### Consequence: Tree.N loses CoW

If Tree.N wraps `Buffer<Node>.Arena` directly, Tree.N becomes unconditionally ~Copyable. This is a **breaking change** for `Tree.N where Element: Copyable`, which currently supports `Copyable` conformance and value-semantic CoW.

#### Option A: Tree.N wraps Arena in a reference type

```swift
struct N<Element: ~Copyable, let n: Int>: ~Copyable {
    final class _Box {
        var arena: Buffer<Node>.Arena
        var rootIndex: Int
    }
    var _box: _Box
}

// Then CoW:
extension Tree.N where Element: Copyable {
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_box) {
            _box = _Box(arena: _box.arena.copy(), rootIndex: _box.rootIndex)
        }
    }
}
```

**Problem**: Buffer.Arena has no `copy()` method. Would need to add one. Also, wrapping an arena in a box adds indirection.

#### Option B: Tree.N implements CoW by creating a new Arena and copying nodes

```swift
mutating func makeUnique() {
    if !isKnownUniquelyReferenced(&_box) {
        var newArena = Buffer<Node>.Arena(minimumCapacity: _arena.header.capacity)
        // Copy all occupied nodes from old to new
        _arena.forEachOccupied { slot in
            let node = _arena.storage[slot]  // borrow
            newArena.insert(node.copy())     // Requires Element: Copyable
        }
        // ... but indices must be preserved!
    }
}
```

**Critical problem**: Buffer.Arena.insert assigns indices based on free-list/highWater order. If we insert nodes into a fresh arena, they may get different indices than the originals. All parent/child index links would be broken.

To preserve indices, we'd need a low-level copy that initializes slots at specific positions — which Buffer.Arena doesn't expose.

#### Option C: Add Buffer.Arena.copy() method

Buffer.Arena gains:

```swift
extension Buffer<Element>.Arena where Element: Copyable {
    public func copy() -> Self {
        var new = Self(minimumCapacity: header.capacity)
        // Copy meta array 1:1
        new._meta.update(from: _meta, count: Int(bitPattern: header.highWater))
        // Copy occupied elements at same indices
        let hw = Int(bitPattern: header.highWater)
        for i in 0..<hw {
            if _meta[i].token & 1 == 1 {
                let slot = Index<Element>(Ordinal(UInt(i)))
                new.storage.initialize(to: storage[slot], at: slot)
            }
        }
        new.header = header
        return new
    }
}
```

This preserves all indices (slots are copied at the same positions), so parent/child links remain valid.

#### Option D: Keep Storage class, delegate arena ops to Buffer.Arena's static methods

Instead of wrapping `Buffer<Node>.Arena`, Tree.N's Storage class uses Buffer.Arena's static methods for slot management:

```swift
final class Storage: ManagedBuffer<Header, Node> {
    var _meta: UnsafeMutablePointer<Buffer<Node>.Arena.Meta>

    func _allocateSlot() -> Buffer<Node>.Arena.Position {
        Buffer<Node>.Arena.allocateSlot(header: &header, meta: _meta)
    }
}
```

This preserves the reference-type Storage (enabling CoW) while reusing Buffer.Arena's implementation.

**Advantage**: CoW works exactly as before. No API break.

**Disadvantage**: Tree.N still owns some arena infrastructure (the ManagedBuffer subclass). Less code reduction than full delegation.

#### Recommendation: Option C + Option A hybrid

1. Add `Buffer<Element>.Arena.copy() -> Self where Element: Copyable` to buffer-primitives
2. Tree.N wraps Arena in a reference-type box for CoW
3. `makeUnique()` uses `_arena.copy()` to duplicate the arena preserving indices

This maximizes code reuse while preserving CoW. The box adds one indirection but Tree.N already had a reference-type `Storage` — so the indirection count is unchanged.

**Alternative worth considering**: Option D is simpler and more conservative. It reuses Buffer.Arena's static methods (allocateSlot, freeSlot, isValid, etc.) without wrapping the full Arena struct. The tradeoff is less code elimination but zero API surface change.

**Decision point**: This question needs your input. The choice between "full Arena wrapping with box for CoW" vs "keep Storage class, delegate to Arena statics" determines the migration's scope and risk profile.

---

### Q7: Tree.Unbounded Differences

**Tree.Unbounded.Node**:

```swift
struct Node: ~Copyable {
    var element: Element
    var childIndices: Swift.Array<Int>  // Dynamic, heap-allocated
    var parentIndex: Int
}
```

vs **Tree.N.Node**:

```swift
struct Node: ~Copyable {
    var element: Element
    var childIndices: InlineArray<n, Int>  // Fixed-size, inline
    var childCount: Int
    var parentIndex: Int
}
```

#### Key Difference: Node owns heap allocations

`Tree.Unbounded.Node.childIndices` is a `Swift.Array<Int>`. This means each Node **owns a separate heap allocation** for its children array. When the arena deinitializes a Node, Swift.Array's deinit will free that allocation.

**Impact on linear deinit (Q2)**: Still correct. Buffer.Arena's linear deinit calls `storage.deinitialize(at: slot)` which calls `(ptr + slot).deinitialize(count: 1)`. This invokes Node.deinit, which invokes Array.deinit, which frees the children array. No ordering dependency — each node's Array is independently owned.

**Impact on Arena growth**: When Buffer.Arena grows, it moves occupied elements to new storage. Moving a `Tree.Unbounded.Node` involves moving its `Swift.Array<Int>` — but Swift.Array is Copyable/movable, so this works. The array's heap buffer is not copied; only the Array struct (pointer + length + capacity) is moved.

**Impact on CoW copy**: When copying nodes for CoW, each `Swift.Array<Int>` in each node is copied via Array's CoW. This is O(n) copies where n is the number of nodes, but each individual Array copy is O(1) until mutated (Array has its own CoW). Total copy cost: O(n) to scan + O(1) per Array = O(n).

#### Additional consideration: No `childCount` field

`Tree.Unbounded.Node` has no `childCount` — it uses `childIndices.count` directly. This simplifies the migration slightly (one fewer field to manage).

#### Recommendation: No special handling needed

Tree.Unbounded migrates identically to Tree.N. The dynamic children array is an opaque part of the Node type; Buffer.Arena doesn't know or care about Node internals. All arena operations (allocate, free, move, deinitialize) work on whole Nodes.

---

## Evaluation: Cognitive Dimensions [RES-025]

| Dimension | Current (hand-rolled) | Post-migration (Buffer.Arena) |
|-----------|-----------------------|-------------------------------|
| **Visibility** | Arena internals (tokens, freeHead, meta) scattered across Tree.N | Arena internals encapsulated in Buffer.Arena; Tree.N only sees Position |
| **Consistency** | Each tree family reimplements arena storage independently | Single Arena implementation shared across all data structures |
| **Viscosity** | Changing arena invariants requires parallel edits in Tree.N and Tree.Unbounded | Change Buffer.Arena once, all consumers inherit |
| **Role-expressiveness** | `_tokens`, `_nextFree` fields don't express their role as "arena metadata" | `Buffer<Node>.Arena` name expresses purpose |
| **Error-proneness** | Token increment, free-list linking reimplemented in each tree — must stay in sync | Proven implementation with 171 tests |
| **Abstraction** | Too low — tree code mixes tree logic with arena bookkeeping | Proper separation of concerns |

---

## Outcome

**Status**: DEFERRED

All sub-questions analyzed except Q6 (CoW strategy), which requires an architectural decision between full Arena wrapping with Box for CoW vs. keeping the Storage class with delegation to Arena statics. Analysis is complete and ready to resume when tree-primitives migration is prioritized.

**Deferred since**: 2026-03-10

### Decisions Made

| Question | Recommendation | Rationale |
|----------|---------------|-----------|
| Q1: Stored properties | Single `_arena: Buffer<Node>.Arena` + `rootIndex` | Maximum code elimination; profile before adding cache |
| Q2: Deinit order | Linear deinit is correct | Child indices are value types; no ownership chain between nodes |
| Q3: Index types | Hybrid: Int internally, Index<Node> at Arena boundary | Zero-cost conversion; preserves InlineArray<n, Int> layout |
| Q4: Sentinels | Keep -1 sentinels | Internal to tree; never cross Arena boundary |
| Q5: Inline/Small | Defer — keep hand-rolled | Structurally different; needs own research |
| Q7: Tree.Unbounded | No special handling | Array<Int> children are opaque to Arena |

### Decision Required

| Question | Options | Your input needed |
|----------|---------|-------------------|
| Q6: CoW strategy | (A) Box Arena + add Arena.copy() / (B) Keep Storage class, delegate to Arena statics / (C) Drop CoW (breaking change) | Which approach? |

### Implementation Sequence (pending Q6 resolution)

1. Add `Buffer<Element>.Arena.copy() -> Self where Element: Copyable` to buffer-primitives (if Q6 = Option A/C)
2. Add `rootIndex` support — either as a field on Tree.N or as a custom Arena.Header extension
3. Migrate `Tree.N` (growable) first — most code, highest impact
4. Migrate `Tree.N.Bounded` — direct mapping to Arena.Bounded
5. Migrate `Tree.Unbounded` — same pattern as Tree.N
6. Migrate `Tree.Unbounded.Bounded` — same pattern as Tree.N.Bounded
7. Leave `Tree.N.Inline`, `Tree.N.Small`, `Tree.Unbounded.Small` unchanged
8. Delete hand-rolled Storage classes
9. Run full test suite, benchmark hot paths

---

## References

- Hanson, D. R. (1990). Fast Allocation and Deallocation of Memory Based on Object Lifetimes. *Software: Practice and Experience*, 20(1):5-12.
- Bonwick, J. (1994). The Slab Allocator: An Object-Caching Kernel Memory Allocator. *USENIX Summer 1994*.
- `primitives-taxonomy-naming-layering-audit.md` — DECISION — canonical naming for arena vs pool.
- `memory-pool-arena-buffer-usage-analysis.md` — RECOMMENDATION — Memory.Pool/Arena usage findings.
- `storage-pool-architecture.md` — DECISION — independent implementation vs composition precedent.
