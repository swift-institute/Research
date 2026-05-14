# Swift Package Domain — L1/L2 Split

<!--
---
version: 1.1.0
last_updated: 2026-05-14
status: APPROVED
research_tier: 2
applies_to: [swift-package-primitives, swift-spm-standard, swift-package-graph, swift-impact, ecosystem-wide]
normative: true
---
-->

## Context

### Trigger

The `swift-package-graph` + `swift-impact` arc (per `downstream-impact-ci-for-swiftpm-ecosystems.md` v1.0.0, 2026-05-14) surfaced a domain-ownership question: which layer owns the SwiftPM package model? The audit of existing L1 + L3 surfaces showed:

- **swift-package-primitives** (L1) hosts a `Package` namespace whose own docstring explicitly states the namespace is *"generic rather than brand-flavored — `Package` not `SwiftPM.Package` — so cross-ecosystem tooling (registry analyzers, dependency tooling, manifest generators) can adopt the types without importing a consumer-flavored surface"*. But its actual contents — `Package.Dependency` with `.path` / `.urlFrom` / `.urlRange` Source variants — are **SwiftPM-flavored**. The namespace claims genericity that the contents don't honor.
- **swift-manifest-primitives** (L1) owns the Institute DSL manifest pattern (`Lint.swift`, `Format.swift`), not SwiftPM `Package.swift`.
- **swift-manifests** (L3) owns the DSL manifest *loader*, also not SwiftPM `Package.swift`.
- **swift-dependency-analysis** (L3) is the closest existing fit but is stale per principal.

The first-class domain owners for SwiftPM's package model are therefore **missing**. The arc cannot proceed without resolving this.

### Scope

Ecosystem-wide per `[RES-002a]`. This document establishes:

1. The L1/L2/L3 layering for the SwiftPM package domain.
2. The migration of SwiftPM-flavored types out of swift-package-primitives.
3. The naming and mandate of the new L2 package (`swift-spm-standard`).
4. The deferral conditions for an L3 `swift-package-manager` foundation.

### Prior research (cite-and-extend per `[HANDOFF-013]`)

- `swift-institute/Research/downstream-impact-ci-for-swiftpm-ecosystems.md` v1.0.0 (2026-05-14) — parent arc that surfaced this question; established that no off-the-shelf tooling for downstream-impact CI exists.
- `swift-package-primitives/Package.swift` docstring (verified 2026-05-14): explicitly anticipates `Package.Identity` (SE-0292 registry) and `Package.Manifest` (richer manifest model) as "future siblings (additive per framework Axiom 3)".
- `swift-institute/Skills/swift-institute/SKILL.md` — five-layer architecture (`[ARCH-LAYER-*]`).
- `swift-institute/Skills/research-process/SKILL.md` — `[RES-018]` premature primitive (applied here for L3 deferral), `[RES-020]` parallel subagent verification (applied during 2026-05-14 dep audit), `[RES-026]` citations.

---

## Question

How should the Institute layer the SwiftPM package-manager domain such that:

1. **Cross-ecosystem tooling** (analyzers, registry tools, generic dep-graph builders) consume the universal vocabulary without importing SwiftPM-flavored surface;
2. **SwiftPM-specific consumers** (swift-package-graph, swift-impact, future release-readiness / audit / version-bump) consume the typed manifest model directly;
3. **The layering is consistent with the Institute's external-spec-at-L2 pattern** (RFCs, ISOs, etc.);
4. **No layer carries a domain it does not own** (per the 2026-05-14 principal-stated principle: "each package should own its own domain").

Decomposes into:

1. What's L1-generic (universal) vs L2-SwiftPM-specific (spec-bound)?
2. Why is SwiftPM an L2 external spec?
3. What migrates out of swift-package-primitives?
4. What does swift-spm-standard contain?
5. When should L3 `swift-package-manager` be authored?
6. Naming + on-disk placement of swift-spm-standard.

---

## Analysis

### Q1 — L1-generic vs L2-SwiftPM-specific

**Universal across package managers** (Cargo, npm, Maven, Hex, NuGet, SwiftPM, ...):

- The *identity* of a package as a typed name (`Tagged<Package, String>`).
- The *identity* of a product/library as a typed name.
- The *identity* of a target/module as a typed name.
- The *concept* of a dependency edge (source → target).
- The *concept* of a manifest as a "package descriptor".

Universal **abstractions** can live at L1 (as protocols or generic types) but the *concrete realizations* of those abstractions are spec-bound and belong higher.

**SwiftPM-specific** (defined by Apple's `swift-package-manager` project as a specification):

- The `Package.swift` file format (PackageDescription DSL — a Swift API).
- The `swift package dump-package` JSON wire format.
- The set of source variants: `.path`, `.url(Requirement)`, `.registry` (SE-0292).
- The set of version requirement variants: `.from`, `.upToNextMajor`, `.upToNextMinor`, `.exact`, `.range`, `.branch`, `.revision`.
- The set of product kinds: `.library`, `.executable`, `.plugin`.
- The library type sub-enum: `.static`, `.dynamic`, `.automatic`.
- The set of target kinds: `.regular`, `.test`, `.executable`, `.plugin`, `.binary`, `.system`, `.macro`.
- The target-dependency forms: `.product(name:package:)`, `.target(name:)`, `.byName(...)`.
- The platform/version model: `SupportedPlatform`, `Platform`, `PlatformVersion`.
- The swift-tools-version directive and parsing of the leading comment.
- Per-target settings (`SwiftSetting`, `CSetting`, `CXXSetting`, `LinkerSetting`).
- Resources, public headers path, plugin usage.

These are **specifications defined by the SwiftPM project**, not universal package-manager abstractions. They belong at L2.

### Q2 — Why SwiftPM is an L2 external spec

The Institute's L2 layer hosts spec implementations: types and parsers/serializers for external specifications. Verified examples (per CLAUDE.md):

- `swift-rfc-4122` — UUID format (IETF RFC).
- `swift-iso-32000` — PDF (ISO).
- `swift-rfc-3986` — URI syntax (IETF RFC).
- Many sub-orgs: swift-ietf, swift-iso, swift-w3c, swift-whatwg, swift-ecma, etc.

The pattern is: **an external authority owns the spec; the L2 package faithfully represents it as Swift types with Codable wire conformance**.

**SwiftPM fits this mold.** The spec authority is Apple's `swift-package-manager` project. The PackageDescription DSL is a published API. The `dump-package` JSON output is a documented wire format. swift-spm-standard's mandate is: *typed Swift representations of these spec artifacts.*

Unlike RFCs/ISOs, SwiftPM doesn't fit a sub-org under swift-standards (no "Apple" sub-org exists today, nor would it carve cleanly — Apple owns Swift itself + SwiftPM + Foundation + AppKit/SwiftUI + many other specs). swift-spm-standard therefore lives directly in `swift-standards/` proper, not under a sub-org.

### Q3 — What migrates out of swift-package-primitives

**Stays in swift-package-primitives** (genuinely universal):

```swift
public enum Package: Sendable {}
public enum Product: Sendable {}
public enum Target:  Sendable {}

extension Package { public typealias Name = Tagged<Package, String> }
extension Product { public typealias Name = Tagged<Product, String> }
extension Target  { public typealias Name = Tagged<Target,  String> }
```

These identifiers are package-manager-agnostic. A Cargo crate, an npm package, a SwiftPM package — all can carry a `Package.Name`.

**Moves to swift-spm-standard** (SwiftPM-specific):

```swift
// Currently in swift-package-primitives — MIGRATES OUT.
extension Package {
  public struct Dependency: Sendable, Hashable {
    public enum Source: Sendable, Hashable {
      case path(String)
      case urlFrom(url: String, from: String)
      case urlRange(url: String, lower: String, upper: String)
    }
    public let source: Source
    public let name: Package.Name
    public let products: [Product.Name]
  }
}
```

This type is SwiftPM-shaped (its Source variants encode SwiftPM's `.package(...)` clause forms). It moves to swift-spm-standard verbatim as v0, then expands (Q4).

### Q4 — What swift-spm-standard contains

The v0.1 surface, with explicit reference to PackageDescription / SwiftPM behavior:

```swift
// All declared in swift-spm-standard.
// `Package`, `Product`, `Target` namespaces re-extended here for SwiftPM-specific nesting.

extension Package {
  /// A SwiftPM package's typed manifest, as emitted by `swift package dump-package`.
  public struct Manifest: Sendable, Hashable, Codable {
    public let name: Package.Name
    public let toolsVersion: Version.Tools           // from swift-version-primitives
    public let dependencies: [Package.Dependency]
    public let products: [Package.Manifest.Product]
    public let targets: [Package.Manifest.Target]
    public let platforms: [SupportedPlatform]?
    // Additional fields (swiftLanguageModes, cLanguageStandard, etc.) added
    // additively as consumers need them; not blocking v0.1.
  }

  public struct Dependency: Sendable, Hashable, Codable {
    public enum Source: Sendable, Hashable {
      case path(String)
      case url(String, Package.Requirement)
      case registry(Package.Identity, Package.Requirement)  // SE-0292
    }
    public let source: Source
    public let name: Package.Name
    public let products: [Product.Name]
  }

  /// Version-requirement variants exactly as PackageDescription declares them.
  public enum Requirement: Sendable, Hashable, Codable {
    case from(Version.Semantic)                   // .package(url:from:)
    case upToNextMajor(from: Version.Semantic)    // .upToNextMajor(from:)
    case upToNextMinor(from: Version.Semantic)    // .upToNextMinor(from:)
    case range(Version.Range)                     // half-open Range<Version>
    case exact(Version.Semantic)                  // .exact(_:)
    case branch(String)                           // .package(url:branch:)
    case revision(String)                         // .package(url:revision:)
  }

  /// Registry-form identity per SE-0292: "<scope>.<name>".
  public struct Identity: Sendable, Hashable, Codable {
    public let scope: String
    public let name: String
  }
}

extension Package.Manifest {
  public struct Product: Sendable, Hashable, Codable {
    public let name: Product.Name
    public let kind: Product.Kind
    public let targets: [Target.Name]
  }

  public struct Target: Sendable, Hashable, Codable {
    public let name: Target.Name
    public let kind: Target.Kind
    public let dependencies: [TargetDependency]
    public let path: String?
    // Settings, resources, plugin usage added additively in later versions.
  }

  public enum TargetDependency: Sendable, Hashable, Codable {
    case product(Product.Name, package: Package.Name)
    case target(Target.Name)
    case byName(String)
  }
}

extension Product {
  public enum Kind: Sendable, Hashable, Codable {
    case library(LibraryType)
    case executable
    case plugin
  }

  public enum LibraryType: Sendable, Hashable, Codable {
    case `static`
    case `dynamic`
    case automatic
  }
}

extension Target {
  public enum Kind: Sendable, Hashable, Codable {
    case regular
    case executable
    case test
    case plugin
    case binary
    case system
    case macro
  }
}

public struct SupportedPlatform: Sendable, Hashable, Codable {
  public let platform: Platform
  public let version: String   // Could be Version.Semantic in v0.2; SwiftPM emits raw strings
}

public enum Platform: String, Sendable, Hashable, Codable {
  case macOS, iOS, tvOS, watchOS, visionOS
  case macCatalyst, driverKit
  case linux, android, windows, wasi
  case freeBSD, openBSD
  // Match SwiftPM's enumeration; extend when SwiftPM extends.
}
```

**Codable conformances** match the JSON shape SwiftPM emits via `swift package dump-package`. This is the wire format — the L2 owns both the in-memory model and the JSON encoding/decoding of that model.

**Out of scope for v0.1** (additive in later versions): per-target settings (`SwiftSetting`, `CSetting`, `CXXSetting`, `LinkerSetting`), resources, public headers path, plugin usage, swift language modes, C/C++ language standards. Each is additive and lands as consumers (audit, release-readiness) need them.

### Q5 — When to author L3 `swift-package-manager`

Per `[RES-018]` (Premature Primitive Anti-Pattern): a new L3 foundation requires (a) demonstrating composition of existing primitives doesn't cover the use case, AND (b) at least one second consumer independent of the originating investigation.

For an L3 `swift-package-manager` foundation that would own manifest loading + resolving + materialization:

| Consumer | Need from L3 swift-package-manager | Could compose L2 + swift-process + swift-json directly? |
|---|---|---|
| swift-package-graph | Load all `Package.swift` manifests in a workspace | YES — subprocess + JSON decode is ~80 LOC |
| swift-impact | (Transitively via swift-package-graph) | n/a — doesn't load manifests directly |
| Future release-readiness | Load + verify a single package's manifest | YES (same 80 LOC) |
| Future audit | Load + analyze manifest patterns | YES (same 80 LOC) |
| Future version-bump | Load + mutate (rewrite) a manifest | NO — mutation is non-trivial; needs an L3 owner |

Today's count: 1 immediate consumer (swift-package-graph). Future consumers may compose directly. **Mutation is the trigger** — when a consumer needs to write manifests back (version bumps, Source rewrites, scaffolding), an L3 foundation becomes justified.

**Verdict: defer L3 swift-package-manager.** swift-package-graph contains its own subprocess + JSON decode for v0.1. Re-evaluate when (a) a third-direct consumer emerges OR (b) the first mutation use case appears.

### Q6 — Naming + placement

**Chosen name**: `swift-spm-standard` (principal-stated 2026-05-14).

- Uses the `spm` abbreviation (common SwiftPM shorthand).
- Carries the `-standard` suffix matching the dominant L2 pattern (swift-color-standard, swift-json-feed-standard).
- Compact at 18 characters; avoids the doubled-"swift" awkwardness of `swift-swift-package-manager-standard`.
- The principal noted "for now" — open to renaming if a more consistent ecosystem-wide convention emerges.

**Placement**: `/Users/coen/Developer/swift-standards/swift-spm-standard/`

- L2 home is swift-standards (per CLAUDE.md "L2 Standards").
- No sub-org (no swift-apple org exists or is planned).
- Public visibility from day 1 (`[CI-032]` — gets free CI).

---

## Outcome

**Status: APPROVED**

### Approval

Approved 2026-05-14 by principal as part of Wave 1A of the Phase 3 follow-up arc; v0.3 of swift-spm-standard implements the v0.1-design types per Q4 (`Manifest.Product`, `Manifest.Target`, `Product.Kind`, `Product.LibraryType`, `Target.Kind`, `SupportedPlatform`, `Platform`), reuses the existing top-level `Target.Dependency` for the target-dependency surface (consistent with `[API-NAME-001]`, no compound `TargetDependency`), and adds a second-pass decode that back-fills `Package.Dependency.products` by walking the target-dependency edges. The Q4 structural-naming concern is resolved via module-qualified references (`Package_Primitives.Product.Name`) inside the shadowed `extension Package.Manifest` blocks — typealias-based resolutions fail because Swift access control rejects a `private` / `internal` typealias appearing in a public declaration. v0.3 retains the ignore-extras strategy for the remaining `dump-package` fields (settings, resources, packageKind, traits, etc.); these add additively as consumers need them.

The Institute's SwiftPM domain layers as follows:

| Layer | Package | Owns | Status |
|---|---|---|---|
| L1 | swift-package-primitives | Universal `Package.Name` / `Product.Name` / `Target.Name` typed identifiers; namespaces. | Exists; **needs refactor** to remove migrated types. |
| L1 | swift-version-primitives | Universal `Version.Semantic`, `Version.Calendar`, `Version.Tools`, `Version.Range`. | Exists; consumed by L2. |
| L2 | **swift-spm-standard** (NEW) | SwiftPM PackageDescription DSL as types: `Package.Manifest`, `Package.Dependency`, `Package.Requirement`, `Package.Identity`, `Manifest.Product`, `Manifest.Target`, `TargetDependency`, `Product.Kind`, `Target.Kind`, `SupportedPlatform`, `Platform` + JSON Codable conformances. | **TO AUTHOR.** |
| L3 | swift-package-manager (DEFERRED) | Manifest loading / resolving / materialization. | Defer until ≥2 direct consumers OR mutation use case. |
| L3 | swift-package-graph (NEW) | Reverse-dep graph queries. | **TO AUTHOR**, depends on swift-spm-standard. |
| L3 | swift-impact (NEW) | Build-impact orchestration. | **TO AUTHOR**, depends on swift-package-graph. |

### Migration plan

**Phase 0a** — Author swift-spm-standard at swift-standards/swift-spm-standard:
- Scaffold (Package.swift, README, LICENSE, .swift-format, .swiftlint.yml, .github/, Sources/SPM Standard/, Tests/).
- Implement v0.1 surface per Q4.
- Public visibility from day 1.
- Tests: round-trip Codable for each type against captured `swift package dump-package` JSON fixtures.

**Phase 0b** — Refactor swift-package-primitives:
- Remove `Package.Dependency` (and `Package.Dependency.Source`).
- Keep `Package.Name`, `Product.Name`, `Target.Name` and the three top-level namespaces.
- Update the namespace docstring to remove the "future sibling Package.Manifest" reference (Package.Manifest now lives at L2).
- Bump major version (breaking change pre-1.0).

**Phase 0c** — Update consumers:
- Grep ecosystem-wide for `import Package_Primitives` AND a usage of `Package.Dependency`.
- For each consumer: switch the import to `swift-spm-standard` (specifically `SPM_Standard` module) for the migrated types.
- Estimate: low-double-digit number of consumers at most, given swift-package-primitives is recent.

**Phase 1** — Author swift-package-graph (separate design doc).

**Phase 2** — Author swift-impact (separate design doc).

### Sequencing

Phase 0a and 0b can run in parallel (each modifies a different package). Phase 0c follows both. Then Phase 1, then Phase 2.

## Open questions

1. **JSON wire format stability**: `swift package dump-package` output schema can change across Swift toolchain versions. swift-spm-standard's Codable conformances pin to Swift 6.3+ output. Document the assumption; revisit at Swift 7. Mitigation: maintain a small corpus of captured JSON fixtures in `Tests/` and assert round-trip.

2. **Tagged identity collision**: `Package.Name`, `Product.Name`, `Target.Name` are all `Tagged<TypeNamespace, String>`. The TypeNamespace tags are the empty enums `Package`, `Product`, `Target`. These are tagged distinct via their type — no string-level collision.

3. **Registry-form Identity model (SE-0292)**: `Package.Identity` is `<scope>.<name>` per SE-0292. Currently no Institute consumer uses registry-form deps. Spec the type; defer testing/validation until adoption.

4. **Platform model: PackageDescription's actual enum vs ours**: SwiftPM's `Platform` enum grows over time. swift-spm-standard's `Platform` enum should mirror it. Establish a refresh cadence (e.g., every Swift toolchain bump, re-check); document the source of truth.

5. **Manifest.Target.path semantics**: when not set, SwiftPM auto-derives the path from `Sources/<TargetName>/`. swift-spm-standard preserves the optionality (the wire format reflects what was declared). Consumers needing the resolved path do their own derivation.

6. **Mutation API in swift-spm-standard or future swift-package-manager L3?**: swift-spm-standard v0.1 has Codable read/write but does NOT include manifest mutation helpers (e.g., "add a dependency", "bump a version"). Mutation belongs in an L3 owner if/when it's needed. v0.1: read-only model.

7. **Should swift-package-primitives itself be renamed?** Its docstring claims genericity; renaming to something more clearly cross-ecosystem (e.g., `swift-package-identity-primitives`) might prevent future drift back to SwiftPM-flavored content. Defer; rename is a separate breaking change with its own cost. Track as a future cleanup option.

## References

### Verified primary sources (2026-05-14)

- `/Users/coen/Developer/swift-primitives/swift-package-primitives/Sources/Package Primitives/Package.swift` — namespace docstring; "generic rather than brand-flavored"; lists `Package.Identity` + `Package.Manifest` as future siblings.
- `/Users/coen/Developer/swift-primitives/swift-package-primitives/Sources/Package Primitives/Package.Dependency.swift` — current Source variants (.path/.urlFrom/.urlRange); explicitly notes "Future sibling Source variants (registry-form per SE-0292; revision/branch constraints) MAY extend the enum additively per typed-identifier-naming Axiom 3."
- `/Users/coen/Developer/swift-primitives/swift-package-primitives/Sources/Package Primitives/Product.swift` — Product namespace docstring; "sibling to Package and Target rather than nested"; lists `Product.Kind` + `Product.LibraryType` as future.
- `/Users/coen/Developer/swift-primitives/swift-package-primitives/Sources/Package Primitives/Target.swift` — Target namespace docstring; lists `Target.Kind` + `Target.ModuleName` as future.
- `/Users/coen/Developer/swift-primitives/swift-version-primitives/Sources/Version Primitives/` — `Version.Semantic`, `Version.Calendar`, `Version.Tools`, `Version.Range` confirmed.
- `/Users/coen/Developer/swift-foundations/swift-manifests/Sources/Manifest Loader/Manifest.Load.swift` — confirms swift-manifests is for Institute DSL manifests, NOT SwiftPM Package.swift.
- `/Users/coen/Developer/swift-foundations/swift-process/Sources/` — Process.Spawn confirmed for future loader implementations.
- `/Users/coen/Developer/swift-foundations/swift-json/Sources/` — JSON.Serializable + JSON.parse confirmed for Codable wire format.

### Internal cross-references

- `swift-institute/Research/downstream-impact-ci-for-swiftpm-ecosystems.md` v1.0.0 — parent arc.
- `swift-institute/Skills/swift-institute/SKILL.md` — `[ARCH-LAYER-*]` five-layer architecture.
- `swift-institute/Skills/swift-package/SKILL.md` — `[PKG-NAME-*]`, `[PKG-DEP-*]`.
- `swift-institute/Skills/research-process/SKILL.md` — `[RES-018]` (premature primitive; applied to defer L3), `[RES-020]` (subagent verification), `[RES-026]` (citations).
- `swift-institute/Skills/code-surface/SKILL.md` — `[API-NAME-001]` nested namespaces, `[API-NAME-002]` no compound identifiers, `[API-ERR-001]` typed throws.
- `swift-institute/Skills/existing-infrastructure/SKILL.md` — consulted before authoring new types.

### Memory references

- `feedback_workspace_scope_l1_only.md` — current active scope is L1 only; swift-spm-standard's first consumer (swift-package-graph) targets swift-primitives but the design generalizes across all five layers.
- `feedback_no_inter_launch_soak.md` — pre-1.0 breaking changes are paced by readiness, not calendar floors.

### External references

- SwiftPM PackageDescription API documentation (Apple) — the spec source authority.
- SE-0292 (Package Registry Service) — for Registry-form `Package.Identity` model.
- `swift package dump-package` output schema — the JSON wire format swift-spm-standard mirrors.
