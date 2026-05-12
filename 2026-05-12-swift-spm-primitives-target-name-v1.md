# swift-spm-primitives Target.Name v1.0.0 Inclusion

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
> The substantive recommendation (Target.Name included in v1.0.0;
> swift-foundations/swift-dependency-analysis is the independent
> second consumer per [RES-018]; Option D — trio + roadmap section)
> survives in the successor §Q3 + §Q9. Naming references throughout
> this doc (`SwiftPM.Target.Name`) are SUPERSEDED — corrected to
> `Target.Name` per framework Axioms 1 and 2.

## Context

The parent design Research
(`2026-05-12-swift-spm-primitives-design.md` v1.0.0 RECOMMENDATION,
commit `14df127`) recommended shipping a **trio** in v1.0.0:
`SwiftPM.Package.Name`, `SwiftPM.Product.Name`, and
`SwiftPM.Target.Name`. The audit closures (F-A2.11 / F-A3.4 /
F-A3.5) only require Package.Name and Product.Name; Target.Name was
added on the grounds of "rounds out the manifest-identifier set;
cross-consumer coverage; one release vs two."

That rationale is dangerously close to the **symmetric-completeness**
shape that [RES-018] explicitly forbids: "*this cell is empty in the
orthogonal grid*" reasoning is disallowed as the sole justification
for a new primitive. The parent doc's trio rationale, read literally,
is symmetric-completeness ("rounds out the set") + ergonomic
release-cadence preference. That is NOT enough under [RES-018].

This Research doc isolates the Target.Name v1.0.0 question and
verifies — independently — whether the type clears [RES-018]'s
second-consumer hurdle. If it does, the parent doc's trio
recommendation stands on substantive grounds rather than
symmetric-completeness grounds. If it does not, Target.Name defers
to v1.1.0+ until a consumer surfaces.

**Trigger**: open question #2 surfaced in the parent doc's Outcome
section ("confirm the trio shape (Package + Product + Target) over
the audit-minimal pair (Package + Product only)").

## Question

Does `SwiftPM.Target.Name` clear [RES-018]'s second-consumer hurdle
independently of Package.Name and Product.Name, justifying inclusion
in v1.0.0?

The question is NOT "is Target.Name useful eventually" (yes, in any
manifest-aware tool). The question is "is there empirical second-
consumer demand at v1.0.0 release time, separate from the convenience
of trio-shipping?"

## Analysis

### Cross-consumer enumeration: where Target.Name independently appears

A grep at write-time (2026-05-12) across `swift-primitives/`,
`swift-standards/`, `swift-foundations/` (excluding `.build`)
surfaces:

**Site 1 — `swift-foundations/swift-dependency-analysis`** (L3):

`Sources/Dependency Analysis/Package.Manifest.Target.swift:6` —

```swift
public struct Target {
    public let name: String   // ← target name
    public let kind: Kind
    public let path: String?
    public let dependencies: [Dependency]
}
```

Used at:
- `Package.analyze.swift:80` — `packagePath + "/Tests/" + target.name`
- `Package.analyze.swift:82` — `packagePath + "/Sources/" + target.name`
- `Package.analyze.swift:60` — `Analysis.Target(name: target.name, entries: entries)`

[Verified: 2026-05-12]. swift-dependency-analysis uses target names
for two semantically distinct purposes:

1. **Filesystem path construction** — the target name names the
   `Sources/<target>` and `Tests/<target>` subdirectory containing
   the target's source files. This is a use unique to target names;
   neither package names nor product names participate.
2. **Identity grouping in analysis results** — `Analysis.Target.name`
   keys the per-target dependency reports. Again, unique to target
   names.

**Site 2 — `swift-foundations/swift-dependency-analysis`**:

`Sources/Dependency Analysis/Package.Analysis.Target.swift:5` —

```swift
public struct Target {
    public let name: String   // ← analysis-result target name
    public let entries: [Entry]
}
```

[Verified: 2026-05-12]. Distinct struct from Manifest.Target above;
this is the analysis-result type, NOT the manifest-parse type. Both
use `name: String` for the target identity. This is the SAME
identifier semantics flowing through two distinct types in the
analysis pipeline (parse → group → emit).

**Site 3 — `swift-foundations/swift-linter` Materializer/Extractor**
(originating consumer):

Per `2026-05-12-swift-spm-primitives-target-name-v1.md` subagent
verification: `Lint.SingleFile.Materializer.swift:122` uses a
hardcoded `"Lint"` target name; `Lint.SingleFile.Extractor.swift`
parses package + product names from the consumer's `Lint.swift` AST
but does NOT extract target names. [Verified: 2026-05-12].

**This is a crucial finding**: the linter — the originating
audit consumer — does NOT have direct demand for Target.Name. The
linter's only target-name use is the hardcoded eval-project target
name (`"Lint"`), which is institute infrastructure, not a typed
identifier the consumer-facing API needs.

### Applying [RES-018]'s tests

**Test 1: "Is there a second consumer beyond the originating
investigation?"**

- Originating investigation: the linter audit (F-A2.11 / F-A3.4 /
  F-A3.5).
- The linter itself does NOT consume target names from manifests
  [Verified: 2026-05-12].
- swift-dependency-analysis DOES consume target names independently
  [Verified: 2026-05-12].
- → **second consumer exists** in `swift-foundations/swift-dependency-analysis`.

**Test 2: "Why not compose existing primitives?"**

- A target name is a `Swift.String` constrained to a SwiftPM
  manifest-identifier-role. The existing primitives catalog has:
  - `Tagged<Tag, U>` (generic phantom-typed wrapper)
  - `Lint.Source.Path` (Tagged<Lint.Source, String>) — wrong domain
    (linter source paths, not SwiftPM target names)
  - `Lint.Rule.ID` (Tagged<Lint.Rule, String>) — wrong domain
- Composition into the v1.0.0 trio: `SwiftPM.Package.Name` covers
  package-name role; `SwiftPM.Product.Name` covers product-name role.
  Target-name role has no analog in the existing catalog.
- → composition cannot cover the use case.

**Test 3: Symmetric-completeness exclusion**

The parent doc's recommendation cited "rounds out the manifest-
identifier set" as supporting evidence. That phrasing is
symmetric-completeness language. The verification above demonstrates
that Target.Name is supported by INDEPENDENT consumer evidence
(swift-dependency-analysis), NOT by symmetric-completeness alone.
The recommendation is sound; only the doc-text needs strengthening
to surface the independent evidence rather than leaning on the
symmetric-completeness phrasing.

### Options

#### Option A — Trio at v1.0.0 (Package + Product + Target)

**Description**: Ship all three typealiases in the v1.0.0 release.

**Advantages**:

- Closes audit Defers (F-A2.11 / F-A3.4 / F-A3.5).
- Equips `swift-foundations/swift-dependency-analysis` to migrate its
  manifest-target identifier surface in the same wave as the linter.
- One release event; downstream consumer-migration dispatches see a
  complete manifest-identifier surface at v1.0.0.
- All three types are mechanically identical (typealias over
  `Tagged<_, Swift.String>`); incremental code cost over the pair is
  one file plus one extension declaration.

**Disadvantages**:

- Slight risk of widening the API surface beyond strict audit-driven
  need. Mitigated by the independent swift-dependency-analysis
  evidence verified at write-time.

#### Option B — Audit-minimal pair at v1.0.0 (Package + Product)

**Description**: Ship only Package.Name and Product.Name in v1.0.0;
Target.Name defers to v1.1.0 when a downstream migration dispatch
specifically requests it.

**Advantages**:

- Strict audit-driven scoping. The audit's deferred items name only
  package and product; v1.0.0 closes exactly those.
- Conservative — each shipped type has a 1:1 closure with a specific
  audit finding.
- v1.1.0 can land Target.Name additively (no breaking change).

**Disadvantages**:

- swift-dependency-analysis would either (a) wait for v1.1.0 before
  typing its target-name surface, or (b) define its own
  `Tagged<DependencyAnalysis.Target, String>` typealias and migrate
  later. Both paths waste effort vs shipping Target.Name now.
- Two release events for a single conceptual surface; readers of
  the package's evolution see Target.Name as an afterthought rather
  than a peer of Package.Name and Product.Name.

#### Option C — Extended set at v1.0.0 (Package + Product + Target + Source.Kind + ToolsVersion)

**Description**: Ship the trio plus `SwiftPM.Source.Kind` (enum
`.path | .url | .registry`) and `SwiftPM.Manifest.ToolsVersion` in
v1.0.0.

**Advantages**:

- Maximal surface — anything the linter / manifest-primitives /
  dependency-analysis might need is shipped together.

**Disadvantages**:

- `SwiftPM.Source.Kind`: no current consumer needs source-kind
  discrimination at the typed-primitive layer (per parent doc Q3
  table; F-A2.10 was disposed of as Acceptable code-gen literal).
  Symmetric-completeness shape per [RES-018] — explicit prohibition.
- `SwiftPM.Manifest.ToolsVersion`: the extractor parses
  `// swift-tools-version:` as Swift.String; the audit did not
  surface ToolsVersion as a Real Gap. No current second-consumer
  demand verified.
- Over-applies the package's scope beyond what consumers require
  at v1.0.0.

#### Option D — Trio at v1.0.0 + advisory roadmap note

**Description**: Option A, plus a README/roadmap section explicitly
naming the deferred types (Source.Kind, ToolsVersion, Registry.Scope,
Registry.Name, Identity, Version) and citing what would trigger
their addition (specific consumer demand).

**Advantages**:

- Same as Option A.
- The roadmap section publicly defers the deferred types; readers
  understand the v1.0.0 scope is intentional.

**Disadvantages**:

- Strictly additive to Option A; no real downside.

### Comparison

**Criteria**:

1. [RES-018] second-consumer hurdle cleared per type
2. Audit-closure coverage (closes F-A2.11 / F-A3.4 / F-A3.5)
3. Independent-consumer support
4. Release-cadence efficiency
5. Symmetric-completeness exclusion ([RES-018])
6. Risk of over-shipping at v1.0.0

| Criterion | A (trio) | B (pair) | C (extended) | D (trio + roadmap) |
|-----------|:---:|:---:|:---:|:---:|
| [RES-018] cleared per type | ✓ (P, Pr, T all have ≥2 consumers verified) | ✓ (P, Pr have ≥2 consumers) | ✗ (Source.Kind, ToolsVersion fail hurdle) | ✓ |
| Audit-closure coverage | ✓ | ✓ | ✓ | ✓ |
| Independent-consumer support | ✓ (swift-dependency-analysis) | partial (Target.Name's consumer waits) | ✓ | ✓ |
| Release-cadence efficiency | ✓ | ✗ (two releases for one surface) | ✓ | ✓ |
| Symmetric-completeness exclusion | ✓ (Target.Name has indep demand) | ✓ | ✗ (Source.Kind / ToolsVersion don't) | ✓ |
| Over-shipping risk | low | none | high | low |

### Theoretical grounding per [RES-018]

The institute's hurdle for new primitives is structural: the
"second consumer" requirement exists to prevent over-design where
the originating investigation is the only real demand. Verifying
the second consumer EMPIRICALLY (grep at write-time) is the rule's
operational form.

For the v1.0.0 trio:

| Type | Originating investigation | Second consumer | Hurdle cleared |
|------|---------------------------|-----------------|----------------|
| Package.Name | Linter audit F-A2.11 | swift-manifest-primitives (Manifest.Dependency.name) | ✓ |
| Product.Name | Linter audit F-A3.4 / F-A3.5 | swift-manifest-primitives (Manifest.Dependency.product) | ✓ |
| Target.Name | (none — linter does not consume target names) | swift-dependency-analysis (Manifest.Target.name) | ✓ — the originating investigation IS swift-dependency-analysis's manifest-target parsing; the linter audit's role is co-incidental |

For the broader v1.0.0+ scope:

| Type | Second-consumer verified? | Verdict |
|------|---------------------------|---------|
| Source.Kind | ✗ | Defer |
| ToolsVersion | ✗ | Defer |
| Registry.Scope | ✗ (no current registry-aware tool) | Defer per parent doc |
| Registry.Name | ✗ | Defer per parent doc |
| Identity | ✗ | Defer per parent doc |
| Version | ✗ here; addressed in companion Research | Defer to future swift-semver-primitives (see `2026-05-12-swift-semver-primitives-package-version-placement.md`) |

## Outcome

**Status**: v1.0.0 RECOMMENDATION per [RES-003a]. Principal flips to
DECISION on sign-off.

**Recommended**: **Option D** — ship the trio (Package.Name +
Product.Name + Target.Name) at v1.0.0 with an explicit README
roadmap section deferring Source.Kind / ToolsVersion / Registry.*
/ Identity to v1.1.0+ on demonstrated consumer demand, and Version
to a future `swift-semver-primitives` package per the companion
Research.

**Rationale (cleared per [RES-018])**:

1. **Target.Name has independent second-consumer evidence**: the
   originating audit (linter) does NOT consume target names; but
   `swift-foundations/swift-dependency-analysis` does, for both
   filesystem-path construction and analysis-result identity
   keying. The hurdle is cleared on substantive grounds, not on
   symmetric-completeness.

2. **The parent doc's "rounds out the set" rationale, while
   imprecise, was directionally correct**. This Research surfaces the
   substantive evidence (swift-dependency-analysis) that justifies
   the trio shape under [RES-018], and recommends the parent doc's
   wording be strengthened to cite the independent evidence rather
   than relying on symmetric-completeness phrasing.

3. **Option D's roadmap section makes the deferred-type list
   explicit**, preventing future readers from reading the v1.0.0
   scope as accidental rather than intentional. The roadmap
   becomes Source.Kind / ToolsVersion / Registry.Scope /
   Registry.Name / Identity (each gated on a verified second-
   consumer surfacing), plus Version deferred to
   swift-semver-primitives.

**Refined parent-doc text suggestion**: the v1.0.0 trio entry in
`2026-05-12-swift-spm-primitives-design.md` §Q3 SHOULD cite
swift-dependency-analysis's Manifest.Target.name + analyze.swift
path-construction usage as the Target.Name second-consumer
evidence. The current wording ("rounds out the manifest-identifier
set... multiple ecosystem consumers reference target names as
`Swift.String` (manifest-primitives, swift-manifests)") was
imprecise:
- manifest-primitives' `Manifest.Dependency` does NOT carry a
  target-name field [Verified: 2026-05-12].
- swift-manifests does not extract target names from consumer
  manifests in current code [Verified: 2026-05-12].
- swift-dependency-analysis IS the independent Target.Name consumer.

**Open questions surfaced for principal sign-off**:

1. Confirm Option D over Option A (the roadmap section is strictly
   additive; Option D is the same shape with documentation
   discipline).
2. Confirm whether the parent doc `2026-05-12-swift-spm-primitives-design.md`
   should be amended to v1.1.0 with the corrected Target.Name
   consumer citation (swift-dependency-analysis) OR whether this
   companion Research stands as the substantive citation.

## References

### Parent design Research

- `swift-institute/Research/2026-05-12-swift-spm-primitives-design.md`
  v1.0.0 RECOMMENDATION (commit `14df127`) — parent doc; §Q3 surfaces
  the open question this doc answers.

### Independent-consumer verification (per [RES-023])

[Verified: 2026-05-12 via grep + file:line read]:

- `swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.Manifest.Target.swift:6`
  — `public let name: String` on `Manifest.Target`.
- `swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.Analysis.Target.swift:5`
  — `public let name: String` on `Analysis.Target`.
- `swift-foundations/swift-dependency-analysis/Sources/Dependency Analysis/Package.analyze.swift:60, :80, :82`
  — target-name use sites (analysis identity, filesystem path
  construction).
- `swift-primitives/swift-manifest-primitives/Sources/Manifest Primitives/Manifest.Dependency.swift:24-56`
  — Dependency carries `name` (package), `product`, `path`,
  `imports` — but NOT a target-name field; module-name `imports`
  has different semantics.
- `swift-foundations/swift-linter/Sources/Linter Core/Lint.SingleFile.Materializer.swift:122`
  — hardcoded `"Lint"` target name; not extracted from consumer
  manifest.
- `swift-foundations/swift-linter/Sources/Linter Core/Lint.SingleFile.Extractor.swift`
  — extracts package and product names; does NOT extract target
  names from consumer manifests.

### Companion Research

- `swift-institute/Research/2026-05-12-swift-spm-primitives-validation-timing.md`
  v1.0.0 RECOMMENDATION — addresses open question #1.
- `swift-institute/Research/2026-05-12-swift-semver-primitives-package-version-placement.md`
  v1.0.0 RECOMMENDATION — addresses open question #3.

### Skills cited

- [RES-003] document structure
- [RES-009] multi-option analysis
- [RES-018] premature primitive anti-pattern (second-consumer
  hurdle)
- [RES-023] empirical-claim verification
- [RES-026] citations
