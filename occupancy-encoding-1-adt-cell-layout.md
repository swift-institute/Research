# Occupancy Encoding (1) — ADT Cell Layout and the Extra-Inhabitant Frontier

<!--
---
version: 1.0.0
last_updated: 2026-06-08
status: DECISION
tier: 3
scope: ecosystem-wide
toolchain_of_record: Apple Swift 6.3.2 (swift-6.3.2-RELEASE, TOOLCHAINS=org.swift.632202605101a), arm64-apple-macosx26.0
extends:
  - occupancy-lives-in-the-leaf.md                          # the placement LAW (occupancy in the leaf)
  - occupancy-encoding-4-placement-proof.md                 # the information-floor + placement-lattice + satisfiability theorem (the cell is one row of its matrix)
  - conditional-deinit-conditionally-copyable-generics.md   # the SE-0427 Wall-1 proof + S1–S8 matrix
consumes_as_axiom:
  - "occupancy-encoding-4-placement-proof.md §I.4"          # xi(Element) cost function + niche table (this note engineers the cell that fills that row)
---
-->

> **One-line result.** Attack the occupancy problem at the *element cell*. The cell
> `Slot<E> = Optional<E>` is the maximal point reachable purely at the ADT layer: it
> achieves **(A) one neutral `Store.Protocol` (no `Store.Sparse`), (D) self-cleaning with
> no `deinit`, (E) maximal decomposition** *unconditionally for all E*, and **(C)
> conditional value-semantics for all E** — because Swift's stdlib `Optional` is *already*
> `~Copyable`/`~Escapable`-aware (verified: `arm64-apple-macos.swiftinterface:16176`). It
> achieves **(B) ≤1-bit (in fact 0-marginal-bit) density iff `E` exports ≥1 extra inhabitant
> (a "niche")**, and the niche test is **automatic and derivable for free** — recursively
> through struct nesting and across aggregate fields, with no `BitPackable` protocol needed.
> The **exact residual**: for `E` with `xi(E)=0` (full-domain integers, padding-free PODs)
> the cell forces a stride-rounded tag (measured `Int? ` = 16 B/slot = 64 bit/slot), so a
> spare-bit cell is *unreachable* and the only ADT-level recovery is **manual bit-stealing**
> (nominate a sentinel value), which spends one value from `E`'s domain and forfeits
> `Optional`'s totality. That residual is **not vacuous** but it is **costed, not forbidden** —
> it is exactly the `(B)`-vs-everything-else tension the placement law isolates, viewed through
> the cell.

---

## Context

This is **angle 1** of the shared occupancy-encoding research program (a multi-agent attack
on the same problem; siblings: `occupancy-encoding-4-placement-proof.md` — placement proof &
information floor). The shared problem: find and *prove* how far Swift's type system can
encode an occupancy-bearing container achieving all of (A)–(E):

- **(A)** ONE `Store.\`Protocol\`` — no `Store.Sparse` refinement.
- **(B)** Guaranteed bit-density occupancy: ≤1 bit/slot, not a per-element tag.
- **(C)** Value semantics / conditional `Copyable` where wanted, with the `.Inline`/`.Small`
  carve-out *types* dissolved into one generic `Buffer<S>`.
- **(D)** Self-cleaning teardown: no buffer `deinit`; SE-0427 Wall-1 avoided.
- **(E)** Maximal decomposition + clean composition.

My assigned angle is the **element CELL and its bit-level layout**: determine whether a
`Slot<E>` ADT can achieve guaranteed ≤1-bit occupancy *and* self-cleaning for all `E`, or
characterize **exactly** the `E` for which it is free vs. costed, with measured `MemoryLayout`
evidence on 6.3.2.

The companion angle-4 note proves the *information-theoretic* and *placement* frontier and
treats the cell (`E_tag`) as one encoding among three (ledger / bitmap / tag), summarized in a
6-row niche table (§I.4). **This note is the engineering companion**: it goes inside the cell
ADT — the `~Copyable` story stdlib already ships, the custom-vs-stdlib equivalence, the
*recursive automatic* niche discovery, the manual bit-stealing escape and its ownership
mechanics, and the full element-class taxonomy. It **does not re-derive** angle-4's floor; it
consumes §I.4 as an axiom and builds the cell that fills that row.

### Trigger

Tier-3 shared dispatch (2026-06-08): "Find — and PROVE — how far Swift's type system can
encode an occupancy-bearing container achieving all of (A)–(E) … YOUR ANGLE: algebraic-data-
type & cell-layout engineering. Determine whether a `Slot<E>` can achieve guaranteed ≤1-bit
occupancy AND self-cleaning for all E — or characterize EXACTLY the E for which it is free vs.
costed, with measured `MemoryLayout` evidence on 6.3.2."

### Constraints

Read-only on institute production (file:line cited, non-mutating). All spikes compiled & run
on **Apple Swift 6.3.2** (`swift-6.3.2-RELEASE`, `TOOLCHAINS=org.swift.632202605101a`,
arm64-apple-macosx26.0) — never a dev snapshot; no compiler-wall claim without a minimal
repro. Tier-3 rigor per [RES-020]/[RES-023]/[RES-024]/[RES-026]; probe the real compiler before
any "impossible"/"can't be expressed" claim per `feedback_convention_vs_typesystem_constraint`.
Research only — no tower-package edits; `/tmp/occ-cell/` scratch.

## Question

Can an ADT cell `Slot<E>` achieve **guaranteed ≤1-bit occupancy AND self-cleaning for all E**?
If not for all `E`, characterize *exactly* the `E` for which it is free vs. costed, and prove:

1. `Optional<E>` extra-inhabitant behavior — measured `MemoryLayout<E?>` vs `MemoryLayout<E>`
   across representative element classes (class ref; enum with spare cases; `Bool`; small
   fully-packed POD; `Index`/pointer; `~Copyable` types).
2. Can a `SpareBit`/`BitPackable` protocol exposing a usable extra-inhabitant (with a tagged
   fallback) be made **automatic/derivable**? Can it be `~Copyable`-aware?
3. Whether a `Slot` ADT is `BitwiseCopyable`/trivially-destructible exactly when `E` is, so the
   leaf's *automatic* value-witness self-cleans (no custom deinit) — proving (D) for the cell.
4. Manual extra-inhabitant / bit-stealing for pointer- or index-typed elements.

---

## Axioms (consumed, not re-proved)

| # | Axiom | Source |
|---|-------|--------|
| **AX-L** | Liveness + teardown live in a single-allocation *leaf*, never the buffer; the buffer is a thin no-`deinit` generic. | `occupancy-lives-in-the-leaf.md` (DECISION, ratified 2026-06-07) |
| **AX-4** | `xi(Element) ≥ 1` ⟹ `Optional<Element>` tag costs **0 marginal bits** (niche-fill); `xi=0` ⟹ tag rounds to stride, ≥8 bit/slot. Niche table for {class, Bool, enum, ptr, UInt8, Int} measured on 6.3.2. | `occupancy-encoding-4-placement-proof.md` §I.4, Thm I.3 |
| **AX-1** | A conditionally-`Copyable` *generic* value type cannot declare any `deinit` (`copyable_illegal_deinit`); SE-0427 — *"Deterministic destruction requires the type to be unconditionally noncopyable."* | `conditional-deinit-conditionally-copyable-generics.md` (S1, S6; SE-0427 §"Conformance to Copyable") |
| **AX-S7** | Swift *already* performs conditional **automatic field** teardown: a `~Copyable` field's `deinit` runs for the `~Copyable` instantiation; a `Copyable` field is trivial. | same note, S7 (runtime-verified) |

This note's contribution is orthogonal to all four: it engineers the **cell ADT** that, placed
in the leaf per AX-L, supplies occupancy through its *own layout* — and characterizes precisely
when that is free.

---

## Part I — The cell and its layout predicate

### I.1 The cell

The sparse-occupancy cell is the single-payload sum type:

```swift
Slot<E> ≜ Optional<E>           //  .none = vacant   |   .some(e) = occupied
```

Sparsity is **intrinsic to the cell**, not an added container capability. A slab/store of
`Slot<E>` cells reads occupancy *in-band* as `cell == nil`. This is the ADT-layer realization of
AX-L: the cell carries its own occupancy bit, so the leaf needs no separate occupancy plane and
the buffer needs no `deinit`.

### I.2 The layout predicate (measured, 6.3.2)

The cell satisfies **(B) ≤1-bit density** exactly when wrapping `E` in `Optional` adds **zero**
size — i.e. the discriminator is folded into `E`'s **extra inhabitants** (spare bit-patterns
that are not valid `E` values). Define:

```
free(E)  ⟺  MemoryLayout<E?>.size == MemoryLayout<E>.size   ⟺   xi(E) ≥ 1
```

Measured on Swift 6.3.2 (`/tmp/occ-cell/layout.swift`, `swiftc -O`), the **full element-class
taxonomy** — broader than AX-4's six rows:

| Element class | `E` size/stride/align | `E?` size/stride | Verdict |
|---|---|---|---|
| `class Ref` (reference) | 8 / 8 / 8 | 8 / 8 | **FREE** — null is the niche |
| `enum{red,green,blue}` (3 cases) | 1 / 1 / 1 | 1 / 1 | **FREE** — 253 spare patterns |
| `Bool` | 1 / 1 / 1 | 1 / 1 | **FREE** — 254 spare patterns |
| `UnsafeRawPointer` | 8 / 8 / 8 | 8 / 8 | **FREE** — null niche |
| `UnsafeMutablePointer<Int>` | 8 / 8 / 8 | 8 / 8 | **FREE** — null niche |
| `OpaquePointer` | 8 / 8 / 8 | 8 / 8 | **FREE** — null niche |
| `ObjectIdentifier` | 8 / 8 / 8 | 8 / 8 | **FREE** — null niche |
| `struct{UInt32, Bool}` | 5 / 8 / 4 | 5 / 8 | **FREE** — niche from the `Bool` byte |
| `struct FullByte{UInt8}` | 1 / 1 / 1 | 2 / 2 | **TAG +1 B** — full domain, `xi=0` |
| `UInt8` (raw) | 1 / 1 / 1 | 2 / 2 | **TAG +1 B** |
| `struct Pair2{UInt8,UInt8}` | 2 / 2 / 1 | 3 / 3 | **TAG +1 B** |
| `UInt64` (raw) | 8 / 8 / 8 | 9 / **16** | **TAG +1 B size, +8 B stride** |
| `Int` (word) | 8 / 8 / 8 | 9 / **16** | **TAG +1 B size, +8 B stride** |

Two engineering facts beyond AX-4's leaf-type table:

1. **The aggregate `struct{UInt32, Bool}` is FREE.** Niche discovery is *structural and
   recursive*: the optimizer reuses a spare inhabitant from *any* field. The `Bool` field uses
   2 of its 256 byte-patterns, and `Optional` folds `.none` into that byte (confirmed
   precisely: `struct{Ref,Bool}` = 9 B and `struct{Ref,Bool}?` = 9 B — the discriminator
   reuses the `Bool` byte, not fresh storage; `/tmp/occ-cell/mixed.swift`).
2. **The `xi=0` tag is stride-rounded, not bit-sized.** For word-aligned `Int`/`UInt64`, the
   single logical discriminator bit forces `E?` to **16 B stride** — the tag rounds up a whole
   word. This is *why* the cell loses catastrophically on density for full-domain integers
   (§III), and is the alignment effect AX-4's cost function predicts.

### I.3 Niche discovery is automatic and derivable — *for free* (answering Q2, FREE half)

The brief asks whether a `SpareBit`/`BitPackable` protocol "exposing a usable extra-inhabitant
when E has one … can be made automatic/derivable." **For the FREE case it already is — with no
protocol at all.** The compiler's extra-inhabitant machinery derives the niche structurally and
recursively (`/tmp/occ-cell/composition.swift`):

| Construct | `Optional` size | Niche survives? |
|---|---|---|
| `Ref` | 8 | baseline |
| `struct Wrap1{ r: Ref }` | 8 | **yes — 1 nesting layer** |
| `struct Wrap2{ w: Wrap1 }` | 8 | **yes — 2 nesting layers** |
| `struct Mixed{ a: Ref; b: Bool }` (= 9 B) | 9 | **yes — picks an available field niche** |

So a single-field struct wrapper over a niche-bearing type *preserves the niche*, transitively.
The `Index<E>`/`Tagged<Tag,Value>` family is exactly this shape — a one-field wrapper over a
raw ordinal — so a `Tagged<…, UnsafeRawPointer>` index keeps the pointer's null niche
automatically. **No `BitPackable` protocol buys anything in the FREE case**; the layout
optimizer is the derivation. (The protocol earns its keep only in the `xi=0` *manual* case — §IV.)

---

## Part II — Self-cleaning and the `~Copyable` story (answering Q1, Q3, and (C)/(D))

### II.1 The cell self-cleans with no `deinit` (D)

`Slot<E> = Optional<E>` carries **zero custom `deinit`**, yet its automatic value-witness
deinitializes the `.some` payload at exactly the right moments. Verified end-to-end on 6.3.2
(`/tmp/occ-cell/selfclean.swift`) with a `Tracked` class element across a 3-slot slab (slot 1
vacant):

```
occupancy bits: [1, 0, 1]      <- the ≤1-bit plane Optional folds INTO the cell
dealloc 2                       <- slot 2 set to .none: payload torn down in-place
dealloc 0                       <- scope exit: remaining payload torn down
```

This is (D) for the cell path **with no `deinit` and therefore no SE-0427 Wall-1 trigger** (AX-1).
Placed in the leaf per AX-L, an array/region of `Slot<E>` cells tears down via the *element's
own* value-witness — there is no occupancy oracle to walk, hence no buffer `deinit`.

### II.2 Trivial-destructibility tracks `E` exactly (Q3)

The cell is `BitwiseCopyable` / trivially-destructible **exactly when `E` is** — so when `E` is
trivial, teardown is a genuine no-op (the witness truly does nothing); when `E` is a resource,
the witness runs the payload's destructor. Verified by overload-resolution probe
(`/tmp/occ-cell/selfclean.swift`):

| `E` | `E` `BitwiseCopyable` | `Optional<E>` `BitwiseCopyable` |
|---|---|---|
| `UInt8`, `struct{UInt8}`, `Int`, `UnsafeRawPointer` | true | **true** |
| `enum{a,b,c}` | true | **true** |
| `class C` (refcounted) | false | **false** |

This is the stdlib conformance `extension Optional : BitwiseCopyable where Wrapped :
BitwiseCopyable, Wrapped : ~Escapable` (verified in the interface, II.3) made empirical. It is
the cell-level proof of (D): the *automatic* value-witness self-cleans, and trivial `E` yields a
trivial cell — no dead teardown cost.

### II.3 The headline finding: stdlib `Optional` is *already* the `~Copyable`-aware cell (Q1, (C))

The naïve expectation (and the framing implicit in the original tension: "cell `Slot<E> =
Optional<E>` … self-cleans … *when E has spare bits, tag otherwise*", with an unstated
Copyable-only caveat) is that stdlib `Optional` is Copyable-only and a custom `~Copyable`-aware
cell would be required for resource elements. **This is false on Swift 6.3.2.** Stdlib
`Optional` is fully `~Copyable`/`~Escapable`-aware, with conditional `Copyable`,
`BitwiseCopyable`, `Sendable`, and `ExpressibleByNilLiteral`.

**Primary-source citation** — Swift 6.3.2 stdlib interface
(`…/swift-6.3.2-RELEASE.xctoolchain/usr/lib/swift/macosx/Swift.swiftmodule/arm64-apple-macos.swiftinterface`,
lines 16176–16188) [Verified: 2026-06-08]:

```swift
@frozen public enum Optional<Wrapped> : ~Swift.Copyable, ~Swift.Escapable
    where Wrapped : ~Copyable, Wrapped : ~Escapable { … }
extension Swift.Optional : Swift.Copyable        where Wrapped : Swift.Copyable, Wrapped : ~Escapable {}
extension Swift.Optional : Swift.Escapable       where Wrapped : Swift.Escapable, Wrapped : ~Copyable {}
extension Swift.Optional : Swift.BitwiseCopyable  where Wrapped : Swift.BitwiseCopyable, Wrapped : ~Escapable {}
extension Swift.Optional : Swift.Sendable        where Wrapped : Swift.Sendable, Wrapped : ~Copyable, Wrapped : ~Escapable {}
@_preInverseGenerics extension Swift.Optional : Swift.ExpressibleByNilLiteral where Wrapped : ~Copyable, Wrapped : ~Escapable {}
```

**End-to-end behavioral proof** (`/tmp/occ-cell/q1b.swift`) — a `~Copyable` resource element
with a `deinit`, held in stdlib `Optional`, reassigned and consumed:

```
assigned
dealloc 1        <- o = .none: the ~Copyable payload tore down
got 2
dealloc 2        <- consume o: the moved-out payload tore down
```

**And the layout discipline is preserved for `~Copyable` E** (`/tmp/occ-cell/q1c.swift`):

```
Optional<struct{UInt8}:~Copyable>      size = 2   (TAG — xi=0)
Optional<struct{UnsafeRawPointer}:~Copyable> size = 8   (FREE — pointer niche)
```

**Consequence for (C):** the cell delivers conditional value-semantics for *all* E with **no
custom type** — stdlib `Optional<E>` is `~Copyable` when `E` is, `Copyable` when `E` is. This is
strictly stronger than the prior framing and removes any need for an institute `Slot` type for
the conditional-Copyable property.

### II.4 A custom `Slot` enum reproduces stdlib `Optional` exactly (and is therefore unnecessary)

For completeness, a hand-rolled `~Copyable`-aware cell was built and measured
(`/tmp/occ-cell/noncopyable.swift`):

```swift
@frozen public enum Slot<E: ~Copyable>: ~Copyable { case vacant; case occupied(E) }
extension Slot: Copyable where E: Copyable {}
```

It **compiles on 6.3.2**, **self-cleans with no `deinit`** (payload `dealloc` fires on `.vacant`
reassignment and on `consume`), **enforces conditional Copyable** (copying a `Slot<Copyable>`
compiles; copying a `Slot<~Copyable>` is rejected — `/tmp/occ-cell/q5.swift`), and has **layout
identical to stdlib `Optional`**:

| `E` | custom `Slot<E>` | stdlib `Optional<E>` |
|---|---|---|
| `Bool` | 1 | 1 |
| `class Ref` | 8 | 8 |
| `UInt8` | 2 | 2 |
| `UInt64` | 9 | 9 |
| `UnsafeRawPointer` | 8 | 8 |

The compiler's extra-inhabitant optimizer applies to *user* single-payload enums identically.
**Recommendation: use stdlib `Optional<E>` directly as the cell** — a custom `Slot` type is pure
redundancy (it would also re-implement `ExpressibleByNilLiteral`, `Equatable`, pattern-matching,
etc.). The only reason to introduce a nominal cell is a *semantic* niche-fill cell over `xi=0`
elements (§IV), which is a different type with a different contract.

---

## Part III — The residual: `xi(E) = 0` forces a tag (the (B) wall, viewed through the cell)

For `E` with **no** extra inhabitant — full-domain integers (`Int`, `UInt64`, `UInt8`),
padding-free PODs (`Pair2`) — the cell *cannot* be bit-dense. The discriminator must occupy
fresh, alignment-rounded storage. The density cost, measured at `N=64`
(`/tmp/occ-cell/composition.swift`):

| Encoding | Per cell | Total (N=64) | Occupancy cost | (B) ≤1 bit/slot? |
|---|---|---|---|---|
| (a) `Optional<class Ref>` (niche) | 8 B | 512 B | **0 marginal** | **yes** (with margin) |
| (b) `UInt64` + side bitmap (the AX-L leaf plane) | 8 B + ⅛ B | 520 B | **8 B total = 1 bit/slot** | **yes** |
| (c) `Optional<UInt64>` (tag, `xi=0`) | 16 B | 1024 B | **512 B = 64 bit/slot** | **NO** |

So for `xi=0` elements the **cell path costs 64 bit/slot vs the separate bit-plane's 1
bit/slot** — a 64× density loss, because the tag rounds up to a full word. This is exactly the
information-floor verdict (AX-4 Thm I.3) seen at the cell granularity: *the tag honors (B) only
under a niche.*

**This is the irreducible boundary of the cell path for (B).** No amount of ADT cleverness
recovers it within `Optional`'s totality: `Optional` must represent *every* value of `E` plus
`.none`, and if `E` already uses every bit pattern, there is nowhere to put `.none` but in fresh
storage. The recovery is not an ADT move — it is either (i) leave the cell and use the leaf's
separate bit-plane (the AX-L bitmap; angle-4's `E_bitmap`), or (ii) **manual bit-stealing** (§IV).

---

## Part IV — Manual extra-inhabitant / bit-stealing (answering Q4, and Q2's costed half)

When `xi(E)=0` but the *consumer* knows a value `E` will never legitimately store (a sentinel),
occupancy can be folded into the value at **0 marginal bits** by nominating that value as
"vacant." This is the codec-split path: the cell *is* `E`; vacancy is a reserved value, not a
separate plane. This is the only place a `SpareBit`/`BitPackable` protocol earns its keep.

### IV.1 The protocol and the 0-bit cell

```swift
protocol SpareBearing: ~Copyable {
    static func makeVacant() -> Self          // a FRESH owned vacant value
    borrowing func isVacant() -> Bool
}
@frozen enum DenseSlot<E: SpareBearing & ~Copyable>: ~Copyable {
    case raw(E)                                // single payload, NO extra case → layout == E
    static func makeVacant() -> Self { .raw(E.makeVacant()) }
    borrowing func isVacant() -> Bool { switch self { case .raw(let e): return e.isVacant() } }
}
```

Measured on 6.3.2 (`/tmp/occ-cell/bitsteal.swift`), for a `UInt`-backed handle reserving `0`:

```
Handle{bits: UInt}              size = 8
DenseSlot<Handle>               size = 8     <- 0-bit occupancy: folded into the value
Optional<Handle>                size = 9     <- the AUTOMATIC tag CANNOT do this (UInt has no niche)
```

The decisive comparison: `Optional<Handle>` is **9 B** (the compiler does *not* know `0` is
unused for a `UInt`-backed struct — `UInt` has `xi=0`), but `DenseSlot<Handle>` is **8 B**
because the *user* nominated `0`. So manual bit-stealing recovers exactly what the automatic
niche-fill cannot, at the cost of (a) spending one value from `E`'s domain and (b) forfeiting
`Optional`'s totality (the type no longer distinguishes "absent" from "the sentinel value" —
correctness rests on the consumer's invariant).

### IV.2 The `~Copyable` ownership wrinkle (a real finding)

The first draft of `SpareBearing` declared `static var vacantSentinel: Self { get }`. On 6.3.2
this **fails to compile** for `~Copyable` E:

```
error: 'unknown' is borrowed and cannot be consumed
  static var vacant: DenseSlot { .raw(E.vacantSentinel) }
                                       ^ consumed here
```

A property *getter* yields a **borrow**; the borrowed sentinel cannot be *consumed* into the
payload. The fix is a **`static func makeVacant() -> Self`** that produces a fresh *owned* value
(consuming-capable). This is a genuine `~Copyable` API-design constraint for any spare-bit
protocol: vacancy must be produced as an owned value, not vended as a borrowed constant. (It
composes with `[MEM-OWN-001]`/`[MEM-OWN-002]` — the owned/borrowed boundary.)

### IV.3 Why this stays at the cell and does not need a niche in the type layout

`DenseSlot` is *not* a layout trick — it is a *semantic* contract. The compiler still sees a
single-payload enum over a no-niche `E` and would tag it if forced to (e.g. `Optional<DenseSlot<Handle>>`
re-tags). Its 0-bit property holds only because `DenseSlot` *never forms an `Optional`* — it
reads vacancy through `isVacant()`. This is the cell-layer analog of the institute's existing
sentinel patterns and is the correct home for the `xi=0` niche-fill when the consumer can supply
an invariant.

---

## Part V — Which of (A)–(E) the cell path achieves

| Property | Cell path (`Slot<E> = Optional<E>`) | Evidence |
|---|---|---|
| **(A)** one neutral `Store.\`Protocol\``, no `Store.Sparse` | **YES, unconditionally.** A store of `Optional<E>` cells conforms a neutral element-store protocol (capacity + slot r/w) with **no** `firstVacant`/bitmap/`allocate` requirement; occupancy is in-band `cell == nil`. | `/tmp/occ-cell/storeconform.swift` (compiles with `SuppressedAssociatedTypes`; `~Copyable` element, conditional Copyable; self-cleans `dealloc 1`/`dealloc 3` with no `deinit`) |
| **(B)** ≤1-bit density | **CONDITIONAL: yes iff `xi(E) ≥ 1`.** 0 marginal bits for niche-bearing E (class/Bool/enum/ptr/aggregate-with-spare); **64× worse than a bitmap** for `xi=0` E (Int=64 bit/slot). Manual bit-stealing recovers 0-bit for `xi=0` E at a semantic cost. | §I.2, §III, §IV |
| **(C)** value-semantics / conditional `Copyable`, carve-out types dissolved | **YES, unconditionally for all E** — stdlib `Optional` is `~Copyable`-aware with conditional `Copyable`; no custom cell type. The cell is one generic; no `.Inline`/`.Small` *cell* types. | §II.3, interface 16176–16188 |
| **(D)** self-cleaning, no `deinit`, Wall-1 avoided | **YES, unconditionally for all E.** The cell's automatic value-witness tears down the payload; no custom `deinit` ⟹ no `copyable_illegal_deinit` (AX-1). | §II.1–II.2 |
| **(E)** maximal decomposition + clean composition | **YES, unconditionally.** The cell is a leaf-element atom; `Optional<E>` composes into the existing `Memory.Inline`/`Storage.Contiguous` leaf with no leaf `deinit` (a `MiniLeaf<Optional<Resource>>` deallocates only occupied slots). | `/tmp/occ-cell/composition.swift` |

**Summary:** the cell path achieves **(A), (C), (D), (E) unconditionally for all E**, and **(B)
exactly on the niche-bearing E** (free) / costed-by-manual-sentinel on `xi=0` E. The single
property the cell *cannot* deliver for-free-for-all-E is **(B)**, and the obstruction is precisely
`xi(E)=0` — the same wall the placement law and angle-4's information floor isolate, here proven
to be a property of `E`'s *layout*, not of the container.

---

## Outcome

**Status: DECISION.**

**The maximal cell-layer point.** `Slot<E> = Optional<E>` (stdlib `Optional`, used directly) is
the maximal occupancy-bearing cell reachable purely at the ADT layer. It satisfies **(A)+(C)+(D)+(E)
unconditionally for every E**, and **(B) at 0 marginal bits exactly when `E` exports ≥1 extra
inhabitant**. The niche test is **automatic and derivable for free** — recursively through struct
nesting and across aggregate fields — so for the entire reference / enum / `Bool` / pointer /
`Index`-over-pointer / niche-bearing-aggregate population, the cell gives bit-dense,
self-cleaning, conditionally-copyable, single-protocol occupancy with **no custom type, no
`deinit`, and no `BitPackable` protocol**.

**What is beyond it, and whether the residual is vacuous.** The residual is the cell over `xi(E)=0`
elements — full-domain integers (`Int`, `UInt8`, `UInt64`), padding-free PODs. For these the cell
**provably cannot** be bit-dense within `Optional`'s totality (no spare pattern exists for `.none`;
the tag rounds to a full word → 64 bit/slot for `Int`). This residual is **not vacuous** —
full-domain integers are among the most common element types. But it is **costed, not forbidden**:

1. **Leave the cell, use the leaf's bit-plane** (AX-L bitmap / angle-4 `E_bitmap`): 1 bit/slot,
   honors (B), at the cost of a leaf that holds an occupancy plane (and, on *inline* storage, a
   custom `deinit` to walk it — which is exactly where angle-4's cell-14 exclusion bites and AX-1
   forces the inline leaf move-only). The cell path's residual *hands off* to the placement
   problem; it does not introduce a new obstruction.
2. **Manual bit-stealing** (`DenseSlot` + `SpareBearing.makeVacant()`): 0 bit/slot, honors (B),
   at the cost of spending one value from `E`'s domain and forfeiting `Optional`'s totality —
   and requires the consumer-supplied invariant. The `~Copyable` ownership constraint (vacancy
   produced as an owned value, not a borrowed constant) is a real API rule for any such protocol.

**Does the residual need a named language feature?** *No — not at the cell layer.* The cell-layer
residual is fully resolved by existing mechanisms (bitmap-in-leaf, or manual sentinel). The
language feature that the *broader* problem needs — a **conditional `deinit`** (SE-0427's
deliberately-excluded generalization; held as PITCH-0003) — is needed **only** for the
*intersection* of {`xi=0` × inline × sparse × want-value-semantics} where the bitmap forces an
inline leaf `deinit` that collides with AX-1. That is angle-4's cell 14, and it is a *placement*
limitation, not a cell-ADT limitation. **The cell ADT itself reaches its maximal point with no new
language feature; the one honest residual it cannot dense-encode (`xi=0`) is exactly where the
already-identified conditional-`deinit` feature would help, and only in combination with inline +
value-semantics.**

This is consistent with — and the cell-layer refinement of — `occupancy-lives-in-the-leaf.md`'s
"one honest residual" (bit-density + value-semantics + inline simultaneously) and
`occupancy-encoding-4-placement-proof.md`'s cell-14 exclusion. The three notes agree: the
irreducible core is one corner's copyability under {inline × sparse × no-niche}, **not** a type
explosion and **not** any cell-ADT impossibility.

### Honest drawback ledger (the cell path)

| # | Drawback | Severity | Mitigation |
|---|---|---|---|
| 1 | **(B) fails for `xi=0` elements** (Int/UInt/packed POD): 8×–64× density loss vs bitmap. | High for integer-keyed dense stores | Use the leaf bit-plane (AX-L) for `xi=0`; or manual `DenseSlot` sentinel. |
| 2 | **Stride rounding amplifies the tag** for word-aligned `xi=0` E (`Int?` = 16 B). | High | As #1. Never use the tombstone cell for `Int`/`Double`/pointer-as-`UInt`. |
| 3 | **Manual bit-stealing forfeits totality** — `DenseSlot` cannot distinguish "absent" from "sentinel value"; correctness rests on a consumer invariant. | Medium | Reserve for closed-world handle/index domains where the sentinel is structurally impossible. |
| 4 | **`SpareBearing` vacancy must be owned, not borrowed** (a `~Copyable` ownership constraint; getter-form fails to compile). | Low (design rule) | `static func makeVacant() -> Self`, never a `{ get }` property. |
| 5 | **stdlib `Array` cannot hold `Optional<~Copyable E>`** (`Array` requires `Copyable`); a sparse store of `~Copyable`-element cells must use an institute container ([DS-021]) or a manually-managed leaf. | Low | Per [DS-021], use `Array_Primitives.Array` / the institute container catalog, not `[Swift.Element]`. |
| 6 | **No occupancy *iteration* primitive in-band** — `cell == nil` is O(1) per slot but "find next vacant" is O(N) over cells (a bitmap is O(word)). | Medium | For workloads dominated by vacant-slot search, the bitmap leaf wins regardless of (B); the cell path optimizes density+simplicity, not scan. |

### Relationship to prior research (this note EXTENDS, does not contradict)

- **`occupancy-lives-in-the-leaf.md` (AX-L):** the cell is *how* sparse occupancy is realized
  in a leaf when the chosen representation is per-element tombstone (one of the leaf's
  occupancy representations alongside bitmap/generation/free-list). The cell needs no buffer
  `deinit`; consistent with the law. This note adds the *which-E-is-free* characterization the
  law's "one honest residual" line asserts without measuring.
- **`occupancy-encoding-4-placement-proof.md` (angle-4):** this note is the cell-engineering
  companion. Angle-4 proves the information floor and places `E_tag` as one of three encodings
  (§I.4, one 6-row table). This note engineers the cell that fills that row: the full
  taxonomy, the `~Copyable` story (which angle-4 does not cover — it measures Copyable leaf
  types only), the custom-vs-stdlib equivalence, the recursive automatic niche derivation, and
  the manual bit-stealing escape with its ownership mechanics. **No contradiction**: both
  measure `class/Bool/enum/ptr = 0 marginal, UInt8 = +1 B, Int = +8 B` on 6.3.2 — the tables
  agree exactly.
- **`conditional-deinit-conditionally-copyable-generics.md` (AX-1, AX-S7):** the cell *avoids*
  Wall-1 entirely by carrying no `deinit` (self-cleaning is the automatic value-witness, the
  S7 phenomenon applied at the cell granularity). The conditional-`deinit` feature this note
  defers to is needed only for the placement residual (cell 14), not the cell ADT.

### Promotion candidates ([RES-006a])

- **[DS-023]** (ecosystem-data-structures) — the tombstone (`Element?`) form "buys copyability by
  spending density" is asserted; this note supplies the **measured** density cost (0 / 1 / 64
  bit/slot by `xi(E)`) and the precise FREE/TAG element classification. Candidate to quantify.
- **[MEM-COPY-016]** (memory-safety) — cross-reference that stdlib `Optional` is `~Copyable`-aware
  (the cell needs no custom type for conditional Copyable); useful where the triangle discusses
  conditional-Copyable cells.
- **A new `[MEM-OWN-*]` micro-rule** (memory-safety) — spare-bit/sentinel protocols for `~Copyable`
  E must vend vacancy as an *owned* value (`static func makeVacant() -> Self`), never a borrowed
  `{ get }` property (IV.2). Candidate if the manual bit-stealing path is adopted anywhere.

## References

### Internal ([RES-019] — grepped `swift-institute/Research/` for occupancy / spare-bit / extra-inhabitant / tombstone / `Optional<E>` / `Slot<` / BitwiseCopyable before drafting)
- `occupancy-lives-in-the-leaf.md` (DECISION, 2026-06-07) — the placement law (AX-L); the "one honest residual" line this note measures.
- `occupancy-encoding-4-placement-proof.md` (DECISION, 2026-06-08) — sibling angle; information floor + placement lattice + satisfiability matrix; §I.4 niche cost function (consumed as AX-4).
- `conditional-deinit-conditionally-copyable-generics.md` (RECOMMENDATION, 2026-06-06, superseded-in-part) — SE-0427 Wall-1 proof (AX-1), S1–S8 matrix, S7 automatic-field-teardown (AX-S7).
- `iterator-span-buffer-elimination.md` — single-payload-enum ABI note (the `Optional<T>` payload-at-offset-0 / extra-inhabitant statement), corroborated here by measurement.

### Primary — source, read directly, file:line cited [Verified: 2026-06-08]
- Swift 6.3.2 stdlib interface `…/swift-6.3.2-RELEASE.xctoolchain/usr/lib/swift/macosx/Swift.swiftmodule/arm64-apple-macos.swiftinterface:16176–16188` — `Optional` `~Copyable`/`~Escapable` declaration + conditional `Copyable`/`BitwiseCopyable`/`Sendable`/`ExpressibleByNilLiteral` conformances.
- `swift-memory-inline-primitives/Sources/Memory Inline Primitives/Memory.Inline.swift:41–114` — the move-only dense leaf precedent (`@_rawLayout` + `Store.Initialization` ledger + self-cleaning `deinit`); the leaf into which a `Slot<E>` element composes.
- `swift-store-primitives/Sources/Store Protocol Primitives/Store.Protocol.swift:20–69` — the neutral `Store.\`Protocol\`` (capacity + slot subscript + `initialize`/`move`); the protocol the cell store conforms with no sparse refinement (A). Uses `SuppressedAssociatedTypes`.
- `swift-storage-arena-primitives/Sources/Storage Arena Primitives/Storage.Arena.swift:19–68` — the shipped sparse-leaf existence proof (occupancy-driven teardown on a Backing class; the heap analog of the cell-in-leaf shape).

### Primary — Swift Evolution / compiler (via the companion note, AX-1)
- SE-0427 Noncopyable Generics, §"Conformance to `Copyable`" — *"Deterministic destruction requires the type to be unconditionally noncopyable."* (the law the cell sidesteps by carrying no `deinit`).
- `lib/Sema/TypeCheckInvertible.cpp:221–233`; `include/swift/AST/DiagnosticsSema.def:8390` (`copyable_illegal_deinit`) — the Wall-1 emission site (AX-1), reproduced on 6.3.2 in the companion note's S1.

### Prior art ([RES-021] — contextualization step)
- **Rust niche optimization** — `Option<&T>` / `Option<NonNull<T>>` / `Option<Box<T>>` are the *identical* mechanism: the niche (null) folds `None` into the pointer's bytes at 0 marginal bits, while `Option<usize>` (full-domain) costs a word. `NonZero*` / `NonNull` are Rust's *declared*-niche types — the analog of the manual `SpareBearing` sentinel, promoted into the type layout. The free/costed boundary is **language-independent**: it tracks the existence of a layout niche, not the language. (Consumed from the companion note's primary-source-verified Rust survey; corroborated by this note's 6.3.2 `MemoryLayout` measurements, which match Rust's niche behavior class-for-class.)

### Empirical artifacts ([RES-023]/[RES-024] — every load-bearing layout/diagnostic/behavioral claim compiled & run on Apple Swift 6.3.2, `swift-6.3.2-RELEASE`, `TOOLCHAINS=org.swift.632202605101a`, arm64-apple-macosx26.0, 2026-06-08; `/tmp/occ-cell/`)
- `layout.swift` — the full element-class FREE/TAG taxonomy table (§I.2) + nesting probe.
- `selfclean.swift` — (D) self-cleaning of `Optional<E>` with no `deinit` + `BitwiseCopyable` coupling (§II.1–II.2).
- `noncopyable.swift`, `q5.swift` — custom `~Copyable`-aware `Slot` enum: compiles, self-cleans, conditional-Copyable enforced, layout == stdlib `Optional` (§II.4).
- `q1b.swift`, `q1c.swift` — stdlib `Optional<~Copyable E>` end-to-end teardown + layout retention (§II.3).
- `bitsteal.swift` — manual bit-stealing `DenseSlot`/`SpareBearing` (0-bit for `xi=0` E) + the owned-vs-borrowed `~Copyable` wrinkle + derivability ceiling (`Optional<UIntHandle>`=9 vs `DenseSlot<Handle>`=8) (§IV).
- `composition.swift` — density accounting (0 / 1 / 64 bit/slot, §III) + recursive niche discovery (§I.3) + cell-as-element leaf composition (E).
- `mixed.swift` — the aggregate-niche nuance (`struct{Ref,Bool}?` reuses the `Bool` byte) (§I.2).
- `storeconform.swift` — neutral-protocol conformance with no sparse refinement (A), `~Copyable` element, self-cleaning, conditional Copyable.
