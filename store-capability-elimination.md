# Eliminating Store.Creatable + Store.Tracked via Memory Decomposition

<!--
---
version: 1.0.0
last_updated: 2026-06-05
status: RECOMMENDATION (elimination; gated on the post-Cleave-4 Memory-leaf decomposition)
tier: 2
type: investigation/architecture
scope: ecosystem-wide (store + memory + storage tower)
supersedes_partially: the prior "keep" verdict for Store.Creatable / Store.Tracked in the capability-protocol decompose/compose scoping
depends_on:
  - swift-institute/Research/storage-memory-split.md (the #3 split that created the Memory leaves)
provenance: wart-investigation (read-only probes, receipts in .probe-bank/prism-wart/); seat-accepted + filing-authorized by the principal 2026-06-05
-->

**Coen ten Thije Boonkkamp · Swift Institute · June 2026**

## Abstract

A prior scoping judged `Store.Creatable` (allocation/relocation) and `Store.Tracked` (the initialization ledger) *load-bearing* and kept them. That verdict was against the **current fused** storage structure. Against the **post-Cleave-4 memory-decomposed** structure — type-distinct `Memory.Heap` (ARC-allocating) and `Memory.Inline` (in-place, non-allocating) leaves under `Storage.Contiguous<M>` — both protocols are **eliminable at the store tier**: their capabilities relocate to the memory layer, where allocation and relocation become **compile-time type-selection** and the ledger becomes a **`Memory.Heap`-private** record. The one irreducible residue is the ledger *concept* for ARC-backed `~Copyable` memory (leak-freedom), which lives privately in the leaf, not as a universal store protocol.

## Why the fused structure created the warts

`Store.Creatable`/`Store.Tracked` are store-tier protocols generic over **all** storages — contiguous and non-contiguous, allocating and inline. That breadth *forces*: (a) a runtime bulk-vs-elementwise relocation **override** (a generic over the broad protocol loses the bulk path); (b) a universal ledger requirement even on stores that don't allocate or track; (c) a non-allocating leaf (`Inline`) awkwardly *not* conforming to a "creatable" store. Decomposing the memory tier into **distinct leaf types** removes the breadth — and with it, the warts.

## Findings (Apple Swift 6.3.2; receipts in `prism-wart/receipts/`)

1. **Allocation → memory leaf, type-selected (ELIMINABLE).** `Memory.Heap.create` allocates; `Memory.Inline` has none (the tell). Growable disciplines gate on a tiny memory-level marker (`Allocating`, or the existing `Memory.Allocator.Protocol`). `Linear<MemHeap>` and `Linear<MemArena>` grow via one generic at **0 witness**; `Linear<MemInline>` is unrepresentable (correct). No store-tier `Store.Creatable`.
2. **Relocation → `where M: ContiguousMem` (ELIMINABLE; overturns the prior "irreducible").** The bulk override is lost only through a *broad* generic; a generic constrained to **contiguous** memory (which the contiguous disciplines are) **statically selects** the bulk path. Receipt: broad → "elementwise", contiguous-constrained → "BULK". No requirement.
3. **Ledger → `Memory.Heap`-private (ELIMINABLE as a universal protocol; IRREDUCIBLE as a concept).** The ledger exists because `Memory.Heap`'s ARC `deinit` fires automatically with the discipline header unreachable. A leaf-internal liveCount (maintained by the leaf's own ops, read by its `deinit`) tears down `~Copyable` elements with **no `Store.Tracked` requirement and no discipline sync** (`Tracked.live = 0`). Removing the record entirely **leaks** (`Tracked.live = 5`) — the hard floor (leak-freedom). `Memory.Inline`/`Memory.Contiguous` need no ledger at all.

## The principle (extends the Cleave-5 decompose/compose rule)

A store-tier capability protocol is a **wart** when the *need* it encodes is really a **property of a specific memory leaf**, not of all stores. Decomposing the leaf into distinct types converts:
- a runtime **override** → compile-time **type-selection** (constrain the generic to the narrow capability),
- a universal **stored requirement** → a **leaf-private** record (the leaf maintains and consumes it),
- an awkward **non-conformance** → an honest **absence** (the inline leaf simply lacks the capability).

The hard floor is unchanged correctness: **leak-freedom** for ARC-backed `~Copyable` memory keeps a live-extent record — but privately, in the leaf.

## Revised Cleave-5 plan (for these two)
1. Eliminate `Store.Creatable` → memory-level `Allocating` marker / `Memory.Allocator.Protocol`; relocation as `where M: ContiguousMem`.
2. Eliminate `Store.Tracked` → `Memory.Heap`-private ledger (count for contiguous); non-ARC leaves carry none.
3. Keep `Store.Protocol` (4-op), `Span.Protocol`; the single-region `Storage.Protocol` marker dissolves (`Storage.Contiguous<M>` is single-region by construction).
4. Gated on the Memory-leaf decomposition landing (Cleave-4 E4 + split).

## Flagged for real-structure validation
- Ring (wrapped, range-set) / Split (sparse) ledger — not [0,count); confirm leaf-private range-set vs a narrow discipline path (still not universal `Store.Tracked`).
- Exact count of ARC-backed allocating leaves (Heap/Arena/Pool/Slab) → marker shape.
- CoW (`ensureUnique` deep-copy) reads the ledger — confirm the leaf-private record serves CoW as well as deinit.
- Re-gate 0-witness on the real leaves at implementation (standing Phase-3 SIL recheck).

## References
- `prism-cleave5/` (the uniform-vs-override rule; the prior "keep" this supersedes for Creatable/Tracked).
- `prism/findings.md` (default-CMO specialization methodology).
- `Memory.Heap.swift` (ARC façade + the `deinit` cleanup oracle); `Memory.Inline.swift` (caller-managed, no tracking); `Memory.Allocator.Protocol.swift` (memory-layer allocation home); `swift-institute/Research/storage-memory-split.md` (the #3 split that created the leaves).
