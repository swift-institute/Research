# ADT / Buffer / Storage Decoupling — The Canonical ADT Shape

<!--
---
version: 1.0.0
last_updated: 2026-06-18
status: COMPANION to ecosystem-data-structures [DS-025]–[DS-027] (the normative Charter; ratified 2026-06-18). This doc is the rationale + status ledger; the binding rules live in the skill.
tier: 3
scope: ecosystem-wide (the tower container ADTs — array, queue, stack, deque, set, dictionary, heap, slot-map, tree, …)
type: investigation/architecture
toolchain_of_record: Apple Swift 6.3.2 (swift-6.3.2-RELEASE, TOOLCHAINS=org.swift.632202605101a)
builds_on:
  - swift-institute/Research/universal-adt-shape.md                       # DECISION (2026-06-18) — the doc this ADDITIVELY corrects (omitted point 4)
  - swift-institute/Research/cross-layer-capability-protocol-model.md     # RECOMMENDATION/APPROVED (Tier 3) — minimal orthogonal cores; the R/C/D normal form. KEPT (backbone)
  - swift-institute/Research/derive-for-free-capability-composition.md    # RECOMMENDATION (Tier 3) — the warranted-refinement test C1–C4; ALREADY names the <ADT>.Protocol consumer layer
  - swift-institute/Research/occupancy-encoding-2-category-theory-composition.md  # RECOMMENDATION (Tier 3) — composition-over-refinement, proven ×2 on 6.3.2
provenance: Step 1 of the ADT/Buffer/Storage decoupling plan (HANDOFF-adt-shape-research.md). RESEARCH/SYNTHESIS only — no package source / Package.swift edited, no builds run, no experiments re-run (all empirical claims CITE the prior receipts). Toolchain of record for cited empirical work: Swift 6.3.2.
---
-->

**Coen ten Thije Boonkkamp · Swift Institute · June 2026**

> **RATIONALE COMPANION to the Charter (ratified 2026-06-18).** The normative rules now live in the
> `ecosystem-data-structures` skill — [DS-025] canonical shape, [DS-026] conformance predicate +
> three-shape taxonomy, [DS-027] packaging law. This document is their rationale + status ledger; read
> the skill for the binding text. It formalizes the converged
> "ADT shape" as **Step 1** of the ADT/Buffer/Storage decoupling plan and grounds it against the
> ecosystem's own prior research + experiments. It does **not** re-open the converged model; it
> **grounds, reconciles, and additively corrects** it. The correction it carries is a single
> *additive* one (point 4 below), not a teardown — the existing `universal-adt-shape.md` DECISION
> was right on no-bound / minimal-cores / compose-not-refine, and its only gap was omitting the
> additive per-ADT consumer protocol.
>
> **Status: COMPANION — the model was ratified into the skill 2026-06-18 (full-vision scope).**
> All empirical claims CITE prior receipts (Swift 6.3.2, `TOOLCHAINS=org.swift.632202605101a`); no
> builds were run and no experiments re-run for this synthesis. File:line facts are `[Verified:
> 2026-06-18]` against the canonical (non-`.build`) sources.

---

## Context

The tower container ADTs (array, queue, stack, deque, set, dictionary, heap, slot-map, tree, …)
must share **one shape**, so a reader who learns `Array<S>` understands `Tree<S>`. The corpus had
already decided the *mechanism* — composition over refinement, minimal orthogonal cores, the
warranted-refinement test — and on 2026-06-17/18 the principal directed and the seat ratified the
*skeleton* in `universal-adt-shape.md` (DECISION): every ADT is `struct ADT<S>` over a minimally
bound storage, capabilities by conditional extension, **no foundational lower-protocol bound on the
ADT type**.

**Trigger** ([RES-001]/[RES-011]/[RES-012]): Step 1 of the ADT/Buffer/Storage decoupling plan asks
for the canonical, *formalized* statement of this shape in the cross-layer normal-form vocabulary,
reconciled with the existing decision docs, with any genuine discrepancy surfaced. The principal's
standing view is that this was *substantially decided last week* (window ≈ 2026-06-09..16) — so this
doc **locates that prior work and builds on it**, rather than re-deriving from scratch.

This is a **Tier 3** investigation ([RES-020]): ecosystem-wide, cross-layer, precedent-setting, a
long-lived semantic contract every future tower ADT depends on. It is a *discovery/formalization*
doc ([RES-012]–[RES-016]) over an already-converged model, not a reopening.

**Constraints** ([RES-007]): research/synthesis only — no package source or `Package.swift` edited,
no builds, no experiments re-run (cite them). The converged model is not re-opened; a *genuine*
contradiction would HALT-and-surface, not be reconciled away (see §4 — none found; one load-bearing
**caveat** is surfaced instead).

---

## Question

State the canonical "ADT shape" precisely, in the cross-layer **R/C/D normal form**, such that:

1. the six converged points are formalized and grounded against the ecosystem's own prior art;
2. the relationship to `universal-adt-shape.md` (DECISION) and
   `cross-layer-capability-protocol-model.md` (RECOMMENDATION/APPROVED) is explicit; and
3. any genuine discrepancy between the converged model and the prior art is surfaced with a
   citation rather than reconciled away.

---

## 1. Prior-Art Reconciliation ([HANDOFF-013] / [RES-019] — read + reconcile FIRST)

Each artifact below was read in full. Verification tags per [RES-013a]/[RES-023]. Dispositions:
**KEEP** (backbone, unchanged), **EXTEND** (this doc adds to it), **GROUND** (supplies the verified
fact base), **SUPERSEDE-with-reason**, **COORDINATE** (interlocks; sequencing note).

### 1.1 Where "last week's decision" lives

The principal's "substantially decided last week" (window ≈ 2026-06-09..16) is **not one document
— it is two distinct, complementary decisions**, and conflating them is the trap this doc avoids:

- **The shape/skeleton decision** lives in **`universal-adt-shape.md`** (DECISION, 2026-06-18) +
  its GATE-1 proof and receipts in **`.handoffs/HANDOFF-tree-universal-shape.md`** (GATE 1
  RATIFIED 2026-06-18; scratch `/tmp/uadt/`). This is `struct ADT<S: ~Copyable>` + conditional
  capability extensions, **no hard storage bound** — the new, principal-directed skeleton, proven
  on a fresh `Container<S>` and ratified for **Tree as the first/reference adopter**.
- **The families *execution* decision** lives in the **`REPORT-ADT-families-*` set** (2026-06-10,
  seat-verified + principal-ratified): set / dictionary / queue / deque / slot-map were **built**
  to the *Array playbook* — i.e. **with** the hard bound `S: Store.Protocol & Buffer.Protocol`.

These two are **a fortnight apart and point in opposite directions on the bound** — by design and
correctly so (§4.2 reconciles them via the C1/C2 test + the scope/sequencing clause). The brief's
"substantially decided last week" is most precisely the **shape decision** (`universal-adt-shape.md`
+ GATE-1, 2026-06-17/18); the families tranche is the *prior, layer-consistent* execution that the
shape decision now generalizes one level up. **No discrepancy** — see §4.2.

### 1.2 Reconciliation table

| Artifact | Date / status | Read | Disposition | Reason |
|----------|---------------|------|-------------|--------|
| `Research/universal-adt-shape.md` | 2026-06-18 · DECISION (Tier 3) | `[Verified: 2026-06-18]` | **EXTEND (additive correction)** | The skeleton (no-bound + conditional-extension + compose-not-refine + minimal cores) is **right** and grounded. Its **one gap**: it never mentions the **additive per-ADT consumer protocol** (`ADT.Protocol`; the `__ArrayProtocol`/`Array: Array.Protocol` layer). Grep of the doc for `additive`/`ADT.Protocol`/`__ArrayProtocol`/`Array.Protocol`/`consumer protocol` returns **empty** `[Verified: 2026-06-18]`. This doc supplies point 4; §6 recommends the disposition (amend-in-place). |
| `Research/cross-layer-capability-protocol-model.md` | v1.5.0, 2026-06-04 · RECOMMENDATION, APPROVED 2026-05-28 (Tier 3) | `[Verified: 2026-06-18]` | **KEEP (backbone)** | The minimal orthogonal cores + the **R/C/D edge-kind normal form** (§3.2) + the decision rule (refine within an axis where identity holds, compose across axes) + the specialization boundary. Explicitly "Buffer HAS-A storage; does NOT refine it." **Unchanged.** This is the vocabulary the whole doc is written in. |
| `Research/derive-for-free-capability-composition.md` | v1.5.0, 2026-06-02 · RECOMMENDATION (Tier 3) | `[Verified: 2026-06-18]` | **KEEP / GROUND** | Carries the **warranted-refinement test C1–C4** (§6.2) that `universal-adt-shape.md` runs on the base seam. Critically, its v1.0.0 abstract **already names the `<ADT>.Protocol` consumer layer** as the top of the stack (`Memory.Contiguous.Protocol → Storage.Protocol → Buffer.Protocol → <ADT>.Protocol`), and GAP-L (landed) hoists Array index witnesses **onto `Array.Protocol`**. → point 4 is *already in the corpus*; `universal-adt-shape.md` simply did not carry it forward. |
| `Research/occupancy-encoding-2-category-theory-composition.md` | v1.0.0, 2026-06-08 · RECOMMENDATION (Tier 3) | `[Verified: 2026-06-18]` | **KEEP / GROUND** | The categorical proof (×2 on 6.3.2) that the richer surface attaches by **capability conjunction** `where S: Occupancy`, never by refining the store — "exactly as the shipping `Buffer.Arena` already does." The mechanism `universal-adt-shape.md` generalizes to the base seam. Applies C1–C4 to occupancy → OVERLAP not NEST → sibling, not refine. |
| `.handoffs/REPORT-ADT-families-composition.md` + `-spike-findings.md` + `-execution.md` + `-leg8-execution.md` | 2026-06-10 · seat-verified + principal-ratified | `[Verified: 2026-06-18]` | **COORDINATE / GROUND (the caveat source)** | The families (set/dict/queue/deque/slot-map) were built with the **hard bound** (Array playbook). **F-4 empirically walled** relaxing `Shared`'s *declaration* bound → minted **[MEM-COPY-018]**. This is **NOT** a contradiction of the no-bound ADT shape (it governs a *column combinator* consumed via same-type method pins, one layer below the ADT) — but it IS the load-bearing **caveat for Array's realignment** (§4.2, §5). |
| `.handoffs/GOAL-tower-adt-families.md` | 2026-06-10 · ratified | `[Verified: 2026-06-18]` | **GROUND** | The per-family Array-playbook template (gate+seam generic; pinned split constructors [MEM-COPY-017]; `@frozen` [API-IMPL-022]; [DS-024] Seam.Ledger laws). Confirms every families-tranche ADT carries the hard bound; the slot-store leaves genuinely *are* slot-stores → the bound was correct for them. |
| `.handoffs/HANDOFF-tree-universal-shape.md` | 2026-06-17/18 · GATE 1 RATIFIED | `[Verified: 2026-06-18]` | **GROUND** | The GATE-1 proof + receipts (`/tmp/uadt/`): one `Container<S: ~Copyable>` carries slot + ordinal-child + keyed-child capabilities as conditional extensions; keyed storage (NOT a slot-store) is a valid `Container<S>`; negatives fail correctly; **0 `witness_method`** in the `-O` cross-module client SIL. GATE-2 recon (line 111) **independently rediscovered point 4** ("Array<S> *itself* conforms to Array.Protocol conditionally; the storage never does") — corroborating this doc's correction. |
| `.handoffs/REPORT-tree-recomposition-R0-revalidation.md` | 2026-06 · HALT-to-principal | `[Verified: 2026-06-18]` | **GROUND (the "wall" this dissolves)** | Proves (×2) that a keyed child storage (`Dictionary.Ordered`) conforms **neither** `Store.Protocol` **nor** `Buffer.Protocol`, and the integer-indexed variants can't share a generic child-walk over the existing seam — the "tree can't be `Tree<S>`" wall. This is **exactly** the artifact of a hard `S: Store.Protocol` bound that the no-bound shape removes (`universal-adt-shape.md` §"Why this"). |
| `Experiments/storage-protocol-specialization` | CONFIRMED 2026-05-28 (per cross-layer doc) | Carried forward `[Verified: 2026-06-18 — cited, not re-run]` | **GROUND (0-witness foundation)** | Generic-over-`some Store.Protocol` algorithm specializes cross-module to **0 `witness_method`**; residual only in the unused generic fallback. The basis for the Step-2 specialization claim (§5). Not re-run per the brief. |
| `Experiments/property-inout-specialization` | CONFIRMED 2026-05-28 (per cross-layer doc) | Carried forward `[Verified: 2026-06-18 — cited, not re-run]` | **GROUND (the boundary line)** | Concrete-Base `Property.Inout` accessors flatten to 0-witness unconditionally; protocol-Base do **not** without `@inlinable` (→ the `~Copyable` borrow-init miscompile). Draws the REQUIRES/PROVIDES line. Not re-run. |
| `swift-buffer-primitives/Research/storage-generic-buffer-core.md` | v1.1.0 · RECOMMENDATION (per-package) | `[Verified: 2026-06-18]` | **KEEP / GROUND** | The two-lever model (generic-over-`some Storage.Protocol` algorithm = cold→default; concrete-Base `Property.Inout` = hot) — the Storage/Buffer realization of the specialization boundary. (Located at the *per-package* path, not the ecosystem `Research/`; the brief's bare name resolved here.) |
| `.handoffs/HANDOFF-buffer-storage-protocols.md` | 2026-05-25 · pilot complete | `[Verified: 2026-06-18]` | **GROUND** | Decision #4: "a buffer HAS-A storage, is not a kind-of storage → `Buffer.Protocol` does NOT refine `Storage.Protocol`." Decision #5: **`Buffer.Protocol` = consumer-facing capability protocol**, not an op-dispatch surface. Decision #6: protocols can't nest in generic types → every `*.Protocol` is a hoisted `__XProtocol` + `Protocol` typealias. Grounds points 1, 4, and the `__`-hoist naming rule. |

**Net** ([HANDOFF-013]): the model, the normal-form vocabulary, the warranted-refinement test, the
0-witness foundation, **and the `<ADT>.Protocol` consumer layer** all already exist in the corpus.
What this doc contributes is (a) the **formal statement of the full shape in R/C/D normal form**
including the layer `universal-adt-shape.md` omitted (point 4), (b) the **explicit reconciliation**
of the shape decision with the families-execution decision (the bound tension, §4.2), and (c) the
**Array-realignment caveat** that [MEM-COPY-018] imposes (§5).

---

## 2. Verified source facts (re-verified by reading the canonical sources; file:line)

All paths are the canonical (non-`.build`) sources under `swift-primitives/`. (A stale
`Array<Element>` copy exists inside graph-primitives' `.build/checkouts/` — ignored; the canonical
declaration is below.) Tags `[Verified: 2026-06-18]`.

| # | Fact | File:line | Verbatim |
|---|------|-----------|----------|
| F-A | **Array carries the foundational hard bound (THE OUTLIER)** | `swift-array-primitives/Sources/Array Primitive/Array.swift:44` | `public struct Array<S: Store.`Protocol` & Buffer.`Protocol` & ~Copyable>: ~Copyable where S.Count == Index<S.Element>.Count` |
| F-B | **Array's *additive* consumer conformance (already correct)** | `swift-array-primitives/Sources/Array Primitives/Array ~Copyable.swift:50` | `extension Array: Array.`Protocol` where S: Span.`Protocol` & ~Copyable {}` |
| F-C | **The per-ADT consumer protocol (hoisted) + alias** | `swift-array-primitives/Sources/Array Protocol Primitives/Array.Protocol.swift:20, :84` | `public protocol __ArrayProtocol: Collection.Bidirectional & ~Copyable { … }` ; `public typealias `Protocol` = __ArrayProtocol` |
| F-D | **Buffer is the target minimal-bound shape, already shipped** | `swift-buffer-primitives/Sources/Buffer Primitive/Buffer.swift:23` | `public enum Buffer<S: ~Copyable> {}` |
| F-E | **Buffer's additive capability conformance (the target pattern)** | `…/Buffer Linear Bounded Primitive/Buffer.Linear.Bounded+Buffer.Protocol.swift:21` (and `Buffer.Ring.Bounded` :23) | `extension Buffer.Linear.Bounded: Buffer.`Protocol` where S: ~Copyable { … }` |
| F-F | **`Store.Protocol` (`__StoreProtocol`) = the 4-op slot seam** | `swift-store-primitives/Sources/Store Protocol Primitives/Store.Protocol.swift:20,25,46,58,68,81` | `protocol __StoreProtocol: ~Copyable` requiring `capacity` (:25), `subscript(slot:) { get set }` (:46), `initialize(at:to:)` (:58), `move(at:)` (:68), defaulted `prepareForMutation()` (:81/:89) |
| F-G | **`Buffer.Protocol` (`__BufferProtocol`) = occupancy only** | `swift-buffer-primitives/Sources/Buffer Protocol Primitives/Buffer.Protocol.swift:22,41,51,67` | `protocol __BufferProtocol: ~Copyable, ~Escapable` requiring `count` (:41); `isEmpty` (:51) is a **(D) default** `count == .zero` (:67) |
| F-H | **`swift-store-primitives` depends on index only** | `swift-store-primitives/Package.swift:28` | sole dep `swift-index-primitives` (branch main) |
| F-I | **store-vs-storage split + the Step-7 OPEN overlap** | `swift-storage-primitives/Sources/Storage Protocol Primitives/` | The directory holds only `Store.Protocol+{Sequence,Fill,Move,Copy,Deinitialize}.swift` + `exports.swift`. **No `Storage.Protocol.swift` and NO `protocol __StorageProtocol` declaration exists anywhere** (grep `[Verified: 2026-06-18]`). The slot **protocol** is `Store.Protocol` (in swift-store-primitives); `swift-storage-primitives` provides the **concrete** `Storage.Contiguous` that conforms it. The `Storage Protocol Primitives` *product* exists but surfaces no `__StorageProtocol` — flag as the plan's **Step 7 OPEN item; not resolved here**. |

**The decisive pair.** F-A vs F-D + F-B/F-C/F-E:

- **`Array` (F-A)** binds `S: Store.Protocol & Buffer.Protocol` — a **foundational hard bound** on
  the ADT type. This is the **outlier**.
- **`Buffer` (F-D)** binds `S: ~Copyable` only, and layers capabilities *additively* by conditional
  conformance (F-E). **Buffer already implements the target shape.**
- **`Array` *also already* does the additive per-ADT consumer conformance** (F-B): `Array<S>`
  *itself* conditionally conforms `Array.Protocol` (F-C) `where S: Span.Protocol`. The *storage* `S`
  never conforms `Array.Protocol`. → **point 4 is already shipping in Array**; the foundational hard
  bound (F-A) is the only thing that needs to change to realign Array.

---

## 3. The formalized model (points 1–6) in R/C/D normal form

Vocabulary is `cross-layer-capability-protocol-model.md` §3.2 (KEEP): the **minimal orthogonal
cores** and the three **edge kinds** —

| Edge | Meaning | Mechanism |
|------|---------|-----------|
| **(R) Refine** (IS-A) | sub-protocol genuinely *is* the super; only within an axis where identity holds | `protocol P: Q` |
| **(C) Compose** (HAS-A / capability-conjunction) | a default/capability fires when the subject *also* satisfies another protocol; across axes | `extension X where S: Q { … }` |
| **(D) Provides-as-default** (intra-protocol derivation) | derive from a protocol's own requirements | `extension P { … }` |

### Point 1 — Minimal orthogonal cores (KEPT, principal-confirmed)

The capability cores stay **separate, minimal, composed-not-refined**:

| Core | Requires (irreducible) | Source |
|------|------------------------|--------|
| `Store.`Protocol`` | `capacity`, `subscript{get set}`, `initialize(at:to:)`, `move(at:)` (4 ops + defaulted `prepareForMutation`) | F-F |
| `Buffer.`Protocol`` | `count` (occupancy); `isEmpty` is **(D)** | F-G |
| `Memory.Contiguous.`Protocol`` | `span` | cross-layer §3.4 |
| `Set.`Protocol`` | `contains` + `count` (membership core) | cross-layer §4.2 |

A buffer **has-a** storage; a set **has-a** buffer; none **is-a** the layer below — the relations are
**(C)**, never **(R)**. **Element-access is NOT folded into Buffer; the "strict-layering /
one-protocol-below" idea is DROPPED.** (Grounded: `HANDOFF-buffer-storage-protocols.md` Decisions
#4/#5; `occupancy-encoding-2` — `Occupancy` does not refine `Store`; conformer sets OVERLAP not
NEST → sibling.)

### Point 2 — `struct ADT<S: ~Copyable>` (minimal bound; no foundational lower-protocol bound)

The ADT type binds **`~Copyable` only** — no `Store.Protocol`/`Buffer.Protocol`/any-core bound on
the type itself. This is **exactly how `Buffer<S: ~Copyable>` is shaped today** (F-D). Copyability
and teardown **flow from `S`** (`extension ADT: Copyable where S: Copyable`; the ADT carries no
`deinit`).

```swift
@frozen public struct ADT<S: ~Copyable>: ~Copyable {
    @usableFromInline package var storage: S
    @inlinable public init(storage: consuming S) { self.storage = storage }
    @inlinable public consuming func take() -> S { storage }
}
extension ADT: Copyable  where S: Copyable  {}
extension ADT: Sendable  where S: Sendable & ~Copyable {}
```

*Warranted-refinement justification for the no-bound* (derive-for-free C1–C4, applied to "should
`Store.Protocol` be a hard bound on a universal ADT?"): for a family that includes trees, a keyed
storage **is not** a slot-store by identity (**C1 fails**) and the conformer sets **overlap, do not
nest** (**C2 fails**) → the store seam **must not** be a hard bound on the type; it is a conditional
capability. (`universal-adt-shape.md` §"Why this"; `REPORT-tree-recomposition-R0-revalidation` is the
proof that keyed genuinely is not an `S` under the bound.)

### Point 3 — Capabilities layered by conditional extension on the orthogonal cores (edge-kind C)

Operations attach by **conditional extension keyed on the capability `S` supports** — never by a
hard bound on the type:

```swift
extension ADT where S: Store.`Protocol`  & ~Copyable { /* slot-tier ops */ }
extension ADT where S: Buffer.`Protocol` & ~Copyable { /* occupancy ops: count, isEmpty, … */ }
extension ADT where S: <child/keyed capability> & ~Copyable { /* tree/keyed ops */ }
```

This is the **cross-layer edge-kind (C)** — capability conjunction in an extension constraint. It is
the categorical product made type-level, "exactly as the shipping `Buffer.Arena` already does"
(`occupancy-encoding-2`). **GATE-1 proved it ×2 on 6.3.2** for one `Container<S>` carrying slot +
ordinal-child + keyed-child capabilities, with **negatives failing correctly** (array→child errors;
tree→slot errors) and **0 `witness_method`** in the `-O` cross-module client SIL
(`HANDOFF-tree-universal-shape.md` GATE-1).

### Point 4 — Additive per-ADT consumer protocol (the layer `universal-adt-shape.md` OMITTED)

`ADT<S>` *itself* conditionally conforms a **consumer-facing per-ADT protocol** — the
`__ArrayProtocol`/`Array.Protocol` layer (F-B/F-C) — **additively**, via:

```swift
extension ADT: ADT.`Protocol` where S: <cores the consumer surface needs> & ~Copyable {}
```

This is a **distinct layer** from point 3:

- **Point 3** is `extension ADT where S: Cap` — *un-conformed* capability ops on the ADT, keyed on
  what the **storage** supports.
- **Point 4** is `extension ADT: ADT.Protocol where S: Cap` — the **ADT type conforming a
  consumer-facing protocol** (`__ArrayProtocol: Collection.Bidirectional`), so generic consumers can
  write `func f<A: Array.Protocol>(_ a: A)`. **The storage `S` never conforms `ADT.Protocol`**; only
  `ADT<S>` does (F-B; corroborated by `HANDOFF-tree-universal-shape.md` GATE-2 recon line 111).

`ADT.Protocol` is a **hoisted** `__ADTProtocol` + a `Type.Protocol` typealias (protocols can't nest
in generic types — `HANDOFF-buffer-storage-protocols.md` Decision #6; F-C). It is **consumer-facing**
(`Buffer.Protocol` Decision #5), not an op-dispatch surface — hot mutating ops stay concrete-Base
(`property-inout-specialization`). Array **already does this correctly** (F-B); **Buffer already does
the capability-conformance form** (F-E). **This is the single additive correction** to
`universal-adt-shape.md` (§6).

### Point 5 — Deps decoupled (the decoupling proper)

The **generic ADT core depends only on the minimal *protocol* packages** (e.g. `Store Protocol
Primitives`, `Buffer Protocol Primitives`), which themselves are near-leaf (`swift-store-primitives`
depends on index only — F-H). **Concrete-column constructors** (the convenience inits that name
`Memory.Heap`, `Storage.Contiguous`, `Shared`, allocators) live in a **separate target**. This is
the literal "ADT/Buffer/Storage decoupling": Array's deep Memory/Storage deps today come **only** from
`Array.swift`'s convenience inits — splitting those out leaves the generic core depending on the
protocol packages alone. (Array's current import block — `Array.swift:12-20` — pulls
`Buffer_Linear_Primitive`, `Storage_Contiguous_Primitives`, `Memory_Heap_Primitives`,
`Memory_Allocator_Primitive`, `Shared_Primitive`; these are the concrete-constructor deps to relocate.)

### Point 6 — Array is the OUTLIER to be realigned (NOT the template)

`Array` (F-A) carries the foundational hard bound and is the **outlier**. **`Buffer` (F-D) is the
template** — it already has the minimal `~Copyable` bound and additive capability conformances. The
realignment drops Array's `S: Store.Protocol & Buffer.Protocol` bound to `S: ~Copyable`, moving the
slot/occupancy surface into conditional extensions (point 3) and **keeping** Array's already-correct
additive `Array: Array.Protocol` conformance (point 4 / F-B). **Tree is the first/reference adopter**
(done in isolation, `universal-adt-shape.md` §"Scope and sequencing"); **Array's own alignment
follows in a later pass** — see the **caveat in §5** (Array's per-column same-type method pins +
[MEM-COPY-018]), which is why Array's realignment is non-trivial and must be Step-2-confirmed, not
assumed.

---

## 4. Explicit reconciliation

### 4.1 With `cross-layer-capability-protocol-model.md` — minimal orthogonal cores (KEPT)

**KEPT, unchanged, and used as the backbone.** Its §3.2 normal form (R/C/D), its decision rule
(refine within an axis where identity holds; compose across axes), and its "Buffer HAS-A storage;
does not refine it" are the vocabulary of §3 above. Point 1 of the converged model **is** this
doc's §3.1 restated, principal-confirmed. Nothing in the converged model contradicts it; the
converged model *extends the same decided test one level up* — from "extra capabilities over a
**retained** `Store.Protocol` base bound" to "the base seam itself, for the full ADT family"
(`universal-adt-shape.md` §"Why this"). No supersession.

### 4.2 With `universal-adt-shape.md` — right on the skeleton; omitted point 4 — AND the bound tension

**What it got right (KEEP):** no foundational lower-protocol bound on the ADT type (`struct ADT<S:
~Copyable>`); capabilities by conditional extension; **compose-not-refine**; **minimal cores**;
the C1/C2 justification; GATE-1's 0-witness proof. All grounded in §2–§3.

**What it omitted (the single additive correction):** the **additive per-ADT consumer protocol**
(point 4). The DECISION doc describes only `struct ADT<S>` + conditional *capability* extensions
(its point-3-equivalent). It **never mentions** `ADT.Protocol`/`__ArrayProtocol`/the `Array:
Array.Protocol` conformance (grep returns empty, §1.2). Yet the prior art **already had this layer**
(`derive-for-free` names `<ADT>.Protocol` at the top of the stack; GAP-L hoists witnesses onto
`Array.Protocol`), Array **already ships it correctly** (F-B), and the doc's own GATE-2 recon
**rediscovered it** (line 111). So this is an **additive** correction — adding the omitted layer —
**not a teardown**. §6 gives the exact delta.

**The bound tension — reconciled, NOT a discrepancy ([RES-013a]/the brief's `ask:` rule):** the
families tranche (2026-06-10, ratified) built set/dict/queue/deque/slot-map **with** the hard bound
`S: Store.Protocol & Buffer.Protocol`, and **F-4 empirically walled** (one-variable proof) relaxing
`Shared`'s *declaration* bound to a smaller bound + conditional conformance, concluding "`Shared`'s
shipped bound is **load-bearing** and stays" → **[MEM-COPY-018]**. On its face this points *opposite*
to `universal-adt-shape.md`'s no-bound shape. **It is not a contradiction**, for three independently
sufficient reasons:

1. **Different subject.** [MEM-COPY-018] governs a **column combinator (`Shared`) consumed via
   `where S == Wrapper<E, Concrete<E>>` same-type *method* pins**, one layer *below* the ADT.
   `universal-adt-shape.md`'s no-bound rule governs the **ADT type** (`Tree<S>`, eventually
   `Array<S>`), which is consumed *generically*, not via same-type pins on its own storage. The
   GATE-1 proof uses no such pins. These are **distinct constructs at distinct layers**.
2. **Scope/sequencing is explicit.** `universal-adt-shape.md` §"Scope and sequencing" states **Tree
   is the first adopter**; **Array's and the rest of the family's alignment "follow in their own
   later passes."** The families were built *before* the shape decision, to the *then-current*
   playbook. The shape decision does not retroactively invalidate them; it sets the **shared target**
   they migrate toward.
3. **The bound was *correct* for the slot-store families.** Every families-tranche leaf
   (array/queue/set/dict/slot-map storage) **genuinely is a slot-store** — it conforms
   `Store.Protocol`. Run C1/C2 for *those* families and the store seam **passes** (every leaf IS-A
   slot-store; conformer sets nest) — so the hard bound is *warranted* there. The seam fails C1/C2
   **only** when the family must include **trees** (keyed storage is not a slot-store). This is
   precisely `universal-adt-shape.md`'s own reasoning ("those notes applied the rule to extra
   capabilities over a **retained** `Store.Protocol` base bound — because in the storage tier every
   leaf genuinely is a slot-store"). The no-bound generalizes the test to the **tree-inclusive**
   universal family; it does not declare the bounded slot-store families wrong.

→ **No HALT-triggering contradiction.** The converged model stands. The tension resolves to a
**layer boundary + a sequencing clause**, and to a **caveat on Array's realignment** (§5).

### 4.3 With the families execution (COORDINATE) and the R0 "wall" (GROUND)

- The **families execution** (`REPORT-ADT-families-*`) is the *prior, layer-consistent* build; it
  **coordinates** with the shape decision via §4.2 (the slot-store families migrate to the no-bound
  shape in their own later passes, carrying the [MEM-COPY-018] caveat wherever they use `Shared`
  same-type pins).
- The **R0 revalidation "wall"** (`Tree` can't be `Tree<S>`) is **grounded** as the artifact the
  no-bound shape dissolves: keyed storage conforms neither core, so a hard `S: Store.Protocol` bound
  excludes it; removing the bound (point 2) + conditional child capability (point 3) admits it —
  GATE-1 proved exactly this (`Container<KeyedChildStore>` builds + runs).

---

## 5. The Array-outlier finding + Buffer-already-implements-the-target (and the realignment caveat)

**Finding (F-A/F-D/F-B):**

- **`Array` is the OUTLIER**: it carries the foundational hard bound `S: Store.Protocol &
  Buffer.Protocol` on the type (F-A). It is *not* the template.
- **`Buffer` already implements the target shape**: `enum Buffer<S: ~Copyable>` (F-D) with capability
  conformances added *additively* (F-E). The shape `universal-adt-shape.md` directs is **already
  shipping** at the buffer tier.
- **Array already does point 4 correctly**: `extension Array: Array.Protocol where S: Span.Protocol`
  (F-B) — the additive per-ADT consumer conformance. So Array's realignment is **drop the type-level
  bound** (point 6) while **keeping** its additive conformance (point 4).

**Caveat (load-bearing; do not gloss — surfaced per the brief's `ask:` discipline):** Array's
realignment is **not** a free find-and-replace of the bound, because of **[MEM-COPY-018]** (minted
from families-tranche F-4). Array's per-column construction/growth methods pin per column with
**same-type method pins** `where S == Shared<E, Buffer.Linear>` (the Array-playbook mechanic #2), and
those pins **must derive `S`'s seam obligations**. [MEM-COPY-018] proves a conditional
*protocol-keyed* conformance does **not** derive through such a pin (the requirement machine reifies a
concrete-subject requirement, which is ill-formed). For the **storage column combinator (`Shared`)**
the rule's conclusion is "keep the obligations in the **declaration** bound" — and `Shared`'s bound
stays. The **open question for Array's realignment** is whether dropping `Array<S>`'s *type-level*
bound to `~Copyable` (point 2) leaves Array's same-type-pinned methods able to see `S`'s seam
obligations through their own `where S == …` pins. **Tree had no such pins (GATE-1 proved it fresh);
Array does.** This is a **Step-2 confirmation target**, possibly a genuine wall **specific to Array**,
and must not be assumed away. It does **not** affect the *shape* decision (the shape is proven); it
affects the *Array adoption pass*, which `universal-adt-shape.md` already stages as "a later pass."

---

## 6. Recommended disposition of `universal-adt-shape.md` — AMEND IN PLACE (additive)

**Recommendation: amend in place (v1.0.0 → v1.1.0), NOT supersede.** The DECISION is **right** on
everything it states; its only gap is *omission* of point 4, which is additive and already shipping
in Array (F-B) and named in the corpus (`derive-for-free`). Supersession would discard a correct,
freshly-ratified, compiler-verified decision over a single additive gap — the wrong instrument
([RES-008] lifecycle: update concluded research, preserve original analysis).

**Exact delta** (the seat/principal apply on ratification of *this* RECOMMENDATION; this doc edits
no other doc):

1. **Add a fourth shape clause** to the Decision section (after the conditional-capability-extension
   clause). Proposed text:

   > **Additive per-ADT consumer protocol.** `ADT<S>` *itself* conditionally conforms a
   > consumer-facing per-ADT protocol — `extension ADT: ADT.`Protocol` where S: <cores>` — the
   > `__ArrayProtocol`/`Array.Protocol` layer (`Array ~Copyable.swift:50`). This is **distinct** from
   > the capability extensions: those are un-conformed ops keyed on the storage; this is the ADT type
   > conforming a consumer-facing protocol so generic consumers can constrain on `ADT.Protocol`. The
   > **storage `S` never conforms `ADT.Protocol`** — only `ADT<S>` does. `ADT.Protocol` is a hoisted
   > `__ADTProtocol` + `Type.Protocol` typealias ([PKG-NAME-006]; protocols can't nest in generic
   > types) and is **consumer-facing, not an op-dispatch surface** (hot mutating ops stay
   > concrete-Base). **Array and Buffer already implement this correctly.**

2. **Add the Array-realignment caveat** to the "Scope and sequencing" section (so the later Array
   pass is not assumed trivial). Proposed text:

   > **Array-realignment caveat ([MEM-COPY-018]).** Array's per-column construction/growth methods use
   > same-type `where S == Shared<…>` pins; those pins must derive `S`'s seam obligations. Whether
   > dropping `Array<S>`'s type-level bound to `~Copyable` leaves those pins well-formed is a Step-2
   > confirmation item (possibly an Array-specific wall) — Tree had no such pins (GATE-1 fresh); Array
   > does. Confirm before the Array adoption pass.

3. **Add to References** (or `builds_on`): this doc (`adt-buffer-storage-decoupling-shape.md`),
   `derive-for-free-capability-composition.md` (for the `<ADT>.Protocol` consumer layer), and the
   `REPORT-ADT-families-*` set + [MEM-COPY-018] (for the bound reconciliation + caveat).

4. **Bump** `version: 1.0.0 → 1.1.0`, `last_updated`, and append a changelog entry:
   *"1.1.0: ADDITIVE correction — added the omitted per-ADT consumer-protocol clause (point 4) +
   the [MEM-COPY-018] Array-realignment caveat; reconciled with the 2026-06-10 families-execution
   bound (no contradiction — layer boundary + sequencing). Per adt-buffer-storage-decoupling-shape.md."*

The DECISION's **status stays DECISION** after the amendment (it remains a ratified decision; the
amendment is additive, [RES-006a] "promotion is elevation, not invalidation"). This doc stays
**RECOMMENDATION** until SEAT-verified and principal-ratified.

---

## 7. Pointer to Step 2's confirmation target

**Step 2 confirms the full combination as a union** (the shape decision proved the skeleton; Step 2
proves the *whole shape together* compiles + specializes):

> minimal-bound `struct ADT<S: ~Copyable>` (point 2) **+** conditional-extension ops on *separate*
> orthogonal cores (point 3, `Store.Protocol` / `Buffer.Protocol` / child capability) **+** the
> additive `extension ADT: ADT.Protocol where S: <cores>` (point 4) → **builds ×2** (debug + `-O`),
> **0 warnings**, **0 `witness_method`** in the cross-module `-O` client SIL, on **Swift 6.3.2**.

**Basis (cite, do not re-run — per the brief):** GATE-1 already proved the skeleton + conditional
capabilities + 0-witness for `Container<S>` (`HANDOFF-tree-universal-shape.md`); `Experiments/
storage-protocol-specialization` proves generic-over-`some Store.Protocol` → 0-witness;
`Experiments/property-inout-specialization` draws the concrete-Base boundary;
`occupancy-encoding-2`'s spikes prove the `where S: Cap` conjunction + 0-witness cross-module. **What
Step 2 adds** is the *union* — specifically that adding the **point-4 conformance** (`extension ADT:
ADT.Protocol where S: <cores>`) on top of the no-bound + conditional-capability shape **does not**
re-introduce a hard bound, a warning, or a `witness_method` (GATE-1 carried capabilities but did
**not** add an `ADT.Protocol` conformance; that conjunction is the delta Step 2 confirms). **Array's
same-type-pin question (§5) is the second Step-2 target** — confirm the pins survive the bound drop,
or surface the wall.

---

## 8. Open items carried forward (not resolved here)

- **Step 7 (storage-protocol overlap, F-I):** there is a `Storage Protocol Primitives` *product* but
  **no `__StorageProtocol` declaration** — the slot protocol is `Store.Protocol` (store-primitives);
  `swift-storage-primitives` ships the concrete `Storage.Contiguous`. This naming/overlap is the
  plan's **Step 7**; flagged, **not resolved here** (per the brief).
- **Array same-type-pin realignment (§5):** Step-2 confirmation; possibly an Array-specific
  [MEM-COPY-018] wall. Surface, do not assume.
- The honest copyability residual (`bit-density ∧ value-semantics ∧ inline` ⟹ move-only, SE-0427) is
  a property of one leaf instantiation, not of the shape (`universal-adt-shape.md` §"Honest residual";
  `occupancy-encoding-2`). Not re-litigated.

---

## Outcome

**Status: RECOMMENDATION / DRAFT — NOT a final DECISION.** The canonical ADT shape is: every tower
container is **`struct ADT<S: ~Copyable>`** (point 2, the `Buffer<S>` shape) over **minimal
orthogonal cores** that **compose, not refine** (point 1, KEPT from
`cross-layer-capability-protocol-model.md`), with **capability ops by conditional extension keyed on
the cores** (point 3, edge-kind C, GATE-1-proven) **and** an **additive per-ADT consumer protocol**
`extension ADT: ADT.Protocol where S: <cores>` (point 4 — the layer `universal-adt-shape.md` omitted;
already shipping in Array F-B, in Buffer F-E), with **deps decoupled** so the generic core depends
only on the protocol packages (point 5). **`Buffer` already implements the target; `Array` is the
outlier** carrying a foundational hard bound (point 6, F-A).

The single correction to `universal-adt-shape.md` is **additive** (point 4) — **amend in place**
(§6), do not supersede; the DECISION was right on no-bound / minimal-cores / compose-not-refine. The
2026-06-10 families-execution bound is **not** a contradiction (§4.2): it is a *layer boundary*
([MEM-COPY-018] governs the `Shared` combinator's declaration bound, not the ADT type) plus an
explicit *sequencing clause* (Array and the slot-store families realign in later passes), plus the
**load-bearing caveat** (§5) that Array's same-type method pins make its realignment a Step-2
confirmation target, possibly a wall. Step 2 confirms the **union** of points 2+3+4 (builds ×2,
0-warn, 0 `witness_method` on 6.3.2) and Array's pin survival, citing the existing experiments as the
basis (§7). **HALT for SEAT verification against source + prior art before principal ratification.**

## References

- `swift-institute/Research/universal-adt-shape.md` — DECISION (Tier 3, 2026-06-18): the skeleton this corrects additively.
- `swift-institute/Research/cross-layer-capability-protocol-model.md` — RECOMMENDATION/APPROVED (Tier 3): minimal orthogonal cores + the R/C/D normal form (backbone, KEPT).
- `swift-institute/Research/derive-for-free-capability-composition.md` — RECOMMENDATION (Tier 3): the warranted-refinement test C1–C4; names the `<ADT>.Protocol` consumer layer.
- `swift-institute/Research/occupancy-encoding-2-category-theory-composition.md` — RECOMMENDATION (Tier 3): composition-over-refinement, proven ×2 on 6.3.2.
- `swift-buffer-primitives/Research/storage-generic-buffer-core.md` — RECOMMENDATION (per-package): the two-lever model.
- `.handoffs/HANDOFF-tree-universal-shape.md` — GATE-1 proof + receipts (`/tmp/uadt/`); GATE-2 recon (line 111).
- `.handoffs/REPORT-ADT-families-{composition,spike-findings,execution,leg8-execution}.md` + `GOAL-tower-adt-families.md` — the 2026-06-10 families execution (the hard-bound build) + F-4/[MEM-COPY-018].
- `.handoffs/REPORT-tree-recomposition-R0-revalidation.md` — the "tree can't be `Tree<S>`" wall the no-bound dissolves.
- `.handoffs/HANDOFF-buffer-storage-protocols.md` — Buffer HAS-A storage (#4); `Buffer.Protocol` consumer-facing (#5); hoisted-protocol nesting limit (#6).
- `swift-institute/Skills/memory-safety/advanced-ownership.md` [MEM-COPY-018] — same-type method pins derive suppression, not conformance, conditions (the Array-realignment caveat).
- `Experiments/storage-protocol-specialization`, `Experiments/property-inout-specialization` — the 0-witness foundations (cited, not re-run).
- Source: `Array.swift:44`, `Array ~Copyable.swift:50`, `Array.Protocol.swift:20/84`, `Buffer.swift:23`, `Store.Protocol.swift` (4-op seam), `Buffer.Protocol.swift` (count) — all `[Verified: 2026-06-18]`.
