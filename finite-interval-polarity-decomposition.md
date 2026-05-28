# Finite, Interval, and Polarity: Decomposing the Four ℤ/2ℤ Enums

<!--
---
version: 1.1.0
last_updated: 2026-05-28
status: SUPERSEDED
tier: 3
scope: ecosystem-wide
supersededBy: order-cluster-decomposition-and-modernization.md
---
-->

> **SUPERSEDED 2026-05-28** by
> [`order-cluster-decomposition-and-modernization.md`](order-cluster-decomposition-and-modernization.md).
> The investigation widened from "where do the four finite enums go" into a full
> reconciliation + `[MOD-031]` modernization of the order-theoretic cluster
> (`comparison` · `order` · `interval` · `finite` · the `algebra` classification
> overflow). The successor carries forward this doc's cross-ecosystem SLR and
> diagnosis, and **revises two findings**: (1) `Gradient` is a **duplicate of the
> already-existing `Order.Direction`** — it unifies into `order-primitives`, NOT a
> new `Algebra Gradient` target; (2) the interval-endpoint home is confirmed as a
> **new `swift-interval-primitives`** (principal decision 2026-05-28). The SLR,
> the bit-precedent framing, and the `Bound`-collision analysis below remain valid
> and are the detailed source for the successor.

> **Investigation spin-off.** Produced from `HANDOFF-finite-interval-decomposition.md`
> (parent session paused). Derived *through* and conforming *to* the institute's
> architecture + code skills (modularization, code-surface, swift-package,
> swift-institute, primitives, existing-infrastructure, implementation). Every
> placement/naming claim cites a governing rule ID. **Change no source** — this
> doc is the deliverable.

---

## Context

`swift-finite-primitives` currently conflates two unrelated domains:

- **(A) Finite-enumeration infrastructure** — `Finite.Enumerable`, `Finite.Enumeration`,
  `Finite.Capacity`, the `Finite.Bound<N>` phantom tag, `Ordinal.Finite<N>`,
  `Index.Bounded<N>`. This *is* the `Finite` domain: types with a known, countable,
  indexed set of inhabitants, plus compile-time-capacity-bounded ordinals/indices.
  `[Verified: 2026-05-28]` against `Finite.swift`, `Finite.Enumerable.swift`,
  `Ordinal.Finite.swift`.

- **(B) Four top-level ℤ/2ℤ classification enums** — `Bound` (lower/upper),
  `Boundary` (closed/open), `Endpoint` (start/end), `Gradient` (ascending/descending).
  Each is a two-case `Sendable, Hashable, CaseIterable, Codable` enum with a labeled
  involution (`opposite` / prefix `!`), a `Value<Payload> = Pair<Self, Payload>`
  typealias, and (in the `Finite Primitives` umbrella) an `Algebra.Group<Self>.z2`
  witness. They are **top-level types, not `Finite.*`** — a second domain bundled
  into a `Finite`-namespaced package. `[Verified: 2026-05-28]` against `Bound.swift`,
  `Boundary.swift`, `Endpoint.swift`, `Gradient.swift`.

### How (B) came to live in `finite-primitives`

`[Verified: 2026-05-28]` against `algebra-primitives-package-split.md` v1.0.0
(2026-02-04): the four enums were **originally in `swift-algebra-primitives`**,
grouped with `Parity`, `Sign`, `Polarity`, `Monotonicity`, `Ternary` as "9 enum
classification types (Parity, Sign, Bound, etc.)". The split doc moved the
`Finite.Enumerable` conformances out as `@retroactive` and the Z₂-transport
witnesses into an aggregate. In the live corpus the four enums (and their
`Algebra.Group<X>.z2` witnesses + `X+Finite` conformances) now sit in
`swift-finite-primitives`, while `Parity`/`Sign`/`Polarity`/`Monotonicity`/`Ternary`
remained in `swift-algebra-primitives`. The move parked (B) wherever its
`Finite.Enumerable` conformance pointed — conflating *"conforms to
`Finite.Enumerable`"* with *"belongs to the Finite domain."* `Polarity` and
`Comparison` are conformed to `Finite.Enumerable` by `finite-primitives` too, yet
nobody claims they are Finite-domain types; the same is true of (B).

### Trigger and parent pattern

`[RES-001]` architecture choice. The just-finished **bit arc** established the
pattern this investigation tests: *a type's primary identity lives in its domain
package; its ℤ/2ℤ algebra is a **secondary** witness extracted to a recipient-owned
`<domain>-algebra` bridge.* `swift-bit-algebra-primitives` shipped (`Bit.z2:
Algebra.Field<Bit>` in `Bit+Z2.swift`, recipient-side accessor); `swift-bit-primitives`
was modernized. `finite` was the next "extract its algebra" target — but the
diagnosis is that the algebra isn't `finite`'s: it belongs to the mis-parented (B)
enums, which are not Finite-domain types at all.

### Scope and tier

`[RES-020]` **Tier 3**: ecosystem-wide, precedent-setting, normative,
hard-to-undo. Establishes where the order/interval value-classification vocabulary
lives for the next 20 years and the `Finite` domain's identity surface. Optimized
**purely for evergreen / correctness via decomposition + composition** — explicitly
NOT for current consumer demand (`[ARCH-LAYER-008]`: correctness is the sole driver
of split/reshape/extraction pre-1.0; the four enums have effectively zero real
external consumers today, which is irrelevant to the decision).

---

## Question

Optimizing for evergreen/correctness:

1. Where do the four enums and their ℤ/2ℤ witnesses belong — a new domain
   (Interval / Range / Order?), folded into an existing one, or split?
2. `Gradient` — interval traversal-direction, or the algebra polarity family beside
   `Monotonicity`?
3. Nest as `Interval.Bound` per `[API-NAME-001]`?
4. What is `finite-primitives`' correct `[MOD-031]` / `[MOD-035]` shape once (B) leaves?
5. Where do the ℤ/2ℤ witnesses land?

---

## Methodology

Driven by `[RES-029]` (**semantic identity FIRST** for binding/placement questions;
cost/cohesion are tiebreakers only after multiple options remain semantically valid;
operational behavior of adjacent ecosystem types outranks use-site counts).
`[RES-019]` internal-research grep run before the external survey. Cross-ecosystem
SLR per `[RES-023]`; primary sources verified per `[RES-032]`/`[RES-020]` (every
load-bearing external claim tagged `[Verified: 2026-05-28]` against the cited doc).

---

## Internal Prior Art (`[RES-019]`)

| Document | Bearing on this question |
|----------|--------------------------|
| `algebra-primitives-package-split.md` v1.0.0 | The four enums were one family with Parity/Sign/Polarity/Monotonicity/Ternary in `algebra-primitives`; `Finite.Enumerable` conformances are `@retroactive` and separable from the type definitions. |
| `byte-primitive-extraction-and-domain-naming.md` v1.1.1 (SUPERSEDED→`operation-domain-naming…`) | **Direct precedent**: `Byte` was mis-parented as `Parser.Byte`; extracted to `swift-byte-primitives` (value type) + `swift-byte-parser-primitives` (specialization). "`Byte` is not a parser concept; it is a value type the parser happens to consume." |
| `operation-domain-naming-and-organization.md` v1.0.1 (DECISION, tier 3) | Confirms the four enums are **not** operation domains (no verb-capability); they are pure value-type classifications, governed by `[PKG-NAME-001]` (noun) + `[API-NAME-001/001a/001b]`, not the agent/witness/`-able` triple. |
| `range-lazy-semantic-identity.md` v2.1.0 (SUPERSEDED) + `range-sequence-collection-semantic-analysis.md` | `Range.Lazy<Bound>` was renamed `Vector` and moved to `swift-vector-primitives`; `swift-range-primitives` is now only `Swift.Range+*` stdlib extensions. **"Range" is not available as a domain home** for interval descriptors. The "name by what it IS" principle and the tier-3 prior-art rigor are the model for this doc. |
| `domain-first-repository-organization.md` / `domain-first-prior-art.md` (RECOMMENDATION) | Domain names are anchored in **MSC 2020**: `06-XX` "Order, lattices, ordered algebraic structures" → institute "Ordering, Comparison"; `08-XX` "General algebraic systems" → Algebra. Intervals, bounds, endpoints, order-direction are **06-XX order theory**, distinct from **08-XX** algebra. |
| `swift-bit-algebra-primitives` (`Bit+Z2.swift`) | Recipient-owned ℤ/2ℤ bridge exemplar: `Bit.z2` accessor in a separate `<recipient>-algebra` package, per `[MOD-014]` + `[PKG-NAME-016]`. |

`[Verified: 2026-05-28]` — no `swift-interval-*` or `swift-order-*` package exists;
`swift-comparison-primitives` is the live 06-XX member (`Comparison` type, `[MOD-031]`
shape); `swift-range-primitives` hosts only `Swift.Range` extensions; only `Parity`
carries packaged `Algebra.Group`/`Algebra.Field` witnesses (`Algebra.Group+Parity`
in group-primitives, `Algebra.Field+Parity` in field-primitives) — `Sign`/`Polarity`/
`Monotonicity`/`Ternary` carry none.

---

## Cross-Ecosystem Literature Study (SLR, `[RES-021]`/`[RES-023]`)

**Research question.** How do best-in-class systems model: which-end (lower/upper),
inclusivity (open/closed), traversal-terminal (start/end), and order-direction
(ascending/descending) — as a *generic binary-classification* facility, or as
*domain vocabulary* (interval / order / sequence)?

**Search corpus.** Swift stdlib; Rust `std`; C++ `std::ranges` + Boost.Interval +
Boost.ICL; Haskell (`Data.Interval`, `Bounded`, `Ord`); PostgreSQL range types;
IEEE 1788-2015; order/lattice theory; MSC 2020. Inclusion: language/library
constructs that reify any of the four concepts. Exclusion: secondary tutorials.

### Findings

| System | Inclusivity (open/closed) | Which-end / unbounded | Direction / order-result | Source `[Verified: 2026-05-28]` |
|--------|---------------------------|-----------------------|--------------------------|--------------------------------|
| **Swift stdlib** | Distinct **types** (`Range` half-open, `ClosedRange` closed), not an enum | `RangeExpression.Bound` = the **endpoint value type** (`Comparable`); `PartialRange*` for unbounded | `Comparable`; `ComparisonResult` (3-valued) | developer.apple.com — `RangeExpression.Bound` is the value associatedtype |
| **Rust** | `std::ops::Bound` = `Included(T)` / `Excluded(T)` / `Unbounded` | which-end is **positional** (`RangeBounds::start_bound()`/`end_bound() -> Bound<&T>`); `Unbounded` is the third case | `cmp::Ordering` = `Less`/`Equal`/`Greater` (3-valued) | doc.rust-lang.org `enum.Bound`, `trait.RangeBounds` |
| **C++ / Boost.ICL** | `interval_bounds` = `{open, closed, left_open, right_open}` (4-valued); static types `closed_interval`/`open_interval`/`left_open_interval`/`right_open_interval` | runtime `bounds()` on `discrete_interval`/`continuous_interval` | `std::strong_ordering` (`<=>`) | boost.org ICL interval construction |
| **Haskell `data-interval`** | `data Boundary = Open \| Closed` | endpoints are `Extended r = NegInf \| Finite r \| PosInf`; interval = `(Extended r, Boundary)` per end | `Ordering = LT \| EQ \| GT` | hackage `Data.Interval` |
| **PostgreSQL** | `[`/`(` lower, `]`/`)` upper; `lower_inc`/`upper_inc` | which-end positional in `[a,b)`; `lower_inf`/`upper_inf` for unbounded | sort `ASC`/`DESC` | postgresql.org rangetypes |
| **IEEE 1788-2015** | Intervals are closed connected subsets of ℝ; bound inclusivity is intrinsic to the set model | lower/upper endpoints (inf/sup) | n/a | IEEE 1788-2015 §interval definition |
| **Order/lattice theory** | open/closed = topological boundary of an interval | lower/upper bound; infimum/supremum | monotone direction; order-preserving/reversing | standard; MSC `06-XX` |

### Synthesis

1. **Inclusivity (`Boundary` = open/closed) is first-class *interval* vocabulary,
   cross-ecosystem.** Haskell names it identically — `data Boundary = Open | Closed`
   — and places it in the **interval** library. Boost.ICL reifies it as
   `interval_bounds`. PostgreSQL exposes `lower_inc`/`upper_inc`. This is not a
   fringe concept; it is the canonical descriptor of an interval endpoint.

2. **`Bound` × `Boundary` *compose* into a full endpoint specification.** Boost.ICL's
   4-valued `interval_bounds` (`{closed, open, left_open, right_open}`) is exactly the
   product *which-end × inclusivity*; PostgreSQL's `[a,b)` literal carries both per
   end; Haskell pairs `(Extended r, Boundary)` per end. The institute's own
   `Boundary.swift` doc says: *"Combine with `Bound` for complete endpoint
   specification."* Compositionality across two orthogonal axes is a **domain
   signature** — these are not independent classifications, they are the two axes of
   one structure.

3. **The word "Bound" is dangerously overloaded.** Swift `RangeExpression.Bound` =
   the endpoint *value type* (Int). Rust `std::ops::Bound` = *inclusivity +
   unboundedness* (≈ the institute's `Boundary`, **not** its `Bound`). The institute's
   `Bound` = which-end (lower/upper). Three incompatible meanings of one token —
   confirmed inside the institute corpus itself, where `[Verified: 2026-05-28]` the
   bare grep for `Bound`/`Boundary` matched `Finite.Bound<N>` (capacity tag),
   `Range.Lazy<Bound>`-era generic params, Tagged generic bounds, and
   `Ordinal.Distance` — almost none of them the (B) enum. **Namespacing the (B)
   `Bound` is mandatory** to disambiguate.

4. **A third axis — unboundedness — is universally present and the institute's
   2-valued `Boundary` lacks it.** Rust `Unbounded`, PostgreSQL `lower_inf`/`upper_inf`,
   Haskell `Extended`'s `±Inf` all model "no bound this direction." This is a real
   future gap for a proper interval domain (`[RES-021]` contextualization step:
   adding it is cheap once `Interval` exists; it would be a third case or a sibling
   `Interval.Extent` type — *not* a reason to widen `Boundary`, which is genuinely
   binary).

5. **Order-direction (`Gradient` = asc/desc) is *not* interval-specific.** It is the
   sign of a monotone change / a sort direction (PostgreSQL `ASC`/`DESC`), the
   2-valued reduction of `Monotonicity` (drop `.constant`) and of `Comparison` (drop
   `.equal`). It lives in **06-XX order**, beside `Monotonicity`/`Comparison`, not
   in interval-endpoint vocabulary.

6. **No surveyed ecosystem has a "binary-classification" domain.** Two-element
   types are primitive (`Bool`); specific two-valued concepts live in their *semantic*
   domains (interval, order, sequence); the ℤ/2ℤ group structure is *applied to*
   them by an algebra abstraction. This is decisive for `[RES-029]`: the unifying
   trait of the four enums ("two-element type with a labeled involution") is a
   **structure that cuts across domains, not a domain** — exactly the bit precedent
   (Bit's identity is the bit domain; its 𝔽₂ structure is a secondary witness).

---

## Theoretical Grounding (`[RES-022]`/`[RES-024]`)

**The four enums are one ℤ/2ℤ *species* but three order-theoretic *concepts*.**

Each enum `E` with cases `{a, b}` and involution `ι: E → E` (`ι(a)=b`, `ι(b)=a`,
`ι∘ι = id`) is isomorphic, as a group under the unique non-trivial involution, to
ℤ/2ℤ — equivalently to `Parity` under XOR. The witness `E.z2` is exactly the
transport of structure along the bijection `φ: E → Parity`:

```
φ(a) = .even,  φ(b) = .odd        combine_E(x,y) = φ⁻¹(φ(x) ⊕ φ(y))     identity = a
```

This is *structure*, and it is shared by all four (and by `Bit`, and by `Parity`).
It is **secondary** — it says only "this two-element set is ℤ/2ℤ." It does not
determine *where the type lives*.

The *primary* identity is the order-theoretic concept each names, and they decompose
into three distinct positions in **MSC 06-XX** (order, lattices):

| Enum | Concept | Order-theoretic role | Composes? |
|------|---------|----------------------|-----------|
| `Boundary` (closed/open) | endpoint **inclusivity** | whether `inf`/`sup` ∈ the set (topological boundary) | with `Bound` → endpoint |
| `Bound` (lower/upper) | endpoint **by value** | which of `inf`/`sup` | with `Boundary` → endpoint |
| `Endpoint` (start/end) | endpoint **by traversal** | terminal of a directed walk | with `Gradient` → `Bound` |
| `Gradient` (asc/desc) | **direction** of change | sign of a monotone map; sort order | relates `Endpoint`↔`Bound` |

**Two clean compositions emerge**, both confirming the order/interval clustering:

- **endpoint = `Bound` × `Boundary`** (the interval-endpoint product; Boost.ICL's
  `interval_bounds`).
- **`Bound` = `Endpoint` × `Gradient`** — under an *ascending* gradient,
  `start ↦ lower`, `end ↦ upper`; under *descending*, the map flips. `Bound` (order)
  and `Endpoint` (traversal) coincide only once a `Gradient` is chosen. This is why
  `Bound` and `Endpoint` are **not** redundant despite both being "which of two
  ends": one is ordered by value, the other by traversal, and `Gradient` is the
  functor between them.

`Boundary`, `Bound`, `Endpoint` are the **endpoint descriptors** (they describe the
ends of a 1-D extent); `Gradient` is the **orientation** (it describes the direction
along it). The endpoint descriptors form an interval domain; the orientation belongs
with the order-behavior classifications.

---

## Analysis

The placement test (synthesizing `[MOD-DOMAIN]`, `[MOD-RENT]`, `[RES-029]`, the
bit/byte precedents): **does the enum anchor a coherent semantic domain with
theoretical content and a compositional partner, or is it a lone classification best
grouped with its structural/semantic siblings?**

### Option A — Revert: all four → `algebra-primitives` classification family

Put `Bound`/`Boundary`/`Endpoint`/`Gradient` back beside `Parity`/`Sign`/`Polarity`/
`Monotonicity`/`Ternary` as per-type targets (`Algebra Bound Primitives`, …),
top-level enums.

- **Pros**: structurally identical to the existing family; zero new packages; their
  Z₂ witnesses co-locate (group-primitives, like `Algebra.Group+Parity`); reverses a
  known mis-parent with the least motion; honors `[MOD-020]` (zero dep-delta →
  target-split in an existing package).
- **Cons**: perpetuates a **category error**. `algebra-primitives` is MSC **08-XX**
  (general algebraic systems); `Bound`/`Boundary` are **06-XX** (order/interval). The
  family already *is* a structure-grouped collection (its members span number-theory /
  physics / order / logic) — adding interval vocabulary deepens the conflation rather
  than fixing it. Leaves the `Bound` naming collision **unresolved** (stays
  top-level, colliding with Swift/Rust `Bound`). Fails `[RES-029]`: it ranks
  *structural symmetry* over *semantic identity*.

### Option B — New `Interval` domain for the endpoint descriptors; `Gradient` to the classification family

`Bound`+`Boundary`+`Endpoint` → new `swift-interval-primitives` (namespace
`Interval`); `Gradient` → `algebra-primitives` beside `Monotonicity`.

- **Pros**: honors `[RES-029]` (semantic identity drives). `Interval` is a real,
  cross-ecosystem-validated, MSC-06-XX domain (IEEE 1788, Boost.Interval/ICL, Haskell
  `Data.Interval`, PostgreSQL ranges); the three endpoint descriptors are its
  coherent vocabulary and they *compose* (`Bound` × `Boundary`; `Endpoint` × `Gradient`
  → `Bound`). Namespacing under `Interval` **resolves** the `Bound` collision
  (`Interval.Bound` vs `Swift.RangeExpression.Bound` vs `Rust std::ops::Bound`).
  Leaves room for the universally-present **unbounded** axis. `Gradient` lands beside
  its true sibling `Monotonicity` (the 3-valued order-direction classification).
- **Cons**: one new package; `Gradient`-in-`algebra` retains the family's 08-XX/06-XX
  imperfection (but that is a *pre-existing* property of the family, not introduced
  here — `Monotonicity` already sits there). `[MOD-020]` zero-dep-delta would prefer
  a target-split — but there is **no existing same-domain package** to split into
  (no interval/order-descriptor package exists), so `[MOD-DOMAIN]`/`[MOD-029]`
  (domain-distinctness drives splits) governs and a new package is correct.

### Option C — New `Order` super-domain for all four

A single `swift-order-primitives` (06-XX) hosting all four (and, eventually,
`Comparison`, `Monotonicity`).

- **Pros**: maximally semantic (all four are 06-XX). One package.
- **Cons**: over-reaches the handoff's scope and bundles two *distinct* sub-concepts
  (endpoint-descriptors vs orientation/comparison) into one namespace, losing the
  compositional `Interval` story; would require moving `Comparison` (out of its
  established `swift-comparison-primitives`) and `Monotonicity` (out of algebra) to be
  coherent — a much larger arc. The interval sub-domain is concrete and ready now;
  the broader Order consolidation is a separate, ecosystem-level question (see
  *Residual*).

### Comparison

| Criterion (`[RES-029]` tiering) | A: Revert→Algebra | B: Interval + Gradient→Algebra | C: Order super-domain |
|---|:---:|:---:|:---:|
| **Tier 1 — semantic identity** | ✗ structure over domain | **✓ domain-first** | ✓ domain-first |
| **Tier 2 — adjacent operational consensus** | ✗ (cross-ecosystem puts these in interval/order) | **✓** (Haskell `Boundary`, Boost.ICL, IEEE 1788) | ✓ |
| Resolves `Bound` naming collision | ✗ | **✓ `Interval.Bound`** | ✓ `Order.Bound` |
| Compositional vocabulary preserved | ✗ | **✓** | partial (mixes endpoint + orientation) |
| Respects existing `Monotonicity`/`Comparison` placement | ✓ | **✓** | ✗ requires moving both |
| New packages | 0 | 1 (+1 bridge) | 1 (+ migrations) |
| Scope fit (handoff) | reverts only | **exact** | over-reaches |

**`[RES-022]` framing**: structural correctness dominates; diff-size/package-count
are tiebreakers only among structurally-equivalent options. A and B/C are
*structurally distinct* (A reifies an incidental ℤ/2ℤ grouping as the home; B/C
recognize the order/interval domain). **Option B** is the structurally-correct
minimum that fits scope.

---

## Recommendation

**Status: RECOMMENDATION. Option B.** The four enums are **order-theoretic value
vocabulary (MSC 06-XX), not finite-enumeration vocabulary**; they must leave
`swift-finite-primitives`. Decompose by semantic identity:

### (1) Interval-endpoint vocabulary → new `swift-interval-primitives`

A new L1 package, namespace **`Interval`** (noun, `[PKG-NAME-001]`), hosting the
three endpoint descriptors as nested types per `[API-NAME-001]` (Nest.Name) /
`[API-NAME-001b]` (the larger domain `Interval` owns; the descriptors nest) /
`[API-NAME-001a]` (three sibling types ⇒ a genuine namespace, not a variant label):

```
Interval.Bound      // lower / upper            (which-end, by value)
Interval.Boundary   // closed / open            (inclusivity)
Interval.Endpoint   // start / end              (terminal, by traversal)
```

- **Noun choice — `Interval`, not `Range` or `Order`** (`[PKG-NAME-005]` shortest
  natural noun, cross-ecosystem precedent): `Range` is taken by Swift's `Range` and
  the institute's `swift-range-primitives` (now `Swift.Range+*` extensions);
  `Interval` is the precise term in IEEE 1788, Boost.Interval, Haskell `Data.Interval`;
  `Order` is the broader 06-XX super-domain, reserved for the residual question.
- **`[MOD-DOMAIN]`/`[MOD-RENT]`**: a coherent semantic domain (capability:
  interval-endpoint specification; theoretical content: interval/order theory, the
  `Bound`×`Boundary` product, IEEE 1788; consumer: pre-1.0 correctness-driven per
  `[ARCH-LAYER-008]`, with future range/interval-arithmetic types). `[MOD-020]` is
  satisfied — no existing same-domain package exists to absorb these, so a new
  package, not a target-split, is correct.
- **Dependency**: `Pair_Primitives` only (for `Interval.Bound.Value<Payload>` etc.).
  `[PRIM-FOUND-001]` Foundation-free. `[MOD-031]` shape: singular `Interval Primitive`
  root (zero-dep namespace) + per-sub-namespace targets + umbrella.
- **Future evergreen hook**: the universally-present **unbounded** axis (Rust
  `Unbounded`, PG `*_inf`, Haskell `Extended`) lands here later — as a third case on
  a future `Interval.Extent` or as the eventual `Interval` type's endpoint model —
  *not* by widening the genuinely-binary `Boundary`.

### (2) Order-direction → `algebra-primitives` classification family

**`Gradient`** (ascending/descending) → `swift-algebra-primitives` as a new per-type
target `Algebra Gradient Primitives` (top-level `Gradient`, mirroring
`Algebra Monotonicity Primitives`). `Gradient` is the 2-valued reduction of
`Monotonicity` (its true sibling) and a sort/order direction — **not** an
interval-endpoint descriptor. This follows the established precedent: the
classification family (`Parity`/`Sign`/`Polarity`/`Monotonicity`/`Ternary`) groups
lone small classifications by their algebraic character; `Gradient` is exactly such a
type and originated there (`algebra-primitives-package-split.md`).

### (3) ℤ/2ℤ witnesses → recipient-owned bridges (bit precedent)

Per `[MOD-014]` (extract by default) + `[PKG-NAME-016]` (integration =
recipient-then-provider) + the `swift-bit-algebra-primitives` exemplar:

- **`Interval.Bound`/`Boundary`/`Endpoint` Z₂** → new bridge
  **`swift-interval-algebra-primitives`** (recipient `Interval` gains `Algebra` group
  structure). **Recipient-side accessors** `Interval.Bound.z2` / `Interval.Boundary.z2`
  / `Interval.Endpoint.z2` (mirroring `Bit.z2`), **not** the current structure-side
  `Algebra.Group<Bound>.z2`. This keeps `swift-interval-primitives` free of any
  algebra dependency (interval stays low-tier, clean), exactly as `swift-bit-primitives`
  stays free of `algebra-field`.
- **`Gradient` Z₂** → `swift-algebra-group-primitives` as `Algebra.Group+Gradient`,
  beside the existing `Algebra.Group+Parity`. `Gradient` is an algebra-ecosystem
  citizen (like `Parity`), so its witness co-locates in the structure package; no
  bridge needed.

### (4) `swift-finite-primitives` after (B) leaves — `[MOD-035]` scope + `[MOD-031]` shape

**`[MOD-035]` scope statement** (to be added at publication-readiness): *`swift-finite-primitives`
provides the substrate for **finite enumerable types** (a known, countable, indexed
set of inhabitants) and **compile-time-capacity-bounded** ordinals/indices.* Core
targets: `Finite` (namespace + `Finite.Bound<N>` capacity tag), `Finite.Enumerable`,
`Finite.Enumeration`, `Finite.Capacity`, `Ordinal.Finite<N>`, `Index.Bounded<N>`.
**Out of scope**: interval-endpoint descriptors (→ `swift-interval-primitives`),
order-direction (→ `swift-algebra-primitives`/`Gradient`), and the ℤ/2ℤ transport
witnesses (→ the bridge / group-primitives).

- After (B) leaves, the internal `Finite.Bound<N>` capacity tag is the **only**
  "Bound" in the package — the intra-package name collision dissolves.
- **`Finite.Enumerable` conformances stay in `finite-primitives`.** `finite` already
  reaches *down* to conform foreign types (`Polarity`, `Comparison`) to
  `Finite.Enumerable`; it does the same for the relocated `Interval.Bound`/`Boundary`/
  `Endpoint` and `Gradient` — `finite` depends on `interval-primitives` +
  `algebra-primitives` and provides `extension Interval.Bound: Finite.Enumerable`,
  etc. (the `X+Finite.swift` files stay, retargeted). Direction is downward
  (`finite` → `interval`/`algebra`), so `interval`/`algebra` stay low-tier and
  algebra/finite-free. The Z₂ witness files (`Algebra.Group+Bound`, …) **leave**
  `finite` entirely.
- **`[MOD-031]` migration** (at publication-readiness, `[MOD-001]` legacy → singular
  root): `Finite Primitive` root target = `{Finite` namespace, `Finite.Bound<N>}`
  (zero external deps per `[MOD-017]`); per-sub-namespace targets carry their own deps
  (`Finite Enumerable Primitives` → Ordinal/Cardinal; `Finite Bounded Primitives` →
  Ordinal/Tagged/Index). Note the current `Finite Primitives Core` is **not**
  zero-dep, which is *why* a flat `Core → Primitive` rename fails — the `[MOD-017]`
  zero-dep root must be carved to the namespace + tag only.

---

## Answers to the Five Questions

1. **New domain vs existing; the noun.** New domain **`Interval`**
   (`swift-interval-primitives`) for the endpoint descriptors (`Bound`, `Boundary`,
   `Endpoint`); `Gradient` folds into the existing `algebra-primitives` classification
   family. Noun = **`Interval`** (not `Range` — taken; not `Order` — the reserved
   super-domain).
2. **`Gradient`.** **Algebra polarity/classification family, beside `Monotonicity`** —
   it is order-direction (the 2-valued `Monotonicity`/sort direction), not an
   interval-endpoint descriptor. (It relates `Endpoint`↔`Bound` as the orientation
   functor, but its *identity* is direction-of-change.)
3. **`Interval.Bound`?** **Yes** — `Interval.Bound`, `Interval.Boundary`,
   `Interval.Endpoint` per `[API-NAME-001]`/`[API-NAME-001a]`/`[API-NAME-001b]`. The
   namespace is mandatory: it resolves the three-way `Bound` collision (institute
   which-end vs Swift endpoint-value vs Rust inclusivity).
4. **`finite` shape.** Scope reduced to the (A) Finite-enumeration domain with a
   `[MOD-035]` scope statement; `[MOD-031]` singular `Finite Primitive` root (namespace
   + `Finite.Bound<N>` tag, zero-dep) + per-sub-namespace targets. `Finite.Enumerable`
   conformances for the relocated types **stay** (finite reaches down, as it already
   does for `Polarity`/`Comparison`); the Z₂ witnesses **leave**.
5. **ℤ/2ℤ witnesses.** Recipient-owned bridge `swift-interval-algebra-primitives`
   (`Interval.Bound.z2` etc., recipient-side, like `Bit.z2`) for the interval enums;
   `Algebra.Group+Gradient` in `swift-algebra-group-primitives` (beside
   `Algebra.Group+Parity`) for `Gradient`.

---

## Residual / Open Questions

| Item | Type | Disposition |
|------|------|-------------|
| Should `Monotonicity`, `Gradient`, and `Comparison` (all MSC 06-XX order-direction/relation classifications) consolidate into an `Order` domain rather than being split between `algebra-primitives` and `comparison-primitives`? | **Premise → direction** (ecosystem-level) | **Surface, do not dispatch** (per `feedback_class_c_ecosystem_stop_not_dispatch`). This is a multi-package architectural-composition question beyond the four-enum scope; the current recommendation places `Gradient` where its live sibling `Monotonicity` already is, and is correct under the present topology. Flag for principal. |
| The universally-present **unbounded** endpoint axis (Rust `Unbounded`, PG `*_inf`, Haskell `Extended`) absent from the binary `Boundary`. | **Premise** | Lands in `swift-interval-primitives` when the `Interval` value type itself is modeled; **not** by widening `Boundary`. Cheap once `Interval` exists. |
| Is `Interval.Endpoint` (start/end) the right home vs a future sequence/linear-structure vocabulary (its `head`/`tail`/`first`/`last` aliases lean sequence-ward)? | **Direction** | `Endpoint` is an interval/order endpoint (terminal of a directed 1-D extent); the sequence aliases are conveniences. Interval is the correct home now. Revisit only if a heavy sequence-position vocabulary domain emerges. |
| `[MOD-020]` zero-dep-delta vs `[MOD-DOMAIN]` for the new `Interval` package. | Resolved | No existing same-domain package exists to split into; `[MOD-DOMAIN]`/`[MOD-029]` govern. Recorded for the executing session. |

No skill amendment is required: the recommendation is fully expressible under
existing rules (`[MOD-DOMAIN]`, `[MOD-014]`, `[MOD-031]`, `[MOD-035]`, `[API-NAME-001/001a/001b]`,
`[PKG-NAME-001/005/016]`, `[ARCH-LAYER-008]`). The one convention this exercise
*relies on but does not find written* — *how to choose between a dedicated domain
package and the algebra classification family for a lone small classification enum* —
is adequately covered by `[MOD-RENT]` (rent test) + `[MOD-DOMAIN]` (coherence) +
`[RES-029]` (semantic-identity-first); if the principal wants it codified as an
explicit decision rule, that is a `skill-lifecycle` amendment to **modularization**,
proposed rather than applied here.

---

## Implementation Note (for the executing session — not part of this RECOMMENDATION)

Migration is a rename + relocation, not a deletion (`[ARCH-LAYER-009]`): create
`swift-interval-primitives` (`Interval.Bound`/`Boundary`/`Endpoint`) and
`swift-interval-algebra-primitives` (recipient-side `z2` accessors); add
`Algebra Gradient Primitives` to `swift-algebra-primitives` and `Algebra.Group+Gradient`
to `swift-algebra-group-primitives`; retarget `finite`'s `X+Finite.swift` conformances
to the relocated types and delete `finite`'s `Algebra.Group+{Bound,Boundary,Endpoint,Gradient}.swift`;
verify per-package `rm -rf .build && swift build && swift test`. Pre-flight the
package graph for cycles (`[MOD-032]`/`[MOD-033]`) — `finite → interval`/`algebra` is
downward and acyclic.

---

## References

`[RES-026]` traceable sources.

### Primary (external) — `[Verified: 2026-05-28]`

- Rust: [`std::ops::Bound`](https://doc.rust-lang.org/std/ops/enum.Bound.html) (`Included`/`Excluded`/`Unbounded`); [`std::ops::RangeBounds`](https://doc.rust-lang.org/std/ops/trait.RangeBounds.html) (`start_bound`/`end_bound`).
- Haskell: [`Data.Interval`](https://hackage.haskell.org/package/data-interval/docs/Data-Interval.html) (`data Boundary = Open | Closed`; `Extended r = NegInf | Finite r | PosInf`).
- C++ / Boost: [Boost.ICL interval construction](https://www.boost.org/doc/libs/release/libs/icl/doc/html/boost_icl/function_reference/interval_construction.html) (`interval_bounds`: open/closed/left_open/right_open; static vs dynamic interval types).
- PostgreSQL: [Range Types](https://www.postgresql.org/docs/current/rangetypes.html) (`[`/`(`/`]`/`)` notation; `lower_inc`/`upper_inc`/`lower_inf`/`upper_inf`).
- Swift: `RangeExpression.Bound` (endpoint value associatedtype; open/closed via distinct `Range`/`ClosedRange` types).
- IEEE 1788-2015, *Standard for Interval Arithmetic*.
- Mathematics Subject Classification (MSC 2020): [`06-XX` Order, lattices, ordered algebraic structures](https://msc2020.org/); `08-XX` General algebraic systems.

### Internal

- `algebra-primitives-package-split.md` v1.0.0 — the nine-enum classification family; `@retroactive` `Finite.Enumerable` separability.
- `byte-primitive-extraction-and-domain-naming.md` v1.1.1 — mis-parented-value-type extraction precedent (`Byte` from `Parser.Byte`).
- `operation-domain-naming-and-organization.md` v1.0.1 — confirms the four are non-operation value classifications.
- `range-lazy-semantic-identity.md` v2.1.0 / `range-sequence-collection-semantic-analysis.md` — `Range` vacated to `Vector`; "name by what it IS"; tier-3 prior-art model.
- `domain-first-repository-organization.md` / `domain-first-prior-art.md` — MSC anchoring of domain names.
- `swift-bit-algebra-primitives` (`Bit+Z2.swift`) — recipient-owned ℤ/2ℤ bridge exemplar.

### Skills

- modularization `[MOD-DOMAIN]`, `[MOD-014]`, `[MOD-020]`, `[MOD-029]`, `[MOD-031]`, `[MOD-032]`, `[MOD-033]`, `[MOD-035]`, `[MOD-RENT]`, `[MOD-017]`.
- code-surface `[API-NAME-001]`, `[API-NAME-001a]`, `[API-NAME-001b]`.
- swift-package `[PKG-NAME-001]`, `[PKG-NAME-005]`, `[PKG-NAME-016]`.
- swift-institute `[ARCH-LAYER-008]`, `[ARCH-LAYER-009]`. primitives `[PRIM-FOUND-001]`, `[PRIM-ARCH-002]`.
- research-process `[RES-019]`, `[RES-020]`–`[RES-024]`, `[RES-026]`, `[RES-029]`, `[RES-032]`.
