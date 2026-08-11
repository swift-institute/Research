# SLI — `InlineArray<count, Element>`: Skip

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

`Swift.InlineArray<count, Element>` (SE-0452, Swift 6.1+) is a fixed-size array with inline storage — a value-type sequence of exactly `count` elements. Unlike `Array<Element>` it has a value-generic parameter (`count: Int`) in addition to the type parameter. Should it conform to `Carrier`?

## Analysis

### Structural match

Trivial self-carriage would compile in principle (it's a value-type with standard Copyable / Escapable conformance when Element is). The default extension handles the mechanics.

### Semantic fit

InlineArray shares Array's zero-payoff issue for trivial self-carriage. Parametric forms also mirror Array's problems (see `sli-array.md`).

### Value-generic wrinkle

InlineArray's `count: Int` value generic doesn't interact with Carrier's Domain/Underlying dimensions directly — but it adds an extra parametric axis the Carrier abstraction doesn't care about, which makes the conformance feel awkward (why expose `count` through a carrier?).

### Availability

SE-0452 lands in Swift 6.1+; carrier-primitives targets 6.3.1 so availability is fine.

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: Same as `sli-array.md` plus the value-generic axis concern. Consumers with a specific InlineArray-based Carrier shape can declare it in their own package.

## References

- Swift stdlib `InlineArray` (SE-0452).
- `sli-array.md`.
