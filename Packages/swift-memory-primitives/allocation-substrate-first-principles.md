# Allocation Substrate — First Principles

<!--
---
version: 1.1.0
last_updated: 2026-05-25
status: DECISION
---
-->

> **Tier 3** (ecosystem-wide, foundational L1 contract, timeless). This document
> is a **design proposal** feeding a `/collaborative-discussion` convergence pass;
> full formal semantics ([RES-024]) and a systematic literature review ([RES-023])
> are deferred to post-convergence. **Converged 2026-05-25** via `/collaborative-discussion`
> (Claude × ChatGPT) + binding principal refinements — see the **Converged Plan**; status is now DECISION.

## Context

This is part of the buffer / storage / memory unification arc. The storage
value-type-façade migration (waves 1–8) is complete and merged to `main`:
`Storage.Heap` / `.Slab` / `.Arena` / `.Pool` are conditionally-`Copyable`
value-type façades conforming to `Storage.Protocol` (`capacity` + `pointer(at:)`).
Before the buffer-side migration (the "Lever-1" generic-over-`some Storage.Protocol`
algorithm), the principal asked for the substrate **below** storage — memory
addressing and allocation — to be made structurally correct, so that "once we
get to buffer, the substrate of storage, memory, and allocation is perfect."

**Trigger**: the question *"should there be an allocator-primitives package?"*
Grounding (2026-05-25) revealed that allocation is **already** decomposed in the
Memory tier — `Memory.Allocator.Protocol`, `Memory.Pool`, and `Memory.Arena` all
exist — but the allocator *protocol* is inert and carries three structural
defects. So the real question is not "new package" but "what is the correct
allocation contract." This document designs it.

**Framing directive** (principal, explicit): judge on **structural correctness +
evergreen composition**, NOT on consumer demand — per `feedback_correctness_and_evergreen`.
The "who consumes it" axis is deliberately out of scope.

**[RES-018] classification**: this is **case (b) — domain-owned vocabulary at
L1**. It redesigns the Memory domain's own allocation vocabulary; it does not
propose a new cross-cutting primitive. The cross-domain-fit gate does not fire.

## Question

What is the structurally-correct contract for *"an allocator"* in the Memory
tier, such that **Memory → Allocation → Storage → Buffer** compose as a clean
layered stack — and how do the three existing allocators (system /
`Memory.Allocator`, slot / `Memory.Pool`, region / `Memory.Arena`) map onto it?

## Current State (verified 2026-05-25)

Three distinct contracts already exist; the allocators and the region noun:

| Type | request | hands back | reclamation | failure idiom | conforms allocator protocol? |
|---|---|---|---|---|---|
| `Memory.Allocator` (system) | `count, alignment` | `Memory.Address` | individual | `throws(Never)` | **yes — the only conformer** |
| `Memory.Arena` | `count, alignment` | `Memory.Address?` | **bulk only** (`reset()`) | `-> Optional` | no |
| `Memory.Pool` | nullary (slot size baked in) | `Index<Slot>` + `pointer(at:)` | individual (`deallocate(at:)`) | `throws(Pool.Error)` | no |
| `Memory.Buffer.Mutable` | — | — | — | — | the **region descriptor**: `{_start: Memory.Address, _count}` |

Verified citations:

- `Memory.Allocator.Protocol`: `~Copyable`, `associatedtype Error`,
  `allocate(count: Memory.Address.Count, alignment:) throws(Error) -> Memory.Address`,
  `deallocate(_ address:, count:, alignment:)` — `swift-memory-primitives/Sources/Memory Allocation Primitives/Memory.Allocator.Protocol.swift:23-49`. [Verified: 2026-05-25]
- Only conformer is `Memory.Allocator` (system malloc wrapper, `throws(Never)`) —
  `…/Memory.Allocator.swift:14-36`. `Memory.Pool` / `Memory.Arena` do **not**
  conform. [Verified: 2026-05-25]
- `Span.Protocol` (a *separate* read-access protocol: `span` +
  `withUnsafeBufferPointer`) — `…/Span Protocol Primitives/Span.Protocol.swift`.
  `Storage.Heap` / `Storage.Inline` conform to it. [Verified: 2026-05-25]
- `Storage.Protocol` = `capacity: Index<Element>.Count` + `@unsafe pointer(at: Index<Element>)`
  — `swift-storage-primitives/Sources/Storage Protocol Primitives/Storage.Protocol.swift:20-37`. [Verified: 2026-05-25]
- `Memory.Buffer.Mutable` = `{_start: Memory.Address, _count: Memory.Address.Count}`,
  a self-describing region descriptor that does **not** own its allocation, with
  static `.allocate(count:alignment:)` and instance `.deallocate()` —
  `swift-memory-buffer-primitives/Sources/Memory Buffer Primitives/Memory.Buffer.Mutable.swift:61-151`. [Verified: 2026-05-25]
- `Memory.Pool.allocateSlot() -> Index<Slot>` (`Memory.Pool.swift:238`),
  `.allocate() -> UnsafeMutableRawPointer` (`:299`), `.deallocate(at: Index<Slot>)`.
  `Memory.Arena.allocate(count:alignment:) -> Memory.Address?` (`Memory.Arena.swift:102`),
  `.reset()` (`:91`), no individual `deallocate`. [Verified: 2026-05-25]
- Packaging: `Memory.Pool` / `Memory.Arena` / `Memory.Buffer` are **already
  separate packages** (`swift-memory-{pool,arena,buffer}-primitives`), each
  depending back on `swift-memory-primitives` {Address, Alignment, Allocation, SLI}.
  The `memory-primitives` skill's Module Structure table is **stale** — it lists
  them as internal targets. [Verified: 2026-05-25]

## Analysis

### Three first-principles defects in the current `Memory.Allocator.Protocol`

1. **The currency is not self-describing.** `deallocate(_ address:, count:, alignment:)`
   forces the *caller* to remember size + alignment to free correctly — the C
   sized-free hazard (`free` needing the original size; `_aligned_free` needing
   alignment). Yet `Memory.Buffer.Mutable` already *is* a self-describing region.
   The protocol simply predates adopting it.
2. **The failure model is three different idioms for one operation** —
   `throws(Never)` (system), `-> Optional` (arena), `throws(Pool.Error)` (pool).
   That inconsistency cannot be unified post-hoc by a consumer; it is a contract
   defect.
3. **One protocol conflates distinct capabilities.** `Memory.Arena` cannot
   conform (no individual `deallocate`); `Memory.Pool` cannot conform (its
   currency is a slot handle, not an address). The protocol describes *only* the
   system allocator while claiming ([MEMP-003]) that "all allocation strategies
   MUST conform." The MUST is unmet and over-broad.

### Decomposing "allocation" — the axes

Allocation is **acquiring exclusive use of a memory region, and (sometimes)
reclaiming it.** Three orthogonal axes distinguish allocators:

| Axis | Values | Witnessed by |
|---|---|---|
| **Request shape** | variable (`count` + `alignment`) · fixed (nullary; size is an allocator property) | system/arena variable; pool fixed |
| **Reclamation discipline** | individual free · scoped/bulk (no individual free) · none | system/pool individual; arena scoped |
| **Currency** | region (address + size, self-describing) · slot-handle (`Index<Slot>` resolved via `pointer(at:)`) | system/arena region; pool handle |

The decisive observation: **"allocator" is not one concept.** Byte/region
allocation, fixed-slot allocation, and scoped allocation differ on these axes.
Forcing them under one protocol (or one package) is a *false unification* — and
the codebase already demonstrates this (Pool/Arena can't conform to the
byte-allocator protocol). The correct shape is a small **capability lattice**,
mirroring how `Storage.Protocol` / `Buffer.Protocol` decompose.

### The core insight: region allocation is the primitive; the slot pool is storage-shaped

A slot pool allocates a region once (from a region allocator), then hands out
fixed-size slots within it, tracked by a free list. Its surface —
`capacity`, `pointer(at: Index<Slot>)`, occupancy — **is exactly
`Storage.Protocol` plus slot allocation.** That is *why* `Storage.Pool` exists
and is a thin typed projection of `Memory.Pool`: a slot allocator **is** "an
allocating storage." This yields the unified stack:

```
Memory.Address / Alignment / Buffer.Mutable        ← addressing + self-describing region
        │
Memory.Allocator.Protocol          allocate(Request) throws(Error) -> Region
        ├── .Freeing.Protocol      + deallocate(_ region)        → Memory.Allocator (system)
        └── .Scoped.Protocol       + reset()  (no individual free) → Memory.Arena
        │
        │  (a fixed-size free-list over a region yields…)
        ▼
Storage.Protocol                   capacity + pointer(at: Index<Element>)   ← Memory.Pool IS this shape
   Storage.Heap   = Storage over a Freeing region allocator
   Storage.Pool   = Storage over a slot free-list  (Memory.Pool)
   Storage.Arena  = Storage over a Scoped allocator (Memory.Arena)
        │
Buffer.Protocol                    count / order over Storage
```

Each layer is the one below + one new responsibility. Pool and Arena are exactly
the points where the allocation layer and the storage layer fuse.

### Options for the protocol contract

**Option A — keep the single byte-allocator protocol (status quo).**
- *Rejected.* Inert (one conformer), cannot unify Pool/Arena (proven by their
  incompatible signatures), and the [MEMP-003] MUST is structurally unmeetable.

**Option B — one base protocol with `associatedtype Request` + `associatedtype Handle`, plus `Freeing` / `Scoped` refinements.**
- The base is fully general: `allocate(_ request: Request) throws(Error) -> Handle`.
  System: `Request = {count, alignment}`, `Handle = region`. Pool: `Request = Void`,
  `Handle = Index<Slot>`. Arena: variable request, region handle + `Scoped`.
- *Advantage*: one base captures all three; currency/request differences become
  associatedtypes; reclamation differences become refinements.
- *Disadvantage*: over-generalizes. A `Handle` that is sometimes a self-describing
  region and sometimes an opaque slot index (resolved only via `pointer(at:)`)
  erases the meaningful structural difference between "the handle IS the bytes"
  (region) and "the handle is a token you indirect" (slot). Loses the
  institute's concrete-capability-protocol idiom.

**Option C — region allocation is the concrete base; slot allocation is a separate, storage-shaped family. (RECOMMENDED)**
- `Memory.Allocator.Protocol` is concretely the **raw region allocator**:
  `allocate(_ request) throws(Error) -> Region`, where `Region` is a concrete
  self-describing type (`Memory.Allocation.Block`, see below). Refinements:
  `.Freeing.Protocol` (`deallocate(_ region)`) and `.Scoped.Protocol` (`reset()`).
  System conforms base + `.Freeing`; Arena conforms base + `.Scoped`.
- **Pool is NOT a `Memory.Allocator`.** It is a `Storage.Protocol`-shaped slot
  pool plus a slot-allocation capability (`allocateSlot()` / `deallocate(at:)`),
  internally *built on* a region allocator. This is the formal statement of the
  Pool ≅ Storage symmetry above, and of why `Storage.Pool` is its typed projection.
- *Advantage*: each allocator conforms to exactly its real capabilities;
  generic code constrains to the capability it needs (`some …Scoped.Protocol`);
  the region/slot distinction is honored, not erased; matches `Storage.Protocol`
  capability-protocol style.
- *Disadvantage*: two families (region allocators + storage-shaped slot pools)
  rather than one mega-protocol — but this reflects reality, not accidental
  fragmentation.

#### Comparison

| Criterion | A (status quo) | B (general assoc) | C (region base + slot family) |
|---|---|---|---|
| Pool conforms cleanly | no | yes (as `Handle = Index<Slot>`) | n/a — Pool is storage-shaped by design |
| Arena conforms cleanly | no | yes (+ Scoped) | yes (base + Scoped) |
| Region/slot distinction | n/a | **erased** into one `Handle` | **honored** (region vs storage-shaped) |
| Self-describing currency | no | depends on Handle | yes (concrete `Block`) |
| Failure model unified | no | yes | yes |
| Matches `Storage.Protocol` idiom | no | partially | **yes** |
| [MEMP-003] meetable | no | yes (over-broad) | yes (narrowed to region allocators) |

### Currency decision: a self-describing region

The allocate/deallocate currency should carry everything needed to *reverse* the
allocation, so `deallocate` cannot be called with a mismatched size/alignment.

- **`Memory.Buffer.Mutable`** (`{start, count}`) already exists and is the natural
  region descriptor — but it carries no **alignment**, which cross-platform
  sized-aligned free (Windows `_aligned_free`) needs.
- **`Memory.Allocation.Block`** (proposed) = `{ region: Memory.Buffer.Mutable; alignment: Memory.Alignment }`.
  This finally gives the `Memory.Allocation` namespace (today only a `Granularity`
  typealias) real load, and makes every reclamation carry full information.
- **Request** should likewise be bundled: `Memory.Allocation.Request { count, alignment }`,
  so the surface is evergreen (zeroed / hugepage hints can be added without
  signature churn). Symmetric: `Memory.Allocation.Request` in → `Memory.Allocation.Block` out.

*Recommendation*: `Memory.Allocation.Block` as the currency (carries alignment);
`Memory.Allocation.Request` as the request.

### Failure model: unify on typed throws

One idiom: `associatedtype Error: Swift.Error` + `… throws(Error) -> …`. System
uses `Error == Never` (expresses infallibility precisely — malloc traps on OOM).
Arena's `-> Optional` becomes `throws(Arena.Error)`. Pool keeps `throws(Pool.Error)`.
This composes with the typed-throws discipline ([API-ERR-001]) and lets generic
code reason uniformly about allocation failure.

### Design sketch (Option C)

Institute hoisted-protocol style (module-scope `__…Protocol` aliased into the
namespace); `~Copyable`; typed throws. Shown logically:

```swift
// base: region allocation
Memory.Allocator.`Protocol`:  ~Copyable
    associatedtype Error: Swift.Error
    mutating func allocate(_ request: Memory.Allocation.Request) throws(Error) -> Memory.Allocation.Block

// refinement: individual reclamation
Memory.Allocator.Freeing.`Protocol`: Memory.Allocator.`Protocol`
    mutating func deallocate(_ block: Memory.Allocation.Block)          // System

// refinement: scoped/bulk reclamation, no individual free
Memory.Allocator.Scoped.`Protocol`:  Memory.Allocator.`Protocol`
    mutating func reset()                                              // Arena
```

`Memory.Pool` conforms to `Storage.Protocol` (it already has `capacity` +
`pointer(at:)`) plus a slot-allocation capability — NOT to `Memory.Allocator.Protocol`.

### Prior art survey ([RES-021])

> External claims below are **from training knowledge**; primary-source
> verification is deferred to the Tier-3 SLR and the `/collaborative-discussion`
> pass (which is itself a cross-model verification of these shapes).

- **Rust** — `core::alloc::GlobalAlloc` / `Allocator`: `alloc(Layout) -> *mut u8`,
  `dealloc(ptr, Layout)`. `Layout` (size + align) is the self-describing currency
  passed *back* to `dealloc` — exactly the "self-describing region" fix. Arena
  crates (`bumpalo`) deliberately do not implement a meaningful per-allocation
  free (scoped/bulk reclaim).
- **C++** — `std::pmr::memory_resource`: `do_allocate(bytes, align)` /
  `do_deallocate(p, bytes, align)` — again size+align handed back to deallocate.
  `std::pmr::monotonic_buffer_resource` is the arena: `do_deallocate` is a no-op
  (scoped reclaim on destruction).
- **Zig** — `std.mem.Allocator` (vtable: `alloc` / `resize` / `free`), where
  `free` takes the original byte slice back (self-describing). `ArenaAllocator`
  wraps a child allocator and frees in bulk (`deinit`); per-allocation `free` is a
  no-op.

**Contextualization step ([RES-021])**: the cross-system consensus is threefold —
(a) a **self-describing currency** (Layout / byte-slice / size+align) is passed
back to free; (b) an **arena is an allocator whose individual-free is a no-op /
absent** (scoped reclamation as a discipline, not a separate concept); (c) the
allocator is **one trait, with reclamation as the varying part**. Our ecosystem's
divergences (non-self-describing `deallocate`, inert protocol, three failure
idioms) are NOT a deliberate design — the principal has confirmed the protocol
"wasn't put a lot of thought in at the time." So the prior-art consensus maps
cleanly onto our type system as: `Memory.Allocation.Block` (self-describing
currency) + `Scoped` refinement (arena-as-no-op-free, but expressed as a *typed
capability* rather than a silently-no-op method — a strict improvement over the
surveyed systems) + typed-throws unification. The one place we *should* diverge
from the consensus's "one trait": the region/slot split (Option C), because our
typed `Index<Slot>` + `pointer(at:)` slot model is genuinely storage-shaped,
whereas the surveyed systems express pools as just another byte-allocator.

### The Heap fork (open decision)

To make the substrate fully uniform, `Storage.Heap` would acquire its bytes from
a `Memory.Allocator.Freeing.Protocol` (default: system) instead of hardcoding
stdlib `ManagedBuffer` (`Storage.Heap.swift:102`). The tension is real and
permanent:

- `ManagedBuffer` fuses the refcount header + element storage into **one**
  allocation (the default Heap's efficiency).
- An allocator-parameterized Heap holds a `Memory.Allocation.Block` in its CoW
  backing class → **two** allocations (class box + region) unless it reimplements
  tail allocation. The allocator (bytes) and the CoW class (refcount identity)
  are orthogonal, so both can coexist — at the cost of the extra indirection.

This is a genuine fork (uniformity vs single-allocation), surfaced here for the
convergence pass, not resolved.

## Outcome

**Status: DECISION** — converged 2026-05-25 via `/collaborative-discussion` (Claude × ChatGPT,
6 rounds) + three binding principal refinements; see the **Converged Plan** below. Tier-3
formalization ([RES-024] formal semantics, [RES-023] SLR) remains deferred.

> Note: the recommendation text and D1–D4 table below are preserved as the **pre-convergence
> record** per [RES-008]. The Converged Plan supersedes them where they differ (see *Divergences*).

Two structural calls are **recommended**:

1. **Region allocation is THE allocation primitive.** `Memory.Allocator.Protocol`
   is the region-allocator contract; `Memory.Pool` is reframed as a
   `Storage.Protocol`-shaped slot pool (NOT a `Memory.Allocator`). This formalizes
   the Pool ≅ Storage symmetry and explains `Storage.Pool`.
2. **A self-describing currency + a capability lattice + a unified failure model.**
   `Memory.Allocation.Block` (region + alignment) as the allocate/deallocate
   currency; `Memory.Allocator.Protocol` base with `.Freeing` / `.Scoped`
   refinements; typed throws with `associatedtype Error` (`Never` for the system
   allocator).

**Open decisions for the convergence pass:**

| ID | Decision | Recommendation |
|---|---|---|
| D1 | Option B (general `associatedtype Handle`) vs Option C (concrete region base + separate slot family) | **C** |
| D2 | Currency = `Memory.Buffer.Mutable` vs `Memory.Allocation.Block` | **Block** (carries alignment) |
| D3 | Heap fork — allocator-parameterized vs `ManagedBuffer`-default | open |
| D4 | Packaging — extract `Memory Allocation` into `swift-memory-allocation-primitives`? | downstream of the contract; defer |

**Non-goals / settled**: no new "allocator" package that re-bundles Pool + Arena
(it would coarsen the already-separate per-namespace packages, against [MEMP-002]);
no freestanding (memory-dependency-free) allocator (the vocabulary *is*
`Memory.Address` / `Alignment` / `Count`). `Memory.Pool`'s in-band free-list
representation is settled and out of scope (`pool-free-list-representation.md`,
DECISION). [MEMP-003] is restated as a defect to repair (narrow to region
allocators, fix the stale module/signature).

## Converged Plan

### Summary

Converged via `/collaborative-discussion` (Claude × ChatGPT, 6 rounds, both CONVERGED) plus
three binding principal refinements. The substrate settles on a **single self-describing
currency** (`Memory.Allocation.Request` → `Memory.Allocation.Block`, where `Block` carries a
non-owning `Memory.Allocation.Region` + `alignment`) and a **single individually-freeing
region-allocator protocol** (`Memory.Allocator.Protocol` = `allocate` + `deallocate`). Scoped
(arena) and slot (pool) allocation are **concrete sibling disciplines, not protocol conformers**.
The concrete system allocator is **L2-provided** (`Memory.Allocator.system`, no public type).
This refines the Option-C recommendation above in three ways (see *Divergences*).

### Final contract (L1 + L2)

```swift
// ── L1: swift-memory-primitives, target "Memory Allocation Primitives" ──
extension Memory.Allocation {
    public struct Region {              // NEW — non-owning geometry only (C12)
        public let start: Memory.Address
        public let count: Memory.Address.Count
    }
    public struct Block {               // NEW — the allocate/deallocate currency
        public let region: Memory.Allocation.Region
        public let alignment: Memory.Alignment
    }
    public struct Request {             // NEW — symmetric input
        public let count: Memory.Address.Count
        public let alignment: Memory.Alignment
    }
    // existing: Granularity, Error(.exhausted)
}

extension Memory.Allocator {            // Memory.Allocator is the namespace (enum)
    public protocol `Protocol`: ~Copyable {
        associatedtype Error: Swift.Error
        mutating func allocate(_ request: Memory.Allocation.Request) throws(Error) -> Memory.Allocation.Block
        mutating func deallocate(_ block: Memory.Allocation.Block)
    }
}
// `associatedtype Error` lets each conformer choose its failure model:
// `Never` for a trapping allocator, `Memory.Allocation.Error` for a fallible one.

// ── L2: per spec authority (POSIX swift-ieee-1003 / Windows swift-windows-standard /
//        Darwin swift-darwin-standard) — provided BY EXTENSION ──
extension Memory.Allocator {
    // platform malloc/free witnesses on a PRIVATE concrete conformer;
    // NO public `Memory.Allocator.System` type (C15 / P20 / C17).
    public static var system: some Memory.Allocator.`Protocol` { /* platform-backed */ }
}
```

**Scoped & slot disciplines are concrete siblings — they do NOT conform** to
`Memory.Allocator.Protocol` (their reclamation discipline and currency are structurally
incompatible with individually-freeing region allocation):

- `Memory.Arena` (scoped/bulk): `allocate(_:) -> Memory.Allocation.Block?` (bump; MAY move to
  `throws(Memory.Arena.Error)`) + `reset()` (bulk; `deinit` frees backing). No individual
  `deallocate`. Used concretely.
- `Memory.Pool` (raw slot substrate): `allocateSlot() -> Index<Slot>` / `deallocate(at:)` /
  `pointer(at:) -> UnsafeMutableRawPointer` (raw). `Storage.Pool<Element>` (separate package) is
  its typed `Storage.Protocol` projection (verified: composes `Memory.Pool` in a CoW class).

`Memory.Allocation.{Region, Block, Request}` are shared value-type vocabulary that arena/pool MAY
use even without conforming to the protocol.

### Decision register

| ID | Decision | Outcome |
|---|---|---|
| D1 | Allocator-contract shape | **Single `Memory.Allocator.Protocol` (allocate + deallocate).** Region allocation with individual free IS the contract. Arena (scoped) and Pool (slot) are concrete non-conforming siblings. Supersedes the Option-C `Freeing`/`Scoped` lattice (principal, 2026-05-25). |
| D2 | Self-describing currency | **`Memory.Allocation.Block { region: Memory.Allocation.Region; alignment }`** + symmetric `Request { count, alignment }`. `Block` does NOT compose `Memory.Buffer.Mutable` (verified package cycle); a new `Memory.Allocation.Region` is pulled down to the allocation tier and `Memory.Buffer.Mutable` is later re-expressed as a byte-access view over it. |
| D3 | Heap allocator-parameterization | **Defer.** Keep `Storage.Heap` single-allocation (`ManagedBuffer`/stdlib). The fork is an artifact of class-based CoW; the future allocator-aware Heap is a native Memory-tier tail-allocated, manual-refcount, allocator-injected primitive ([DS-022]) — single-allocation AND allocator-aware (Rust `RcBox` / C++ `allocate_shared` shape). Reinforced by D-system: L1 storage cannot depend on the L2 system allocator ([ARCH-LAYER-001]), so an allocator-aware Heap is generic over `some Memory.Allocator.Protocol` (now able to free) or deferred. |
| D4 | Packaging | **Defer.** `Memory.Allocation` is a target in swift-memory-primitives; extraction to `swift-memory-allocation-primitives` is [MEMP-002]-consistent but downstream of the contract. |
| D-system | System-allocator placement | **L2, accessor, no public type** (principal, binding). `Memory.Allocator.system` via platform-package extension; concrete conformer is private. Mirrors the existing `Memory.Allocation.system` / `Memory.Allocation.Error.init?(code:)` / `Darwin.Memory.Allocation.Statistics` / `System.Memory` L2-provisioning pattern. [ARCH-LAYER-003], [PKG-NAME-011]. |
| D-resize | Resizing capability | **Defer** as a documented future axis. When added: byte-preserving Memory-tier resizing (realloc/mremap shape); element-preserving growth is a Storage-tier concern. |

### Divergences from the original recommendation (preserved per [RES-008])

1. **D1 Option-C lattice → single protocol.** The recommended base + `Freeing` + `Scoped`
   refinement protocols are replaced by ONE `Memory.Allocator.Protocol` (allocate + deallocate);
   arena/pool become concrete non-conforming siblings rather than `Scoped`/storage-shaped
   conformers. This resolves [MEMP-003]'s over-broad "all strategies MUST conform" by *narrowing*
   the protocol to individually-freeing region allocators, and aligns with the prior-art
   "one interface" consensus (Zig/Rust/C++). (Principal, 2026-05-25; ChatGPT had converged on the
   lattice at Round 6.)
2. **Currency geometry → new `Memory.Allocation.Region`, not `Memory.Buffer.Mutable`.** Composing
   `Memory.Buffer.Mutable` would invert the `swift-memory-primitives` ⇄
   `swift-memory-buffer-primitives` dependency (verified package cycle). (Claude C11; ChatGPT +
   principal accepted.)
3. **Concrete system allocator → L2 (`Memory.Allocator.system`, no public type)**, not an L1
   `Memory.Allocator.System`. (Principal, binding.)

### Open implementation sub-decisions (do not change the contract; resolve at implementation)

- **`Memory.Allocator` host shape** — most naturally a caseless-`enum` namespace (hosts
  `.Protocol` + the L2 `.system` accessor; the concrete conformer is a private L2 type).
  Recommended; confirm.
- **L1 default conformer for Embedded / no-platform builds** — whether L1 also ships a
  stdlib-backed conformer (`throws(Never)`, over `UnsafeMutableRawPointer.allocate`/`.deallocate`)
  so Embedded targets that import no platform package still have a `Memory.Allocator.Protocol`
  value, or L1 exposes only the protocol + concrete `Memory.Arena`/`Memory.Pool` with the system
  allocator strictly L2.
- **`Memory.Arena` reset surface** — `arena.reset()` directly (single-form per [API-NAME-008]) vs
  an `arena.scoped` Property.View (only if multiple scoped ops, e.g. + checkpoint, materialize).
- **System-allocator failure model** — `throws(Never)` (trap) vs `throws(Memory.Allocation.Error)`
  (fallible; errno / GetLastError) per platform conformer.

### Action items (follow-ups — NOT performed in this design-only pass)

- [ ] **Skill [MEMP-003] restatement** (via skill-lifecycle): narrow to "`Memory.Allocator.Protocol`
  is the individually-freeing region-allocator contract (allocate + deallocate over
  `Memory.Allocation.Block`); scoped (arena) and slot (pool) disciplines are concrete siblings that
  do not conform." Fix the stale module location (skill says "Memory Buffer Primitives"; actual is
  "Memory Allocation Primitives") and the stale `deallocate(_ address:)` signature (actual:
  `deallocate(_:count:alignment:)`, to become `deallocate(_ block: Memory.Allocation.Block)`).
- [ ] **Fix the stale POSIX-package comment** in `Memory.Allocation.swift` (and `.Error.swift`):
  `swift-iso-9945` → `swift-ieee-1003`.
- [ ] **Implement** (separate, authorized pass): the `Region`/`Block`/`Request` types; update
  `Memory.Allocator.Protocol` (add `deallocate(Block)`, `allocate(Request) -> Block`); L2
  `Memory.Allocator.system` extension(s); re-express `Memory.Buffer.Mutable` over `Region`; arena
  `allocate -> Block?` / `throws`.
- [ ] **Tier-3 formalization** — formal semantics ([RES-024]) + SLR ([RES-023]) remain deferred.

### Agreed by

- **Claude** — Rounds 1, 3, 5 (+ this synthesis). Verified all signatures against source; caught
  the `Block`/`Buffer.Mutable` package cycle (C11) and confirmed the `Storage.Pool`-wraps-`Memory.Pool`
  relationship.
- **ChatGPT** — Round 6 CONVERGED on the contract (D1–D4 + currency + L2 system placement). The
  single-protocol capability shape was decided by the principal *after* Round 6 and is consistent
  with the prior-art one-interface consensus ChatGPT itself cited (Q1/Q8 answers).
- **Principal** — three binding refinements (L2 system placement; `.system` accessor / no public
  type; single allocator protocol with `deallocate` in the base) + the final capability-shape
  decision, 2026-05-25.

Transcript: `/tmp/allocation-substrate-transcript.md`.

## References

- Prior art (internal, this package): `pool-free-list-representation.md` (DECISION
  — Pool's in-band typed-sentinel free list; sits one level *below* this doc's
  allocator-contract topic); `memory-address-mutability.md` (`Memory.Address` =
  position-only); `contiguous-memory-access-standardization.md` (`Span.Protocol`).
- Storage arc: `swift-storage-primitives/Research/storage-protocol-capacity-pilot.md`;
  `swift-buffer-primitives/Research/storage-generic-buffer-core.md` (Lever-1).
- Source (verified 2026-05-25): `Memory.Allocator.Protocol.swift:23-49`;
  `Memory.Allocator.swift:14-36`; `Memory.Buffer.Mutable.swift:61-151`;
  `Memory.Arena.swift:91,102`; `Memory.Pool.swift:238,299`;
  `Storage.Protocol.swift:20-37`; `Span.Protocol.swift`.
- Skill rules: [MEMP-003] (Allocator Protocol — to be repaired), [MEMP-002]
  (namespace-axis decomposition), [API-ERR-001] (typed throws), [API-NAME-001]
  (Nest.Name), [RES-018] case (b), `feedback_correctness_and_evergreen`.
- External (from training knowledge; primary-source verification deferred):
  Rust `core::alloc::{GlobalAlloc, Allocator}` + `Layout`; C++
  `std::pmr::memory_resource` + `monotonic_buffer_resource`; Zig `std.mem.Allocator`
  + `ArenaAllocator`.
