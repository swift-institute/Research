# SLI — `Void` / `()`: Skip

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

`Swift.Void` (alias for the empty tuple `()`) is the unit type — a type with exactly one value (the empty tuple). Should it conform to `Carrier`?

## Analysis

### Structural match

Tuples in Swift cannot directly conform to protocols (SE-0283 made tuples Equatable / Comparable / Hashable via compiler-synthesized conformances but did not open nominal protocol conformance on tuples in general). An `extension Void: Carrier` declaration fails to compile:

```swift
extension Void: Carrier { ... }
// error: non-nominal type 'Void' (aka '()') cannot be extended
```

### Workaround?

We could introduce a nominal wrapper type:

```swift
public struct Unit {}

extension Unit: Carrier {
    public typealias Underlying = Unit
}
```

And ship it in the SLI target. But then we've invented a new type (`Carrier_Primitives_Standard_Library_Integration.Unit`) that isn't Void, just represents Void-like semantics. Consumers would have to decide between using Void (no Carrier) or Unit (Carrier but not interoperable with functions returning `()`). Adds API surface without resolving the underlying language limitation.

## Outcome

**Status**: DECISION — skipped from 0.1.0 SLI.

**Rationale**: The Swift language doesn't permit `extension Void: Carrier`. A wrapper type would be a new invention, not a stdlib integration. Consumers who genuinely need a Carrier-shaped unit type can declare their own `struct Unit` with a standalone `extension Unit: Carrier { ... }` in their package.

## References

- Swift stdlib `Void` / `()`.
- SE-0283 (Tuple conformances) — explains the limitation.
