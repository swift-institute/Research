# Swift SemVer Primitives — Package.Version Placement

<!--
---
version: 1.0.0
last_updated: 2026-05-12
status: SUPERSEDED
tier: 2
scope: cross-package
supersededBy: 2026-05-12-swift-package-and-version-primitives-design.md
---
-->

> **SUPERSEDED 2026-05-12** by
> [`2026-05-12-swift-package-and-version-primitives-design.md`](2026-05-12-swift-package-and-version-primitives-design.md)
> v1.0.0 RECOMMENDATION, applying the framework codified in
> [`2026-05-12-typed-identifier-naming-framework.md`](2026-05-12-typed-identifier-naming-framework.md).
>
> The substantive recommendation (Option C — separate package owns
> the versioning primitives; cross-ecosystem reuse rationale via
> Rust semver / node-semver / pub_semver precedent; SE-0292
> validation reference) survives in the successor §Q3 +
> swift-version-primitives section. Naming references throughout
> this doc (`swift-semver-primitives` package name, `SemVer.*`
> namespace, `SemVer.Version` type) are SUPERSEDED — both
> "swift-semver" and "SemVer" are abbreviations of "Semantic
> Versioning" forbidden by framework Axiom 1. Corrected: package
> `swift-version-primitives`, namespace `Version.*`, primary type
> `Version.Semantic` (per user explicit guidance; the `SemVer`
> typealias MAY land post-v1.0.0 as additive convenience per
> framework Axiom 1's typealias carve-out).

## Context

The parent design Research
(`2026-05-12-swift-spm-primitives-design.md` v1.0.0 RECOMMENDATION,
commit `14df127`) recommended deferring `SwiftPM.Package.Version` to
a future `swift-semver-primitives` package rather than shipping it
inside `swift-spm-primitives`. The rationale was one paragraph in
Q3:

> SemVer is a cross-ecosystem domain (NPM, Cargo, Maven all use it);
> conflating it with SwiftPM-specific primitives mis-models the
> spec. Future `swift-semver-primitives` is the right home.

That paragraph is directionally correct but light on substantiation.
The placement decision has downstream consequences:

1. Whether the institute owns a standalone Swift SemVer library
   alongside any future package-manager primitives.
2. Whether `swift-spm-primitives` v1.x.x would `import
   SemVer_Primitives` for its dependency-resolution surface, or
   inline a Swift-only Version type.
3. Whether community Swift SemVer packages (mxcl/Version,
   SwiftPackageIndex/SemanticVersion, sersoft-gmbh/semver) become
   reference points or competing surface.

This Research doc isolates the placement question and substantiates
the deferral with cross-ecosystem prior art + concrete naming
recommendations.

**Trigger**: open question #3 surfaced in the parent doc's Outcome
section ("confirm `SwiftPM.Package.Version` defers to a future
`swift-semver-primitives` package rather than shipping here").

**Internal research consulted per [HANDOFF-013] / [RES-019]**:

- Verified [Verified: 2026-05-12] that NO existing
  `swift-version-primitives` or `swift-semver-primitives` package
  exists in `/Users/coen/Developer/swift-primitives/`.
- Verified [Verified: 2026-05-12] that NO prior research exists on
  SemVer typing in `swift-institute/Research/` (greenfield).

## Question

Where should the typed Swift representation of a SemVer 2.0.0
version live, given that:

1. SwiftPM's `Package.Dependency.SourceControlRequirement` /
   `RegistryRequirement` consumes `Version` values.
2. SwiftPM internally ships TWO duplicate Version implementations
   (PackageDescription DSL + TSCUtility).
3. The community has at least four published Swift SemVer libraries.
4. No SE proposal codifies SemVer rules beyond SE-0152's reference
   to semver.org.

Should `SwiftPM.Package.Version` ship inside `swift-spm-primitives`
(treating SemVer as a SwiftPM detail), or in a separate
`swift-semver-primitives` package (treating SemVer as a cross-
ecosystem spec)?

## Analysis

### Prior art

**Cross-ecosystem package-manager precedent** (all separate-from-PM
shapes; per agent survey 2026-05-12):

| Ecosystem | SemVer library | Relationship to package manager | Citation |
|-----------|---------------|---------------------------------|----------|
| Rust | `semver` crate (docs.rs/semver) | Separate crate; cargo consumes it | [docs.rs/semver](https://docs.rs/semver/latest/semver/) |
| Node.js | `node-semver` (npm package `semver`) | Separate npm package; npm consumes it | [github.com/npm/node-semver](https://github.com/npm/node-semver) |
| Dart | `pub_semver` | Separate Dart pub package; pub consumes it | (referenced in SwiftPM `VersionSetSpecifier.swift:370`) |

The pattern is **unanimous**: SemVer parsing, typing, and
range-algebra are published as freestanding libraries separate from
the package manager. The package manager imports the SemVer library;
the SemVer library does not depend on the package manager. SwiftPM
is the outlier — it bundles two duplicate Version implementations
inside its own toolchain.

**Swift-ecosystem precedent**:

| Package | Stars | Surface | Foundation-free? |
|---------|------:|---------|:---:|
| `swiftlang/swift-package-manager` `PackageDescription.Version` | (in-tree) | struct (5 components), Comparable, ExpressibleByStringLiteral, side-channel error reporting | ✓ |
| `swiftlang/swift-tools-support-core` `TSCUtility.Version` | (in-tree) | struct (5 components), throwing init, VersionError enum, Codable, JSON | depends on TSC infra |
| `mxcl/Version` | 336 | Acknowledged fork of swiftlang's Version | (likely yes) |
| `SwiftPackageIndex/SemanticVersion` | 70 | Custom prerelease enum (alphanumeric/numeric); single-string prerelease/build fields | (likely yes) |
| `sersoft-gmbh/semver` | 15 | mutable major/minor/patch with willSet asserts; uses `Foundation.CharacterSet` | ✗ — imports Foundation |
| `gwynne/swift-semver` | 13 | struct implementation | unknown |

[Verified: 2026-05-12 via subagent survey]. None has critical-mass
adoption parity with SwiftPM's internal Version; community libraries
exist precisely because SwiftPM's is not consumable outside the
manifest DSL.

**Swift Evolution governance**: No SE proposal formally codifies
SemVer rules. SE-0152 (Package Manager Tools Version) references
semver.org with one amendment (patch component optional, defaults to
0). [Verified: 2026-05-12 via subagent].

**SwiftPM's own duplication evidence**: the existence of TWO Version
structs inside swiftlang's monorepo (PackageDescription DSL + TSC
utility) is direct evidence that conflating SemVer with the package
manager has already cost SwiftPM something. SwiftPM internals
(`Basics`, `PackageGraph`, etc.) `import struct TSCUtility.Version`
rather than the DSL Version. [Verified: 2026-05-12 via subagent].

### Options

#### Option A — `SwiftPM.Package.Version` inside `swift-spm-primitives`

**Description**: v1.x.x of `swift-spm-primitives` adds a typed
`SwiftPM.Package.Version` shape (struct or `Tagged<...>`) without
referencing any external SemVer package.

**Advantages**:

- One package owns the full SwiftPM-identifier surface (names +
  version).
- No new package introduced; smaller ecosystem footprint.

**Disadvantages**:

- Mis-models the spec: SemVer is a cross-ecosystem standard, not a
  SwiftPM detail. Consumers in non-SwiftPM contexts (NPM bridge,
  Cargo bridge, Swift Package Index, release tooling, registry
  tooling) cannot use `SwiftPM.Package.Version` without importing
  `SwiftPM Primitives` — a naming smell that telegraphs the design
  error.
- Repeats SwiftPM's own duplication mistake: the moment any other
  ecosystem package needs SemVer (release-readiness scripts,
  package-graph analysis, version-range tooling), it would either
  (a) depend on `swift-spm-primitives` to get the type (wrong
  semantics — SemVer is not SwiftPM-specific), or (b) define its
  own duplicate Version type. Either path is suboptimal.
- Per [API-NAME-003] spec-mirroring: the spec is "SemVer 2.0.0", not
  "SwiftPM.Package.Version". Naming the type after the spec it
  implements is the institute's convention.

#### Option B — Separate `swift-semver-primitives` package

**Description**: A new L1 primitives package
`swift-semver-primitives` provides `SemVer.Version` (and adjacent
types: `SemVer.Version.Range`, `SemVer.Version.Set`,
`SemVer.Error`). `swift-spm-primitives` v1.0.0 does NOT ship a
Version type; v1.1.0+ (when a consumer surfaces) may add typed
SwiftPM-specific dependency-requirement composition (e.g.,
`SwiftPM.Package.Dependency.Requirement = .exact(SemVer.Version) |
.range(Range<SemVer.Version>) | .revision(GitRevision) |
.branch(GitBranch)`) by importing `SemVer Primitives`.

**Advantages**:

- Spec-mirroring per [API-NAME-003]: namespace `SemVer` matches the
  spec's own short name. Package name `swift-semver-primitives`
  matches `-primitives` suffix per [PRIM-NAME-001].
- Cross-ecosystem-correct: SemVer is the cross-ecosystem standard;
  the institute's SemVer package can be consumed by SwiftPM tooling,
  NPM bridges, registry tooling, Swift Package Index forks, etc.,
  without dragging in SwiftPM-specific surface.
- Matches Rust / Node / Dart precedent verbatim.
- Avoids replaying SwiftPM's internal duplication. The institute
  ships SemVer once; SwiftPM-specific composition uses it; future
  consumers reuse it.
- Allows `swift-spm-primitives` v1.0.0 to ship at minimal scope
  (typed names only), with version typing deferred until a real
  consumer needs it.

**Disadvantages**:

- One additional package in the ecosystem (more repos, more CI, more
  metadata).
- The Version-typing question moves to a separate dispatch (this
  Research recommends but does not author the new package).

#### Option C — Hybrid: SemVer typing in `swift-semver-primitives`, SwiftPM-specific version-RANGE shapes in `swift-spm-primitives`

**Description**: Option B's split, plus an additional principle —
SwiftPM-specific composition over `SemVer.Version` (e.g.,
`Package.Dependency.Requirement`'s `.exact(Version) | .range(Range<Version>) |
.revision | .branch`) lives in `swift-spm-primitives` v1.1.0+,
NOT in `swift-semver-primitives`. The base `SemVer.Version` lives in
`swift-semver-primitives`; the SwiftPM-flavored requirement enum
lives where SwiftPM-specific shapes belong.

**Advantages**:

- Same as Option B with an explicit boundary: SemVer-pure shapes in
  the SemVer package; SwiftPM-flavored compositions in the SwiftPM
  package.

**Disadvantages**:

- Slightly more architectural cleanup work spelled out, but no
  meaningful disadvantage vs Option B.

### Comparison

**Criteria**:

1. Spec-mirroring per [API-NAME-003]
2. Cross-ecosystem precedent alignment (Rust / Node / Dart)
3. SwiftPM internal duplication avoidance
4. Naming hygiene (does the namespace match what the type IS?)
5. [PRIM-FOUND-001] no-Foundation feasibility
6. Future consumer breadth (Swift Package Index, release tooling,
   etc.)
7. Ecosystem package footprint (number of repos)
8. v1.0.0 swift-spm-primitives scope discipline

| Criterion | A (inline) | B (separate) | C (separate + SwiftPM-shapes) |
|-----------|:---:|:---:|:---:|
| Spec-mirroring | ✗ | ✓ | ✓ |
| Cross-ecosystem precedent fit | ✗ | ✓ | ✓ |
| Avoids SwiftPM-style duplication | ✗ | ✓ | ✓ |
| Naming hygiene | ✗ ("SwiftPM.Package.Version" misnames a SemVer 2.0.0 value) | ✓ | ✓ |
| [PRIM-FOUND-001] feasible | ✓ | ✓ (swiftlang's Version is Foundation-free; mirrorable) | ✓ |
| Future consumer breadth | restricted to SwiftPM-flavored consumers | broad | broad |
| Ecosystem package footprint | smaller | one more repo | one more repo |
| v1.0.0 swift-spm-primitives scope discipline | scope creep | clean | clean |

**[RES-018] check for `swift-semver-primitives`**:

The premature-primitive rule requires a second-consumer hurdle for
any new ecosystem primitive. For `swift-semver-primitives`:

| Type | First consumer | Second consumer | Hurdle cleared? |
|------|----------------|-----------------|:---:|
| `SemVer.Version` | `swift-spm-primitives` v1.1.0+ (when typed dependency-requirement surface lands) | Swift Package Index (parses versions from registry, currently uses SwiftPackageIndex/SemanticVersion) OR release-readiness tooling under `swift-institute/Scripts/` (which currently shell-parses tags) | ✓ — multiple potential consumers; the question is verified-now vs verified-later |

The hurdle is conceptually clear but not empirically verified at
write time — `swift-spm-primitives` itself does not yet exist; the
Swift Package Index would adopt only after the institute ships a
viable replacement; release-readiness tooling could migrate. To
honor [RES-018] empirically, the second-consumer evidence must be
verified at the moment `swift-semver-primitives` v1.0.0 ships, not
at this Research's write time.

**This Research does NOT author swift-semver-primitives. It
recommends DEFERRAL of the Version-typing question to a separate
future dispatch, which itself must satisfy [RES-018] at its own
write time**.

### Theoretical grounding per [RES-021] (contextualization step)

The cross-ecosystem precedent surveyed (Rust / Node / Dart) shows
universal adoption of separate-from-PM SemVer packages. Per
[RES-021], universal adoption does not imply universal necessity —
the institute MUST contextualize the proposed concept in its own
type system before classifying SwiftPM's bundled-Version pattern as
an anomaly.

Contextualization:

- Rust's `semver` crate: an external crate consumed by cargo. Cargo
  could in principle bundle a Version type internally; it chose not
  to. The reason cited in `semver` crate docs: "specifically
  intended to implement Cargo's interpretation of Semantic
  Versioning." The semantic match is exact; the separation is for
  reuse outside cargo.
- Node's `node-semver`: maintained by the npm team but published as
  a freestanding npm package. The same reasoning — separation
  enables reuse by anything in the Node.js ecosystem that handles
  versions.
- Dart's `pub_semver`: same shape.

In each case, the SemVer library serves the package manager AND
ecosystem-wide consumers. SwiftPM's internal duplication (DSL
`Version` + TSC `Version`) is the empirical evidence that the
bundled approach failed in Swift specifically — SwiftPM internals
chose to import a different Version than the one they ship for the
DSL.

In the institute's type system, `SemVer.Version` would be a
spec-mirroring namespace (`SemVer` is the spec's own short name)
with `Tagged`-or-struct backing. No Swift-specific cost from the
separation — the type is composable into `swift-spm-primitives` via
import, exactly as Rust composes `semver::Version` into cargo via
crate dep. The contextualization confirms the cross-ecosystem
pattern fits the institute's type system without compromise.

### Recommended `swift-semver-primitives` shape (FOR FUTURE DISPATCH)

NOT authored by this Research; surfaced here as the recommended
direction for the future dispatch that will design the package:

| Type | Description |
|------|-------------|
| `SemVer.Version` | The five-component struct: `major`, `minor`, `patch`, `prereleaseIdentifiers`, `buildMetadataIdentifiers`. Sendable, Hashable, Equatable, Comparable, Codable, CustomStringConvertible, LosslessStringConvertible. Throwing init with typed throws per [API-ERR-001]. |
| `SemVer.Version.Identifier` | `enum { case alphanumeric(String); case numeric(UInt) }` for prerelease precedence (§11.4 of SemVer 2.0.0). Matches SwiftPackageIndex/SemanticVersion's pattern. |
| `SemVer.Error` | Typed errors mirroring TSC's `VersionError` (nonASCII, invalidVersionCoreIdentifiersCount, nonNumericalOrEmptyVersionCoreIdentifiers, etc.). |
| `SemVer.Version.Range` | Semantic version range (alias for `Range<SemVer.Version>` or a dedicated struct, depending on the SE-0152 amendment's handling of lenient parsing). |
| `SemVer.Version.Set` | Algebraic version-set type: `.any | .empty | .exact(Version) | .range(Range<Version>) | .union([SemVer.Version.Set])`. Mirrors SwiftPM's internal `VersionSetSpecifier`. Optional in v1.0.0; deferred to v1.1.0+ if Range alone suffices. |

**Namespace choice**: `SemVer` over `SemanticVersion`:

- Spec-mirroring: semver.org uses "SemVer 2.0.0" as the canonical
  short form; "Semantic Versioning" is the spelled-out name.
- Concise at use sites: `SemVer.Version.Range` reads cleaner than
  `SemanticVersion.Range`.
- Matches `RFC_4122.UUID` / `ISO_32000.Page` precedent — spec
  namespaces use the spec's own short name.

**Optional naming refinement**: `SemVer_2_0_0.Version` — explicit
spec-version prefix matching `RFC_4122` precedent. The advantage is
explicit spec-version pinning; the disadvantage is verbose
use-sites. RECOMMEND `SemVer.Version` (current convention) over the
versioned-namespace shape; if SemVer 3.0.0 ever ships and is
incompatible, a separate `SemVer3` namespace can land additively.

## Outcome

**Status**: v1.0.0 RECOMMENDATION per [RES-003a]. Principal flips to
DECISION on sign-off.

**Recommended**: **Option C** — separate `swift-semver-primitives`
package owns `SemVer.Version` and adjacent types; `swift-spm-primitives`
v1.0.0 does NOT ship a Version type. `swift-spm-primitives` v1.1.0+
MAY add SwiftPM-flavored dependency-requirement composition (e.g.,
`SwiftPM.Package.Dependency.Requirement`) over `SemVer.Version`
imported from `swift-semver-primitives`.

**This Research does NOT author `swift-semver-primitives`**. It
recommends a future Research + package-authoring dispatch when:

1. A second consumer beyond `swift-spm-primitives` v1.1.0+ surfaces
   (release tooling, Swift Package Index fork, registry-aware tool,
   etc.), satisfying [RES-018]'s second-consumer hurdle at its own
   write time.
2. The principal authorizes the Research dispatch shape.

**Rationale (structural correctness per [RES-022])**:

1. Cross-ecosystem precedent is unanimous: Rust / Node / Dart all
   ship SemVer as separate-from-PM libraries. Bundling is the
   Swift-ecosystem anomaly.
2. Spec-mirroring per [API-NAME-003]: SemVer is the spec; the
   namespace mirrors the spec, not the consuming package manager.
3. SwiftPM's own internal duplication (DSL Version + TSC Version)
   is direct empirical evidence that bundling failed in Swift
   specifically.
4. v1.0.0 swift-spm-primitives ships at minimum scope (typed names
   trio); Version typing waits for its own future dispatch.

**Implementation gates for the future swift-semver-primitives
dispatch** (not actioned by this Research):

- Verify [RES-018] second-consumer empirically at dispatch write
  time. Candidates: Swift Package Index, release tooling under
  `swift-institute/Scripts/`, registry-aware tooling, NPM/Cargo
  bridge packages.
- Re-derive validation rules from SemVer 2.0.0 spec text per
  [API-NAME-003] (NOT from swiftlang/swift-package-manager source —
  the spec is the canonical source, with SE-0152's tools-version
  patch-optional amendment as a documented institute exception).
- Layer per [PRIM-FOUND-001]: Foundation-free. The swiftlang
  implementations are already Foundation-free; mirroring is
  achievable.
- Tier: primitives Tier 0 (zero primitives deps) or Tier 1
  (depends on swift-tagged-primitives if SemVer.Version is backed
  by Tagged) — TBD at dispatch time.

**What this Research authorizes vs defers**:

| Item | Authorized | Deferred |
|------|:---:|:---:|
| swift-spm-primitives v1.0.0 ships WITHOUT Version typing | ✓ | — |
| swift-spm-primitives v1.1.0+ imports swift-semver-primitives | — | ✓ (after swift-semver-primitives ships) |
| swift-semver-primitives package authoring | — | ✓ (future dispatch) |
| `SemVer.Version` design (struct shape, conformances, errors) | — | ✓ (future dispatch) |
| `SemVer.Version.Range` / `SemVer.Version.Set` design | — | ✓ (future dispatch) |
| Renaming if SemVer 3.0.0 ever ships incompatible | — | ✓ (additive `SemVer3` namespace possible) |

**Open questions surfaced for principal sign-off**:

1. Confirm Option C over Option B (the only difference is an
   explicit principle that SwiftPM-flavored composition goes in
   swift-spm-primitives, not in swift-semver-primitives).
2. Confirm `SemVer` namespace over `SemanticVersion` or
   `SemVer_2_0_0`. Current recommendation: `SemVer`.
3. Confirm the future swift-semver-primitives dispatch shape — full
   design Research first (mirroring the parent doc's pattern), or
   abbreviated brief given the well-trodden ground.

## References

### Parent design Research

- `swift-institute/Research/2026-05-12-swift-spm-primitives-design.md`
  v1.0.0 RECOMMENDATION (commit `14df127`) — parent doc; §Q3
  surfaces the open question this doc answers.

### Cross-ecosystem prior art (per [RES-021] / [RES-026])

[Verified: 2026-05-12 via subagent survey]:

- [SemVer 2.0.0 specification](https://semver.org/) — canonical spec
- [Rust `semver` crate](https://docs.rs/semver/latest/semver/) — cargo-domain separate library
- [npm `node-semver`](https://github.com/npm/node-semver) — npm-domain separate library
- Dart `pub_semver` — pub-domain separate library (referenced in
  SwiftPM's `Sources/PackageGraph/VersionSetSpecifier.swift:370`)

### swiftlang / Apple sources (per [RES-026])

Verified against `swiftlang/swift-package-manager@main e1ced73eb`
and `swiftlang/swift-tools-support-core` (2026-05-12):

- `Sources/Runtimes/PackageDescription/Version.swift:38-93` —
  PackageDescription DSL Version (5 components, Sendable,
  precondition-based validation).
- `Sources/Runtimes/PackageDescription/Version+StringLiteralConvertible.swift`
  — non-throwing parser with side-channel error reporting.
- `Sources/Runtimes/PackageDescription/PackageRequirement.swift:181-231`
  — SourceControlRequirement / RegistryRequirement / Range
  constructors.
- `Sources/PackageGraph/VersionSetSpecifier.swift:16-31` —
  algebraic version-set type (internal to SwiftPM resolver).
- `swift-tools-support-core/Sources/TSCUtility/Version.swift:49-167`
  — TSC's duplicate Version with typed throws (`VersionError`),
  Codable, JSON.

### Community Swift SemVer prior art

[Verified: 2026-05-12 via subagent search]:

- [`mxcl/Version`](https://github.com/mxcl/Version) — 336 stars,
  fork of swiftlang Version with negative-integer warning shim.
- [`SwiftPackageIndex/SemanticVersion`](https://github.com/SwiftPackageIndex/SemanticVersion)
  — 70 stars, powers Swift Package Index. Uses
  `PreReleaseIdentifier` enum for proper precedence.
- [`sersoft-gmbh/semver`](https://github.com/sersoft-gmbh/semver)
  — 15 stars, imports Foundation (incompatible with
  [PRIM-FOUND-001]).
- [`gwynne/swift-semver`](https://github.com/gwynne/swift-semver)
  — 13 stars (Vapor maintainer).

### Swift Evolution

- [SE-0152 — Package Manager Tools Version](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0152-package-manager-tools-version.md)
  — single reference to semver.org with patch-component-optional
  amendment.

### Companion Research

- `swift-institute/Research/2026-05-12-swift-spm-primitives-validation-timing.md`
  v1.0.0 RECOMMENDATION — addresses open question #1.
- `swift-institute/Research/2026-05-12-swift-spm-primitives-target-name-v1.md`
  v1.0.0 RECOMMENDATION — addresses open question #2.

### Skills cited

- [API-NAME-003] specification-mirroring names
- [API-ERR-001] typed throws
- [PRIM-FOUND-001] no Foundation imports
- [PRIM-NAME-001] -primitives suffix
- [RES-003] document structure
- [RES-009] multi-option analysis
- [RES-018] premature primitive anti-pattern (second-consumer
  hurdle)
- [RES-021] prior art survey (contextualization step)
- [RES-022] structural correctness over diff size
- [RES-026] citations
