# Escapable Conformer Support

<!--
---
version: 1.0.0
last_updated: 2026-05-09
status: DECISION
tier: 1
scope: package
trigger: cohort ~Escapable adoption push 2026-05-09. Mirrors swift-equation-primitives `3495e50` and swift-hash-primitives `0e5708e` upgrades for Comparison.Protocol.
related:
  - swift-equation-primitives/Research/escapable-conformer-support.md
  - swift-hash-primitives/Research/escapable-conformer-support.md
  - swift-institute/Research/escapable-support-pair-either-product.md
---
-->

## Decision

`Comparison.Protocol` admits `~Escapable` conformers as of commit `a4fd209`:

```swift
public protocol `Protocol`: Equation.`Protocol`, ~Copyable, ~Escapable {
    static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

extension Comparison.`Protocol` where Self: ~Copyable & ~Escapable {
    public static func <= (lhs: borrowing Self, rhs: borrowing Self) -> Bool { ... }
    public static func > (lhs: borrowing Self, rhs: borrowing Self) -> Bool { ... }
    public static func >= (lhs: borrowing Self, rhs: borrowing Self) -> Bool { ... }
}
```

Comparison.Protocol refines Equation.Protocol — both upgraded together (along with Hash.Protocol) so the inherited conformances compose cleanly.

## Cross-references

- Sibling-protocol upgrades: swift-equation-primitives `3495e50`, swift-hash-primitives `0e5708e`
- Cohort consumers: swift-pair-primitives `7f7c7ef`, swift-either-primitives `b6b7672`
- Ecosystem-wide research: swift-institute/Research/escapable-support-pair-either-product.md
