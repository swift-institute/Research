# SLI — `Set<Element>`: Skip

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: DECISION
tier: 1
scope: swift-carrier-primitives SLI target
---
-->

## Context

`Swift.Set<Element>` is a `Copyable & Escapable` generic hash-set container requiring `Element: Hashable`. Should it conform to `Carrier`?

## Analysis

### Structural match

Trivial self-carriage compiles:

```swift
extension Set: Carrier {
    public typealias Underlying = Set<Element>
}
```

Because the default extension `where Underlying == Self` provides the rest.

### Semantic fit

Same issue as `Array<Element>` (see `sli-array.md`): trivial self-carriage adds no phantom dimension — `Set<Int>` as `some Carrier<Set<Int>>` is indistinguishable from plain `Set<Int>`. No diagnostic, reflection, or generic-dispatch value emerges.

A parametric form `Set: Carrier where Element: Carrier` would unwrap each element's underlying:

```swift
extension Set: Carrier where Element: Carrier, Element.Underlying: Hashable {
    typealias Underlying = Set<Element.Underlying>
    // Non-trivial getter rebuilds the set from underlyings
}
```

Problem: Set-of-Carrier hash consistency. `Element.Underlying.hashValue` need not equal `Element.hashValue`; mapping between `Set<Element>` and `Set<Element.Underlying>` is NOT a simple element-wise lift — it can collapse elements or change the cardinality (two `Tagged<A, Int>` values with different Tags but same rawValue hash to the SAME position in a Set<Int> but DIFFERENT positions in a Set<Tagged<A, Int>>). The round-trip is lossy.

### Could-it-be-done verdict

| Form | Viable? | Cost |
|------|---------|------|
| Trivial self-carrier | Yes | No payoff; centralizes a conformance no one clearly needs |
| Parametric (element-unwrap) | Partially — hash-consistency issues break the round-trip property |

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: No payoff in the trivial form; hash-consistency issues in the parametric form. Consumers with a specific need can declare their own conformance with their specific semantics.

## References

- Swift stdlib `Set<Element>`.
- `sli-array.md` for the parallel parametric-vs-trivial analysis.
