# DocC Multi-Target Documentation Aggregation

<!--
---
version: 1.2.0
last_updated: 2026-04-21
status: DECISION
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

### Option F — umbrella-only docs + symbol-graph patching (source shape unchanged)

*Added 2026-04-21 v1.1.0 after the swift-property-primitives 0.1.0 render
spot-check surfaced that Options B–D all produce fragmented multi-catalog
sidebars that have no UX payoff for the reader. Simplified 2026-04-21 v1.2.0
after the `swift build` symbol-graph-extraction route replaced the
`xcodebuild docbuild` route — variant `.docc/` directories dropped entirely,
symbol-graph patching became a defensive no-op.*

The insight that separates Option F from B–E: the research that
justifies the multi-target split (see `swift-primitives/swift-property-
primitives/Research/variant-decomposition-rationale.md`) is **entirely
source-level**. Narrow imports, dep-graph surface, consumer partitioning,
Core-internal hygiene. Nothing in that research argues for *documentation*
fragmentation. The documentation fragmentation was an incidental side-
effect of the source split, and it has no payoff.

Option F keeps the source shape (five library products, Core internal,
umbrella re-exports) but consolidates all `.docc` content under the
umbrella catalog:

- Every per-symbol article (`Property.md`, `Property.Typed.md`,
  `Property.View*.md`, …) lives in the umbrella catalog, with its `#`
  heading rewritten to `Property_Primitives/<SymbolPath>` (attaching
  the article as a documentation extension of the symbol as seen through
  the umbrella module).
- Variant targets carry NO `.docc/` directory — not even an empty one.
  The umbrella owns the sole catalog (see v1.2.0 finding below about
  the `swift build` pipeline which makes the `.gitkeep` placeholder
  form unnecessary).
- CI runs `swift build -c release -Xswiftc -emit-symbol-graph
  -Xswiftc -emit-symbol-graph-dir <out>`. SwiftPM compiles every
  variant + Core as a dependency and swiftc emits each module's
  symbol graph to `<out>`.
- A post-extraction script (`Scripts/patch-umbrella-symbol-graph.py` in
  the package) walks the non-umbrella graphs, builds a
  `precise-identifier → docComment` map, and injects matching comments
  into the umbrella's graph. With the `swift build` route this patches
  zero symbols in practice — swift build's symbol-graph emission
  preserves doc comments on `@_exported` re-exports, unlike
  `xcodebuild docbuild` (see v1.2.0 finding below). Retained as a
  defensive no-op in case a future Swift release regresses the
  behaviour.
- `xcrun docc convert` runs once on the umbrella catalog with
  `--additional-symbol-graph-dir` pointing at a directory containing
  ONLY the patched umbrella graph — NOT the pool of all graphs. Passing
  all graphs creates cross-module reference ambiguity because the same
  precise-identifier appears under both its declaring module and the
  umbrella; in-catalog `` `SymbolName` `` spans then fail to resolve.
  A single `.doccarchive` is produced.

| Aspect | Behavior |
|--------|----------|
| Doc comments preserved for every symbol | ✓ swift build route preserves them natively; patch step is a defensive no-op |
| Single archive (one sidebar, one `Property`) | ✓ |
| Works with stable CLI tools | ✓ `swift build` + `xcrun docc convert` (no SPM plugin, no `docc merge`, no `xcodebuild docbuild`) |
| Narrow-import precision preserved | ✓ (source targets unchanged) |
| Stability | Stable toolchain commands; patching script is ~30 lines of stdlib Python |
| `docc merge` required | ✗ (single archive obviates merge) |
| Package.swift dependency cost | Zero — preserves `[MOD-002]` |
| Variant `.docc/` directories required | ✗ (v1.2.0) swift build emits no warnings for absent variant catalogs |
| Works when `@_exported` is replaced by `public import` | No (`public import` doesn't transparently expose sibling symbols — see SE-0409); use only while `@_exported` is the umbrella pattern |

**Cost-benefit**: Option F has the cheapest long-term maintenance in the
catalog. The patching step is a single post-docbuild command invoking a
self-contained script; it replaces both the five per-scheme docbuilds of
Options B/D and the `docc merge` step of Option D. The trade-off is a
one-time migration: moving per-symbol articles into the umbrella and
rewriting their `#` headings.

**Applies when**: the package has (a) a multi-target source shape with
(b) an umbrella target using `@_exported public import` to re-export
variants, and (c) no consumer-facing requirement for per-variant
docbuild artifacts. The swift-property-primitives case satisfies all
three. Packages whose consumers genuinely need per-variant archives
(e.g., distributing documentation separately per variant) should prefer
Options B–D.

**Verified empirically**: applied to swift-property-primitives at commit
`78cd7a1` (Apr 2026). Pipeline: 1 docbuild + 1 patch + 1 convert. Output:
1 archive, full per-symbol docs, tutorial preserved, articles preserved,
visual identity preserved. Replaces the Option D pipeline that landed at
commits `794449e` / `a45845c` / `79ae689`. **v1.2.0 update**: simplified
at commit `d1cea57` to use `swift build` symbol-graph extraction instead
of `xcodebuild docbuild`; variant `.docc/` directories removed entirely;
patch step becomes a defensive no-op (see "v1.2.0 findings" below).

#### Option F — v1.2.0 findings

Two discoveries during the Apr 21 2026 post-adoption simplification pass
change how Option F is implemented, without changing the decision itself:

**Finding 1 — `swift build` vs `xcodebuild docbuild` for symbol-graph
extraction.** The v1.1.0 pipeline used `xcodebuild docbuild -scheme
"Property Primitives"` to drive symbol-graph extraction. That route has
two properties v1.2.0 simplifies past:

| Property | xcodebuild docbuild | swift build `-emit-symbol-graph` |
|----------|--------------------|----------------------------------|
| Doc comments on `@_exported` re-exports in the umbrella's graph | STRIPPED (the patch step is load-bearing) | PRESERVED (the patch step is a defensive no-op) |
| Empty variant `.docc/` directories | Warns "No valid content was found in this file" — one warning per variant per architecture (ten on our five-variant package) | No warning; swift build never enters the docbuild code path |
| Tool chain | Xcode-bundled | SwiftPM + swiftc, no Xcode-specific route |
| Derived-data footprint | Full docbuild under `DerivedData/` | Just object files + symbol graphs under `.build/` |

The `xcodebuild docbuild` doc-stripping behaviour is consistent with
DocC's archive-per-module model (Option B's cost column). Crucially,
swiftc's symbol-graph emitter does NOT apply that stripping —
`-emit-symbol-graph` emits whatever the module's public API surface
is, including re-exported symbols with their declaring-module doc
comments intact.

Mechanism: swiftc's `-emit-symbol-graph` walks the module's public
API surface and serializes each symbol with the doc comment attached
at the declaration site; `@_exported` re-exports inherit the
declaring-module comment because the symbol graph records them with
their ORIGINAL precise identifier (e.g., `s:24Property_Primitives_Core0A0V`
for a Property declared in Core, even when emitted as part of the
umbrella's graph). `xcodebuild docbuild` invokes a different symbol-graph
extractor path that applies additional filtering, which is where the
stripping happens.

**Finding 2 — variant `.docc/` directories are unnecessary under Option
F's swift-build route.** v1.1.0 recommended variant directories retain
a `.gitkeep` to satisfy `[DOC-020]`'s literal rule AND to silence the
`xcodebuild docbuild` warnings above. With swift build both reasons
fall away: no warnings are emitted, and `[DOC-020]`'s "every module
has a `.docc/`" rule is better handled by an explicit exception clause
than by gitkeep-only placeholders. Removing the directories makes the
umbrella-owns-everything invariant visible on disk.

**Cost of the swift-build route**: in exchange for these simplifications,
the CI job can no longer rely on Xcode's implicit symbol-graph
emission during `docbuild`. The pipeline has to name the emit flags
explicitly (`-Xswiftc -emit-symbol-graph -Xswiftc -emit-symbol-graph-dir
<path>`), pool the graphs, and drive `xcrun docc convert` directly.
The total CI-job size is comparable to v1.1.0 — what's lost in
implicit wiring is gained back in not having to run the patch script
for real.

**Cross-module ambiguity gotcha**: `xcrun docc convert` must receive
ONLY the patched umbrella graph via `--additional-symbol-graph-dir`,
NOT the full pool of graphs. Passing the full pool causes DocC to see
the same precise identifier (e.g., `s:24Property_Primitives_Core0A0V`
for `Property`) under both its declaring module (Core) and the
umbrella, and every in-catalog cross-reference to the symbol becomes
ambiguous — DocC can't choose which module path to resolve under, and
the cross-ref silently fails. Symptom: "Failed to resolve reference"
warnings for `` `Property` ``, `` `Property.Typed` ``, etc. Fix:
isolate the umbrella-graph file in a dedicated dir and pass only that
dir.

### Comparison

| Criterion | B: @_exported status quo | C: SPM combined-docs | D: docc merge manual | E: single-target reshape | **F: umbrella-only + patch** |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Doc comments preserved in unified view | ✗ | ✓ | ✓ | ✓ (single-archive) | **✓** |
| Works today with `xcodebuild docbuild` | ✓ | ✗ | partial | ✓ | **✓** |
| Experimental stability | stable | experimental | stable commands, hand-rolled | stable | **stable** |
| Narrow-import precision preserved | ✓ | ✓ | ✓ | ✗ | **✓** |
| Tooling complexity | lowest | low | high | lowest | **low (one script)** |
| Single-archive distribution | ✗ | ✓ | ✓ | ✓ | **✓** |
| Sidebar has one `Property` (not N) | ✗ (N catalogs side-by-side) | ✗ (still N, just combined) | ✗ (still N, just merged) | ✓ | **✓** |
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

**Status**: DECISION (v1.1.0 — Option F adopted as the ecosystem pattern).

### Key findings

1. **DocC's `@_exported public import` does not propagate per-symbol doc
   comments to the re-exporting archive.** This is a structural property of
   the archive-per-module model, not a bug. Verified empirically across all
   member kinds and all re-exported targets in swift-property-primitives.

2. **The ecosystem-idiomatic pattern is Option F** — keep the source
   multi-target split (for compile-time narrow imports), consolidate all
   `.docc` content under the umbrella catalog, and patch the umbrella's
   symbol graph with declaring-module doc comments before `docc convert`.
   Single archive, single sidebar, one `Property`. Empirically validated at
   commit `78cd7a1` in swift-property-primitives.

3. **The variant-decomposition research is source-level only.** Reading
   that research's justifications carefully — narrow imports, dep-graph
   surface, consumer use-case partitioning, Core-internal hygiene — every
   claim concerns compile-time semantics. None argues for documentation
   fragmentation. The docs fragmentation in Options B/C/D is an incidental
   side-effect of the source split, not a desired property. Option F
   decouples the two concerns cleanly.

4. **Options C and D are viable but strictly worse than Option F** for
   packages matching the ecosystem's `@_exported` umbrella shape. Option C
   costs a Package.swift dependency (swift-docc-plugin) and requires the
   experimental flag; Option D requires per-scheme docbuilds plus
   `docc merge`. Option F produces the same single-archive output from one
   docbuild and one convert with no new tooling beyond a ~30-line stdlib
   Python post-extraction script.

5. **Option B (ship as-is with a README note) is discouraged** for
   user-facing documentation. The multi-catalog sidebar has no payoff for
   readers — the sidebar groupings reflect Package.swift target
   boundaries, which consumers do not care about. Readers want "find the
   Property type, see its members, read its docs." Option F delivers that;
   Option B does not.

### Recommendations

| # | Recommendation | Priority | Rationale |
|---|---------------|----------|-----------|
| R1 | Swift Institute packages with a multi-target + umbrella + `@_exported` shape SHOULD adopt Option F for their distribution docs build | **Critical** | Produces the single-archive UX consumers want while preserving the source-level narrow-import benefit. No new dependencies, no experimental flags. |
| R2 | Packages adopting Option F SHOULD consolidate per-symbol articles into the umbrella catalog with `#` headings rewritten to `<UmbrellaModule>/<SymbolPath>`. Variant targets have NO `.docc/` directory (v1.2.0: not even a `.gitkeep`-only one) — the umbrella owns the sole catalog | **Critical** | The article-to-symbol attachment mechanism is catalog-scoped; articles must live where the symbol graph is consumed. The swift-build symbol-graph route (v1.2.0) emits no warnings for absent variant catalogs, so the v1.1.0 `.gitkeep` workaround is unnecessary. |
| R3 | Packages adopting Option F SHOULD carry a `Scripts/patch-umbrella-symbol-graph.py` (or equivalent) that walks non-umbrella symbol graphs and injects doc comments into the umbrella's graph | **Critical** | The patch is the load-bearing step that closes the `@_exported` doc-stripping gap. Without it Option F collapses back to Option B. Reference implementation ships in swift-property-primitives. |
| R4 | Swift Institute skills — `modularization`, `documentation` — SHOULD reference this research when a package's multi-target + umbrella shape is being decided or audited | **High** | Documentation and compile-time dependency concerns are separable; skills should not conflate them. |
| R5 | `[DOC-020]` ("Every module MUST have a `.docc` catalogue directory") SHOULD gain an explicit exception for variant targets whose docs are consolidated under an umbrella catalog | **High** | The literal rule is satisfied by a `.gitkeep`, but the rule's intent is "every module is documented." With Option F, variant modules are documented — through the umbrella. The exception should be named to prevent future audits from flagging Option F as a convention violation. |
| R6 | The ecosystem SHOULD publish one concrete case study of Option F (swift-property-primitives) as a blog post | **Medium** | Option F is not a DocC-team-blessed pattern; it's an ecosystem workaround for a DocC limitation. Documenting the pattern externally accelerates adoption elsewhere and gives the DocC team concrete feedback on the `@_exported` re-export gap. |

### What this does NOT recommend

- **No reshape to single-target** (Option E). The variant decomposition is
  driven by compile-time dependency-graph concerns that remain valid. Docs
  shouldn't dictate package shape; Option F preserves the source shape
  while fixing the docs UX.
- **No removal of `@_exported`** from umbrella `exports.swift` files. The
  umbrella remains the canonical consumer-facing import point; `@_exported`
  is load-bearing for it.
- **No migration to `public import`** as a replacement for `@_exported` in
  umbrellas. `public import` declares a dependency but does not transparently
  expose sibling symbols; the umbrella pattern requires `@_exported`.
- **No adoption of swift-docc-plugin** solely to get combined documentation
  (Option C). Option F matches Option C's output without the Package.swift
  dependency or experimental-flag exposure.

### Applicability to swift-property-primitives 0.1.0

Option F **was adopted for 0.1.0** at commit `78cd7a1`, then simplified
at commit `d1cea57` (v1.2.0 pipeline). Current shape: `swift build -c
release -Xswiftc -emit-symbol-graph -Xswiftc -emit-symbol-graph-dir <out>`
emits per-module symbol graphs with full `@_exported` doc comments; the
umbrella-only graph is piped through `xcrun docc convert` with
`--additional-symbol-graph-dir` pointing at a directory containing only
the umbrella graph. Output: `Property Primitives.doccarchive` with every
per-symbol page rendering full docs, the purple-accent landing page, the
tutorial, and five topical articles. No variant `.docc/` directories on
disk.

Superseded work from the same release cycle:
- Commits `794449e` / `a45845c` / `79ae689` implemented Option D (per-scheme
  docbuild + `docc merge`). Superseded by `78cd7a1` once the six-catalog
  sidebar was observed to have no reader payoff.
- Commit `60a1180` restored `.gitkeep`-only variant `.docc/` placeholders
  under the v1.1.0 pipeline to silence `xcodebuild docbuild`'s
  "No valid content" warnings. Superseded by `d1cea57` which switched to
  the swift-build pipeline and removed the variant directories entirely.

### Follow-on items

- Update `[DOC-020]` in the `documentation` skill per R5 — explicit
  exception for consolidated-under-umbrella variant targets.
- Reference this research from `[MOD-015]` in the `modularization` skill:
  consumer-import-precision + docs-consolidation are compatible, and this
  research documents how.
- Blog post per R6: "Multi-Target Swift Packages Without Multi-Catalog
  Documentation." Grounded in the swift-property-primitives case study.
- Monitor swift-docc-plugin's combined-documentation feature for parity
  with Option F. If the plugin reaches the same UX with equal or better
  ergonomics, re-evaluate.

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
