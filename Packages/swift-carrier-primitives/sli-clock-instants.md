# SLI — Clock Instant family (`ContinuousClock.Instant`, `SuspendingClock.Instant`): Skip

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

Swift concurrency provides two clock types with nested Instant types: `ContinuousClock.Instant` (wall-clock point) and `SuspendingClock.Instant` (suspending-clock point). Both are Copyable, Escapable, Hashable, Comparable. Should they conform to `Carrier`?

## Analysis

### Structural match

Each compiles with trivial self-carriage via the default extension.

### Semantic fit

Clock Instants are points in time, not value wrappers. Trivial self-carriage gives `ContinuousClock.Instant: some Carrier<ContinuousClock.Instant>` — no phantom dimension, no cross-type algorithm benefit.

Unlike `Duration` (which is a time-SPAN and naturally a value), Instants are positional — they describe where on a timeline you are. The "carry a value" abstraction fits less cleanly. Even for Duration we admitted there's limited payoff; for Instants it's weaker still.

### Specificity concern

`ContinuousClock.Instant` and `SuspendingClock.Instant` are nested under their respective Clock types. Shipping their Carrier conformances in the SLI target centralizes two very specialized types that few consumers reach for.

### Could-it-be-done verdict

| Form | Viable? | Value |
|------|---------|-------|
| Trivial self-carrier | Yes | Low — positional semantics mismatch |

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: Clock Instants are positional, not value-like. Trivial self-carriage adds no payoff; the abstraction's fit is weaker than for Duration. Too specialized to centralize without a concrete use case. Duration was included as the minimal time-related conformance; extending to Instants would bloat the SLI without proportionate utility.

## References

- Swift stdlib `ContinuousClock.Instant`, `SuspendingClock.Instant`.
- `Duration+Carrier.swift` in the SLI target — included as the one time-related conformance.
