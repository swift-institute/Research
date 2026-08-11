# Interval Value Type Design

<!--
---
version: 1.0.0
last_updated: 2026-05-28
status: RECOMMENDATION
tier: 2
scope: package-specific
---
-->

> **Deferred design (cluster Phase 5).** `swift-interval-primitives` today ships only
> the three interval-endpoint *descriptor* enums — `Interval.Bound` (lower/upper),
> `Interval.Boundary` (closed/open), `Interval.Endpoint` (start/end) — extracted from
> `swift-finite-primitives` during the order-cluster reconciliation. This document
> captures the design of the **`Interval` value type itself** and the **unbounded
> endpoint axis**, the remaining (Phase 5) item of that program. It is analysis +
> recommendation; **no implementation is authorized by it** — it exists so the value
> type is designed before it is built.
>
> **Prior art is not re-derived here.** The cross-ecosystem systematic survey
> (Swift / Rust / C++ Boost.ICL / Haskell `data-interval` / PostgreSQL / IEEE 1788 /
> MSC, with verified primary sources) lives in
> `swift-institute/Research/finite-interval-polarity-decomposition.md` (SUPERSEDED, but
> the SLR stands) and `swift-institute/Research/order-cluster-decomposition-and-modernization.md`.
> This doc cites it and focuses on the value-type shape.

## Context

The cluster reconciliation established `Interval` as the MSC-06-XX interval sub-domain
and gave it the three endpoint *descriptors*. Those descriptors only become useful
when a value type composes them into an actual interval. Two facts from the SLR frame
the design:

1. **An interval endpoint is the product `Bound × Boundary`** — which-end × inclusivity
   (Boost.ICL's 4-valued `interval_bounds = {closed, open, left_open, right_open}`;
   PostgreSQL's `[a,b)`; Haskell's `(Extended r, Boundary)` per end). The institute's
   `Interval.Bound` + `Interval.Boundary` are exactly these two axes.
2. **Every surveyed system has an *unbounded* third state** that the institute's binary
   `Boundary` lacks — Rust `std::ops::Bound::Unbounded`, PostgreSQL `lower_inf`/`upper_inf`,
   Haskell `Extended`'s `NegInf`/`PosInf`. The finite-decomposition doc's standing
   guidance: model it **without widening the binary `Boundary`**.

## Question

1. What is the shape of the `Interval` value type?
2. How is the **unbounded** axis modeled (without polluting binary `Boundary`)?
3. How do `Bound`/`Boundary`/`Endpoint` compose into it; what is an "endpoint" value?
4. What are the element constraints (`Comparable`/`~Copyable`) and package dependencies?

## Prior Art (condensed; full SLR cited above)

| System | Interval value type | Unbounded | Inclusivity |
|--------|---------------------|-----------|-------------|
| **Swift stdlib** | distinct *types* `Range`/`ClosedRange`/`PartialRangeFrom/UpTo/Through` | via the partial-range *types* | encoded in the type, not a field |
| **Rust** | `RangeBounds` trait; `(Bound<T>, Bound<T>)` | `Bound::Unbounded` | `Bound::Included/Excluded` |
| **Haskell `data-interval`** | `Interval r` = `(Extended r, Boundary)` × 2 | `Extended = NegInf \| Finite r \| PosInf` | `data Boundary = Open \| Closed` |
| **Boost.ICL** | `discrete_interval`/`continuous_interval` + 4 static types | unbounded not a first-class endpoint (separate) | `interval_bounds` (4-valued = Bound×Boundary) |
| **PostgreSQL** | range types | `lower_inf`/`upper_inf` | `lower_inc`/`upper_inc` |
| **IEEE 1788-2015** | closed connected subset of ℝ; `[lo, hi]` with ±∞ allowed | ±∞ endpoints | bounds intrinsic to the set |

**Two model families**: (A) Swift's *type-per-shape* (open/closed/partial are distinct
types — no runtime inclusivity field); (B) the *value-carrying* model (Rust/Haskell/PG/ICL:
one interval type whose endpoints carry inclusivity + boundedness as data). The institute
already chose family (B) by reifying `Bound`/`Boundary` as value enums.

## Analysis

### A. The endpoint type — `Interval.Extent<Value>` (the unbounded axis)

The clean way to add the unbounded state without touching the binary `Boundary` is a
dedicated endpoint type that is *either* a bounded endpoint (a value + its inclusivity)
*or* unbounded — directly mirroring Rust's `Bound<T>` and Haskell's `Extended` × `Boundary`:

```swift
extension Interval {
    /// One end of an interval: a value with its inclusivity, or unbounded (±∞).
    public enum Extent<Value> {
        case bounded(Value, Interval.Boundary)   // closed/open at `Value`
        case unbounded                            // no bound this direction (±∞)
    }
}
```

- `Interval.Boundary` stays strictly binary (closed/open) — the unbounded state is the
  *absence* of a bound, modeled by the enum case, not a third `Boundary`. (Satisfies the
  finite-doc constraint.)
- `Extent` is the institute analog of Rust `Bound<T>`; the `Interval.Bound` enum
  (lower/upper) labels *which* extent, exactly as Rust's positional `start_bound`/`end_bound`.

**Rejected alternative**: a third `Boundary.unbounded` case — pollutes a type whose
binary open/closed identity is used independently (e.g. as a `Finite.Enumerable` 2-element
classification); the SLR + finite-doc both reject it.

### B. The interval value type — `Interval<Value>`

```swift
public struct Interval<Value> {
    public let lower: Interval.Extent<Value>   // the Bound.lower extent
    public let upper: Interval.Extent<Value>   // the Bound.upper extent
}
```

- **Generic parameter is `Value`, NOT `Bound`.** Swift's `Range<Bound>` names its element
  `Bound`; the institute's `Interval.Bound` is the lower/upper *enum*. Naming the generic
  `Bound` would collide and re-create the three-way `Bound` overload the cluster work
  exists to kill. Use `Value` (or `Element`).
- Subscript by `Interval.Bound`: `interval[.lower] -> Extent<Value>`, `interval[.upper]`,
  making `Bound` the index into the two extents (its constitutive role).
- `Interval.Endpoint` (start/end) governs *traversal* direction over the interval (for an
  eventual iteration/Vector bridge); it relates to `Bound` via `Order.Direction`
  (`Endpoint × Direction → Bound`, per the finite-doc composition note). Not stored;
  used by traversal APIs.

### C. Element constraint and dependencies

- **`Value: Comparison.Protocol`** (institute `Comparable`, from `swift-comparison-primitives`
  — a *foundational universal dependency* per the cluster decision) for `contains`,
  `overlaps`, `isEmpty`, ordering of bounds. This adds a `comparison` dep to
  `swift-interval-primitives` (today Pair-only) — acceptable (comparison is foundational).
- **Copyability**: start `Value: Comparison.Protocol` (Copyable). A `~Copyable` variant is
  a later option if a consumer needs intervals of move-only values; not a v1 requirement.
- **Order**: `Order.Direction` is needed only for the traversal/`Endpoint` bridge, which can
  be a later additive step — v1 of the value type need not depend on `order`.

### D. Operations (v1 surface, IEEE-1788-informed)

`contains(_ value:)`, `isEmpty`, `overlaps(_:)`, `intersection(_:)`, `union(_:)` (or
`hull`), `clamped(_:)`; plus stdlib bridges `init?(_ range: Range<Value>)` /
`ClosedRange` / `PartialRange*` (the partial ranges map to one `unbounded` extent) and a
`contains` consistent with Swift's. Defer the full IEEE-1788 arithmetic (interval
addition/multiplication) — that is a numeric/interval-arithmetic concern, a separate
package or later phase, not the base value type.

## Outcome

**Status: RECOMMENDATION (implementation deferred).**

Recommended shape:
1. `Interval.Extent<Value>` = `.bounded(Value, Boundary) | .unbounded` — the endpoint type
   that adds the unbounded axis without widening binary `Boundary` (institute analog of
   Rust `Bound<T>` / Haskell `Extended`×`Boundary`).
2. `Interval<Value>` = `(lower: Extent, upper: Extent)`; generic param named **`Value`**
   (never `Bound`); `subscript(_: Interval.Bound) -> Extent<Value>` makes `Bound` the
   extent index.
3. `Value: Comparison.Protocol`; add `comparison` dep (foundational). Copyable v1;
   `~Copyable` later if needed. `order` dep only when the `Endpoint`/traversal bridge lands.
4. v1 ops: containment / emptiness / overlap / intersection / union / clamp + stdlib
   `Range`-family bridges. IEEE-1788 interval *arithmetic* is out of scope (later/separate).

**Why deferred, not built now:** the cluster reconciliation (Phases 1–4) is a complete,
green milestone; the `Interval` value type is net-new functionality with no current
consumer demand, so per `[ARCH-LAYER-008]` it is correctness-driven-when-prioritized, not
urgent. Building it should follow the institute's normal package-build flow with the
[MOD-031] shape already in place (`Interval Extent Primitives` + `Interval Type`/value
sub-target, alongside the existing descriptor sub-targets).

### Open questions for the implementing session
- `Extent` vs an `Extended<Value>` (`NegInf/Finite/PosInf`) split — does the institute want
  a reusable `Extended` numeric-tower type (cf. Haskell) separate from interval, or is the
  `unbounded` case on `Extent` sufficient? (Lean: `Extent` is sufficient for intervals;
  a general `Extended` is a numeric-domain concern if ever needed.)
- Normalization of empty/degenerate intervals (PostgreSQL normalizes `[4,4)` → `empty`) —
  canonical-form policy.
- Whether `Interval` should bridge to / unify with `swift-range-primitives`' `Swift.Range`
  extensions or `swift-vector-primitives` (the former `Range.Lazy`/`Vector`).

## References

- `swift-institute/Research/order-cluster-decomposition-and-modernization.md` — the cluster program (Phase 5 = this doc); the constitutive-identity framework; foundational-dep policy.
- `swift-institute/Research/finite-interval-polarity-decomposition.md` (SUPERSEDED) — the full cross-ecosystem interval SLR with verified primary sources (Rust `std::ops::Bound`, Haskell `Data.Interval`, Boost.ICL, PostgreSQL ranges, IEEE 1788, Swift `RangeExpression`).
- Skills: `code-surface` `[API-NAME-001]` (Nest.Name — `Interval.Extent`/`Interval.Bound`), `swift-package` `[PKG-NAME-001]`, `modularization` `[MOD-031]`/`[MOD-017]`, `swift-institute` `[ARCH-LAYER-008]`.
