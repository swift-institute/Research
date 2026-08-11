# Storage.Split → Storage.Columns Redesign

<!--
---
version: 1.0.0
last_updated: 2026-05-25
status: DEFERRED
tier: 2
scope: cross-package
---
-->

## Context

This document captures a converged-but-deferred redesign of `Storage.Split`. It
is part of the broader arc to make the **memory → storage → buffer → ADT**
substrate first-principles-clean before the buffer-layer deduplication
(`Buffer.Protocol` / `Storage.Protocol` leverage).

During the storage-layer convergence, the four lifecycle-owning storages
(`Storage.Heap`, `Storage.Slab`, `Storage.Arena`, `Storage.Pool`) became
conditionally-`Copyable` value-façades over their own backing classes.
`Storage.Split` did not follow, and is the lone residual outlier:

- the lone reference type in the family (`public final class Split<…>`),
- the lone type exposing `slotCapacity` rather than `capacity` (everything else
  converged on `capacity`) — which, as the analysis shows, is forced by its
  `ManagedBuffer`-subclass shape, not a careless residual,
- the lone type that does **not** conform `Storage.Protocol`.

The question is whether that residual status is a defect to fix or a principled
difference to embrace — and, if reshaped, what the correct shape, name, and
package placement are.

**This redesign is deferred.** The current `Storage.Split` compiles and its
test suite is green (see *Current State*); the principal's decision (2026-05-25)
is to leave it in place and return to this later. This document records the
design so the return is cheap.

A parallel, independent investigation is converging on the **allocation
substrate** (`Memory.Allocator.Protocol` redesign) via
`/collaborative-discussion` — see
`swift-memory-primitives/Research/allocation-substrate-first-principles.md`.
That work changes how `Storage.Heap` *acquires* bytes; it does **not** touch
the field-addressing surface this document is about. The two are decoupled.

## Question

Should `Storage.Split` be reshaped — (1) renamed to `Storage.Columns`,
(2) generalized from a fixed two-array (lane + element) layout to an
N-column structure-of-arrays, and (3) have its ownership relocated out of the
storage and into the consuming buffer, so that `Storage.Columns` becomes a
value-type, `~Escapable`, non-owning **borrowed view** (an `Ownership.Borrow`
conformer) rather than a `ManagedBuffer` subclass? And what becomes of the
`swift-storage-split-primitives` package if so?

## Current State

*Verified: 2026-05-25 — `swift build` clean (12.36s); `swift test` green
(18 tests, 1 suite, 0 failures). Working tree clean on `main` @ `83a57c3`.*

`Storage.Split` is a two-array-in-one-allocation storage — a primary **element**
(payload) array parallel to a **lane** (metadata) array, co-allocated in a
single `ManagedBuffer`:

| Fact | Location |
|------|----------|
| `public final class Split<Lane: BitwiseCopyable>: ManagedBuffer<Storage.Split<Lane>.Header, UInt8>` | `Storage.Split.swift:78` |
| Nested in `extension Storage where Element: ~Copyable` | `Storage.Split.swift:15` |
| `Header` carries only `capacity: Index<Element>.Count` | `Storage.Split.swift:92–103` |
| Layout: `[lanes][padding][elements]` in one allocation | `Storage.Split.swift:21–26` |
| `_elementRegionOffset` / `_totalBytes` layout computation | `Storage.Split ~Copyable.swift:24–34` |
| Public accessor named `slotCapacity` not `capacity` — `Split` IS a `ManagedBuffer<…,UInt8>` subclass, so `capacity` is taken by the inherited `ManagedBuffer.capacity: Int` (byte count) | `Storage.Split ~Copyable.swift:67–69` |
| `field: (lane:, element:)` vends the two `Storage.Field` handles | `Storage.Split ~Copyable.swift:89–100` |
| Core access primitive `pointer<Value: ~Copyable>(_ field:, at slot:)` | `Storage.Split ~Copyable.swift:117–130` |
| Copyable field subscript `[field, at:]` | `Storage.Split Copyable.swift:68–73` |
| `initialize` / `deinitialize` `Property` accessors delegate to `pointer` | `Storage.Split+Initialize.swift`, `+Deinitialize.swift` |
| **No `deinit`** — element lifecycle is consumer-managed | `Storage.Split.swift:36–50, 79–80` |

Two structural facts drive the redesign:

1. **`Storage.Split` does no element lifecycle management.** It treats lane
   bytes as opaque (`Lane: BitwiseCopyable`) and never deinitializes elements.
   Occupancy — which slots hold live elements — is *externalized to the
   consumer*. This is documented as a deliberate capability boundary, "the same
   contract as `UnsafeMutableBufferPointer` or raw `ManagedBuffer`"
   (`Storage.Split.swift:36–41`).
2. **It is field-addressed, not single-region-addressed.** Access is
   `pointer(field, at: slot)` over `Storage.Field` descriptors, not the
   single-region `pointer(at:)` of `Storage.Protocol`. This is *why* it doesn't
   (and structurally shouldn't) conform `Storage.Protocol` — and it's fine,
   because `Storage.` is a namespace, not a conformance club. But the
   non-conformance is currently undocumented.

## The Sole Consumer

*Verified: 2026-05-25 — `swift-buffer-slots-primitives` is the only package with
a `Package.swift` dependency on `swift-storage-split-primitives`.*

`Buffer.Slots` is the open-addressing / SwissTable substrate. It uses `Split` as
the control-bytes-plus-slots layout:

| Fact | Location |
|------|----------|
| Holds `var storage: Storage<Element>.Split<Metadata>` by value | `Buffer.Slots.swift:43` |
| Constructs via `.create(capacity:laneInitial: metadataInitial)` (e.g. `0x80` EMPTY) | `Buffer.Slots+Capacity.swift:17–19` |
| `copy(where isOccupied: (Metadata) -> Bool)` — occupancy-aware deep copy | `Buffer.Slots Copyable.swift:18–45` |
| → bulk-copies the lane (BitwiseCopyable, always fully initialized) | `Buffer.Slots Copyable.swift:22–27` |
| → copies element slots **only where `isOccupied(...)` is true** | `Buffer.Slots Copyable.swift:29–42` |
| `ensureUnique(where:)` guarded by `isKnownUniquelyReferenced(&storage)` | `Buffer.Slots Copyable.swift:56–57` |
| Separate `BitwiseCopyable` fast path bulk-copies both arrays (no occupancy needed) | `Buffer.Slots Copyable.swift:67–106` |

The occupancy-aware copy is the load-bearing observation: copying a non-trivial
`Element` requires knowing which slots are live, because reading an
uninitialized slot to copy it is undefined behavior. The consumer knows
occupancy (it interprets `0x80` = empty); the storage does not.

## Analysis

### Decision 1 — Reframe and rename: `Split` → `Storage.Columns`

`Split` is a borrowed analogy (Apple Accelerate's `DSPSplitComplex`, cited at
`Storage.Split.swift:72–75`). It describes *binary* separation of two parallel
arrays, which is accidental — the type is conceptually a
**structure-of-arrays**: a primary payload column plus one or more parallel
metadata sidecar columns. `Storage.Columns` is the domain-honest name and
generalizes cleanly to N columns. Per `[PRIM-NAME-003]` (names describe
mechanism, not origin), `Columns` wins over `Split`.

### Decision 2 — Generalize to N typed columns (structure-of-arrays)

Drop the hardcoded single `<Lane>` parameter and the fixed `(lane, element)`
accessor; replace the lane-then-element offset computation with a K-column
layout. The mechanism question is *how* to express "N typed columns":

| Mechanism | Shape | Verdict |
|-----------|-------|---------|
| Parameter packs | `Columns<each Column>` | Legal, but packs expand in lockstep — they cannot random-access "column *k* as its own static type." Even folding per-column layout requires a `for-in` pack expansion (array-literal expansion is rejected). Wrong ergonomics for an O(1) typed column access. |
| Field-driven (recommended) | raw region + typed `Storage.Field<T>` handles derived from a K-column `Layout` | `Storage.Field` (offset + stride) **already is** the O(1) typed columnar-access atom, and it is column-count-agnostic. `Split` already routes every access through it. |

*Carried forward from a prior-session `/tmp` probe (per [RES-013a],
re-verify before implementation): both the pack form and the Field form compile
as `ManagedBuffer` subclasses; the distinction is ergonomic, not feasibility.
The probe confirmed pack layout-folding works only via `for-in` expansion, and
that Field-addressed O(1) typed access compiles.*

Recommendation: **Field-driven N-column.** A pack-typed schema can be offered
later as a higher-layer façade if a consumer ever wants a type-enumerated
column list; it is the wrong primitive at L1.

### Decision 3 — Ownership placement: where does the refcount/CoW class live?

This is the crux, and it resolves a question the storage arc left implicit.

**The family rule (made explicit here): the refcount-bearing class lives
wherever copy-on-write lives, and CoW lives wherever occupancy/lifecycle
ownership lives.**

| Storage | Knows its own occupancy? | Can copy itself? | So its CoW class lives… |
|---------|--------------------------|------------------|--------------------------|
| `Heap` | yes — a contiguous range | yes | in `Heap` (value-façade over its own class) |
| `Slab` | yes — a bitmap | yes | in `Slab` |
| `Arena` | yes — a high-water mark | yes | in `Arena` |
| `Pool` | yes — a free list | yes | in `Pool` |
| `Split` | **no — externalized to the consumer** | **no** | **in the consumer** ← the outlier |

`Split` is the only storage that hands occupancy to its consumer. Walk the
concrete chain for the SwissTable case:

1. Value-copying the table requires copying element slots **only where
   occupied** (`Buffer.Slots Copyable.swift:29–42`); reading an empty slot's
   uninitialized memory is UB for non-trivial `Element`.
2. "Occupied" is the *meaning* of the control bytes (`0x80` = empty) — the
   hash table's logic, which the two-axis split (Header owns logical truth;
   storage owns physical truth) places in the **buffer**.
3. The storage deliberately treats lanes as opaque (`Lane: BitwiseCopyable`),
   so it *cannot* perform the copy correctly. Only the buffer can.
4. The refcount class that `isKnownUniquelyReferenced` checks exists to serve
   CoW. Therefore it belongs where CoW is — the **buffer**.

So the principled placement is: the class moves *out* of the storage and *into*
the consuming buffer's backing; `Storage.Columns` becomes a value type. This is
not the elimination of a class — it is its **relocation** to the tier that has
the information to justify it. It also *unifies* ownership that is today
awkwardly split (the `Split` class owns the allocation; `Buffer.Slots` owns CoW
+ occupancy + element teardown).

Three shapes follow:

| Option | `Storage.Columns` | The class | Assessment |
|--------|-------------------|-----------|------------|
| **A** Keep a class | owning `ManagedBuffer` subclass (renamed `Split`) | stays in storage | simplest; minimal consumer change; but leaves the family's lone reference type and keeps ownership split across two types |
| **B** Borrowed view (recommended) | value-type `~Escapable` non-owning view (`Ownership.Borrow.Protocol` conformer) | moves to `Buffer.Slots.Backing` (a class owning allocation + occupancy-aware CoW + `deinit`) | family-consistent value type; ownership unified; lifetime-safe; cost is class *relocation* + restructuring `Buffer.Slots` |
| **B′** Full dissolution | no `Storage.Columns` type at all; consumer composes `Memory.Buffer.Mutable` (region) + `Storage.Field` handles + a small offset helper | n/a | maximal decomposition; but contradicts the "name it `Storage.Columns`" framing and loses a reusable storage-tier view |

### The decomposition that decides it

Applying the established two-axis split (Header = logical truth;
storage = physical truth) to the SwissTable case lands each concern in exactly
one tier:

| Concern | Tier | Why |
|---------|------|-----|
| One allocation, partitioned into K co-allocated regions | **Memory** | bytes + offsets; `Memory.Buffer.Mutable` is already the non-owning raw region |
| Typed, field-addressed slot access over those regions | **Storage** | `pointer<Value>(field, at:)` over `Storage.Field` — pure physical addressing |
| Occupancy (the control bytes' *meaning*), CoW, lifetime, teardown | **Buffer** | occupancy is logical state → Header/buffer |
| The hash map | **ADT** | `Set` / `Dictionary` over the buffer |

The control column's *bytes* are physical (a storage region); their *meaning*
(occupancy) is logical (buffer). That split is the whole answer, and it makes
Option B fall out as the structurally correct shape.

### Ownership.Borrow placement (the borrowed-view mechanism for Option B)

*Verified: 2026-05-25 against `swift-ownership-primitives`.*

The right analog for the value-type view is **not** `Memory.Buffer.Mutable`
(which is `Copyable` + escapable + `@unchecked Sendable` — it can dangle); it is
`Ownership.Borrow`:

- `public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable`
  (`Ownership.Borrow.swift:72`) — `Copyable` (pointer copies are safe) but
  `~Escapable` (`Ownership.Borrow.swift:31`), lifetime-bound to its source via
  `@_lifetime(borrow …)`. The compiler forbids it outliving the bytes.
- `Ownership.Borrow.Protocol` is the hoisted `__Ownership_Borrow_Protocol`
  (SE-0404 prohibits a protocol nested in a generic), with
  `associatedtype Borrowed: ~Copyable, ~Escapable = Ownership.Borrow<Self>`
  (`__Ownership_Borrow_Protocol.swift:30–31`). It is the sibling of `Span`,
  `Path.Borrowed`, `String.Borrowed`.

So `Storage.Columns` would join the ownership lattice as a borrowed view:
`Storage.Columns: ~Escapable`, conforming `Ownership.Borrow.Protocol`,
vending per-slot reads as `Ownership.Borrow<Value>` and per-slot mutations as
`Ownership.Inout<Value>`, with the raw `pointer(field, at:)` staying the
`@unsafe` choke point. The owner (`Buffer.Slots.Backing`) holds the allocation
and vends the view `@_lifetime(borrow self)` — never storing it.

The type system *enforces* the decomposition: a `~Escapable` view cannot be a
stored property of an escapable type, so `Buffer.Slots` literally cannot hold a
`Storage.Columns` in a `var` — it must store the owning backing class and borrow
the view per-operation (exactly how `Span` is used). That independently confirms
"refcount/CoW class in the buffer; view is a transient borrow."

**Implementation constraint (verified, load-bearing).**
`Ownership.Borrow.init(borrowing:)` for the `~Copyable Value` path
(`Ownership.Borrow.swift:146–195`) is sound for **cross-module** callers **only
while it stays non-`@inlinable`**. Adding `@inlinable` causes the Swift
6.3.1 / 6.4-dev optimizer to inline the body across module boundaries and
reproduce a release-mode miscompile (a callee-frame spill slot that dies after
the closure returns). Same-module consumers must instead use the
`init(_ pointer: UnsafePointer<Value>)` path. Consequence for this design:
`Storage.Columns` lives in `swift-storage-primitives` and is consumed
cross-module by `swift-buffer-slots-primitives` → the borrow construction is
safe *provided the borrowing inits/accessors that cross the boundary remain
non-`@inlinable`*; only `swift-storage-primitives`' own tests must use the
pointer-init path. Evidence + minimal reproducer:
`swift-institute/Experiments/borrow-pointer-storage-release-miscompile/`;
audit `swift-institute/Audits/borrow-pointer-storage-release-miscompile.md`.
(This corrects an earlier informal "cross-module is unconditionally safe"
framing — the non-`@inlinable` qualifier is essential.)

The clean symmetry: `Span : a contiguous region :: Storage.Columns : a
co-allocated multi-column region` — both `~Escapable` borrowed projections, both
obtained `@_lifetime(borrow self)` from an owner.

### Decision 4 — Packaging (open; gated on an explicit deletion authorization)

Option B implies a packaging consequence:

- **Dissolve `swift-storage-split-primitives`**: the view (`Storage.Columns` +
  a `Layout` helper) belongs next to `Storage.Field` in
  `swift-storage-primitives`; the ownership/occupancy moves into
  `swift-buffer-slots-primitives`. No standalone split/columns package.
- **Alternative**: keep a thin renamed `swift-storage-columns-primitives`
  holding just the view. Less decomposition-clean (the view is really
  "`Field`, plural"), but preserves a package boundary.

Deleting a package is a one-way, hard-to-reverse repo operation and is **gated
on an explicit per-repo authorization** from the principal (workspace repo-op
discipline). It is not decided here.

### Sub-choice — Element-primary vs fully-symmetric

If Option B proceeds, one permanent sub-choice remains:

- **Element-primary (leaning)**: `Storage<Element>.Columns` — `Element` stays
  the primary/index column and the shared slot-index tag (`Index<Element>`),
  preserving the `Storage<Element>.X` family nesting and giving a natural
  slot-index. The sole consumer's slot index *is* the payload index, so this
  fits SwissTable directly.
- **Fully-symmetric standalone**: `Storage.Columns` with its own synthetic
  row-index and no privileged column — purer SoA, but breaks the
  `Storage<Element>.X` nesting and introduces a new row phantom for no benefit
  the sole consumer needs.

## Comparison

| Criterion | A (keep class) | **B (borrowed view)** | B′ (dissolve fully) |
|-----------|----------------|------------------------|---------------------|
| Family consistency (value-type) | ✗ lone reference type | ✓ | ✓ (no type) |
| Ownership unified in one tier | ✗ split across 2 types | ✓ (buffer backing) | ✓ (buffer) |
| Compiler-enforced lifetime safety | ✗ | ✓ (`~Escapable`) | partial (`Memory.Buffer.Mutable` is escapable) |
| Reusable storage-tier view | ✓ | ✓ | ✗ |
| Consumer churn | minimal | moderate (restructure `Buffer.Slots`) | high |
| Eliminates a class | ✗ | ✗ (relocates) | ✓ |
| Matches `Storage.Columns` framing | rename only | ✓ | ✗ |

## Prior Art

*Tier-2 survey per [RES-021]; claims below are from general domain knowledge,
not freshly verified against primary sources (this is a DEFERRED capture, not a
DECISION) — flagged per [RES-032].*

- **SwissTable / Abseil `raw_hash_set`, Rust `hashbrown`**: the canonical
  control-bytes + slots layout this type exists to serve. Control bytes are a
  parallel metadata array; group scans (SSE2 / NEON, mirrored here by SIMD16
  lane scans) read the control array. Occupancy is encoded in the control bytes
  and interpreted by the table, not the allocation — exactly the
  occupancy-in-the-consumer split argued above.
- **Structure-of-arrays (SoA)**: the general pattern `Storage.Columns`
  generalizes to. Data-oriented-design literature and ECS frameworks (e.g.
  archetype storage) co-allocate parallel typed columns indexed by a shared row
  index.
- **Swift `Span` / `MutableSpan` (SE-0447 / SE-0467)** and the ecosystem
  `Ownership.Borrow` / `Property.Borrow`: the `~Escapable` borrowed-view model
  Option B adopts. A non-owning, lifetime-bound projection of memory owned
  elsewhere.
- **`ManagedBuffer` tail allocation**: the mechanism `Split` currently uses
  (header + trailing elements in one allocation). Relevant to the *Heap*
  fork in the allocation-substrate doc, not to this view.

**Contextualization step ([RES-021]).** The universally-adopted pattern across
these systems is "control/metadata array parallel to a payload array, with
occupancy owned by the table." This redesign does **not** diverge from that
consensus — it *aligns* with it by moving occupancy ownership to the buffer
(the "table"), which is where every surveyed system already puts it. The current
ecosystem shape (occupancy in the consumer, addressing in the storage) is
already consistent with prior art; the only divergence is the *accidental*
placement of the refcount class in the storage, which Option B corrects.

## [RES-018] Classification

`Storage.Columns` is **not** a new cross-cutting primitive. It is **case (b),
domain-owned vocabulary at L1**: a type the storage domain uses to express its
own addressing concept (`Field`, plural) inside `swift-storage-primitives`. It
reuses an existing cross-cutting primitive (`Ownership.Borrow`) rather than
introducing one. The composition check and cross-domain-fit hurdles of case (a)
do not apply; governance is `[MOD-DOMAIN]` (semantic coherence) alone.

## Outcome

**Status: DEFERRED.**

The current `Storage.Split` compiles and its tests pass (verified 2026-05-25).
Per the principal's 2026-05-25 decision, it is **left in place**; this document
records the redesign for a later return.

**Structural calls captured (recommended, not yet decided):**

1. Reframe/rename `Split` → `Storage.Columns` (domain-honest SoA name).
2. Field-driven N-column generalization (not parameter packs).
3. **Option B** — `Storage.Columns` as a value-type `~Escapable` borrowed view
   (`Ownership.Borrow.Protocol` conformer); the refcount/CoW class relocates to
   `Buffer.Slots.Backing`. Justified by "refcount lives where occupancy lives"
   and the memory→storage→buffer→ADT decomposition.

**Calibration the principal must make on return — minimal vs full:**

- **Minimal**: keep `Storage.Split` an owning class; only rename to `Columns`,
  fix `slotCapacity` → `capacity`, generalize to N columns. Ownership stays
  split across two types (the status quo, which works). Low churn.
- **Full (Option B)**: the ownership move above. Structurally correct; relocates
  (does not eliminate) the class; restructures `Buffer.Slots`. Higher churn.

**Open sub-decisions (do not resolve without the principal):**

- Packaging (Decision 4): dissolve `swift-storage-split-primitives` vs. thin
  renamed `swift-storage-columns-primitives`. **Package deletion is gated on an
  explicit per-repo authorization.**
- Element-primary vs fully-symmetric standalone shape.

**What would resolve the deferral:** a principal decision on minimal-vs-full,
then (if full) promotion of this doc to a Tier-3 DECISION with the formal
semantics and SLR that an `Ownership.Borrow`-conformer L1 contract warrants
([RES-024]), plus re-running the parameter-packs-vs-Field probe ([RES-013a]),
before any implementation wave.

**On the `slotCapacity` accessor (not a careless residual):** it is **not**
independently renameable to `capacity`. `Storage.Split` IS a
`ManagedBuffer<Header, UInt8>` subclass and inherits `ManagedBuffer.capacity: Int`
(the raw byte count), so the slot-count accessor must take a distinct name. This is
the same `Int` / `Index<Element>.Count` collision documented for `Storage.Heap`,
resolved there only by the value-type façade hiding the `ManagedBuffer`
(`Storage.Heap+Storage.Protocol.swift:19–22`). Only Option B — making `Columns` a
value-type view that is no longer a `ManagedBuffer` subclass — frees the `capacity`
name. The rename is therefore genuinely gated on the redesign, not merely deferred
to avoid churn. (A further point in Option B's favour: the awkward `slotCapacity`
is a symptom of the class-shape Option B removes.)

## References

- `swift-storage-split-primitives` — current source (file:line cites above).
- `swift-buffer-slots-primitives` — sole consumer (file:line cites above).
- `swift-ownership-primitives/Sources/Ownership Borrow Primitives/Ownership.Borrow.swift`
  — `Ownership.Borrow` shape + the `init(borrowing:)` non-`@inlinable`
  cross-module constraint (`:72`, `:31`, `:146–195`).
- `swift-memory-primitives/Research/allocation-substrate-first-principles.md`
  — the parallel, decoupled allocation-substrate redesign.
- `swift-institute/Experiments/borrow-pointer-storage-release-miscompile/` and
  `swift-institute/Audits/borrow-pointer-storage-release-miscompile.md`
  — evidence for the `Ownership.Borrow` release-mode miscompile constraint.
- Abseil SwissTables design notes; Rust `hashbrown`; SE-0447/SE-0467 (`Span`).
