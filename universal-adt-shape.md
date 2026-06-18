# The Universal ADT Shape — Storage-Generic + Layered Capabilities

<!--
---
version: 1.0.0
last_updated: 2026-06-18
status: SUPERSEDED 2026-06-18 by the Charter in the ecosystem-data-structures skill ([DS-025]–[DS-027]). Retained as historical rationale; NOT normative — read the skill.
tier: 3
scope: ecosystem-wide (the tower container ADTs — array, queue, stack, deque, set, dictionary, heap, tree, …)
type: architecture/decision
toolchain_of_record: Apple Swift 6.3.2 (swift-6.3.2-RELEASE, TOOLCHAINS=org.swift.632202605101a)
builds_on:
  - swift-institute/Research/occupancy-encoding-2-category-theory-composition.md   # composition-over-refinement, proven ×2 on 6.3.2
  - swift-institute/Research/derive-for-free-capability-composition.md             # the warranted-refinement test (C1–C4)
  - swift-institute/Research/cross-layer-capability-protocol-model.md              # Buffer HAS-A storage; doesn't refine it
supersedes_partially: the tree-recomposition corrected-E SHAPE (its ENGINE is reused; only the skeleton is superseded)
provenance: principal direction (2026-06-17); GATE-1 validation probe (executor), seat-verified on 6.3.2 (2026-06-18); scratch /tmp/uadt/
---
-->

**Coen ten Thije Boonkkamp · Swift Institute · June 2026**

> **⚠️ SUPERSEDED 2026-06-18.** The canonical rules now live in the `ecosystem-data-structures` skill —
> [DS-025] (canonical ADT shape), [DS-026] (conformance predicate + three-shape taxonomy), [DS-027]
> (packaging law). This document is retained as historical rationale only; for the normative Charter,
> read the skill. The layer this doc omitted (the additive per-ADT consumer protocol) and the packaging
> law it lacked are both in the skill; `adt-buffer-storage-decoupling-shape.md` is the rationale companion.

## Decision

Every tower container ADT is **`struct ADT<S>`** — a thin generic over a storage `S` minimally bound
(`~Copyable` only). The ADT's operations are supplied by **conditional extensions keyed on the
capabilities `S` supports** — `extension ADT where S: SlotStore { … }`,
`extension ADT where S: ChildStore { … }`, … — never by a hard storage bound on the type. **No storage
capability protocol is a requirement on the ADT type; capabilities compose (conjunction in extension
constraints), they do not refine.** Copyability and teardown flow from `S`.

This is the *pattern*, applied per ADT: `Array<S>` carries the slot layer; `Tree<S>` carries the
child/traversal layer; each ADT is `X<S>` over a storage with its own conditional-capability extensions.

**Naming** is part of the shape: a `__`-prefixed spelling is reserved for the one escape hatch Swift
forces — a protocol hoisted out of a generic type ([PKG-NAME-006]). Every other nested type is
`Type.X` (Nest.Name, [API-NAME-001]); where an element-agnostic phantom tag must be hoisted, hoist the
real decl and expose a `Type.X` typealias (the pool mechanic) — never a public `__` spelling.

## Why this, and why now

The container family must share one shape so a reader who learns `Array<S>` understands `Tree<S>`.
The corpus had already decided the *mechanism*: `occupancy-encoding-2` proved (×2 on 6.3.2) that a
capability attaches to a generic container by **conditional extension** — composition, not refinement —
and `derive-for-free`'s **warranted-refinement test** (C1–C4) is the standing rule: *compose by default;
make a protocol a hard bound only when it is a genuine identity-subset (C1) with nesting conformer-sets
(C2).* But those notes applied the rule to *extra* capabilities layered over a **retained** `Store.Protocol`
base bound — because in the storage tier every leaf genuinely *is* a slot-store.

This decision extends the same decided test one level up — to the base seam itself, for the full ADT
family. Run C1/C2 on *"should `Store.Protocol` be a hard bound on a universal ADT that includes trees?"*:
a keyed-tree storage is **not** a slot-store by identity (C1 fails) and the conformer-sets overlap, do
not nest (C2 fails) → **by the corpus's own test, the store seam must NOT be a hard bound on the type;
it is a conditional capability.** The "tree can't be `Tree<S>`" wall (`tree-recomposition-R0-revalidation`)
was an artifact of the hard `S: Store.Protocol` bound; removing it dissolves the wall.

## Proof (GATE-1 validation probe; seat-verified on 6.3.2, 2026-06-18)

Scratch: `/tmp/uadt/`. One `Container<S>` (`S: ~Copyable`, `Copyable where S: Copyable`) carrying a slot
capability (mirroring the 4-op `__StoreProtocol` verbatim) and a child capability (per-conformer
`Address`: `Int` for ordinal trees, `Key` for keyed) — both as conditional extensions, neither refining
the other, neither bounding `Container`.

| Claim | Verdict (seat-rebuilt from source) |
|---|---|
| Positive build ×2 (debug + `-O`) | rc=0, **0 warn / 0 err** both |
| Slot + ordinal-child + keyed-child capabilities all layered; copyability flows from `S` | run output identical ×2 (copy-independence; ord-tree child@1=2; keyed-tree child[right]=2; move-only `Container<HeapSlots<Token>>` is `~Copyable`) |
| Negative controls fail-to-compile as designed | array→child `rc=1` "conform to 'ChildStore'"; tree→slot `rc=1` "conform to 'SlotStore'" |
| **Keyed storage (NOT a slot-store) is a valid `Container<S>`** (R0 wall dissolves) | `Container<KeyedChildStore>` builds + runs |
| Full specialization — zero dynamic dispatch | **0** `witness_method` in the `-O` cross-module client SIL |

**Faithful reductions** ([EXP-004]/[EXP-020], as the occupancy-doc spikes used): `Int` handles, a plain
`[Node]` arena, `Element==Int` in the SIL driver — they isolate the *shape* claim and do not bear on it.
GATE 1 proves the **skeleton**; the single-leaf conditional-`Copyable` arena (CoW via `Shared`, no buffer
`deinit`) is the shipping R1 engine (`Tree.Storage` + occupancy-doc S5), **reused, not re-proven**.

## What this supersedes — and what it keeps

- **Supersedes** the tree corrected-E *shape* — storage hidden behind a `Tree.Protocol` conformance —
  which diverged from this family pattern (it predates connecting the tree arc to the composition test).
- **Keeps** the R1 *engine* verbatim: the generational arena, `handle(at:)`/decode, traversal + keyed
  algorithms, and the test suites. The reshape is a re-skeleton, not a rewrite.

## Scope and sequencing

- **Tree is the first / reference adopter**, done **in isolation** (tree-recomposition GATE 2): its
  downstream consumers are out of scope and adapt in a later pass.
- **Array's own alignment** (drop its hard `S: Store.Protocol` bound → layered) and the rest of the
  family follow in their own later passes. This decision is the shared target; adoption is staged.

## Honest residual

The same single corner the occupancy doc mapped: *bit-density ∧ value-semantics ∧ inline* forces
move-only (SE-0427). It is a property of one leaf instantiation, not of the shape, and the carve-out
*type* still dissolves into one `ADT<S>`. Not re-litigated here.

## References
- `swift-institute/Research/occupancy-encoding-2-category-theory-composition.md` — DECISION/RECOMMENDATION (Tier 3): composition over refinement; the mechanism this generalizes.
- `swift-institute/Research/derive-for-free-capability-composition.md` — RECOMMENDATION (Tier 3): the warranted-refinement test C1–C4, applied here to the base seam.
- `swift-institute/Research/cross-layer-capability-protocol-model.md` — RECOMMENDATION (Tier 3, APPROVED): Buffer HAS-A storage.
- `.handoffs/HANDOFF-tree-universal-shape.md` § GATE 1 — the executor receipts; `/tmp/uadt/` — sources + binaries + SIL (seat-verified 2026-06-18).
