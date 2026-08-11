# SLI — `ContiguousArray<Element>`: Skip

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

`Swift.ContiguousArray<Element>` is a variant of `Array<Element>` guaranteeing contiguous native storage (no bridged-to-NSArray representation). Functionally near-identical to Array for the purposes of Carrier conformance. Should it conform to Carrier?

## Analysis

ContiguousArray's considerations are identical to Array's (see `sli-array.md`). Trivial self-carriage is zero-payoff; parametric forms require opinionated Domain/Underlying choices.

One small note: ContiguousArray's contiguous-storage guarantee isn't relevant to the Carrier abstraction — Carrier doesn't care about storage layout.

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: Same as `sli-array.md`. The Array / ContiguousArray distinction is orthogonal to the Carrier question.

## References

- Swift stdlib `ContiguousArray<Element>`.
- `sli-array.md`.
