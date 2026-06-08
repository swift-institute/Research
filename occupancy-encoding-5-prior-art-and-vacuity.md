# Occupancy Encoding 5 — Cross-Language Prior Art and the Vacuity Verdict

<!--
---
version: 1.0.0
last_updated: 2026-06-08
status: DECISION
tier: 3
scope: ecosystem-wide
extends:
  - occupancy-lives-in-the-leaf.md                              # the placement law this corroborates
  - conditional-deinit-conditionally-copyable-generics.md       # the Wall-1 proof + S1-S8 matrix this re-runs
builds_on:
  - canonical-buffer-discipline-cross-language-survey.md        # the Linear/Ring/Slab discipline survey
  - storage-buffer-abstraction-analysis.md                      # storage-strategy-under-one-protocol intractability
  - buffer-storage-associatedtype-prior-art.md                  # T1-T4 storage-exposure taxonomy
---
-->

## Context

A shared investigation (5 angles) asks whether an occupancy-bearing container can achieve
**all** of:

- **(A)** ONE `Store.\`Protocol\`` — no refinement;
- **(B)** guaranteed bit-density (≤ 1 bit/slot occupancy metadata);
- **(C)** value semantics / conditional `Copyable`, with the `.Inline`/`.Small` carve-out
  *types* dissolved into one generic `Buffer<S>`;
- **(D)** self-cleaning teardown (no buffer `deinit`; SE-0427 Wall-1 avoided);
- **(E)** maximal decomposition + clean composition.

The suspected hard core: **bit-dense + value-semantics + inline may be mutually exclusive**
(SE-0427). The ecosystem already converged a placement law in `occupancy-lives-in-the-leaf.md`
(tier-3 DECISION, 2026-06-07): occupancy + teardown live in a single-allocation **leaf**, never
in the buffer, so every `Buffer.<discipline>` is one no-`deinit` generic and the `.Inline`/`.Small`
carve-out **types** dissolve — leaving exactly one honest residual: a bit-dense *inline* sparse leaf
has a `deinit` and is therefore move-only (copyability is spent for that one corner).

**This document is angle 5.** It does two things the prior corpus does not (verified absent via
[RES-019] grep — the existing cross-language surveys cover *discipline taxonomy* and
*allocator-strategy abstraction*, not occupancy *encoding* and not consumer vacuity):

1. **A cross-language occupancy-encoding survey** against primary sources — how mature systems
   reconcile "dense occupancy + value/move semantics + ONE interface" — mapping each encoding to
   A–E and to portability under Swift's `~Copyable` model.
2. **The vacuity census** — enumerating the institute tower's *actual* sparse consumers and
   asking whether **any** real consumer simultaneously needs the provably-excluded corner
   (bit-dense + value-semantics + inline + spare-bit-less element). If none do, the trilemma is
   *vacuous in practice* and the maximal-achievable point **is "all of A–E" for every real
   consumer**.

### Trigger

Shared-problem dispatch (angle 5: cross-language prior art + vacuity verdict), 2026-06-07.
Honest mandate: maximal point + boundary + *is the excluded corner vacuous?* — **no wall claim
without a minimal repro on Swift 6.3.2** (`TOOLCHAINS=org.swift.632202605101a`).

### Constraints

Research only — no tower edits; `/tmp` scratch only for layout confirmation on 6.3.2. Tier-3 rigor
per [RES-020]/[RES-021]/[RES-023]/[RES-024]/[RES-026]/[RES-032]. Per [HANDOFF-013]/[RES-019] this
**extends** the named prior docs rather than re-deriving them; the Wall-1 *proof* belongs to
`conditional-deinit-conditionally-copyable-generics.md` and is cited, not re-litigated (it is
independently re-run here only for the 6.3.2 repro the mandate requires).

## Question

1. Across mature systems (Rust, C++, Zig/Odin), what *encodings* reconcile dense/sparse occupancy
   with value/move semantics under one interface, and which of them port to Swift's `~Copyable`
   model? Map each to A–E.
2. Does any **real** institute sparse consumer need the excluded corner (bit-dense + inline +
   value-semantics + spare-bit-less element)? I.e. **is the trilemma vacuous in practice?**

---

## Part 0 — The 6.3.2 repro (mandate gate)

The shared problem forbids any wall claim without a minimal repro on Swift 6.3.2. The bundle ID
`org.swift.632202605101a` resolves to `Apple Swift version 6.3.2 (swift-6.3.2-RELEASE)` (verified
`TOOLCHAINS=org.swift.632202605101a swift --version`, 2026-06-08). The prior tier-3 note already
ran the full S1–S8 matrix on this exact toolchain; the decisive corners were independently
re-compiled here. `[Verified: 2026-06-08, Swift 6.3.2]`:

| Probe | Construct | Result on 6.3.2 | Meaning |
|---|---|---|---|
| **achievable α** | unconditional `~Copyable` generic leaf + `deinit` (S2) | ✅ compiles | a *move-only leaf* may carry teardown |
| **achievable β** | conditional-`Copyable` generic buffer, **no** `deinit` (S5) | ✅ compiles | a *buffer over a leaf* is fine |
| **α+β assembled** | `Buffer<S5>` over a move-only `S2` leaf | ✅ compiles + `consume`s | the occupancy-lives-in-the-leaf shape **builds** |
| **the corner, concrete** | `@_rawLayout` inline + inline `UInt64` bitmap + `deinit` walking it (a real bit-dense inline sparse leaf) | ✅ compiles, **unconditionally `~Copyable`** | the excluded corner is **expressible as a type** — but move-only |
| **the wall (1/2)** | …same leaf + `extension: Copyable where Element: Copyable` | ❌ `error: deinitializer cannot be declared in generic struct … that conforms to 'Copyable'` | `copyable_illegal_deinit` (SE-0427) bars copyability |
| **the wall (2/2)** | …same, even **without** the deinit | ❌ `error: stored property '_storage' … has non-Copyable type '_Raw'` | `@_rawLayout` storage independently poisons `Copyable` |
| **buffer-level deinit (S1)** | conditional-`Copyable` generic buffer **+** `deinit` | ❌ `copyable_illegal_deinit` | Wall-1, on the buffer — the reason occupancy can't stay in the buffer |
| **tombstone escape** | `InlineArray<count, Element?>`, no deinit | ✅ compiles, **`Copyable`** | density spent (per-slot discriminator), copyability bought |

**The repro establishes the precise shape of the excluded corner.** It is *not* a type that fails
to exist — the bit-dense inline sparse leaf **compiles**. It is a type that cannot *also* be
`Copyable`, for **two independent reasons** that both bind on 6.3.2: (1) the SE-0427 deinit law
(`copyable_illegal_deinit`), and (2) `@_rawLayout` storage being non-`Copyable`. Either alone forces
move-only; together they make the exclusion doubly robust. The only way to recover copyability is the
**tombstone** form (`Element?`), which spends bit-density (a discriminator per slot, not 1 bit/slot).
This is exactly the "one honest residual" of `occupancy-lives-in-the-leaf.md`, now confirmed with a
concrete bit-dense leaf rather than the prior note's abstract `Inner<T>` field.

Scratch artifacts: `/tmp/occ-vacuity/{probes,corner,s1,tombstone}.swift` (Swift 6.3.2, 2026-06-08).

---

## Part 1 — Cross-language occupancy-encoding survey

### Method ([RES-021]/[RES-023]/[RES-032])

Primary sources only (the runtime's actual code/docs, the proposal's actual text); secondary
sources excluded per [RES-032]. Each system is read for its *occupancy encoding* — how it marks a
slot live/dead — and its *teardown-vs-copyability coupling*. The contextualization step ([RES-021])
follows: each encoding is concretized in the institute's type system before being called portable or
not.

### 1.1 Rust — the linchpin (same `Drop ⟹ !Copy` law, escapes by layout)

Rust's `Drop ⟹ !Copy` (rustc **E0184**) and *no conditional `Drop`* (rustc **E0367**) are the
exact twins of Swift's `deinit ⟹ ~Copyable` (SE-0427 / `copyable_illegal_deinit`) — established by
`conditional-deinit-conditionally-copyable-generics.md` and not re-argued here. What angle 5 adds is
the **slot-container encoding** layer on top of that law:

| Crate | Occupancy encoding | Teardown ↔ copyability | A–E mapping |
|---|---|---|---|
| **`slab`** | `enum Entry<T> { Occupied(T), Vacant(next: usize) }` per slot — the discriminator **is** the free-list link | `Vec<Entry<T>>` owns drop; container is `Clone where T: Clone`, never `Copy` | dense-ish (enum tag, **not** 1 bit/slot), value-sem ✓, ONE type ✓ — **(B) fails** (tag ≥ 1 byte) |
| **`slotmap::SlotMap`** | `(value, version: u32)` slots in a `Vec`; **even/odd version = vacant/occupied** (parity oracle — *exactly* `Storage.Arena.Meta.token`) | historically **required `V: Copy`** "due to current stable Rust restrictions"; relaxed once layout reworked ("slotmap now supports all types on stable") | dense slots, parity occupancy (≈ 1 bit *semantically*, stored in a u32), **(C) once cost the `Copy` constraint** |
| **`slotmap::DenseSlotMap`** | **two arrays**: a dense `Vec<T>` (packed values) + a slot array of `(index, version)` — "two indirections per random access; the slots contain indices used to access the contiguous memory" | no `Copy` requirement — values live in their own contiguous `Vec` that owns drop | the **SoA escape**: relaxes (C) by *moving values to a separate contiguous allocation* = the `Storage.Arena` move |
| **`generational-arena` / `thunderdome`** | `Vec` of `{ generation: u64/u32, data: Option<T> }`; 8-byte `Index` (NonZero-packed even inside `Option`) | `Clone where T: Clone`; drop via the `Vec`; no `Copy` requirement (uses `Option<T>`, i.e. a tombstone) | generational occupancy, value-sem ✓ via tombstone — **(B) traded** (the `Option<T>` discriminator) |

**The decisive Rust finding** (verified against orlp/slotmap `src/lib.rs` primary source, [Verified:
2026-06-08]): `SlotMap`/`HopSlotMap` *historically required `V: Copy`* precisely because their
**dense `(value, version)` slot layout** could not run a destructor for live slots without the
`Drop`/`Copy` conflict — *the identical wall the institute hit*. The two escapes Rust shipped are
**exactly** the institute's two:

1. **`DenseSlotMap`** moves values into a **separate dense `Vec`** that owns `Drop` (SoA) — the
   `Storage.Arena` / `DenseSlotMap`-style packed-array move. This is the **(C) relaxation by layout**.
2. **`Option<T>` tombstones** (generational-arena) spend density to keep `Clone` — the **(B)-for-(C)
   trade**, the Swift `Element?` form.

Rust has **no** language feature that gives bit-dense + inline + `Copy` simultaneously. The
`Slottable` "Copy required" trait was *deprecated by reworking the layout*, not by a `Drop` change.
**The institute is not missing a Rust trick** — it is on the same equilibrium.

### 1.2 C++ — the one model that decouples the axes (and why it does not port)

| Mechanism | Occupancy encoding | Teardown ↔ copyability | Portability to `~Copyable` Swift |
|---|---|---|---|
| `std::optional<T>` | separate `bool` engaged-flag + storage for `T` (no niche/spare-bit optimization in the standard layout — `sizeof(optional<int>) > sizeof(int)`) | destructor is **trivial iff `T` trivially-destructible** (P0848R3 conditionally-trivial SMF); a user dtor only *deprecates* the copy, does not delete it | **does not port** — C++ keeps destructor ⊥ copyability orthogonal; Swift couples them deliberately (SE-0427) |
| `[[no_unique_address]]` | lets an empty/occupancy companion take 0 bytes when adjacent | orthogonal to teardown | **partially**: Swift's `@_rawLayout` + inline bitmap already achieves the no-padding inline layout; the *coupling* problem is untouched |
| `plf::colony` / **`std::hive`** (C++26) | a **skipfield** (low-complexity jump-counting pattern) parallel to the element blocks — counts runs of erased elements for O(1) branchless skip; **not** 1 bit/slot (it stores *jump counts*, wider than a bit) | element blocks own destruction; container is copyable when `T` is | **shape ports** as a *sparse leaf* (skipfield = an in-leaf occupancy oracle, SoA), but it is **not bit-dense** (jump-counts > 1 bit) and inline-`hive` would face the same Swift coupling |
| `boost::container::flat_map/flat_set` | **no occupancy metadata** — sorted contiguous vector, "occupied" = "present in [begin,end)" | trivial — it is just a `vector` | this is the **dense (B)-trivial** case: occupancy *is* the range, no bitmap. Maps to `Buffer.Linear`'s range-ledger |

The C++ conditionally-trivial destructor (`std::optional`/`std::variant`, generalized by **P0848R3**)
is the *one* model that expresses "trivial for some instantiations, non-trivial for others." It does
not port for the reason the prior note established and [RES-021] formalizes: C++'s destructor is a
**separate special member** from the copy constructor; *the presence of a destructor is not the
copyability switch*. Swift (and Rust) make destructor-presence *be* the switch. Importing C++'s
escape would mean decoupling the very axes Swift's safety model couples — i.e. it is not a portable
encoding, it is a different language.

### 1.3 The SwissTable control-byte plane — bit-dense occupancy that *does* port

Rust `hashbrown` (and Abseil/Google SwissTable) store occupancy in a **control-byte plane**: one
byte per slot, grouped into SIMD-scannable groups of 16 — `EMPTY` (`0xFF` / high bit set), `DELETED`
(tombstone, high bit set), or a 7-bit `h2` hash fingerprint (high bit clear). Lookups SIMD-compare
the fingerprint across a group before touching keys. Verified against rust-lang/hashbrown primary
description, [Verified: 2026-06-08].

| Property | SwissTable control plane |
|---|---|
| occupancy density | **1 byte/slot** (control byte), not 1 bit — but the byte does double duty (occupancy + fingerprint + tombstone) |
| layout | the control plane is a **separate parallel allocation** (SoA) from the slots — *exactly* `Buffer.Slots` / `Storage.Split` |
| teardown ↔ copyability | the slots' `Vec`/allocation owns drop; the table is `Clone where T: Clone`, never `Copy` |
| A–E mapping | the SoA-control-plane *is the leaf-occupancy move*: occupancy lives in the same single logical allocation as the slots, teardown on that allocation, the *container* is a thin generic |

The SwissTable plane is the **strongest external corroboration of the placement law**: a
mature, performance-critical sparse container puts its occupancy oracle (the control bytes) in the
**same SoA allocation as the elements** and lets that allocation own teardown — making the container
type itself a thin generic with no per-instantiation destructor entanglement. It is the
`Storage.Split` / `Storage.Arena` shape, vindicated at scale. (It is byte-dense, not bit-dense, by a
*deliberate* speed choice — the spare 7 bits hold the fingerprint — not because a bit was unreachable.)

### 1.4 Zig / Odin — manual, no copyability coupling

Zig's `std.MultiArrayList` (SoA: a separate slice per field, including any occupancy/tag field) and
the explicit-`Allocator` model carry **no copyability concept at all** — Zig has no `Copy`/`Drop`
trait system; teardown is a manual `deinit(allocator)` call. Occupancy, when present, is a normal SoA
field or an external bitset. There is no coupling to escape, so there is no encoding to port — Zig
simply *does the SoA move by default* (every container is MultiArrayList-shaped) and pushes teardown
to an explicit call. This is the **degenerate confirmation**: when the language does not couple
teardown to copyability, the natural layout is already "occupancy + teardown in the (SoA) leaf."
(Confirmed against the existing `buffer-storage-associatedtype-prior-art.md` Zig survey; not
re-fetched.)

### 1.5 Encoding → A–E → portability synthesis

| Encoding (source) | (A) one iface | (B) ≤1 bit/slot | (C) value/cond-Copyable | (D) self-clean, no buffer deinit | (E) decompose/compose | Ports to `~Copyable` Swift? |
|---|---|---|---|---|---|---|
| **range-ledger** (flat_map; `Buffer.Linear`) | ✓ | ✓ (occupancy = the range; **0 bits/slot**) | ✓ (cond-Copyable; teardown in leaf) | ✓ | ✓ | **Already shipped** (dense leaf) |
| **SoA packed array** (DenseSlotMap; EnTT dense+sparse; SwissTable plane; Zig MAL; `Storage.Arena`) | ✓ | ✓ heap (bitmap/gen 1 bit or 1 byte in the *one* leaf alloc) | ✓ heap (class-backed → cond-Copyable) | ✓ (leaf/backing owns teardown) | ✓ | **Already shipped** (sparse heap leaf = `Storage.Arena`) |
| **dense `(value,version)` slots** (slotmap `SlotMap`) | ✓ | ✓ (parity in the version word) | **✗ inline** (the historic `V: Copy` wall) / ✓ heap | ✗ inline / ✓ heap | ✓ | inline: **NO** (the corner); heap: yes |
| **enum/Option tombstone** (slab; generational-arena; `Element?`) | ✓ | **✗** (discriminator ≥ 1 byte/slot) | ✓ (no deinit needed) | ✓ | ✓ | **Yes — but spends (B)** |
| **conditionally-trivial dtor** (C++ `std::optional`, P0848R3) | ✓ | depends | ✓ + inline + dense **simultaneously** | ✓ | ✓ | **NO** (requires decoupling dtor from copyability — not Swift's model) |

**Reading of the matrix.** Every encoding that achieves **B + C + inline simultaneously** is either
(i) the C++ conditionally-trivial-destructor model, which is *non-portable* because it decouples the
two axes Swift couples, or (ii) the tombstone model, which achieves C + inline by *abandoning B*. No
surveyed system — including Rust, the closest twin — achieves bit-dense + value-semantics + inline
together under the `Drop ⟹ !Copy` law. Rust *had* the dense-inline-`Copy` case and **removed it by
moving to SoA** (DenseSlotMap) or tombstones. **The institute's excluded corner is the universal
excluded corner among copyability-coupled languages.** ([RES-021] contextualization: the
*restriction* is the cross-language norm; only the decoupled C++ model escapes, at the cost of the
safety property Swift wants. The absence in Swift is a deliberate equilibrium, not a gap.)

This **corroborates `occupancy-lives-in-the-leaf.md` from the outside**: the two universally-shipped
escapes (SoA-packed and tombstone) are exactly the law's two legs — the heap/SoA sparse leaf
(`Storage.Arena`, DenseSlotMap, SwissTable) gets A+B+C+D+E, and the inline corner keeps A+B+D+E but
spends C (move-only), with tombstone as the C-for-B swap.

---

## Part 2 — The vacuity census

### Method ([RES-023] empirical-claim verification)

The trilemma's excluded corner is *bit-dense + value-semantics + inline + spare-bit-less element*.
The corner matters **only if some real consumer needs all four at once.** This section enumerates the
institute tower's actual sparse-discipline consumers and classifies each by (backing it instantiates,
element type, whether it needs inline, whether it needs value-semantics on an inline form). Every row
is grep-verified against the live `swift-primitives` / `swift-foundations` / `swift-standards` trees
(not from memory), 2026-06-08. "Real consumer" excludes the owning buffer/slab/tree package families
themselves (which only *declare/export* the variants), `Tests/`, `Experiments/`, and `.build/`
mirrors.

### 2.1 The sparse disciplines and their real consumers

| Discipline | Real consumer(s) | Backing instantiated | Inline? | Value-sem on inline? |
|---|---|---|---|---|
| **`Buffer.Slab`** | `Dictionary` (slab-backed hash map); `Slab<Element>` (user container) | `Buffer<Storage<Key>.Contiguous<Memory.Heap<Key>>>.Slab` and `…<Value>…` (file: `Dictionary.swift:99-101`, `Dictionary+CoW.swift:172-173`, `Dictionary ~Copyable.swift:48-49`) | **No — heap** | n/a |
| **`Buffer.Arena`** | `Tree.N` / `Tree.Binary`; `Tree.Keyed`; `Tree.Unbounded`; `Async.Timer.Wheel` | `Buffer<Storage<Node>.Arena>.Arena` (`Tree.N.swift:72`); `Buffer<Storage<Node>.Arena>.Arena.Bounded` (`Async.Timer.Wheel.Storage.swift:42`) | **No — heap** (`.Bounded` is a *capacity* axis, still heap) | n/a |
| **`Buffer.Linked`** | `List.Linked<E,N>`; `Queue.Linked`; `Async.Timer.Wheel.Payload` | `Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linked<N>` (`List.Linked.swift:78`) | **No — heap** | n/a |

Every real sparse consumer instantiates a **heap** leaf. `Dictionary` (the highest-traffic
`Buffer.Slab` consumer) is `Memory.Heap`-backed; all three `Tree` families and the timer wheel use
the shipping `Storage.Arena` heap leaf; the linked structures use `Memory.Heap`.

### 2.2 The excluded-corner probe — who instantiates an inline-sparse variant?

The corner is *inline*. So: does any non-owning consumer, anywhere in the ecosystem, instantiate
`Slab.Static`, `Buffer.Slab.Inline`, `Buffer.Slab.Small`, `Buffer.Arena.Inline`, `Buffer.Linked.Inline`,
`Storage.Arena.Inline`, or any sibling inline-sparse form?

Grep across **all three orgs** (`swift-primitives`, `swift-foundations`, `swift-standards`),
excluding `.build/`, `Tests/`, `Experiments/`, `.swift-lint/`, and the owning buffer/slab/tree
package families, for instantiation syntax (`X.Inline[<(]`, `X.Small[<(]`, `X.Static[<(]`):

> **Result: zero.** The only residual matches are *self-references inside the
> `swift-storage-arena-primitives` package's own `Storage.Arena.Inline` declaration and doc-comment
> files* (`Storage.Arena.Inline.swift:21,40`, `Storage.Arena.Inline ~Copyable.swift:183`) — i.e. the
> type declaring itself, not a consumer using it. No `Package.swift` outside the buffer family lists
> any inline-sparse product (`Buffer Slab Inline`, `Buffer Arena Inline`, `Buffer Linked Inline`, …)
> as a dependency. `swift-foundations` (4 614 `.swift` files) yields **no** inline-sparse
> instantiation.

The inline-sparse variants are **declared and exported but instantiated by no one** outside their own
package families. They are uninhabited corners of the tower.

### 2.3 The spare-bit dimension (the fourth conjunct)

Even setting inline aside, the corner additionally requires a **spare-bit-less element** — because if
the element type *had* spare bits, a niche/payload-in-spare-bits encoding could in principle store
occupancy *inside* the element (Rust's `NonZero`-in-`Option` trick), sidestepping the bitmap and thus
the deinit-walk-the-bitmap that forces move-only. The real consumers' element types are:

- `Dictionary` → `Key` / `Value` (arbitrary user types — generic, no guaranteed spare bits, but also
  **heap-backed**, so the corner is already not hit);
- `Tree.*` → `Node` (an arena node — heap-backed);
- `List.Linked` / `Queue.Linked` → arbitrary `Element` (heap-backed);
- `Async.Timer.Wheel` → timer `Node` (heap-backed, `.Bounded`).

No real consumer pairs an inline sparse backing with a spare-bit-less element, because **no real
consumer uses an inline sparse backing at all**. The fourth conjunct is moot once the third (inline)
is shown uninhabited.

### 2.4 Why the heap leaf already gives every real consumer A–E

For every real consumer (all heap-backed), the shipping `Storage.Arena` pattern (and the
relocated-Slab-leaf / restored-free-list-leaf the law prescribes) delivers **all of A–E**:

- **(A)** one `Store.\`Protocol\`` — the heap leaf conforms it; the buffer is generic over it.
- **(B)** ≤ 1 bit/slot — the bitmap (Slab) is 1 bit/slot *inside the leaf's single allocation*; the
  generation oracle (Arena) is a parity bit in a word it needs anyway; the free-list link reuses the
  slot. Bit-density is preserved because the occupancy lives in the leaf's one allocation.
- **(C)** value semantics / conditional `Copyable` — the *heap* leaf is class-backed, so it is
  `Copyable where Element: Copyable` (the `Storage.Arena` / `Swift.Array` posture). The buffer over it
  is the same.
- **(D)** self-cleaning teardown, no buffer `deinit` — teardown lives on the leaf's backing class
  (`Storage.Arena.Backing.deinit`, generation-token iteration), exactly as the law requires; the
  buffer carries no `deinit`, so Wall-1 never fires.
- **(E)** maximal decomposition + clean composition — `Buffer.<discipline>` is one thin generic over
  `Store.Sparse.\`Protocol\``; the `.Inline`/`.Small` *types* dissolve; `.Bounded` (a capacity axis)
  is retained as already-lawful.

### 2.5 The vacuity verdict

> **VACUOUS — YES.** No real institute consumer hits the excluded corner. Every sparse consumer
> (`Dictionary`, `Slab`, `Tree.N`/`Keyed`/`Unbounded`, `List.Linked`, `Queue.Linked`,
> `Async.Timer.Wheel`) is **heap-backed**, and the heap sparse leaf delivers **all of A–E**
> simultaneously. The inline-sparse variants are declared/exported but **instantiated by no
> non-owning consumer anywhere** in primitives, foundations, or standards. The corner that the
> trilemma proves impossible — bit-dense + value-semantics + inline + spare-bit-less element — is
> **uninhabited in practice.**

Therefore the **maximal-achievable point IS "all of A–E" for every real consumer.** The trilemma is
real (Part 0 reproduces its teeth on 6.3.2; Part 1 shows it is the universal excluded corner among
copyability-coupled languages), but it is a statement about an **empty corner of the design space**.
The only cost the trilemma extracts — move-only-ness of a bit-dense *inline* sparse leaf — is paid by
**no current consumer**, and were one to appear, it would pay it as a single move-only *leaf* (one
type, not a family), with the tombstone (`Element?`) form available as the C-for-B swap.

---

## Outcome

**Status: DECISION.** (Corroborates and extends the 2026-06-07 `occupancy-lives-in-the-leaf.md`
DECISION from two independent directions; introduces no new tower disposition — it supplies the
prior-art and vacuity *evidence* the placement law asserted as its "one honest residual.")

1. **The trilemma is real but its excluded corner is the universal one.** Independently reproduced on
   Swift 6.3.2 (`org.swift.632202605101a`): a bit-dense inline sparse leaf compiles but is
   unconditionally `~Copyable`, blocked *doubly* (SE-0427 `copyable_illegal_deinit` **and**
   `@_rawLayout` non-`Copyable` storage). The cross-language survey shows this is the same corner
   excluded by Rust (which removed its dense-inline-`Copy` case by moving to SoA/tombstones), and
   escapable only by C++'s destructor⊥copyability decoupling, which does not port to Swift's safety
   model. **Bit-dense + value-semantics + inline = pick two** is a cross-language law, not a Swift
   defect.

2. **The corner is vacuous in practice.** Every real institute sparse consumer is heap-backed; the
   heap sparse leaf (`Storage.Arena` and the law's relocated-Slab / restored-free-list leaves)
   delivers **all of A–E** at once. No non-owning consumer instantiates any inline-sparse variant
   anywhere in the ecosystem. **The maximal-achievable point is "all of A–E" for every real
   consumer.**

3. **The encodings that port are the two the law already prescribes.** The SoA-packed sparse leaf
   (DenseSlotMap / EnTT dense+sparse / SwissTable control plane / Zig MultiArrayList / `Storage.Arena`)
   gives A+B+C+D+E heap; the tombstone form (`Element?`) gives A+C+D+E inline by trading B. The C++
   conditionally-trivial-destructor model is the only thing that would give all-three-on-inline and it
   is non-portable. No external system offers a fourth option.

### Implications for the tower (evidence, not new edits)

- The `decomposition-layer-placement-package-map.md` §C.3 / line-4312-entry "HARD-FLOOR LINE" that
  retained `Buffer.{Slab,Linked,Arena}.{Inline,Small}` as forced keeps is *already* superseded by
  `occupancy-lives-in-the-leaf.md`; **this census supplies the missing empirical backing** for that
  supersession: the hard-floor was retained on the premise that the inline-sparse corner is
  load-bearing, and the census shows it has **zero inhabitants.** The dissolution of the inline-sparse
  *types* (per the law's Implementation §) strands no consumer.
- The one genuinely move-only artifact that survives — a bit-dense inline sparse *leaf*, should any
  future consumer need one — is already modeled by `Memory.Inline` (the dense move-only inline leaf,
  `@_rawLayout` + `Store.Initialization` ledger + self-cleaning deinit, `Memory.Inline.swift:41-114`).
  A sparse inline leaf is the same shape with a per-slot occupancy oracle; it compiles on 6.3.2 (Part
  0) and would be one type, not a carve-out family.

### Residual (premise vs direction, per [RES-027])

- **Direction (not load-bearing):** if a future consumer genuinely needs a bit-dense inline sparse
  container *with value semantics*, the C-for-B tombstone swap or the move-only leaf are the answers;
  the conditional-`deinit` Swift Evolution pitch (PITCH-0003, held per
  `conditional-deinit-conditionally-copyable-generics.md` move 3) is the only thing that would lift
  the corner, and a single hypothetical consumer is below the [PITCH-PROC-002] evidence bar. No
  experiment owed — the corner is empirically uninhabited (§2.2), so there is no premise to refute.
- **Verified empirical claims** (this doc): all consumer-backing rows (§2.1) cite file:line; the
  zero-inline-consumer result (§2.2) is a live grep across three orgs; the 6.3.2 compile results (Part
  0) are reproduced in `/tmp/occ-vacuity/`. [Verified: 2026-06-08].

## References

### Primary — Swift compiler / 6.3.2 repro
- Toolchain `org.swift.632202605101a` = Swift 6.3.2 (`swift-6.3.2-RELEASE`), verified `swift --version`.
- `copyable_illegal_deinit` diagnostic — reproduced on 6.3.2; scratch `/tmp/occ-vacuity/corner.swift`, `s1.swift`.
- `@_rawLayout` non-`Copyable`-storage poison — reproduced on 6.3.2; `/tmp/occ-vacuity/corner.swift`.
- The achievable corners (S2/S5/assembled/tombstone) — reproduced on 6.3.2; `/tmp/occ-vacuity/probes.swift`, `tombstone.swift`.

### Primary — cross-language sources ([Verified: 2026-06-08])
- Rust `slotmap` — orlp/slotmap `src/lib.rs` (deprecated `Slottable`: "slotmap now supports all types on stable"; `SlotMap` `(value, version)` slots vs `DenseSlotMap` "two indirections … slots contain indices used to access the contiguous memory"); https://docs.rs/slotmap/ ; https://github.com/orlp/slotmap.
- Rust `slab` — `enum Entry<T> { Occupied(T), Vacant(usize) }`; https://docs.rs/slab/.
- Rust `generational-arena` / `thunderdome` — `{ generation, data: Option<T> }`; 8-byte NonZero-packed `Index`; https://docs.rs/generational-arena/ ; https://docs.rs/thunderdome/ ; https://github.com/lpghatguy/thunderdome.
- Rust `hashbrown` SwissTable — control-byte plane (EMPTY/DELETED/7-bit h2), groups of 16, SIMD probe; https://github.com/rust-lang/hashbrown.
- C++ `plf::colony` / `std::hive` — low-complexity jump-counting skipfield; https://plflib.org/colony.htm ; P0447 (https://isocpp.org/files/papers/P0447R19.html).
- C++ P0848R3 — conditionally-trivial special member functions; https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p0848r3.html.
- C++ `std::optional` layout (separate bool + storage; trivial dtor iff `T` trivially-destructible) — cppreference (corroborated via `conditional-deinit-conditionally-copyable-generics.md` §C++ which verified the destructor-triviality clause).
- EnTT sparse-set — dense (packed, insertion-order) + sparse (entity-id→dense-index) arrays; https://github.com/skypjack/entt/blob/main/src/entt/entity/sparse_set.hpp ; https://skypjack.github.io/2020-08-02-ecs-baf-part-9/.
- Rust E0184 / E0367 (the `Drop ⟹ !Copy` / no-conditional-`Drop` law) — established in `conditional-deinit-conditionally-copyable-generics.md`; not re-fetched.

### Primary — institute source (file:line, [Verified: 2026-06-08])
- `swift-storage-arena-primitives/.../Storage.Arena.swift:75-278` — the shipping sparse **heap** leaf (value façade over a `Backing` class; parity-token occupancy `Meta:113-135`; generation-token teardown `deinit:245-255`; conditional `Copyable:278`).
- `swift-memory-inline-primitives/.../Memory.Inline.swift:41-114` — the dense **inline** move-only leaf (`@_rawLayout` + `Store.Initialization` ledger + self-cleaning `deinit`; the `_deinitWorkaround` for swift#86652 at `:59-60`).
- `swift-buffer-slab-primitives/.../Buffer.Slab.swift:34-90`, `Buffer.Slab.Header.swift:24-34` — occupancy bitmap held in the buffer's `Box` (the located bug the law relocates to the leaf).
- `swift-dictionary-primitives/.../Dictionary.swift:99-101` + `Dictionary+CoW.swift:172-173` — `Buffer<Storage<Key>.Contiguous<Memory.Heap<…>>>.Slab` (heap-backed real consumer).
- `swift-tree-n-primitives/.../Tree.N.swift:72` — `Buffer<Storage<Node>.Arena>.Arena` (heap).
- `swift-async-primitives/.../Async.Timer.Wheel.Storage.swift:42` — `Buffer<Storage<Node>.Arena>.Arena.Bounded` (heap + capacity axis).
- `swift-list-linked-primitives/.../List.Linked.swift:78` — `Buffer<Storage<Element>.Contiguous<Memory.Heap<…>>>.Linked<N>` (heap).

### Internal ([RES-019])
- `occupancy-lives-in-the-leaf.md` (tier-3 DECISION, 2026-06-07) — the placement law this corroborates; its "one honest residual" is the corner this doc proves vacuous-in-practice.
- `conditional-deinit-conditionally-copyable-generics.md` (tier-3, 2026-06-06) — the Wall-1 proof (S1–S8) + Rust/C++ prior-art; this doc extends its survey to the slot-container encoding layer and adds the vacuity census.
- `canonical-buffer-discipline-cross-language-survey.md`; `storage-buffer-abstraction-analysis.md`; `buffer-storage-associatedtype-prior-art.md` — the existing discipline-taxonomy / allocator-strategy / storage-exposure surveys this builds on (none of which cover occupancy *encoding* or consumer vacuity).
- Skills: [DS-023] (occupancy lives in the leaf), [MEM-COPY-016] (Wall-1 law), [MEM-SAFE-027] (Wall-2 `_deinitWorkaround`).
