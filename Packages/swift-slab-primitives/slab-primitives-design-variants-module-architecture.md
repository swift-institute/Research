# Slab Primitives: Design, Variants, and Module Architecture

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
research_tier: 2
applies_to: [swift-slab-primitives]
normative: false
---
-->

## Context

`swift-slab-primitives` currently provides a monolithic `Slab<Element>` type — a thin wrapper around `Buffer<Storage<Element>.Heap>.Slab.Bounded` in a single module. This is the only data structure package in swift-primitives that has **not** undergone the module split for `~Copyable` support, and it lacks the variant types (Static, Indexed) that all other data structure packages provide.

The buffer layer already provides three slab variants:

| Buffer Type | Storage | Capacity | Growable |
|-------------|---------|----------|:---:|
| `Buffer<Storage<Element>.Heap>.Slab` | Heap (`Storage.Heap`) | Runtime | Yes |
| `Buffer<Storage<Element>.Heap>.Slab.Bounded` | Heap (`Storage.Heap`) | Runtime (fixed at init) | No |
| `Buffer<Storage<Element>.Heap>.Slab.Inline<let wordCount: Int>` | Stack (`Storage.Inline`) | Compile-time | No |

Plus a phantom-typed wrapper:

| Buffer Type | Purpose |
|-------------|---------|
| `Buffer<Storage<Element>.Heap>.Slab.Bounded.Indexed<Tag>` | Zero-cost `Index<Tag>` instead of `Bit.Index` |

The data structure layer currently exposes only one of these (Bounded), with no module split and no variant types. Every other comparable data structure package (Array, Stack, Queue, Heap) has both a module split and 3-5 variant types.

**Trigger**: [RES-012] Discovery — proactive audit before the package reaches maturity, plus [RES-014] consistency analysis against sibling data structure packages.

---

## Question

How should `swift-slab-primitives` be designed? What variants should it include, what module split does it need, and what API surface should it expose?

### Sub-questions

- SQ1: What variants should `Slab` have, given the buffer-layer infrastructure?
- SQ2: What module split is needed for `~Copyable` support?
- SQ3: What API surface should each variant expose?
- SQ4: Should the current `initialize`/`deinitialize` naming be replaced?
- SQ5: Should `Slab` provide an auto-insert API (allocator-chosen index)?
- SQ6: What should the index type be — `Int` or `Index<Element>`?

---

## Prior Art Survey [RES-021]

### Rust Ecosystem

#### `slab` crate (tokio-rs/slab)

The dominant Rust slab implementation. 89M+ downloads. API:

```rust
let mut slab = Slab::new();              // growable
let key: usize = slab.insert(value);     // auto-insert, returns index
let value = slab.remove(key);            // remove by index
let value = &slab[key];                  // subscript read
let value = &mut slab[key];              // subscript write
slab.contains(key) -> bool;             // occupancy check
slab.len() -> usize;                    // occupied count
slab.capacity() -> usize;               // total slots
slab.is_empty() -> bool;
slab.iter() -> impl Iterator<Item = (usize, &T)>;  // iterate (index, value) pairs
slab.vacant_entry() -> VacantEntry;      // reserve-then-insert pattern
```

**Key design decisions**:
- Growable by default (no fixed-capacity variant).
- Auto-insert is the primary API (`insert(val) -> key`). Manual index insertion does not exist.
- Uses a free list (not bitmap) for O(1) allocation.
- Index-based subscript access (panics on vacant slot).
- Iteration yields `(usize, &T)` pairs — index + reference.

#### `sharded-slab` crate (tokio-rs)

Thread-safe slab with lock-free allocation. Same API as `slab` but:
- Fixed page size (compile-time).
- Generational indices for stale-reference detection.
- Concurrent insert/remove without global lock.

#### `slotmap` crate

Generational slab with versioned keys:

```rust
let mut sm = SlotMap::new();
let key: DefaultKey = sm.insert(value);  // key = (index, generation)
sm.remove(key);                          // checks generation before removing
sm[key];                                 // panics if generation mismatch
sm.contains_key(key) -> bool;
```

**Key innovation**: Generation counter in key prevents ABA problem. This is what our `Buffer.Arena` (proposed) addresses — a different concept from `Buffer.Slab`.

#### `thunderdome` crate

Minimal generational arena. Same concept as `slotmap` with smaller key size (8 bytes vs 16 bytes default).

### Comparison: Rust Slab vs Our Slab

| Aspect | Rust `slab` | Our `Slab<Element>` |
|--------|-------------|---------------------|
| Index assignment | Allocator-chosen (auto-insert) | Consumer-chosen |
| Occupancy tracking | Free list | Bitmap |
| First-vacant complexity | O(1) via free list head | O(word) via bitmap scan |
| Insert complexity | O(1) amortized (grow + free list) | O(1) at known index |
| Growth | Yes (default) | No (current: Bounded) |
| Generation tracking | No | No |
| Iteration | `(usize, &T)` pairs | Via bitmap.ones |
| Subscript | `slab[key]` (panics on vacant) | Not exposed |
| Index type | `usize` (untyped) | `Index<Element>` (typed) |

**Key divergence**: Rust's `slab` is allocator-chosen (insert returns the index). Our `Slab` is consumer-chosen (caller specifies the index). This is a fundamental design difference inherited from `Buffer.Slab`, which was designed to back `Hash.Table` (where the probing algorithm determines the slot).

**Compositional hierarchy**: Consumer-chosen `insert(_:at:)` is the **primitive** operation. Auto-insert `insert(_:) -> Int` is **composed** from `firstVacant()` + `insert(_:at:)`. The primitive is more general — auto-insert can be built on top, but consumer-chosen cannot be built on top of auto-insert. Following the primitives philosophy of composable building blocks, consumer-chosen is the foundation and auto-insert is the convenience layer.

### C++ and Other Languages

No standard slab type exists in C++ STL, Java, Python, or Swift stdlib. The concept exists primarily in:
- Kernel allocators (Bonwick slab, Linux SLAB/SLUB)
- Game engines (entity storage, object pools)
- Rust ecosystem (tokio-rs/slab, slotmap)

See [slab-first-principles.md](../../swift-buffer-primitives/Research/slab-first-principles.md) for the detailed Bonwick analysis.

---

## Inventory (Current State)

### Package Structure

```
swift-slab-primitives/
├── Package.swift
├── Sources/
│   └── Slab Primitives/           ← single monolithic module
│       ├── Slab.swift             ← struct Slab<Element: ~Copyable>: ~Copyable
│       ├── Slab.Error.swift       ← Slab.Error enum
│       └── exports.swift          ← re-exports
└── Tests/
    └── Sources/
        └── Slab Primitives Tests/
            └── Slab Tests.swift
```

### Current API Surface

| Category | Method | Notes |
|----------|--------|-------|
| Init | `init(capacity: Int) throws(Error)` | Runtime capacity, fixed |
| Query | `occupancy: Int` | Count of occupied slots |
| Query | `isEmpty: Bool` | All slots empty |
| Query | `isFull: Bool` | All slots occupied |
| Query | `isOccupied(at: Int) -> Bool` | Check specific slot |
| Query | `firstVacant() -> Int?` | Find first empty slot |
| Checked | `initialize(at: Int, to: consuming Element) throws(Error)` | Bounds-checked insert |
| Checked | `deinitialize(at: Int) throws(Error) -> Element` | Bounds-checked remove |
| Unchecked | `initialize(__unchecked: Int, to: consuming Element)` | Precondition-guarded insert |
| Unchecked | `deinitialize(__unchecked: Int) -> Element` | Precondition-guarded remove |
| Mutation | `removeAll()` | Clear all slots |

### Current Dependencies

```
swift-standard-library-extensions
swift-index-primitives
swift-bit-primitives
swift-ownership-primitives
swift-collection-primitives      ← imported but not used (Sequence commented out)
swift-buffer-primitives          ← Buffer Slab Primitives
```

### Backing Buffer: `Buffer<Storage<Element>.Heap>.Slab.Bounded`

The current `Slab<Element>` wraps `Buffer<Storage<Element>.Heap>.Slab.Bounded`, which is the **fixed-capacity, heap-backed** buffer variant. This means:

- Capacity determined at runtime (`init(minimumCapacity:)`).
- No growth after initialization.
- Heap storage via `Storage<Element>.Heap`.
- Bitmap occupancy via `Slab.Header` (wraps `Bit.Vector`).

The growable `Buffer<Storage<Element>.Heap>.Slab` and inline `Buffer<Storage<Element>.Heap>.Slab.Inline<wordCount>` are **not exposed** at the data structure layer.

---

## Analysis

### SQ1: What variants should Slab have?

#### Available Buffer Infrastructure

| Buffer | Data Structure Wrapper | Status |
|--------|----------------------|--------|
| `Buffer.Slab` (growable, heap) | — | **Not exposed** |
| `Buffer.Slab.Bounded` (fixed, heap) | `Slab<Element>` (current) | Exposed |
| `Buffer.Slab.Inline<wordCount>` (fixed, inline) | — | **Not exposed** |
| `Buffer.Slab.Bounded.Indexed<Tag>` (phantom-typed) | — | **Not exposed** |

#### Comparison with Sibling Data Structures

| Package | Variants | Buffer Disciplines Used |
|---------|----------|------------------------|
| swift-array-primitives | Array, Fixed, Static, Small, Bounded | Buffer.Linear |
| swift-stack-primitives | Stack, Bounded, Static, Small | Buffer.Linear |
| swift-queue-primitives | Queue, Fixed, Static, Small, Linked, DoubleEnded | Buffer.Ring, Buffer.Linked |
| swift-heap-primitives | Heap, Fixed, Static, Small, Min, Max, MinMax | Buffer.Linear |
| **swift-slab-primitives** | **Slab (bounded only)** | **Buffer.Slab (Bounded only)** |

#### Variant Analysis

**Option A: Minimal — Base + Static**

| Variant | Wraps | Purpose |
|---------|-------|---------|
| `Slab<Element>` | `Buffer.Slab` | Growable, heap-backed (primary type) |
| `Slab<Element>.Static<let wordCount: Int>` | `Buffer.Slab.Inline<wordCount>` | Inline, compile-time capacity |

- Pros: Simple. Covers the two fundamental storage strategies (heap vs inline).
- Cons: No fixed-capacity heap variant. No phantom-typed variant.

**Option B: Moderate — Base + Static + Indexed**

| Variant | Wraps | Purpose |
|---------|-------|---------|
| `Slab<Element>` | `Buffer.Slab` | Growable, heap-backed (primary type) |
| `Slab<Element>.Static<let wordCount: Int>` | `Buffer.Slab.Inline<wordCount>` | Inline, compile-time capacity |
| `Slab<Element>.Indexed<Tag>` | Wraps `Slab<Element>` | Phantom-typed `Index<Tag>` access |

- Pros: Covers type-safe index use cases (ECS entity storage). Indexed is zero-cost.
- Cons: No fixed-capacity heap variant.

**Option C: Full — Base + Static + Bounded + Indexed**

| Variant | Wraps | Purpose |
|---------|-------|---------|
| `Slab<Element>` | `Buffer.Slab` | Growable, heap-backed (primary type) |
| `Slab<Element>.Bounded` | `Buffer.Slab.Bounded` | Fixed-capacity, heap-backed (current behavior) |
| `Slab<Element>.Static<let wordCount: Int>` | `Buffer.Slab.Inline<wordCount>` | Inline, compile-time capacity |
| `Slab<Element>.Indexed<Tag>` | Wraps `Slab<Element>` | Phantom-typed `Index<Tag>` access |
| `Slab<Element>.Static<wc>.Indexed<Tag>` | Wraps `Slab.Static` | Phantom-typed inline variant |

- Pros: Full coverage of buffer infrastructure. Explicit bounded semantics.
- Cons: More variants to maintain. Bounded may be unnecessary if growable `Slab` with `reserveCapacity` suffices.

#### Should the Base Slab Be Growable?

The current `Slab<Element>` is fixed-capacity (wraps `Buffer.Slab.Bounded`). Changing to growable is a semantic shift.

**Arguments for growable base**:
1. **Consistency**: `Array<Element>` is growable. `Stack<Element>` is growable. The base type is always the most general.
2. **Rust precedent**: `slab::Slab` is growable.
3. **Use cases**: ECS entity storage naturally grows as entities are added.
4. **Subsumption**: A growable slab with `capacity` set at init behaves identically to a bounded slab if the user never exceeds capacity.

**Arguments for bounded base**:
1. **Current behavior**: Changing semantics breaks existing consumers.
2. **Predictability**: Fixed capacity prevents unexpected allocations.
3. **Embedded**: No-growth is required for embedded targets.

**Assessment**: The base type should be growable, matching Array/Stack/Queue precedent. The current bounded behavior moves to `Slab.Bounded`. This is a clean migration: rename the internal buffer from `Buffer.Slab.Bounded` to `Buffer.Slab` and add growth support.

#### Recommendation: Option B (Moderate)

| Variant | Wraps | Primary Use Case |
|---------|-------|------------------|
| `Slab<Element>` | `Buffer.Slab` | General-purpose growable slab |
| `Slab<Element>.Static<let wordCount: Int>` | `Buffer.Slab.Inline<wordCount>` | Embedded / stack-allocated / real-time |
| `Slab<Element>.Indexed<Tag>` | Wraps `Slab<Element>` | Type-safe ECS-style entity storage |

Rationale:
- Two storage strategies (heap + inline) covers all deployment targets.
- `Indexed<Tag>` enables the primary advanced use case (type-safe handles) at zero cost.
- No explicit `Bounded` variant — a growable slab initialized with `reserveCapacity` and never grown past it serves the same purpose. If demand emerges, `Bounded` can be added later without breaking changes.
- `Static.Indexed<Tag>` is omitted for now — can be added if needed. Inline slabs are typically small and performance-critical, making phantom typing less valuable.

---

### SQ2: What module split is needed?

#### Why Module Split Is Required

Swift's `~Copyable` constraint propagation means that `Sequence` conformance (which requires `Element: Copyable` because `Iterator` must be `Copyable`) cannot coexist in the same module as core type definitions without poisoning the `~Copyable` generic parameter. All sibling packages solve this with a multi-module split.

#### Canonical Pattern (from Array, Stack, Queue, Heap)

```
{Type} Primitives Core      → Type definitions, ~Copyable operations
{Type} Dynamic Primitives    → Copyable conformances (Sequence, subscript, CoW)
{Type} Static Primitives     → Copyable conformances for inline variant
{Type} Primitives            → Umbrella re-export
```

#### Proposed Module Split for Slab

**Module 1: Slab Primitives Core**

Purpose: All type definitions and operations that work with `~Copyable` elements.

Contents:
- `Slab.swift` — `struct Slab<Element: ~Copyable>: ~Copyable` (growable, heap)
  - Nested: `struct Static<let wordCount: Int>: ~Copyable` (inline)
  - Nested: `struct Indexed<Tag: ~Copyable>: ~Copyable` (phantom-typed wrapper)
  - Nested: `enum Error: Swift.Error, Sendable, Equatable` — per [PATTERN-022], nested types referencing `~Copyable` generic parameters MUST remain in the same file as the parent type
  - Conditional: `extension Slab: Copyable where Element: Copyable {}`
  - Conditional: `extension Slab: @unchecked Sendable where Element: Sendable {}`
- `exports.swift` — Re-exports: Index Primitives, Buffer Slab Primitives, Property Primitives

**[PATTERN-022] constraint**: All nested type declarations (`Static`, `Indexed`, `Error`) must be in `Slab.swift`. Extensions adding methods to these types CAN be in separate files with `where Element: ~Copyable`.

Operations (available for ALL elements, including `~Copyable`). All indices are `Index<Element>`, all counts are `Index<Element>.Count` per SQ6:
- `init()`, `init(minimumCapacity: Index<Element>.Count)`
- `insert(_:at: Index<Element>)`, `remove(at: Index<Element>) -> Element` (checked, throwing) — primitives
- `insert(__unchecked:at: Index<Element>)`, `remove(__unchecked: Index<Element>) -> Element` (unchecked)
- `insert(_:) -> Index<Element>` (composed: auto-insert at first vacant)
- `update(at: Index<Element>, with:) -> Element` (swap old for new — essential for ~Copyable, per [IMPL-INTENT])
- `occupancy: Index<Element>.Count`, `isEmpty`, `isFull`, `capacity: Index<Element>.Count`
- `isOccupied(at: Index<Element>)`, `firstVacant() -> Index<Element>?`
- `removeAll()` (delegates to buffer bulk operation per [IMPL-032])
- `drain` property — consuming iteration via `Property<Sequence.Drain, Self>.View` per [IMPL-021]

Dependencies:
```
Buffer Slab Primitives       (swift-buffer-primitives)
Index Primitives             (swift-index-primitives)
Property Primitives          (swift-property-primitives)
Ownership Primitives         (swift-ownership-primitives)
Standard Library Extensions  (swift-standard-library-extensions)
Bit Primitives               (swift-bit-primitives)
```

**Module 2: Slab Dynamic Primitives**

Purpose: Operations and conformances that require `Element: Copyable`.

Contents:
- `Slab Copyable.swift` — Copyable-only extensions for base Slab
- `Slab ~Copyable.swift` — ~Copyable extensions that need Collection/Sequence imports
- `exports.swift` — Re-exports: Slab Primitives Core, Collection Primitives, Sequence Primitives

Operations (Copyable only):
- `subscript(index: Index<Element>) -> Element { get set }` (read/write without ownership transfer)
- `peek(at: Index<Element>) -> Element` (read without removing)
- `Sequence` conformance — iterate `(Index<Element>, Element)` pairs over occupied slots
- Copy-on-write support (if applicable — see analysis below)

Dependencies:
```
Slab Primitives Core
Collection Primitives        (swift-collection-primitives)
Sequence Primitives          (swift-sequence-primitives)
```

**Module 3: Slab Static Primitives**

Purpose: Copyable-only operations for `Slab.Static<wordCount>`.

Contents:
- `Slab.Static Copyable.swift` — Copyable extensions for Static variant
- `exports.swift` — Re-exports: Slab Primitives Core

Operations (Copyable only):
- `peek(at: Index<Element>) -> Element`
- `subscript(index: Index<Element>) -> Element { get set }`
- `Sequence` conformance (if `Storage.Inline` constraints permit — see INV-INLINE-004a)

Dependencies:
```
Slab Primitives Core
Sequence Primitives          (swift-sequence-primitives)
```

**Note on INV-INLINE-004a**: `Buffer.Slab.Inline` uses `Storage.Inline` which depends on `@_rawLayout` — unconditionally `~Copyable`. This means `Slab.Static` **cannot** conform to `Copyable` or `Swift.Sequence` even when `Element: Copyable`, until Swift gains `InlineArray.init(unsafeUninitializedCapacity:)`. The Static Primitives module may initially be thin, containing only `peek` and `subscript` without protocol conformances.

**Module 4: Slab Primitives (Umbrella)**

Purpose: Single public import for consumers.

Contents:
- `exports.swift` — Re-exports all modules

```swift
@_exported public import Slab_Primitives_Core
@_exported public import Slab_Dynamic_Primitives
@_exported public import Slab_Static_Primitives
```

Dependencies:
```
Slab Primitives Core
Slab Dynamic Primitives
Slab Static Primitives
```

#### Module Dependency Graph

```
Slab Primitives (umbrella)
├── Slab Primitives Core           ← types + ~Copyable ops
│   ├── Buffer Slab Primitives
│   ├── Index Primitives
│   ├── Property Primitives
│   ├── Ownership Primitives
│   ├── Bit Primitives
│   └── Standard Library Extensions
├── Slab Dynamic Primitives        ← Copyable ops for Slab
│   ├── Slab Primitives Core
│   ├── Collection Primitives
│   └── Sequence Primitives
└── Slab Static Primitives         ← Copyable ops for Slab.Static
    ├── Slab Primitives Core
    └── Sequence Primitives
```

---

### SQ3: What API surface should each variant expose?

#### Base Slab (Growable, Heap-Backed)

All index parameters use `Index<Element>` and all quantities use `Index<Element>.Count` per SQ6.

| Category | API | Constraint | Notes |
|----------|-----|-----------|-------|
| **Init** | `init()` | ~Copyable | Empty slab, no allocation |
| **Init** | `init(minimumCapacity: Index<Element>.Count)` | ~Copyable | Pre-allocate slots |
| **Capacity** | `capacity: Index<Element>.Count` | ~Copyable | Current total slots [IMPL-006] |
| **Capacity** | `reserveCapacity(_ minimumCapacity: Index<Element>.Count)` | ~Copyable | Grow if needed |
| **Occupancy** | `occupancy: Index<Element>.Count` | ~Copyable | Occupied slot count [IMPL-006] |
| **Occupancy** | `isEmpty: Bool` | ~Copyable | All vacant |
| **Occupancy** | `isFull: Bool` | ~Copyable | All occupied |
| **Occupancy** | `isOccupied(at: Index<Element>) -> Bool` | ~Copyable | Check specific slot |
| **Occupancy** | `firstVacant() -> Index<Element>?` | ~Copyable | First empty slot |
| **Insert** | `insert(_ element: consuming Element, at index: Index<Element>) throws(Error)` | ~Copyable | Checked, consumer-chosen primitive |
| **Insert** | `insert(_ element: consuming Element, __unchecked index: Index<Element>)` | ~Copyable | Unchecked variant |
| **Insert** | `insert(_ element: consuming Element) throws(Error) -> Index<Element>` | ~Copyable | Composed: `firstVacant()` + `insert(_:at:)` |
| **Remove** | `remove(at index: Index<Element>) throws(Error) -> Element` | ~Copyable | Checked removal primitive |
| **Remove** | `remove(__unchecked index: Index<Element>) -> Element` | ~Copyable | Unchecked variant |
| **Remove** | `removeAll()` | ~Copyable | Delegates to buffer bulk op [IMPL-032] |
| **Update** | `update(at index: Index<Element>, with element: consuming Element) throws(Error) -> Element` | ~Copyable | Atomic swap primitive (essential for ~Copyable) |
| **Read** | `subscript(index: Index<Element>) -> Element { get set }` | **Copyable** | Non-destructive access |
| **Read** | `peek(at index: Index<Element>) -> Element` | **Copyable** | Read without removing |
| **Borrow** | `withUnsafePointer(at: Index<Element>, _ body: (UnsafePointer<Element>) -> R) -> R` | ~Copyable | Pointer-based read |
| **Borrow** | `withUnsafeMutablePointer(at: Index<Element>, _ body: (UnsafeMutablePointer<Element>) -> R) -> R` | ~Copyable | Pointer-based mutate |
| **Iterate** | `Sequence` conformance (yields `(Index<Element>, Element)` pairs) | **Copyable** | Over occupied slots |
| **Iterate** | `drain` property — `Property<Sequence.Drain, Self>.View` | ~Copyable | Consuming iteration [IMPL-021] |
| **Conform** | `Copyable where Element: Copyable` | — | Conditional |
| **Conform** | `@unchecked Sendable where Element: Sendable` | — | Conditional |

#### Slab.Static (Inline, Compile-Time Capacity)

Same API as base Slab except:

| Difference | Base Slab | Static |
|-----------|-----------|--------|
| Init | `init()`, `init(minimumCapacity:)` | `init()` (capacity is compile-time) |
| Growth | `reserveCapacity(_:)` | Not available (fixed) |
| Copyable | Conditional | **Cannot** (INV-INLINE-004a) |
| Sequence | Yes (Copyable) | Blocked until `InlineArray.init(unsafeUninitializedCapacity:)` |

#### Slab.Indexed (Phantom-Typed)

Wraps `Slab<Element>` but retags all indices from `Index<Element>` to `Index<Tag>`:

| Base Slab API | Indexed API | Conversion |
|--------------|-------------|------------|
| `insert(_:at: Index<Element>)` | `insert(_:at: Index<Tag>)` | `.retag(Element.self)` |
| `remove(at: Index<Element>)` | `remove(at: Index<Tag>)` | `.retag(Element.self)` |
| `insert(_:) -> Index<Element>` | `insert(_:) -> Index<Tag>` | `.retag(Tag.self)` |
| `update(at: Index<Element>, with:)` | `update(at: Index<Tag>, with:)` | `.retag(Element.self)` |
| `isOccupied(at: Index<Element>)` | `isOccupied(at: Index<Tag>)` | `.retag(Element.self)` |
| `firstVacant() -> Index<Element>?` | `firstVacant() -> Index<Tag>?` | `.retag(Tag.self)` |
| `subscript(Index<Element>)` | `subscript(Index<Tag>)` | `.retag(Element.self)` |
| `capacity: Index<Element>.Count` | `capacity: Index<Tag>.Count` | `.retag(Tag.self)` |
| `occupancy: Index<Element>.Count` | `occupancy: Index<Tag>.Count` | `.retag(Tag.self)` |

**Implementation**: Zero-cost `.retag()` throughout per [IMPL-003], following `Buffer.Slab.Bounded.Indexed<Tag>`. The entire conversion chain is `Index<Tag>` → `Index<Element>` → `Bit.Index` — two zero-cost retags. No `__unchecked` construction, no rawValue extraction.

---

### SQ4: Should the current naming be replaced?

#### Current vs Proposed

| Current (Storage Vocabulary) | Proposed (Collection Vocabulary) | Rationale |
|------------------------------|----------------------------------|-----------|
| `initialize(at:to:)` | `insert(_:at:)` | "Insert" is the standard collection verb. Buffer layer already uses `insert`. |
| `deinitialize(at:)` | `remove(at:)` | "Remove" is the standard collection verb. Buffer layer already uses `remove`. |
| `initialize(__unchecked:to:)` | `insert(_: __unchecked:)` | Mirrors checked signature shape with `__unchecked` replacing the throwing label. |
| `deinitialize(__unchecked:)` | `remove(__unchecked:)` | Consistent with checked variant. |
| — | `update(at:with:) -> Element` | **New**. Essential for ~Copyable elements where subscript setter is unavailable. Swap old for new. |

#### Analysis

The current naming (`initialize`/`deinitialize`) comes from the **storage layer** vocabulary. These terms describe memory lifecycle operations: placing bytes into uninitialized memory and moving bytes out.

However, at the **data structure layer**, the user is not thinking about memory initialization — they are thinking about inserting and removing elements from a collection. Every sibling data structure uses collection vocabulary:

| Data Structure | Insert | Remove |
|---------------|--------|--------|
| Array | `append(_:)`, `insert(_:at:)` | `remove(at:)`, `removeLast()` |
| Stack | `push(_:)` | `pop()` |
| Queue | `enqueue(_:)` | `dequeue()` |
| Set | `insert(_:)` | `remove(_:)` |
| Dictionary | `insert(_:forKey:)` | `removeValue(forKey:)` |
| Hash.Table | `insert(_:)` | `remove(at:)` |
| **Slab (current)** | **`initialize(at:to:)`** | **`deinitialize(at:)`** |
| **Slab (proposed)** | **`insert(_:at:)`** | **`remove(at:)`** |

The buffer layer (`Buffer.Slab`) already uses `insert(_:at:)` / `remove(at:)`. The data structure layer should not use lower-level vocabulary than the layer it wraps.

**Recommendation**: Rename to `insert`/`remove`. This aligns with:
1. CS convention (insert/remove are standard operations on indexed containers).
2. Buffer layer naming (already uses insert/remove).
3. Sibling data structure naming (Array, Set, Dictionary all use insert/remove).
4. [API-NAME-002] — methods should use the most natural verb for the abstraction level.

---

### SQ5: Should Slab provide auto-insert?

#### The Auto-Insert Pattern

```swift
// Consumer-chosen primitive: caller specifies where
slab.insert(element, at: slot)

// Auto-insert (composed): slab picks first vacant, returns typed index
let slot: Index<Entity> = try slab.insert(entity)
```

Auto-insert composes `firstVacant()` + `insert(_:at:)` into a single atomic operation. This is the **primary API** in Rust's `slab` crate.

#### Arguments For

1. **Primary use case**: Most slab consumers don't care which index they get — they just want to store an element and get back a handle. ECS entity allocation, connection tracking, and resource management all follow this pattern.
2. **Atomicity**: `firstVacant()` + `insert(_:at:)` as two calls creates a TOCTOU gap (another thread could claim the slot between the two calls). Auto-insert is a single operation.
3. **Ergonomics**: `let id = slab.insert(entity)` is cleaner than `let id = slab.firstVacant()!; slab.insert(entity, at: id)`.
4. **Rust precedent**: Auto-insert is the only way to insert in `slab::Slab`. Consumer-chosen insertion is not supported. Our design is more general by supporting both.

#### Arguments Against

1. **Error handling**: What if the slab is full (for bounded/static variants)? Must throw. But the growable variant can grow, so it never fails for capacity reasons (only allocation failure).
2. **Naming collision**: `insert(_:at:)` and `insert(_:)` have different return types. The first returns `Void`; the second returns `Index<Element>`. This is fine — the overloads have different arity.

#### Proposed API

```swift
// Auto-insert: inserts at first vacant slot, returns the typed index.
// For growable Slab: grows if full. Throws only on allocation failure.
// For Static: throws if full.
@discardableResult
public mutating func insert(_ element: consuming Element) throws(Error) -> Index<Element>

// Indexed variant (retags Element → Tag):
@discardableResult
public mutating func insert(_ element: consuming Element) throws(Error) -> Index<Tag>
```

**Recommendation**: Yes, include auto-insert as a **composed convenience**, not a primitive. The operation hierarchy is:

1. **Primitive**: `insert(_:at: Index<Element>)` — consumer-chosen placement. This is the foundation.
2. **Primitive**: `firstVacant() -> Index<Element>?` — bitmap scan for first empty slot.
3. **Composed**: `insert(_:) -> Index<Element>` — built from `firstVacant()` + `insert(_:at:)`.

This follows the primitives philosophy: the primitive operations compose, and the convenience is built on top. Consumer-chosen `insert(_:at:)` is the irreducible operation; auto-insert exists because the composition is common enough to warrant a single-call API (atomicity, ergonomics, eliminates TOCTOU).

---

### SQ6: What should the index type be?

#### The Question

The current `Slab<Element>` uses `Int` for all index parameters. Is `Int` the principled type for Slab indices, or is it mechanism leaking into the API?

#### Analysis

Per [IMPL-INTENT], every line must read as intent, not mechanism. Per [IMPL-002], arithmetic on typed values MUST use typed operators. Per [IMPL-010], `Int` conversions live inside boundary overloads. The question is: **where is the boundary?**

**Array uses Int because it has a principled reason:**
- `Swift.Array` uses `Int` for subscripts — compatibility.
- Array IS the fundamental integer-indexed collection in Swift.
- `Int` is the natural type for "position in a contiguous sequence."

**Slab has no such reason:**
- No `Swift.Slab` exists — the API is greenfield.
- Slab is specialized infrastructure, not a basic collection.
- The buffer layer already uses typed indices (`Bit.Index`, `Index<Tag>`).
- Slot positions are typed quantities — `Index<Element>` means "position of an Element in this slab."

**What does Int express?** "A number." Mechanism.
**What does Index<Element> express?** "A slot position for an Element in this slab." Intent.

#### The Type Flow

With `Index<Element>` as the public type, the internal conversion becomes zero-cost `.retag()`:

```swift
// Index<Element> → Bit.Index: zero-cost retag per [IMPL-003]
_buffer.insert(consume element, at: index.retag(Bit.self))

// Bit.Index → Index<Element>: zero-cost retag
return bitIndex.retag(Element.self)
```

Compare with the `Int` approach, which requires a manual boundary helper:

```swift
// Int → Bit.Index: manual conversion, rawValue chain
Bit.Index(__unchecked: (), Ordinal(UInt(index)))

// Bit.Index → Int: manual conversion
Int(bitPattern: bitIndex.rawValue.rawValue)
```

The typed approach eliminates the `_slotIndex(_:)` helper entirely. The conversion is a `.retag()` — one functor call, zero cost, reads as intent.

#### What About Consumer Ergonomics?

Consumers constructing indices from literal values:

```swift
// Index<Element> supports ExpressibleByIntegerLiteral via Ordinal:
slab.insert(entity, at: 0)     // literal works
slab.insert(entity, at: 5)     // literal works
slab.isOccupied(at: 3)         // literal works
```

Consumers with runtime values cross the boundary at **their** call site, not inside Slab:

```swift
let slot: Index<Entity> = Index(Ordinal(UInt(userInput)))
slab.insert(entity, at: slot)
```

This is correct per [IMPL-010]: the `Int` boundary lives at the consumer's edge, where untyped data enters the typed domain. Slab's internals are typed end-to-end.

#### Impact on Slab.Indexed<Tag>

With `Int` as the base type, `Indexed<Tag>` must convert `Index<Tag>` → `Int` → `Bit.Index` — two boundaries. With `Index<Element>` as the base type, `Indexed<Tag>` simply retags `Index<Tag>` → `Index<Element>` → `Bit.Index` — all zero-cost functor operations per [IMPL-003].

| Base Type | Indexed<Tag> conversion | Cost |
|-----------|-------------------------|------|
| `Int` | `Index<Tag>` → `Int` → `Bit.Index` | Two boundaries, rawValue extraction |
| `Index<Element>` | `Index<Tag>` → `Index<Element>` → `Bit.Index` | Two `.retag()` calls, zero cost |

#### Typed Quantities for Counts and Capacities

If indices are typed, counts and capacities should be too:

| Current (Int) | Proposed (Typed) | Type |
|---------------|-----------------|------|
| `capacity: Int` | `capacity: Index<Element>.Count` | `Tagged<Element, Cardinal>` |
| `occupancy: Int` | `occupancy: Index<Element>.Count` | `Tagged<Element, Cardinal>` |
| `init(minimumCapacity: Int)` | `init(minimumCapacity: Index<Element>.Count)` | Typed count |
| `firstVacant() -> Int?` | `firstVacant() -> Index<Element>?` | Typed index |
| `insert(_:) -> Int` | `insert(_:) -> Index<Element>` | Typed index |

Per [IMPL-006]: stored properties that hold quantities SHOULD use typed wrappers. `capacity` and `occupancy` are quantities of Element slots — `Index<Element>.Count` is the correct type.

#### Recommendation: `Index<Element>` Throughout

**Slab is NOT principally about Int.** Slab is about typed slot positions. The public API should use `Index<Element>` for indices and `Index<Element>.Count` for quantities. The conversion to `Bit.Index` is a zero-cost `.retag()`.

This aligns with:
1. [IMPL-INTENT] — `Index<Element>` reads as intent; `Int` reads as mechanism.
2. [IMPL-002] — Typed arithmetic throughout; no rawValue chains.
3. [IMPL-003] — `.retag()` for cross-domain conversion.
4. [IMPL-006] — Typed stored properties for quantities.
5. [IMPL-010] — The `Int` boundary belongs at the consumer's edge, not inside Slab.
6. The buffer layer already uses typed indices (`Bit.Index`, `Index<Tag>`).
7. `Hash.Table` — the other sparse indexed data structure — also uses typed indices, not `Int`.

---

### Copy-on-Write Considerations

Array, Stack, and Queue all implement copy-on-write (CoW) when `Element: Copyable`. Should Slab?

**Array CoW model**: On copy, the new Array shares the same `Storage.Heap` buffer. On mutation, if `!isKnownUniquelyReferenced`, copy the buffer first.

**Slab CoW model**: Same pattern would work — `Buffer.Slab` uses `Storage.Heap` which is a class (reference-counted). On copy, share the buffer. On mutation, copy if not unique.

**Arguments for CoW**:
- Consistency with Array/Stack/Queue.
- Enables `Slab: Copyable where Element: Copyable` to have value semantics (not just bitwise copy).
- Prevents accidental shared-mutation bugs.

**Arguments against CoW**:
- Adds complexity.
- Slab is more of an allocation structure than a value container — copying a slab is less common than copying an array.
- The `Buffer.Slab.Bounded` currently does NOT implement CoW.

**Assessment**: CoW should be implemented for the growable `Slab` (which wraps `Buffer.Slab` with `Storage.Heap`). This matches the pattern used by Array and Stack. The Static variant uses `Storage.Inline` and is stack-allocated — CoW does not apply.

---

### Cognitive Dimensions Analysis [RES-025]

| Dimension | Assessment |
|-----------|-----------|
| **Visibility** | Good. `occupancy`, `isEmpty`, `isFull`, `isOccupied(at:)` make internal state visible. |
| **Consistency** | Improved. `insert`/`remove` matches Array, Set, Dictionary. Module split matches Array, Stack. |
| **Viscosity** | Low. Adding/removing elements is a single method call. Auto-insert reduces boilerplate. |
| **Role-expressiveness** | Good. `Slab.Indexed<Entity>` clearly communicates "entity storage." `Slab.Static<64>` clearly communicates "inline, 64 slots." |
| **Error-proneness** | Improved. Typed throws (`throws(Slab.Error)`) prevent error erasure. Typed indices (`Index<Element>`) prevent cross-slab index confusion. Checked/unchecked pairs give control. Auto-insert eliminates TOCTOU with `firstVacant`. |
| **Abstraction** | Right level. Three variants (dynamic, static, indexed) cover the main use cases without over-abstracting. |

---

## Outcome

**Status**: IN_PROGRESS

### Recommended Architecture

#### 1. Variants

| Variant | Wraps | Storage | Growable | Declared In |
|---------|-------|---------|:---:|-------------|
| `Slab<Element>` | `Buffer.Slab` | Heap | Yes | Struct body |
| `Slab<Element>.Static<let wordCount: Int>` | `Buffer.Slab.Inline<wordCount>` | Inline | No | Nested in body |
| `Slab<Element>.Indexed<Tag>` | `Slab<Element>` | (wraps base) | Yes | Nested in body |

#### 2. Module Split

| Module | Purpose | Key Dependencies |
|--------|---------|-----------------|
| **Slab Primitives Core** | Types + ~Copyable ops | Buffer Slab, Index, Property, Ownership |
| **Slab Dynamic Primitives** | Copyable ops for Slab | Core + Collection + Sequence |
| **Slab Static Primitives** | Copyable ops for Slab.Static | Core + Sequence |
| **Slab Primitives** | Umbrella | Core + Dynamic + Static |

#### 3. API Naming and Compositional Hierarchy

**Primitives** (irreducible operations — all typed per SQ6):

| Operation | Name | Rationale |
|-----------|------|-----------|
| Store element at slot | `insert(_:at: Index<Element>)` | Consumer-chosen primitive. Foundation for all insertion. |
| Remove element from slot | `remove(at: Index<Element>) -> Element` | Consumer-chosen primitive. Foundation for all removal. |
| Replace element at slot | `update(at: Index<Element>, with:) -> Element` | Atomic swap primitive. Essential for ~Copyable [IMPL-INTENT]. |
| Find first empty slot | `firstVacant() -> Index<Element>?` | Bitmap scan primitive. |
| Check slot state | `isOccupied(at: Index<Element>) -> Bool` | Occupancy query primitive. |

**Composed** (built from primitives):

| Operation | Name | Composition |
|-----------|------|-------------|
| Store at first vacant | `insert(_:) -> Index<Element>` | `firstVacant()` + `insert(_:at:)` |
| Consuming iteration | `drain` property | `Property<Sequence.Drain, Self>.View` [IMPL-021] |
| Clear all slots | `removeAll()` | Delegates to buffer bulk op [IMPL-032] |

#### 4. Package.swift Structure (Proposed)

```swift
products: [
    .library(name: "Slab Primitives", targets: ["Slab Primitives"]),
    .library(name: "Slab Primitives Core", targets: ["Slab Primitives Core"]),
    .library(name: "Slab Dynamic Primitives", targets: ["Slab Dynamic Primitives"]),
    .library(name: "Slab Static Primitives", targets: ["Slab Static Primitives"]),
],
targets: [
    .target(
        name: "Slab Primitives Core",
        dependencies: [
            .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
            .product(name: "Index Primitives", package: "swift-index-primitives"),
            .product(name: "Bit Primitives", package: "swift-bit-primitives"),
            .product(name: "Ownership Primitives", package: "swift-ownership-primitives"),
            .product(name: "Property Primitives", package: "swift-property-primitives"),
            .product(name: "Buffer Slab Primitives", package: "swift-buffer-primitives"),
        ]
    ),
    .target(
        name: "Slab Dynamic Primitives",
        dependencies: [
            "Slab Primitives Core",
            .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
        ]
    ),
    .target(
        name: "Slab Static Primitives",
        dependencies: [
            "Slab Primitives Core",
            .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
        ]
    ),
    .target(
        name: "Slab Primitives",
        dependencies: [
            "Slab Primitives Core",
            "Slab Dynamic Primitives",
            "Slab Static Primitives",
        ]
    ),
]
```

#### 5. Source File Layout (Proposed)

Per **[PATTERN-022]**: all nested type declarations (`Static`, `Indexed`, `Error`) that reference the `~Copyable` generic parameter MUST remain in the same file as the parent `Slab<Element>` struct. Extensions adding methods CAN be in separate files with `where Element: ~Copyable`.

```
Sources/
├── Slab Primitives Core/
│   ├── Slab.swift                    ← struct Slab<E: ~Copyable>: ~Copyable
│   │                                    nested: Static<let wordCount: Int>
│   │                                    nested: Indexed<Tag: ~Copyable>
│   │                                    nested: Error enum
│   │                                    conditional: Copyable where Element: Copyable
│   │                                    conditional: @unchecked Sendable where Element: Sendable
│   ├── Slab ~Copyable.swift          ← extension Slab where Element: ~Copyable
│   │                                    insert/remove/update/occupancy
│   ├── Slab.Static ~Copyable.swift   ← extension Slab.Static where Element: ~Copyable
│   ├── Slab.Indexed ~Copyable.swift  ← extension Slab.Indexed where Element: ~Copyable
│   └── exports.swift                 ← @_exported imports
│
├── Slab Dynamic Primitives/
│   ├── Slab Copyable.swift           ← subscript, peek, CoW, Sequence, Iterator
│   ├── Slab.Indexed Copyable.swift   ← Indexed Copyable ops
│   └── exports.swift                 ← @_exported Core + Collection + Sequence
│
├── Slab Static Primitives/
│   ├── Slab.Static Copyable.swift    ← peek, subscript (Sequence blocked by INV-INLINE-004a)
│   └── exports.swift                 ← @_exported Core + Sequence
│
└── Slab Primitives/
    └── exports.swift                 ← @_exported all modules
```

#### 6. Implementation Skill Compliance

The following implementation skill rules are directly relevant to the Slab data structure layer:

| Rule | Application |
|------|-------------|
| **[IMPL-INTENT]** | All public API reads as intent. `insert`/`remove`/`update` are domain verbs, not storage mechanism (`initialize`/`deinitialize`). `Index<Element>` reads as intent; `Int` reads as mechanism. |
| **[IMPL-002]** | Typed arithmetic throughout. `Index<Element>`, `Index<Element>.Count` — no `Int`, no `.rawValue.rawValue` chains. |
| **[IMPL-003]** | All cross-domain conversions use `.retag()`: `Index<Element>` → `Bit.Index` via `.retag(Bit.self)`. `Slab.Indexed<Tag>` retags `Index<Tag>` → `Index<Element>` → `Bit.Index`. Zero cost, reads as intent. |
| **[IMPL-006]** | `capacity` and `occupancy` stored as `Index<Element>.Count`, not raw `UInt` or `Int`. |
| **[IMPL-010]** | No `Int` boundary inside Slab. The `Int` boundary belongs at the **consumer's** edge — where untyped data enters the typed domain. Slab's internals are typed end-to-end. |
| **[IMPL-020]/[IMPL-021]** | `drain` exposed as `Property<Sequence.Drain, Self>.View` (the `~Copyable` accessor pattern). Not an ad-hoc struct. |
| **[IMPL-032]** | `removeAll()` delegates to buffer bulk `removeAll()`. No per-element loop at data structure layer. |
| **[IMPL-033]** | Iteration uses highest-level abstraction: `bitmap.ones.forEach { }` inside infrastructure, `Sequence` or `drain` at consumer level. No manual `while` loops at the data structure layer. |
| **[IMPL-040]** | Checked operations use typed throws (`throws(Slab.Error)`). Unchecked operations use `precondition`. Low-level pointer access uses precondition. |
| **[IMPL-041]** | `Slab.Error` is a nested enum with domain-level case names (`.indexOutOfBounds`, `.full`). |
| **[PATTERN-017]** | No `.rawValue` at call sites. All conversions are `.retag()` (zero-cost functor). |
| **[PATTERN-022]** | All nested types (`Static`, `Indexed`, `Error`) in `Slab.swift`. Method extensions in separate files. |

**Typed index flow** (per [IMPL-002], [IMPL-003], SQ6):

The entire conversion chain is zero-cost retags — no `_slotIndex` helper, no `Int(bitPattern:)`, no rawValue extraction:

```swift
extension Slab where Element: ~Copyable {
    @inlinable
    public mutating func insert(
        _ element: consuming Element,
        at index: Index<Element>
    ) throws(Error) {
        guard index < capacity.map(Ordinal.init) else { throw .indexOutOfBounds }
        _buffer.insert(consume element, at: index.retag(Bit.self))  // zero-cost
    }
}
```

Consumer call sites read as pure intent:

```swift
var slab = Slab<Entity>(minimumCapacity: .init(Cardinal(1024)))
let slot: Index<Entity> = try slab.insert(entity)           // auto-insert
let old = try slab.update(at: slot, with: newEntity)         // atomic swap
slab.drain { slot, element in process(element) }             // consuming iteration
slab.isOccupied(at: slot)                                    // occupancy check
```

For `Slab.Indexed<Tag>`, the chain is `Index<Tag>` → `Index<Element>` → `Bit.Index` — two zero-cost retags:

```swift
extension Slab.Indexed where Element: ~Copyable, Tag: ~Copyable {
    @inlinable
    public mutating func insert(
        _ element: consuming Element,
        at index: Index<Tag>
    ) throws(Error) {
        try _base.insert(consume element, at: index.retag(Element.self))
    }
}
```

### Open Questions

1. **Buffer.Slab growth semantics**: Does `Buffer.Slab` (the growable variant) support `reserveCapacity`-style growth, or only implicit growth on insert? This affects whether we need a `grow(to:)` method on the data structure.

2. **Sequence element type**: Should `Slab` iterate over `Element` or `(Index<Element>, Element)` pairs? Rust `slab` iterates `(usize, &T)` pairs. Swift's `Dictionary` iterates `(key, value)` pairs. For Slab, yielding `(Index<Element>, Element)` pairs is more useful because the typed index is the only way to refer back to the element. This applies to both `Sequence` conformance (Copyable) and `drain` (consuming iteration).

3. **Small variant**: Should `Slab.Small<let wordCount: Int>` exist (SBO: inline when small, heap when grown)? Deferred — add if demand emerges.

### Resolved Questions (promoted from open to decided)

1. **Update API**: `update(at: Index<Element>, with:) -> Element` is **required**, not optional. Per [IMPL-INTENT], for `~Copyable` elements the `subscript` setter is unavailable — `update` is the only way to replace an element without `remove` + `insert` (which leaves the slot momentarily vacant, creating a TOCTOU gap and requiring the caller to manage the old value). The `update` method is the intent-level expression for "swap the element at this slot."

### Implications

- **Breaking change**: Renaming `initialize`/`deinitialize` to `insert`/`remove` and changing the base type from bounded to growable. Since the package is pre-1.0, this is acceptable.
- **New dependencies**: `swift-property-primitives` and `swift-sequence-primitives` added as dependencies.
- **Test migration**: Existing tests need updating for new API names and module imports.

---

## References

1. tokio-rs/slab. "Pre-allocated storage for a uniform data type." https://github.com/tokio-rs/slab
2. Bonwick, J. (1994). "The Slab Allocator: An Object-Caching Kernel Memory Allocator." *Proc. USENIX Summer 1994*.
3. Deutsch, A. (2017). "A slot_map Container for C++." P0661R0.
4. West, C. (2018). "Using Rust for Game Development." RustConf 2018.
5. Fitzgen (2018). `generational-arena` Rust crate. https://github.com/fitzgen/generational-arena
6. Peters, O. `slotmap` crate. https://docs.rs/slotmap
7. [slab-first-principles.md](../../swift-buffer-primitives/Research/slab-first-principles.md) — Buffer.Slab naming analysis.
8. [primitives-taxonomy-naming-layering-audit.md](../../Research/primitives-taxonomy-naming-layering-audit.md) — Full taxonomy audit.
9. Nystrom, R. (2014). *Game Programming Patterns*, Chapter 19: "Object Pool."
10. Green, T.R.G. (1989). "Cognitive Dimensions of Notations." *People and Computers V*, 443-460.

---

## Deferral

**Date**: 2026-03-15
**Previous status**: IN_PROGRESS (since 2026-02-11)
**New status**: DEFERRED

**Blocker/Reason**: Document provides complete design for slab-primitives variants (Slab, Slab.Static, Slab.Indexed), module split (Core + Inline modules), API surface, and implementation plan with 4 phases. Analysis is thorough but implementation has not started. The package remains a monolithic stub wrapping Buffer.Slab.Bounded. Deferred because slab-primitives is lower priority than active work streams (leaf package audit, typed throws, rendering architecture).

**Resumption trigger**: When slab-primitives is needed by a downstream consumer, or when data structure packages enter a parity/completeness cycle.
