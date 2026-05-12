# Swift Package and Version Primitives Design

<!--
---
version: 1.0.0
last_updated: 2026-05-12
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

This Research authors the unified design for two new L1 primitives
packages: `swift-package-primitives` (typed identifiers for the
Swift package domain — package names, product names, target names)
and `swift-version-primitives` (typed versioning — Semantic
Versioning 2.0.0 and future kinds).

**Trigger**: the typed-primitive adoption audit + addendum
(`swift-foundations/swift-linter/Research/2026-05-12-typed-primitive-adoption-audit.md`
+ addendum, commit `b27d99a`) dispositioned three Ambiguous findings
as **Defer (primitives-gap)**:

- **F-A2.11** `Lint.SingleFile.PackageDependency.name: Swift.String`
- **F-A3.4** `Lint.Dependency.products: [Swift.String]`
- **F-A3.5** `Lint.SingleFile.PackageDependency.products: [Swift.String]`

The blocker on all three is "no L1 primitives package exists yet
for SwiftPM identifier shapes." This dispatch authors the design
Research doc closing the blocker.

**This Research SUPERSEDES four prior 2026-05-12 docs**:

| Superseded doc | Commit | What it carried |
|----------------|--------|-----------------|
| `2026-05-12-swift-spm-primitives-design.md` v1.0.0 | `14df127` | Parent design under `SwiftPM.*` namespace |
| `2026-05-12-swift-spm-primitives-validation-timing.md` v1.0.0 | `adb87d8` | Open Q5 — validation timing |
| `2026-05-12-swift-spm-primitives-target-name-v1.md` v1.0.0 | `adb87d8` | Open Q3 — Target.Name inclusion |
| `2026-05-12-swift-semver-primitives-package-version-placement.md` v1.0.0 | `adb87d8` | Open Q3 — Version placement |

The substantive recommendations of all four docs survive; only
naming changes. The four prior docs used `SwiftPM.*` and `SemVer.*`
namespaces, which violate two principal-affirmed principles:

1. No abbreviations as primary identifiers (`SwiftPM` abbreviates
   "Swift Package Manager"; `SemVer` abbreviates "Semantic
   Versioning").
2. Maximal ecosystem adoption / reuse / integration (a
   `SwiftPM.Package.Name` consumed by NPM/Cargo bridges or registry
   tooling drags in a SwiftPM-flavored namespace where the value
   is generic).

The framework theorizing the corrected naming is captured in the
companion Research
`2026-05-12-typed-identifier-naming-framework.md` v1.0.0
RECOMMENDATION — read alongside this design doc. This design APPLIES
the framework.

**Parent context pre-settled (carried forward unchanged)**:

| Decision | Resolution | Source |
|----------|------------|--------|
| Generic `swift-package-primitives` vs alternative | Generic noun (framework Axiom 2) | This Research |
| Import `PackageDescription` directly | Rejected | PackageDescription is toolchain-scoped, imports Foundation (violates `[PRIM-FOUND-001]`), is a DSL aggregate type not an identifier carrier |
| Foundation imports | Rejected per `[PRIM-FOUND-001]` | Primitives constraint |

**Internal research consulted per [HANDOFF-013] / [RES-019]**:
same corpus as the four superseded docs (decimal-carrier-integration
phantom-tag rule; glob-l1-vocabulary-relocation bootstrap precedent;
Lint.Rule.ID typealias precedent; manifest-primitives consumer;
swift-dependency-analysis consumer). Carrying forward without
re-derivation. Additionally consulted:

- `swift-institute/Research/2026-05-12-typed-identifier-naming-framework.md`
  v1.0.0 RECOMMENDATION (companion) — the framework this design
  applies.

## Question

What is the design of the institute's L1 typed-primitive packages
for Swift-package management identifiers (package / product /
target names) and Semantic Versioning (Version.Semantic), applying
the typed-identifier-naming framework?

The question subdivides into nine sub-questions answered per
[RES-009] multi-option analysis:

1. Package names (validate via framework)
2. Namespaces (validate via framework)
3. v1.0.0 type sets per package
4. Validation rules sourcing (unchanged from superseded parent Q4)
5. Validation timing (unchanged from superseded validation-timing
   doc — typealias / struct decision)
6. Conformances per type
7. Heritage posture (unchanged — greenfield + spec citations)
8. Tier classification per package
9. Cross-consumer enumeration (carried from superseded parent Q9 +
   target-name companion)

## Analysis

### Q1 — Package names (framework-applied)

**Framework Axioms 1 + 2 application**:

| Candidate | Framework verdict |
|-----------|-------------------|
| `swift-spm-primitives` | ✗ Axiom 1 violation — "spm" / "SPM" abbreviates "Swift Package Manager" |
| `swift-swiftpm-primitives` | ✗ Axiom 1 violation — "swiftpm" abbreviates |
| `swift-swift-package-manager-primitives` | ✗ Axiom 2 violation — "Swift Package Manager" is the BRAND/TOOL, not the generic-noun domain |
| `swift-package-primitives` | ✓ Axiom 2 — "package" is the generic noun for the domain |
| `swift-semver-primitives` | ✗ Axiom 1 violation — "semver" abbreviates |
| `swift-semantic-version-primitives` | ✗ Axiom 2 violation — "Semantic" is the specialization, not the generic noun |
| `swift-version-primitives` | ✓ Axiom 2 — "version" is the generic noun; "semantic" is a variant per Axiom 3 |

**Outcome**:

- **Package 1**: `swift-package-primitives`
- **Package 2**: `swift-version-primitives`

Both names: noun-form per `[PKG-NAME-001]`; `-primitives` suffix
per `[PRIM-NAME-001]`; spelled out per framework Axiom 1; generic
noun per framework Axiom 2.

### Q2 — Namespaces (framework-applied)

**Framework Axioms 2 + 3 application**:

| Candidate | Framework verdict |
|-----------|-------------------|
| `SwiftPM.*` | ✗ Axioms 1+2 violation — brand-namespace + abbreviation |
| `SPM.*` | ✗ Axiom 1 violation — abbreviation |
| `PackageManager.*` | ✗ Axiom 1 risk — would need decomposition; brand-flavored |
| `SwiftPackageManager.*` | ✗ Axiom 2 violation — brand/tool, not generic noun |
| `Package.*` | ✓ Axioms 1+2 — generic noun, spelled out, cross-ecosystem-reusable |
| `SemVer.*` | ✗ Axioms 1+2 violation — abbreviation + would lock in a single versioning kind |
| `SemanticVersion.*` | ✗ Axiom 2 violation — "Semantic" is the specialization; should be nested |
| `Version.*` with `Version.Semantic` inside | ✓ Axioms 2+3 — generic-noun top-level, spec-mirroring variant inside |

**Existing institute precedent supporting `Package.*`**:
`swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.swift:2`
already declares `public enum Package {}` at L3 [Verified:
2026-05-12]. The framework's `Package.*` recommendation promotes
this institute-established pattern from L3 to L1. Downstream
swift-dependency-analysis becomes an extension of the L1 namespace.

**Outcome**:

- **Package 1 namespace**: `Package.*`
- **Package 2 namespace**: `Version.*`
- **Package 1 type-name primary**: `Package.Name`, `Product.Name`,
  `Target.Name` (top-level sibling namespaces per Q3 analysis below)
- **Package 2 type-name primary**: `Version.Semantic` (per user's
  explicit guidance; framework Axiom 3 supports)

### Q3 — v1.0.0 type sets

#### swift-package-primitives v1.0.0

**Audit-driven closures**:

| Audit ID | Type closing it |
|----------|-----------------|
| F-A2.11 | `Package.Name` |
| F-A3.4 / F-A3.5 (products half) | `Product.Name` |

**Independent-consumer-driven addition (cleared via framework Axiom 4)**:

| Type | Second-consumer verification |
|------|------------------------------|
| `Target.Name` | `swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.Manifest.Target.swift:6` (`name: String`) + `Package.analyze.swift:60,80,82` (analysis identity + path construction) [Verified: 2026-05-12] |

**Top-level vs nested decision**: per framework Axiom 3, the
question is whether Product and Target nest under Package, or are
top-level siblings.

| Option | Shape | Argument |
|--------|-------|----------|
| Flat | `Package.Name`, `Product.Name`, `Target.Name` | Each namespace is independent; product/target names address themselves outside specific-package context (`swift build --target X`); the SwiftPM build graph addresses these globally |
| Nested | `Package.Name`, `Package.Product.Name`, `Package.Target.Name` | Product and Target are structurally MEMBERS of a Package (`Package.products: [Product]`, `Package.targets: [Target]` in the DSL) |

The institute's existing precedent at L3 swift-dependency-analysis
NESTS deeply: `Package.Manifest.Target` (Target under Manifest under
Package). That precedent is for analysis-specific Target structs;
at the L1 primitive identifier layer, the names are universal —
addressable without a Package context.

**Decision**: flat, top-level. `Package`, `Product`, `Target` are
each top-level namespaces, each hosting a `Name` typealias at
v1.0.0 plus expected sibling additions over time. This matches the
institute's distinct-namespace-per-distinct-domain-entity pattern
(`File`, `Path`, `Memory`, `Buffer`, etc.).

**v1.0.0 set**:

| Type | Backing | Closure |
|------|---------|---------|
| `Package.Name` | `Tagged<Package, Swift.String>` | F-A2.11; second consumer manifest-primitives |
| `Product.Name` | `Tagged<Product, Swift.String>` | F-A3.4/F-A3.5; second consumer manifest-primitives |
| `Target.Name` | `Tagged<Target, Swift.String>` | second consumer swift-dependency-analysis |

**Deferred (Axiom 4 — no second consumer verified at write time)**:

- `Source.Kind` enum (`.path` / `.url` / `.registry`) — defer
- `Package.Manifest.ToolsVersion` — defer
- `Package.Identity` (registry scope.name composite) — defer until
  a registry-aware tool surfaces
- Generic `Package` struct (full manifest model) — defer; L3
  swift-dependency-analysis already has `Package.Analysis` /
  `Package.Manifest` adequate for current use

**Promotion of L3 `Package` enum to L1**: the existing
`swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.swift:2`
declaration `public enum Package {}` is RE-DECLARED in L1
swift-package-primitives. swift-dependency-analysis becomes an
extension of the L1 declaration (`extension Package { public enum
Analysis { ... } }`). The L3 module's `public enum Package {}`
must be removed in the same wave to avoid collision. This is a
DOWNSTREAM consumer-migration dispatch beyond this Research; flagged
for principal awareness.

#### swift-version-primitives v1.0.0

**Single primary type**: `Version.Semantic` (Semantic Versioning
2.0.0).

**Framework Axiom 4 — second-consumer verification at write
time**:

| Consumer | Use site |
|----------|----------|
| Originating | `swift-package-primitives` v1.1.0+ (when typed dependency-requirement composition lands; not blocked on this Research) |
| Second consumer | swift-dependency-analysis MAY benefit; Swift Package Index forks; release-readiness tooling under `swift-institute/Scripts/`; registry-aware tooling — candidates surfaced in superseded `2026-05-12-swift-semver-primitives-package-version-placement.md`. Empirical verification at swift-version-primitives v1.0.0 write time is REQUIRED per Axiom 4 |

**This Research authorizes the package design but does NOT verify
the second-consumer hurdle empirically at write time** — that
verification is the future swift-version-primitives v1.0.0
dispatch's responsibility. This Research's recommendation is "the
package SHOULD exist with this design IF Axiom 4 clears at that
dispatch's write time."

**v1.0.0 set**:

| Type | Backing | Notes |
|------|---------|-------|
| `Version.Semantic` | Struct (NOT typealias) — 5 components, full SemVer 2.0.0 spec | Sendable, Hashable, Equatable, Comparable, Codable, CustomStringConvertible, LosslessStringConvertible |
| `Version.Semantic.Identifier` | `enum { case alphanumeric(Swift.String); case numeric(Swift.UInt) }` | Prerelease identifier precedence per SemVer 2.0.0 §11.4 |
| `Version.Semantic.Error` | `enum: Swift.Error` | Typed throws cases (nonASCII, invalidVersionCoreIdentifiersCount, etc.) — mirrors swiftlang TSCUtility.VersionError |

**Optional v1.0.0 addition (if cheap)**:

- `Version.Semantic.Range` — typed range (typealias for
  `Range<Version.Semantic>` or dedicated struct). Verify second
  consumer at the dispatch.
- `Version.Semantic.Set` — algebraic version-set (`.any | .empty |
  .exact | .range | .union`). Mirrors SwiftPM's internal
  `VersionSetSpecifier`. Defer to v1.1.0 unless a consumer
  surfaces.

**Future variants (per framework Axiom 3 — additive)**:

| Variant | When |
|---------|------|
| `Version.Calendar` (CalVer) | When a consumer surfaces calendar versioning need |
| `Version.Tools` (SwiftPM tools-version subset) | When manifest tooling needs typed tools-version |
| `Version.Date` | When a consumer needs date-keyed versioning |

**Convenience typealias** (POST-v1.0.0, optional, additive per
framework Axiom 1's typealias carve-out):

```swift
public typealias SemVer = Version.Semantic
```

User-confirmed direction; lands only if a specific consumer
surfaces ergonomic demand. The primary declaration is
`Version.Semantic`.

### Q4 — Validation rules sourcing

[Verified: 2026-05-12 against `swiftlang/swift-package-manager@main
e1ced73eb`]. Inherited from superseded parent doc Q4 unchanged:

**Two-tier upstream validation**:

1. **Strict (SE-0292 codified)** — `PackageIdentity.Scope` /
   `PackageIdentity.Name` at
   `Sources/PackageModel/PackageIdentity.swift:130-294`. Regex per
   SE-0292:
   - Scope: `\A[a-zA-Z\d](?:[a-zA-Z\d]|-(?=[a-zA-Z\d])){0,38}\z`
     (1-39 chars)
   - Name: `\A[a-zA-Z0-9](?:[a-zA-Z0-9]|[-_](?=[a-zA-Z0-9])){0,99}\z`
     (1-100 chars)
   Used for registry identifiers, NOT manifest-level names.

2. **Permissive — emptiness-only checks** for manifest-level
   `Package(name:)`, product names, target names. Per
   `Sources/PackageLoading/PackageBuilder.swift:1576-1578` (product),
   `:837-844` (target), and `Sources/PackageModel/Manifest/Manifest.swift:31`
   (package `displayName` unvalidated).

**Swift Evolution governance**: only **SE-0292** codifies SemVer +
registry identifier rules. No SE proposal codifies manifest-level
name validity beyond emptiness.

**Stability**: zero diff in the four key validator files since
SE-0292 landed (Apr 2021). Effectively frozen.

**Architectural mismatch (carried from superseded parent)**:
institute typed `Package.Name` / `Product.Name` / `Target.Name` at
v1.0.0 mirror the PERMISSIVE tier (manifest-level), NOT the
STRICT tier (registry). Registry-form `Package.Identity` is
deferred to a future version per Axiom 4.

### Q5 — Validation timing

Inherited from superseded validation-timing doc unchanged:

**For `Package.Name` / `Product.Name` / `Target.Name`**: pure
typealias, NO construction-time validation. Matches `Lint.Rule.ID`
precedent. Compatible with institute product-name convention
including spaces (`"Manifest Primitives"`,
`"Tagged Primitives Standard Library Integration"`). Future
v1.1.0+ MAY add a companion `.Strict` validating wrapper if a
consumer surfaces real demand.

**For `Version.Semantic`**: struct with throwing init, typed
throws (`Version.Semantic.Error`). Matches `Glob.Pattern` precedent
shape. The Version domain DOES have a strict spec (semver.org +
SE-0292's amendment for SwiftPM tools-version); construction-time
validation enforces it. Different choice than Package.Name because
the underlying invariant IS materially different.

### Q6 — Conformances

**`Package.Name` / `Product.Name` / `Target.Name`** (typealiases
over Tagged) — all inherited:

| Protocol | Source |
|----------|--------|
| `Sendable` | Tagged main target (conditional on String) |
| `Hashable` | Tagged main target |
| `Equatable` | Tagged main target |
| `Comparable` | Tagged main target |
| `Codable` | Tagged main target |
| `CustomStringConvertible` | Tagged main target |
| `ExpressibleByStringLiteral` | Tagged Primitives Standard Library Integration target |

No re-declaration needed in `swift-package-primitives`.

**`Version.Semantic`** — explicit conformances:

| Protocol | Notes |
|----------|-------|
| `Sendable` | Hand-rolled (struct) |
| `Hashable` | Hand-rolled (note SemVer 2.0.0 §10 build-metadata-excluded equality per swiftlang TSCUtility precedent) |
| `Equatable` | Custom `==` matching the §10 precedence rule |
| `Comparable` | Hand-rolled — implements SemVer 2.0.0 §11 precedence (numeric vs alphanumeric prerelease comparison) |
| `Codable` | Hand-rolled, JSON round-trip via underlying string form |
| `CustomStringConvertible` | Canonical SemVer 2.0.0 spelling |
| `LosslessStringConvertible` | Failable `init?(_ versionString: String)` |
| `ExpressibleByStringLiteral` | Defer to a separate SLI target (or omit if Tagged SLI pattern unavailable here since Version.Semantic is a struct not a Tagged typealias) |

### Q7 — Heritage posture

Inherited unchanged: **greenfield with SE-0292 + semver.org
citations** in DocC. Zero borrowed lines.

- `swift-package-primitives` v1.0.0 ships typealiases only — no
  validation logic, no upstream code to borrow.
- `swift-version-primitives` v1.0.0 ships `Version.Semantic`
  validation — mirrored from semver.org spec text + SE-0152 patch-
  optional amendment, NOT from swiftlang source. Spec-mirroring per
  `[API-NAME-003]`, not source borrowing under `[HERITAGE-*]`.
- Both packages ship clean Apache 2.0 LICENSE (institute standard).

### Q8 — Tier classifications

| Package | Research Tier | Primitives DAG Tier |
|---------|--------------|--------------------|
| swift-package-primitives | Tier 2 cross-package per `[RES-020]` | Tier 1 (single dep on swift-tagged-primitives which is Tier 0) |
| swift-version-primitives | Tier 2 cross-package per `[RES-020]` | Tier 0 (zero primitives deps — Version.Semantic is a struct not a Tagged-wrapper) OR Tier 1 if it adopts Tagged for variant tagging |

This Research doc itself: **Tier 2 cross-package** (same
classification as superseded parent).

### Q9 — Cross-consumer enumeration

Carried from superseded parent Q9 + target-name companion:

**swift-package-primitives consumers** (3 identified):

| Layer | Package | Use |
|-------|---------|-----|
| L1 | `swift-manifest-primitives` `Manifest.Dependency` | Package.Name (field `name`), Product.Name (field `product`) [Verified: 2026-05-12] |
| L3 | `swift-foundations/swift-manifests` | Transitive via `Manifest.Dependency` |
| L3 | `swift-foundations/swift-linter` | Audit closures F-A2.11 / F-A3.4 / F-A3.5 [Verified: 2026-05-12] |
| L3 | `swift-foundations/swift-dependency-analysis` | Target.Name (Package.Manifest.Target.name, Package.analyze.swift path-construction) [Verified: 2026-05-12]; will become extension of the L1 `Package` namespace post-promotion |

**swift-version-primitives consumers** (verified candidates;
empirical write-time verification deferred to that dispatch):

- swift-package-primitives v1.1.0+ (dependency-requirement
  composition)
- Swift Package Index forks
- release-readiness tooling under `swift-institute/Scripts/`
- registry-aware tooling
- NPM / Cargo bridge packages (cross-ecosystem)

Per Axiom 4, the swift-version-primitives dispatch MUST verify
these empirically at its write time.

## Outcome

**Status**: v1.0.0 RECOMMENDATION per [RES-003a]. Principal flips
to DECISION on sign-off.

**Recommended design**:

### Package 1: `swift-package-primitives`

| Aspect | Recommendation |
|--------|----------------|
| Package name | `swift-package-primitives` |
| Namespace | `Package.*`, `Product.*`, `Target.*` (top-level siblings) |
| v1.0.0 types | `Package.Name`, `Product.Name`, `Target.Name` (pure typealiases over Tagged) |
| Validation | None at construction; mirror upstream permissive tier |
| Conformances | Inherited from Tagged main + SLI |
| Heritage | Greenfield, SE-0292 DocC citation |
| Research Tier | Tier 2 |
| Primitives DAG Tier | Tier 1 (dep: swift-tagged-primitives) |

**File layout**:

```
swift-package-primitives/
├── Package.swift
├── README.md
├── LICENSE.md
├── Sources/
│   └── Package Primitives/
│       ├── Package.swift              (public enum Package {})
│       ├── Package.Name.swift         (typealias)
│       ├── Product.swift              (public enum Product {})
│       ├── Product.Name.swift         (typealias)
│       ├── Target.swift               (public enum Target {})
│       └── Target.Name.swift          (typealias)
└── Tests/
    └── Package Primitives Tests/
        ├── Package.Name Tests.swift
        ├── Product.Name Tests.swift
        └── Target.Name Tests.swift
```

**Canonical type declaration**:

```swift
// Package.Name.swift
import Tagged_Primitives

/// A typed, stable identifier for a Swift package's manifest-level
/// `name:` field.
///
/// `Package.Name` is `Tagged<Package, Swift.String>` — the value is
/// a `String` but its type carries the package-identity at compile
/// time. Mixing package names with product names or target names is
/// rejected at the type system, not at runtime.
///
/// Construction via `ExpressibleByStringLiteral` shipped by
/// `swift-tagged-primitives`'s standard-library-integration target:
///
/// ```swift
/// let name: Package.Name = "swift-primitives"
/// ```
///
/// Validation: none at construction time. Upstream SwiftPM enforces
/// only emptiness for manifest-level names; institute consumers
/// inherit the same permissive contract.
extension Package {
    public typealias Name = Tagged<Package, Swift.String>
}
```

Identical shape for `Product.Name` and `Target.Name`.

### Package 2: `swift-version-primitives`

| Aspect | Recommendation |
|--------|----------------|
| Package name | `swift-version-primitives` |
| Namespace | `Version.*` |
| v1.0.0 types | `Version.Semantic` (struct), `Version.Semantic.Identifier` (enum), `Version.Semantic.Error` (enum) |
| Validation | Throwing init at construction; typed throws |
| Conformances | Hand-rolled Sendable/Hashable/Equatable/Comparable/Codable/CustomStringConvertible/LosslessStringConvertible |
| Heritage | Greenfield, semver.org + SE-0292 + SE-0152 DocC citations |
| Research Tier | Tier 2 |
| Primitives DAG Tier | Tier 0 or 1 |

**File layout**:

```
swift-version-primitives/
├── Package.swift
├── README.md
├── LICENSE.md
├── Sources/
│   └── Version Primitives/
│       ├── Version.swift                          (public enum Version {})
│       ├── Version.Semantic.swift                 (struct)
│       ├── Version.Semantic.Identifier.swift      (enum)
│       └── Version.Semantic.Error.swift           (enum)
└── Tests/
    └── Version Primitives Tests/
        └── Version.Semantic Tests.swift
```

**Canonical type declaration**:

```swift
// Version.Semantic.swift

/// Semantic Versioning 2.0.0 typed representation.
///
/// Implements the spec at https://semver.org/ — five components:
/// MAJOR.MINOR.PATCH[-prerelease][+build].
///
/// Construction via the throwing init validates against the spec's
/// character-class and structure rules. Equality and comparison
/// follow §11 precedence rules (build metadata excluded per §10).
///
/// ```swift
/// let v = try Version.Semantic("1.2.3-alpha.1+sha.abc123")
/// ```
extension Version {
    public struct Semantic: Sendable, Hashable, Comparable, Codable, CustomStringConvertible, LosslessStringConvertible {
        public let major: Swift.UInt
        public let minor: Swift.UInt
        public let patch: Swift.UInt
        public let prereleaseIdentifiers: [Identifier]
        public let buildMetadataIdentifiers: [Swift.String]

        public init(
            major: Swift.UInt,
            minor: Swift.UInt,
            patch: Swift.UInt,
            prereleaseIdentifiers: [Identifier] = [],
            buildMetadataIdentifiers: [Swift.String] = []
        ) {
            self.major = major
            self.minor = minor
            self.patch = patch
            self.prereleaseIdentifiers = prereleaseIdentifiers
            self.buildMetadataIdentifiers = buildMetadataIdentifiers
        }

        public init(_ versionString: Swift.String) throws(Error) {
            // Spec validation per semver.org
            // ...
        }

        public init?(_ versionString: Swift.String) {
            // LosslessStringConvertible failable init
            // ...
        }

        // Comparable, Equatable, CustomStringConvertible, Codable implementations
        // ...
    }
}
```

### Out of scope for this Research

- **Authoring either package** — design only. Package authoring is
  a downstream dispatch (one per package, sequenced as
  swift-package-primitives FIRST, then swift-version-primitives
  pending Axiom 4 verification).
- **Migrating downstream consumers** (swift-foundations/swift-linter
  closures F-A2.11 / F-A3.4 / F-A3.5; swift-manifest-primitives
  field-typing; swift-dependency-analysis L3 Package namespace
  removal). All separate downstream dispatches.
- **Promoting framework to skill** — out of scope; surface via
  skill-lifecycle per the framework Research's recommendation.

### Recommended next dispatches (one-line each)

1. **swift-package-primitives v1.0.0 package-authoring brief** —
   implement Package.swift + 6 source files + 3 test files per the
   file layout above; ship to a new `swift-primitives/swift-package-primitives`
   repo.
2. **swift-version-primitives v1.0.0 design Research** — verify
   Axiom 4 second-consumer empirically at write time, then either
   recommend the package-authoring or defer.
3. **swift-dependency-analysis L3 Package-namespace migration** —
   remove `enum Package {}` from
   `swift-dependency-analysis/Sources/Dependency Analysis/Package.swift`;
   replace with `import Package_Primitives`; convert sub-types to
   `extension Package`.
4. **swift-foundations/swift-linter audit-closure migration
   (F-A2.11 / F-A3.4 / F-A3.5)** — type `Lint.Dependency.products`
   as `[Product.Name]` and `Lint.SingleFile.PackageDependency.name`
   as `Package.Name`. NOTE per user: swift-foundations/swift-linter
   is being worked on; the dispatch should coordinate with the
   in-flight work.

### Open questions surfaced for principal sign-off

1. Confirm flat top-level shape (`Package.*` / `Product.*` /
   `Target.*` as siblings) over nested (`Package.Product.*` /
   `Package.Target.*`).
2. Confirm `Version.Semantic` as struct (validating) over
   `Tagged<Version.Semantic, Swift.String>` typealias (non-
   validating). The current recommendation breaks symmetry with
   the Package/Product/Target trio because Version has a strict
   spec where Package/Product/Target manifest-level names do not.
3. Confirm `swift-version-primitives` v1.0.0 should ship Range +
   Set algebra alongside Version.Semantic, OR ship only the bare
   Version.Semantic + Identifier + Error.
4. Confirm whether the framework Research and this design Research
   should be promoted from Tier 2 to Tier 3 ecosystem-wide given
   the framework's normative scope.

### Pre-existing gaps surfaced en passant

- `swift-foundations/swift-linter/Research/_index.json` stale per
  superseded addendum (carried forward unchanged).
- L3 `swift-dependency-analysis` declares `public enum Package {}`
  that must be removed in the consumer-migration dispatch to avoid
  collision with the new L1 declaration.
- Existing institute namespaces with potential abbreviation debt
  (`IO`, possibly others) — flagged for audit dispatch per framework
  Research follow-up recommendations.

## References

### Framework (companion)

- `swift-institute/Research/2026-05-12-typed-identifier-naming-framework.md`
  v1.0.0 RECOMMENDATION — the framework this design applies.

### Superseded predecessors

| File | Status |
|------|--------|
| `2026-05-12-swift-spm-primitives-design.md` v1.0.0 (commit `14df127`) | SUPERSEDED — substantive recommendations carried forward under framework-corrected names |
| `2026-05-12-swift-spm-primitives-validation-timing.md` v1.0.0 (commit `adb87d8`) | SUPERSEDED — Option A typealias-without-validation conclusion carried forward |
| `2026-05-12-swift-spm-primitives-target-name-v1.md` v1.0.0 (commit `adb87d8`) | SUPERSEDED — Target.Name inclusion + swift-dependency-analysis citation carried forward |
| `2026-05-12-swift-semver-primitives-package-version-placement.md` v1.0.0 (commit `adb87d8`) | SUPERSEDED — separate-package recommendation carried forward under swift-version-primitives name |

### Primary inputs

- Audit: `swift-foundations/swift-linter/Research/2026-05-12-typed-primitive-adoption-audit.md` v1.0.0 TRIAGE
- Addendum: `swift-foundations/swift-linter/Research/2026-05-12-typed-primitive-adoption-audit-addendum.md` v1.0.0 RECOMMENDATION (commit `b27d99a`)

### Institute precedents (per [RES-019] / [RES-026])

[Verified: 2026-05-12]:

- `swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.swift:2`
  — `public enum Package {}` at L3 (target for promotion to L1).
- `swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.Manifest.Target.swift:6`
  — Target.name second-consumer site.
- `swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.analyze.swift:60,80,82`
  — Target.name path-construction + analysis identity.
- `swift-primitives/swift-manifest-primitives/Sources/Manifest Primitives/Manifest.Dependency.swift:24-56`
  — Package.Name + Product.Name second-consumer site (L1).
- `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.ID.swift:12-28`
  — typealias-over-Tagged precedent.
- `swift-primitives/swift-glob-primitives/Package.swift:1-85`
  — L1 bootstrap Package.swift shape (2026-05-02).

### Upstream sources (per [RES-026])

[Verified against `swiftlang/swift-package-manager@main e1ced73eb`
2026-05-12]:

- `Sources/PackageModel/PackageIdentity.swift:130-294` — SE-0292
  Scope/Name validators.
- `Sources/PackageModel/Manifest/Manifest.swift:31` — `displayName`
  unvalidated.
- `Sources/PackageLoading/PackageBuilder.swift:837-844,1576-1578`
  — Target/Product emptiness checks.
- `Sources/Runtimes/PackageDescription/Version.swift:38-93` —
  PackageDescription DSL Version (mirrorable shape).
- `swift-tools-support-core/Sources/TSCUtility/Version.swift:49-167`
  — TSC's typed-throws Version implementation.

### Swift Evolution

- [SE-0152 — Package Manager Tools Version](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0152-package-manager-tools-version.md)
- [SE-0292 — Package Registry Service](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0292-package-registry-service.md)
- [SE-0450 — SwiftPM Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md)

### Cross-ecosystem prior art

- [Rust `semver` crate](https://docs.rs/semver/latest/semver/)
- [Node.js `node-semver`](https://github.com/npm/node-semver)
- [semver.org 2.0.0 specification](https://semver.org/)

### Skills cited

- `[API-NAME-001]` Nest.Name
- `[API-NAME-001a]` Single-type-no-namespace
- `[API-NAME-002]` No compound identifiers
- `[API-NAME-003]` Specification-mirroring
- `[API-NAME-010]` No synthesized `*Tag` suffixes
- `[API-NAME-012]` No `impl`/`obj`/`inst` abbreviations (framework
  Axiom 1 generalizes)
- `[API-ERR-001]` Typed throws
- `[API-IMPL-005]` One type per file
- `[PKG-NAME-001]` Noun-form package naming
- `[PRIM-FOUND-001]` No Foundation imports
- `[PRIM-NAME-001]` `-primitives` suffix
- `[PRIM-ARCH-002]` Downward dependencies only
- `[HERITAGE-*]` Heritage trigger threshold (not crossed)
- `[RES-003]` Document structure
- `[RES-009]` Multi-option analysis
- `[RES-018]` Premature primitive (framework Axiom 4)
- `[RES-020]` Research tiers
- `[RES-021]` Prior art survey
- `[RES-022]` Structural correctness over diff size
- `[RES-023]` Empirical-claim verification
- `[RES-026]` Citations
