# Principled Absence — `Strideable`

<!--
---
version: 1.1.0
last_updated: 2026-04-30
status: DECISION
tier: 1
---
-->

<!--
Changelog:
- v1.1.0 (2026-04-30, same-day reclassification): policy correction
  per `sli-literal-vs-strideable-tradeoff.md` (DECISION). Strideable
  remains SOFT structurally (the conformance is authorable; experiment
  unchanged) but is **excluded from SLI by policy** because the
  literal-conformance footgun reactivates when both Strideable and
  ExpressibleBy*Literal are in scope. The user-directed trade-off
  (2026-04-30) chose ExpressibleBy*Literal for SLI inclusion over
  Strideable; consumers who want generic-Tagged Strideable copy the
  6-line extension into their own codebase explicitly.
- v1.0.0 (2026-04-30): initial empirical classification SOFT, SLI-
  eligible. Superseded in-day by the v1.1.0 policy reclassification.
-->

## Context

`pointfreeco/swift-tagged` declares `Tagged<Tag, Underlying>: Strideable where Underlying: Strideable`, with `Stride == Underlying.Stride` and forwarding `distance(to:)` / `advanced(by:)`. The conformance enables `for i in start...end { … }` iteration over Tagged values whose Underlying strides.

Swift Institute's `swift-tagged-primitives` deliberately removes this conformance. The argument is semantic — stride operations on a phantom-typed value should belong to the *domain* (the tag), not auto-forwarded from the underlying value. A `Tagged<User, Int>` that is `Strideable` lets consumers write `userA...userB`, which compiles and does something, but the something is "iterate Int values between userA's raw and userB's raw." That meaning is incidental to the domain, not derived from it. A domain that does have meaningful stride semantics (e.g., `Index<Element>` over a contiguous collection) should author its Strideable conformance per-domain, not inherit it via blanket forwarding.

This document establishes the rationale and empirically classifies the absence as **soft** (eligible for SLI opt-in) or **hard** (not authorable even on opt-in) via the experiment in `Experiments/tagged-no-strideable/`.

**Trigger**: Per-protocol absence work directed by user 2026-04-30. Per [RES-001].

**Scope**: Package-specific (swift-tagged-primitives). Per [RES-002a].

## Question

Should `Tagged<Tag, Underlying>` conform to `Strideable` (when `Underlying: Strideable`)? If absent by default, what is the legitimate opt-in path, and is the conformance even authorable on Swift 6.3.1?

## Prior art

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.2 — original removal rationale (one paragraph).
- [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md) — establishes that without `Strideable`, the literal-conformance footgun is dormant; with it, the footgun reactivates. Strideable is therefore load-bearing for an *anti-footgun* property, not just a stride convenience.
- `swift-index-primitives/Research/Strideable Index Design.md` (DECISION 2026-01-28) — approved `Index: Strideable where Tag: ~Copyable` at the *specialisation* layer (Index, not Tagged). Establishes the per-domain conformance pattern.
- [`principled-absence-rawrepresentable.md`](./principled-absence-rawrepresentable.md) — same-day pattern instance; empirical experiment surfaced a structural `~Escapable`-non-awareness blocker. Strideable's classification depends on whether the same blocker applies (Strideable's requirements are function-style, not stored-property-style — the Swift-level blocker may or may not fire here).

## Analysis

### Option A — Conform unconditionally (pointfreeco pattern)

```swift
extension Tagged: Strideable where Underlying: Strideable {
    public func distance(to other: Tagged) -> Underlying.Stride {
        underlying.distance(to: other.underlying)
    }
    public func advanced(by n: Underlying.Stride) -> Tagged {
        Tagged(_unchecked: underlying.advanced(by: n))
    }
}
```

**Pros**:
- Drop-in `for i in start...end` ergonomics for any Tagged whose Underlying strides.
- Familiar stdlib pattern.

**Cons**:
1. **Reactivates the literal-conformance footgun** ([`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md)): once Tagged is `Strideable`, the silent overload-resolution misfire on `.map(Bit.Index.init)` reactivates because Strideable enables `Range<Tagged>` patterns that drive the resolution into the failing case. This is the strongest single argument against blanket Strideable.
2. **Blanket forwarding ignores domain**. A `Tagged<User, Int>` strides "by Int" — but the tag never participated in the semantic claim. The stride operation does not respect the domain at all; it's a bare Underlying operation in domain clothing.
3. **Cross-domain ranges still don't compile** (the phantom Tag protects this), but **same-domain ranges do** — consumers form `userA...userB` thinking "users between A and B" while the implementation is "Int-stride between rawA and rawB." If users are sparse (non-contiguous IDs), the iteration produces non-existent users.

### Option B — SLI opt-in

```swift
// In Sources/Tagged Primitives Standard Library Integration/Tagged+Strideable.swift
extension Tagged: Strideable
where Tag: ~Copyable & ~Escapable, Underlying: Strideable & Comparable & Equatable & Escapable {
    public func distance(to other: Tagged) -> Underlying.Stride { underlying.distance(to: other.underlying) }
    public func advanced(by n: Underlying.Stride) -> Tagged { Tagged(_unchecked: underlying.advanced(by: n)) }
}
```

**Pros**:
- Default safety preserved — main-target consumers don't get blanket strideability + footgun reactivation.
- Opt-in available for consumers who knowingly want stride semantics on their Tagged values.

**Cons**:
- Once a consumer imports SLI, the literal-footgun-reactivation argument applies in their compilation unit.
- Same blanket-forwarding-ignores-domain critique as Option A, just behind an import gate.
- Requires empirical verification: does the conformance even compile on Swift 6.3.1? See experiment.

### Option C — Hard absence + per-domain conformance (current position)

```swift
// Consumer authors per-domain conformance (e.g., in swift-index-primitives):
extension Index: Strideable where Tag: ~Copyable {
    public func distance(to other: Index) -> Ordinal.Stride { ... }
    public func advanced(by n: Ordinal.Stride) -> Index { ... }
}
```

**Pros**:
- Domain owns the stride semantics. `Index<Element>` strides "by position in the collection," authored at the domain layer where that semantic is correct.
- Avoids the literal-footgun reactivation entirely (no Tagged-level Strideable means no Tagged-level Range patterns).
- Phantom Tag never carries strideability it doesn't earn semantically.

**Cons**:
- Consumers who genuinely want generic-Tagged stride operations must author per-domain conformance — boilerplate per type. (Mitigated by the fact that the per-domain author is the only one who can correctly specify what stride means for their domain.)

## Empirical verification

[`Experiments/tagged-no-strideable/`](../Experiments/tagged-no-strideable/) tested Option B's authorability on Swift 6.3.1 (2026-04-30):

| Test | Result |
|---|---|
| Option B (opt-in conformance via `extension Tagged: @retroactive Strideable where ...`) compiles | **✓ Authorable** |
| `tagged.distance(to:)` and `tagged.advanced(by:)` forward correctly | ✓ |
| `for u in userA...userB { … }` iterates same-domain range correctly | ✓ ([1, 2, 3, 4, 5]) |
| Cross-domain range (`userA ... orderB`) is rejected by phantom Tag | ✓ (compile error) |
| Per-domain conformance (Option C) — `Slot: Strideable` with valid-IDs-position stride | ✓ — domain stride differs from raw-Int stride |

**Empirical classification**: **SOFT absence**. Strideable's requirements are function-style (`distance(to:)`, `advanced(by:)`) rather than stored-property-style — so the structural `~Escapable` blocker that hit RawRepresentable does NOT fire here. The conformance is authorable on consumer-side opt-in (and therefore on SLI).

The experiment also demonstrates Option C's per-domain pattern via `Slot: Strideable` where the stride increments by *valid-ID-position*, not raw-Int — illustrating that domain-correct stride semantics are accessible to consumers regardless of whether they take the SLI path.

## Outcome

**Status**: DECISION — Option C (per-domain conformance) for all consumers; SLI does NOT ship Strideable.

`Tagged<Tag, Underlying>: Strideable` is **absent from both the main target and the SLI target**. The conformance is empirically authorable (the per-domain pattern verified in the experiment), but the SLI inclusion is **excluded by policy** per [`sli-literal-vs-strideable-tradeoff.md`](./sli-literal-vs-strideable-tradeoff.md) (DECISION 2026-04-30) — shipping Strideable in SLI alongside the `ExpressibleBy*Literal` conformances activates the literal-conformance footgun documented in [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md). The user-directed trade-off (2026-04-30) chose to ship literals in SLI rather than Strideable.

**Soft / Hard classification**: **SOFT structurally + SLI-excluded-by-policy**. The conformance is authorable on Swift 6.3.1 (the experiment's empirical finding stands); the SLI exclusion is the policy choice in the trade-off doc.

**Consumer alternative**: copy the 6-line extension into the consumer's own codebase when generic-Tagged Strideable is needed:

```swift
extension Tagged: Strideable
where Tag: ~Copyable & ~Escapable,
      Underlying: Strideable & Comparable & Equatable & Escapable {
    public func distance(to other: Tagged) -> Underlying.Stride {
        underlying.distance(to: other.underlying)
    }
    public func advanced(by n: Underlying.Stride) -> Tagged {
        Tagged(_unchecked: underlying.advanced(by: n))
    }
}
```

The consumer who copies this into their own scope is also opting into the literal-conformance footgun for that scope — knowingly, with the rationale documented here. For Index types specifically, `swift-index-primitives/Research/Strideable Index Design.md` (DECISION 2026-01-28) approves `Index: Strideable where Tag: ~Copyable` as the per-domain pattern at the Index layer.

**Forward-compatibility note**: This empirical finding is specific to Swift 6.3.1. Future Swift toolchain versions may change function-style witness semantics for `~Escapable` types; the classification SHOULD be revalidated on toolchain updates. The policy decision (SLI exclusion) is independent of toolchain.

## References

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.2 (the seed paragraph).
- [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md) — Strideable as the footgun-reactivation pivot.
- `swift-index-primitives/Research/Strideable Index Design.md` (DECISION 2026-01-28) — the approved per-domain Strideable pattern.
- [`principled-absence-rawrepresentable.md`](./principled-absence-rawrepresentable.md) — same-day pattern; the structural-blocker discovery.
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) `extension Tagged: Strideable`.
