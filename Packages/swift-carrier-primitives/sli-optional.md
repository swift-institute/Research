# SLI — `Optional<Wrapped>`: Skip (strong case for could-be-done)

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

`Swift.Optional<Wrapped>` is a single-parameter sum type (`.some(Wrapped) | .none`). Optional has special semantic weight in Swift — it's the canonical "maybe" monad, first-class in the language. Should it conform to `Carrier`?

## Analysis

### Structural match

Trivial self-carriage compiles: `extension Optional: Carrier { typealias Underlying = Optional<Wrapped> }`. The default extension provides the getter and init.

### Semantic fit — trivial self-carriage

Trivial form is weak in the same way as Array/Set/Dictionary: `Optional<Int>` as `some Carrier<Optional<Int>>` is identical to plain `Optional<Int>`. No payoff.

### Semantic fit — parametric self-carriage

The interesting conformance is:

```swift
extension Optional: Carrier where Wrapped: Carrier {
    typealias Domain = Wrapped.Domain
    typealias Underlying = Optional<Wrapped.Underlying>
    var underlying: Optional<Wrapped.Underlying> { map { $0.underlying } }
    init(_ underlying: Optional<Wrapped.Underlying>) {
        self = underlying.map { Wrapped($0) }
    }
}
```

This reads cleanly. `Optional<Tagged<User, Int>>` becomes a carrier of `Optional<Int>` with `Domain = User`. Round-trip works: `Optional(.some(x)).underlying` returns `.some(x.underlying)`, `Optional(.some(x.underlying))` reconstructs.

The map pattern parallels Swift's standard Optional.map; consumers would find it natural.

### Why skip anyway

Three strikes:

1. **Generic Domain propagation lock-in.** Choosing `Domain = Wrapped.Domain` is one reasonable option; another is `Domain = Optional<Wrapped.Domain>` (preserves the presence dimension at the type level). Each has defenders. For 0.1.0 FINAL, committing to one is a one-way door.

2. **`~Copyable` Wrapped interaction.** When Wrapped is `~Copyable`, the `init(_ underlying: consuming [Underlying])` — wait no, Optional has `.take()` as the canonical consume pattern (see `swift-ownership-primitives/Sources/Ownership Primitives Standard Library Integration/Optional+take.swift`). Mixing Carrier's consuming init with Optional's existing consume semantics could create subtle interactions we haven't explored.

3. **Principled alternative exists.** Consumers who want `Optional<MyCarrier>: Carrier` can declare it in their package. If they want the specific parametric shape, they write it; if they want trivial, they write that instead. Centralizing the choice in carrier-primitives pre-commits.

### Could-it-be-done verdict

| Form | Viable? | Risk for 0.1.0 FINAL |
|------|---------|---------------------|
| Trivial self-carrier | Yes | No payoff |
| Parametric (`Wrapped: Carrier`, `Domain = Wrapped.Domain`) | Yes, cleanly | Locks Domain choice; blocks alternative shapes |
| Parametric (`Domain = Optional<Wrapped.Domain>`) | Yes, alternative | Same lock-in, different choice |

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: The parametric form has strong intuition (Optional.map-style carrier mapping) but is a one-way door on Domain propagation. Without a validated downstream use case, committing to one shape at 0.1.0 FINAL is higher risk than deferring. Optional is too central to Swift to pre-commit its Carrier semantics without broad ecosystem buy-in.

Consumers that want `Optional<MyCarrier>: Carrier` in their specific shape can declare it in their own package.

## References

- Swift stdlib `Optional<Wrapped>`.
- `swift-ownership-primitives/Sources/Ownership Primitives Standard Library Integration/Optional+take.swift` — existing ecosystem Optional extension (for reference; different pattern).
