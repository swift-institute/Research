# Buffer-Namespace Membership: Occupancy Disciplines vs Raw Byte Regions

<!--
---
version: 1.2.0
last_updated: 2026-06-03
status: RECOMMENDATION
tier: 2
scope: cross-layer
changelog:
  - "1.2.0 (2026-06-03): CORRECTION (Buffer.Slots ONLY). The §3.3 / Outcome verdict `Buffer.Slots → Storage` is SUPERSEDED — the GAP-O Q2 fold executing it was a regression, reversed 2026-06-03. Q2 = KEEP `Buffer.Slots` in `Buffer.*` (Hash.Table → Buffer.Slots → Storage.Split, no bypass) per hash-table-storage-buffer-layering.md v3.0.0 (DECISION, normative) + metadata-parametric-slots.md v2.0.0 (DECISION). The occupancy-classification test (§1) mis-fires for Slots: it is a metadata-parametric buffer discipline (peer of Linear/Ring/Slab) whose occupancy is consumer-managed BY DESIGN (locked R4), not a degenerate pass-through (it carries CoW + predicate-deinit that Storage.Split does not). Aligned/Unbounded → Memory (§3.1/§3.2) UNAFFECTED. Emptied/deletable pkgs 3 → 2 (aligned+unbounded; slots STAYS). The Memory/Storage/Buffer boundary-definition consolidation remains the open Class-(c) item."
  - "1.1.0 (2026-06-02): [RES-023] CORRECTION, caught on independent resume-verification. §3.1's v1.0.0 claim 'Memory.Aligned name is free (verified: no existing Memory.Aligned)' was FALSE — `Memory.Aligned` is an existing `public protocol` (swift-memory-primitives/Sources/Memory Alignment Primitives/Memory.Aligned.swift:33 — `extension Memory { public protocol Aligned { static var alignment: Memory.Alignment { get } } }`), catalogued in the memory-primitives skill Type Hierarchy as `.Aligned (wrapper)`, currently ZERO conformers. A concrete `struct Memory.Aligned` would collide; the §3.2 `Memory.Aligned.Resizable` candidate is also dead (cannot nest a type inside a protocol). The VERDICT (Aligned/Unbounded → Memory; Slots → Storage.Split) is UNCHANGED; sub-decisions (a)/(c) reframed — the relocated region CONFORMS to the existing `Memory.Aligned` protocol (its first consumer) under a non-colliding name + its own namespace-axis target per [MEMP-002]. `Memory.Unbounded` (sibling) remains free. The count≡capacity classification (Unbounded :102-110 byte-identical; 5 stayers count≠capacity) and 0/1/1 blast radius were re-verified on disk and HOLD."
  - "1.0.0 (2026-06-02): Initial RECOMMENDATION (GAP-O Tier-2 investigation)."
applies_to:
  - swift-buffer-primitives
  - swift-buffer-aligned-primitives
  - swift-buffer-unbounded-primitives
  - swift-buffer-slots-primitives
  - swift-memory-primitives
  - swift-memory-buffer-primitives
  - swift-storage-split-primitives
normative: false
---
-->

> **⚠️ CORRECTION (2026-06-03) — the `Buffer.Slots` verdict is REVERSED; the rest of this note STANDS.**
>
> The §3.3 / §Outcome recommendation to relocate **`Buffer.Slots` → Storage** is **SUPERSEDED**. The GAP-O "Q2" fold that executed it (Hash.Table re-pointed directly onto `Storage<Int>.Split<Int>`; `Buffer.Slots` emptied to a shell) was a **regression** and was reversed 2026-06-03. **Q2 disposition: KEEP `Buffer.Slots` in `Buffer.*`** — the researched layering is `Hash.Table → Buffer.Slots → Storage.Split` (no bypass).
>
> **The occupancy-classification test (§1) mis-fires for `Buffer.Slots`.** "Tracks no occupancy" does **not** disqualify a buffer. `Buffer.Slots` is a genuine **metadata-parametric** buffer discipline — a peer of Linear/Ring/Slab — whose discipline is random-access slots with a per-slot metadata lane, and which **deliberately** delegates occupancy to the consumer through that lane (its locked requirement **R4**). It is **not** a degenerate pass-through over `Storage.Split`: it carries the buffer-level discipline `Storage.Split` does **not** — copy-on-write (`ensureUnique()` / `ensureUnique(where:)`) and predicate `deinitialize(where:)`. The fold "worked" only by smuggling that discipline **down** into `Storage.Split` (which by [DS-005] tracks no lifecycle), the symptom of layer-boundary overreach, not validation. So the §1 test is correct for raw byte/slot *regions* (Aligned/Unbounded) but must not be read as "a buffer that delegates occupancy isn't a buffer."
>
> **Governing research (cite, do not re-derive — [RES-019]):** `swift-hash-table-primitives/Research/hash-table-storage-buffer-layering.md` **v3.0.0** (DECISION, normative — records the occupancy-premise refutation) and `swift-buffer-primitives/Research/metadata-parametric-slots.md` **v2.0.0** (DECISION — `Buffer.Slots` peer discipline; Outcome #8 *"Hash.Table → Buffer.Slots → Storage.Split — no bypass"*). Both were converged research on disk **before** the fold; the fold contradicted them (root cause: the [RES-019] prior-research grep was skipped until late).
>
> **Scope of this correction:** ONLY the `Buffer.Slots` row. **`Buffer.Aligned` / `Buffer.Unbounded` → Memory (§3.1, §3.2) are UNAFFECTED** and remain the recommendation (HELD pending the Memory dispatch + boundary work). **Emptied/deletable packages therefore drop from 3 to 2** (aligned + unbounded; `swift-buffer-slots-primitives` **stays**). The deeper question — whether `Storage.Split` should slim to a **Memory-tier** SoA region with `Buffer.Slots` carrying the full discipline (the Memory/Storage/Buffer **boundary-definition consolidation**) — is the open **Class-(c)** item for principal `/goal` dispatch.

## Context

**Trigger.** GAP-O in `derive-for-free-capability-composition.md` (the
capability-composition framework doc; co-architect-owned — this note is the
*separate* Tier-2 investigation GAP-O asked for, not an edit to that doc).
GAP-O was surfaced by the GAP-N spike: while testing whether a universal
`{capacity, isFull, availableCapacity}` surface could fold into the single
`Buffer.\`Protocol\``, the spike found the surface **vacuous** for two
`Buffer.*` members — `Buffer.Aligned` and `Buffer.Unbounded` — whose `count`
≡ `capacity`. Those two track *allocation*, not *occupancy*, so `isFull` is
always-true and `availableCapacity` always-zero (inverted for a resizable
buffer). The root cause GAP-N diagnosed: `count` means **occupancy** on the
five genuine disciplines (Arena/Linear/Linked/Ring/Slab) but **allocation
size** on the two byte buffers; `{count, isEmpty}` tolerates the conflation,
`{capacity, isFull}` exposes it.

**Principal framing (2026-06-02, two directives that govern this note).**

1. *"Buffer should be the logical layer over physical storage primitives."*
2. *"You cannot ignore the storage primitives packages."*

These two directives ARE the classification axis. Directive (1) fixes Buffer as
the **logical** layer (occupancy semantics). Directive (2) fixes the **physical**
layer beneath it as a two-tier stack — **Storage** (typed slot regions with
element-lifecycle tracking) over **Memory** (raw byte allocation) — and requires
the membership analysis to place each misclassified member into the *correct*
physical package, not lump everything at "Memory."

**Governing internal model ([RES-019]).** `cross-layer-capability-protocol-model.md`
(v1.1.0, **APPROVED 2026-05-28**, Tier 3) already separates these axes
ecosystem-wide:

| Capability protocol | Package | Identity | Surface |
|---|---|---|---|
| `Span.\`Protocol\`` | swift-span-primitives | physical contiguous **read** | `span` + unsafe escape (model §3, line 51) |
| `Storage.\`Protocol\`` | swift-storage-primitives | physical **slot-access** | `pointer(at:)`, `capacity` |
| `Buffer.\`Protocol\`` | swift-buffer-primitives | logical **occupancy** | `count` + `isEmpty` (model §3, line 53) |

The model states verbatim that `Buffer.\`Protocol\`` *"Does NOT refine
`Storage.Protocol` (has-a) nor `Iterable` (orthogonal)"* and that `span` stays on
the contiguous-read capability — at the time `Memory.Contiguous.Protocol`, since lifted
out to the namespace-neutral `Span.Protocol` — for contiguous variants (§3.4, lines 200-203).
A buffer **has-a** storage; it is not a *kind-of* storage. This note applies that
already-approved logical/physical split to the *membership* of the `Buffer.*`
namespace — the dual of the protocol-shape question the model answered.

**Constraints.** Research-only; DESIGN / RATIONALE ONLY — no package edits, no
relocation, no protocol changes. This is a class-(c) cross-layer-relocation
decision: this note **recommends**; the principal **decides**. Tier 2 per
[RES-020] (cross-package / cross-layer; precedent-shaping for layer-membership
but reversible). Every empirical claim verified on disk 2026-06-02 per [RES-023];
the prior brief's "Binary.Cursor uses Unbounded" claim was **refuted** on disk
(see §4).

---

## Question

Which members of the `Buffer.*` namespace are genuine **occupancy disciplines**
(a logical layer tracking occupancy distinct from allocation over a physical
storage), and which are **raw byte regions** or **raw slot regions** that belong
at the physical layer (Memory or Storage) instead? Specifically: should
`Buffer.Aligned`, `Buffer.Unbounded`, and `Buffer.Slots` be reclassified OUT of
`Buffer.*`, and if so, to which physical package?

---

## 1. The classification test

A member of the logical `Buffer.*` namespace MUST be an **occupancy discipline**:
it tracks **occupancy** (`count` — "how full") as a quantity **distinct from
allocation** (`capacity` — "how big"), over a physical storage it *has-a*. The
test, stated as a decision procedure on a candidate type `T`:

| Property | Occupancy discipline (Buffer) | Raw region (Memory) | Raw slots (Storage) |
|---|---|---|---|
| `count` exists and means **occupancy** | **Yes** — `count` is a separate stored/computed quantity ("elements held") | No — `count` ≡ allocated size, or absent | No logical `count` at all |
| `count` vs `capacity` | `count ≠ capacity` (count ≤ capacity; the gap IS the buffer's identity) | `count ≡ capacity` (one number: allocated bytes) | `capacity` only; occupancy is consumer-managed |
| element-lifecycle ownership | discipline tracks init/occupied ranges or bitmaps | none (raw bytes; `BitwiseCopyable`) | none (consumer manages; "no element deinit") |
| physical substrate it has-a | a `Storage.*` primitive | a `Memory.*` region (no Storage) | IS a `Storage.*` primitive + thin header |

**The decisive predicate** is the middle row: *does `count` track something
distinct from `capacity`?* If the type's `count` and `capacity` are the same
number (byte-identical expression, or `count` is simply "allocated size"), the
type has **no occupancy state** and is therefore physical, not logical — it fails
Buffer membership regardless of which namespace it currently lives in.

This is a **membership / placement** question, so per [RES-029] it is driven on
**semantic identity first** (IS-A occupancy-discipline / NOT-A), with operational
behavior of adjacent ecosystem types as the empirical anchor; consumer-count is a
tiebreaker only. Consistent with [ARCH-LAYER-006] / [ARCH-LAYER-008]: the
disposition is **correctness/identity-driven, not adoption-driven** (the near-zero
adoption found in §4 is corroborating, not load-bearing).

---

## 2. Inventory — every `Buffer.*` member classified (file:line, verified 2026-06-02)

### 2a. The 18 `Buffer.\`Protocol\`` conformers

Grep `extension … : Buffer.\`Protocol\`` across swift-primitives / swift-standards
/ swift-foundations returns exactly 18 conformers in 7 packages:

| # | Conformer | `count` definition (file:line) | `count` vs `capacity` | Verdict |
|---|---|---|---|---|
| 1 | `Buffer.Linear` | `header.count` (Buffer.Linear+Lifecycle.swift:26); capacity `:30` `header.capacity`; Header field Buffer.Linear.Header.swift:26 | **distinct** (occupancy stored in header) | **Occupancy — STAY** |
| 2 | `Buffer.Ring` (+ Bounded/Inline/Small) | `header.count` (Buffer.Ring+Operations.swift:24); capacity `:28`; Header field Buffer.Ring.Header.swift:22 | **distinct** | **Occupancy — STAY** |
| 3 | `Buffer.Slab` (+ Bounded/Inline/Small) | `occupancy` in `Bit.Index.Count` (Buffer.Slab+Operations.swift:32); capacity Buffer.Slab+Subscript.swift:21 | **distinct** (popcount of occupied bitmap slots ≠ total slots; sparse `Count` domain) | **Occupancy — STAY** |
| 4 | `Buffer.Arena` (+ Bounded/Inline/Small) | `occupied` (Buffer.Arena ~Copyable.swift:32); capacity Buffer.Arena.Header.swift:30 | **distinct** | **Occupancy — STAY** |
| 5 | `Buffer.Linked` (+ Inline/Small) | `header.count.retag(Element.self)` (Buffer.Linked ~Copyable.swift:68); capacity `:76` `storage.capacity` in `Index<Node>.Count` | **distinct** (occupancy element-domain; capacity node-domain) | **Occupancy — STAY** |
| 6 | `Buffer.Aligned` | `count` = "number of bytes allocated" (Buffer.Aligned.swift:77); **no separate `capacity`** | `count` ≡ allocation | **Raw region — RELOCATE → Memory** |
| 7 | `Buffer.Unbounded` | `count` = `_storage.count.retag(Element.self)` (Buffer.Unbounded.swift:102-104); `capacity` = `_storage.count.retag(Element.self)` `:108-110` | `count` ≡ `capacity` (**byte-identical expression**) | **Raw region — RELOCATE → Memory** |

(Conformer family counts: Arena ×4, Slab ×4, Ring ×4, Linked ×3, Linear ×1,
Aligned ×1, Unbounded ×1 = 18. `Buffer.Linear`'s Bounded/Inline/Small variants
do **not** carry the `Buffer.\`Protocol\`` conformance — verified — though they
remain occupancy disciplines as Linear variants.)

### 2b. The non-conformer

| Member | Surface (file:line) | Verdict |
|---|---|---|
| `Buffer.Slots<Metadata>` | **non-conformer** (no `Buffer.\`Protocol\``, verified); **no `count`**; only `capacity = header.capacity` (Buffer.Slots+Capacity.swift:29); backed by `Storage<Element>.Split<Metadata>` (Buffer.Slots.swift:43); *"performs no element lifecycle management"* `:17`; *"the same contract as `Storage.Split`"* `:27-28`; its `Header` is *"trivial — just capacity. Unlike Linear (count)"* (Buffer.Slots.Header.swift:8) | **Raw slots — RELOCATE → Storage** |

### 2c. Supporting / out-of-scope members

| Member | Nature | Disposition |
|---|---|---|
| `Buffer.\`Protocol\`` (`__BufferProtocol`) | the logical-occupancy capability protocol | **STAY** (its identity is exactly the occupancy core) |
| `Buffer.Growth` / `Buffer.Growth.Policy` | growth-strategy value type (`enum Growth {}` + `struct Policy`, Buffer.Growth.Policy.swift:8) | **STAY** (support vocabulary for growable disciplines; not a region) |

### 2d. The two confirmations that make the suspects unambiguous

- **`Buffer.Aligned`'s own conformance comment admits the conflation**: the empty
  conformance `extension Buffer.Aligned: Buffer.\`Protocol\` where Element == Byte {}`
  (Buffer.Aligned+Buffer.Protocol.swift:30) is documented as *"the logical element
  count is the allocated byte count"* (`:24`). The doc on the type itself says
  *"The `count` property always equals the current capacity"* (Buffer.Unbounded.swift:21,
  Buffer.Aligned.swift:25 "intentionally fixed-size"). Both **defer occupancy to
  `Binary.Cursor`**: Aligned *"Reader/writer indices (use `Binary.Cursor` …)"*
  (Buffer.Aligned.swift:27); Unbounded *"This type does NOT track 'written bytes'
  — use `Binary.Cursor.writerIndex`"* (Buffer.Unbounded.swift:28-29), under the
  stated principle *"Binary owns semantics … Buffer owns storage (allocation,
  capacity)"* (`:25-26`). By their own design statements, these are storage
  regions, not occupancy disciplines.
- **`Buffer.Aligned` already IS a Memory-layer type**: it conforms the
  contiguous-read capability `Span.\`Protocol\`` (then `Memory.Contiguous.\`Protocol\``;
  Buffer.Aligned.swift:270), allocates via
  `UnsafeMutableRawPointer.allocate(byteCount:alignment:)` (`:41`, `:106-122`),
  and its own usage guidance says *"For most APIs, accept `some
  Span.Protocol`* (then the Memory-namespaced spelling) *rather than `Buffer.Aligned` directly"* (`:66-68`).

**Result of the test:** five families (Linear, Ring, Slab, Arena, Linked) are
genuine occupancy disciplines and STAY. Three members — `Buffer.Aligned`,
`Buffer.Unbounded`, `Buffer.Slots` — fail the occupancy test and are misclassified.

---

## 3. Per-member home recommendation

The principal's two directives map each misclassified member to a *specific*
physical package. The logical-over-physical layering is **already the real
package-dependency structure** for the five genuine disciplines (verified
2026-06-02):

```
Buffer.Linear/Ring  →  swift-storage-primitives          (Storage.Heap / .Inline)
Buffer.Slab         →  swift-storage-slab-primitives     (Storage.Slab)
Buffer.Arena        →  swift-storage-arena-primitives    (Storage.Arena)
Buffer.Linked       →  swift-storage-pool-primitives     (Storage.Pool)
Buffer.Slots        →  swift-storage-split-primitives    (Storage.Split)   ← but adds no occupancy
Buffer.Aligned      →  swift-memory-primitives ONLY      (no Storage underneath)
Buffer.Unbounded    →  swift-memory-primitives ONLY      (no Storage underneath)
```

Every genuine discipline is a *logical occupancy layer composing a `Storage.*`
primitive*. The three misclassified members are exactly the ones that break the
pattern — and *how* they break it tells you their correct home.

### 3.1 `Buffer.Aligned` → **Memory layer** (`Memory.Aligned`)

`Buffer.Aligned` is a fixed-size, aligned, self-owning `~Copyable` raw byte
region with `count` ≡ allocation and no element lifecycle. It depends **only** on
swift-memory-primitives — no Storage primitive underneath — because there is no
element lifecycle to track. It is structurally `Storage.Contiguous<Byte>` (the owned
typed region, then spelled `Memory.Contiguous<Byte>`) plus an **alignment guarantee**.

**[DS-020] composition-over-existing check.** Does an existing primitive
already cover it? Closest is the owned typed region `Storage.Contiguous<Element>`
(then spelled `Memory.Contiguous<Element>`, "above raw pointers, below `Storage`",
before it was itself dissolved into the storage tier). It does **not**
cover Aligned: that region's initializer adopts a pre-resolved base
(`Storage.Contiguous.swift`) — it *adopts* a pre-allocated pointer; it does
**not** allocate-with-alignment, and stores no alignment. Aligned's *aligned
allocation* + stored `alignment` + `isAligned(to:)` is a genuine capability gap in
the Memory layer. So this is **not** a premature primitive ([RES-018] / [DS-020]):
it is **existing domain-owned vocabulary relocating to its correct layer** — the
Memory domain owns "raw aligned byte allocation."

**Recommended home + name:** a Memory-layer type **`Memory.Aligned`**, sibling of
`Memory.Heap` / `Memory.Buffer` / `Memory.Inline`. The name is free
(verified: no existing `Memory.Aligned`). Under [API-NAME-001b], "Aligned" is a
*manner* descriptor of a memory region, consistent with the sibling shape-words
`Memory.Heap`, `Memory.Inline`. Two sub-options for the principal:
- **(a) distinct sibling `Memory.Aligned`** (recommended) — preserves the named
  alignment capability as a first-class Memory primitive.
- **(b) fold into the owned typed region** (`Storage.Contiguous`, then spelled
  `Memory.Contiguous`) by adding an aligned-allocating
  initializer + `alignment` storage — fewer types, but couples the alignment
  guarantee into the generic adopt-only type and forces the `Element == Byte`
  specialization to coexist with the generic `BitwiseCopyable` surface.

It retains its `Span.\`Protocol\`` conformance either way (that
conformance is the right one — physical contiguous read).

### 3.2 `Buffer.Unbounded` → **Memory layer** (`Memory.Aligned.Resizable` / `Memory.Unbounded`)

`Buffer.Unbounded` is a growable raw byte region: it *is* `Buffer.Aligned` +
`Buffer.Growth.Policy`, with `count` ≡ `capacity` (byte-identical) and occupancy
explicitly delegated to `Binary.Cursor.writerIndex`. It depends only on
swift-memory-primitives (+ the Aligned it wraps). It moves **with** Aligned to the
Memory layer.

**Recommended home + name:** a Memory-layer growable region. Because it is "Aligned
+ growth," the cleanest names are **`Memory.Aligned.Resizable`** (nests the growth
under the aligned region it extends) or a sibling **`Memory.Unbounded`** (both
free). `Buffer.Growth.Policy` is its only Buffer-namespace dependency; it should
travel as `Memory.Growth.Policy` (or be referenced from wherever the growth
vocabulary lands) so the Memory region carries no residual `Buffer.*` import.

### 3.3 `Buffer.Slots` → **Storage layer** (fold into / sit beside `Storage.Split`)

> **⚠️ SUPERSEDED 2026-06-03 — see the correction banner at the top of this note.** This subsection's verdict is **reversed**: **Q2 = KEEP `Buffer.Slots` in `Buffer.*`** (`Hash.Table → Buffer.Slots → Storage.Split`, no bypass). The premise below — that `Buffer.Slots` "adds essentially nothing logical over `Storage.Split`" / is "a degenerate pass-through" — is **wrong**: it carries CoW (`ensureUnique`) + predicate `deinitialize(where:)` that `Storage.Split` does not, and its no-occupancy property is the *deliberate design* of a metadata-parametric buffer discipline (locked R4), not an absence of content. The fold that executed this verdict was a regression and was reversed. Governing: `hash-table-storage-buffer-layering.md` v3.0.0, `metadata-parametric-slots.md` v2.0.0. The text below is retained as the (refuted) original recommendation.

This is the member the principal's second directive ("cannot ignore the storage
primitives packages") targets. `Buffer.Slots<Metadata>` is **not** a Memory-layer
raw region — it is a **Storage-layer slot region**:

- It **has no logical occupancy** (no `count`; consumer tracks occupancy through
  metadata values, Buffer.Slots.swift:14-20) → fails Buffer membership.
- It is, by its own documentation, *"the same contract as `Storage.Split`"*
  (`:27-28`) and is **backed by** `Storage<Element>.Split<Metadata>` (`:43`).
- Its `Header` is *"trivial — just capacity. Unlike Linear (count)"*
  (Buffer.Slots.Header.swift:8) — and `Storage.Split` **already owns** a
  `Header(capacity:)` + `slotCapacity` (Storage.Split ~Copyable.swift:55, :67).
  So `Buffer.Slots.Header` is **redundant** with `Storage.Split`'s own header.

`Buffer.Slots` therefore adds essentially **nothing logical** over `Storage.Split`
— it is a degenerate pass-through wrapper that re-exposes Split's capacity and
slot-pointer surface under a `Buffer.*` name. Under "Buffer = logical layer," a
member with no logical content does not belong in Buffer.

**Recommended home:** relocate to the **Storage layer**. Two sub-options, gated by
[DS-020] + what the sole consumer actually uses (§4):
- **(a) fold into `Storage.Split`** (recommended pending the consumer check) —
  Hash.Table (the only consumer) gets a `Storage.Split<Metadata>` region with
  slot-addressed access directly; the redundant header collapses. Requires
  checking which Slots-specific operations (`ensureUnique()`, `deinitialize(where:)`)
  Hash.Table relies on and porting them onto / beside `Storage.Split`.
- **(b) relocate as a distinct Storage-layer type `Storage.Slots`** — if the
  metadata-parametric convenience surface is worth a named Storage type distinct
  from `Storage.Split`. This keeps the type but moves it to the correct layer and
  drops the misleading `Buffer.*` name.

Either way: **out of `Buffer.*`, into the Storage layer**, per directive (2). This
adjudicates the framework doc's open "Slots (Memory / Storage / stays)" question:
**Storage** (specifically, collapse onto `Storage.Split`).

### 3.4 What STAYS

`Buffer.Linear`, `Buffer.Ring`, `Buffer.Slab`, `Buffer.Arena`, `Buffer.Linked`
(and all their Bounded/Inline/Small variants), `Buffer.\`Protocol\``, and
`Buffer.Growth.*` stay. After the three relocations, **every remaining `Buffer.*`
member tracks occupancy distinct from allocation** over a `Storage.*` primitive —
the namespace becomes exactly "the logical layer over physical storage
primitives," per directive (1).

---

## 4. Consumer blast-radius map

Grepped ecosystem-wide (swift-primitives + swift-standards + swift-foundations;
both path- and url-form `.package(…)` deps; excluding the owning package, tests,
and build logs), verified 2026-06-02:

| Type | Real source consumers | Package-level dependents | Blast radius |
|---|---|---|---|
| `Buffer.Aligned` | **1**: `Buffer.Unbounded` (wraps it). `swift-tensor-primitives` references it only in `///` doc comments (Tensor.Storage.Aligned.swift:15) with **no `Package.swift` dependency** — aspirational, not compiled. | `swift-buffer-unbounded-primitives` only | **Tiny** — moves with Unbounded |
| `Buffer.Unbounded` | **0** | **none** — no package declares a dependency on `swift-buffer-unbounded-primitives` | **Zero** |
| `Buffer.Slots` | **1**: `Hash.Table` (`swift-hash-table-primitives`; Hash.Table.swift:149 "owns a heap-allocated `Buffer.Slots`"; Hash.Table+ensureUnique.swift delegates to `Buffer.Slots.ensureUnique()`) → backs `Dictionary` / `Set.Ordered` | `swift-hash-table-primitives` only | **One consumer** (Hash.Table) |

**[RES-023] correction to the trigger brief.** The brief stated *"e.g.
Binary.Cursor uses Unbounded."* This is **false as a code dependency**:
`Binary.Cursor` is `struct Cursor<Storage: Span.\`Protocol\` &
~Copyable>` (then spelled `Memory.Contiguous.\`Protocol\``; Binary.Cursor.swift:42) — it is **generic over
the contiguous-read capability `Span.\`Protocol\``**, not over `Buffer.Unbounded`, and tracks its
own reader/writer occupancy via `readerIndex`/`writerIndex` (`:65-70`). Neither
`Binary.Cursor` nor swift-binary-cursor-primitives references Unbounded or
Aligned. This **strengthens** the recommendation: the positioned-byte occupancy
abstraction (`Binary.Cursor`) *already* composes the physical contiguous-read
capability (`Span.\`Protocol\``), and `Buffer.Aligned`/`Unbounded` are merely
candidate conformers of that capability. Relocating them to Memory aligns
them with the abstraction they were always meant to serve.

**Net blast radius is minimal and identity-driven, not adoption-gated:**
Unbounded has zero dependents; Aligned has one (Unbounded, which moves with it);
Slots has one (Hash.Table). The relocations touch ≤ 3 owning packages + 1 external
consumer (Hash.Table). Per [ARCH-LAYER-008] this near-zero adoption is *not* the
reason to relocate — semantic identity is — but it confirms the move is cheap and
low-risk during the pre-1.0 architectural-shaping window. ([ARCH-LAYER-009]: this
is rename/reshape/relocate, **not** deletion — permitted pre-1.0.)

---

## 5. Sequencing vs GAP-N

GAP-N (fold `{capacity, isFull, availableCapacity}` into the single
`Buffer.\`Protocol\``) was adjudicated **WONTFIX-as-posed** precisely because
`Buffer.Aligned` / `Buffer.Unbounded` make the fullness surface vacuous —
`isFull` always-true, `availableCapacity` always-zero — since their `count` ≡
`capacity`. GAP-N is marked **REVIVABLE via GAP-O**: once the allocation-only
members leave `Buffer.*`, every remaining conformer tracks occupancy-within-
allocation and the `{count, capacity, isEmpty, isFull, availableCapacity}` surface
becomes coherent.

**Recommended order:**

1. **GAP-O first (this note's relocations).** Reclassify `Buffer.Aligned`,
   `Buffer.Unbounded` → Memory; `Buffer.Slots` → Storage. This makes
   `Buffer.\`Protocol\`.count` *unambiguously occupancy* across all remaining
   conformers and removes the two vacuous-fullness members.
2. **GAP-N second (revisit after GAP-O).** With the namespace coherent, re-open
   whether `capacity` + fullness belong on `Buffer.\`Protocol\``. Note the GAP-N
   spike's own narrowing still applies to the *remaining* disciplines: fullness
   reduces to `count == capacity` only for **Ring** (and contiguous Linear);
   **Arena** (`!hasFree && highWater >= capacity`), **Linked** (`isExhausted`,
   node-domain), and **Slab** (`popcount >= capacity`) override with
   domain-specific fullness. So even post-GAP-O the payoff is a *uniform
   occupancy-state surface*, with `isFull` as a gated default for the contiguous
   disciplines — a modest [MOD-RENT] rent to weigh then, not now.

Do **not** attempt GAP-N before GAP-O; the conflation is what made GAP-N vacuous.

---

## 6. Prior-art alignment ([RES-019])

This note **extends**, and is governed by, existing internal research; it does not
re-derive:

- **`cross-layer-capability-protocol-model.md`** (v1.1.0, APPROVED 2026-05-28,
  Tier 3) — the governing model. It already fixes the logical/physical split
  (`Buffer.\`Protocol\`` = occupancy; `Span.\`Protocol\`` = physical
  read; Buffer HAS-A Storage, does NOT refine it). This note applies that approved
  *protocol-shape* decision to *namespace membership*: a member whose only content
  is physical (raw region / raw slots) belongs on the physical side of the same
  split. The relocation makes the membership consistent with the approved model.
- **`storage-buffer-abstraction-analysis.md`** (v1.2.0, Tier 3) — its inventory
  (line 34) recorded `Buffer.Aligned` / `Buffer.Unbounded` as living in a
  **separate package `swift-binary-buffer-primitives` (Tier 16)**, explicitly
  labeled *"byte-specialized buffers"* and **excluded** from the six-discipline
  inventory (Ring, Linear, Slab, Linked, Slots, Arena). The current
  `Buffer.\`Protocol\``-conforming, co-namespaced state is **drift away from** that
  earlier separation; GAP-O restores a cleaner version of it (to Memory/Storage,
  not a Tier-16 byte-buffer package). That doc's central finding — abstraction
  belongs at the *ownership/capability* level, storage strategy is essential
  variation — also supports keeping the five genuine disciplines distinct.
- **`buffer-storage-associatedtype-prior-art.md`** (v1.0.0, Tier 2) — establishes
  `Buffer.\`Protocol\`` as the *logical occupancy core* (`count`/`isEmpty`) that
  HAS-A storage and does not expose it. A member with `count` ≡ allocation has no
  logical core to contribute — direct support for excluding Aligned/Unbounded from
  the logical protocol's namespace.

No external prior-art survey is needed beyond what these Tier-2/3 docs already
contain; the question is internal layer-membership, governed by the approved
model.

---

## Outcome

**Status: RECOMMENDATION** (class-(c); principal decides).

**GO/STAY per member:**

| Member | Verdict | Correct home | Confidence |
|---|---|---|---|
| `Buffer.Linear` (+variants) | **STAY** | swift-buffer-primitives (logical, over Storage.Heap/Inline) | High |
| `Buffer.Ring` (+variants) | **STAY** | swift-buffer-ring-primitives (over Storage.Heap/Inline) | High |
| `Buffer.Slab` (+variants) | **STAY** | swift-buffer-slab-primitives (over Storage.Slab) | High |
| `Buffer.Arena` (+variants) | **STAY** | swift-buffer-arena-primitives (over Storage.Arena) | High |
| `Buffer.Linked` (+variants) | **STAY** | swift-buffer-linked-primitives (over Storage.Pool) | High |
| `Buffer.\`Protocol\``, `Buffer.Growth.*` | **STAY** | swift-buffer-primitives | High |
| `Buffer.Aligned` | **RELOCATE → Memory** | `Memory.Aligned` (sibling of Memory.Heap/Buffer), swift-memory-primitives | High |
| `Buffer.Unbounded` | **RELOCATE → Memory** | `Memory.Aligned.Resizable` / `Memory.Unbounded`, swift-memory-primitives | High |
| `Buffer.Slots` | ~~RELOCATE → Storage~~ **REVERSED 2026-06-03 → STAY in `Buffer.*`** (see correction banner + §3.3) | swift-buffer-slots-primitives (over `Storage.Split`) | — (occupancy-test mis-fire; metadata-parametric buffer discipline per R4) |

**Recommended sequence:** GAP-O relocations first (this note) → then revisit GAP-N
on the now-coherent occupancy-only namespace.

**Net effect:** `Buffer.*` becomes exactly "the logical occupancy layer over
physical storage primitives" (principal directive 1); the raw byte regions land at
**Memory** and the raw slot region lands at **Storage** (principal directive 2);
`Buffer.\`Protocol\`.count` becomes unambiguously occupancy; and GAP-N becomes
revivable.

**Open items for the principal's decision (not blockers to the recommendation):**
1. `Memory.Aligned` as a distinct sibling vs folding into the owned typed region (`Storage.Contiguous`, then spelled `Memory.Contiguous`)
   (§3.1 a/b).
2. `Buffer.Slots` fold-into-`Storage.Split` vs distinct `Storage.Slots` (§3.3
   a/b) — gated by which Slots ops Hash.Table needs (`ensureUnique`,
   `deinitialize(where:)`).
3. Final names for the relocated growable region (`Memory.Aligned.Resizable` vs
   `Memory.Unbounded`) and the growth-policy vocabulary's home.

---

## References

### Internal research (governs per [RES-019])
1. `cross-layer-capability-protocol-model.md` (v1.1.0, APPROVED 2026-05-28, Tier 3) — logical/physical capability split; Buffer HAS-A Storage, span on the contiguous-read capability (then `Memory.Contiguous.Protocol`, since lifted out to `Span.Protocol`). §3, lines 51-53, 188-203.
2. `storage-buffer-abstraction-analysis.md` (v1.2.0, Tier 3) — Aligned/Unbounded historically in separate Tier-16 `swift-binary-buffer-primitives`, excluded from the six-discipline inventory (line 34); storage-strategy abstraction belongs at the ownership-capability level.
3. `buffer-storage-associatedtype-prior-art.md` (v1.0.0, Tier 2) — Buffer.Protocol is the logical occupancy core that has-a (not exposes) storage.
4. `derive-for-free-capability-composition.md` — GAP-N / GAP-O (co-architect-owned; this note is the GAP-O Tier-2 investigation it requested).

### Source (verified on disk 2026-06-02, [RES-023])
5. `swift-buffer-primitives/Sources/Buffer Protocol Primitives/Buffer.Protocol.swift` — `__BufferProtocol` (`count` + `isEmpty`); orthogonal-to-Storage note lines 87-91.
6. `swift-buffer-aligned-primitives/.../Buffer.Aligned.swift` — `count` = allocated bytes (:77); aligned allocation (:41); `Span.Protocol` conformance — then the Memory-namespaced spelling — (:270); "accept some Span.Protocol" (:66-68).
7. `swift-buffer-unbounded-primitives/.../Buffer.Unbounded.swift` — `count` ≡ `capacity` (:102-110); occupancy → Binary.Cursor.writerIndex (:28-29).
8. `swift-buffer-slots-primitives/.../Buffer.Slots.swift` — non-conformer; backed by Storage.Split (:43); "same contract as Storage.Split" (:27-28); Header "trivial — just capacity" (Buffer.Slots.Header.swift:8).
9. `swift-storage-split-primitives/.../Storage.Split ~Copyable.swift` — `Header(capacity:)` (:55), `slotCapacity` (:67), slot `pointer` (:117).
10. The owned typed region (then `swift-memory-primitives/.../Memory.Contiguous.swift` — self-owning region, `init(adopting:count:)` (:100), "above raw pointers, below Storage"; since dissolved into `swift-storage-primitives/.../Storage.Contiguous.swift`).
11. `swift-binary-cursor-primitives/.../Binary.Cursor.swift` — `Cursor<Storage: Span.Protocol & ~Copyable>` (then the Memory-namespaced spelling; :42), reader/writer occupancy (:65-70). (Refutes "Binary.Cursor uses Unbounded.")
12. Genuine disciplines' `count` vs `capacity`: Buffer.Linear+Lifecycle.swift:26/:30; Buffer.Ring+Operations.swift:24/:28; Buffer.Slab+Operations.swift:32; Buffer.Arena ~Copyable.swift:32; Buffer.Linked ~Copyable.swift:68/:76.

### Skills
13. [RES-029] (membership/placement → semantic-identity-first), [RES-018]/[DS-020] (composition-over-existing gate), [MOD-DOMAIN] (factor the law), [ARCH-LAYER-001/006/008/009] (layer direction; correctness-not-adoption; no pre-1.0 deletion), [API-NAME-001b] (subject-vs-manner naming), [DS-001/004/005/006] (four-layer composition catalog).
