# Storage.Protocol Pointer Modernization: Replacing `UnsafeMutablePointer` with Modern Span Types

<!--
---
version: 1.1.0
last_updated: 2026-06-02
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-storage-primitives, swift-buffer-linear-primitives]
normative: false
changelog:
  - "1.1.0 (2026-06-02): Added the North-Star Requirement Set section — the maximal-safety / maximal-derivation ceiling (4 members: capacity + yielding subscript + initialize + move), the init-state-graph argument for why three transition primitives is the irreducible safe floor, and the explicit trade the two locked constraints make against it. Added feasibility gate (4): yielding-accessor zero-witness specialization."
  - "1.0.0 (2026-06-02): Initial investigation. Triggered by the pre-public-release request to remove UnsafeMutablePointer from Storage.Protocol's single primitive."
---
-->

## Context

`Storage.Protocol` (hoisted `__StorageProtocol`, namespace alias `Storage.\`Protocol\``)
is the single-region, slot-addressed storage contract that unifies the five
disciplines — Heap, Inline, Pool, Arena, Slab — beneath the buffer layer. Its
entire interface is two members
(`Storage.Protocol.swift:25,35-36`, [Verified: 2026-06-02]):

```swift
public protocol __StorageProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    var capacity: Index<Element>.Count { get }

    @unsafe
    func pointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element>
}
```

`pointer(at:)` is documented as *"the primitive address computation … all
higher-level access (initialize / move / span) delegates to it"* — the protocol
is deliberately a **single primitive**, with every lifecycle and span operation
derived in extensions or concrete per-discipline accessors.

The recent `spike/storage-protocol` arc (Waves 1–4, CONFIRMED 2026-05-25,
`storage-protocol-capacity-pilot.md`) **standardized on this primitive**: Wave 1
added the public unbounded `pointer(at:)` witness to `Storage.Inline`, Wave 3
delegated the new `Storage.Heap` value-type façade's access through it, and the
SIL gate proved `some Storage.\`Protocol\`` specializes to **zero
`witness_method` / `class_method`** dispatch through `capacity` + `pointer(at:)`
in release + cross-module ([EXP-020] closed for Inline, Pool, Heap).

**Trigger**: before `Storage.Protocol` is made **public** for the 1.0 surface,
the principal wants `UnsafeMutablePointer<Element>` removed from it — *"upgrade
it to modern swift (no `UnsafeMutablePointer`)"* — accepting that this has large
downstream consequences (buffer + tree + collection consumers).

**Principal constraints (locked during the investigation conversation, 2026-06-02)**:

1. **One primitive** (or as few as absolutely necessary); derive everything else.
2. **Modern Swift** — no `UnsafeMutablePointer` (and not the `Unsafe*Pointer`
   family generally) on the surface.
3. **Keep `borrowing` semantics** — the current non-mutating, CoW-bypass shape of
   `pointer(at:)` is retained; the replacement must not force exclusive (`mutating`)
   access onto the access path.
4. **No protocol refinement** — the contiguous capability stays the *independent,
   already-existing* `Span.Protocol` (composed via
   `Storage.Protocol & Span.Protocol`), **not** a new
   `__ContiguousStorageProtocol` refining the base.

## Question

What replaces `@unsafe func pointer(at slot:) -> UnsafeMutablePointer<Element>`
as the single `Storage.Protocol` primitive, expressed in modern Swift (Span
family, not `Unsafe*Pointer`), while preserving (a) `borrowing` semantics,
(b) the zero-witness specialization proven by the capacity pilot, and (c) the
"one primitive, derive the rest" shape — across both contiguous (Heap, Inline)
and sparse (Arena, Pool, Slab) disciplines?

## Analysis

### Finding 1 — `pointer(at:)` fuses two capabilities that modern Swift split on purpose

A raw `UnsafeMutablePointer<Element>` is **init-state-agnostic**: the *same*
handle reads initialized memory, initializes raw memory, and deinitializes it
back. That agnosticism is exactly what made one primitive sufficient — every
lifecycle and access operation could be derived from it. Modern Swift's safety
model **deletes that agnosticism**: each span-family type encodes init-state in
its *type*.

| Modern primitive | read | in-place mutate | bulk/span | **initialize raw slot** | deinit / move-out |
|---|---|---|---|---|---|
| `Span<Element>` | ✅ | — | ✅ (read) | ❌ | ❌ |
| `MutableSpan<Element>` | ✅ | ✅ | ✅ | ❌ (UB to *form* over uninitialized memory) | ❌ (breaks all-initialized invariant) |
| `OutputSpan<Element>` | ✅ via `.mutableSpan` | ✅ | ✅ | ✅ **but frontier/append only** (slot == count) | ✅ `removeLast` (frontier only) |
| (raw pointer — status quo) | ✅ | ✅ | ✅ | ✅ **any slot** | ✅ any slot |

The gap is the bottom-right of the *safe* rows: **random-slot initialization of
an arbitrary `~Copyable` element has no modern-safe primitive.** `MutableSpan`
cannot legally be formed over uninitialized memory; `OutputSpan` only initializes
at the frontier (`slot == count`), which serves Heap-as-array but breaks the
sparse disciplines (Arena/Pool/Slab allocate slot *k* from a free-list / bitmap
while *k−1* is still uninitialized). The only construct that ever unified
frontier-init and arbitrary-slot-init was the raw pointer.

**Consequence**: constraints (1) *one primitive*, (2) *modern-safe*, and the
implicit *derive-everything-including-init* cannot all three hold simultaneously
for the sparse disciplines. One must bend.

### Finding 2 — The `borrowing` constraint is in tension with an existing ecosystem DECISION

The ecosystem has already settled how lifetime-safe mutable access is expressed
(`nonescapable-support-memory-storage-buffer.md`, **DECISION**, and
`yielding-vs-returning-lifetime-models.md`, Tier 2 RECOMMENDATION,
[Verified: 2026-06-02]):

- **`span` properties** → `@_lifetime(borrow self)` + `_overrideLifetime(_, borrowing: self)`. *"The Span cannot outlive the borrow of self. Sound."*
- **`mutableSpan` properties** → `@_lifetime(&self)` + `_overrideLifetime(_, mutating: &self)`. *"Exclusive access prevents aliasing. Sound."*
- **Per-slot mutation** → *"the Property.View pattern with `_modify` accessors already handles this. Verdict: Not needed — MutableSpan + Property.View already cover these patterns."*

The institute's **sound** mutable-span pattern is therefore **exclusive
(`@_lifetime(&self)` / `_modify`), i.e. `mutating`.** `Storage.Inline` already
exposes a sound `.mutableSpan` via `@_lifetime(&self)`.

`pointer(at:)`, by contrast, is **non-mutating** (`borrowing`) yet hands out a
mutable pointer — this is precisely the **CoW-bypass escape hatch** that lives
*outside* the sound model (which is why it is `@unsafe`). Keeping `borrowing`
mutable access therefore does **not** reduce to the sound `@_lifetime(&self)`
pattern; it reproduces the escape hatch with a different vocabulary type. A
`MutableSpan` returned from `borrowing self` aliases storage the caller only
borrows — for reference-backed disciplines (Heap/Arena/Pool/Slab, memory behind
a class reference) this is *no more unsafe than `pointer(at:)` is today* (same
CoW-bypass hazard, now bounds-checked and non-escaping); for `Storage.Inline`
(bytes in `self`'s value via `@_rawLayout`, `Storage.Inline ~Copyable.swift:59-65`,
[Verified: 2026-06-02]) it is an exclusivity violation that no Span construct
launders.

**Consequence**: under constraint (3), the replacement accessor is an
`@unsafe`-backed `MutableSpan`-returning accessor — a strict improvement over a
naked pointer (bounds-checked, non-escaping, no pointer arithmetic capability),
but **not** the sound exclusive pattern. "Keep `borrowing`" ≡ "retain an
`@unsafe` accessor"; the sound alternative is `mutating`, which the principal has
declined for the access path.

### Finding 3 — Only one consumer calls transitions generically through the protocol

The single generic-over-`Storage.Protocol` algorithm file is
`swift-buffer-linear-primitives/Sources/Buffer Linear Primitive/Storage.Protocol+Linear.swift`
([Verified: 2026-06-02] — sole file matching both the `Storage.Protocol`
constraint and generic `pointer(at:)` transition calls; `Buffer.Protocol.swift:91`
documents the contract: *"(`pointer(at:)`, `capacity`) stays in the storage
layer"*). Its `linear*` statics (`linearAppend`, `linearRemoveFirst`,
`linearRemove`, `linearRemoveLast`, `removeAll`, `removeSubrange`) call
`storage.pointer(at:).initialize/move/deinitialize/moveInitialize` over any
conforming storage.

Crucially, `Buffer.Linear` **is itself the linear/contiguous discipline** — its
storage is Heap or Inline, never the sparse Arena/Pool/Slab. So its generic
transitions need only *contiguous/frontier* semantics, which **`OutputSpan`
already provides** — and the buffer-linear layer **already adopts `OutputSpan`**
(`Buffer.Linear+OutputSpan.swift`, `Buffer.Linear.Bounded+OutputSpan.swift`,
`Buffer.Linear+OutputSpan Copyable.swift`, [Verified: 2026-06-02]). The sparse
consumers (e.g. tree/linked structures over `Storage.Arena`) are *concrete* on
their discipline and call that discipline's own `initialize` (e.g.
`Storage.Arena ~Copyable.swift:147`), which lives in the memory-arithmetic tier
below this protocol.

**Consequence**: the transitions do **not** need to be protocol requirements.
The one generic consumer can recompose on `Span.Protocol` + the
already-adopted `OutputSpan`.

### Finding 4 — Any replacement must re-pass the zero-witness SIL gate

The capacity pilot proved `capacity` + `pointer(at:)` specialize to **0
`witness_method` / 0 `class_method`** through `some Storage.\`Protocol\`` in
release + cross-module ([EXP-017]/[EXP-020], `storage-protocol-capacity-pilot.md`).
A `@_lifetime(...) borrowing func mutableSpan(at:) -> MutableSpan<Element>`
witness introduces span-construction (`_overrideLifetime`) into the inlined body;
the replacement must re-run the existing
`Experiments/storage-protocol-heap-sil-gate/` and the pool/inline gate and
re-confirm zero-witness specialization. This is a **new acceptance criterion**
the status-quo primitive already satisfies and the replacement must not regress.

### Options

#### Option A — Span-as-primitive; transitions promoted to protocol requirements

Replace `pointer(at:)` with a per-slot `mutableSpan(at:)` accessor **and** add
`initialize(at:to:)` / `move(at:)` / `deinitialize(at:)` as protocol
requirements (each discipline hand-writes them; their bodies hold the residual
raw-init `@unsafe`).

- **Pro**: eradicates `UnsafeMutablePointer` from the protocol *entirely*,
  including internally. No raw type anywhere on the contract.
- **Con**: violates constraint (1) — expands a deliberately single-primitive
  protocol by three requirements × every conformer; no default implementations
  are possible (nothing generic to build them on). This is drift from the
  current design and was explicitly challenged by the principal.

#### Option B — Demote the raw primitive (keep one primitive, derive everything)

Keep a single raw-slot requirement but mark it `package` / `@_spi` (off the
*public* surface); derive `initialize`/`move`/`deinitialize` as today's generic
extensions, and add a public `mutableSpan(at:)` accessor also derived from it.

- **Pro**: preserves the one-primitive architecture exactly; minimal conformance
  burden; transitions stay derived.
- **Con**: `UnsafeMutablePointer` still exists *in the protocol*, only hidden
  from the public ABI. Fails constraint (2) under the stricter reading ("no
  `UnsafeMutablePointer`, period"), satisfies it under the looser reading ("clean
  *public* surface").

#### Option C — Single modern-safe access primitive; transitions sink below the protocol (RECOMMENDED)

Make the protocol's **one primitive** the modern access span; let the
transitions leave the protocol entirely (they were never genuinely protocol-generic
except in the contiguous `Buffer.Linear` path, per Finding 3).

```swift
public protocol __StorageProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    var capacity: Index<Element>.Count { get }

    // The single primitive. Count-1 span over the (caller-asserted initialized)
    // slot. @unsafe + borrowing preserves the CoW-bypass semantics of pointer(at:);
    // no naked pointer, bounds-checked, non-escaping.
    @unsafe
    @_lifetime(borrow self)
    borrowing func mutableSpan(at slot: Index<Element>) -> MutableSpan<Element>
}
```

Derivations and placements:

- **read / in-place mutate** (former `.pointee` read/write, e.g. tree node
  access) → `storage.mutableSpan(at: s)[0]` / `…[0].field = x`. A **count-1**
  span, because `MutableSpan` asserts its whole extent is initialized — one
  known-initialized slot is well-formed; a from-slot-to-capacity span over
  possibly-uninitialized slots is not.
- **contiguous bulk / C-interop** → the **independent** `Span.Protocol`
  (`span` / `mutableSpan` over `0..<count`), composed as
  `Storage.Protocol & Span.Protocol` (constraint 4 — no refinement;
  this matches the existing `storage-contiguous-protocol-conformance.md` DECISION).
- **`initialize` / `move` / `deinitialize`** → **not** protocol members. The one
  generic consumer (`Storage.Protocol+Linear.swift`) constrains
  `where Self: Span.Protocol` and drives append/remove via the
  already-adopted **`OutputSpan`**. Sparse disciplines call their own backing's
  typed-slot init in the memory tier.

- **Pro**: one primitive; modern (no pointer) on the *entire* protocol surface;
  `borrowing` preserved (constraint 3); no refinement (constraint 4); the
  irreducible raw-init `@unsafe` sinks to the memory-arithmetic tier where it
  belongs, out of `Storage.Protocol`.
- **Con**: `Storage.Inline`'s access stays `@unsafe` even as a span (Finding 2 —
  borrow-aliases self's value). The accessor is `@unsafe borrowing`, **not** the
  sound `@_lifetime(&self)` pattern (Finding 2 — a consequence of constraint 3,
  not of this option). Must re-pass the SIL gate (Finding 4).

### Comparison

| Criterion | A (transitions as requirements) | B (demote raw primitive) | **C (sink transitions)** |
|---|---|---|---|
| One primitive (constraint 1) | ❌ +3 requirements | ✅ | ✅ |
| No `UnsafeMutablePointer` on surface (constraint 2) | ✅ everywhere | ⚠️ public-only | ✅ everywhere |
| `borrowing` preserved (constraint 3) | ✅ | ✅ | ✅ |
| No refinement (constraint 4) | ✅ | ✅ | ✅ |
| Conformance burden | High (3 × N, no defaults) | Lowest | Low |
| Faithful to current single-primitive design | ❌ drift | ✅ | ✅ |
| Residual `@unsafe` location | scattered per-discipline op bodies | one raw primitive per discipline | memory tier + count-1 span ctor + Inline |
| Re-passes zero-witness SIL gate | must verify | must verify | must verify |

## North-Star Requirement Set — the safety / derivation ceiling

The three options above are all shaped by the two locked principal constraints
(*one primitive*, *keep borrowing*). It is worth recording, separately, what the
protocol would look like with those constraints **relaxed** — the maximal-safety,
maximal-derivation ceiling — so the locked-constraint design is understood as a
*conscious trade away from* a known optimum, not as the optimum itself.

```swift
public protocol __StorageProtocol: ~Copyable {
    associatedtype Element: ~Copyable

    var capacity: Index<Element>.Count { get }

    // Initialized-slot access: read + in-place mutate. Yielding accessors —
    // zero @unsafe, sound by construction, ergonomic (storage[s].field = x).
    subscript(slot: Index<Element>) -> Element { read modify }

    // The two irreducible init-state transitions. Fully safe signatures; any
    // unsafe is encapsulated in the conformer body, never on the surface.
    mutating func initialize(at slot: Index<Element>, to element: consuming Element)
    mutating func move(at slot: Index<Element>) -> Element
}
```

One property + three members. Everything else derives.

### Why three transition primitives is the irreducible safe floor

Model a slot as a two-state machine (uninitialized / initialized). The operations
consumers need are the *edges* of that graph:

| Edge | Operation | In the set as |
|---|---|---|
| init → init (read) | read a live slot | `subscript`'s `read` |
| init → init (write) | mutate a live slot in place | `subscript`'s `modify` |
| **uninit → init** | initialize | `initialize(at:to:)` |
| **init → uninit (+extract)** | move-out | `move(at:)` |
| init → uninit (discard) | deinitialize | **derives** from `move` (`{ _ = move(at:) }`) |

The three bolded edges are distinct state transitions. **No safe Swift type
performs two of them** — every safe span-type encodes init-state in its type
(`Span`/`MutableSpan` = all-initialized; `OutputSpan` = frontier). The raw
pointer was "one primitive" only because it is init-state-agnostic, and that
agnosticism is exactly what makes it `@unsafe`. The dichotomy is structural:

> **minimal-unsafe ⟺ three transition primitives. one primitive ⟺ unsafe.**

This is the formal reason the principal's "one primitive" and "modern-safe"
constraints could not both hold (Finding 1, restated as a closed form). The
north-star resolves it by choosing three safe primitives over one unsafe one.
"As few as absolutely necessary" *is four* the moment safety is required.

### What derives for free

Generic extensions over the base, written once: `deinitialize(at:)`,
`deinitialize(range:)`, `swapAt`, `move(from:to:)`, `fill`, `clear`/`removeAll`,
read-only `forEach`/`reduce`/`contains`, `copy(to:)` (`Element: Copyable`).
Composed with the independent `Span.Protocol` (Heap/Inline only):
`span`/`mutableSpan` (sound `@_lifetime(borrow self)` / `@_lifetime(&self)`),
`withUnsafeBufferPointer`/`withMutableSpan`, bulk frontier-init via `OutputSpan`,
`moveInitialize`/range-copy between storages, `Sequence`/`Collection`. Four
primitives → essentially the whole storage + buffer API, generically.

### Safety profile

Zero `@unsafe` on the protocol surface; zero `@unsafe` at any call site. The only
residual unsafe is **encapsulated inside conformer bodies** for `initialize` /
`move`, and even that shrinks — contiguous Heap/Inline frontier-init can use
`OutputSpan` (safe); only arbitrary-slot **sparse** init keeps a genuine unsafe
core in the memory tier. **`Storage.Inline` mutation is safe here**: the `modify`
accessor takes exclusive `&self`, so the borrow-aliasing hazard that makes Inline
irreducibly unsafe under the `borrowing` constraint (Finding 2) does not arise.

### Performance profile

Mutation is `mutating` (exclusive) → CoW is **correct, not bypassed**. For
`~Copyable` elements (unique by construction) this is *free* — no CoW to trigger.
For `Copyable` elements it forks-on-shared-write, which is the correct value
semantics, and Heap's internal CoW (capacity pilot Wave 4) already implements it.
`initialize`/`move` specialize like the pilot's method pattern.

**Performance gate (4)**: do `read`/`modify` yielding accessors *as protocol
requirements* specialize to zero `witness_method`/`class_method` in cross-module
release the way `pointer(at:)` did (Finding 4)? Coroutine accessors should inline
to a direct yielded address under `-O`, but this is the single open performance
question for the north-star and must be settled by re-running the capacity
pilot's SIL gate against a yielding-subscript witness. If yielding accessors
specialize as well as `pointer(at:)`, the north-star is also the *performant*
world; if they carry residual coroutine overhead through the witness, that cost
must be weighed.

### The trade the locked constraints make

| Dimension | North-star | Locked-constraint design (Option C) |
|---|---|---|
| Base requirements | 4 (capacity, subscript{read modify}, initialize, move) | 1 (`borrowing mutableSpan(at:)`) |
| Mutation access | `mutating` — exclusive, **sound** | `borrowing` — shared, **`@unsafe` escape hatch** |
| CoW | triggers correctly (free for `~Copyable`) | bypassed (the purpose of borrowing) |
| `@unsafe` on surface | none | yes (the accessor) |
| Inline mutation | safe | irreducibly `@unsafe` |
| Derive-for-free | maximal | read/mutate + compose; transitions sink out |

The entire gap is two boxes: *keep borrowing* buys the per-element CoW-bypass at
the price of safety; *one primitive* is reachable only by going unsafe. A
`mutating func withMutableSpan(_:)` (scoped exclusive access) recovers most of the
CoW-bypass **soundly** within the north-star (one exclusivity check at the scope
boundary, many in-place writes inside), so the practical cost of relaxing *keep
borrowing* may be smaller than it appears — the principal loses the *non-mutating*
accessor shape and free-standing (non-scoped) span values, not the in-place
multi-write performance itself.

## Constraints and feasibility gates

The recommendation is **contingent** on three type-system gates that must be
verified on the pinned toolchain (Apple Swift 6.3.2, per the capacity pilot)
before any code lands — per [RES-021] (stdlib-conformance verification spike)
and [RES-023] (empirical-claim verification). These are *hypotheses pending
verification*, not established facts:

1. **`@_lifetime(borrow self) borrowing func … -> MutableSpan<Element>` over
   `Element: ~Copyable` on a `~Copyable` `Self`** compiles and specializes. The
   ecosystem's sound `MutableSpan` precedent is `@_lifetime(&self)` (mutating);
   the `borrowing` variant returning `MutableSpan` is the least-precedented
   construct here and the one most likely to fail. (`_overrideLifetime(_, borrowing:)`
   exists for the *read-only* `Span` path; whether it soundly carries a
   *mutable* span from a borrow is the open question.)
2. **`OutputSpan` over `~Copyable` Element** for the `Buffer.Linear` frontier-init
   recomposition — likely already true given the existing
   `Buffer.Linear+OutputSpan.swift` adoption, but must be confirmed for the
   `~Copyable` tier specifically.
3. **Zero-witness SIL gate re-pass** (Finding 4) — re-run
   `Experiments/storage-protocol-heap-sil-gate/` and the pool/inline gate against
   the span-accessor primitive.

If gate (1) fails, the design bends toward **Option B** (the
`borrowing`-returning-`MutableSpan` construct is replaced by a demoted
`@_spi` raw primitive, with the public `mutableSpan(at:)` accessor derived from
it) — which is why B is retained as the documented fallback rather than
discarded.

## Outcome

**Status**: RECOMMENDATION — **Option C** (single modern-safe access primitive;
transitions sink below the protocol), with **Option B** as the documented
fallback if feasibility gate (1) fails.

**Rationale** (per [RES-022] — structural correctness over minimum-diff): Option C
is the only design that honors all four locked principal constraints
simultaneously *and* is faithful to the protocol's deliberate single-primitive
shape. It recognizes that init-state transitions were never truly the protocol's
job — they are the memory tier's — and that the one generic consumer recomposes
cleanly on the already-adopted `Span.Protocol` + `OutputSpan`. The
residual `@unsafe` does not vanish (Finding 1 — it cannot, for random-slot init
of `~Copyable`), but it relocates to the memory-arithmetic tier, off the
`Storage.Protocol` public surface.

**Honest ceiling, recorded so it is not rediscovered as a defect later**:

- This is **not** "make it safe." Under the `borrowing` constraint (3), the
  access primitive is `@unsafe`, and `Storage.Inline`'s case is irreducibly so
  (Finding 2). The win is the *removal of `UnsafeMutablePointer`* and the gain of
  bounds-checking + non-escaping + no-arithmetic-capability — not memory safety.
  The sound alternative (`@_lifetime(&self)`, `mutating`) was declined for the
  access path by principal constraint.
- Random-slot initialization of `~Copyable` elements has no modern-safe primitive
  (Finding 1); the sparse disciplines retain a localized `@unsafe` init core in
  the memory tier regardless of which option is chosen.

**Not implemented.** No code changed. Next steps:

1. Run feasibility gates (1)–(3) above as a `/tmp` + experiment spike on Swift
   6.3.2 ([RES-021]). Report results; if gate (1) fails, switch to Option B.
2. On gate pass, draft the migration plan: protocol edit → 7 conformer rewrites
   (Heap, Inline, Arena, Slab, Pool, Arena.Inline, Pool.Inline) → recompose
   `Storage.Protocol+Linear.swift` on `Span.Protocol` + `OutputSpan`
   → propagate to `Buffer.Linear` and downstream tree/collection consumers.
3. Re-run the SIL gate (Finding 4) as the merge criterion.

This document is **research-first** per [RES-011]: the design question is
resolved (contingent on the gates) before any implementation approach is
attempted, preventing implementation thrashing across 7 conformers.

## Prior Art

**Internal (governs, per [RES-019]):**

- `storage-protocol-capacity-pilot.md` (CONFIRMED, 2026-05-25) — the arc that
  standardized `pointer(at:)` as the primitive and proved zero-witness
  specialization. This document is its de-pointer follow-on.
- `nonescapable-support-memory-storage-buffer.md` (DECISION) — establishes
  `span` via `@_lifetime(borrow self)`, `mutableSpan` via `@_lifetime(&self)`,
  per-slot mutation via `_modify` Property.View as the *sound* patterns. Source
  of Finding 2.
- `yielding-vs-returning-lifetime-models.md` (Tier 2 RECOMMENDATION) — yielding
  (599 sites) vs returning (28 `_overrideLifetime` sites) model trade-offs;
  borrow/inout bindings as the simplifying watch-list feature.
- `storage-contiguous-protocol-conformance.md` (DECISION) — `Span.Protocol`
  as the independent contiguous contract (supports constraint 4, composition not
  refinement).
- `inline-storage-read-pointer-escape.md` (DECISION) — closure-based pointer
  access pattern for `Storage.Inline` (bears on the Inline borrow-aliasing
  caveat, Finding 2).
- `swift-array-primitives/Research/se-0527-rigid-unique-array-alignment.md` —
  `OutputSpan` adoption precedent in the array/buffer layer; the v1.0→v1.1
  amendment ([RES-023] origin) confirming `Buffer.Linear.span`/`.mutableSpan`
  cover only `0..<count`, not the uninitialized tail.

**External:**

- SE-0447 — *Span: Safe Access to Contiguous Storage* (the `Span` / read-only
  primitive). `MutableSpan` / `OutputSpan` are the mutable and
  initializing-frontier counterparts adopted in the buffer layer; their
  institute vetting is captured in the internal docs above rather than re-cited
  here by SE number (SE numbers not independently re-verified at write time —
  [RES-032]).

## References

- `Storage.Protocol.swift:25,35-36` — the current two-member contract.
- `Storage.Inline ~Copyable.swift:59-65` — `@_rawLayout` inline storage (Inline
  borrow-aliasing case).
- `Storage.Arena ~Copyable.swift:147` — sparse-discipline concrete `initialize`.
- `swift-buffer-primitives/.../Buffer.Protocol.swift:91` — *"(`pointer(at:)`,
  `capacity`) stays in the storage layer"*.
- `swift-buffer-linear-primitives/.../Storage.Protocol+Linear.swift` — the sole
  generic-over-protocol transition consumer.
- `Experiments/storage-protocol-heap-sil-gate/` — the zero-witness SIL gate to
  re-pass.
- [EXP-017] release + cross-module validation; [EXP-020] synthetic-to-production
  specialization gap; [RES-011] research-first; [RES-021] verification spike;
  [RES-022] structural-correctness framing; [RES-023] empirical-claim
  verification.
