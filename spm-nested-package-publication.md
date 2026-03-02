# SPM Nested Package Publication Feasibility

<!--
---
version: 1.0.0
last_updated: 2026-02-26
status: DECISION
research_tier: 2
applies_to: [institute, primitives, standards, foundations]
normative: false
---
-->

## Context

The Swift Institute is exploring domain-first repository organization where each domain repo (e.g., `swift-time`) would contain both primitives (Layer 1) and foundations (Layer 3) as separate sub-packages. This would improve consumer discoverability — one repo per domain instead of navigating three layer-organized monorepos.

### Trigger

Publication planning [RES-012]. Before committing to a publication structure, we need to validate whether SPM supports the proposed nested-package model.

### Scope

Ecosystem-wide [RES-002a]. This decision affects the physical repository structure of all published packages.

---

## Question

Can a published Swift package contain nested `Package.swift` files (sub-packages) that are individually consumable as versioned dependencies?

### Sub-questions

- SQ1: Does SPM support nested `Package.swift` files within a versioned package?
- SQ2: Can path dependencies within the same git repo be consumed via git URL?
- SQ3: What alternative models exist for multi-layer packages?
- SQ4: Is there an active Swift Evolution proposal that would change the answer?
- SQ5: What do major Swift packages do in practice?

---

## Empirical Validation

### Experiment Setup

Four configurations tested with local git repos consumed via `file://` URLs:

| Test | Configuration | Result |
|:---:|---|:---:|
| 1-4 | Nested `Primitives/Package.swift`, path deps for externals, local builds | **PASS** |
| 5-8 | Cross-domain nested packages, unique dir names, local path deps | **PASS** |
| 9 | Nested `Package.swift`, external PATH deps, consumed via git URL | **FAIL** |
| 10-11 | Single `Package.swift`, multiple products, consumed via git URL | **PASS** |
| 12 | Nested `Package.swift`, external GIT URL deps, consumed via git URL | **FAIL** |

### Key Error

When a versioned package (consumed via git URL) contains a `.package(path:)` dependency — even to a subdirectory within the same repo — SPM rejects it:

```
package 'swift-time' is required using a stable-version but 'swift-time'
depends on an unstable-version package 'timeprimitives'
```

### Additional Finding: Identity Collision

When two repos both contain a nested directory named `Primitives/`, SPM assigns both the package identity `Primitives` (derived from directory name, not the `name:` field in `Package.swift`). Cross-referencing between them fails with identity ambiguity.

---

## Prior Art Survey [RES-021]

### SPM Proposals and Pitches

| Proposal | Year | Status | Addresses Sub-Packages? |
|---|---|---|---|
| Draft: Multi-Package Repos (Dunbar) | 2016-2017 | Concept, never formally proposed | Yes — shared version per repo tag |
| Workspace.swift pitch | 2018 | Draft only, never submitted | No — development workflow only |
| SPM Multi-Package Repos pitch | 2020 | Suspended pending SE-0292 | Yes — shared version per repo tag |
| SE-0226: Target-Based Resolution | 2018 | Accepted, Swift 5.2 | No |
| SE-0291: Package Collections | 2021 | Accepted, Swift 5.5 | No — discovery only |
| SE-0292: Package Registry | 2021 | Accepted, Swift 5.7 | Potentially via registry tooling |
| SE-0386: `package` access modifier | 2023 | Accepted, Swift 5.9 | No — but enables cross-target sharing |
| SE-0450: Package Traits | 2024 | Accepted, Swift 6.1 | No — conditional features only |
| Multi-Package Repo GitHub issue | 2017 | Open, no activity since 2022 | Requested but not implemented |

**Key finding**: The multi-package repos proposal was drafted in 2016, re-pitched in 2020, and suspended pending SE-0292. SE-0292 (Package Registry) shipped but does not address sub-packages. The proposal has been dormant for 4+ years with no active champion.

### Swift Forums Confirmation

[Thread #74895 (September 2024)](https://forums.swift.org/t/failed-to-resolve-dependencies-dependencies-could-not-be-resolved-because-package-nestedpackage-is-required-using-a-stable-version-but-nestedpackage-depends-on-an-unstable-version-package-localpackage-and-root-depends-on-nestedpackage-1-1-0/74895): User has exact same scenario — nested package in same repo. Community response confirms this is a hard architectural limitation with no workaround.

[Thread #63003 (February 2023)](https://forums.swift.org/t/is-it-possible-to-have-sub-package-swift-files/63003): Jeremy Giesbrecht (Swift team) explicitly states path dependencies "do not work for versioned releases, because most paths point at different things depending on the context."

[GitHub issue #5915 (November 2022)](https://github.com/swiftlang/swift-package-manager/issues/5915): Filed, still open, no resolution offered by SPM team.

### Industry Patterns [RES-021]

| Package | Repos | Products | Strategy |
|---|:---:|:---:|---|
| swift-collections | 1 | 11 | Granular products + umbrella + Traits |
| swift-nio | 6 | 12 (core) | Narrow waist (NIOCore) + satellite repos |
| swift-syntax | 1 | 18 | Granular products per layer |
| Hummingbird | 22 | 6 (core) | Narrow waist (HummingbirdCore) + satellite repos |
| Vapor | 1+many | 3 (core) | Monolithic core + ecosystem repos |
| TCA | 1 | 1 | Monolithic by design |
| Firebase | 1 | 31 | Granular products (extreme) |
| Apollo GraphQL | 1 dev | many dist | Git subtrees → separate distribution repos |

**Two dominant patterns emerge**:

1. **Granular products in one Package.swift** (swift-collections, swift-syntax, Firebase): One repo, many products. Consumers import only what they need. All products share a single version.

2. **Narrow waist + satellite repos** (NIO, Hummingbird, Vapor): Core repo vends foundational abstractions. Optional capabilities live in separate repos depending only on the core.

No major Swift package uses nested `Package.swift` files for published packages.

---

## Analysis

### Why Domain Repos With Nested Sub-Packages Cannot Work

The proposed model:
```
swift-time/
  Package.swift                    → foundations (Layer 3)
  TimePrimitives/Package.swift     → primitives (Layer 1)
```

Fails for two independent reasons:

**Reason 1: SPM rejects path dependencies in versioned packages.** This is by design and confirmed by the Swift team. No proposal to change this is active.

**Reason 2: The standards layer creates circular dependencies.** Even if nested packages worked, the dependency chain `TimePrimitives → ISO_8601 → Time` means `swift-time` (containing both TimePrimitives and Time) would have a circular dependency with `swift-standards` (containing ISO_8601). SPM prohibits circular package dependencies.

### Why Single Package.swift With Multiple Products Partially Works

The model:
```
swift-time/
  Package.swift    → products: [TimePrimitives, Time]
  Sources/TimePrimitives/
  Sources/Time/
```

Works for packages where no intermediate layer sits between the products. **Fails** when standards (Layer 2) must depend on the primitives product but the foundations product must depend on standards — creating a circular package dependency.

### What Actually Works

**Separate packages per layer** — the current model:
```
swift-primitives/swift-time-primitives/    → Layer 1
swift-standards/swift-iso-8601/            → Layer 2 (depends on ↑)
swift-foundations/swift-time/              → Layer 3 (depends on both ↑)
```

This is the only structure that satisfies:
1. SPM's versioning requirements (all deps are versioned packages)
2. No circular dependencies (strict downward flow)
3. Independent versioning per layer

### Possible Workaround: Git Subtrees (Apollo Pattern)

Development happens in a domain monorepo. CI uses `git subtree split` to publish each layer as a separate git repo with independent version tags. Consumers see separate repos; developers work in one.

| Aspect | Benefit | Cost |
|---|---|---|
| Developer experience | Single repo per domain | CI automation required |
| Consumer experience | Clean versioned deps | Same as current model |
| Versioning | Independent per layer | Tag coordination via CI |
| Complexity | Hidden in CI | Build/release tooling |

This preserves the consumer-facing three-package model while giving developers domain-first organization internally.

---

## Outcome

**Status**: DECISION

### Nested Package.swift: Rejected

SPM does not support nested `Package.swift` files in published packages. This is a hard architectural limitation confirmed by the Swift team, with no active proposal to change it. The limitation has been documented since at least 2017 and remains unresolved as of February 2026.

### Current Layer-First Model: Confirmed Correct

The three-repo structure (`swift-primitives`, `swift-standards`, `swift-foundations`) is the only structure that satisfies SPM's versioning requirements, avoids circular dependencies, and allows independent layer versioning. This is not a temporary workaround — it is the architecturally correct structure given SPM's design.

### Consumer Discoverability: Mitigate Via Documentation

The consumer inconvenience of navigating three repos for one domain is real. Mitigation:
- "Where does X live?" index mapping concepts → packages
- Cross-linked READMEs between layers
- Package Collections (SE-0291) for curated domain groupings
- Documentation site with domain-first navigation

### Future Watch

- **Multi-Package Repos proposal**: Dormant since 2020. If revived, would enable shared-version sub-packages within one repo. Monitor [GitHub issue #5108](https://github.com/apple/swift-package-manager/issues/5108).
- **Package Registry (SE-0292)**: Could enable registry-side sub-package publishing. No concrete work in this direction.
- **Package Traits (SE-0450)**: Useful for conditional dependencies within a layer, not for cross-layer organization.

### Deferred: Git Subtree Evaluation

The Apollo-pattern git subtrees offer a potential development-time improvement (domain monorepos for developers, separate repos for consumers). This requires a separate investigation into CI tooling requirements and is not blocking publication.

---

## References

- [Draft SwiftPM: Multi-Package Repos (Dunbar, 2016)](https://forums.swift.org/t/draft-swiftpm-proposal-multi-package-repositories/4503)
- [SPM Multi-Package Repos pitch (2020)](https://forums.swift.org/t/spm-multi-package-repositories/43193)
- [Package Manager Workspace pitch (2018)](https://forums.swift.org/t/package-manager-workspace/10667)
- [Is it possible to have sub Package.swift files? (2023)](https://forums.swift.org/t/is-it-possible-to-have-sub-package-swift-files/63003)
- [Nested package unstable-version error (2024)](https://forums.swift.org/t/failed-to-resolve-dependencies-dependencies-could-not-be-resolved-because-package-nestedpackage-is-required-using-a-stable-version-but-nestedpackage-depends-on-an-unstable-version-package-localpackage-and-root-depends-on-nestedpackage-1-1-0/74895)
- [Remote versioned packages + local packages (GitHub #5915)](https://github.com/swiftlang/swift-package-manager/issues/5915)
- [Multi-Package Repo Support (GitHub #5108)](https://github.com/apple/swift-package-manager/issues/5108)
- [SE-0292: Package Registry](https://forums.swift.org/t/accepted-with-modifications-se-0292-package-registry-service/49849)
- [SE-0450: Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md)
- [SE-0386: package access modifier](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0386-package-access-modifier.md)
- [Apollo: Managing Swift Packages in a Monorepo with Git Subtrees](https://www.apollographql.com/blog/how-apollo-manages-swift-packages-in-a-monorepo-with-git-subtrees)
- [When should one use Targets instead of Packages?](https://forums.swift.org/t/when-should-one-use-targets-instead-of-packages-in-swift-package-manager/71119)
