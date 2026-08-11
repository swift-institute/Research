# Principled Absence — `LosslessStringConvertible`

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: DECISION
tier: 1
---
-->

## Context

`pointfreeco/swift-tagged` declares `Tagged<Tag, Underlying>: LosslessStringConvertible where Underlying: LosslessStringConvertible`, with the `init?(_ description: String)` failable init forwarding to `Underlying.init?(_:)` and `description` inherited from the unconditional `CustomStringConvertible` conformance.

`LosslessStringConvertible` requires a *round-trip guarantee*: for any value `v`, `T(v.description) == v`. This guarantee is the protocol's defining contract.

Swift Institute's `swift-tagged-primitives` deliberately removes this conformance. The argument is that the round-trip is **lossy from the Tagged perspective**: the `description` only encodes `Underlying.description`, not the phantom Tag. A `Tagged<User, Int>(_unchecked: 42)` has description `"42"`, identical to `Tagged<Order, Int>(_unchecked: 42)`'s description. The round-trip `Tagged(description) → description → Tagged(description)` cannot distinguish which tag was originally on the value because the tag isn't in the string. The *inhabitable* contract is "round-trip preserves the underlying value"; the *claimed* contract is "round-trip preserves the tagged value." These are different.

This document establishes the rationale and empirically classifies the absence.

**Trigger**: Per-protocol absence work directed by user 2026-04-30. Per [RES-001].

**Scope**: Package-specific (swift-tagged-primitives). Per [RES-002a].

## Question

Should `Tagged<Tag, Underlying>` conform to `LosslessStringConvertible` (when `Underlying: LosslessStringConvertible`)? If absent by default, what is the legitimate opt-in path, and is the conformance even authorable on Swift 6.3.1?

## Prior art

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.9 — original removal rationale (one paragraph).
- [`principled-absence-rawrepresentable.md`](./principled-absence-rawrepresentable.md) / [`principled-absence-strideable.md`](./principled-absence-strideable.md) / [`principled-absence-identifiable.md`](./principled-absence-identifiable.md) — same-day pattern; established the empirical-classification methodology.
- Swift stdlib `LosslessStringConvertible` declaration — inherits `CustomStringConvertible`; adds `init?(_ description: String)`.

## Analysis

### Option A — Conform unconditionally (pointfreeco pattern)

```swift
extension Tagged: LosslessStringConvertible
where Underlying: LosslessStringConvertible {
    public init?(_ description: String) {
        guard let underlying = Underlying(description) else { return nil }
        self.init(_unchecked: underlying)
    }
}
// description inherited from CustomStringConvertible.
```

**Pros**:
- Drop-in for stdlib LosslessStringConvertible-constrained APIs.
- Familiar `init?(_:)` failable-init pattern.

**Cons**:
1. **Round-trip is lossy from Tagged's perspective**. Two Tagged values with the same Underlying but different phantom Tags produce identical descriptions; the round-trip cannot recover the original tag. The protocol contract claims more than the type can deliver.
2. **Misleads about the protocol's own claim**. LosslessStringConvertible's documented invariant is `T(v.description) == v` for all `v`. For Tagged, this holds within a single Tag (because the Tag is part of the type, so `T == Tagged<User, Int>` and the round-trip stays within that type), but the *stored content* of the description doesn't carry the Tag — so a consumer who serializes via description, transmits it, and reconstitutes via init?(_) loses the Tag if the receiving side picks the wrong Tagged type.
3. **Reactivates the literal-conformance footgun in a different shape**. With unconditional `LosslessStringConvertible`, `String → Tagged<Tag, X>` is now an "ambient" conversion, available through any `init?(_:)` that takes String. Combined with literal conformances, this expands the overload-resolution surface in ways that mirror the Strideable footgun reactivation.

### Option B — SLI opt-in

```swift
// In Sources/Tagged Primitives Standard Library Integration/Tagged+LosslessStringConvertible.swift
extension Tagged: LosslessStringConvertible
where Tag: ~Copyable & ~Escapable, Underlying: LosslessStringConvertible & Escapable {
    public init?(_ description: String) {
        guard let underlying = Underlying(description) else { return nil }
        self.init(_unchecked: underlying)
    }
}
```

**Pros**:
- Default safety preserved.
- Opt-in for consumers who knowingly want String-roundtrip.

**Cons**:
- Lossy-from-Tagged-perspective cost remains, behind an import gate.
- Requires empirical authorability verification — `init?(_:)` is a function-style requirement; `description` requirement is satisfied by the existing CustomStringConvertible conformance. Both requirements should be authorable, but verification needed. See experiment.

### Option C — Hard absence + per-domain LosslessStringConvertible

```swift
// Consumer authors per-domain conformance:
struct UserID: LosslessStringConvertible {
    let storage: Tagged<User, Int>
    init?(_ description: String) {
        guard let raw = Int(description) else { return nil }
        self.storage = Tagged<User, Int>(_unchecked: raw)
    }
    var description: String { String(storage.underlying) }
}
```

**Pros**:
- Domain owns the lossless guarantee. The per-domain wrapper *is* a single tag, so the round-trip is genuinely lossless within that domain.
- Avoids the cross-domain lossy-roundtrip trap.

**Cons**:
- Per-domain conformance boilerplate.

## Empirical verification

[`Experiments/tagged-no-losslessstringconvertible/`](../Experiments/tagged-no-losslessstringconvertible/) tests Option B's authorability on Swift 6.3.1. See experiment for the empirical SOFT/HARD classification.

## Outcome

**[Updated post-experiment]**:

The experiment empirically verified that **Option B (SLI-style opt-in) IS authorable on Swift 6.3.1** — `init?(_:)` is function-style; `description` requirement is satisfied by the existing CustomStringConvertible conformance.

**Soft / Hard classification**: **SOFT** absence — **shipped in SLI** at [`Sources/Tagged Primitives Standard Library Integration/Tagged+LosslessStringConvertible.swift`](../../Sources/Tagged%20Primitives%20Standard%20Library%20Integration/Tagged+LosslessStringConvertible.swift) (2026-04-30). The `description` requirement is satisfied by Tagged's main-target `CustomStringConvertible` conformance (cross-module witness inheritance); the `init?(_:)` requirement is provided by the SLI extension. Lossy-from-Tagged-perspective trade-off documented at the conformance source.

Consumer-facing friction: importing SLI activates literal-conformance candidates that ambiguate `Tagged<Tag, Int>("...")` overload resolution with `LosslessStringConvertible.init?(_:)`. The known workaround is `Tagged<Tag, Int>(String("..."))` to disambiguate. See `Research/sli-literal-vs-strideable-tradeoff.md` § "Resolution of the unambiguous-string-init friction" for the full discussion.

The experiment also demonstrates the lossy-roundtrip cost — different phantom Tags producing identical descriptions — and the per-domain alternative which preserves the within-domain roundtrip guarantee genuinely.

**Forward-compatibility note**: Empirical finding specific to Swift 6.3.1; revalidate on toolchain updates.

## References

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.9 (the seed paragraph).
- [Swift stdlib LosslessStringConvertible](https://developer.apple.com/documentation/swift/losslessstringconvertible) — the round-trip contract.
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) `extension Tagged: LosslessStringConvertible`.
