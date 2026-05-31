# Bit Algebraic-Structure Witness Placement

<!--
---
version: 1.0.0
last_updated: 2026-05-31
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

> **Scope.** Where Bit's *algebraic structure* (Boolean algebra — lattice / semiring /
> monoid; the ℤ/2ℤ field) should live, and which of bit-primitives' hand-rolled
> operations are redundant under the institute's established **structure-as-witness-in-a-
> bridge** pattern. Spans `swift-bit-primitives`, `swift-bit-algebra-primitives`,
> `swift-bool-algebra-primitives`, `swift-algebra-primitives`, and the planned
> `swift-finite-algebra-primitives`.
>
> **Reconciles, does not duplicate.** This is a Tier-2 *application* of the Tier-3
> framework already set in `order-cluster-decomposition-and-modernization.md` (the C1–C5
> placement principle + the generic `finite ⊗ algebra` bridge). Where that doc governs,
> it governs; this doc extends it to the Bit domain, which it did not cover.
>
> **Plan-only.** No source is changed by this doc. Execution, if approved, is sequenced
> by the principal and coordinated with the order-cluster program.

---

## 1. Context

Two threads converged on this question:

1. The **maximizing-decomposition + composition** shift (the move away from re-export-
   bundled umbrellas toward fine-grained targets + extracted cross-package integrations,
   `[MOD-014]` / `[MOD-031]`). A public-readiness review of `swift-memory-primitives`
   surfaced that `memory → bit → finite`, and asked whether `bit`'s dependency on `finite`
   is even correct.
2. The principal's hypothesis that *"the Bit Boolean stuff might be able to be refactored
   to use `bool-algebra-primitives`."*

Investigating both surfaced a single underlying truth: **`swift-bit-primitives` hand-rolls
algebraic structure that the institute already models as composable witnesses in extracted
bridge packages.** `Swift.Bool` has its full algebra tower witnessed in
`swift-bool-algebra-primitives`; `Bit` has only the ℤ/2ℤ field witnessed (in
`swift-bit-algebra-primitives`) and hand-rolls everything else. The order-cluster program
has, in parallel, established both the *placement framework* and a *generic mechanism* that
together resolve the Bit case.

**Tier 2** `[RES-020]`: cross-package, applies an existing (Tier-3) precedent rather than
setting a new one, reversible, informal semantic commitment. Optimized for evergreen /
correctness via decomposition `[ARCH-LAYER-008]`, not consumer count.

---

## 2. Question

Where should `Bit`'s algebraic structure live, and which hand-rolled operations are
redundant once it lives there? Concretely:

- Can `Bit Boolean Primitives` be "refactored to use `bool-algebra-primitives`"?
- Is `bit → finite` (for the `Bit: Finite.Enumerable` conformance) correctly placed?
- Is the `Bit Z₂ Field` operation layer (and the `Bit.z2` field witness) redundant?

---

## 3. Current-State Inventory `[Verified: 2026-05-31]`

All claims below verified against source at the cited `file:line`.

| Where | Contents | External coupling |
|-------|----------|-------------------|
| `swift-bit-primitives` · `Bit Primitive` (root) | `Bit` (`Bit.swift`), `Bit.Order` (`Bit.Order.swift`) | none (zero-dep `[MOD-017]` root ✓) |
| · `Bit Boolean Primitives` | generators `^ & \| ~` (`Bitwise Operators.swift:11–29`); named `and/or/xor/!/flipped/toggled` (`Bit Boolean Operations.swift`); compound `nand/nor/xnor/andNot` (`Bit Compound Operators.swift`); `^` on `Swift.Bool` (`Bool+XOR.swift:26`) | `Bit Primitive` only |
| · `Bit Primitives` (fat content **+** umbrella) | `Bit.Value<P> = Pair<Bit,P>` (`Bit.Value.swift:14`), `Bit.Order.Value`; `Bit+{Finite.Enumerable, Hash.Protocol, Equation.Protocol, Comparison.Protocol}`; `Bit Z₂ Field` (`adding = ^` `:11–13`, `multiplying = &` `:23–25`); `exports.swift` re-exports `Finite`, `Hash`, `Tagged` | **Finite**, Hash, Equation, Comparison, Pair, Tagged |
| · SLI | stdlib conformances; **`FixedWidthInteger << some Carrier.Protocol<Cardinal>`** (`FixedWidthInteger+Cardinal.swift:19`); plus mis-placed `Bit.Mask`/`Bit.Set` types | Cardinal, Carrier |
| `swift-bit-algebra-primitives` · `Bit Algebra Primitives` | `Bit.z2: Algebra.Field<Bit>` **inline**, built from `{ $0 ^ $1 }` / `{ $0 & $1 }` (`Bit+Z2.swift:12–32`) — does **not** call `Bit.adding`/`Bit.multiplying` | `Algebra Field Primitives`, `Bit Boolean Primitives` (`Package.swift:24–34`) |
| `swift-bool-algebra-primitives` · `Bool Algebra Primitives` | `Algebra.{Lattice, Monoid, Semilattice, Semiring}+Bool`, **inline** (`Algebra.Lattice+Bool.swift:18–20`: `init(join: .disjunction, meet: .conjunction)`) | `Algebra-{Monoid,Semiring,Semilattice,Lattice}` only (`Package.swift:24–40`) |
| `swift-algebra-primitives` | `Magma → Monoid → Semiring → Group → Ring → Field`, plus `Semilattice/Lattice/Module/Law`; **zero external deps (Tier 0)** | none |

Two facts fall out immediately:

- **`Bit.z2` re-derives `^`/`&` inline; it never calls `Bit.adding`/`Bit.multiplying`.** So
  the `Bit Z₂ Field` native ops are *orphaned* — no caller in bit or bit-algebra. They
  duplicate the generators `^`/`&` under field-semantic names.
- **`Bool`'s witnesses are all inline** (built from `&&`/`||`/`!`) and live in an extracted
  bridge depending only on `algebra-primitives`. `algebra-primitives` carries **no** `*Bool*`
  files — they were migrated cleanly to `bool-algebra` (resolving the deferred-work Item 6
  duplication concern; `find … -iname '*Bool*'` over `algebra-primitives/Sources` is empty
  `[Verified: 2026-05-31]`).

---

## 4. The Established Pattern (three precedents + one framework)

| Precedent | What it shows |
|-----------|---------------|
| `swift-bool-algebra-primitives` | An element type's Boolean algebra = **inline `Algebra.Lattice/Semiring/…` witnesses in an extracted `{element}-algebra` bridge**, built from the type's native generators. There is *no `Algebra.Boolean` type* — "`Swift.Bool` IS the two-element Boolean algebra, extended directly; its complement is the native `!`" (`Package.swift:28–32`). |
| `swift-bit-algebra-primitives` (`Bit+Z2.swift`) | Bit's ℤ/2ℤ field = inline witness in the **Bit recipient-owned bridge** (`[PKG-NAME-016]` recipient-then-provider). |
| `swift-set-algebra-primitives` (planned, per `cross-layer-capability-protocol-model.md`) | Set's union=join / intersection=meet / complement = Boolean-algebra witnesses in a Set⊗algebra bridge. |
| `order-cluster-decomposition-and-modernization.md` §4 (**C1–C5**) | The placement law: a type is homed by **constitutive identity**, never by an **incidental capability**. `Finite.Enumerable` is a *capability* (conformers span multiple domains — **C2**); a generic bridge over a capability confers structure regardless of home (**C5**). |

The pattern is uniform: **concrete generators stay native on the type; the algebraic
*structure* is an inline witness in an extracted `{element}-algebra` bridge.** `Bool`
follows it fully. `Bit` follows it only for the ℤ/2ℤ field, and hand-rolls the rest.

### 4.1 The reconciling insight — Bit IS ℤ/2ℤ via the generic `finite-algebra` bridge

`[Carried forward — order-cluster v1.0.0 is RECOMMENDATION / plan-only; the bridge is not
yet built]` order-cluster §5 specifies one generic **`swift-finite-algebra-primitives`**
bridge, *generic over `Finite.Enumerable`*: a conformer of count *N* is ℤ/Nℤ via its
`ordinal` bijection, so `extension Algebra.Group where Element: Finite.Enumerable` confers
ℤ/Nℤ on **every** conformer — and "the existing per-type witnesses already *are* this."

`Bit: Finite.Enumerable` with `count = 2` (`Bit+Finite.Enumerable.swift:13`). Therefore once
that bridge exists, **`Bit` receives its ℤ/2ℤ group (and, for the prime modulus N=2, its GF(2)
field via the `Algebra.Z.Modulo<n>.field()` residue path) generically** — making the per-type
`Bit.z2` witness *optional sugar* rather than load-bearing, exactly as order-cluster says for
`Order.Direction`/`Interval.Bound`. The native `Bit.adding`/`multiplying` are redundant under
*either* the existing `Bit.z2` or the future generic bridge.

---

## 5. Options

**Option A — Status quo.** Bit hand-rolls generators + named gates + compound gates + Z₂
field-aliases in `bit-primitives`; `bit-algebra` carries only the per-type `Bit.z2`.
*Pros*: ergonomic direct methods; no extra import. *Cons*: asymmetric with `Bool`; the
algebraic structure is hand-rolled and un-witnessed (no `Algebra.Lattice<Bit>` for generic
consumers); `Bit Z₂ Field` aliases are orphaned duplicates; `bit → finite` exists only to
host an incidental capability conformance (**C2** error).

**Option B — Full mirror + subsume.** Generators stay native in `Bit Boolean`; author Bit's
`Algebra.{Lattice, Semilattice, Monoid, Semiring}` witnesses **inline** in `bit-algebra`
(mirroring `bool-algebra`); subsume the ℤ/2ℤ field into the generic `finite-algebra` bridge
(`Bit.z2` → optional sugar); **derive** the compound gates (`nand/nor/xnor/andNot`) from the
Boolean-algebra structure; retire the `Bit Z₂ Field` aliases. *Pros*: full symmetry with
`Bool`; single source of structure; maximal dedup. *Cons*: derived gates move up to the
`bit-algebra` tier → a `[MOD-015]` consumer-altitude regression for `bit.nand(other)`;
depends on the (unbuilt) generic bridge for the field subsumption; largest migration.

**Option C — Mirror + dedup now, subsume later (staged).** Generators **and** ergonomic
named/compound gates stay native in `Bit Boolean` (Bit is a hardware-logic type — gates are
its domain vocabulary); author the missing `Algebra.{Lattice, Semilattice, Monoid, Semiring}`
witnesses inline in `bit-algebra` (mirror `bool-algebra`); retire the orphaned `Bit Z₂ Field`
`adding`/`multiplying` now (the `Bit.z2` witness already supersedes them); coordinate the ℤ/2ℤ
*field* subsumption + the `Finite.Enumerable` conformance placement with order-cluster Phase 1.
*Pros*: removes the clearest redundancy immediately; restores Bool-symmetry for structural
consumers; preserves bit-domain ergonomics; no dependency on the unbuilt bridge for the
actionable part. *Cons*: the compound gates remain both hand-rolled (in bit) and derivable
(from the witness) until/unless B's derivation is taken — a tolerated, documented overlap.

**Option D — `Bit Boolean` depends on `bool-algebra` / collapse `Bit` into `Bool`.** The
literal reading of the hypothesis. **Rejected**: `bool-algebra` witnesses `Swift.Bool`
specifically; `Bit` is a distinct bit-domain type (`rawValue: UInt8`, frozen), not a `Bool`
wrapper. The reuse is of the *pattern*, not of the Bool-specific package; collapsing the types
would erase the deliberate Bit/Bool domain distinction.

### Comparison

| Criterion | A (status quo) | B (full mirror+subsume) | C (mirror+dedup, stage) | D (depend on bool-algebra) |
|-----------|----------------|--------------------------|--------------------------|-----------------------------|
| Bool-symmetry (structure witnessed) | ✗ | ✓ | ✓ | partial/wrong type |
| Removes orphaned Z₂ aliases | ✗ | ✓ | ✓ | ✗ |
| Bit-domain gate ergonomics preserved | ✓ | ✗ (gates move up a tier) | ✓ | n/a |
| Depends on unbuilt generic bridge | — | yes (field) | no (staged) | — |
| Respects Bit ≠ Bool domain split | ✓ | ✓ | ✓ | ✗ |
| Migration size | none | large | small + staged | n/a |

---

## 6. Constraints

- **Layering.** `algebra-primitives` is Tier 0 (no external deps `[Verified: 2026-05-31]`).
  `bit-algebra → {bit, algebra}` is downward; adding Bit's lattice/semiring witnesses there
  introduces no new upward/lateral edge `[ARCH-LAYER-001]`. Generators stay in `bit` (Tier 6);
  the *structure* lives one tier up in `bit-algebra` — the same split `Bool` uses.
- **`[MOD-034]` foundational vs incidental.** Bit's `Hash`/`Equation`/`Comparison.Protocol`
  conformances are **foundational roles** (value identity) and **stay in `bit`**. Bit's
  Boolean-algebra and ℤ/2ℤ are **incidental** structure (capability, not identity; not used
  internally by bit) → bridge. This is the discriminating line: not "extract every
  integration," only the incidental algebraic structure.
- **`bit → finite` (the original blocker).** The `Bit: Finite.Enumerable` conformance is an
  incidental capability conformance (**C2**), currently the *sole* reason `bit` depends on
  `finite` (only `Bit+Finite.Enumerable.swift` + `exports.swift` reference `Finite`
  `[Verified: 2026-05-31]`). Its placement is governed by order-cluster's resolution of the
  identical question for `Comparison`/`Interval` types — see §7.
- **`[ARCH-LAYER-009]` no removal pre-1.0.** Retiring the `Bit Z₂ Field` aliases is a reshape
  (removing two orphaned methods / emptying one file), not a module removal — permitted, but
  requires explicit per-action authorization.

---

## 7. The `bit → finite` placement, reconciled

This refines the earlier ad-hoc suggestion (made before the order-cluster prior art was
consulted) to *"extract `swift-bit-finite-primitives`."* order-cluster did **not** extract
the analogous `X: Finite.Enumerable` conformances to per-domain bridges. Its Phase-2 decision
(principal, 2026-05-28) keeps `Comparison+Finite` / `Interval.*+Finite` **in `finite`**
(finite reaching *down* to conform them), reserving extraction-to-a-bridge **only** for the
`finite ⊗ algebra` surface — because *"`comparison-primitives` is a foundational universal
dependency"* whereas *algebra* is the non-foundational domain `finite` must avoid.

Applied to Bit, three candidate placements remain, to be decided *with* order-cluster rather
than ahead of it:

| Placement | Edge | Note |
|-----------|------|------|
| (a) In `finite` (finite conforms Bit) | `finite → bit` | Mirrors the `Comparison`/`Interval` resolution. Requires `bit` to sit below `finite` — which holds *once* `bit → finite` is dropped (Bit's only finite use is this conformance). Question: is `bit` "foundational-universal" enough to be a clean `finite` dep, or is it too domain-specific (unlike `comparison`/`carrier`/`tagged`)? |
| (b) In a bridge `swift-bit-finite-primitives` | bridge `→ {bit, finite}` | `[MOD-014]` extraction default; neither base depends on the other. Cleanest manifest-decoupling; one more package. |
| (c) Subsumed | — | If Bit's algebra is delivered via the generic `finite-algebra` bridge (§4.1), the `Finite.Enumerable` conformance is the *hinge* the bridge needs; its home is then chosen by (a)/(b), and `Bit.z2` retires into the generic witness. |

Either way, the conclusion the memory-readiness arc cares about holds: **`bit` should not
depend on `finite` merely to host an incidental capability conformance** — the conformance
moves (to `finite`, or to a bridge), and `finite` leaves `bit`'s — and therefore `memory`'s —
transitive closure.

---

## 8. Outcome

**Status: RECOMMENDATION.**

**Answer to the framing question.** Not *"`Bit Boolean` depends on `bool-algebra`"* (Option D,
rejected — `bool-algebra` is `Swift.Bool`-specific). Rather: **`Bit` should mirror
`bool-algebra`'s witness pattern in `bit-algebra`**, and **Bit's ℤ/2ℤ is subsumed by the
generic `finite-algebra` bridge** once it exists. The *pattern* is reused; the Bool package is
the exemplar, not the dependency.

**Recommended path — Option C (staged), sequencing toward B:**

1. **Retire the orphaned `Bit Z₂ Field` aliases** (`adding`/`multiplying`). They are unused
   even by `Bit.z2` and duplicate `^`/`&`. *(Smallest, highest-confidence win; needs auth per
   `[ARCH-LAYER-009]`.)*
2. **Author Bit's `Algebra.{Lattice, Semilattice, Monoid, Semiring}` witnesses inline in
   `swift-bit-algebra-primitives`**, mirroring `bool-algebra` (built from Bit's `& \| ~`).
   This closes the Bool/Bit asymmetry and gives generic consumers `Algebra.Lattice<Bit>` etc.
3. **Keep the generators and ergonomic gates native in `Bit Boolean`** (Bit is a hardware-logic
   type; gates are its domain vocabulary). Whether to *derive* the compound gates from the
   structure (Option B) is a deferred `[MOD-015]` altitude decision, not required now.
4. **Coordinate with order-cluster Phase 1**: the ℤ/2ℤ *field* subsumption and the
   `Bit: Finite.Enumerable` conformance placement (§7) resolve together when the generic
   `swift-finite-algebra-primitives` bridge lands. Until then `Bit.z2` stays as-is.

**Sequencing note (direction, not premise).** Steps 1–2 stand alone and do not depend on the
unbuilt generic bridge. Step 4 *is* dependent on order-cluster Phase 1; it is flagged as a
coordination direction, not a load-bearing premise of this recommendation, and must be
re-verified when that bridge exists (does the generic `Finite.Enumerable → ℤ/Nℤ` witness wire
through to a GF(2) **field** for Bit, or only the additive group?).

**Implementation status (2026-05-31).** **Step 2 landed** under principal authorization:
`swift-bit-algebra-primitives` gained inline `Algebra.{Lattice, Semilattice, Monoid,
Semiring.Commutative}` witnesses for `Bit` (mirroring `bool-algebra` — join/meet = `\|`/`&`,
bottom/top = `.zero`/`.one`, complement = native `~`), with package deps + `exports.swift`
wired and 13 law tests added (idempotence / absorption / complement / distributivity);
`swift test` green (20/20). **Step 1 deferred**: `Bit Z₂ Field`'s `adding`/`multiplying` are
NOT orphaned — they carry dedicated tests (`swift-bit-primitives/.../Bit Tests.swift:190–213`),
so the "orphaned" premise did not hold; the whole ℤ/2ℤ op-layer is better handled in the
coordinated step-4 subsumption than removed piecemeal. **Steps 3** (generators stay native —
no action) and **4** (ℤ/2ℤ subsumption + `Finite.Enumerable` placement, gated on order-cluster
Phase 1) remain open, surfaced for the principal to sequence per
`feedback_class_c_ecosystem_stop_not_dispatch`.

---

## 9. Prior Art

**Internal (governs — `[RES-019]`):**
- `order-cluster-decomposition-and-modernization.md` v1.0.0 (Tier 3, RECOMMENDATION, plan-only) — the C1–C5 placement framework and the generic `finite-algebra` bridge. **Governs** the capability-placement and ℤ/Nℤ-subsumption parts of this doc.
- `finite-interval-polarity-decomposition.md` v1.1.0 (SUPERSEDED) — the "domain identity primary, algebra in a recipient-owned bridge" framing; the `Bit.z2` precedent.
- `cross-layer-capability-protocol-model.md` v1.1.0 (Tier 3) — the planned `swift-set-algebra-primitives` Boolean-algebra/lattice bridge; authorization of the Boolean-algebra-on-`Bool` package.
- `swift-algebra-primitives/Research/deferred-work.md` v2.0.0 — Item 1 (`Algebra.Z.Modulo<n>.field()` returns nil for non-prime), Item 2 (`Algebra.Field.z2(via: Optic.Iso)` transport), Item 6 (Bool semiring/monoids — since migrated to `bool-algebra`).
- `comparative-bitset-bitvector-primitives.md`, `algebra-primitives-package-split.md` — adjacent bit/algebra structure surveys.

**External (contextualization `[RES-021]`):** Haskell `Data.Bits` / Boolean type classes; Rust `core::ops::{BitAnd, BitOr, Not}` traits; abstract algebra (GF(2) = the Boolean ring; Boolean algebra = complemented distributive lattice). *Contextualization:* "every language gives bits AND/OR/NOT" does **not** imply hand-rolling the *algebra* — the institute deliberately separates concrete generators (native) from algebraic structure (inline witnesses in an extracted bridge). The hand-rolled-structure-in-`bit` shape is the deviation; the witness-bridge shape is the institute's intended form.

---

## 10. References

- `swift-bit-primitives`: `Bit Boolean Primitives/Bitwise Operators.swift:11–29`, `Bit Compound Operators.swift`, `Bit Boolean Operations.swift`, `Bool+XOR.swift:26`; `Bit Primitives/Bit Z₂ Field.swift:11–25`, `Bit.Value.swift:14`, `Bit+Finite.Enumerable.swift:13`, `exports.swift:7`; `Bit Primitives Standard Library Integration/FixedWidthInteger+Cardinal.swift:19`.
- `swift-bit-algebra-primitives`: `Bit Algebra Primitives/Bit+Z2.swift:12–32`; `Package.swift:24–34`.
- `swift-bool-algebra-primitives`: `Bool Algebra Primitives/Algebra.Lattice+Bool.swift:18–20`; `Package.swift:24–40`.
- `swift-algebra-primitives`: Tier-0 manifest (no external deps).
- Skills: modularization `[MOD-014/015/017/031/034/035]`; swift-package `[PKG-NAME-016]`; swift-institute `[ARCH-LAYER-001/008/009]`; research-process `[RES-019/020/021/023/027]`; `feedback_class_c_ecosystem_stop_not_dispatch`.
