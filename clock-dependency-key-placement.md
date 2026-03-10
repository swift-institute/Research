# Clock Dependency Key Placement

<!--
---
version: 1.1.0
last_updated: 2026-03-10
status: RECOMMENDATION
---
-->

## Context

As part of adopting `nonisolated(nonsending)` and clock-parameterized temporal operators in swift-async, we need a `@Dependency(\.clock)` integration that provides:

1. A `Dependency.Key` conformance resolving to a type-erased clock
2. A `Dependency.Values` extension exposing `\.clock`
3. Mode-aware defaults: `ContinuousClock` in production, `Clock.Immediate` in tests/previews

This requires access to both the dependency system (swift-dependencies, L3) and clock types (swift-clock-primitives, L1). The question is where this integration code should live.

## Question

In which package should the clock dependency key (`Dependency.Values.clock`) be defined?

## Current Dependency Graph

```
Layer 1 (Primitives):
  swift-clock-primitives ── Clock.Immediate, Clock.Test, Clock.Any, etc.
  swift-time-primitives  ── Duration, Instant types

Layer 3 (Foundations):
  swift-dependencies ── @Dependency, Dependency.Key, withDependencies
    └─ swift-witnesses (L3)
    └─ swift-environment (L3)

  swift-time ── Composes time + clock primitives
    └─ swift-clock-primitives (L1)
    └─ swift-time-primitives (L1)
    └─ swift-time-standard (L2)

  swift-async ── Temporal operators (delay, interval, timer, etc.)
    └─ swift-async-primitives (L1)
    └─ swift-buffer-primitives (L1)
    └─ swift-reference-primitives (L1)

  Packages depending on swift-clock-primitives:
    swift-async, swift-io, swift-tests, swift-time

  Packages depending on swift-dependencies:
    swift-async, swift-testing, swift-tests
```

## Analysis

### Option A: In swift-dependencies

Add swift-clock-primitives (L1) as a dependency of swift-dependencies (L3). Define the clock key directly in the Dependencies module.

**Advantages**:
- Universal availability: any package importing Dependencies gets `\.clock`
- Follows Pointfree precedent (their swift-dependencies ships clock/date/UUID keys)
- Simple — no new package
- Natural home for "standard dependencies" (clock, date, UUID, locale)

**Disadvantages**:
- Couples swift-dependencies to swift-clock-primitives permanently
- Every consumer of Dependencies transitively pulls in Clock Primitives (and its dependency chain: Kernel Primitives, Synchronization, etc.)
- Blurs the scope of swift-dependencies from "generic DI framework" to "DI framework + standard keys"

**Dependency change**: swift-dependencies gains swift-clock-primitives (L3 → L1, valid)

### Option B: In swift-time

swift-time already depends on swift-clock-primitives. Add swift-dependencies as a dependency.

**Advantages**:
- swift-time is the existing L3 composition layer for time/clock concerns
- No new package needed
- Packages that work with time already depend on swift-time

**Disadvantages**:
- swift-time gains a lateral dependency on swift-dependencies (L3 → L3)
- Packages that need `@Dependency(\.clock)` but don't need the full Time module are forced to import it
- Conflates "time domain modeling" with "dependency injection integration"

**Dependency change**: swift-time gains swift-dependencies (lateral, L3 → L3)

### Option C: In swift-async

Define the key in the Async Stream target where the temporal operators consume it.

**Advantages**:
- Co-located with the primary consumer
- No new packages or dependency changes beyond what's already planned

**Disadvantages**:
- Limits `@Dependency(\.clock)` to packages that depend on swift-async
- swift-io, swift-tests, and any future clock consumers must depend on swift-async to get the key
- Wrong abstraction level — a clock dependency key is not specific to async streams

### Option D: New swift-clocks package (L3)

A focused composition package that bridges clock-primitives with dependencies.

```
swift-clocks (L3, new)
  └─ swift-clock-primitives (L1)
  └─ swift-dependencies (L3, lateral)
```

Provides: `Dependency.Values.clock`, maybe `Clock.Any` convenience initializers, re-exports Clock Primitives.

**Advantages**:
- Single-responsibility: "clock types + dependency integration"
- Mirrors the L1 → L3 composition pattern (clock-primitives → clocks, like time-primitives → time)
- swift-dependencies stays generic, swift-clock-primitives stays L1
- Any L3+ package that needs `@Dependency(\.clock)` depends on swift-clocks
- Can grow to include clock-related utilities beyond just the dependency key

**Disadvantages**:
- New package to create and maintain
- One more dependency for consumers to declare
- Lateral dependency on swift-dependencies (same concern as Option B)

**Dependency change**: New package with one L1 dep + one lateral L3 dep

### Option E: In swift-dependencies, but as a separate target

swift-dependencies adds a `Dependencies Clock` target that depends on Clock Primitives. The main `Dependencies` target remains unchanged.

**Advantages**:
- Clock key available without coupling the core Dependencies module
- Consumers opt in by depending on `Dependencies Clock` instead of `Dependencies`
- Keeps core Dependencies lightweight

**Disadvantages**:
- Still couples the swift-dependencies package to clock-primitives
- Adds target complexity to swift-dependencies
- Unusual pattern — most consumers would need both targets

### Option F: Integration sub-package inside swift-dependencies

swift-dependencies hosts integration sub-packages in an `integration/` directory. Each is an independent Swift package with its own `Package.swift`, similar to `Experiments/` isolation (EXP-002b).

```
swift-dependencies/
├── Package.swift                                    (core: unchanged)
├── Sources/Dependencies/                            (generic DI framework)
└── integration/
    └── swift-clocks-dependency/
        ├── Package.swift                            (deps: clock-primitives + dependencies)
        └── Sources/
            └── Clocks Dependency/
                └── Dependency+Clock.swift            (ClockKey + Dependency.Values.clock)
```

The integration Package.swift:

```swift
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "swift-clocks-dependency",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Clocks Dependency", targets: ["Clocks Dependency"])
    ],
    dependencies: [
        .package(path: "../../../swift-primitives/swift-clock-primitives"),
        .package(path: "../.."),  // swift-dependencies
    ],
    targets: [
        .target(
            name: "Clocks Dependency",
            dependencies: [
                .product(name: "Clock Primitives", package: "swift-clock-primitives"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        )
    ]
)
```

Consumers depend on the sub-package by path:

```swift
// In swift-async/Package.swift
.package(path: "../swift-dependencies/integration/swift-clocks-dependency"),
```

And import:

```swift
import Clocks_Dependency  // provides @Dependency(\.clock)
```

**Advantages**:
- swift-dependencies core stays generic — zero coupling to clock-primitives
- Integration code lives near the DI framework (conceptual ownership)
- No new top-level package — sub-package of swift-dependencies
- Independently buildable (own Package.swift, own dependency graph)
- **Extensible pattern** — future integrations follow the same structure:
  ```
  integration/
  ├── swift-clocks-dependency/     (clock DI)
  ├── swift-time-dependency/       (time DI)
  ├── swift-io-dependency/         (IO DI)
  └── swift-uuid-dependency/       (UUID DI)
  ```
- Parent Package.swift never references integration packages (same isolation as Experiments)
- Clear signal: "optional integration, not core"

**Disadvantages**:
- Nested relative paths (`../../../swift-primitives/...`) can be fragile across environments
- Discoverability: consumers must know integration sub-packages exist
- The integration package references its parent via `../..` — works but unusual for SPM
- Slightly more build graph complexity for consumers

**Dependency change**: None to swift-dependencies itself. New sub-package has L1 dep + parent dep.

### Comparison

| Criterion                        | A: deps | B: time | C: async | D: swift-clocks | E: dep target | F: sub-pkg |
|----------------------------------|:-:|:-:|:-:|:-:|:-:|:-:|
| No new top-level package         | ✓ | ✓ | ✓ |   | ✓ | ✓ |
| No new lateral deps              | ✓ |   | ✓ |   | ✓ | ✓ |
| Universal availability           | ✓ |   |   | ✓ | ✓ | ✓ |
| Dependencies core stays generic  |   | ✓ | ✓ | ✓ |   | ✓ |
| Clock-primitives stays L1        | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Mirrors L1→L3 composition pattern|   |   |   | ✓ |   |   |
| Extensible integration pattern   |   |   |   |   |   | ✓ |
| Consumer simplicity              | ✓ |   |   |   |   |   |
| Appropriate abstraction level    | ✓ |   |   | ✓ |   | ✓ |
| Co-located with DI framework     | ✓ |   |   |   | ✓ | ✓ |

## Constraints

- swift-clock-primitives (L1) cannot depend on swift-dependencies (L3) — eliminates defining the key at L1
- Lateral L3 dependencies are allowed per user directive (precedent set for swift-async → swift-dependencies)
- The key's `Value` type must be type-erased (`Clock.Any<Duration>`) because `any Clock<Duration>` can't call `sleep(until:)` due to associated type erasure

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option F (integration sub-package) is the strongest candidate.

Option F uniquely satisfies the most criteria: the dependencies core stays generic, no new top-level package, universally available to any consumer, co-located with the DI framework, and — critically — establishes a reusable pattern for all future dependency integrations (time, UUID, IO, etc.). The `integration/` directory mirrors the existing `Experiments/` isolation pattern (EXP-002b).

**Runner-up**: Option D (standalone swift-clocks) is architecturally equivalent but requires a new top-level package. Option A (in swift-dependencies core) is the most pragmatic but permanently couples the generic DI framework to clock types.

**Key trade-off**: Option F adds path-depth complexity (`../swift-dependencies/integration/swift-clocks-dependency`) in exchange for clean separation and extensibility. If path resolution proves fragile across environments, fall back to Option D.
