# Storage Arena Architecture

<!--
---
version: 1.0.0
last_updated: 2026-02-11
status: DECISION
research_tier: 3
applies_to: [swift-memory-primitives, swift-storage-primitives, swift-buffer-primitives]
normative: false
---
-->

## Context

Three research documents converge on the same type — `Storage<Element>.Arena` —
with partially conflicting recommendations:

1. **`memory-storage-composition-feasibility.md`** (RECOMMENDATION) — Step 9:
   "Implement Storage.Arena composing Memory.Arena — Memory.Arena needs no
   modifications." Establishes that Storage types SHOULD compose Memory types
   (Memory = raw, Storage = typed), mirroring SE-0107's raw/typed separation.

2. **`buffer-arena-conditional-copyable.md`** (RECOMMENDATION) — Option A:
   Create `Storage<Element>.Arena` as a `ManagedBuffer` subclass with SoA
   layout (meta + elements) and an arena-semantics-aware deinit. This would
   make `Buffer.Arena` conditionally Copyable by removing its deinit.

3. **Current implementation** — `Storage<Element>.Arena` already exists as a
   `final class` composing `Memory.Arena` + `Bit.Vector`. It is a bump
   allocator (sequential allocation, no individual deallocation). It has zero
   buffer-layer consumers — `Buffer.Arena` uses `Storage.Heap` + a manually
   managed `UnsafeMutablePointer<Meta>` instead.

The first document says compose Memory.Arena. The second says use ManagedBuffer.
The current implementation composes Memory.Arena but serves a different purpose
(bump allocation) than what Buffer.Arena needs (free-list with generation tokens).

This document reconciles these positions.

### Trigger

During implementation of Option A from `buffer-arena-conditional-copyable.md`,
the proposed ManagedBuffer approach would have broken the composition
recommendation from `memory-storage-composition-feasibility.md`. That document
explicitly recommends Storage.Arena compose Memory.Arena, and the five-layer
architecture mandates downward-only composition (Storage composes Memory).

### Constraints

1. Storage.Arena MUST be a reference type (class) — Buffer.Arena needs
   reference semantics for conditional Copyable conformance
2. Storage.Arena SHOULD compose Memory.Arena — per prior research and
   architectural consistency
3. Memory.Arena provides raw contiguous allocation with deinit-based
   deallocation — a ~Copyable struct
4. Buffer.Arena needs: SoA layout (meta + elements), generation-token
   occupancy tracking, free-list slot recycling, self-cleaning deinit
5. No Foundation imports
6. Must support `~Copyable` elements

## Question

How should `Storage<Element>.Arena` be architected to serve `Buffer.Arena`'s
needs (conditional Copyable, generation tokens, SoA layout) while preserving
composition with `Memory.Arena` as recommended by prior research?

## Analysis

### SQ1: What Does Memory.Arena Actually Provide?

`Memory.Arena` (`swift-memory-primitives`) is a bump allocator:

```swift
@safe
public struct Arena: ~Copyable {
    internal let _storage: UnsafeMutableRawPointer   // raw allocation
    internal let _capacity: Memory.Address.Count      // total bytes
    internal var _allocated: Memory.Address.Count      // bump cursor

    public init(capacity: Memory.Address.Count)        // allocate raw block
    public var baseAddress: UnsafeMutableRawPointer     // start of allocation
    public mutating func allocate(count:alignment:) -> Memory.Address?
    public mutating func reset()                       // reset cursor to zero

    deinit { _storage.deallocate() }                   // free raw block
}
```

Its value proposition is two-fold:
1. **Allocation lifecycle** — `init` allocates, `deinit` deallocates. No manual
   `deallocate()` call needed.
2. **Bump allocation** — O(1) sequential allocation with alignment support.

For our purposes, value (1) is universal — any raw allocation benefits from
deterministic cleanup. Value (2) is specific to sequential allocation, which
Buffer.Arena does NOT use (it uses random-access slots with a free-list).

### SQ2: How Can Memory.Arena Be Composed?

Memory.Arena can be composed in two ways:

**A. As a bump allocator** — Use `allocate()` for sequential region allocation.
This is the current Storage.Arena pattern: allocate one region per slot
sequentially, track occupancy with Bit.Vector.

**B. As a raw allocation provider** — Use only `init(capacity:)` for the
allocation and `baseAddress` for pointer access. Ignore the bump pointer.
Compute custom layout within the raw allocation.

Approach B is more general. It uses Memory.Arena purely for its allocation
lifecycle (RAII) while the consumer manages layout. This is valid composition —
analogous to how `std::vector` in C++ composes `std::allocator` even though
vector manages its own internal layout.

For Buffer.Arena's needs:
- Approach A cannot work: bump allocation is sequential, but Buffer.Arena
  needs random-access slot storage with a free-list.
- Approach B works: Memory.Arena provides a contiguous raw allocation.
  Storage.Arena imposes SoA layout (meta array + element array) within it.

### SQ3: Composition (Memory.Arena) vs Direct (ManagedBuffer)

Two architectures can deliver the reference-type, self-cleaning storage that
Buffer.Arena requires:

**Architecture 1: Class composing Memory.Arena**

```
┌─────────────────────────────────┐
│ Storage<E>.Arena (final class)  │  ← ARC reference type
│   _arena: Memory.Arena          │  ← raw allocation lifecycle
│   _elementOffset: Int           │  ← layout constant
│   _slotCapacity: Index<E>.Count │
│   _highWater: Index<E>.Count    │  ← synced for deinit
│                                 │
│   deinit:                       │
│     iterate meta tokens         │
│     deinitialize occupied elems │
│     // Memory.Arena deinit      │
│     // fires automatically →    │
│     // raw deallocation         │
└─────────────────────────────────┘
         │ _arena.baseAddress
         ▼
┌─────────────────────────────────────────────────┐
│ Raw allocation (owned by Memory.Arena)           │
│ [Meta₀][Meta₁]...[Meta_{n-1}] [pad] [E₀]...[E_{n-1}] │
└─────────────────────────────────────────────────┘
```

**Architecture 2: ManagedBuffer subclass**

```
┌─────────────────────────────────────────────────┐
│ Storage<E>.Arena : ManagedBuffer<Header, UInt8>  │  ← ARC + data in one alloc
│   header: { highWater, slotCapacity }            │
│   body:                                          │
│   [Meta₀][Meta₁]...[Meta_{n-1}] [pad] [E₀]...[E_{n-1}] │
│                                                  │
│   deinit:                                        │
│     iterate meta tokens                          │
│     deinitialize occupied elems                  │
│     // ManagedBuffer dealloc                     │
│     // frees everything                          │
└─────────────────────────────────────────────────┘
```

### SQ4: Allocation Count Analysis

| Architecture | Class Object | Data Buffer | Total |
|-------------|:------------:|:-----------:|:-----:|
| 1 (Memory.Arena) | 1 (class) | 1 (Memory.Arena's raw alloc) | **2** |
| 2 (ManagedBuffer) | — | 1 (ManagedBuffer = class + data) | **1** |

Architecture 2 has one fewer allocation. However:
- Arena creation is infrequent (once per data structure, or once per growth)
- The class object for Architecture 1 is small (~40 bytes: 5 stored properties)
- Modern allocators have O(1) allocation for small objects
- Memory.Arena's raw allocation is the large one (proportional to capacity)

**The allocation count difference is negligible for arena usage patterns.**
Arenas are created once and used for many insert/remove operations. The extra
class object allocation in Architecture 1 is amortized over the arena's lifetime.

### SQ5: Deinit Ordering Guarantee

Architecture 1 requires a specific deinit ordering: Storage.Arena's class deinit
must deinitialize elements BEFORE Memory.Arena's struct deinit deallocates the
raw storage.

Swift guarantees this ordering for class deinit:
1. Class deinit body executes
2. Stored properties are destroyed (struct deinits fire)

This is specified in the Swift Language Reference and is the same guarantee that
the current `Storage.Pool` relies on — its `deinit` accesses `_pool: Memory.Pool`
before Memory.Pool's deinit fires.

**The ordering is safe and guaranteed.**

### SQ6: Can Memory.Arena Be Upgraded for This Use Case?

The question arises: should Memory.Arena gain features that better support
Storage.Arena's needs?

**Memory.Arena currently provides:**
- `init(capacity:)` — allocate raw block
- `baseAddress` — pointer to start
- `allocate(count:alignment:)` — bump-allocate region
- `reset()` — reset cursor
- `deinit` — deallocate

**What Storage.Arena needs from Memory.Arena:**
- A raw contiguous allocation — ✓ (`init` + `baseAddress`)
- Automatic deallocation — ✓ (`deinit`)
- Nothing else — the bump pointer, `allocate()`, and `reset()` are NOT used

Memory.Arena's existing API is sufficient. No upgrades needed. This aligns
with the prior research conclusion: "Memory.Arena requires no modifications
for composition."

**However**, Memory.Arena's bump allocation features (`allocate`, `reset`,
`_allocated`) become dead weight when used purely as a raw allocation provider.
This suggests two possible improvements (neither required):

1. **Extract a simpler base type** — `Memory.Allocation` or similar, that
   provides only `init(capacity:)`, `baseAddress`, and `deinit`. Memory.Arena
   would compose or extend it with bump-allocation semantics. This is a
   refactoring improvement, not a functional requirement.

2. **Accept the unused features** — Memory.Arena's bump allocation adds
   ~16 bytes of overhead (`_allocated` cursor + `_capacity` duplicate of what
   we track in Storage.Arena). This is negligible. Simplicity of composition
   outweighs micro-optimization.

**Recommendation: No Memory.Arena changes.** The existing API suffices. The
unused bump features are harmless overhead.

### SQ7: Growth Semantics

Buffer.Arena supports growth (doubling capacity when full). Growth requires:
1. Allocate new, larger storage
2. Copy meta prefix from old to new
3. Move occupied elements from old to new
4. Release old storage (without deinitializing moved elements)

For Architecture 1 (Memory.Arena composition):
- Create new `Storage<Element>.Arena` with larger capacity
- Copy meta: `memcpy(newMetaBase, oldMetaBase, oldCapacity * 8)`
- Move elements: iterate occupied slots, move each
- Disarm old: set `old._highWater = .zero` (deinit scans 0 slots = no-op)
- Replace reference: `_arenaStorage = new`
- Old class deinits: body is no-op, Memory.Arena deinit frees old raw alloc ✓

For Architecture 2 (ManagedBuffer):
- Create new ManagedBuffer with larger capacity
- Same copy/move sequence
- Disarm old: set `old.header.highWater = .zero`
- Replace reference, old ManagedBuffer deallocs ✓

**Both architectures handle growth identically.** The disarm-then-replace
pattern works for both.

### SQ8: Architectural Consistency

The five-layer architecture mandates downward-only composition:

```
Buffer  → Storage → Memory
Buffer.Ring    → Storage.Heap    → ManagedBuffer (stdlib)
Buffer.Linked  → Storage.Pool    → Memory.Pool
Buffer.Arena   → Storage.Arena   → ???
```

| Architecture | Storage.Arena composes | Consistent? |
|-------------|----------------------|-------------|
| 1 (Memory.Arena) | Memory.Arena | ✓ Storage composes Memory |
| 2 (ManagedBuffer) | ManagedBuffer (stdlib) | ✓ Storage composes stdlib |

Both are consistent with downward-only composition. The difference is WHICH
raw layer is composed:
- Architecture 1 composes our own `Memory.Arena`
- Architecture 2 composes stdlib's `ManagedBuffer`

Note that `Storage.Heap` already composes `ManagedBuffer` (not a Memory type).
So Architecture 2 has precedent. The composition-feasibility research notes:
"Storage.Heap composes a raw allocator (ManagedBuffer). Storage.Pool should
compose a raw allocator (Memory.Pool). The pattern is consistent — the specific
raw allocator differs because the allocation strategy differs."

The question is: which raw allocator is the RIGHT fit for arena storage?

- `ManagedBuffer`: provides ARC + header + typed element buffer in one alloc
- `Memory.Arena`: provides raw contiguous allocation with deterministic cleanup

Memory.Arena is a closer semantic match — it's an arena allocator serving
an arena storage type. ManagedBuffer is a generic managed buffer. But
ManagedBuffer gives the single-allocation advantage.

### SQ9: Prior Art — Allocator Composition in Other Languages

**Rust:**
- `typed-arena` crate composes `Vec<u8>` (raw allocation) and adds typed overlay
- `bumpalo` wraps raw allocation and provides typed access
- `slotmap` (the generational-arena pattern) uses a `Vec<Slot<V>>` internally —
  it DOES NOT compose a raw allocator, because Rust's `Vec` already handles allocation

**C++:**
- `std::pmr::monotonic_buffer_resource` owns a raw buffer and provides bump allocation
- `std::pmr::pool_resource` composes `monotonic_buffer_resource`
- The composition chain is: pool → monotonic → raw allocation

**Zig:**
- `std.heap.ArenaAllocator` wraps any `Allocator` interface
- Composition is always through an allocator interface, not a concrete type

**Pattern**: Languages with explicit allocation (Rust, C++, Zig) compose
allocators through interfaces or concrete wrappers. The composed allocator
provides raw memory; the wrapper adds typed semantics.

Our Memory.Arena → Storage.Arena composition follows this exact pattern.

## Comparison

| Criterion | Arch 1 (Memory.Arena) | Arch 2 (ManagedBuffer) |
|-----------|:---------------------:|:----------------------:|
| Allocations per arena | 2 (class + raw) | 1 (ManagedBuffer) |
| Composes Memory.Arena | **Yes** | No |
| Prior research compliance | **Full** (composition rec.) | Partial (violates Step 9) |
| Architectural consistency | Memory → Storage chain | Stdlib → Storage chain |
| Cache locality (meta+elem) | Same (contiguous in raw alloc) | Same (contiguous in body) |
| Deinit ordering | Guaranteed (class body → struct deinit) | Guaranteed (ManagedBuffer deinit) |
| Growth pattern | Create new class, disarm old | Create new MB, disarm old |
| Memory.Arena changes needed | **None** | N/A |
| Code complexity | ~120 lines (class + composition) | ~100 lines (ManagedBuffer subclass) |
| Existing pattern precedent | Storage.Pool composes Memory.Pool | Storage.Heap subclasses ManagedBuffer |
| Overhead | ~16 bytes unused bump state | ~0 |
| CoW via isKnownUniquelyReferenced | ✓ | ✓ |
| Conditional Copyable enabled | ✓ | ✓ |
| Self-cleaning deinit | ✓ (element deinit + auto dealloc) | ✓ (element deinit + MB dealloc) |

## Prior Art

### Internal
- `memory-storage-composition-feasibility.md` (RECOMMENDATION) — establishes
  composition as recommended for Storage.Pool and Storage.Arena
- `buffer-arena-conditional-copyable.md` (RECOMMENDATION) — identifies the
  conditional Copyable problem and proposes Option A (arena-aware storage class)
- `storage-pool-architecture.md` (DECISION, superseded) — original independence
  analysis for Storage.Pool
- `memory-pool-arena-buffer-usage-analysis.md` (RECOMMENDATION) — zero-consumer
  analysis for Memory types
- `primitives-taxonomy-naming-layering-audit.md` (DECISION) — four-layer stack
  validation (Memory → Storage → Buffer → Data Structure)
- `storage-primitives-comparative-analysis.md` (RECOMMENDATION) — REC-001
  sketched Storage.Arena composing Memory.Arena
- `swift-buffer-primitives/Research/arena-buffer-design.md` (RECOMMENDATION) —
  Buffer.Arena design with generation tokens, free-list, position handles

### Swift Evolution
- SE-0107: UnsafeRawPointer API — raw/typed separation model
- SE-0390: Noncopyable structs and enums — deinit-implies-~Copyable constraint
- SE-0427: Noncopyable generics — classes with ~Copyable stored properties

### Academic
- Bonwick, "The Slab Allocator" (USENIX 1994) — typed cache layered on raw vmem
- Bonwick & Adams, "Magazines and Vmem" (USENIX 2001) — multi-tier composition

## Outcome

**Status**: DECISION

### Preliminary Recommendation: Architecture 1 — Class Composing Memory.Arena

Compose `Memory.Arena` inside a `final class` that adds SoA layout, generation-
token deinit, and reference semantics for conditional Copyable.

### Rationale

1. **Honors prior research.** `memory-storage-composition-feasibility.md`
   explicitly recommends "Implement Storage.Arena composing Memory.Arena."
   Architecture 1 fulfills this recommendation. Architecture 2 would require
   a new research document to supersede it and justify why ManagedBuffer is
   preferred over Memory.Arena for this specific type.

2. **Memory.Arena needs no changes.** Architecture 1 uses Memory.Arena as-is.
   No modifications to swift-memory-primitives are needed. This was the key
   finding of the composition-feasibility research.

3. **Consistent with Storage.Pool pattern.** The current Storage.Pool is a
   `final class` composing `Memory.Pool` (a ~Copyable struct). Storage.Arena
   as a `final class` composing `Memory.Arena` (a ~Copyable struct) is the
   same pattern.

4. **Both architectures solve the problem.** Conditional Copyable, self-cleaning
   deinit, CoW support, and growth — all work identically in both architectures.
   The choice is about architectural consistency, not functionality.

5. **The allocation count difference is negligible.** One extra small class
   allocation per arena lifetime, amortized over thousands of insert/remove
   operations. This is not a meaningful performance difference.

### Proposed Structure

```swift
extension Storage where Element: ~Copyable {
    public final class Arena {
        @usableFromInline package var _arena: Memory.Arena
        @usableFromInline package let _elementOffset: Int
        @usableFromInline package let _slotCapacity: Index<Element>.Count
        @usableFromInline package var _highWater: Index<Element>.Count

        deinit {
            // 1. Iterate meta tokens, deinitialize occupied elements
            // 2. Memory.Arena deinit fires automatically → frees raw storage
        }

        @frozen
        public struct Meta: BitwiseCopyable {
            public var token: UInt32
            public var nextFree: UInt32
        }
    }
}
```

Layout within Memory.Arena's raw allocation:
```
baseAddress
│
▼
┌──────────────────────────────────────────────────────────┐
│ Meta₀ │ Meta₁ │ ... │ Meta_{n-1} │ [align pad] │ E₀ │ ... │ E_{n-1} │
└──────────────────────────────────────────────────────────┘
│←── n × 8 bytes ──────────────→│              │←── elements ──→│
│                                │←─ _elementOffset from base ─→│
```

### Implementation Outline

| Step | Package | Change |
|------|---------|--------|
| 1 | swift-storage-primitives | Rewrite `Storage.Arena` class: compose Memory.Arena, SoA layout, Meta type, deinit |
| 2 | swift-storage-primitives | Rewrite `Storage Arena Primitives`: factory, pointer access, element ops |
| 3 | swift-storage-primitives | Keep `Storage.Arena.Inline` unchanged (orthogonal) |
| 4 | swift-buffer-primitives | Change `Buffer.Arena` struct: `_arenaStorage: Storage<Element>.Arena` |
| 5 | swift-buffer-primitives | Remove `Buffer.Arena.deinit` and `Buffer.Arena.Bounded.deinit` |
| 6 | swift-buffer-primitives | Update static methods for new storage type |
| 7 | swift-buffer-primitives | Update instance methods, add header sync |
| 8 | swift-buffer-primitives | Uncomment `extension Buffer.Arena: Copyable where Element: Copyable {}` |
| 9 | swift-storage-primitives | Update Storage.Arena tests |

### Resolved Questions

1. **`_elementOffset`: computed, not cached.** Matches Storage.Split pattern.
   The computation (multiply + align) uses compile-time constants.

2. **`Buffer.Arena.Meta` → typealias to `Storage.Arena.Meta`.** Meta definition
   moves to Storage.Arena. Buffer.Arena.Meta becomes a typealias. Acceptable
   since this is pre-ABI-stable code.

3. **Header sync: write-through.** Matches Ring/Linear pattern. Every mutation
   that changes `highWater` syncs to `Storage.Arena._highWater`.

4. **`Storage.Arena.Inline`: unchanged.** Orthogonal — different backing,
   different allocation pattern, different consumers.

## References

See Prior Art section above for full list.
