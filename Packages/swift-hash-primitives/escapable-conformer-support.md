# Escapable Conformer Support

<!--
---
version: 1.0.0
last_updated: 2026-05-09
status: DECISION
tier: 1
scope: package
trigger: cohort ~Escapable adoption push 2026-05-09. Mirrors swift-equation-primitives `3495e50` upgrade for Hash.Protocol.
related:
  - swift-equation-primitives/Research/escapable-conformer-support.md
  - swift-institute/Research/escapable-support-pair-either-product.md
---
-->

## Decision

`Hash.Protocol` admits `~Escapable` conformers as of commit `0e5708e`:

```swift
public protocol `Protocol`: Equation.`Protocol`, ~Copyable, ~Escapable {
    borrowing func hash(into hasher: inout Hasher)
}

extension Hash.`Protocol` where Self: ~Copyable & ~Escapable {
    public var hashValue: Hash.Value { ... }
}
```

The `borrowing func hash(into:)` requirement supports `~Escapable Self` correctly. Hash.Protocol refines Equation.Protocol — both upgraded together so the inherited conformance composes cleanly.

## Cross-references

- Sibling-protocol upgrade: swift-equation-primitives `3495e50`
- Sibling-protocol upgrade: swift-comparison-primitives `a4fd209`
- Cohort consumers: swift-pair-primitives `7f7c7ef`, swift-either-primitives `b6b7672`
- Ecosystem-wide research: swift-institute/Research/escapable-support-pair-either-product.md
