# Order-Theoretic Cluster — Decomposition, Composition, and Modernization

<!--
---
version: 1.0.0
last_updated: 2026-05-28
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
supersedes: finite-interval-polarity-decomposition.md
---
-->

> **Scope.** Reconciles type placement *and* `[MOD-031]` modernization across the
> order-theoretic primitive cluster — `swift-comparison-primitives`,
> `swift-order-primitives`, a new `swift-interval-primitives`,
> `swift-finite-primitives`, and the *classification overflow* currently parked in
> `swift-algebra-primitives`. Supersedes `finite-interval-polarity-decomposition.md`
> (which scoped only the four finite enums); that doc's cross-ecosystem SLR,
> bit-precedent framing, and `Bound`-collision analysis are carried forward by
> reference and remain the detailed source.
>
> **Execution is delegated, not inline.** Per principal direction (2026-05-28),
> once this plan is approved, implementation proceeds via an
> **orchestrator/supervisor + subordinate/implementer** pattern (subagents or
> `/handoff`), never hands-on-keyboard from the planning session. This doc is
> **plan-only**; no source is changed by it. The phased plan below is written to be
> dispatchable.

---

## 1. Context

`finite-interval-polarity-decomposition.md` diagnosed four enums
(`Bound`/`Boundary`/`Endpoint`/`Gradient`) as mis-parented in
`swift-finite-primitives`. Investigating the destination surfaced a larger truth:
**the order-theoretic cluster is half-modernized and its types are scattered across
four packages by incidental structure rather than semantic domain.** All of
`Comparison`, `Order`, `Interval`-concepts, and the order-direction/monotonicity
classifications are **MSC 06-XX** ("Order, lattices, ordered algebraic
structures"); several currently live in `swift-algebra-primitives` (**MSC 08-XX**,
general algebraic systems) purely because they are small enums that carry an
algebraic involution.

**Trigger.** Principal direction (2026-05-28) to widen the finite investigation
into a cluster decomposition + modernization program, **with finite-first
sequencing** (remove `finite`'s `algebra` dependency as step 1).

**Tier 3** `[RES-020]`: ecosystem-wide, precedent-setting (fixes the 06-XX cluster's
shape for the long run), hard-to-undo, timeless. Optimized for evergreen /
correctness via decomposition + composition `[ARCH-LAYER-008]`, not consumer count.

---

## 2. Current-State Inventory `[Verified: 2026-05-28]`

| Package | MSC | `[MOD-031]` modernized? | Contents |
|---------|-----|--------------------------|----------|
| `swift-comparison-primitives` | 06-XX | **Yes** (singular `Comparison Primitive` root + `Comparison Protocol`/`Property`/`Tagged`/SLI sub-targets + umbrella + TS) | `Comparison` (less/equal/greater), `Comparison.Protocol` (institute `Comparable`; refines `Equation.Protocol`; → `Swift.Comparable` on 6.4+), `Comparison.Compare`, `Comparison.Clamp` |
| `swift-order-primitives` | 06-XX | **No** (single flat `Order Primitives` target) | `Order`, `Order.Direction` (asc/desc + `.reversed`), `Order.Comparator<T>` (+ Chaining/Reversal/Projection/Partial/Comparable), `Order.Orderable` (empty marker), `Order.Projection`. Deps: comparison, property |
| `swift-finite-primitives` | (capability) | **No** (legacy `[MOD-001]` Core + implementation-bearing umbrella) | (A) `Finite.Enumerable`/`Enumeration`/`Capacity`, `Finite.Bound<N>` tag, `Ordinal.Finite<N>`, `Index.Bounded<N>`; (B) the four enums + their `Algebra.Group<X>.z2` witnesses + `X+Finite` conformances. Deps incl. **algebra, algebra-group**, comparison |
| `swift-algebra-primitives` | 08-XX | **Yes** (singular `Algebra Primitive` root + per-type targets + umbrella + TS) | `Algebra` namespace, `Algebra.Iso<A,B>`, top-level `Parity`/`Sign`/`Polarity`/`Monotonicity`/`Ternary` |
| `swift-interval-primitives` | 06-XX | **(to be created)** | — |

Algebraic *structures* (`Algebra.Group`/`Field`/`Ring`/…) already live in their own
sibling packages; only `Algebra.Group+Parity` / `Algebra.Field+Parity` are bound to a
classification enum.

---

## 3. First-Principles Assessment: `Comparison` ↔ `Order`

The two-package split is **principled and correct**, on an *intrinsic vs extrinsic
ordering* axis:

- **`Comparison` = the relation (the atom).** "Given two values, how do they
  relate?" — the 3-way **result** (`Comparison`), the **intrinsic** total-order
  capability (`Comparison.Protocol` = institute `Comparable`), and elementary ops
  (`Compare`, `Clamp`). Foundational; no dependency on `Order`.
- **`Order` = arrangement built on the relation.** "How do we arrange/sort, using
  comparison strategies?" — reified composable **comparators** (`Order.Comparator`),
  **direction** (`Order.Direction`), projections, and **extrinsic** orderability
  (`Order.Orderable` = "orderable by a supplied comparator, even without an intrinsic
  order"). Depends on `Comparison` ✓ (correct direction — `Comparison` is the lower
  atom).

**Two defects confirm the relationship "was not carefully considered":**

1. **`Order.Orderable` is a near-vacuous empty marker** (`protocol Orderable: ~Copyable {}`)
   whose sole job is to host the `.order` fluent accessor. Its real semantic — the
   *extrinsic* complement to `Comparison.Protocol`'s *intrinsic* order — is undocumented,
   and the empty-marker realization is thin (`[MOD-RENT]`, `[API-NAME-001a]`). **Decision
   needed** (Phase 4): document-and-justify the intrinsic/extrinsic split, or fold `.order`
   onto `Comparison.Protocol`.
2. **Cluster half-modernized**: `comparison` + `algebra` are `[MOD-031]`-clean;
   `order` + `finite` are not — which is *why* placements drifted (there was no
   modern per-sub-namespace home to land them in).

**Verdict**: keep the `Comparison`/`Order` split and the `Order → Comparison`
dependency; treat `Order` as the 06-XX *arrangement* layer that the interval and
direction vocabulary joins.

---

## 4. Placement Principle — Constitutive Identity vs Incidental Property

A type's package home is its **constitutive identity** (the concept it exists to
name), never an **incidental property** it possesses (a capability it conforms to, a
structural shape it shares with unrelated types, or a consumer that uses it).
Criteria, priority-ordered (mirroring `[RES-029]`'s tiering):

- **C1 — Constitutive test (`[MOD-DOMAIN]`, `[RES-029]` tier 1).** Complete *"T exists
  in order to express ___."* The blank is the home. A capability, a cardinality, or a
  consumer can never fill the blank.
- **C2 — Capability ≠ home.** If a candidate home is a protocol whose conformers span
  *multiple unrelated domains*, it is a **capability**, not a domain. Homing a type
  where its capability-protocol lives is the "`Int` belongs in `Hashable`" error.
- **C3 — Adjacent consensus (`[RES-029]` tier 2).** Where do sibling concepts live,
  in-ecosystem and cross-ecosystem? Operational consensus outranks aesthetic grouping.
- **C4 — Primitiveness (`[MOD-029]`).** *Tiebreaker only*: among semantically-valid
  homes, prefer the one minimizing T's dependency tree. A bare type is primitive in
  *any* modernized home, so this rarely selects a domain.
- **C5 — Bridge independence.** If T's secondary structure is conferred by a *generic*
  bridge over a capability, T's home need not coincide with the bridge's
  recipient-capability.

**Worked verdict — the classification enums are homed by constitutive domain, not by
the `Finite` capability.** `Finite.Enumerable` is a capability (its conformers span
algebra, order, games — **C2**); none of the four enums exists *to express finiteness*
(**C1** — `Gradient` expresses *direction*, `Bound` *which-end-of-interval*);
`Order.Direction` already lives in `order`, and cross-ecosystem direction lives in
`cmp`/`Ord`, never in a "finite" module (**C3**). "Most primitive" (**C4**) is neutral —
a bare enum is primitive in any `[MOD-031]`-modernized home; the only un-primitive case
(`Order.Direction` behind `order`'s `comparison` dep) is an artifact of `order` being
un-modernized, which Phase 3 fixes. And the generic `finite-algebra` bridge confers the
ℤ/2ℤ structure regardless of home (**C5**), so a Finite home buys nothing. The FOR-finite
case rested only on a tiebreaker and on symmetry with the `algebra` classification family
— itself flagged mis-parented (§2), and whose one legitimate member, `Parity`, is in
`algebra` by **C1** (parity/ℤ2 *is* a number-theoretic concept), not by structural
grouping.

**Capability-recipient vs domain-home — why `swift-finite-algebra` is still correct.**
The bridge name (`[PKG-NAME-016]` recipient-then-provider) refers to the
**`Finite.Enumerable` *capability*** as the recipient (any conformer, regardless of
domain), not to the Finite *domain*. `Order.Direction` and `Interval.Bound` conform
`Finite.Enumerable`, so they are valid recipients of the generic witnesses while living
in their constitutive domains. The capability is the bridge's hinge; the domain is the
type's home — both hold at once.

---

## 5. Placement Reconciliation (the decisions)

Driven by §4 + `[RES-029]` (semantic identity first) + the cross-ecosystem SLR (carried
from the superseded doc: Haskell `data Boundary = Open|Closed`; Boost.ICL
`interval_bounds` = `Bound × Boundary`; Rust/PG/IEEE-1788; the 3-way `Bound`
overload) + MSC anchoring.

| Type (current home) | Decision | Target | Rule basis |
|---------------------|----------|--------|------------|
| `Bound` (finite) | **move + namespace** | `Interval.Bound` → new `swift-interval-primitives` | `[API-NAME-001/001a/001b]`, `[MOD-DOMAIN]`, `[PKG-NAME-001]` |
| `Boundary` (finite) | move + namespace | `Interval.Boundary` | same |
| `Endpoint` (finite) | move + namespace | `Interval.Endpoint` | same |
| `Gradient` (finite) | **UNIFY (duplicate) — keep `Order.Direction`, drop `Gradient`** | `Order.Direction` (already exists in `order-primitives`; its constitutive home, realized as a primitive zero-dep `Order Direction Primitives` sub-target post-`[MOD-031]`). Delete finite's `Gradient`. | §4 (C1/C3; C4 neutral once `order` is modern), `[API-NAME-004]` |
| `Monotonicity` (algebra) | move | `Order.Monotonicity` (06-XX; 3-valued direction-with-`constant`, sibling of `Direction`) | `[MOD-DOMAIN]`, MSC 06-XX |
| `Sign` (algebra) | **triage (Phase 4)** | numeric/order — candidate `Comparison`/numeric; **not** algebra | open |
| `Polarity` (algebra) | triage (Phase 4) | physics classification — no current math home; likely stays standalone/grab-bag | open |
| `Ternary` (algebra) | triage (Phase 4) | numeric/numeral (balanced ternary; depends on `Sign`) | open |
| `Parity` (algebra) | **stay** | `swift-algebra-primitives` — genuine ℤ/2ℤ element; only enum with packaged `Algebra.Group`/`Field` witnesses | `[MOD-RENT]` (passes) |
| `Algebra.Iso` (algebra) | **stay (flag)** | `swift-algebra-primitives` — properly nested; but `Optic.Iso` exists → "who owns Iso" is a Phase-4 question | open |

**ℤ/2ℤ (and ℤ/Nℤ) witness placement — ONE generic bridge** (`[MOD-014]` + `[PKG-NAME-016]` recipient-then-provider; confirmed by principal 2026-05-28):

A single **`swift-finite-algebra-primitives`** bridge (deps: `finite` + `algebra` +
`algebra-group`) holds the entire `finite ⊗ algebra` integration surface. It is
**generic over `Finite.Enumerable`**, not per-type:

- A `Finite.Enumerable` of count *N* is isomorphic to the cyclic group **ℤ/Nℤ** via its
  `ordinal` bijection (the existing per-type witnesses already *are* this — `forward:
  { $0 == .lower ? .even : .odd }` is `ordinal 0/1 ↔ Parity`). So a generic
  `extension Algebra.Group where Element: Finite.Enumerable` (cyclic via `ordinal` mod
  `count`) confers ℤ/2ℤ (and ℤ/Nℤ) on **every** conformer — `Order.Direction`,
  `Interval.Bound/Boundary/Endpoint`, and the algebra classifications — for free,
  regardless of their home domain (**§4 C5**).
- This is also the home for the **`Algebra.Z<n>` / `Algebra.Residue` / `Algebra.Residual:
  Finite.Capacity`** residue system, which `algebra-primitives-package-split.md` already
  flagged as "structurally coupled to finite-primitives."
- It **subsumes** the per-domain bridges floated earlier (no `interval-algebra`, no
  `order-algebra`, no separate `algebra-finite`). Optional per-type sugar accessors
  (`Interval.Bound.z2`, `Order.Direction.z2`) MAY be added here over the generic witness
  if wanted (would add `interval`/`order` deps to the bridge); default is generic-only.
- `Parity`'s existing `Algebra.Group+Parity` / `Algebra.Field+Parity` witnesses stay in
  `algebra-group`/`algebra-field` (unchanged).

---

## 6. Target Package Graph (after the full program)

```
comparison-primitives (06-XX, atom: relation)         [modern ✓]
        ▲
order-primitives (06-XX, arrangement; owns Direction) [Phase 3: modernize + absorb Monotonicity]
        ▲                         ▲
interval-primitives (06-XX)   finite-primitives        [Phase 1: created]  [Phase 1: algebra-free; Phase 2: modernize]
   (Bound/Boundary/Endpoint)      (Enumerable/Bounded/Capacity; conforms interval/order/comparison types down)
                                       │ (downward conformance deps: → interval, → order, → comparison)
                                       ▼
                          finite-algebra-primitives (bridge: finite + algebra + algebra-group)
                            (generic Algebra.Group over Finite.Enumerable = ℤ/Nℤ cyclic;
                             Algebra.Z<n>/Residue system; algebra-classification : Finite.Enumerable)
        ▲
algebra-primitives (08-XX: Algebra, Iso, Parity[, Sign/Polarity/Ternary pending triage])  [modern ✓]
```

Key invariant restored: **`finite-primitives` no longer depends on `algebra`**.
`finite` reaches *down* to conform interval/order/comparison types to `Finite.Enumerable`
(downward, legal); both directions of the `finite ⊗ algebra` integration (the generic
ℤ/Nℤ witnesses **and** the algebra-classification `Finite.Enumerable` conformances) live
in the one `finite-algebra` bridge.

---

## 7. Phased Execution Plan (delegated; finite-first)

**Delegation model** (principal-mandated): each phase is dispatched to a
**subordinate/implementer** (subagent or `/handoff`) under this session's
**orchestrator/supervisor** role per the `supervise` skill. The orchestrator does
not edit source. Each phase ends green (`rm -rf .build && swift build && swift test`
per touched package, per `[MOD-025]`) and acyclic (`[MOD-032]`/`[MOD-033]` pre-flight).
Work proceeds on `main` per `feedback_work_on_main_directly_fine`; new repos default
`--private` per `feedback_never_create_public_repos`; explicit per-file `git add`.

### Phase 1 — `finite-primitives` algebra-dependency removal (FIRST)

*Goal*: `finite`'s `Package.swift` declares neither `swift-algebra-primitives` nor
`swift-algebra-group-primitives`. Dispatchable as one supervised arc (it is large
because the dependent content needs new homes before the dep can drop —
`[ARCH-LAYER-009]` forbids deletion).

1. **Create `swift-interval-primitives`** (L1, namespace `Interval`; deps: `Pair` only
   — the three descriptors import nothing else; `order` dep arrives in Phase 5 with the
   `Interval` value type). Move `Bound`→`Interval.Bound`, `Boundary`→`Interval.Boundary`,
   `Endpoint`→`Interval.Endpoint` (carry their `opposite`/`!`, aliases, `Value<Payload>`,
   `Codable`). `[MOD-031]` shape from creation: singular `Interval Primitive` root +
   per-sub-namespace + umbrella + TS; `[MOD-035]` scope statement.
2. **Drop `Gradient`** (keep `Order.Direction`, which already exists in `order-primitives`
   and serves the concept): delete finite's `Gradient.swift` + `Gradient+Finite.swift`.
   No `order-primitives` change required in Phase 1; migrating `Gradient`'s aliases
   (`rising`/`falling`/`up`/`down`) onto `Order.Direction` is optional **Phase-3 polish**.
3. **Create `swift-finite-algebra-primitives`** bridge (deps: `finite` + `algebra` +
   `algebra-group`) — the one `finite ⊗ algebra` surface:
   (a) generic `extension Algebra.Group where Element: Finite.Enumerable` cyclic (ℤ/Nℤ)
   witness, generalized from finite's `Algebra.Group+{Bound,Boundary,Endpoint,Gradient}.swift`;
   (b) move the algebra-classification `Parity/Sign/Polarity/Monotonicity/Ternary +Finite.swift`
   conformances here (out of finite). Optional per-type `.z2` sugar (would add `interval`/`order`
   deps) — default generic-only.
4. **Retain finite's interval/comparison conformances downward**:
   `Interval.{Bound,Boundary,Endpoint}+Finite` stay in finite (finite → **interval**,
   downward); `Comparison+Finite` stays (finite → **comparison**). None require algebra.
   (`Order.Direction`'s `Finite.Enumerable` conformance, if wanted, lives with `order` or
   the bridge — not a finite concern.)
5. **Rewire `finite/Package.swift`**: drop `swift-algebra-primitives` +
   `swift-algebra-group-primitives`; add `swift-interval-primitives`. Delete finite's four
   `Algebra.Group+*.swift` files (ported to the bridge in step 3). Umbrella stops
   re-exporting `Algebra_*`.
6. **Verify**: grep downstream for consumers of finite's `Algebra_*` re-exports and of the
   four enums BEFORE deleting; per-package clean build+test (`rm -rf .build && swift build
   && swift test`) for finite + the 2 new packages + any downstream; `[MOD-032]`/`[MOD-033]`
   cycle pre-flight (all new edges downward). HALT-and-report on unexpected scope rather
   than working around.

### Phase 2 — `finite-primitives` `[MOD-031]` modernization

Legacy `Finite Primitives Core` → singular **`Finite Primitive`** root (`Finite`
namespace + `Finite.Bound<N>` capacity tag, **zero external deps** per `[MOD-017]`) +
per-sub-namespace targets (`Finite Enumerable Primitives` → Ordinal/Cardinal;
`Finite Bounded Primitives` → Ordinal/Tagged/Index) + clean exports-only umbrella +
`[MOD-035]` scope statement. (The current Core is **not** zero-dep — hence no flat
`Core → Primitive` rename; the root must be carved to namespace + tag only.)

**Conformance placement (principal decision 2026-05-28).** The cross-domain
`Finite.Enumerable` conformances currently in the umbrella (`Comparison+Finite`,
`Interval.{Bound,Boundary,Endpoint}+Finite`) move out of the exports-only umbrella
into a dedicated integration sub-target (e.g. `Finite Primitives Standard Library
Integration`-style, depending on `Finite Enumerable Primitives` + the conformed
package). They **stay in finite** — they are NOT extracted to `comparison-finite` /
`interval-finite` bridges. Rationale: **`comparison-primitives` is a foundational
universal dependency** (same tier of universality as `carrier-primitives` /
`tagged-primitives` — any package may depend on it), so a `finite → comparison` edge
is not a hub-smell; and `finite → interval` is a benign one-way edge on a tiny
(Pair-only) sibling. The `finite-algebra` bridge remains the **one** extraction —
because the goal was specifically to keep finite free of `algebra` (a non-foundational
domain), per the explicit Phase-1 directive. Net finite deps after Phase 2:
Ordinal/Tagged/Index/Iterator/Cardinal + Comparison + Interval + Pair — **no algebra**.

### Phase 3 — `order-primitives` modernization + direction/monotonicity consolidation

`[MOD-031]` (singular `Order Primitive` root + `Order Direction`/`Comparator`/`Orderable`/
`Projection` sub-targets). Finalize `Order.Direction` as the canonical direction (Gradient
absorbed). Move `Monotonicity` (algebra → `Order.Monotonicity`).

### Phase 4 — `algebra-primitives` classification triage

`Sign`/`Polarity`/`Ternary` final homes (numeric/physics/numeral); `Algebra.Iso` vs
`Optic.Iso` ownership; `Order.Orderable` empty-marker resolution (document intrinsic/extrinsic,
or fold onto `Comparison.Protocol`). `Parity` stays.

### Phase 5 — `Interval` value type (evergreen completion) — CAPTURED AS DEFERRED RESEARCH

Model `Interval<Value>` (deps: comparison; order for the traversal bridge) and add the
universally-present **unbounded** axis (Rust `Unbounded` / PG `*_inf` / Haskell `Extended`)
via an `Interval.Extent` endpoint type (`.bounded(Value, Boundary) | .unbounded`), **not**
by widening the binary `Boundary`.

**Status: written down as a per-package `/research-process` RECOMMENDATION rather than
built now** (principal direction 2026-05-28) — Phases 1–4 are a complete green milestone;
the value type is net-new functionality with no current consumer, so per `[ARCH-LAYER-008]`
it is correctness-driven-when-prioritized. The design (Extent type, `Interval<Value>` shape,
generic param named `Value` not `Bound`, `Value: Comparison.Protocol`, v1 op surface,
stdlib-range bridges, IEEE-1788 arithmetic out of scope) lives at
**`swift-interval-primitives/Research/interval-value-type-design.md`** (v1.0.0, tier 2,
RECOMMENDATION).

---

## 8. Residual / Open Questions

**Resolved (principal, 2026-05-28):** ℤ/2ℤ witness placement → one generic
`swift-finite-algebra-primitives` bridge (no per-domain bridges); `Gradient` vs
`Order.Direction` → keep `Order.Direction`, drop `Gradient`; algebra-classification
`+Finite` conformances → preserved in the `finite-algebra` bridge (not dropped).
**Phase-2 conformance placement** → `Comparison+Finite` / `Interval.*+Finite` stay in
finite (relocated to an integration sub-target, out of the exports-only umbrella);
NOT extracted to bridges. Principle: **`comparison-primitives` (with `carrier-`,
`tagged-primitives`) is a foundational universal dependency** — depending on it is
never a hub-smell; `interval` is a benign tiny sibling edge. `finite-algebra` stays
the sole extraction (algebra is the non-foundational domain finite must avoid).

**Phase 4 triage — resolved (principal "proceed", 2026-05-28), via the §4 constitutive-identity framework:**

- **`Sign`** (+/−/0) → **`Numeric.Sign`** in `swift-numeric-primitives` — constitutive: the sign of a number (signum; cf. stdlib `FloatingPointSign`, existing `Decimal.Sign`/`Format.Numeric.Sign`). Inline ×-monoid travels with it. Large cascade (~8–10 consumers) → own supervised sub-arc.
- **`Ternary`** (−1/0/+1) → **`Numeric.Ternary`** — balanced-ternary numeral digit (depends on `Sign`); follows the Sign arc. Distinct from `Logic.Ternary` (nesting disambiguates). Small cascade.
- **`Polarity`** (+/−/neutral) → **PARK in place** (stays in `swift-algebra-primitives` for now), flagged *physics/electrical, awaiting a physics/signal domain*. No math home; ~zero real consumers. NOT deprecated — `[ARCH-LAYER-009]` forbids removal pre-1.0 without explicit auth; parking is reversible.
- **`Algebra.Iso`** → **deprecate; consolidate to `Optic.Iso`** — `Optic.Iso<Whole,Part>` is the same forward/backward iso but fuller (reversed/composing/identity/modify) and canonical ("the strongest optic"); the original split design used `Optic.Iso`. Migrate the z2-transport consumers (`algebra-group`, `algebra-field`, `algebra-primitives`) to `Optic.Iso` (+ optic dep); mark `Algebra.Iso` `@available(deprecated)` (keep source pre-1.0).
- **`Order.Orderable`** → **keep + document** the intrinsic(`Comparison.Protocol`)/extrinsic(orderable-by-supplied-comparator) split. It IS consumed (heap, structured-queries, cyclic, test) — not vestigial; folding onto `Comparison.Protocol` would lose the extrinsic case.
- **`Parity`** → **stays** in algebra (the ℤ/2ℤ group representative; most algebra-bound). Borderline (parity-of-integer is arguably numeric) but not moved.

Net after Phase 4: `swift-algebra-primitives` ≈ the `Algebra` namespace root + `Parity` (+ parked `Polarity`) — the namespace-owner package the structure packages (`Algebra.Group`/`Field`/…) extend.

**Still open:** optional per-type `.z2` sugar accessors over the generic witness (cosmetic); whether to eventually move `Parity` → `Numeric.Parity` (leave algebra a pure namespace root).

No skill amendment is required to express any of this; if the principal wants the
"dedicated-domain vs algebra-classification-family for a lone classification enum"
choice codified, that is a `skill-lifecycle` amendment to **modularization**
(proposed, not applied).

---

## 9. References

- `finite-interval-polarity-decomposition.md` v1.1.0 (SUPERSEDED) — full cross-ecosystem SLR (Rust/Haskell/Boost.ICL/PostgreSQL/IEEE-1788/MSC, primary sources `[Verified: 2026-05-28]`), bit-precedent framing, `Bound`-collision analysis.
- `algebra-primitives-package-split.md` v1.0.0 — origin of the nine-enum classification family.
- `byte-primitive-extraction-and-domain-naming.md` v1.1.1 — mis-parented-value-type extraction precedent.
- `swift-bit-algebra-primitives` (`Bit+Z2.swift`) — recipient-owned ℤ/2ℤ bridge exemplar.
- Skills: modularization `[MOD-DOMAIN/014/017/020/025/029/031/032/033/035/RENT]`; code-surface `[API-NAME-001/001a/001b/004]`; swift-package `[PKG-NAME-001/005/016]`; swift-institute `[ARCH-LAYER-008/009]`; primitives `[PRIM-FOUND-001]`; supervise; research-process `[RES-019/020/022/023/029]`.
