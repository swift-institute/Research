# DocC Multi-Target Documentation Aggregation

<!--
---
version: 1.0.0
last_updated: 2026-04-21
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
applies_to: [swift-property-primitives, swift-primitives, swift-standards, swift-foundations, all multi-target packages]
---
-->

## Context

The Swift Institute ecosystem routinely ships packages with multiple library
targets — a "Core" internal target plus public variant products plus an
umbrella product that `@_exported public import`s every variant. The package
in hand, `swift-property-primitives` (Apr 2026, 0.1.0 release), is the
canonical example: six library targets (Core + 5 variants + umbrella), each
carrying its own `.docc` catalog, tied together by `@_exported public import`
in the umbrella's `exports.swift`.

During the 0.1.0 render spot-check the principal observed that per-symbol
detail pages in the **umbrella's** `.doccarchive` render as signature-only —
no abstract, no parameter list, no discussion, no example. Symbol-graph JSON
inspection confirmed the root cause: `@_exported public import` re-exports
the symbol but does NOT propagate the symbol's documentation (abstract,
parameters, discussion, code blocks) to the re-exporting archive. The Core
target's own archive has the complete doc; the umbrella archive has only the
declaration.

Concrete evidence (one JSON payload per archive for the same init symbol):

```
Umbrella archive:
  property_primitives/property/init(_:).json
  abstract: <MISSING>
  primaryContentSections: ['declarations']

Core archive:
  property_primitives_core/property/init(_:).json
  abstract: "Creates a property wrapping the given base value."
  primaryContentSections: ['declarations', 'parameters', 'content']
```

This behavior is consistent across ALL re-exported symbols (Property,
Property.Typed, Property.Consuming, Property.View family, Property.View.Read
family) and ALL member kinds (initializers, stored properties, computed
properties, instance methods). It is not isolated to minimal single-line
abstracts, not isolated to `consuming`-parameter inits, and not isolated to
the Core target.

The decision the ecosystem needs: given this is a long-standing DocC
limitation, what is the idiomatic shape for multi-target Swift packages that
want unified consumer-facing documentation?

## Question

For Swift packages with multiple library targets ending in an umbrella that
re-exports all variants — the Swift Institute ecosystem shape —
what is the idiomatic 2026 approach to producing a unified DocC documentation
archive that preserves per-symbol doc comments across all targets?

## Analysis

### Prior art — upstream tracking

| Source | Claim | Status |
|--------|-------|--------|
| swiftlang/swift-docc#255 "Allow combined documentation of multiple targets" | Core feature request for multi-target archive | OPEN since 2022-05 |
| swiftlang/swift-docc#331 "`@_exported import`s should not emit symbols from external dependencies" | @_exported symbols appear without proper handling | OPEN since 2022-07 |
| swift-docc-plugin 1.4.0 (Aug 2023) | Introduces `--enable-experimental-combined-documentation` | Experimental, still present in 1.4.6 (Feb 2025) |
| swift-docc-plugin 1.4.3 (Sep 2023) | Fixes multi-dependency linking bug | Patch |
| Swift Evolution SE-0409 (2024) | `public import` official | Mainline |

Two Swift Forums threads are load-bearing for current state:

- [Combined documentation of multiple targets](https://forums.swift.org/t/combined-documentation-of-multiple-targets/59579)
  (May 2022, ongoing) — original proposal. The architecture favors *separate
  `docc convert` per target + a `docc merge` action to combine archives* over
  a single `docc convert` consuming all targets at once. The reasoning:
  bidirectional cross-target links create broken references when a dependency
  can't be built locally; linking only works in dependency order.
- [A preview of DocC's support for combined documentation](https://forums.swift.org/t/a-preview-of-doccs-support-for-combined-documentation/74373)
  (Sep 2024) — announces the experimental `--enable-experimental-combined-documentation`
  flag shipping in swift-docc-plugin 1.4.0, which wraps the merge architecture
  behind a single SPM-plugin invocation.
- [Docbuild and Merge Multiple DocC Catalogs](https://forums.swift.org/t/docbuild-and-merge-multiple-docc-catalogs/77013)
  (2024) — community confirms the Xcode-bundled DocC has limitations relative
  to the latest toolchain-bundled DocC; the combined feature needs the latter
  to produce proper landing pages and unified navigation.

### Option A — single target, multiple products

Collapse Core + variants into a single target; expose multiple products from
that target.

**Not viable.** SwiftPM binds each product to exactly one target. The
single-target-multiple-products shape is not supported.

### Option B — multi-target + umbrella with `@_exported` (status quo)

The ecosystem's current shape. Each variant is a separate target; the umbrella
`@_exported public import`s each variant's product. `xcodebuild docbuild
-scheme "Umbrella"` builds one `.doccarchive` per target — Xcode's
Documentation Viewer lays them side-by-side in its sidebar.

| Aspect | Behavior |
|--------|----------|
| Symbol presence in umbrella archive | ✓ symbols appear (re-exported) |
| Abstract / parameter / discussion preservation | ✗ stripped during re-export |
| Cross-archive navigation in viewer | ✓ sidebar lists all archives, click to switch |
| Cross-archive backlinks ("Mentioned in") | ✓ DocC auto-generates |
| Topical articles in umbrella resolve to variant symbols | ✓ resolves at docbuild time |
| Variant articles resolve to sibling variant symbols | ✗ fails unless catalogs are in umbrella |
| Self-contained umbrella archive distribution | ✗ must ship all N archives |
| Static-hosting story | Not automatic — per-archive hosting |

Discovered empirically on swift-property-primitives: every per-symbol page in
the umbrella archive has `abstract: <MISSING>` and `sections: ['declarations']`
only. Variant archives have full docs. The umbrella is therefore a navigation
hub + articles catalog, not a per-symbol reference.

**Cost-benefit**: works today with `xcodebuild docbuild` (the default build
chain); reads well in Xcode's sidebar; doesn't need any new tooling. Loses
fidelity on per-symbol pages through the umbrella; forces the consumer to
click through to the variant archive for member-level docs.

### Option C — multi-target + `swift-docc-plugin` combined documentation

Replace `xcodebuild docbuild` with the SPM plugin invocation:

```bash
swift package generate-documentation \
    --enable-experimental-combined-documentation \
    --target Property_Primitives_Core \
    --target Property_Typed_Primitives \
    --target Property_Consuming_Primitives \
    --target Property_View_Primitives \
    --target Property_View_Read_Primitives \
    --target Property_Primitives
```

Or with `--product` instead of `--target` for public products.

Produces one `.doccarchive` that contains every target's documentation with
doc comments intact — each target builds its own symbol graph; the plugin
merges them into a unified archive with combined navigation.

| Aspect | Behavior |
|--------|----------|
| Doc comments preserved per target | ✓ each symbol graph built separately |
| Combined navigation hierarchy | ✓ single sidebar, all targets |
| Cross-target symbol linking | ✓ via `` ``/TargetName/Symbol`` `` syntax |
| Landing page synthesis | ✓ with dev toolchain; limited with 6.0 stable |
| Bidirectional links | ✗ only dependency-order linking (unidirectional) |
| Platform support | Build runs on host OS (macOS; iOS/UIKit not supported in the combined flow) |
| Stability | Experimental since 1.4.0 (Aug 2023); still experimental in 1.4.6 (Feb 2025) |
| Package-level articles (custom landing) | Not yet implemented as of 2024-09 preview |
| Works with `xcodebuild docbuild` | ✗ — SPM plugin only |
| Works with Xcode Documentation Viewer | Archive is consumable once produced |

**Cost-benefit**: preserves all docs, single archive, better hosting story.
Requires committing to `swift package generate-documentation` over
`xcodebuild docbuild`. Experimental — the flag name `--enable-experimental-*`
signals instability; behaviour may change. Platform constraint to host OS is
real for cross-platform packages (less of a concern for Layer 1 primitives).

### Option D — multi-target + manual `docc merge` pipeline

Build each target's archive separately via `xcodebuild docbuild` or SPM
plugin, then run `docc merge` manually to combine into one archive.

```bash
xcodebuild -scheme "Property Primitives Core" docbuild  # per target
xcodebuild -scheme "Property Typed Primitives" docbuild  # ...
docc merge --output-path Combined.doccarchive \
    "Property Primitives Core.doccarchive" \
    "Property Typed Primitives.doccarchive" \
    # ... all six
docc process-archive transform-for-static-hosting \
    Combined.doccarchive \
    --hosting-base-path "swift-property-primitives"
```

| Aspect | Behavior |
|--------|----------|
| Doc comments preserved per target | ✓ each archive built with its own docs |
| Combined archive | ✓ after merge |
| Requires toolchain-bundled DocC | ✓ Xcode-bundled DocC lacks merge polish |
| Custom scripting | Required — not plug-and-play |
| Works across build chains | ✓ any workflow that produces per-target archives |
| Stability | Less experimental than combined-documentation; more pieces to manage |

**Cost-benefit**: more flexibility — combine any archives from any source.
Requires hand-rolled CI plumbing (bash script wrapping docbuild, merge, and
process-archive transforms). Community reports describe the workflow as
"not plug and play" — production-grade usage needs ongoing maintenance.

### Option E — single-module refactor

Collapse the 5 variants + Core into one target with internal submodule
structure. Single archive, all docs, no re-export.

**Cost**: loses `[MOD-015]` narrow-import precision — consumers can no
longer depend on a specific variant product to minimize compile-time
surface. For a primitive consumed across a large ecosystem
(e.g., swift-property-primitives consumed by buffer, heap, dictionary,
list, memory, storage, ownership primitives), the compile-time-boundary
cost can be real.

**Benefit**: the umbrella archive becomes the ONLY archive; every symbol
renders with full docs; no DocC limitation is hit.

For the Swift Institute ecosystem, this reshape would require a fresh
`/modularization` analysis and is out of scope for a docs-level decision —
the variant split was driven by consumer-dependency-graph concerns, not
documentation concerns.

### Comparison

| Criterion | B: @_exported status quo | C: SPM combined-docs | D: docc merge manual | E: single-target reshape |
|-----------|:---:|:---:|:---:|:---:|
| Doc comments preserved in unified view | ✗ | ✓ | ✓ | ✓ (single-archive) |
| Works today with `xcodebuild docbuild` | ✓ | ✗ | partial | ✓ |
| Experimental stability | stable | experimental | stable commands, hand-rolled | stable |
| Narrow-import precision preserved | ✓ | ✓ | ✓ | ✗ |
| Tooling complexity | lowest | low | high | lowest |
| Single-archive distribution | ✗ | ✓ | ✓ | ✓ |
| Hosting story (GitHub Pages etc.) | awkward | clean | clean | clean |
| Ecosystem precedent (other swift-* packages) | widespread | emerging | rare | rare for multi-variant primitives |

### Theoretical grounding

The distinction turns on **what a module's documentation archive represents**.
Two positions exist in the DocC design:

- **Archive-per-module** — each module is a self-contained unit of docs,
  scoped to symbols it declares. Re-exports are rendered as stubs pointing
  outward, not as first-class citizens. This is the current `xcodebuild
  docbuild` semantics. Aligns with Swift's module-as-unit-of-compilation
  ontology; re-exports are imports, not declarations.
- **Archive-per-distribution** — the archive represents a user-facing
  distribution, which may span multiple compilation modules stitched via
  re-export. The combined-documentation feature implements this view. The
  user's mental model is "I imported one package"; the documentation should
  match that.

The experimental flag name acknowledges the tension. DocC's core is built
around archive-per-module; the combined feature adds archive-per-distribution
on top. Both views are valid; real packages often want both.

### Empirical validation

Applied to swift-property-primitives at commit `7eb5e4f` (fresh docbuild):

| Scenario | Outcome |
|----------|---------|
| Navigate to umbrella's Property → init(_:) detail | Signature only, no abstract |
| Navigate to Core's Property → init(_:) detail | Abstract + discussion + parameter + example |
| Click `Property` from umbrella's Choosing-A-Property-Variant article | Resolves to umbrella's Property page (signature-only) |
| Click `Property` from the Property Primitives Core catalog | Resolves to Core's full Property page |
| Umbrella topical article cross-references (`<doc:Phantom-Tag-Semantics>`) | Resolve within umbrella catalog ✓ |
| Variant article references to umbrella topical article | Failed at docbuild-time; replaced with prose per Phase 7 sweep |
| "Mentioned in" backlinks from Property to umbrella articles | ✓ auto-generated, visible on Property Primitives Core/Property page |

Cognitive-dimensions evaluation (per [RES-025]):

| Dimension | B: status quo | C: SPM combined | D: docc merge |
|-----------|:---:|:---:|:---:|
| Visibility | lower — dual-path navigation | higher — single sidebar | higher — single sidebar |
| Role-expressiveness | medium — umbrella-as-hub is a real affordance | high — unified | high — unified |
| Viscosity | highest — no single archive to ship | lower — one SPM plugin call | medium — bash + merge |
| Error-proneness | medium — users think umbrella docs are complete | lower | lower |
| Abstraction | clear (module = archive) | clear (package = archive) | clear (distribution = archive) |

Option C dominates on user-visible dimensions but carries the "experimental"
caveat. Option B is maximally stable but forces the dual-path navigation
cost onto every reader.

## Outcome

**Status**: RECOMMENDATION.

### Key findings

1. **DocC's `@_exported public import` does not propagate per-symbol doc
   comments to the re-exporting archive.** This is a structural property of
   the archive-per-module model, not a bug. Verified empirically across all
   member kinds and all re-exported targets in swift-property-primitives.

2. **The idiomatic 2026 answer is `--enable-experimental-combined-documentation`**
   in swift-docc-plugin (Option C). The feature is experimental but has been
   in place since 1.4.0 (Aug 2023), received patches through 1.4.6 (Feb 2025),
   and implements the multi-target-to-single-archive architecture the DocC
   team has been converging on since issue #255 (May 2022). Works via the
   SPM command plugin; does NOT work with `xcodebuild docbuild`.

3. **The ecosystem's current shape (Option B — multi-target + umbrella with
   `@_exported`) is valid**, but with a known documentation limitation:
   per-symbol pages accessed through the umbrella show signature-only. The
   variant archives retain full docs and are reachable via Xcode's
   Documentation Viewer sidebar.

4. **The choice is between tooling commitment and documentation fidelity.**
   Option B preserves the `xcodebuild docbuild` CI workflow and ships today;
   Option C commits to `swift package generate-documentation` + an
   experimental flag and produces a higher-fidelity archive. Option D is a
   fallback for cases where Option C doesn't fit.

### Recommendations

| # | Recommendation | Priority | Rationale |
|---|---------------|----------|-----------|
| R1 | Swift Institute packages SHOULD adopt Option C (`--enable-experimental-combined-documentation`) for public-facing distribution builds | **High** | Produces the archive consumers actually want — single navigation hierarchy with full per-symbol docs. The experimental flag has been stable through three patch releases. |
| R2 | Packages using Option B (umbrella + `@_exported`) SHOULD document the limitation in their README | **High** | Readers of per-symbol docs through the umbrella find empty pages — document that the variant catalogs carry the per-symbol reference. Closes an otherwise-opaque UX gap. |
| R3 | CI workflows SHOULD retain `xcodebuild docbuild` for regression checks (zero-warning invariant) AND add `swift package generate-documentation` for the distribution archive | **Medium** | `xcodebuild docbuild` catches ref-resolution warnings per-archive; combined-documentation produces the shippable artifact. Both are useful, neither subsumes the other. |
| R4 | The combined-documentation build SHOULD use the toolchain-bundled DocC, not the Xcode-bundled version | **Medium** | Community report on Swift Forums confirms the Xcode-bundled DocC lacks the landing-page synthesis. Use `xcrun --toolchain swift-DEVELOPMENT-SNAPSHOT` or explicit toolchain selection. |
| R5 | Swift Institute skills (`code-surface`, `documentation`, `modularization`) SHOULD reference this research when a package's multi-target shape is being decided | **Medium** | Documentation-fidelity trade-offs are part of the modularization decision, not just modularization in the abstract. Link this research from `[MOD-015]` consumer-import-precision discussions. |
| R6 | This recommendation SHOULD be re-evaluated when swift-docc-plugin's combined-documentation feature exits experimental status | **Low** | Tooling maturity matters; re-verify assumptions when DocC team signals stability. |

### What this does NOT recommend

- **No reshape to single-target** (Option E). The variant decomposition was
  driven by consumer-dependency-graph concerns that remain valid. Docs
  shouldn't dictate package shape.
- **No removal of `@_exported`** from umbrella exports.swift files. The
  umbrella remains the canonical consumer-facing import point; `@_exported`
  is load-bearing for that.
- **No migration to `public import`** as a replacement for `@_exported` in
  umbrellas. `public import` declares a dependency; it does not transparently
  expose sibling symbols. The umbrella pattern requires `@_exported`.

### Applicability to swift-property-primitives 0.1.0

For the 0.1.0 release currently in flight:

- **Ship with Option B (current shape) + R2 README note.** The combined
  documentation archive can land in 0.1.1 once CI is updated. Zero-warning
  `xcodebuild docbuild` across all 6 product schemes has been achieved and
  is the acceptance criterion; Option C's combined archive is additive.
- **CI update for 0.1.1**: add a `swift package generate-documentation
  --enable-experimental-combined-documentation` step in the docs workflow;
  publish the combined archive to the hosting site alongside (or instead of)
  the umbrella-only archive.

### Follow-on items

- Swift-DocC blog post opportunity: "How the Swift Institute ecosystem
  handles multi-target documentation across 20+ packages." Concrete,
  production-scale case study for the combined-documentation feature — the
  DocC team explicitly called for feedback on real-world usage.
- Monitor `swift-docc-plugin` releases for the feature exiting experimental.
- Consider authoring a `Scripts/build-combined-docs.sh` shim in the
  swift-institute Scripts repo that wraps the SPM plugin invocation with
  ecosystem-appropriate defaults (toolchain selection, hosting base path,
  output path convention). Shared across all multi-target packages.

## References

### Upstream Swift-DocC

- [swiftlang/swift-docc#255 — Allow combined documentation of multiple targets](https://github.com/swiftlang/swift-docc/issues/255). OPEN since 2022-05.
- [swiftlang/swift-docc#331 — `@_exported import`s should not emit symbols from external dependencies](https://github.com/swiftlang/swift-docc/issues/331). OPEN since 2022-07. Tracks the upstream position that @_exported handling needs refinement.
- [swift-docc-plugin releases](https://github.com/swiftlang/swift-docc-plugin/releases). Latest 1.4.6 (Feb 2025); `--enable-experimental-combined-documentation` introduced in 1.4.0 (Aug 2023).

### Swift Forums

- [Combined documentation of multiple targets](https://forums.swift.org/t/combined-documentation-of-multiple-targets/59579) — original 2022 proposal with architectural discussion.
- [A preview of DocC's support for combined documentation](https://forums.swift.org/t/a-preview-of-doccs-support-for-combined-documentation/74373) — Sep 2024 announcement of the experimental flag.
- [Docbuild and Merge Multiple DocC Catalogs](https://forums.swift.org/t/docbuild-and-merge-multiple-docc-catalogs/77013) — community experience with `docc merge` and toolchain-bundled vs Xcode-bundled DocC.
- [Use cases for combined documentation of multiple targets](https://forums.swift.org/t/use-cases-for-combined-documentation-of-multiple-targets-in-swift-docc/59319) — Swift-DocC team's 2022 call for real-world use cases.

### Swift Evolution

- [SE-0409 Access-level modifiers on import declarations](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md) — introduces `public import` as the official replacement for `@_exported` in most cases.

### Third-party commentary

- [Alexander Weiss — "@_exported import vs public import"](https://alexanderweiss.dev/blog/2026-01-16-exported-import-vs-public-import) — Jan 2026 analysis; recommends `public import` generally, reserves `@_exported` for SDK umbrella modules.
- [Nutrient blog — "Generating API documentation for multiple targets with DocC"](https://www.nutrient.io/blog/generating-api-documentation-for-multiple-targets-with-docc/) — practitioner workflow using `xcodebuild docbuild` + custom symbol-graph combination.
- [Alexander Weiss — "DocC for Multi-Platform Documentation"](https://alexanderweiss.dev/blog/2025-03-09-docc-for-multi-platform-documentation) — 2025 multi-platform DocC patterns.

### Internal cross-references

- `swift-property-primitives/HANDOFF.md` — the 0.1.0 release handoff that surfaced this investigation.
- `swift-property-primitives/Research/variant-decomposition-rationale.md` — the 5-variant + umbrella target shape that this research investigates the documentation consequences of.
- [`docc-search-capabilities-and-merged-site-strategy.md`](docc-search-capabilities-and-merged-site-strategy.md) — prior Tier 2 ecosystem research (status: RECOMMENDATION) on `docc merge` at the swift-institute.org site level. Validated that `docc merge` produces unified landing + cross-archive navigation across independently built DocC archives (experiment `docc-merge-multi-archive-hosting/` CONFIRMED 2 of 3 acceptance criteria). **Different layer** — that research is institute-wide site-level archive aggregation across repos; this research is intra-package multi-target aggregation. Both end up recommending DocC's multi-archive combine mechanics; the layers compose cleanly.
- [`documentation-docc-alpha-launch.md`](documentation-docc-alpha-launch.md) — prior Tier 2 DECISION on Documentation.docc root-page structure for swift-institute.org alpha launch. Not directly related to multi-target aggregation but establishes the site's DocC-first posture that this research's Option C preserves.
- Swift Institute `[MOD-015]` consumer-import-precision rule — the convention that motivates multi-target shapes (and thereby creates the documentation aggregation problem this research addresses).

### Ecosystem layering

Three layers of DocC archive aggregation exist in the ecosystem, each answered by a different mechanism:

| Layer | Scope | Mechanism | Prior research |
|-------|-------|-----------|----------------|
| Intra-package | One package, multiple library targets | `--enable-experimental-combined-documentation` (Option C) | **this research** |
| Institute site | swift-institute.org main + Research.docc + Experiments.docc | `docc merge` + static-hosting transform | `docc-search-capabilities-and-merged-site-strategy.md` |
| Search over aggregated content | Full-text across the merged site | Pagefind overlay or SPA with MiniSearch/Fuse.js | `docc-search-capabilities-and-merged-site-strategy.md` |

Layer 1 and Layer 2 both use DocC's multi-archive story; they differ in whether the archives come from one package's targets (layer 1) or from independent repos (layer 2). Layer 3 addresses a separate concern (search limitations) that is orthogonal to aggregation.
