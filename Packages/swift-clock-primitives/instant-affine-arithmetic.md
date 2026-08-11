# Instant Affine Arithmetic

<!--
---
version: 3.0.0
last_updated: 2026-03-01
status: DECISION
tier: 2
---
-->

## Context

`Clock.Continuous.Instant` and `Clock.Suspending.Instant` conform to `InstantProtocol`,
which requires `advanced(by:)` and `duration(to:)`. The stdlib **intended** to provide
default operator implementations (`+`, `+=`, `-`, `-=`, `- (Instant, Instant)`) via
protocol extension on `InstantProtocol`, but disabled them:

```swift
// stdlib/public/core/Instant.swift
/*
disabled for now - this perturbs operator resolution
extension InstantProtocol {
  public static func + (_ lhs: Self, _ rhs: Duration) -> Self { ... }
  ...
}
*/
```

The stdlib works around this by manually defining all 5 operators on each concrete type
(`ContinuousClock.Instant`, `SuspendingClock.Instant`). Our types had an explicit `- (Instant, Instant)`
but were missing `+`, `+=`, `-` (instant minus duration), and `-=`.

This surfaced as a build error: `Clock.Continuous.now + duration` failed to compile in swift-async.

### Trigger

Build failure in `swift-async` where `Clock.Continuous.now + duration` has no matching operator.
Before adding ad-hoc operator definitions, we need to determine the principled approach given
existing affine infrastructure (`Ordinal.Protocol`, `Affine.Discrete.Vector.Protocol`, Tagged).

## Question

How should affine arithmetic operators be structured for clock instant types, considering:

1. The existing `Ordinal.Protocol` / `Affine.Discrete.Vector.Protocol` / Tagged infrastructure
2. Six `InstantProtocol` conformers across two storage representations
3. `Time.Instant` (separate package, different storage, already has operators)
4. The stdlib's disabled default operators and the "perturbs operator resolution" issue
5. Willingness to accept breaking refactors

## Inventory

### Current `InstantProtocol` Conformers

| Type | Storage | Package | Has `+` | Has `-` |
|------|---------|---------|---------|---------|
| `Clock.Continuous.Instant` | `nanoseconds: UInt64` | clock-primitives | **No** | Yes |
| `Clock.Suspending.Instant` | `nanoseconds: UInt64` | clock-primitives | **No** | Yes |
| `Clock.Test.Instant` | `offset: Duration` | clock-primitives | No | No |
| `Clock.Immediate.Instant` | `offset: Duration` | clock-primitives | No | No |
| `Clock.Unimplemented.Instant` | `offset: Duration` | clock-primitives | No | No |
| `Time.Instant` | `seconds: Int64 + nanos: Int32` | time-primitives | Yes | Yes |

Two storage groups in clock-primitives:
- **Nanoseconds group** (Continuous, Suspending): `UInt64` nanoseconds since boot
- **Offset group** (Test, Immediate, Unimplemented): `Duration` offset from zero

### Required Operators (SE-0329 Affine Set)

| Operator | Signature | Affine Semantics |
|----------|-----------|------------------|
| `+` | `(Instant, Duration) -> Instant` | point + vector -> point |
| `+` | `(Duration, Instant) -> Instant` | vector + point -> point |
| `+=` | `(inout Instant, Duration)` | translate in place |
| `-` | `(Instant, Duration) -> Instant` | point - vector -> point |
| `-=` | `(inout Instant, Duration)` | retreat in place |
| `-` | `(Instant, Instant) -> Duration` | point - point -> vector |

### Existing Affine Infrastructure

The ecosystem already solves this problem for discrete positions:

```
Ordinal.Protocol  ←→  Cardinal.Protocol / Affine.Discrete.Vector.Protocol
   (position)              (count / displacement)
```

- Operators defined once on protocols, apply to both bare and `Tagged<T, _>` types
- `Tagged<T, Ordinal>` = `Index<T>` (phantom-typed position)
- `Tagged<T, Affine.Discrete.Vector>` = `Index<T>.Offset` (phantom-typed displacement)
- Single operator definition handles all phantom-tagged variants

### Principled Absences [INFRA-200]

The affine infrastructure has deliberate absences:
- No `Cardinal - Cardinal` via `-` (subtraction isn't total on naturals)
- No `index * 2` (positions aren't scalable)
- No bare scalar operators on typed quantities

Clock instants should respect the same discipline: `Instant + Instant` must never compile.

## Analysis

### Option A: Manual Operators Per Type

Add all 6 operators directly to each of the 5 clock instant types.

```swift
// Repeated 5 times with identical implementations
extension Clock.Continuous.Instant {
    public static func + (lhs: Self, rhs: Duration) -> Self { lhs.advanced(by: rhs) }
    public static func + (lhs: Duration, rhs: Self) -> Self { rhs.advanced(by: lhs) }
    public static func += (lhs: inout Self, rhs: Duration) { lhs = lhs.advanced(by: rhs) }
    public static func - (lhs: Self, rhs: Duration) -> Self { lhs.advanced(by: .zero - rhs) }
    public static func -= (lhs: inout Self, rhs: Duration) { lhs = lhs - rhs }
    // - (Instant, Instant) already exists
}
```

| Criterion | Assessment |
|-----------|------------|
| Boilerplate | **Bad** — 30 operator definitions across 5 types (6 per type) |
| Correctness | Good — each type gets exact right semantics |
| Consistency with ecosystem | **Bad** — doesn't use protocol-based lifting |
| Breaking change | None |
| Risk | Low |

### Option B: Protocol Extension on `InstantProtocol`

Define operators as extension on `InstantProtocol where Duration == Swift.Duration`.

```swift
extension InstantProtocol where Duration == Swift.Duration {
    public static func + (lhs: Self, rhs: Duration) -> Self { lhs.advanced(by: rhs) }
    // ...
}
```

| Criterion | Assessment |
|-----------|------------|
| Boilerplate | **Best** — single definition covers all types |
| Correctness | Good |
| Consistency with ecosystem | Neutral — doesn't use Tagged/protocol pattern |
| Breaking change | Minor — remove existing concrete operators |
| Risk | **High** — stdlib explicitly disabled this ("perturbs operator resolution") |

The stdlib disabled this because concrete operator definitions on `ContinuousClock.Instant`
ambiguate with the protocol extension. Even removing our concrete operators, the stdlib's own
`ContinuousClock.Instant` operators could conflict via `_Concurrency` import. **Rejected.**

### Option C: Own Protocol with Operator Synthesis

Define `Clock.Instant.Protocol` (distinct from stdlib's `InstantProtocol`) with operators.

```swift
extension Clock {
    /// Protocol for clock instant types that provides affine arithmetic.
    ///
    /// Mirrors the ecosystem's `Ordinal.Protocol` pattern: define core operations
    /// once, all conformers get operators via protocol extension.
    public protocol Instant: InstantProtocol where Duration == Swift.Duration {}
}

extension Clock.Instant {
    public static func + (lhs: Self, rhs: Swift.Duration) -> Self {
        lhs.advanced(by: rhs)
    }
    public static func + (lhs: Swift.Duration, rhs: Self) -> Self {
        rhs.advanced(by: lhs)
    }
    public static func += (lhs: inout Self, rhs: Swift.Duration) {
        lhs = lhs.advanced(by: rhs)
    }
    public static func - (lhs: Self, rhs: Swift.Duration) -> Self {
        lhs.advanced(by: .zero - rhs)
    }
    public static func -= (lhs: inout Self, rhs: Swift.Duration) {
        lhs = lhs - rhs
    }
    public static func - (lhs: Self, rhs: Self) -> Swift.Duration {
        rhs.duration(to: lhs)
    }
}
```

All 5 clock instant types conform with a one-liner. No operator duplication.

| Criterion | Assessment |
|-----------|------------|
| Boilerplate | **Good** — 6 operators defined once, 5 one-line conformances |
| Correctness | Good — delegates to each type's `advanced(by:)` |
| Consistency with ecosystem | **Good** — mirrors `Ordinal.Protocol` pattern |
| Breaking change | Minor — add conformance, remove duplicate concrete operators |
| Risk | Low — no stdlib protocol involved, operators on our own protocol |

**Concern**: The existing `-` on `Clock.Continuous.Instant` and `Clock.Suspending.Instant`
would need to be removed (otherwise ambiguous with protocol extension). This is fine —
the protocol extension's implementation is identical.

**Concern**: `Time.Instant` (in time-primitives) has custom `+`/`-` with complex normalization.
Since `Time.Instant.advanced(by:)` delegates to `+`, and our protocol `+` delegates to
`advanced(by:)`, there'd be infinite recursion. **Solution**: `Time.Instant` would need to
invert — make `advanced(by:)` primary, `+` secondary. Or `Time.Instant` doesn't conform
(it's not a "clock instant" — it's an absolute timeline point).

### Option D: Tagged-Based Instant Types

Model clock instants as `Tagged<ClockType, BaseStorage>`, mirroring `Index<T> = Tagged<T, Ordinal>`.

**Critical finding from experiment**: Swift forbids two conditional conformances of the same
protocol on the same generic type, even with mutually exclusive conditions. The naive approach —

```swift
// ❌ DOES NOT COMPILE — conflicting conformances
extension Tagged: InstantProtocol where RawValue == Clock.Nanoseconds { ... }
extension Tagged: InstantProtocol where RawValue == Clock.Offset { ... }
```

— fails with: `conflicting conformance of 'Tagged<Tag, RawValue>' to protocol 'InstantProtocol';
there cannot be more than one conformance, even with different conditional bounds`.

**Solution**: The base types conform directly to `InstantProtocol`. A single conditional
conformance on Tagged uses `InstantProtocol` itself as the constraint — no custom protocol needed:

```swift
extension Clock {
    /// Nanosecond-resolution point in time.
    /// Used by Continuous and Suspending clocks.
    public struct Nanoseconds: InstantProtocol, Sendable, Hashable, Comparable {
        public typealias Duration = Swift.Duration
        public let rawValue: UInt64
        public init(_ rawValue: UInt64) { self.rawValue = rawValue }
        public func advanced(by duration: Swift.Duration) -> Self { ... }
        public func duration(to other: Self) -> Swift.Duration { ... }
    }

    /// Duration-offset point in time (for test/mock clocks).
    /// Used by Test, Immediate, and Unimplemented clocks.
    public struct Offset: InstantProtocol, Sendable, Hashable, Comparable {
        public typealias Duration = Swift.Duration
        public let rawValue: Swift.Duration
        public init(_ rawValue: Swift.Duration = .zero) { self.rawValue = rawValue }
        public func advanced(by duration: Swift.Duration) -> Self { ... }
        public func duration(to other: Self) -> Swift.Duration { ... }
    }
}
```

Typealiases preserve API:

```swift
extension Clock.Continuous {
    public typealias Instant = Tagged<Clock.Continuous, Clock.Nanoseconds>
}
extension Clock.Suspending {
    public typealias Instant = Tagged<Clock.Suspending, Clock.Nanoseconds>
}
extension Clock.Test {
    public typealias Instant = Tagged<Clock.Test, Clock.Offset>
}
// etc.
```

Single `InstantProtocol` conformance — `InstantProtocol` itself is the constraint:

```swift
// ✅ ONE conformance — covers ALL Tagged types wrapping any InstantProtocol conformer
extension Tagged: InstantProtocol where RawValue: InstantProtocol {
    public typealias Duration = RawValue.Duration

    public func advanced(by duration: RawValue.Duration) -> Self {
        Self(__unchecked: (), rawValue.advanced(by: duration))
    }

    public func duration(to other: Self) -> RawValue.Duration {
        rawValue.duration(to: other.rawValue)
    }
}
```

Single set of operators, constrained to `Swift.Duration`:

```swift
extension Tagged where RawValue: InstantProtocol, RawValue.Duration == Swift.Duration {
    public static func + (lhs: Self, rhs: Swift.Duration) -> Self { ... }
    public static func + (lhs: Swift.Duration, rhs: Self) -> Self { ... }
    public static func += (lhs: inout Self, rhs: Swift.Duration) { ... }
    public static func - (lhs: Self, rhs: Swift.Duration) -> Self { ... }
    public static func -= (lhs: inout Self, rhs: Swift.Duration) { ... }
    public static func - (lhs: Self, rhs: Self) -> Swift.Duration { ... }
}
```

Convenience accessors preserve existing API:

```swift
extension Tagged where RawValue == Clock.Nanoseconds {
    public var nanoseconds: UInt64 { rawValue.rawValue }
    public init(nanoseconds: UInt64) { self.init(__unchecked: (), Clock.Nanoseconds(nanoseconds)) }
}

extension Tagged where RawValue == Clock.Offset {
    public var offset: Swift.Duration { rawValue.rawValue }
    public init(offset: Swift.Duration = .zero) { self.init(__unchecked: (), Clock.Offset(offset)) }
}
```

| Criterion | Assessment |
|-----------|------------|
| Boilerplate | **Best** — 6 operators + 1 InstantProtocol conformance, all via single protocol constraint |
| Correctness | Good — delegates to each base type's implementation |
| Consistency with ecosystem | **Best** — directly mirrors `Index<T> = Tagged<T, Ordinal>` pattern |
| New concepts | **None** — uses stdlib's `InstantProtocol` directly |
| Breaking change | **Large** — all `Clock.*.Instant` become typealiases, init patterns change |
| Risk | Low — **empirically verified** across 3 experiment iterations (see Experiment Results) |
| Type safety | **Best** — `Clock.Continuous.Instant` and `Clock.Suspending.Instant` are incompatible at compile time via phantom tag (by construction, not coincidence) |

### Option E: Hybrid — Protocol (C) Now, Tagged (D) Later

Adopt Option C immediately (protocol-based operator synthesis), with Option D as a
future refactor when the ecosystem is ready for the larger breaking change.

This gives us:
- **Now**: Zero boilerplate, principled pattern, no breaking changes to init/property access
- **Later**: Full Tagged integration when clock-primitives is ready for a major version bump

| Criterion | Assessment |
|-----------|------------|
| Boilerplate | Good (same as C) |
| Correctness | Good |
| Breaking change | Minimal now, large later |
| Risk | Low now |

## Comparison

| Criterion | A: Manual | B: InstantProtocol ext | C: Own Protocol | D: Tagged | E: Hybrid |
|-----------|-----------|----------------------|-----------------|-----------|-----------|-
| Boilerplate | Bad (30 defs) | Best (6 defs) | Good (6+5) | **Best** (6+1) | Good (6+5) |
| Ecosystem consistency | Bad | Neutral | Good | **Best** | Good→Best |
| New concepts | None | None | Clock.Instant protocol | **None** | Clock.Instant→None |
| Breaking change | None | Minor | Minor | Large | Minor→Large |
| Risk | Low | **High** | Low | **Low** (verified ×3) | Low |
| Type safety gain | None | None | None | **Best** | None→Best |
| Stdlib compatibility | N/A | **Rejected** | Good | Good | Good |

## Constraints

1. **Stdlib bug**: `InstantProtocol` default operators are disabled. We cannot extend `InstantProtocol` directly.
2. **MemberImportVisibility**: Operators must be importable where they're needed.
3. **`Time.Instant` independence**: time-primitives has its own complex arithmetic. It should not be forced into clock-primitives' pattern.
4. **`_Concurrency.Clock` conformance**: `Clock.Continuous` and `Clock.Suspending` conform to `_Concurrency.Clock` in swift-iso-9945. The `Instant` associated type must satisfy that protocol's requirements.
5. **`let` storage**: `Clock.Continuous.Instant.nanoseconds` is `let`. `+=` and `-=` require replacing `self`, which works for value types.
6. **Conflicting conditional conformances**: Swift does not allow two conditional conformances of the same protocol on the same generic type, even with mutually exclusive conditions. This rules out per-concrete-type `InstantProtocol` conformances on `Tagged`.

## Experiment Results

**Experiment**: `Experiments/tagged-instant/`

### Attempt 1: Per-Type Conformances (REFUTED)

The naive approach — two `extension Tagged: InstantProtocol where RawValue == X` conformances —
fails at compile time:

```
error: conflicting conformance of 'Tagged<Tag, RawValue>' to protocol 'InstantProtocol';
there cannot be more than one conformance, even with different conditional bounds
```

This is a fundamental Swift language limitation, not a bug. It rules out per-concrete-type
conditional conformances on `Tagged`.

### Attempt 2: Custom Protocol Constraint (CONFIRMED)

Introduced `Clock.Tick` as a custom protocol. Both base types conform. A single
`extension Tagged: InstantProtocol where RawValue: Clock.Tick` covers all types.

All 7 variants passed. However, `Clock.Tick` duplicates exactly what `InstantProtocol`
already requires (`advanced(by:)` and `duration(to:)`), prompting the question:
why not use `InstantProtocol` directly?

### Attempt 3: InstantProtocol as Constraint (CONFIRMED — Final)

Eliminated the custom `Clock.Tick` protocol entirely. Base types conform directly to
`InstantProtocol`. The Tagged conformance uses `InstantProtocol` itself as the constraint:

```swift
extension Tagged: InstantProtocol where RawValue: InstantProtocol {
    public typealias Duration = RawValue.Duration
    // ...
}
```

Operators constrained to `Swift.Duration` for clock types:

```swift
extension Tagged where RawValue: InstantProtocol, RawValue.Duration == Swift.Duration {
    // all 6 operators
}
```

**All 7 variants CONFIRMED** — Build Succeeded, correct runtime output:

| Variant | Hypothesis | Result |
|---------|-----------|--------|
| V1 | `extension Tagged: InstantProtocol where RawValue: InstantProtocol` compiles | **CONFIRMED** |
| V2 | One set of 6 operators via `InstantProtocol` constraint | **CONFIRMED** |
| V3 | `_Concurrency.Clock` works with `typealias Instant = Tagged<Self, Clock.Nanoseconds>` | **CONFIRMED** |
| V4 | Convenience inits (`init(nanoseconds:)`, `init(offset:)`) preserve existing API | **CONFIRMED** |
| V5 | Phantom tags prevent mixing `Continuous.Instant` and `Suspending.Instant` | **CONFIRMED** |
| V6 | `clock.now + .seconds(30)` compiles (the original bug) | **CONFIRMED** |
| V7 | All 5 production clock types work as Tagged typealiases | **CONFIRMED** |

### Key Design

```
InstantProtocol (stdlib)
├── Clock.Nanoseconds (struct: UInt64)  ← Continuous, Suspending
└── Clock.Offset (struct: Duration)     ← Test, Immediate, Unimplemented

extension Tagged: InstantProtocol where RawValue: InstantProtocol  ← ONE conformance
extension Tagged where RawValue: InstantProtocol, RawValue.Duration == Swift.Duration  ← ONE operator set

Clock.Continuous.Instant    = Tagged<Clock.Continuous, Clock.Nanoseconds>
Clock.Suspending.Instant    = Tagged<Clock.Suspending, Clock.Nanoseconds>
Clock.Test.Instant          = Tagged<Clock.Test, Clock.Offset>
Clock.Immediate.Instant     = Tagged<Clock.Immediate, Clock.Offset>
Clock.Unimplemented.Instant = Tagged<Clock.Unimplemented, Clock.Offset>
```

No custom protocol introduced. `InstantProtocol` already defines exactly the right
requirements. The `Duration == Swift.Duration` constraint on the operator extension ensures
operators use concrete `Swift.Duration` rather than the associated type.

## Decision

**Option D: Tagged-Based Instant Types** using `InstantProtocol` itself as the constraint.

No custom protocol needed. The base types (`Clock.Nanoseconds`, `Clock.Offset`) conform
directly to `InstantProtocol`. Tagged lifts this conformance via a single conditional
conformance constrained on `InstantProtocol`.

### Rationale

1. **Empirically verified** — three experiment iterations confirm all aspects compile and run correctly.
2. **Best ecosystem consistency** — directly mirrors the `Index<T> = Tagged<T, Ordinal>` pattern.
3. **Best boilerplate reduction** — 6 operators + 1 InstantProtocol conformance defined once
   via protocol constraint, covering all 5 clock instant types.
4. **Best type safety** — phantom tags make `Continuous.Instant` and `Suspending.Instant`
   incompatible at compile time by construction, not coincidence.
5. **No new concepts** — uses `InstantProtocol` (stdlib) directly instead of introducing a
   custom `Clock.Tick` protocol. The base types are just `InstantProtocol` conformers.
6. **API-compatible** — convenience inits and computed properties preserve the existing API surface.
7. **`_Concurrency.Clock` integration** works with Tagged Instant typealiases.
8. **Option B is rejected** due to the stdlib's known operator resolution issue.
9. **Option E (hybrid) is unnecessary** — the experiment proves Option D is safe to implement
   directly, eliminating the need for an intermediate step.

### Implementation Path

1. **Add dependency**: clock-primitives depends on identity-primitives (Tagged)
2. **New file**: `Clock.Nanoseconds.swift` — `Clock.Nanoseconds: InstantProtocol` (UInt64 storage)
3. **New file**: `Clock.Offset.swift` — `Clock.Offset: InstantProtocol` (Duration storage)
4. **New file**: `Tagged+InstantProtocol.swift` — single `extension Tagged: InstantProtocol where RawValue: InstantProtocol`
5. **New file**: `Tagged+InstantProtocol+operators.swift` — all 6 operators via `extension Tagged where RawValue: InstantProtocol, RawValue.Duration == Swift.Duration`
6. **New file**: `Tagged+Clock.Nanoseconds.swift` — convenience init/property (`init(nanoseconds:)`, `.nanoseconds`)
7. **New file**: `Tagged+Clock.Offset.swift` — convenience init/property (`init(offset:)`, `.offset`)
8. **Modify**: `Clock.Continuous.swift` — replace `struct Instant` with `typealias Instant = Tagged<Continuous, Clock.Nanoseconds>`
9. **Modify**: `Clock.Suspending.swift` — same replacement
10. **Modify**: `Clock.Test.swift` — replace with `typealias Instant = Tagged<Test, Clock.Offset>`
11. **Modify**: `Clock.Immediate.swift` — same replacement
12. **Modify**: `Clock.Unimplemented.swift` — same replacement
13. **Modify**: `Clock.Any.swift` — update to use new Instant types (if needed)
14. **Remove**: ad-hoc `+` operators added to Continuous and Suspending
15. `Time.Instant` does NOT participate — it's a calendar-system instant, not a clock instant

### Migration Notes

| Current API | New API | Source compatible? |
|---|---|---|
| `Clock.Continuous.Instant(nanoseconds: 42)` | Same (via convenience init) | Yes |
| `instant.nanoseconds` | Same (via convenience property) | Yes |
| `Clock.Test.Instant(offset: .zero)` | Same (via convenience init) | Yes |
| `instant.offset` | Same (via convenience property) | Yes |
| `Clock.Test.Instant()` | Same (via default parameter) | Yes |
| `instant + .seconds(30)` | Same (now works everywhere) | Yes |
| `instant - other` | Same (now works everywhere) | Yes |

The breaking change is at the **type identity** level: `Clock.Continuous.Instant` changes from
a concrete struct to `Tagged<Clock.Continuous, Clock.Nanoseconds>`. Code that pattern-matches
or uses metatype identity will break. Functional usage (inits, properties, operators) is preserved.

## References

- [SE-0329: Clock, Instant, and Duration](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0329-clock-instant-duration.md) — designed the operators as defaults, disabled due to compiler bug
- [stdlib/public/core/Instant.swift](https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Instant.swift) — disabled default operators
- [stdlib/public/Concurrency/ContinuousClock.swift](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/ContinuousClock.swift) — manual operator pattern
- `swift-affine-primitives` — existing affine infrastructure (`Ordinal.Protocol`, `Affine.Discrete.Vector.Protocol`)
- `swift-tagged-primitives` — `Tagged<Tag, RawValue>` phantom type wrapper
- [INFRA-200] — principled absences (no `Instant + Instant`)
- `swift-institute/Research/clock-static-now-convenience.md` — related clock API research
- `swift-clock-primitives/Experiments/tagged-instant/` — empirical verification (CONFIRMED)
