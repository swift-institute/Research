# Typed Identifier Naming Framework

<!--
---
version: 1.0.0
last_updated: 2026-05-12
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The `swift-spm-primitives` design Research family
(`2026-05-12-swift-spm-primitives-design.md` v1.0.0 commit `14df127`
+ three companion docs at commit `adb87d8`) recommended a `SwiftPM.*`
namespace for typed SwiftPM identifiers and a future
`swift-semver-primitives` package using `SemVer.*` namespace.
Principal feedback surfaced two unifying principles that both prior
recommendations violate:

1. **No abbreviations**: "SwiftPM" abbreviates "Swift Package
   Manager"; "SemVer" abbreviates "Semantic Versioning". Both are
   primary-form abbreviations of spelled-out specification
   terminology.
2. **Maximal ecosystem adoption / reuse / integration**: types
   should be consumable across ecosystems (NPM bridges, Cargo
   bridges, registry tooling, Swift Package Index) without
   importing a consumer-flavored namespace.

These principles, combined, yield a unified framework that resolves
the naming question consistently across typed primitives in the
institute. The framework is partly **new codification** (the
"generic-noun-first, specialization-as-refinement" framing) and
partly **making implicit institute patterns explicit**
(`swift-foundations/swift-dependency-analysis` already declares
`public enum Package {}` as the L3 namespace; `swift-manifest-primitives`
uses `Manifest.*` — both follow the framework's discipline without
having articulated it).

This Research doc names the framework and codifies its four axioms,
so future sessions can apply it directly rather than re-deriving the
shape from first principles each time.

**Trigger**: principal feedback on the `2026-05-12-swift-spm-primitives-design.md`
v1.0.0 RECOMMENDATION and its three companion docs.

**Internal research consulted per [HANDOFF-013] / [RES-019]**:

- `swift-institute/Research/decimal-carrier-integration.md` —
  phantom-tag naming convention (real domain names, NOT synthesized
  `*Tag` suffixes). Composes with Axiom 2.
- `swift-institute/Research/carrier-ecosystem-application-inventory.md`
  — `Tagged<Tag, Base>` adoption survey ecosystem-wide.
- `swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.swift:2`
  — existing institute precedent for `Package.*` namespace at L3
  [Verified: 2026-05-12].
- `swift-primitives/swift-manifest-primitives/Sources/Manifest Primitives/Manifest.swift:35`
  — existing institute precedent for `Manifest.*` namespace at L1
  [Verified: 2026-05-12].
- `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.ID.swift:12-28`
  — typealias-over-Tagged precedent under a non-abbreviated
  namespace [Verified: 2026-05-12].

No prior research codifies the framework explicitly — this is
greenfield meta-research applicable across the institute's typed-
primitive ecosystem [Verified: 2026-05-12].

## Question

What is the canonical naming framework for typed primitive
identifiers in the institute, and how does it resolve naming
conflicts that recurringly arise (abbreviation vs spelled-out,
brand-namespace vs generic-noun, consumer-flavored vs
ecosystem-reusable)?

## Analysis

### The Four Axioms

#### Axiom 1 — Names are spelled out fully

**Statement**: Primary identifiers — package names, namespaces,
top-level types — MUST use the spelled-out form of the underlying
concept. Abbreviations are FORBIDDEN as primary identifiers.

**Examples (forbidden primary forms)**:

| Abbreviation | Spelled-out form | Replacement |
|--------------|------------------|-------------|
| `SwiftPM` | "Swift Package Manager" | Use the generic noun (`Package`) per Axiom 2; SwiftPM-the-tool is one consumer of the generic concept |
| `SemVer` | "Semantic Versioning" | `Version.Semantic` per Axiom 3 (`Semantic` is the kind of versioning, narrowing `Version`) |
| `SPM` | "Swift Package Manager" | Same as `SwiftPM` |
| `URL` | "Uniform Resource Locator" | `RFC_3986.URI` (URI is the broader spec; `URL` is a subset historically conflated) per `[API-NAME-003]` |
| `UUID` | "Universally Unique Identifier" | `RFC_4122.UUID` per `[API-NAME-003]` — kept as a type name because it IS the spec's spelling, but the namespace is the spec |
| `API` | "Application Programming Interface" | Compound; avoid as primary identifier |
| `JSON` | "JavaScript Object Notation" | `RFC_8259.JSON` (kept as type name because IT IS the spec spelling) |

**Carve-out — typealiases for additive convenience**: A spelled-out
primary type MAY be accompanied by a typealias to the common
short-form for ergonomic consumer code:

```swift
// Primary declaration:
extension Version {
    public struct Semantic: Sendable, Hashable, Comparable { ... }
}

// Additive convenience typealias (POST-v1.0.0; only after consumer demand):
public typealias SemVer = Version.Semantic
```

The typealias is OPTIONAL, ADDITIVE, and lands only when a
specific consumer surfaces a demonstrated need. The primary
declaration is non-negotiable.

**Carve-out — spec-mirroring exception per `[API-NAME-003]`**: when
the specification itself uses an acronym as its canonical spelling
(RFC, ISO, IEEE, etc.), the namespace MAY mirror the acronym
(`RFC_4122`, `ISO_32000`, `IEEE_754`). The acronym is the spec's
authoritative form; mirroring is not abbreviation. The boundary is
sharp: spec acronyms are exempt; consumer / tool / brand acronyms
are not.

**Carve-out — institute-established acronyms with no spelled-out
form**: `IO` (input/output) and `URI`-when-the-spec-uses-URI are
established institute namespaces with no clean spelled-out
alternative. These predate the framework and are grandfathered;
new namespaces MUST NOT introduce new abbreviations.

**Rationale**: Abbreviations smuggle ambiguity into well-typed code.
"SwiftPM" means "Swift Package Manager" in Apple's prose but
"Software Project Management" in other contexts; "SemVer" could
abbreviate other version-semantics terms. The institute's
spec-mirroring discipline ([API-NAME-003]) and its existing
prohibition on local-binding abbreviations ([API-NAME-012]: `impl`,
`obj`, `inst`) generalize to the type-and-namespace surface — this
axiom makes that generalization explicit.

**Lint enforcement (future)**: a candidate rule
`Lint.Rule.Naming.AbbreviationAsPrimary` would flag type / namespace
/ package declarations whose name is a known abbreviation. Out of
scope for this Research; surface to skill-lifecycle for code-surface
amendment.

---

#### Axiom 2 — Top-level namespace is the most-generic English noun for the domain entity

**Statement**: The top-level namespace MUST be the most-generic
English noun naming the entity that the types represent — NOT the
brand, tool, framework, or consumer that uses them. "What the type
IS" dominates "who uses it."

**Examples**:

| Domain | Wrong namespace (consumer-flavored) | Correct namespace (generic-noun) |
|--------|-------------------------------------|----------------------------------|
| Semantic versions | `SemVer.*` (abbreviation) or `SwiftPM.Version.*` (consumer) | `Version.*` — Version is the generic noun; specific kinds (Semantic, Calendar, Tools) nest within |
| Swift packages | `SwiftPM.Package.*` (brand) | `Package.*` — Package is the generic noun in Swift ecosystem; SwiftPM is one consumer |
| File paths | `Foundation.URL.*` (framework) | `File.Path.*` (institute) per `[PATH-*]` precedent |
| UUIDs | `Apple.UUID.*` or `Swift.UUID.*` (vendor) | `RFC_4122.UUID` (spec-mirroring per `[API-NAME-003]`) |
| Linter rules | `SwiftLint.Rule.*` (tool) | `Lint.Rule.*` (institute generic) |

**The maximal-reuse principle made structural**: a generic-noun
namespace lets the type be consumed across ecosystems without
dragging in a consumer-flavored namespace. A `Package.Name`
imported by an NPM bridge, a Cargo bridge, a Swift Package Index
fork, or a registry-tooling pipeline — all see the same name
without flavor pollution. A `SwiftPM.Package.Name` would force every
consumer to import a SwiftPM-flavored surface even when their use
is package-name-pure.

**The decision test**:

| Question | If yes | If no |
|----------|--------|-------|
| Could the type be meaningfully consumed by a non-Swift-ecosystem consumer (Cargo, NPM, deb, registry tooling) without semantic loss? | The namespace MUST be the generic noun; consumer-flavored namespaces fragment reuse. | Consumer-flavored namespace MAY be appropriate if the type is genuinely consumer-specific (e.g., `Lint.Rule.Configuration.Mode` is specifically about institute lint rules — `Lint` is the right namespace). |

**Boundary case — Lint.Rule.ID**: the institute names this
`Lint.Rule.ID` (not `Rule.ID`) because the rule-ID concept is
specific to institute lint rules — no cross-ecosystem reuse is
meaningful. The framework supports per-namespace judgment: not
every type is cross-ecosystem; the framework asks the cross-
ecosystem question first to surface the cases where consumer-
flavor is unnecessary.

**Boundary case — Manifest.Dependency**: the existing
`swift-manifest-primitives` uses `Manifest.*` for the institute's
manifest-driven evaluation system (Lint.swift, Format.swift, and
implicitly Package.swift). `Manifest` IS the generic noun for the
domain ("a manifest is a file-scope let-bound typed value declared
in a Swift source file" per the package's own docstring). Not
SwiftPM-flavored, not Lint-flavored — the generic concept the
institute models.

**Rationale**: When the institute commits to a brand-namespace, it
permanently couples its type system to the brand's existence. When
SwiftPM is eventually superseded (or a registry-specific successor
emerges), `SwiftPM.Package.Name` becomes legacy by name even if
the type's shape is still correct. A `Package.Name` survives the
brand's lifecycle because it names what it IS, not who uses it.

---

#### Axiom 3 — Specialization narrows via nested types within the generic namespace

**Statement**: When a generic-noun namespace hosts multiple
variants of a concept (semantic versioning vs calendar versioning
vs tools-version; Apache 2.0 license vs MIT license; HTTP/1.1 vs
HTTP/2 vs HTTP/3), specialization MUST nest within the generic
namespace via Nest.Name per `[API-NAME-001]`. Variants accrete
over time without breaking earlier consumers.

**Examples**:

| Generic namespace | v1.0.0 variant | Future additive variants |
|-------------------|----------------|--------------------------|
| `Version.*` | `Version.Semantic` (SemVer 2.0.0) | `Version.Calendar` (CalVer YYYY.MM.DD); `Version.Tools` (SwiftPM tools-version subset of SemVer); `Version.Date` |
| `Package.*` | `Package.Name`, `Package.Product.Name`, `Package.Target.Name` (typealiases) | `Package.Identity` (registry scope.name), `Package.Dependency` (full struct), `Package.Manifest` (richer than current L3 use) |
| `License.*` (hypothetical) | `License.Apache_2_0`, `License.MIT` | additive |

**Spec-mirroring [API-NAME-003] applies WITHIN the namespace, NOT
AT it**: the namespace level is GENERIC; the nested type names
mirror specification terminology. `Version.Semantic` mirrors
semver.org's "Semantic Versioning"; `Package.Name` mirrors
SwiftPM's `Package(name:)` field name; `License.Apache_2_0`
mirrors the license's own version-pinned identifier.

**The [API-NAME-001a] single-type-no-namespace check**: a namespace
with only one nested type at v1.0.0 is acceptable IF additional
sibling types are plausible at later versions. `Version` namespace
with only `Version.Semantic` clears the check because
`Version.Calendar` / `Version.Tools` are realistic future variants.
`Package` namespace with only `Package.Name` at v1.0.0 clears
because `Package.Identity`, `Package.Manifest` are plausible
sibling additions.

**Rationale**: Variant accretion is the typical evolution pattern
for typed primitives. Locking in a flat shape at v1.0.0 forces
breaking renames when a second variant emerges; nesting from the
start preserves additivity. The institute's existing typed
primitives already follow this pattern (`Lint.Rule.ID` +
`Lint.Rule.Bundle` + `Lint.Rule.Configuration` + ... — all siblings
under `Lint.Rule`); this axiom makes the pattern explicit.

---

#### Axiom 4 — Inclusion at any version is gated on second-consumer demand verified at write time

**Statement**: A typed primitive ships in a package version IF AND
ONLY IF an independent second consumer (beyond the originating
investigation) is verified empirically (grep + file:line) at the
package's write time. Symmetric-completeness arguments ("this
rounds out the set", "this cell is empty in the orthogonal grid")
are explicitly disallowed as the sole justification per [RES-018].

**Application**:

| Type | Originating investigation | Second consumer verification (write time) | Hurdle |
|------|---------------------------|-------------------------------------------|--------|
| `Package.Name` | Linter audit F-A2.11 | `swift-manifest-primitives` `Manifest.Dependency.name` | ✓ cleared |
| `Product.Name` | Linter audit F-A3.4 / F-A3.5 | `swift-manifest-primitives` `Manifest.Dependency.product` | ✓ cleared |
| `Target.Name` | (linter does NOT consume target names) | `swift-foundations/swift-dependency-analysis` `Manifest.Target.name` + `Package.analyze.swift:60,80,82` | ✓ cleared |
| `Version.Semantic` | `swift-package-primitives` v1.1.0+ dependency-requirement composition | Swift Package Index, release tooling, registry tooling (candidates; empirically verify at swift-version-primitives v1.0.0 write time) | ⏳ defer verification to that dispatch |
| `Source.Kind` enum | (none) | (none verified) | ✗ defer |
| `Manifest.ToolsVersion` | (none) | (none verified) | ✗ defer |

**Maximal-reuse via Axiom 4**: the principle that types ship when
real consumers exist is a discipline FOR reuse, not against it. By
restricting v1.0.0 to types with verified consumers, the package
ships a tight surface that downstream re-use can rely on without
deprecation churn.

**Rationale**: This is [RES-018] applied to typed-identifier
primitives specifically. The framework names it as a fourth axiom
because typed-identifier packages have a recurring temptation
toward symmetric-completeness (the trio temptation: "if we have
Package.Name and Product.Name, we should add Target.Name for
completeness") — the empirical verification catches the temptation
without forbidding the inclusion when the empirical evidence
supports it.

### How the axioms compose

The framework is INTERNALLY CONSISTENT — each axiom strengthens the
others without contradiction:

| Axiom | What it answers | Composition with the others |
|-------|-----------------|------------------------------|
| 1 (no abbreviations) | "What is the right SHAPE of the name?" | Forbids primary-form acronyms; the generic noun from Axiom 2 is spelled out by default |
| 2 (generic noun) | "What is the right LEVEL of the namespace?" | Generic noun is spelled-out per Axiom 1; permits cross-ecosystem reuse |
| 3 (specialization nests) | "How does the namespace EVOLVE?" | Variants accrete without breaking; spec-mirroring [API-NAME-003] applies INSIDE the generic-noun namespace |
| 4 (consumer-gated inclusion) | "WHEN does a type ship?" | Maximal-reuse discipline: ship when consumers exist, not when grid is empty |

The composition is what gives the framework its predictive power.
Apply axioms 1-2 first to derive the namespace; apply axiom 3 to
structure the nested types; apply axiom 4 to gate each addition.
The recurring naming questions in the institute's typed-primitive
ecosystem (`SwiftPM` vs `Package`, `SemVer` vs `Version.Semantic`,
brand-namespace vs generic-namespace) decompose cleanly against
this framework.

### Cross-references to existing institute rules

The framework composes with — does not replace — the institute's
existing naming rules:

| Rule | Composition |
|------|-------------|
| `[API-NAME-001]` Nest.Name pattern | Framework operates WITHIN; the generic-noun namespace IS the Nest, nested specialization IS the Name |
| `[API-NAME-001a]` Single-type-no-namespace | Framework respects; Axiom 3's variant-accretion plan satisfies the rule |
| `[API-NAME-002]` No compound identifiers | Framework supports; generic-noun namespaces avoid compound forms ("Package" not "SwiftPackage") |
| `[API-NAME-003]` Spec-mirroring | Framework refines: spec-mirroring applies WITHIN the namespace, NOT AT it. `Version.Semantic` mirrors semver.org's "Semantic Versioning"; `Version` namespace is generic |
| `[API-NAME-012]` No `impl`/`obj`/`inst` local abbreviations | Framework's Axiom 1 generalizes from local-binding scope to type/namespace/package scope |
| `[API-NAME-013]` Redundant prefix removal | Framework composes; generic-noun namespaces avoid redundant brand-prefixes |
| `[API-NAME-010]` No `*Tag` synthesized suffixes | Framework composes; phantom-tag names use real domain entities (Axiom 2's generic noun supplies them) |
| `[PKG-NAME-001]` Noun-form package naming | Framework refines: the noun is the generic-noun namespace's name (`swift-package-primitives` matches `Package.*`) |
| `[PRIM-NAME-001]` `-primitives` suffix | Framework respects |
| `[RES-018]` Premature primitive anti-pattern | Framework's Axiom 4 IS this rule applied to typed-identifier primitives |

### Worked examples (institute precedent supporting the framework)

The framework is partly NEW codification, partly making implicit
institute patterns explicit. Existing types that already follow the
framework:

| Type | Namespace | Generic noun? | Spec-mirroring inside? | Notes |
|------|-----------|:---:|:---:|------|
| `RFC_4122.UUID` | RFC_4122 | ✓ (spec) | ✓ (UUID is spec term) | spec-namespace pattern |
| `RFC_3986.URI` | RFC_3986 | ✓ (spec) | ✓ | spec-namespace pattern |
| `File.Path` | File | ✓ | — | institute generic noun |
| `Memory.Address` | Memory | ✓ | — | institute generic noun |
| `Lint.Rule.ID` | Lint | ✓ (institute generic) | — | institute generic noun; cross-ecosystem reuse not meaningful here |
| `Manifest.Dependency` | Manifest | ✓ (institute generic) | — | institute generic noun; spans Lint.swift / Format.swift / Package.swift |
| `Package.Analysis` (L3 swift-dependency-analysis) | Package | ✓ | — | institute generic noun; the framework's existence-proof |
| `Glob.Pattern` | Glob | ✓ | — | institute generic noun for pattern-matching grammar |
| `Cardinal`, `Ordinal` | (top-level) | ✓ | — | institute generic nouns for typed quantities |

Existing types that VIOLATE the framework (existing-precedent
debt — flagged for follow-up):

| Type | Issue | Framework correction |
|------|-------|---------------------|
| `IO.*` namespace | "IO" is abbreviation of "Input/Output" | Grandfathered (Axiom 1 carve-out for institute-established acronyms); future related namespaces SHOULD spell out |
| `Lint` namespace | "Lint" is the colloquial name for "linter" / "lint analysis" | Grandfathered (institute generic noun; widely understood) |

### Theoretical grounding per [RES-021]

**Cross-ecosystem prior art (universal-adoption-vs-necessity check)**:

| Ecosystem | Naming for typed identifiers | Abbreviated? | Cross-ecosystem-reusable? |
|-----------|------------------------------|:---:|:---:|
| Rust crates | `semver::Version`, `cargo::Package` (snake_case but spelled out) | mostly no | semver is reusable; cargo-specific is not |
| Node.js | `semver` package (lowercase abbreviation in package name; class name is `SemVer`) | YES | partial (npm-specific naming) |
| Go | `golang.org/x/mod/modfile.Module` (generic-noun packages) | no | yes |
| Java | `Maven.Coordinates` style (vendor-flavored), `org.osgi.framework.Version` (generic) | mixed | mixed |

The cross-ecosystem evidence is non-uniform; the framework's
"generic-noun + maximal-reuse" stance is one of several viable
positions, but the **strongest reuse cases come from generic-noun
patterns** (Go's `module.Module`, OSGi's `Version`). The institute's
choice to follow this pattern is principled, not universally
forced.

**Per [RES-021] contextualization step**: applying generic-noun
namespaces to the institute's type system does NOT require new
infrastructure. The institute already has `Tagged<Tag, U>`
(phantom-typed wrappers), `Lint.Rule.ID`-style typealiases, and
multi-package compositional structure. The framework refines naming
discipline within existing infrastructure; no new primitive is
introduced.

## Outcome

**Status**: v1.0.0 RECOMMENDATION per [RES-003a]. Principal flips
to DECISION on sign-off.

**The framework**: four axioms governing typed-primitive
identifier naming in the institute:

1. **Names are spelled out fully** (no abbreviations as primary
   identifiers; typealiases for additive convenience permitted
   post-v1.0.0).
2. **Top-level namespace is the most-generic English noun for the
   domain entity** (cross-ecosystem reuse made structural).
3. **Specialization narrows via nested types within the generic
   namespace** (variants accrete additively; spec-mirroring applies
   inside the namespace).
4. **Inclusion at any version is gated on second-consumer demand
   verified at write time** (maximal-reuse discipline; [RES-018]
   applied to typed-identifier primitives).

**Composition direction (application order)**: Axiom 1 → Axiom 2 →
Axiom 3 → Axiom 4. Spell out the noun; pick the generic noun as the
namespace; structure specializations within it; gate each addition
on consumer demand.

**Application to the `swift-spm-primitives` design family**: the
framework supersedes the `SwiftPM.*` and `SemVer.*` choices in the
four prior research docs. The unified design replacing them is
captured in `2026-05-12-swift-package-and-version-primitives-design.md`
v1.0.0 RECOMMENDATION (companion to this Research). The prior four
docs are SUPERSEDED with status notes pointing to the unified design.

**Future work**:

- **Skill promotion candidate**: the framework's four axioms are
  candidates for promotion to `code-surface` as `[API-NAME-NNN]`
  rules. Per `[RES-006a]`, this Research's findings should land in
  the canonical skill corpus to drive lint enforcement. Out of
  scope for THIS Research; surface via skill-lifecycle.
- **Lint rule candidate**: `Lint.Rule.Naming.AbbreviationAsPrimary`
  would flag type/namespace/package declarations whose name is a
  known-abbreviation. Composes with the existing
  `Lint.Rule.Naming.RedundantPrefix` and other `[API-NAME-*]`
  enforcement.
- **Existing-precedent audit**: a pass over the institute's L1
  namespaces to identify abbreviated-namespace debt (`IO`, others?)
  is a candidate /audit dispatch. Grandfathered status documented
  in this doc; correction policy is per-case.

**Open questions surfaced for principal sign-off**:

1. Confirm the four axioms as v1.0.0 of the framework.
2. Confirm the carve-outs (typealias convenience, spec-mirroring
   acronyms, institute-grandfathered acronyms) as accurately
   capturing the boundary.
3. Confirm Tier-2 (cross-package) classification, or elevate to
   Tier-3 (ecosystem-wide) given the framework's normative scope —
   Tier-3 would require SLR per [RES-023] and formal semantics per
   [RES-024]; the work in this doc is closer to Tier-2 codification
   of an emergent institute pattern than Tier-3 foundational
   theory.
4. Confirm the skill-promotion path (code-surface
   `[API-NAME-NNN]`) as the right downstream target.

## References

### Triggers

- `swift-institute/Research/2026-05-12-swift-spm-primitives-design.md`
  v1.0.0 RECOMMENDATION (commit `14df127`) — superseded by this
  framework; new design in companion Research below.
- `swift-institute/Research/2026-05-12-swift-spm-primitives-validation-timing.md`
  v1.0.0 RECOMMENDATION (commit `adb87d8`) — superseded.
- `swift-institute/Research/2026-05-12-swift-spm-primitives-target-name-v1.md`
  v1.0.0 RECOMMENDATION (commit `adb87d8`) — superseded.
- `swift-institute/Research/2026-05-12-swift-semver-primitives-package-version-placement.md`
  v1.0.0 RECOMMENDATION (commit `adb87d8`) — superseded.

### Companion Research (applies the framework)

- `swift-institute/Research/2026-05-12-swift-package-and-version-primitives-design.md`
  v1.0.0 RECOMMENDATION — unified design replacing the four prior
  docs.

### Institute precedents (per [RES-019] / [RES-026])

[Verified: 2026-05-12]:

- `swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.swift:2`
  — `public enum Package {}` at L3 (existence-proof for the
  framework's Axiom 2).
- `swift-primitives/swift-manifest-primitives/Sources/Manifest Primitives/Manifest.swift:35`
  — `public enum Manifest: Swift.Sendable {}` at L1 (institute
  generic noun).
- `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.ID.swift:12-28`
  — typealias-over-Tagged pattern under institute generic noun
  (`Lint.Rule.ID`).

### Cross-references to existing skill rules

- `[API-NAME-001]` Nest.Name pattern (code-surface)
- `[API-NAME-001a]` Single-type-no-namespace (code-surface)
- `[API-NAME-002]` No compound identifiers (code-surface)
- `[API-NAME-003]` Specification-mirroring (code-surface)
- `[API-NAME-010]` No synthesized `*Tag` suffixes (code-surface)
- `[API-NAME-012]` No `impl`/`obj`/`inst` local-binding
  abbreviations (code-surface) — framework generalizes
- `[API-NAME-013]` Drop redundant prefix when namespace supplies
  context (code-surface)
- `[PKG-NAME-001]` Noun-form package naming (swift-package)
- `[PRIM-NAME-001]` `-primitives` suffix (primitives)
- `[RES-018]` Premature primitive anti-pattern (research-process) —
  framework's Axiom 4 IS this rule
- `[RES-021]` Prior art survey, contextualization step
  (research-process)

### Cross-ecosystem prior art surveyed

(non-load-bearing; informs the framework's positioning)

- [Rust `semver` crate](https://docs.rs/semver/latest/semver/) — separate-from-cargo SemVer library
- [Node.js `node-semver`](https://github.com/npm/node-semver) — separate-from-npm SemVer library
- [Go `golang.org/x/mod/modfile.Module`](https://pkg.go.dev/golang.org/x/mod/modfile) — generic-noun package naming
- [OSGi `org.osgi.framework.Version`](https://docs.osgi.org/) — generic-noun version typing
