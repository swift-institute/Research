# Principled Absence — `Identifiable`

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: DECISION
tier: 1
---
-->

## Context

`pointfreeco/swift-tagged` declares `Tagged<Tag, Underlying>: Identifiable where Underlying: Identifiable`, with `id` forwarding to `underlying.id`. This makes any Tagged whose Underlying is Identifiable also Identifiable.

Swift Institute's `swift-tagged-primitives` deliberately removes this conformance. The argument is semantic:

`Tagged` itself is an identity mechanism — the phantom `Tag` is the discriminator that distinguishes `Tagged<User, Int>` from `Tagged<Order, Int>`. The tag IS the identity; the underlying value is the data.

Forwarding `id` to `underlying.id` claims that "`Tagged` is identifiable by `Underlying.id`," which is a different identity from the one Tagged actually carries. SwiftUI / generic Identifiable code keying off `tagged.id` would observe `underlying.id` — they would not see the phantom-typed identity that makes Tagged distinct from a different Tagged with the same Underlying but different Tag.

The blanket conformance therefore **inverts the identity story**: the phantom Tag that was supposed to be the discriminator becomes invisible to the protocol-driven identity system, while the underlying value (which the wrapper is precisely meant to obscure) gets exposed as the identity.

This document establishes the rationale and empirically classifies the absence as **soft** (eligible for SLI opt-in) or **hard** (not authorable on opt-in) via the experiment in `Experiments/tagged-no-identifiable/`.

**Trigger**: Per-protocol absence work directed by user 2026-04-30. Per [RES-001].

**Scope**: Package-specific (swift-tagged-primitives). Per [RES-002a].

## Question

Should `Tagged<Tag, Underlying>` conform to `Identifiable` (when `Underlying: Identifiable`)? If absent by default, what is the legitimate opt-in path, and is the conformance even authorable on Swift 6.3.1?

## Prior art

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.8 — original removal rationale (one paragraph).
- [`principled-absence-rawrepresentable.md`](./principled-absence-rawrepresentable.md) — same-day pattern; established that protocols requiring stored-property-style witnesses on `~Escapable` types may be structurally non-authorable on Swift 6.3.1. Identifiable's `var id: ID { get }` requirement is similar in shape; empirical verification needed.
- [`principled-absence-strideable.md`](./principled-absence-strideable.md) — same-day pattern; established that function-style witnesses do bypass the structural blocker (Strideable: SOFT). Identifiable's getter is property-style but witnesses by computed-forward (`var id: ID { underlying.id }`), not direct-stored — empirical question is whether this matters.

## Analysis

### Option A — Conform unconditionally (pointfreeco pattern)

```swift
extension Tagged: Identifiable where Underlying: Identifiable {
    public var id: Underlying.ID { underlying.id }
}
```

**Pros**:
- Drop-in for SwiftUI lists / generic Identifiable code keying off `.id`.
- Familiar stdlib pattern.

**Cons**:
1. **Inverts the identity story**. Tagged's identity-discriminator is the phantom Tag; the underlying value is data. The blanket conformance exposes the raw-value identity, hiding the phantom-typed identity from protocol-driven identity systems. SwiftUI's `ForEach` on `[Tagged<Tag, X>]` would treat two Tagged values with the same `Underlying.id` as the *same row*, even if the phantom Tags are different.
2. **Conflates wrapper identity with content identity**. `tagged.id == otherTagged.id` is a claim about the underlying values, not the tagged values. Identity equality should match the value's actual identity, which for Tagged includes the Tag.
3. **Hard to reason about for generic-Tagged consumers**. Generic code constrained on `T: Identifiable` doesn't see the phantom Tag; `T.ID == Underlying.ID` is an associated-type leak that exposes implementation details of the wrapper.

### Option B — SLI opt-in

```swift
// In Sources/Tagged Primitives Standard Library Integration/Tagged+Identifiable.swift
extension Tagged: Identifiable
where Tag: ~Copyable & ~Escapable, Underlying: Identifiable & Escapable {
    public var id: Underlying.ID { underlying.id }
}
```

**Pros**:
- Default safety preserved — main-target consumers get the phantom-typed wrapper without the identity-inversion misleadingness.
- Opt-in path for consumers who knowingly want SwiftUI-style id-driven identity from Underlying.id.

**Cons**:
- Still inverts the identity story; just behind an import gate.
- Generic-Tagged consumers reading the protocol-list see misleading framing once SLI is imported.
- Requires empirical verification of authorability — Identifiable's getter style is property-witness, similar to RawRepresentable. See experiment.

### Option C — Hard absence + per-domain Identifiable

```swift
// Consumer authors per-domain conformance:
struct UserID: Identifiable {
    let storage: Tagged<User, UInt64>
    var id: UInt64 { storage.underlying }
}

// OR more common pattern: the domain type IS the Identifiable.
struct User: Identifiable {
    let id: Tagged<User, UInt64>     // Tagged itself acts as the id
    let name: String
}
```

**Pros**:
- Domain owns the identity semantics. The author of the domain decides what `id` means for their type — usually "the Tagged value itself."
- Avoids the identity-inversion trap. SwiftUI sees the Tagged value as the id, which preserves phantom-typed discrimination.
- Aligns with the "Tagged IS the identity mechanism" framing — Tagged becomes the `ID` of consumer types, not a wrapper that has an id.

**Cons**:
- Consumers must author per-domain Identifiable conformance — boilerplate per type. (Mitigated: most domain types have multiple fields beyond the tagged ID, so they're authoring the struct anyway.)

## Empirical verification

[`Experiments/tagged-no-identifiable/`](../Experiments/tagged-no-identifiable/) tests Option B's authorability on Swift 6.3.1 — does the conformance compile when constraint-shaped to opt-in via consumer extension? See experiment for the empirical SOFT/HARD classification.

## Outcome

(See "Empirical verification" — populated by the experiment's results below.)

**[Updated post-experiment]**:

The experiment empirically verified that **Option B (SLI-style opt-in) IS authorable on Swift 6.3.1**: the `id` witness is a computed property forwarding to `underlying.id` (function-call-like access), not a direct stored-property accessor. The structural `~Escapable` blocker that hit RawRepresentable does NOT fire for Identifiable.

**Soft / Hard classification**: **SOFT** absence — **shipped in SLI** at [`Sources/Tagged Primitives Standard Library Integration/Tagged+Identifiable.swift`](../../Sources/Tagged%20Primitives%20Standard%20Library%20Integration/Tagged+Identifiable.swift) (2026-04-30). Consumers `import Tagged_Primitives_Standard_Library_Integration` to opt in; identity-inversion trade-off documented at the conformance source as part of the in-line rationale.

The experiment also demonstrates Option C — a domain type `User: Identifiable` whose `id` is the Tagged value itself (not `underlying.id`), preserving the phantom-typed identity semantics. This is the recommended pattern for Institute consumers authoring their own domain types; SLI opt-in is for Tagged consumers integrating with external SwiftUI/Identifiable-keyed APIs that they cannot refactor to Tagged-as-id.

**Forward-compatibility note**: Empirical finding is specific to Swift 6.3.1 toolchain. Revalidate on toolchain updates.

## References

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §3.8 (the seed paragraph).
- [`principled-absence-rawrepresentable.md`](./principled-absence-rawrepresentable.md) — same-day pattern; the structural-blocker discovery for stored-property-style witnesses.
- [`principled-absence-strideable.md`](./principled-absence-strideable.md) — same-day pattern; function-style witnesses bypass the blocker.
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) `extension Tagged: Identifiable`.
