# SLI Granularity — Single Bundle vs. Per-Conformance Sub-Targets

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: RECOMMENDATION
tier: 2
---
-->

## Context

The current `swift-tagged-primitives` ships a single `Tagged Primitives Standard Library Integration` (SLI) library product bundling all opt-in stdlib protocol conformances on `Tagged`:

| Conformance | File |
|---|---|
| `Identifiable` | `Tagged+Identifiable.swift` |
| `LosslessStringConvertible` | `Tagged+LosslessStringConvertible.swift` |
| `Sequence` | `Tagged+Sequence.swift` |
| `Collection` | `Tagged+Collection.swift` |
| 7 stdlib literal protocols | `Tagged+Literals.swift` (single file, bundled `@_disfavoredOverload` discipline) |
| `ExpressibleByArrayLiteral` / `ExpressibleByDictionaryLiteral` | `Tagged+Literals.swift` (carve-out section) |

Consumers opt into the entire bundle via `import Tagged_Primitives_Standard_Library_Integration`. There is no per-conformance granularity: a consumer who wants only `Identifiable` (e.g., for SwiftUI `List` integration) gets the full literal-conformance surface as a side effect, including the `unsafeBitCast` carve-out. Conversely, a consumer who wants only literal ergonomics gets the wrapper-vs-content conflation that `Sequence`/`Collection` introduce.

This doc evaluates whether SLI should remain a single bundle or split into per-conformance sub-targets.

**Trigger**: Pre-launch forums-review pressure-test simulation (2026-04-30) surfaced this question via simulated post 11 (the c0 design-alternatives reviewer): "what if SLI shipped as 5 sub-targets — `Tagged Primitives Identifiable`, `Tagged Primitives Literals`, `Tagged Primitives Sequence-Collection`, etc. — letting consumers opt into one without the others?" Per `[FREVIEW-018]`, the post was promoted from archetype-shaped to partially-load-bearing under manual escape-hatch because per-conformance granularity is a real design alternative not previously codified.

**Scope**: Package-specific (`swift-tagged-primitives`); informs related SLI packages in the primitives layer (e.g., `swift-carrier-primitives` SLI).

## Question

Should the `Tagged Primitives Standard Library Integration` library product split into per-conformance sub-targets to give consumers fine-grained opt-in?

## Prior art

- [`sli-literal-vs-strideable-tradeoff.md`](./sli-literal-vs-strideable-tradeoff.md) — the parallel decision (literals over Strideable in SLI). The trade-off doc's footgun analysis at lines 105-112 acknowledges that "the package-level granularity of SLI imports means consumers cannot opt into one without the other"; this doc addresses that observation directly.
- [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md) — establishes the silent-overload-resolution footgun analysis. The literal family ships bundled because the seven literal conformances share the same `@_disfavoredOverload` discipline; splitting *within* the literal family would not change the footgun calculus.
- `swift-carrier-primitives` SLI shape — the precedent. Carrier's SLI bundles its conformances similarly. Splitting tagged's SLI without splitting carrier's would create asymmetric ecosystem precedent.
- `[MOD-015]` (supplementary decomposition; umbrella canonical) — the package modularization rule. SLI is currently the supplementary variant; sub-target splits would extend supplementary decomposition.

## Analysis

### Option A — Status quo (single SLI bundle)

| Pros | Cons |
|---|---|
| Single import, single Package.swift entry, single product graph node. | All-or-nothing opt-in: consumers wanting one conformance pay for all. |
| The `@_disfavoredOverload` discipline applies uniformly across the whole literal family (avoiding the footgun documented in `tagged-literal-conformances-fresh-perspective.md`). | The `unsafeBitCast` carve-out's surface (Array/Dict literals) is bundled with non-bitcast conformances; consumers who want only `Identifiable` import the carve-out's symbols whether they use them or not. |
| Matches `swift-carrier-primitives`'s precedent and the broader Institute primitives convention. | The literal-conformance footgun (with Strideable; documented in the trade-off doc) has bundle-level reach: a consumer importing SLI for `Sequence` gets the full literal surface that may interact with their downstream Strideable types. |
| One product fewer in `Package.swift`; reduced cognitive load for consumers. | Cannot opt into Sequence without also opting into Collection (they're separate files but in the same target). |

### Option B — Per-conformance sub-targets

Hypothetical split:

```swift
products: [
    .library(name: "Tagged Primitives", targets: ["Tagged Primitives"]),
    .library(name: "Tagged Primitives Identifiable", targets: ["Tagged Primitives Identifiable"]),
    .library(name: "Tagged Primitives LosslessStringConvertible", targets: ["Tagged Primitives LosslessStringConvertible"]),
    .library(name: "Tagged Primitives Sequence", targets: ["Tagged Primitives Sequence"]),
    .library(name: "Tagged Primitives Collection", targets: ["Tagged Primitives Collection"]),
    .library(name: "Tagged Primitives Literals", targets: ["Tagged Primitives Literals"]),  // 7 stdlib literals + Array/Dict carve-out
    .library(name: "Tagged Primitives Standard Library Integration", targets: ["Tagged Primitives Standard Library Integration"]),  // umbrella that depends on all of the above
],
```

| Pros | Cons |
|---|---|
| Per-conformance opt-in: consumers pull `Tagged_Primitives_Identifiable` for SwiftUI integration without inheriting the literal-conformance surface. | 5+ new product entries in `Package.swift` and 5+ new target directories under `Sources/`; ~5× the boilerplate for module declarations and `@_exported` re-exports. |
| The bitcast carve-out lives in its own sub-target (`Tagged Primitives Literals`); consumers who want non-bitcast conformances avoid the `unsafe` surface area entirely. | The literal family's `@_disfavoredOverload` discipline is per-protocol; splitting Integer/Float/Boolean/etc. into separate sub-targets does not change footgun behaviour because all 7 still share the resolution surface when imported together. Splitting the literal family is therefore only meaningful as "literals as a group vs. not". |
| Consumers can adopt SLI gradually as they prove out each conformance's trade-off. | Test target dep graph grows: the test target needs all sub-targets to exercise every conformance. The Test Support `@_exported` re-export becomes a multi-import.

| Sub-targets compose: a consumer who wants Sequence + Identifiable but not Collection can express that. | The `swift-carrier-primitives` precedent stays bundled; splitting tagged but not carrier creates asymmetric ecosystem shape and inconsistent consumer expectations. |
| Matches the per-conformance research doc + experiment shape (10 absence docs, 10 experiments) — making the per-conformance granularity legible in package structure too. | The `Tagged Primitives Standard Library Integration` umbrella product becomes a thin re-export shell; consumers who want everything still import that, and consumers who want one thing import the specific sub-target. The umbrella is preserved for backwards compatibility. |

### Option C — Hybrid: keep bundle as default, split only the carve-out

A third option sits between A and B: keep the SLI bundle for the four non-bitcast conformances + 7 stdlib literals (which share `@_disfavoredOverload` discipline), but split the Array/Dict carve-out into its own product (`Tagged Primitives Collection Literals`). Consumers who want SLI without the `unsafeBitCast` surface import only the bundle; consumers who explicitly want collection-literal ergonomics opt into the carve-out separately.

| Pros | Cons |
|---|---|
| Isolates the `[MEM-SAFE-001]` carve-out's surface area to a single explicit opt-in. | One more product entry; still asymmetric vs. carrier-primitives. |
| Preserves the literal family's bundled `@_disfavoredOverload` discipline for the 7 stdlib literals. | The carve-out's surface is small (2 conformances, ~20 lines of code); the splitting cost may exceed the benefit for most consumers. |
| Consumers reading "I imported SLI; do I have unsafeBitCast in my dep graph?" get a clean answer ("only if you also imported `Tagged Primitives Collection Literals`"). | Splits the literal family across two targets, breaking the file-organization grouping. The Tagged+Literals.swift file would split into two files (or stay in one file but ship via two targets, which SwiftPM does not support). |

## Empirical considerations

- **Build time**: per the package's `swift build` measurements, the SLI target compiles in <1s; splitting into 5 targets would not materially change build time at this scale. Per-target compilation parallelism would slightly improve incremental builds for consumers touching only one conformance.
- **API surface**: the umbrella `Tagged_Primitives_Standard_Library_Integration` import surface is the canonical consumer name across the ecosystem. Splitting requires every consumer Package.swift to explicitly enumerate which sub-target(s) they want — visibility cost.
- **Documentation**: per-conformance docs already exist (10 `principled-absence-*.md` + 10 experiments). Splitting at the package level would mirror this structure but adds README maintenance: each sub-target gets its own line in the Architecture file table.
- **Test target**: the existing `Tagged Primitives Standard Library Integration Tests` target imports SLI and exercises each conformance via per-file test suites (Tagged+Identifiable Tests.swift, Tagged+Sequence Tests.swift, etc.). Splitting SLI does NOT change this — the test target would still need to import each sub-target.

## Outcome

**Status**: RECOMMENDATION — Stay with Option A (single SLI bundle) for 0.1.x; revisit at 0.2.0 (or earlier if a real consumer requirement surfaces).

### Rationale

1. **The cost-benefit doesn't favour splitting at current scale.** SLI ships 5 logical conformance groupings. Splitting adds ~5 new products + ~5 new target directories + ~5 new test imports — non-trivial Package.swift complexity for consumers and maintainers. The per-conformance opt-in benefit is real but not yet load-bearing for any known consumer requirement.
2. **The `@_disfavoredOverload` discipline IS bundle-level.** Splitting the literal family into separate sub-targets does not change the silent-overload-resolution footgun behaviour — once a consumer imports any of the literal sub-targets, the resolution surface is the same as importing all of them. The "I want only Integer literals, not String literals" use case doesn't exist in practice (consumers who want the typed-init ergonomics get the whole literal grammar).
3. **The carve-out's surface is bounded.** The `unsafeBitCast` is at exactly 2 sites in `Tagged+Literals.swift:121, 133`. The file-block documentation, the source-level `unsafe` keyword, and the per-protocol absence research doc collectively make the carve-out auditable without requiring it to live in a separate sub-target. A consumer who wants "SLI without `unsafeBitCast` surface" in their dep graph can today author per-domain wrapper structs (Option C in `Research/principled-absence-array-dict-literal.md`) — the affordance exists.
4. **Ecosystem consistency**: `swift-carrier-primitives` ships SLI as a single bundle. Splitting tagged's SLI without splitting carrier's would create asymmetric consumer expectations. Splitting both is a coordinated change across two packages with separate versioning trajectories.
5. **The bar to revisit**: a real consumer requirement that cannot be satisfied within Option A's bundle model — e.g., a downstream package whose own SLI's literal-conformance discipline conflicts with tagged's, OR a security-sensitive consumer who needs build-graph evidence of `unsafeBitCast` exclusion. Until then, the bundle model carries.

### Future evolution path

If/when granular opt-in becomes load-bearing:

- **0.2.0 minor-version bump** to add per-conformance sub-targets while preserving the umbrella `Tagged Primitives Standard Library Integration` product as a meta-target that depends on all sub-targets. Consumers using the umbrella import path see no API change; consumers wanting granular opt-in adopt the new sub-targets explicitly.
- **Coordinate with `swift-carrier-primitives`** to ship the same shape simultaneously, preserving cross-package consistency.
- **Update the SemVer commitment paragraph** in README to record that the umbrella's contents may shrink (additive: more sub-targets) or that consumers depending on the umbrella inherit any new sub-targets. Removing a sub-target from the umbrella is breaking and requires a major-version bump.

The 0.1.x line commits to the umbrella shape; 0.2.0+ may evolve.

### Decision documentation

This RECOMMENDATION supersedes the implicit "single bundle" default by codifying both the rationale for staying bundled AND the migration path for splitting. Future audit cycles should reference this doc when the SLI granularity question recurs (which it will — it is one of the top-5 predicted forum critique angles per `Audits/forums-review/forums-review-objections-2026-04-30.md` Angle 1).

## References

- [`sli-literal-vs-strideable-tradeoff.md`](./sli-literal-vs-strideable-tradeoff.md) — parallel SLI policy decision; documents the package-level granularity observation that motivates this doc.
- [`principled-absence-array-dict-literal.md`](./principled-absence-array-dict-literal.md) v1.2.1 — bitcast carve-out provenance + ABI commitment status.
- [`tagged-literal-conformances-fresh-perspective.md`](./tagged-literal-conformances-fresh-perspective.md) — the silent-overload-resolution footgun analysis (which applies bundle-level, not per-conformance).
- `Audits/forums-review/forums-review-objections-2026-04-30.md` Angle 1 (layering-modularity, score 52.46) — the predicted critique vector this doc closes.
- `Audits/forums-review/forums-review-triage-2026-04-30.md` post 11 (escape-hatched to partially-load-bearing) — the simulated reviewer who proposed Option B.
- `[MOD-015]` (supplementary decomposition; umbrella canonical) — the modularization rule this RECOMMENDATION applies.
