# SLI — `TaskPriority`: Skip (could be done, weak case)

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

`Swift.TaskPriority` is a struct wrapping an 8-bit priority value used by the Swift concurrency runtime for task scheduling. Copyable, Escapable, Hashable, Comparable. Should it conform to `Carrier`?

## Analysis

### Structural match

Trivial self-carriage compiles:

```swift
extension TaskPriority: Carrier {
    public typealias Underlying = TaskPriority
}
```

### Semantic fit

TaskPriority is a value type with one opaque UInt8 inside. It could be seen as "carrying" that UInt8, but the `.rawValue` isn't stable API — TaskPriority intentionally hides its internal representation.

Trivial self-carriage (`Underlying = TaskPriority`) is zero-payoff in the same way Array is: no phantom dimension, no generic dispatch utility. A consumer writing `some Carrier<TaskPriority>` doesn't gain anything over `TaskPriority`.

### Use case analysis

Who would want TaskPriority as a Carrier? Possible: a generic function that accepts "any priority-like value" — but such a function would more naturally take `TaskPriority` directly. No cross-type dispatch utility is evident.

### Could-it-be-done verdict

| Form | Viable? | Value |
|------|---------|-------|
| Trivial self-carrier | Yes | None evident |

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: Trivial self-carriage is technically viable but adds no value for this particular type. TaskPriority is too specialized to justify API-surface commitment without a demonstrated use case. Consumers who need it can declare the conformance in their own package.

## References

- Swift stdlib `TaskPriority` (Swift concurrency).
