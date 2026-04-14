# Cross-Package Integration Strategies

<!--
---
version: 2.0.0
last_updated: 2026-02-27
status: DECISION
research_tier: 3
applies_to: [institute, primitives, standards, foundations]
normative: false
---
-->

## Context

Two distinct modularization problems recur across the Swift Institute ecosystem:

1. **Intra-package dependency isolation** — A single package mixes core infrastructure with applied conformances that pull in additional external dependencies. Downstream consumers that only need the core types are forced to resolve the full dependency graph.

2. **Cross-package optional integration** — Two packages from different dependency trees want to interoperate but neither should depend on the other. A bridge module needs both, but where does it live?

Problem 1 is well-understood and already codified in [MOD-001] through [MOD-013] (intra-package modularization patterns). The solution is Core extraction: split a target into Core + umbrella within the same `Package.swift`.

Problem 2 is unresolved. We have encountered it in two concrete cases and tried different approaches with different failure modes:

| Case | Packages | Attempted Strategy | Result |
|------|----------|-------------------|--------|
| Finite × Collection | `finite-primitives` + `collection-primitives` | Separate integration package (analysis only) | NOT_PURSUED — CaseIterable constraint makes separation impractical |
| Dependencies × Clock | `swift-dependencies` + `swift-clock-primitives` | Nested Package.swift | Works locally; **fails at publication** |

Additionally, the just-completed `finite-primitives` Core extraction demonstrates Problem 1 in action: 10 of 11 downstream consumers only needed Core types, yet all 11 were forced to resolve Algebra, Comparison, and Optic primitives.

### Trigger

[RES-001] Design decision arising from `swift-dependencies/integration/swift-clocks-dependency/` — a nested `Package.swift` that works in development but cannot be published per [spm-nested-package-publication.md].

### Scope

Ecosystem-wide per [RES-002a]. The chosen pattern will be applied to every future cross-package integration across all three layers.

### Tier Justification

Tier 3 because:
- Establishes normative precedent for all future integration decisions
- Affects packages across all three layers (primitives, standards, foundations)
- Cost of error is very high — wrong pattern cascades to every integration point
- Expected lifetime is "timeless infrastructure"

---

## Question

**Primary**: What is the principled strategy for providing optional integration between packages from different dependency trees, given SPM's constraints on nested packages and dependency resolution?

**Secondary**: How do the two problems (intra-package isolation vs cross-package integration) relate, and when does each solution apply?

---

## Prior Art Survey [RES-021]

### Internal Prior Art

| Document | Key Finding | Relevance |
|----------|-------------|-----------|
| [spm-nested-package-publication.md](spm-nested-package-publication.md) | Nested `Package.swift` rejected — SPM hard limitation | Eliminates nested packages as a publication strategy |
| [dual-mode-package-publication.md](dual-mode-package-publication.md) | Release branch with publish tool for `path:` → `url:` transformation | Informs how integration packages would be published |
| [intra-package-modularization-patterns.md](https://github.com/swift-primitives/Research/blob/main/intra-package-modularization-patterns.md) | 13 patterns for targets within a single Package.swift | Codifies the intra-package solution (Problem 1) |
| [finite-collection-join-point-integration.md](https://github.com/swift-primitives/Research/blob/main/finite-collection-join-point-integration.md) | Recommended separate integration package; NOT_PURSUED due to CaseIterable | Shows cross-package integration can be impractical when protocol constraints couple the packages |

### Swift Evolution Proposals

| Proposal | Year | Relevance |
|----------|------|-----------|
| SE-0226: Target-Based Dependency Resolution | 2018 (Swift 5.2) | SPM resolves only dependencies needed by the targets being built. Enables intra-package integration targets that don't pollute consumers who don't use them. |
| SE-0386: `package` access modifier | 2023 (Swift 5.9) | Enables cross-target sharing without `public` exposure |
| SE-0450: Package Traits | 2024 (Swift 6.1) | Traits can gate entire package-level dependencies behind consumer opt-in flags |
| Multi-Package Repos pitch | 2020 (dormant) | Would allow multiple Package.swift per repo — not available, no active champion |

### Industry Patterns

| Project | Integration Strategy | Scale |
|---------|---------------------|-------|
| **swift-nio** | Narrow waist (`NIOCore`) + satellite repos (`swift-nio-ssl`, `swift-nio-http2`, `swift-nio-extras`) | 6 repos, 12+ products |
| **Hummingbird** | Core repo + 22 satellite repos for optional integrations | 22+ repos |
| **Vapor** | Monolithic core + ecosystem repos (`vapor/fluent`, `vapor/leaf`) | 10+ repos |
| **swift-collections** | Single Package.swift, 11 products, selective import | 1 repo |
| **Firebase** | Single Package.swift, 31 products, SE-0226 target-based resolution | 1 repo |
| **TCA** | Monolithic single product | 1 repo |

**Two dominant patterns emerge**:

1. **Satellite repos** (NIO, Hummingbird, Vapor): Core package vends foundational abstractions. Optional integrations live in separate repos that depend on core + the external package. Each satellite is independently versioned and published.

2. **Multi-product single repo** (swift-collections, Firebase): All products in one Package.swift. SE-0226 ensures consumers only resolve dependencies for the products they use. Firebase has 31 products with varied dependencies — consumers importing `FirebaseAuth` don't resolve `FirebaseFirestore`'s dependencies.

A third pattern is emerging:

3. **Trait-gated dependencies** (SE-0450, Swift 6.1+): Package dependencies declared conditionally on traits. Consumer enables a trait to opt into the integration. No separate repo needed.

### Cross-Ecosystem Comparison

| Ecosystem | Integration Mechanism | Example |
|-----------|----------------------|---------|
| **Rust** | Feature flags (cargo features) | `tokio = { features = ["full"] }` — optional deps gated by features |
| **pnpm/npm** | Peer dependencies | `"peerDependencies": { "react": "^18" }` — consumer provides the dep |
| **Go** | Separate modules in same repo | `golang.org/x/crypto` vs `golang.org/x/crypto/ssh` — different import paths, same repo |
| **Haskell** | Cabal flags | `flag with-examples` gates optional dependencies |

**Key insight**: Rust's cargo features and Haskell's cabal flags are direct analogues of SE-0450 Package Traits. They are the dominant pattern in ecosystems with optional integration needs.

---

## Taxonomy: Two Distinct Problems

Before evaluating strategies, we must clearly distinguish the two problems because they have different solutions.

### Problem 1: Intra-Package Dependency Isolation

**Shape**: One package, two concerns, different dependency sets.

```
Package P
├── Core types (deps: A, B)
└── Applied conformances (deps: A, B, C, D, E)
```

**Solved by**: Core extraction ([MOD-001]). Split into `P Core` (deps: A, B) and `P` (deps: P Core, C, D, E) within the same `Package.swift`.

**Example**: `finite-primitives` — Core needs {Ordinal, Identity, Index, Sequence}; umbrella adds {Algebra, Algebra Group, Comparison, Optic}.

**Characteristics**:
- Both concerns are in the same semantic domain
- Core types are defined here, conformances are applied here
- No cross-package ownership question — it's all one package
- Works today with zero SPM limitations

### Problem 2: Cross-Package Optional Integration

**Shape**: Two packages from different dependency trees, a bridge module needs both.

```
Package X (tree 1)      Package Y (tree 2)
       ↑                        ↑
       └── Integration Z ───────┘
```

**Not solved by**: Core extraction (the types live in different packages).

**Example**: `swift-dependencies` × `swift-clock-primitives` → `Clocks Dependency` bridge.

**Characteristics**:
- The two packages are in different semantic domains
- Neither should depend on the other (no natural dependency direction)
- The bridge module defines new code (key implementations, value extensions) that references types from both
- Publication feasibility is a critical constraint

### When Each Applies

| Signal | Problem | Solution |
|--------|---------|----------|
| Package has targets with different external dep sets | 1 (isolation) | Core extraction |
| Package conformances pull in deps that many consumers don't need | 1 (isolation) | Core extraction |
| Two packages need to interoperate but have no dependency relationship | 2 (integration) | See analysis below |
| A framework wants to provide optional adapters for external types | 2 (integration) | See analysis below |

---

## Analysis: Cross-Package Integration Strategies

### Strategy A: Nested Package (Current swift-clocks-dependency approach)

**Description**: Integration package lives as a nested `Package.swift` inside one of the two packages' directory tree.

```
swift-dependencies/
├── Package.swift
├── Sources/Dependencies/
└── integration/
    └── swift-clocks-dependency/
        ├── Package.swift         ← nested
        └── Sources/Clocks Dependency/
```

**Publication feasibility**: **None.** Confirmed by [spm-nested-package-publication.md]: SPM rejects `path:` dependencies in versioned packages. The nested package cannot declare `path: "../.."` to reach its parent when consumed via git URL.

| Criterion | Assessment |
|-----------|-----------|
| Local development | Works — `path:` deps resolve correctly |
| Publication | **Fails** — hard SPM limitation |
| Consumer experience | N/A — consumers cannot use it |
| Repo proliferation | None |
| Discovery | Good — lives next to the code it integrates with |

**Verdict**: Useful as a development prototype only. Cannot be the publication strategy.

---

### Strategy B: Standalone Integration Repo

**Description**: Each integration gets its own git repo, its own `Package.swift`, and its own version.

```
swift-foundations/
├── swift-dependencies/              → Dependencies framework
└── swift-clocks-dependency/         → Integration: Dependencies × Clock (NEW REPO)
```

**Publication feasibility**: **Full.** Standard SPM package with URL dependencies.

| Criterion | Assessment |
|-----------|-----------|
| Local development | Works — `path:` deps in development, `url:` when published |
| Publication | Full — standard SPM package |
| Consumer experience | Clean — `import Clocks_Dependency` |
| Repo proliferation | **1 new repo per integration** |
| Discovery | Poor — integration scattered across repos |
| Version coordination | Must track two upstream packages' versions |

**Applied to the ecosystem**: If `swift-dependencies` needs integrations for Clock, Logging, URLSession, Networking, FileSystem, Database — that's 6 new repos. Each with its own versioning, CI, README.

**NIO precedent**: This is NIO's pattern. `swift-nio-ssl`, `swift-nio-http2`, `swift-nio-extras` are satellite repos. It works at NIO's scale (~6 satellites). It becomes unwieldy at higher integration counts.

**Hummingbird precedent**: Hummingbird has 22 satellite repos. The pattern scales but creates significant maintenance overhead.

---

### Strategy C: Intra-Package Integration Target (SE-0226)

**Description**: Integration target lives inside one of the two packages (the "hub" package) as an additional product. SE-0226 target-based dependency resolution ensures consumers who don't use the integration product don't resolve its additional dependencies.

```swift
// swift-dependencies/Package.swift
products: [
    .library(name: "Dependencies", targets: ["Dependencies"]),
    .library(name: "Clocks Dependency", targets: ["Clocks Dependency"]),
],
dependencies: [
    .package(path: "../swift-witnesses"),
    .package(path: "../swift-environment"),
    .package(path: "../../swift-primitives/swift-clock-primitives"),  // NEW
],
targets: [
    .target(name: "Dependencies", dependencies: [
        .product(name: "Witnesses", package: "swift-witnesses"),
        .product(name: "Environment", package: "swift-environment"),
    ]),
    .target(name: "Clocks Dependency", dependencies: [
        "Dependencies",
        .product(name: "Clock Primitives", package: "swift-clock-primitives"),
    ]),
]
```

**Publication feasibility**: **Full** — standard single Package.swift with multiple products. The publish tool's `path:` → `url:` transformation handles all dependencies identically.

**SE-0226 dependency isolation**: When a consumer depends on `Dependencies` (product), SPM resolves only `swift-witnesses` and `swift-environment`. `swift-clock-primitives` is only resolved when a consumer depends on `Clocks Dependency` (product).

**Caveat**: SE-0226's behavior must be validated empirically for this specific case. The proposal's exact guarantees are:
> "When a package dependency is only used in test targets, it is not resolved for consumers of the package."

Whether this extends to "only used in a product that the consumer didn't request" depends on the resolution implementation. This needs experimental verification.

| Criterion | Assessment |
|-----------|-----------|
| Local development | Works — same as today |
| Publication | Full — single Package.swift, publish tool handles it |
| Consumer experience | Clean — consumer chooses which product to depend on |
| Repo proliferation | **None** |
| Discovery | **Excellent** — all integrations visible in one Package.swift |
| Version coordination | Automatic — integration ships with the hub package |
| Hub package dependency list | Grows with each integration (package-level `dependencies:` array) |

**Applied to the ecosystem**: All clock/logging/networking integrations live as targets in `swift-dependencies`. One Package.swift, one repo, one version.

---

### Strategy D: Trait-Gated Integration Target (SE-0450)

**Description**: Like Strategy C, but the integration dependency is gated behind a Package Trait. The consumer must explicitly enable the trait to opt into the integration.

```swift
// swift-dependencies/Package.swift
let package = Package(
    name: "swift-dependencies",
    traits: [
        .trait(name: "ClockIntegration"),
        .trait(name: "LoggingIntegration"),
    ],
    dependencies: [
        .package(path: "../swift-witnesses"),
        .package(path: "../swift-environment"),
        .package(
            path: "../../swift-primitives/swift-clock-primitives",
            traits: [],
            condition: .when(traits: ["ClockIntegration"])
        ),
    ],
    targets: [
        .target(name: "Dependencies", dependencies: [
            .product(name: "Witnesses", package: "swift-witnesses"),
            .product(name: "Environment", package: "swift-environment"),
        ]),
        .target(name: "Clocks Dependency", dependencies: [
            "Dependencies",
            .product(name: "Clock Primitives", package: "swift-clock-primitives",
                     condition: .when(traits: ["ClockIntegration"])),
        ]),
    ]
)
```

**Publication feasibility**: **Full** — SE-0450 is available since Swift 6.1.

**Consumer usage**:
```swift
// Consumer's Package.swift
.package(url: "https://github.com/.../swift-dependencies.git",
         from: "1.0.0",
         traits: ["ClockIntegration"]),
```

Or via CLI: `swift build --traits ClockIntegration`

| Criterion | Assessment |
|-----------|-----------|
| Local development | Works |
| Publication | Full (Swift 6.1+) |
| Consumer experience | Explicit opt-in per trait; clear what's being pulled in |
| Repo proliferation | **None** |
| Discovery | **Excellent** — traits listed in Package.swift |
| Version coordination | Automatic — ships with hub package |
| Hub package dependency list | Grows, but dependencies are conditionally resolved |
| Maturity | **SE-0450 is new** (Swift 6.1, ~1 year old). Community adoption is nascent. |

**Advantage over Strategy C**: Traits provide an **explicit** opt-in mechanism, vs SE-0226's implicit "only resolve what's needed" behavior. Traits are declarative — `traits: ["ClockIntegration"]` in the consumer's Package.swift makes the integration choice visible and auditable.

**Disadvantage**: Requires Swift 6.1+ for all consumers. Traits are relatively new and may have edge cases.

---

### Strategy E: Integration Hub Package

**Description**: A single dedicated package collects all integrations for a given framework.

```
swift-foundations/
├── swift-dependencies/
└── swift-dependency-integrations/     ← NEW: all integrations here
    ├── Sources/Clocks Dependency/
    ├── Sources/Logging Dependency/
    └── Sources/Networking Dependency/
```

| Criterion | Assessment |
|-----------|-----------|
| Local development | Works |
| Publication | Full |
| Consumer experience | Import from one integration package |
| Repo proliferation | **1 repo total** (not per integration) |
| Discovery | Good — one place to find all integrations |
| Version coordination | Must track all integrated packages' versions |
| Dependency list | Grows linearly with integration count |

**Applied to the ecosystem**: `swift-dependency-integrations` depends on `swift-dependencies` + every package it integrates with. Consumers pick individual products.

**Problem**: The hub package's `dependencies:` array lists every package it integrates with. Even with SE-0226, SPM must fetch and parse every dependency's manifest at resolution time. A hub with 20 integrations creates a large resolution graph even if the consumer only wants one integration.

---

## Comparison

| Criterion | A: Nested | B: Standalone Repos | C: Intra-Package (SE-0226) | D: Traits (SE-0450) | E: Hub Package |
|-----------|-----------|--------------------|-----------------------------|---------------------|----------------|
| Publication | **Fails** | Full | Full | Full (6.1+) | Full |
| Repo proliferation | 0 | 1 per integration | 0 | 0 | 1 total |
| Discovery | Good | Poor (scattered) | Excellent | Excellent | Good |
| Version coordination | N/A | Per-integration | Automatic | Automatic | Must track all |
| Consumer opt-in | N/A | Implicit (add dep) | Implicit (add product dep) | **Explicit** (trait) | Implicit (add product dep) |
| Dependency isolation | N/A | Full (separate repo) | SE-0226 (needs validation) | **Guaranteed** (trait-gated) | SE-0226 (needs validation) |
| Hub package pollution | None | None | Package-level deps grow | **Conditional** (trait-gated) | All deps in one place |
| Maturity | Broken | Proven (NIO) | Proven (Firebase) | New (Swift 6.1) | Proven (Firebase) |
| Minimum toolchain | Any | Any | Swift 5.2 | **Swift 6.1** | Swift 5.2 |
| Ecosystem precedent | None | NIO, Hummingbird | Firebase, swift-collections | Rust features, Haskell flags | — |
| Scales to 20+ integrations | N/A | Poor (20 repos) | Good | **Best** | Moderate |

---

## Theoretical Grounding [RES-022]

### Dependency Graph Theory

Let G = (V, E) be a dependency graph where V = packages, E = dependencies.

**Problem 1 (intra-package isolation)**: A vertex v has internal structure {v_core, v_applied} where v_applied introduces edges that v_core does not need. Solution: split v into two vertices (v_core, v_applied) with v_applied → v_core.

**Problem 2 (cross-package integration)**: Two vertices x, y ∈ V have no edge between them. A new vertex z requires edges z → x and z → y. Question: where does z live?

**Strategy B** (standalone): z is a new vertex in V. |V| grows by 1 per integration.

**Strategy C** (intra-package): z is folded into x as internal structure. |V| unchanged. But x's package-level dependency set grows to include y's transitive deps.

**Strategy D** (traits): z is folded into x as internal structure, but the edge z → y is conditional. The edge only materializes when a consumer activates the trait. This is a **conditional dependency graph** — the graph shape depends on consumer configuration.

**Observation**: Strategy D is the only strategy that keeps |V| constant AND avoids unconditional growth of x's dependency set. It achieves this by making edges conditional — equivalent to Rust's cargo feature gates.

### Integration Point Classification

| Type | Description | Strategy |
|------|-------------|----------|
| **Essential integration** | Package X cannot function without Y | Direct dependency (not an integration problem) |
| **Incidental integration** | X can be viewed through Y's lens | Cross-package integration (Problem 2) |
| **Conformance integration** | X's types conform to Y's protocols | Either problem, depending on whether the conformance is in X's defining module |

The Finite × Collection case is **conformance integration** where the conformance must be in the defining module (CaseIterable constraint). This collapses it into Problem 1.

The Dependencies × Clock case is **incidental integration** — Dependencies works without Clock; the integration provides a convenient pre-configured key. This is purely Problem 2.

---

## Empirical Validation [RES-025]

### SE-0450 Trait-Gated Dependencies (Strategy D) — CONFIRMED

Validated by implementing the `swift-dependencies` clock integration:

1. `swift-dependencies` declares `"Clocks"` trait and `swift-clock-primitives` as a package dependency
2. "Clocks Dependency" target has `.product(name: "Clock Primitives", condition: .when(traits: ["Clocks"]))`
3. `swift build --target Dependencies` (no trait) — builds without resolving `swift-clock-primitives`
4. `swift build --target "Clocks Dependency" --traits Clocks` — builds with clock integration
5. Downstream consumer (`swift-async`) opts in via `.package(path: "...", traits: ["Clocks"])`

**Findings**:
- `traits:` parameter must follow `products:` in `Package()` initializer (ordering constraint)
- Trait-gated product dependencies use the existing `condition:` parameter: `.when(traits: ["Clocks"])`
- Source files need no conditional compilation — the target is simply not built when no consumer requests it
- Module name (`Clocks_Dependency`) is unchanged, so downstream `import` statements are unaffected

### SE-0226 Target-Based Resolution (Strategy C)

Not separately validated. SE-0450 traits provide the stronger guarantee and are the chosen strategy. SE-0226 validation deferred.

---

## Outcome

**Status**: DECISION

### Decision: Strategy D — Trait-Gated Integration Targets (SE-0450)

**For cross-package optional integrations**: Use SE-0450 Package Traits to gate integration targets within the hub package. Each integration is a separate product + target. The external dependency is conditioned on a named trait. Consumers opt in explicitly via `traits: ["TraitName"]` in their package dependency declaration.

**Implemented**: `swift-dependencies` clock integration migrated from nested `Package.swift` to trait-gated target (commits `b81bdcd`, `aae0607`).

**Rationale**:

1. **Strategy A (nested)** is eliminated — hard SPM limitation on publication.

2. **Strategy B (standalone repos)** is viable but scales poorly. Each integration creates a new repo with its own versioning, CI, and maintenance burden. At 5-10 integrations, this becomes the Hummingbird pattern (22 repos).

3. **Strategy C (intra-package SE-0226)** is viable but relies on implicit resolution filtering. Not separately validated.

4. **Strategy D (trait-gated SE-0450)** provides explicit opt-in, zero repo proliferation, automatic version coordination, and excellent discoverability. Validated in production with `swift-dependencies` → `swift-async` consumer chain. This is the Rust cargo features model — proven at massive scale.

5. **Strategy E (hub package)** has no advantage over Strategy D. It adds a repo without adding isolation.

### Decision Framework

| Condition | Strategy |
|-----------|----------|
| Integration is conformance-coupled (like Finite × Collection) | Problem 1 → Core extraction ([MOD-001]) |
| Hub package targets Swift 6.1+ | **Strategy D (traits)** |
| Hub package must support Swift <6.1 consumers | Strategy B (standalone repos) |
| Integration count is small (1-3) and packages are in different layers | Strategy B is acceptable; Strategy D preferred |
| Integration count is large (5+) from a single hub package | **Strategy D (traits)** — repo proliferation unacceptable |

### Implementation Pattern

```swift
// Hub package (e.g., swift-dependencies)
let package = Package(
    name: "swift-dependencies",
    products: [
        .library(name: "Dependencies", targets: ["Dependencies"]),
        .library(name: "Clocks Dependency", targets: ["Clocks Dependency"]),
    ],
    traits: [
        .trait(name: "Clocks"),
    ],
    dependencies: [
        .package(path: "../swift-witnesses"),
        .package(path: "../../swift-primitives/swift-clock-primitives"),
    ],
    targets: [
        .target(name: "Dependencies", dependencies: [
            .product(name: "Witnesses", package: "swift-witnesses"),
        ]),
        .target(name: "Clocks Dependency", dependencies: [
            "Dependencies",
            .product(name: "Clock Primitives", package: "swift-clock-primitives",
                     condition: .when(traits: ["Clocks"])),
        ]),
    ]
)
```

```swift
// Consumer package
.package(path: "../swift-dependencies", traits: ["Clocks"]),
// ...
.product(name: "Clocks Dependency", package: "swift-dependencies"),
```

### Next Steps

1. **Codify**: Add `[MOD-014] Cross-Package Integration Pattern` to the `modularization` skill documenting Strategy D as the canonical approach.

2. **Future integrations**: As `swift-dependencies` gains more integration targets (Logging, URLSession, etc.), each follows the same pattern: new trait + product + target.

### Relationship to Existing Research

This research subsumes and extends:
- **finite-collection-join-point-integration.md**: That document analyzed Options A-D for one specific case. This document generalizes the problem and adds Strategies C and D (SE-0226, SE-0450) which were not considered there.
- **intra-package-modularization-patterns.md**: That document codified Problem 1 solutions. This document addresses Problem 2 which that document does not cover.
- **spm-nested-package-publication.md**: That document eliminated nested packages. This document evaluates the remaining alternatives.

---

## References

### Swift Evolution
- [SE-0226: Package Manager Target Based Dependency Resolution](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0226-package-manager-target-based-dep-resolution.md)
- [SE-0386: `package` Access Modifier](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0386-package-access-modifier.md)
- [SE-0450: Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md)
- [Multi-Package Repos pitch (2020, dormant)](https://forums.swift.org/t/spm-multi-package-repositories/43193)

### Industry Prior Art
- [Firebase Apple SDK: Package.swift (31 products)](https://github.com/firebase/firebase-ios-sdk/blob/main/Package.swift)
- [swift-nio satellite repos](https://github.com/apple/swift-nio)
- [Hummingbird ecosystem](https://github.com/hummingbird-project)
- [Rust: Features (cargo features)](https://doc.rust-lang.org/cargo/reference/features.html)
- [Haskell: Cabal flags](https://cabal.readthedocs.io/en/3.4/cabal-package.html#pkg-field-flag-name)

### Internal Research
- [spm-nested-package-publication.md](spm-nested-package-publication.md) — Nested packages rejected
- [dual-mode-package-publication.md](dual-mode-package-publication.md) — Release branch publication
- [intra-package-modularization-patterns.md](https://github.com/swift-primitives/Research/blob/main/intra-package-modularization-patterns.md) — 13 intra-package patterns
- [finite-collection-join-point-integration.md](https://github.com/swift-primitives/Research/blob/main/finite-collection-join-point-integration.md) — Finite × Collection case study
