# SLI — `Array<Element>`: Skip (could be done, rejected on complexity)

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

`Swift.Array<Element>` is a `Copyable` & `Escapable` value type wrapping a heap-allocated buffer of elements. The question: should `Array<Element>` conform to `Carrier` as a trivial self-carrier (Domain = Never, Underlying = Array<Element>), shipped in the Carrier Primitives Standard Library Integration target?

## Question

Should `extension Array: Carrier` ship in the SLI target?

## Analysis

### Structural match

`Array<Element>` is `Copyable & Escapable` for any Element that is itself Copyable. A trivial self-carriage would be:

```swift
extension Array: Carrier {
    public typealias Underlying = Array<Element>
    // default `extension Carrier where Underlying == Self` provides the rest
}
```

Compiles unconditionally for Copyable Element. For `~Copyable` Element, Array itself becomes `~Copyable`; the default extension's `_read { yield self }` handles both.

### Semantic fit

A trivial self-carrier says "I carry myself." For a value type like `Int`, that's coherent — an `Int` is one value. For `Array<Element>`, which is a collection of values, "I carry myself" is structurally true but semantically weak. The carrier abstraction adds nothing a consumer couldn't do by writing `someArray: [Int]` directly; the `Domain` phantom dimension is unused.

The interesting parametric conformance would be:

```swift
extension Array: Carrier where Element: Carrier {
    typealias Domain = Element.Domain?
    typealias Underlying = [Element.Underlying]
    // Non-trivial getter + init that map over elements
}
```

This treats `Array` as "the carrier of arrays-of-underlyings." But:

- `Domain = Element.Domain?` is a choice — why Optional? Why not a dedicated Domain type?
- The getter would copy every element's underlying, O(n) at each access — surprising for a getter signature that suggests O(1).
- `init(_ underlying: [Element.Underlying])` needs to rebuild Element per position, O(n) allocation.
- Only works when `Element.Domain` is consistent across all elements; arrays with heterogeneous-Domain elements can't conform. But `Array<Element>` has one Element type, so its Domain is uniform.

### Could-it-be-done verdict

| Form | Viable? | Cost |
|------|---------|------|
| Trivial self-carrier (`Underlying = Self`) | Yes, trivially | Zero — but zero semantic payoff |
| Parametric (`Underlying = [Element.Underlying]` with `Element: Carrier`) | Yes, non-trivially | O(n) getter / init; Domain arbitrary (Optional? Something else?); locks a specific semantic choice forever |

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**:

1. **Trivial form has zero semantic payoff.** `[Int]` as `some Carrier<[Int]>` is indistinguishable from plain `[Int]` at the call site. No phantom-tag dimension is created; no diagnostic/reflection value is added. The conformance would be API surface without purpose.

2. **Parametric form commits to a specific semantic choice.** `Domain = Element.Domain?` is one option among several; choosing it now locks it for 0.1.0 FINAL with no clear downstream demand to validate the choice. A consumer who needs `Array: Carrier` in their own context can add it; their choice of Domain can fit their use case.

3. **The single-conformance rule cuts the other way here.** Shipping `Array: Carrier` centrally would FORBID every consumer from declaring a different parametric shape. For a type as widely-used as Array, this centralization is a liability, not an asset — we don't know enough about downstream use cases to pick the right parametric shape.

Consumers that want `[Int]: Carrier<[Int]>` (trivial) or `[Tagged<Tag, Int>]: Carrier<[Int]>` (parametric) can declare the conformance in their own package with the shape they actually need.

## References

- Swift stdlib `Array<Element>`.
- `Research/Carrier Primitives Vision.md` §"Generic Underlying" (formerly the dedicated `capability-lift-pattern.md` §V5a, consolidated 2026-04-29) — the general analysis of generic types as Carrier conformers.
