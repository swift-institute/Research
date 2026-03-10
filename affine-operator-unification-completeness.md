# Affine Operator Unification Completeness

<!--
---
version: 1.1.0
last_updated: 2026-03-10
status: DEFERRED
tier: 1
---
-->

## Context

Phase 2 of the protocol abstraction for phantom-typed wrappers unified Vector-Cardinal comparisons in affine-primitives using `where V.Domain == C.Domain`. However, some operators in `Tagged+Affine.swift` were not unified:

- Ordinal-Ordinal→Vector operators
- Tagged Ordinal - Tagged Vector operators

Source: reflection `2026-02-13-suppressed-associatedtype-domain-unification.md`.

## Question

Should the remaining `Tagged+Affine.swift` operators (Ordinal-Ordinal→Vector, Tagged Ordinal-Tagged Vector) also be unified via Domain + companion types, or is the current split between bare-return and tagged-return intentional?

## Analysis

*Pending investigation.*

Key sub-questions:
1. Do the remaining operators return bare types or tagged types?
2. If tagged, do they preserve the Domain information?
3. Would unification reduce operator count, or are the variants genuinely distinct?

## Outcome

**Status**: DEFERRED

Investigation never started. The remaining Ordinal-Ordinal→Vector and Tagged Ordinal-Tagged Vector operators in `Tagged+Affine.swift` are functional and tested. Unification via Domain is an optimization, not a correctness concern. Revisit when affine-primitives undergoes its next major audit or when new operator variants are added.

**Deferred since**: 2026-03-10
