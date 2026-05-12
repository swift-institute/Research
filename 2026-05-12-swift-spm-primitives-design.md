# swift-spm-primitives Design

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
> The substantive recommendations of this doc (typealias trio, no
> validation, greenfield + SE-0292 citation, Tier 2) survive in the
> successor. The naming choices (`SwiftPM.*` namespace,
> `swift-spm-primitives` package name) are SUPERSEDED — both violate
> the framework's Axioms 1 (no abbreviations) and 2 (generic-noun
> namespace). Corrected names: `Package.*` / `Product.*` / `Target.*`
> namespaces in `swift-package-primitives` package.

## Context

This research authors the design Research doc for a new L1 primitives
package `swift-spm-primitives` that types SwiftPM identifier concepts
(package name, product name, target name) using the institute's
`Tagged<Tag, Swift.String>` pattern.

**Trigger**: the typed-primitive adoption audit + addendum
(`swift-foundations/swift-linter/Research/2026-05-12-typed-primitive-adoption-audit.md` v1.0.0 TRIAGE,
`2026-05-12-typed-primitive-adoption-audit-addendum.md` v1.0.0 RECOMMENDATION)
dispositioned three Ambiguous findings as **Defer (primitives-gap)**:

| ID | Site | Current | Needed |
|----|------|---------|--------|
| F-A2.11 | `Lint.SingleFile.PackageDependency.swift:43` | `name: Swift.String` | typed SwiftPM package name |
| F-A3.4 | `Lint.Dependency.swift:38, 46, 60, 69, 80` | `products: [Swift.String]` | `[SwiftPM.Product.Name]` |
| F-A3.5 | `Lint.SingleFile.PackageDependency.swift:41, 43` | `name: Swift.String, products: [Swift.String]` | same shape |

The blocker on all three is "no L1 primitives package exists yet for
SwiftPM identifier shapes." This dispatch authors the design Research
doc closing the blocker — settling naming, scope, validation,
conformances, heritage posture, and tier classification before any
code lands.

**Parent context (pre-discussed, not re-litigated)**:

| Decision | Resolution | Source |
|----------|------------|--------|
| Generic `swift-package-primitives` vs SwiftPM-specific | SwiftPM-specific | "Package" is ambiguous across ecosystems |
| `Swift.Package.*` namespace | Rejected | `Swift` is the stdlib module name; introducing a top-level enum `Swift` shadows the module |
| Import `PackageDescription` directly | Rejected | PackageDescription is toolchain-scoped, imports Foundation, wrong shape, surface bloat |

**Internal research consulted per [HANDOFF-013] / [RES-019]**:

- `decimal-carrier-integration.md` — codifies the phantom-tag naming
  convention: real domain names, not synthesized `*Tag` suffixes.
  Load-bearing for Q1 and the typed-identifier shape decision.
- `carrier-ecosystem-application-inventory.md` — comprehensive survey
  of `Tagged<Tag, Base>` adoption ecosystem-wide.
- `cardinal-ordinal-vector-enforcement-design.md` — typed-primitive
  enforcement pattern; companion design rationale.
- `glob-l1-vocabulary-relocation.md` — bootstrap design for the most
  recent L1 primitives package (`swift-glob-primitives`, 2026-05-02).
  Direct precedent for package structure and layer placement.
- `github-metadata-harmonization.md` — package naming conventions:
  L1 primitives use `swift-{noun}-primitives`; description format
  requires no compound identifiers per `[API-NAME-001]`.
- `spm-nested-package-publication.md` — validates the SwiftPM
  architectural model; orthogonal but ratifies SwiftPM as the
  modeled domain.

No prior research covers `swift-spm-primitives` or `SwiftPM.*` typed
identifiers — this is greenfield work that extends rather than
duplicates [Verified: 2026-05-12].

## Question

What is the right shape of `swift-spm-primitives` v1.0.0?

The handoff brief enumerates nine sub-questions answered per [RES-009]:

1. Package name (validate or refine `swift-spm-primitives`)
2. Namespace (validate or refine `SwiftPM.*`)
3. v1.0.0 type set + roadmap
4. Validation rules sourcing (where do the rules live upstream?)
5. Validation timing (fail-fast vs deferred)
6. Conformance set
7. Heritage posture (greenfield vs upstream borrow)
8. Tier classification ([RES-020])
9. Cross-consumer enumeration (who else adopts this?)

## Analysis

### Q1 — Package name confirmation

**Options**:

| Option | Form | Pros | Cons |
|--------|------|------|------|
| A | `swift-spm-primitives` | Apple-canonical acronym; short; matches `swift-{noun}-primitives` convention per [PRIM-NAME-001] | "SPM" less common than "SwiftPM" in user-facing material |
| B | `swift-swiftpm-primitives` | Spec-mirroring per [API-NAME-003]; "SwiftPM" is the Apple-blessed product name | Slightly longer; double-word verbosity in the package path |
| C | `swift-package-manager-primitives` | Mirrors the upstream repo name (`swiftlang/swift-package-manager`) | Long; "package-manager" is compound; verbose |
| D | `swift-spm-package-primitives` | Foregrounds "package" as the modeled concept | Parent-rejected redundancy ("spm-package" repeats domain) |

**Criteria**: alignment with Apple's own naming, [PRIM-NAME-001]
`-primitives` suffix discipline, [PKG-NAME-005] shortest-natural-noun
rule, ecosystem recognizability.

**Comparison**:

| Criterion | A `swift-spm-primitives` | B `swift-swiftpm-primitives` | C `swift-package-manager-primitives` |
|-----------|:---:|:---:|:---:|
| Apple-canonical acronym match | ✓ ("SwiftPM" is canonical; "SPM" widely understood) | ✓ ("SwiftPM" matches exactly) | ✗ (long form not used in Apple material) |
| [PRIM-NAME-001] `-primitives` suffix | ✓ | ✓ | ✓ |
| [PKG-NAME-005] shortest-natural-noun | ✓ (3 chars) | ✗ (7 chars, doubled "swift") | ✗ (15 chars) |
| Path/disk-name readability | ✓ | mixed (`swift-swiftpm-…` reads awkwardly) | ✗ |
| Recognizability in ecosystem | ✓ ("spm" widely used in tooling, scripts) | ✓ | mixed |

**Outcome**: **`swift-spm-primitives`**. Apple uses both "SwiftPM" and
"SPM" — "SwiftPM" in prose, "SPM" in command-line tooling, file
extensions (.swiftpm), and scripts. The package-name slot is closer to
the latter context; the namespace will use the prose-form "SwiftPM"
(Q2). This split mirrors Apple's own pattern (e.g., the file
extension `.swiftpm` paired with the spoken/written "SwiftPM").

### Q2 — Namespace confirmation

**Options**:

| Option | Form | Pros | Cons |
|--------|------|------|------|
| A | `SwiftPM.*` | Apple-canonical prose form; spec-mirroring per [API-NAME-003]; no module shadow | "SwiftPM" is a CamelCase acronym — unusual in institute namespaces but well-precedented in Apple's own material |
| B | `SPM.*` | Shortest; matches package name | Less spec-mirroring; "SPM" not the Apple prose form |
| C | `PackageManager.*` | English-readable | Compound name per [API-NAME-001]; would need to decompose as `Package.Manager.*` which is awkward and would compete with a hypothetical generic `Package.*` namespace |
| D | `Package.Manager.*` | Nest.Name decomposition of option C | Forces a top-level `Package` enum that's overly generic (npm/deb/pip ambiguity); creates path-tax for every type |

**Criteria**: [API-NAME-001] no-compound-identifiers, [API-NAME-003]
spec-mirroring, top-level disambiguation across package ecosystems
(npm/deb/pip use "package" too), Apple-vs-Foundation precedent for
acronym namespaces.

**Precedent for CamelCase acronym namespaces in the institute**:

- `RFC_4122.UUID` (institute pattern from CLAUDE.md examples)
- `ISO_32000.Page` 
- `RFC_3986.URI`

The institute uses `RFC_<n>`, `ISO_<n>` for spec namespaces. "SwiftPM"
is not an RFC or ISO number — it's a brand-acronym that names the
domain itself. The closest existing precedent is `URLSession` /
`SwiftSyntax` (Apple-canonical acronyms within type names), but no
prior institute namespace is a CamelCase brand-acronym at the top
level.

**Comparison**:

| Criterion | A `SwiftPM.*` | B `SPM.*` | C `PackageManager.*` |
|-----------|:---:|:---:|:---:|
| [API-NAME-001] no compound | ✓ ("SwiftPM" is a single token in usage) | ✓ | ✗ |
| [API-NAME-003] spec-mirroring | ✓ (Apple uses "SwiftPM" in docs/blog) | ✗ (less canonical) | ✓ (the long form) |
| No module shadow | ✓ (does not collide with `Swift` stdlib) | ✓ | ✓ |
| Disambiguates ecosystem | ✓ (clearly Swift-domain) | ✓ | ✗ (generic across ecosystems) |
| Type-path tax | ✓ (`SwiftPM.Package.Name` — 3 levels) | ✓ | ✗ (`Package.Manager.Package.Name` — 4 levels, redundant) |

**Outcome**: **`SwiftPM.*`**. Apple's own materials uniformly use
"SwiftPM" as the prose form (cf. swift.org/package-manager, swift-blog
posts, WWDC session titles). Per [API-NAME-003], the namespace MUST
mirror the specification terminology — "SwiftPM" is the specification
terminology. The CamelCase-acronym form (`SwiftPM`, not `SPM`,
`Swift_PM`, or `Package.Manager`) treats the acronym as a single
brand-token, consistent with `SwiftUI`, `SwiftSyntax`, `URLSession`
patterns from Apple's own type-naming.

### Q3 — v1.0.0 type set

**Audit-driven closure (minimum-viable v1.0.0)**:

| Type | Closes | Backing |
|------|--------|---------|
| `SwiftPM.Package.Name` | F-A2.11, F-A3.5 (name half) | `Tagged<SwiftPM.Package, Swift.String>` |
| `SwiftPM.Product.Name` | F-A3.4, F-A3.5 (products half) | `Tagged<SwiftPM.Product, Swift.String>` |

**Candidate additions surveyed**:

| Candidate | Verdict | Rationale |
|-----------|---------|-----------|
| `SwiftPM.Target.Name` | **Include v1.0.0** | Same shape as the trio; rounds out the manifest-identifier set; multiple ecosystem consumers reference target names as `Swift.String` (manifest-primitives, swift-manifests). Including together is cheaper than two releases. |
| `SwiftPM.Manifest.ToolsVersion` | Defer | The extractor parses `// swift-tools-version:` lines today as `Swift.String`; the v1.0.0 audit did not surface ToolsVersion as a Real Gap. Introduce when a consumer requires it. |
| `SwiftPM.Source.Kind` enum (`.path` / `.url` / `.registry`) | Defer | Addendum disposed F-A2.10 (`Lint.Dependency.package(path:…)`) as Acceptable code-gen literal; no current consumer needs source-kind discrimination at the typed-primitive layer. |
| `SwiftPM.Package.Version` | Defer to separate `swift-semver-primitives` | SemVer is a cross-ecosystem domain (NPM, Cargo, Maven all use it); conflating it with SwiftPM-specific primitives mis-models the spec. Future `swift-semver-primitives` is the right home. |
| `SwiftPM.Registry.Scope` / `SwiftPM.Registry.Name` | Defer | SE-0292 codifies these but no current consumer parses registry identifiers; introduce when a registry-aware tool surfaces (CI mirror config, package-collection tooling). |
| `SwiftPM.Package.Identity` (the combined `scope.name` form) | Defer | Same gating as Registry.Scope/Name. |

**Comparison rationale for v1.0.0 trio**:

| Criterion | Trio (Package + Product + Target) | Pair (Package + Product) | Singleton (Package only) |
|-----------|:---:|:---:|:---:|
| Closes audit Defers | ✓ | ✓ (partial — name only) | ✗ |
| Rounds out manifest-identifier domain | ✓ | mixed (Target.Name is orphaned) | ✗ |
| Cross-consumer coverage | ✓ (manifest-primitives Dependency, linter Lint.Dependency, manifests Manifest.Resolver) | ✓ (covers 2/3) | ✗ |
| Code volume cost | low (parallel typealias declarations) | low | low |
| Release-cadence cost | ships once | requires v1.1.0 for Target.Name | requires v1.1.0+v1.2.0 |

**Outcome**: v1.0.0 ships the trio **`SwiftPM.Package.Name`,
`SwiftPM.Product.Name`, `SwiftPM.Target.Name`** — same shape, same
conformances, parallel declarations. Other candidates defer to a
roadmap section in the package README.

**Roadmap (post-v1.0.0; not gated on this Research)**:

- `SwiftPM.Manifest.ToolsVersion` when a consumer requires typed
  tools-version (likely the linter's `Lint.Manifest` if/when it adopts
  ToolsVersion comparison).
- `SwiftPM.Registry.Scope` and `SwiftPM.Registry.Name` per SE-0292
  when a registry-aware tool surfaces.
- `SwiftPM.Package.Identity` (combined `scope.name`) when consumers
  need registry-form resolution.
- `SwiftPM.Source.Kind` if a future consumer discriminates among
  path / url / registry sources at the typed-primitive layer.

**`SwiftPM.Package.Version` explicitly does NOT belong here** — defer
to a future `swift-semver-primitives` package per the cross-ecosystem
rationale above.

### Q4 — Validation rules sourcing

Independent verification of the upstream landscape against
`swiftlang/swift-package-manager` `main@e1ced73eb` (2026-05-12):

**Two distinct validators exist upstream, with very different
strictness**:

1. **Strict (SE-0292) — `PackageIdentity.Scope` / `PackageIdentity.Name`** —
   used for **registry identifiers** (`scope.name` form, e.g.
   `mona.LinkedList`). Lives at
   `Sources/PackageModel/PackageIdentity.swift:130-294`.
   
   Regex per SE-0292:
   ```
   Scope: \A[a-zA-Z\d](?:[a-zA-Z\d]|-(?=[a-zA-Z\d])){0,38}\z  (1–39 chars)
   Name:  \A[a-zA-Z0-9](?:[a-zA-Z0-9]|[-_](?=[a-zA-Z0-9])){0,99}\z  (1–100 chars)
   ```
   Case-insensitive equality (`caseInsensitiveCompare`).

2. **Permissive — `Package(name:)` displayName, target names,
   product names** — used at the manifest level. Each enforces only
   **emptiness rejection** (not even consistently as a single shared
   validator):
   - `Package(name:)`: no validator. `displayName` stored raw at
     `Sources/PackageModel/Manifest/Manifest.swift:31`.
   - Product name: `Sources/PackageLoading/PackageBuilder.swift:1576-1578`
     `if product.name.isEmpty { throw Product.Error.emptyName }`.
   - Target name: `Sources/PackageLoading/PackageBuilder.swift:837-844`
     `if name.isEmpty { throw Module.Error.invalidName(...) }`.

**No shared "identifier" validator exists between the two tiers** —
upstream deliberately separates them.

**Swift Evolution governance**:

| SE | Title | Relevance |
|----|-------|-----------|
| **SE-0292** | Package Registry Service | **The single authoritative codification of `Scope` / `Name` rules** for registry identifiers. Manifest-level names are NOT governed by an SE. |
| SE-0450 | SwiftPM Package Traits | Codifies trait-name rule as "valid Swift identifier" (Unicode XID start/continue), implemented as `String.isValidIdentifier` at `Sources/Basics/Collections/String+Extensions.swift:33-36`. Does not touch target/product names. |
| SE-0226 / SE-0301 / SE-0386 / SE-0387 / SE-0396 | (Various) | None codify identifier validity. |

**Stability assessment**: Zero diff in validation lines between local
checkout (Feb 2026) and current `origin/main@e1ced73eb` (2026-05-12)
across all four key files. The two-tier validation set has been
structurally frozen since SE-0292 landed (Apr 2021); target/product
emptiness checks pre-date SE-0292 and are effectively immutable.

**Architectural mismatch worth surfacing**: an institute typed
identifier `SwiftPM.Product.Name` that strictly validated upstream's
permissive rule would accept `" "` (whitespace-only string). That's
unlikely to be what an institute consumer wants. But the SE-0292
strict rule **rejects spaces** — which forbids the institute's own
common product-name convention ("Linter Primitives", "Manifest
Primitives", "Tagged Primitives Standard Library Integration"). The
two strictness tiers fit different roles:

| Tier | Strictness | Applies to |
|------|------------|-----------|
| **SE-0292** | Strict (no spaces, no leading punct) | Registry identifiers — `scope.name`-form |
| **Manifest-level** | Permissive (any non-empty string) | `Package(name:)`, product name, target name |

v1.0.0's audit consumers (linter, manifest-primitives) operate on
manifest-level names, NOT registry identifiers. The v1.0.0 types
inherit the **permissive tier** (rationale carried into Q5).

### Q5 — Validation timing

**Options**:

| Option | Form | Pros | Cons |
|--------|------|------|------|
| A | Pure typealias — no validation | Matches `Lint.Rule.ID` precedent; literal construction free via Tagged SLI; zero validation cost | Empty string and whitespace-only accepted at construction; deferred discovery |
| B | Throwing init with typed throws | Fail-fast; institute-defined invariant enforced at construction | Loses literal construction (or needs `try!` shim); requires `Error` type; more code |
| C | Hybrid — typealias with optional `.validate()` method | Ergonomic by default; opt-in validation | Two surfaces; unclear which the consumer should use |

**Criteria**: [API-IMPL-005] one-type-per-file alignment, [API-ERR-001]
typed throws, precedent (Lint.Rule.ID, Glob.Pattern), audit-purpose
fit (type discrimination vs value validation), upstream-strictness
alignment (Q4).

**Precedent comparison**:

| Precedent | Shape | Validation | Why |
|-----------|-------|------------|-----|
| `Lint.Rule.ID = Tagged<Lint.Rule, String>` | Pure typealias | None | Rule IDs are author-chosen tags; consumer-defined validity domain |
| `Lint.Source.Path = Tagged<Lint.Source, String>` | Pure typealias | None | Path strings come pre-validated from the walker; no construction-time enforcement needed |
| `Glob.Pattern: Sendable, Hashable` (struct) | Validating struct | `init(_:) throws(Glob.Error)` | Pattern strings encode a grammar that downstream consumers rely on |

The decisive question: what does upstream SwiftPM itself enforce?
From Q4, the answer is **just emptiness** for the manifest-level
names. Adding a stricter institute-defined validator (e.g., reject
whitespace) would forbid legitimately-named products like `"Tagged
Primitives Standard Library Integration"` — the institute's own
convention.

**Comparison**:

| Criterion | A (typealias) | B (validating struct) | C (hybrid) |
|-----------|:---:|:---:|:---:|
| Closes audit Defers F-A2.11 / F-A3.4 / F-A3.5 | ✓ | ✓ | ✓ |
| Type discrimination achieved | ✓ | ✓ | ✓ |
| Literal construction (`let n: SwiftPM.Package.Name = "swift-foo"`) | ✓ (via Tagged SLI) | ✗ (or via `try!` shim) | ✓ |
| Compatible with institute product-name convention (spaces) | ✓ | depends on rule choice | ✓ |
| Matches Lint.Rule.ID precedent | ✓ | ✗ | mixed |
| Code volume | minimal | moderate | moderate |
| Surface clarity (one shape) | ✓ | ✓ | ✗ |

**Outcome**: **Option A — pure typealias** matching `Lint.Rule.ID`'s
precedent. The audit closures need type discrimination, not value
validation; upstream SwiftPM itself only enforces emptiness for
manifest-level names; and institute product names routinely contain
spaces, which any non-trivial validator would forbid. Consumers that
want stricter validation MAY layer a separate validating wrapper
(e.g., `SwiftPM.Package.Name.Strict`) in a future release without
breaking the v1.0.0 typealias surface.

**[RES-022] Recommendation framing axis**: the recommended option
(A — typealias) is the **structurally-correct shape** for the closures
the audit identified. The structural goal is type discrimination at
the manifest-identifier level; the typealias shape achieves that
goal with the minimum code surface and the maximum precedent fit.
Option B (validating struct) would over-apply construction-time
enforcement to a domain where upstream itself does not enforce, and
would forbid the institute's own product-name convention. Option C
is structurally correct but introduces dual-surface confusion. The
recommendation prioritizes structural correctness, not diff size —
Option A wins on the merits.

### Q6 — Conformances

The typealias shape inherits conformances from `Tagged<Tag, U>`. From
the precedent survey of `swift-tagged-primitives`:

**Main target (`Tagged Primitives`) — unconditional / conditional**:

| Protocol | Status | Notes |
|----------|--------|-------|
| `Sendable` | Conditional (when `Tag` and `U` are `Sendable`) | `String` is `Sendable` ⇒ all v1.0.0 types are `Sendable` |
| `Equatable` | Conditional (when `U: Equatable`) | `String: Equatable` ⇒ ✓ |
| `Hashable` | Conditional (when `U: Hashable`) | `String: Hashable` ⇒ ✓ |
| `Comparable` | Conditional (when `U: Comparable`) | `String: Comparable` ⇒ ✓ |
| `Codable` | Conditional (when `U: Codable`) | `String: Codable` ⇒ ✓ |
| `CustomStringConvertible` | Forwarded | description = underlying string |
| `BitwiseCopyable` | Conditional | irrelevant for String-backed wrappers |
| `Carrier.Protocol` | Unconditional | from `Tagged+Carrier.Protocol.swift` |

**SLI target (`Tagged Primitives Standard Library Integration`) —
opt-in**:

| Protocol | Status | Notes |
|----------|--------|-------|
| `ExpressibleByStringLiteral` | `@_disfavoredOverload`, conditional | enables `let n: SwiftPM.Package.Name = "swift-foo"` |
| `ExpressibleByStringInterpolation` | `@_disfavoredOverload` | enables `"\(prefix)-bar"` literals |
| `ExpressibleByUnicodeScalarLiteral` | `@_disfavoredOverload` | composes with the above |
| `ExpressibleByExtendedGraphemeClusterLiteral` | `@_disfavoredOverload` | composes with the above |
| `LosslessStringConvertible` | Conditional | round-trips via underlying |
| `Identifiable` | Forwarded to `underlying.id` | not load-bearing for the v1.0.0 trio |

**Outcome**: All three v1.0.0 types are typealiases over
`Tagged<_, Swift.String>`, so they inherit the full conformance set
above **without re-declaration**. Consumers gain literal construction
when they import `Tagged Primitives Standard Library Integration`
alongside `SwiftPM Primitives` — the same pattern `swift-linter-primitives`
follows for `Lint.Rule.ID`.

| Type | Sendable | Hashable | Equatable | Comparable | Codable | CustomStringConvertible | ExpressibleByStringLiteral |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `SwiftPM.Package.Name` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (via SLI) |
| `SwiftPM.Product.Name` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (via SLI) |
| `SwiftPM.Target.Name` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (via SLI) |

No conformance declarations needed in `swift-spm-primitives` itself —
they're all inherited from Tagged.

### Q7 — Heritage posture

**Options**:

| Option | Form | Pros | Cons |
|--------|------|------|------|
| A | Pure greenfield | Zero attribution burden; clean Apache 2.0 LICENSE; no upstream tracking | Loses the "this mirrors upstream's rule" claim if validation is ever added |
| B | Fork of swift-package-manager validators (per `swift-package-heritage` skill) | Codifies the upstream → institute lineage; preserves SE-0292 attribution | Heavyweight for the typealias-only v1.0.0; would require LICENSE.md combining Apache 2.0 + upstream's Apache 2.0 |
| C | Greenfield with SE-0292 citation in DocC (no source borrowing) | Light-weight; documents the spec reference without git-level lineage | None significant |

**Criteria**: [HERITAGE-001+] git-level lineage requirement, code
volume actually borrowed, ongoing maintenance burden of upstream
tracking.

**Decisive observation**: v1.0.0 ships **only typealiases** with **no
validation logic**. There is no upstream code to borrow because there
is no validation code at v1.0.0. SE-0292's regex is the canonical
spec — if a v1.1.0+ adds `SwiftPM.Registry.Scope` / `Registry.Name`
with strict validation, the regex is re-derived from SE-0292 (the
spec text), not from swift-package-manager source.

This is structurally identical to how the institute treats other
spec-mirroring types: `RFC_4122.UUID` re-derives from RFC 4122; it
does not fork an upstream UUID implementation.

**Comparison**:

| Criterion | A (greenfield) | B (fork) | C (greenfield + spec citation) |
|-----------|:---:|:---:|:---:|
| Code-volume borrowing at v1.0.0 | 0 lines | 0 lines (typealias only) | 0 lines |
| Attribution overhead | none | LICENSE.md combo file, absence catalog | DocC mention only |
| Upstream-tracking burden | none | mirrors-of-mirrors problem | none |
| Aligns with `swift-package-heritage` rule trigger | N/A (no borrowed code) | over-applies | N/A |
| Future-proofs strict validators (v1.1.0+) | requires re-derivation from SE-0292 | already has lineage tracking | requires re-derivation from SE-0292 (same as A) |

**Outcome**: **Option C — pure greenfield with SE-0292 citation in
DocC**. v1.0.0 borrows zero lines from swift-package-manager (the
typealias has no validation logic). The package ships a clean Apache
2.0 LICENSE (institute standard); the README and DocC reference
SE-0292 as the authoritative spec for any future Registry-form
types. If v1.1.0+ adds `Registry.Scope` / `Registry.Name`, the regex
is re-derived from SE-0292's published text (same source SwiftPM
uses) — this is spec-mirroring per [API-NAME-003], not source
borrowing under [HERITAGE-*].

### Q8 — Tier classification

Per [RES-020]:

| Criterion | Tier 1 (Quick) | Tier 2 (Standard) | Tier 3 (Deep) | This research |
|-----------|---------------|-------------------|---------------|---------------|
| Scope | Package-specific | Cross-package | Ecosystem-wide | Cross-package |
| Precedent-setting | No | No or reversible | Yes, hard to undo | Reversible (typealias shape can evolve) |
| Semantic commitment | None | Informal | Normative/foundational | Informal (one of many typed-identifier packages) |
| Cost of error | Low | Medium | Very high | Medium |
| Expected lifetime | Single release | Several releases | Timeless infrastructure | Several releases |
| Formalization | Not required | Optional | Mandatory | Optional |

**Tier 3 threshold check**: "Establishes long-lived semantic contract
that future APIs depend on." The v1.0.0 trio is a typealias-over-
Tagged construction — semantically equivalent to half a dozen other
institute typed-identifier packages (Lint.Rule.ID, Lint.Source.Path,
Hash.Value, etc.). It does not establish a new semantic contract
beyond what `Lint.Rule.ID` already establishes; it applies an
existing contract to a new domain.

**Tier 2 fit**:

- Cross-package: at least 3 consumers identified (Q9).
- Reversible: typealias-only shape can be replaced by a validating
  struct in v2.0.0 with a deprecation path.
- Informal commitment: types follow Lint.Rule.ID precedent; no new
  invariant introduced.

**Outcome**: **Tier 2**. The handoff brief's hint matches.

### Q9 — Cross-consumer enumeration

Per the brief's prescribed grep (executed verbatim, non-`.build`
paths only):

```bash
grep -rln "package.path\|product.*: Swift.String\|target.*: Swift.String" \
  swift-primitives/ swift-standards/ swift-foundations/ | grep -v ".build"
```

**Consumer packages identified**:

| Layer | Package | Location | Role |
|-------|---------|----------|------|
| L1 | **swift-manifest-primitives** | `swift-primitives/swift-manifest-primitives/Sources/Manifest Primitives/Manifest.Dependency.swift` | `Manifest.Dependency` declares `name: Swift.String`, `product: Swift.String`, `path: Swift.String` — the L1 foundational consumer of SwiftPM identifier strings [Verified: 2026-05-12, file:1-58] |
| L3 | **swift-manifests** (transitive) | `swift-foundations/swift-manifests/` | Manifest materialization + resolution; depends on `swift-manifest-primitives`; consumes Dependency values through its public API |
| L3 | **swift-foundations/swift-linter** | `Lint.Dependency.swift`, `Lint.SingleFile.PackageDependency.swift` | The originating audit consumer; the three Defer findings (F-A2.11, F-A3.4, F-A3.5) all live here |

Tooling-level (non-Swift code):

| Path | Role |
|------|------|
| `swift-institute/Scripts/detect-redundant-deps.sh` (and siblings) | Shell-level manifest parsers; not direct typed-primitive consumers, but operate on the same identifier space |

**[RES-018] second-consumer hurdle**:

- First consumer: `swift-foundations/swift-linter` (audit-driven).
- Second consumer: `swift-primitives/swift-manifest-primitives` —
  L1, already declares `Dependency.name: Swift.String` and
  `Dependency.product: Swift.String` as the foundational shape that
  `swift-manifests` (L3) and `swift-linter` (L3) compose on top of.
- Third consumer: `swift-foundations/swift-manifests` — transitively
  via `Manifest.Dependency`.

The institute's own `Manifest.Dependency` (at L1!) is the textbook
[RES-018] second consumer: independent of the originating linter
investigation, predates this audit, and its shape would benefit
immediately from the typed identifiers (`name → SwiftPM.Package.Name`,
`product → SwiftPM.Product.Name`).

The [RES-018] hurdle clears decisively: **the L1 manifest-primitives
package is itself an independent consumer**, not a downstream
beneficiary dressed up as evidence.

**Outcome**: **v1.0.0 plans for all three consumers, not
swift-linter-focused.** The dispatch shape is:

1. Ship `swift-spm-primitives` with the trio.
2. Downstream migration dispatch (out of scope for THIS Research)
   would type the three consumers in dependency order: L1
   `manifest-primitives` first (foundational), then L3
   `swift-manifests` (transitive uptake), then L3
   `swift-linter` (closes F-A2.11 / F-A3.4 / F-A3.5).

Per the workspace memory entry `project_linter_maximal_ecosystem_reuse.md`:
"swift-linter restricted to linter-domain code; maximally re-use
ecosystem typed primitives. Foundation gaps get extended at the
foundation per [ARCH-LAYER-011], not papered over at the consumer."
The L1 swift-spm-primitives + L1 manifest-primitives uptake is the
foundational extension; the linter consumes downstream.

## Outcome

**Status**: v1.0.0 RECOMMENDATION per [RES-003a]. Principal flips to
DECISION on sign-off.

### Recommended package shape

| Aspect | Recommendation |
|--------|----------------|
| **Package name** | `swift-spm-primitives` |
| **Namespace** | `SwiftPM.*` |
| **v1.0.0 type set** | `SwiftPM.Package.Name`, `SwiftPM.Product.Name`, `SwiftPM.Target.Name` — pure typealiases over `Tagged<_, Swift.String>` |
| **Validation strategy** | None at construction (mirror Lint.Rule.ID); v1.1.0+ MAY add `Strict` companions if a consumer needs them |
| **Conformances** | All inherited from Tagged main target + SLI: `Sendable`, `Hashable`, `Equatable`, `Comparable`, `Codable`, `CustomStringConvertible`, `ExpressibleByStringLiteral` (via SLI import) |
| **Heritage** | Greenfield with SE-0292 citation in DocC; clean Apache 2.0 LICENSE |
| **Tier** | Tier 2 ([RES-020]) |
| **Primitives tier** | Tier 1 in primitives DAG (depends only on `swift-tagged-primitives` which is Tier 0) |
| **Consumers** | 3 identified — `swift-manifest-primitives` (L1, foundational), `swift-manifests` (L3, transitive), `swift-foundations/swift-linter` (L3, originating) |

### Recommended file layout

```
swift-spm-primitives/
├── Package.swift
├── README.md
├── LICENSE.md
├── Sources/
│   └── SwiftPM Primitives/
│       ├── SwiftPM.swift                  (public enum SwiftPM {} namespace shell)
│       ├── SwiftPM.Package.swift          (nested enum SwiftPM.Package {})
│       ├── SwiftPM.Package.Name.swift     (typealias)
│       ├── SwiftPM.Product.swift          (nested enum SwiftPM.Product {})
│       ├── SwiftPM.Product.Name.swift     (typealias)
│       ├── SwiftPM.Target.swift           (nested enum SwiftPM.Target {})
│       └── SwiftPM.Target.Name.swift      (typealias)
└── Tests/
    └── SwiftPM Primitives Tests/
        ├── SwiftPM.Package.Name Tests.swift
        ├── SwiftPM.Product.Name Tests.swift
        └── SwiftPM.Target.Name Tests.swift
```

One type per file per [API-IMPL-005]. Each `.Name` typealias file
contains only the typealias declaration + DocC comment, following
`Lint.Rule.ID.swift`'s precedent (file:1-29).

### Recommended Package.swift skeleton

```swift
// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-spm-primitives",
    platforms: [
        .macOS(.v26), .iOS(.v26), .tvOS(.v26),
        .watchOS(.v26), .visionOS(.v26),
    ],
    products: [
        .library(name: "SwiftPM Primitives", targets: ["SwiftPM Primitives"]),
    ],
    dependencies: [
        .package(path: "../swift-tagged-primitives"),
    ],
    targets: [
        .target(
            name: "SwiftPM Primitives",
            dependencies: [
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
            ]
        ),
        .testTarget(
            name: "SwiftPM Primitives Tests",
            dependencies: ["SwiftPM Primitives"],
            path: "Tests/SwiftPM Primitives Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
```

Mirrors `swift-glob-primitives/Package.swift` shape (file:1-85)
verbatim modulo product/target names.

### Recommended canonical type declaration

```swift
// SwiftPM.Package.Name.swift

/// A typed, stable identifier for a SwiftPM package's manifest-level
/// `name:` field.
///
/// `SwiftPM.Package.Name` is `Tagged<SwiftPM.Package, Swift.String>` —
/// the value is a `String` (e.g., `"swift-primitives"`) but its type
/// carries the SwiftPM-package-identity at compile time. Mixing
/// package names with product names or target names is rejected at
/// the type system, not at runtime.
///
/// Construction via the `ExpressibleByStringLiteral` conformance
/// shipped by `swift-tagged-primitives`'s standard-library-integration
/// target:
///
/// ```swift
/// let name: SwiftPM.Package.Name = "swift-primitives"
/// ```
///
/// Validation: none at construction time. Upstream SwiftPM enforces
/// only emptiness for manifest-level names; institute consumers
/// inherit the same permissive contract.
extension SwiftPM.Package {
    public typealias Name = Tagged<SwiftPM.Package, Swift.String>
}
```

Identical shape for `SwiftPM.Product.Name` and `SwiftPM.Target.Name`.

### Out of scope for this Research

- Authoring the package itself (Package.swift + Sources/ + Tests/) —
  this Research is design-only.
- Closing F-A2.11 / F-A3.4 / F-A3.5 in `swift-foundations/swift-linter`
  — that's a downstream consumer-migration dispatch.
- Migrating `swift-manifest-primitives` and `swift-manifests` to the
  new types — separate downstream dispatch.
- Authoring `SwiftPM.Registry.Scope` / `SwiftPM.Registry.Name` or
  other roadmap types — deferred to v1.1.0+.
- F-A2.17 (`File.Path.Temporary.randomized` companion) — separate L1
  design question.

### Recommended next dispatch

One line: **Package-authoring brief for `swift-spm-primitives` v1.0.0
following this Research's recommended shape — Package.swift + 6 source
files + 3 test files; ship to `swift-primitives/swift-spm-primitives`
new repo per [PKG-NAME-001] noun-form convention with the institute's
Apache 2.0 LICENSE and SE-0292 reference in DocC.**

### Open questions surfaced for principal sign-off

1. **Q5 / Validation timing**: confirm the typealias-without-validation
   shape is acceptable, or specify a stricter validator (e.g., reject
   whitespace-only) that this Research did NOT recommend.
2. **Q3 / Target.Name inclusion at v1.0.0**: confirm the trio shape
   (Package + Product + Target) over the audit-minimal pair (Package
   + Product only).
3. **Q3 / Roadmap exclusions**: confirm `SwiftPM.Package.Version`
   defers to a future `swift-semver-primitives` package rather than
   shipping here.

### Pre-existing gaps surfaced en passant

- `swift-foundations/swift-linter/Research/_index.json` is per the
  addendum (line 437-441) stale — three 2026-05-12 docs and
  `_Package-Insights.md` absent from `documents[]`. Surfacing only;
  catch-up is out of scope.
- `swift-version-primitives` / `swift-semver-primitives` do NOT
  exist in the ecosystem [Verified: 2026-05-12 via subagent grep].
  Future SemVer typing has no current home.

## References

### Primary inputs

- Audit: `swift-foundations/swift-linter/Research/2026-05-12-typed-primitive-adoption-audit.md` v1.0.0 TRIAGE
- Addendum: `swift-foundations/swift-linter/Research/2026-05-12-typed-primitive-adoption-audit-addendum.md` v1.0.0 RECOMMENDATION
- Handoff dispatch: `HANDOFF-swift-spm-primitives-design-research.md` (read in full)

### Internal research consulted ([RES-019] / [HANDOFF-013])

- `swift-institute/Research/decimal-carrier-integration.md` — phantom-tag naming convention (synthesized `*Tag` suffixes forbidden)
- `swift-institute/Research/carrier-ecosystem-application-inventory.md` — Tagged adoption ecosystem-wide
- `swift-institute/Research/cardinal-ordinal-vector-enforcement-design.md` — typed-primitive enforcement pattern
- `swift-institute/Research/glob-l1-vocabulary-relocation.md` — most recent L1 bootstrap precedent (2026-05-02)
- `swift-institute/Research/github-metadata-harmonization.md` — package naming conventions
- `swift-institute/Research/spm-nested-package-publication.md` — SwiftPM model ratification
- `swift-primitives/swift-tagged-primitives/Research/sli-literal-vs-strideable-tradeoff.md` v1.0.0 DECISION — SLI conformance gating
- `swift-primitives/swift-tagged-primitives/Research/tagged-literal-conformances.md` v3.0.0 DECISION — production literal conformances

### Institute precedents surveyed

- `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.ID.swift:12-28` — canonical typealias-over-Tagged precedent
- `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Source.swift` — `Lint.Source.Path` typealias (phantom-tag discrimination over same underlying)
- `swift-primitives/swift-glob-primitives/Package.swift:1-85` — L1 bootstrap Package.swift shape (2026-05-02)
- `swift-primitives/swift-glob-primitives/Sources/Glob Primitives/Glob.Pattern.swift` — validating struct precedent (alternative shape not chosen for v1.0.0)
- `swift-primitives/swift-linter-primitives/Package.swift:1-89` — typealias-package Package.swift shape
- `swift-primitives/swift-manifest-primitives/Sources/Manifest Primitives/Manifest.Dependency.swift:1-58` — L1 [RES-018] second consumer
- `swift-primitives/swift-tagged-primitives/Sources/Tagged Primitives/` — Tagged conformance surface

### Upstream sources (primary citations per [RES-026])

Verified against `swiftlang/swift-package-manager@main` (revision
`e1ced73eb`, 2026-05-12). Local checkout at
`/Users/coen/Developer/swiftlang/swift-package-manager`:

- `Sources/PackageModel/PackageIdentity.swift:130-294` — `Scope` / `Name` validators (SE-0292)
- `Sources/PackageModel/Manifest/Manifest.swift:31, 113-134` — unvalidated `displayName`
- `Sources/PackageLoading/PackageBuilder.swift:210-262, 837-844, 1497-1578` — Target / Product emptiness checks
- `Sources/PackageLoading/ManifestLoader+Validation.swift:55-95, 97-129` — Manifest-level duplicate + trait checks
- `Sources/Basics/Collections/String+Extensions.swift:33-36` — `isValidIdentifier` (SE-0450)

### Swift Evolution proposals

- [SE-0292 — Package Registry Service](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0292-package-registry-service.md) — Scope/Name regex definition (lines 146-172)
- [SE-0450 — SwiftPM Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md) — trait-name identifier rule (lines 508-513)

### Skills cited

- [PKG-NAME-001] noun-form package naming
- [PKG-NAME-005] shortest-natural-noun rule
- [API-NAME-001] no compound identifiers
- [API-NAME-003] specification-mirroring names
- [API-IMPL-005] one type per file
- [PRIM-NAME-001] `-primitives` suffix
- [PRIM-FOUND-001] no Foundation imports
- [PRIM-ARCH-002] downward dependencies only
- [HERITAGE-*] — heritage trigger threshold (not crossed for v1.0.0)
- [RES-003] document structure
- [RES-009] multi-option analysis
- [RES-018] second-consumer hurdle for new primitives
- [RES-019] Step-0 internal research grep
- [RES-020] research tiers
- [RES-021] prior art survey
- [RES-022] structural correctness over diff size
- [RES-026] citations
