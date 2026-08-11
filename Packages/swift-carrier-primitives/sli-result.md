# SLI — `Result<Success, Failure>`: Skip

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

`Swift.Result<Success, Failure>` is a two-parameter sum type (`.success(Success) | .failure(Failure)`). Should it conform to `Carrier`?

## Analysis

### Structural match

Trivial self-carriage compiles.

### Semantic fit

`Result` is semantically a disjoint union — Success OR Failure, not "a wrapped Success." The canonical "underlying" for `Result<Success, Failure>` is ambiguous:

- `Underlying = Success`? Doesn't fit the `.failure` case (which would need to round-trip as something, but what?).
- `Underlying = Result<Success.Underlying, Failure>` (where `Success: Carrier`)? Parametric in one parameter only; asymmetric.
- `Underlying = Either<Success.Underlying, Failure.Underlying>` (where both parameters are Carriers)? Conceptually cleanest but requires a stdlib Either type that doesn't exist.
- `Underlying = Self`? Trivial self-carriage; no payoff.

Two-parameter sum types don't have a natural Carrier semantics because Carrier assumes a single "wrapped value." Result wraps at most one of two things.

### Could-it-be-done verdict

| Form | Viable? |
|------|---------|
| Trivial self-carrier | Yes, but no payoff |
| Parametric (Success-axis) | Semantically lossy for `.failure` cases |
| Parametric (both-axes) | Requires a stdlib Either type (unavailable) |

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: Result is a sum type with no canonical "wrapped value" to serve as Underlying. The trivial form is zero-payoff; every parametric form is semantically lossy or requires infrastructure that doesn't exist. Carrier's abstraction (single wrapped Underlying) doesn't fit the disjoint-union shape.

Consumers that want to model Result-like carriers should consider the Typed-throws-thunk pattern (see swift-institute feedback `feedback_throws_not_result`) instead, which is the ecosystem-preferred representation for outcome values.

## References

- Swift stdlib `Result<Success, Failure>`.
- `feedback_throws_not_result` — ecosystem convention favoring `() throws(E) -> T` over `Result<T, E>`.
