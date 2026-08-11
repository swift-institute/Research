# SLI — Range family (`Range`, `ClosedRange`, `PartialRangeFrom`, `PartialRangeThrough`, `PartialRangeUpTo`): Skip

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

Swift's range types — `Range<Bound>`, `ClosedRange<Bound>`, `PartialRangeFrom<Bound>`, `PartialRangeThrough<Bound>`, `PartialRangeUpTo<Bound>` — are single-parameter value types describing an interval over some `Comparable` `Bound`. Should any conform to `Carrier`?

## Analysis

The five range types share identical considerations, so one analysis covers them all.

### Structural match

Trivial self-carriage compiles for each. Default extension provides the requirements.

### Semantic fit

A range is a pair of bounds (or a single bound + direction), not a single value. The "wrapped value" the Carrier abstraction assumes doesn't exist — there's no canonical `Underlying` for `Range<Int>` that reads as "the Int this range carries."

Possible parametric interpretations:

- `Underlying = Bound`: absurd — a range isn't a Bound.
- `Underlying = (Bound, Bound)` for `Range`/`ClosedRange`: a pair of bounds. Technically works but `Underlying = (Bound, Bound)` isn't a shape Carrier consumers naturally reach for.
- `Underlying = Range<Bound.Underlying>` where `Bound: Carrier`: parametric over the bound's underlying type. Useful for something like `Tagged<UserId, Int>` ranges, but opinionated.
- `Underlying = Self`: trivial self-carriage, no payoff.

None of these feels canonical for a stdlib ship.

### Could-it-be-done verdict

| Form | Viable? |
|------|---------|
| Trivial self-carrier | Yes, no payoff |
| Bound-pair Underlying | Works but awkward; tuple Underlying is unusual |
| Parametric bound-unwrap | Yes, opinionated choice |

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: Ranges are interval types, not value wrappers. The Carrier abstraction (single wrapped Underlying) fits poorly; no parametric form is canonical. Consumers that need range-of-Carrier semantics (e.g., "a range of Tagged<Tag, Int> indices") can declare the specific shape in their own package.

## References

- Swift stdlib `Range<Bound>`, `ClosedRange<Bound>`, `PartialRangeFrom<Bound>`, `PartialRangeThrough<Bound>`, `PartialRangeUpTo<Bound>`.
