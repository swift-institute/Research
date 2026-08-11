# Escapable Conformer Support

<!--
---
version: 1.0.0
last_updated: 2026-05-09
status: DECISION
tier: 1
scope: package
trigger: cohort ~Escapable adoption push 2026-05-09. swift-pair-primitives' type-level upgrade required Equation.Protocol to admit ~Escapable conformers; same applied to Hash.Protocol and Comparison.Protocol.
related:
  - swift-institute/Research/escapable-support-pair-either-product.md
  - swift-institute/Research/nonescapable-ecosystem-state.md
  - swift-pair-primitives/Research/escapable-arm-support.md
  - swift-either-primitives/Research/escapable-arm-support.md
---
-->

## Question

Should `Equation.Protocol` admit `~Escapable` conformers in addition to `~Copyable`?

## Decision

**Yes.** Upgraded the protocol declaration to suppress both Copyable and Escapable:

```swift
public protocol `Protocol`: ~Copyable, ~Escapable {
    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

extension Equation.`Protocol` where Self: ~Copyable & ~Escapable {
    public static func != (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        !(lhs == rhs)
    }
}
```

Shipped in commit `3495e50`.

## Rationale

The institute Equation.Protocol's `borrowing Self` parameter shape supports `~Escapable Self` correctly — borrowing a ~Escapable value is lifetime-restricted but well-formed. The protocol declaration's `~Copyable`-only suppression was over-restrictive: it excluded ~Escapable conformers despite the operations being implementable on them.

Existing Copyable + Escapable conformers are unaffected (suppressions are permissive).

## Downstream impact

The cohort consumers — `swift-pair-primitives` and `swift-either-primitives` — now admit ~Escapable arms in their institute conformances:

```swift
extension Pair: Equation.`Protocol`
where
    First: Equation.`Protocol` & ~Copyable & ~Escapable,
    Second: Equation.`Protocol` & ~Copyable & ~Escapable
{ ... }
```

Hash.Protocol and Comparison.Protocol followed the same pattern (`swift-hash-primitives` `0e5708e`, `swift-comparison-primitives` `a4fd209`).

## SE-0499 interaction

On Swift 6.4+, `Equation.Protocol` typealiases to `Swift.Equatable` per SE-0499. Stdlib `Equatable` itself is `~Copyable & ~Escapable`-permissive in Swift 6.4 per SE-0499. The upgrade is therefore consistent across the version gate.

## Cross-references

- Empirical verification: cohort consumer tests in swift-pair-primitives and swift-either-primitives
- Sibling-protocol research: swift-hash-primitives `0e5708e`, swift-comparison-primitives `a4fd209`
- Cohort consumer research: swift-pair-primitives/Research/escapable-arm-support.md
