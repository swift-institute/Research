# Primitives Public API Graph Analysis

<!--
---
version: 1.1.0
last_updated: 2026-04-13
status: RECOMMENDATION
tier: 1
---
-->

## Context

The Swift Institute swift-primitives monorepo contains 132 sub-packages across 9+ tiers. Earlier research ([ai-context-reduction-via-type-system-tooling.md](ai-context-reduction-via-type-system-tooling.md)) recommended a symbol graph pipeline as Phase 1 for AI-assisted API discovery. This document reports the results of executing that pipeline: extracting symbol graphs from all packages, distilling them into a compact API graph, and analyzing the public API surface for structural gaps, composition patterns, and improvement opportunities.

### Methodology

1. **Extraction**: `swift package dump-symbol-graph --skip-synthesized-members` run on each of the 132 sub-packages sequentially (parallel SPM causes shared-cache contention).
2. **Distillation**: Python script parses all `.symbols.json` files into a single `public-api-graph.json` containing every module's types, relationships, and cross-module extensions.
3. **Analysis**: 8 automated analyses against the distilled graph, plus manual interpretation.

### Artifacts

| File | Location | Size |
|------|----------|------|
| Extraction script | `swift-primitives/Scripts/extract-symbol-graphs.sh` | — |
| Distillation script | `swift-primitives/Scripts/distill-symbol-graphs.py` | — |
| Analysis script | `swift-primitives/Scripts/analyze-api-graph.py` | — |
| Raw API graph | `swift-primitives/.build/public-api-graph.json` | 9.8 MB |
| Analysis report | `swift-primitives/.build/api-analysis.md` | 41 KB |

## Question

What does the public API graph of swift-primitives reveal about structural gaps, composition health, and protocol adoption across the ecosystem?

## Analysis

### Scale

| Metric | Count |
|--------|-------|
| Packages with Package.swift | 132 |
| Packages with extractable symbol graphs | 115 |
| Total modules declared | 435 |
| Non-empty modules | 98 |
| Empty modules (stubs/planned) | 337 |
| Public symbols (own) | 6,144 |
| Public symbols (cross-module extensions) | 7,118 |
| Total public symbols | 13,262 |
| Relationships (memberOf, conformsTo, etc.) | 19,022 |
| Protocols defined | 59 |
| Cross-module extension edges | 366 |

**Key ratio**: More symbols live in cross-module extensions (7,118) than in the modules' own declarations (6,144). This confirms the compositional architecture — modules define core types, then other modules extend them with capabilities.

### Finding 1: Module size distribution

The richest modules by public symbol count:

| Module | Symbols | Types | Methods | Properties | Package |
|--------|---------|-------|---------|------------|---------|
| Geometry_Primitives | 585 | 55 | 183 | 209 | swift-geometry-primitives |
| Dimension_Primitives | 473 | 89 | 33 | 91 | swift-dimension-primitives |
| ASCII_Primitives | 340 | 14 | 26 | 294 | swift-ascii-primitives |
| Test_Primitives_Core | 260 | 37 | 15 | 111 | swift-test-primitives |
| Time_Primitives_Core | 253 | 49 | 23 | 86 | swift-time-primitives |
| Binary_Primitives_Core | 207 | 38 | 16 | 65 | swift-binary-primitives |

Distribution stats (98 non-empty modules): mean 62.7, median 31, min 1, max 585.

The thinnest non-empty modules (1–8 symbols) include namespace stubs (`Algebra_Primitives_Core`, `Index_Primitives_Core`, `Linux_Primitives`) and core type definitions that exist primarily to be extended by other modules.

337 empty modules represent the planned-vs-actual gap. These are declared in Package.swift but have no source files or only re-export modules.

### Finding 2: Namespace structure

Type nesting depth distribution:

| Depth | Count |
|-------|-------|
| 1 | 133 |
| 2 | 423 |
| 3 | 257 |
| 4 | 80 |
| 5 | 13 |

157 unique top-level namespaces. Depth 2 dominates (423 types), consistent with `Nest.Name` convention. The 133 depth-1 types are the namespace roots themselves (e.g., `Geometry`, `Memory`, `Buffer`).

Largest namespaces: Geometry (47 members), Linear (25), Time (21), Sequence (20), Binary (15), Heap (15), ASCII (14), Rendering (14).

### Finding 3: Protocol adoption pyramid

| Tier | Protocol | Module | Conformances |
|------|----------|--------|-------------|
| Universal | Equation.Protocol | Equation_Primitives_Core | 126 |
| Universal | Sequence.Protocol | Sequence_Primitives_Core | 118 |
| Core | Parser.Protocol | Parser_Primitives_Core | 99 |
| Core | Sequence.Iterator.Protocol | Sequence_Primitives_Core | 97 |
| Broad | Hash.Protocol | Hash_Primitives_Core | 44 |
| Broad | Collection.Protocol | Collection_Primitives | 41 |
| Broad | Sequence.Drain.Protocol | Sequence_Primitives_Core | 41 |
| Broad | Sequence.Clearable | Sequence_Primitives_Core | 40 |
| Moderate | Comparison.Protocol | Comparison_Primitives_Core | 36 |
| Moderate | Parser.Printer | Parser_Primitives_Core | 33 |
| Narrow | Witness.Protocol | Witness_Primitives | 21 |

**Drop-off**: Equation/Sequence (~120) → Hash/Collection (~42) is a steep drop. This may indicate types that should conform to Hash/Collection but don't yet.

**Orphaned protocols** (0 conformances):

| Protocol | Module | Assessment |
|----------|--------|-----------|
| Binary.Aligned | Binary_Primitives_Core | Likely awaiting conformances |
| Codable | Coder_Primitives | Dead abstraction or unbuilt bridge |
| Dependency.Key | Dependency_Primitives | No consumers yet |
| Lifetime.Disposable | Lifetime_Primitives | No consumers yet |
| Numeric.Quantized | Numeric_Primitives | No consumers yet |
| Parser.ParserPrinter | Parser_Primitives_Core | Note: Parser.Printer has 33 conformances |
| Random.Generator | Random_Primitives | No consumers yet |

**Low adoption** (1–2 conformances): Collection.Slice.Protocol (1), FormatStyle (1), Memory.Aligned (1), Affine.Discrete.Vector.Protocol (2), Coder.Protocol (2), Ordinal.Protocol (2).

### Finding 4: Cross-module extension topology

The extension graph is hub-and-spoke:

**Most extended modules** (receiving extensions from other modules):

| Module | Extensions received |
|--------|-------------------|
| Kernel Primitives Core | 2,864 |
| Swift stdlib | 2,065 |
| Buffer Primitives Core | 1,407 |
| Parser Primitives Core | 1,157 |
| Bit Primitives Core | 829 |
| Queue Primitives Core | 810 |
| Binary Primitives Core | 696 |
| Property Primitives | 660 |
| Identity Primitives | 630 |
| Tree Primitives Core | 504 |

268 modules extend outward, but only 53 modules receive extensions. This concentration is expected for a primitives layer — Core modules define types, satellite modules add capabilities.

### Finding 5: Parser/Serializer asymmetry

| Domain | Parser modules | Serializer modules |
|--------|---------------|-------------------|
| Generic (combinators) | 38 | 4 |
| Binary | 8 | 0 |
| ASCII | 3 | 3 (balanced) |

The parser infrastructure is approximately 10× richer than serializer. Binary has a full parser package but no binary-serializer counterpart.

### Finding 6: Input without Output

`swift-input-primitives` provides 84 symbols, Input.Protocol (14 conformances), and Input.Stream.Protocol (20 conformances). No `swift-output-primitives` exists.

### Finding 7: Package-level isolation

Isolation metric: packages whose modules neither extend other packages' types nor have their types extended by other packages. Intra-package composition (modules within the same package extending each other) is correctly excluded — that's expected internal structure, not cross-package isolation.

**22 truly isolated packages** (non-empty, zero cross-package composition):

| Package | Symbols | Assessment |
|---------|---------|-----------|
| swift-bitset-primitives | 130 | Rich API, zero composition bridges |
| swift-predicate-primitives | 125 | Rich API, fully self-contained |
| swift-token-primitives | 125 | Rich API, no composition bridges |
| swift-infinite-primitives | 64 | 11 Infinite.Enumerable conformances but no outbound |
| swift-ownership-primitives | 60 | Cross-cutting concept, should compose with Memory/Buffer/Storage |
| swift-serializer-primitives | 50 | Counterpart to heavily-composed Parser |
| swift-effect-primitives | 42 | Isolated effect system |
| swift-text-primitives | 41 | Should bridge to String, ASCII, Source |
| swift-loader-primitives | 37 | — |
| swift-cache-primitives | 17 | — |
| swift-dependency-primitives | 17 | — |
| swift-reference-primitives | 17 | — |
| swift-coder-primitives | 16 | — |
| swift-module-primitives | 13 | — |
| swift-positioning-primitives | 13 | — |
| swift-lifetime-primitives | 11 | — |
| swift-diagnostic-primitives | 8 | — |
| swift-witness-primitives | 7 | — |
| swift-random-primitives | 6 | — |
| swift-range-primitives | 3 | — |
| swift-locale-primitives | 2 | — |
| swift-index-primitives | 1 | — |

The top 5 (Bitset, Predicate, Token, Infinite, Ownership) are architecturally significant — they have substantial APIs but exist as islands in the composition graph.

### Finding 8: Domain coverage map

Domains with the most developed APIs:

| Domain | Packages | Symbols |
|--------|----------|---------|
| geometry | 1 | 585 |
| dimension | 1 | 473 |
| ascii | 3 | 340 |
| test | 1 | 260 |
| time | 1 | 253 |
| algebra | 13 | 275 |
| binary | 2 | 207 |
| rendering | 1 | 160 |
| region | 1 | 158 |

Domains with zero symbols (declared but empty): abstract, arm, backend, driver, intermediate-representation, symbol, syntax, type, x86.

Notable: Kernel has 28 modules but only 7 own symbols — nearly all API surface lives in cross-module extensions, making it the most extension-heavy package.

## Outcome

**Status**: IN_PROGRESS

### Established

1. The symbol graph extraction pipeline works and produces actionable data across 115/132 packages.
2. The public API graph (13,262 symbols, 19,022 relationships) fits comfortably in a single JSON file and can be analyzed programmatically.
3. The compositional architecture is confirmed: more symbols exist in cross-module extensions (7,118) than in own declarations (6,144).

### Actionable findings requiring follow-up

| Priority | Finding | Suggested action |
|----------|---------|-----------------|
| High | Parser/Serializer 10:1 asymmetry | Scope serializer combinator parity |
| High | Bitset/Predicate/Token isolation (125+ symbols each) | Investigate why — intentional or missing bridges? |
| High | 7 orphaned protocols | Triage: remove dead ones, implement conformances for live ones |
| Medium | Ownership isolation (60 symbols) | Should compose with Memory/Buffer/Storage |
| Medium | Input without Output | Determine if Output primitives are needed |
| Medium | Hash/Collection conformance gap (126→44 drop) | Audit which types should conform but don't |
| Low | 337 empty modules | Informational — planned-vs-actual gap |

### Next steps

- Drill into the Bitset/Predicate/Token isolation to determine whether it's intentional (self-contained domains) or a composition gap.
- Triage orphaned protocols — especially Parser.ParserPrinter (0 conformances) vs Parser.Printer (33 conformances).
- Scope the serializer combinator gap (what subset of the 38 parser modules needs a serializer counterpart?).
- Re-run extraction periodically as packages mature — the 337 empty modules will shrink over time.

## References

- [ai-context-reduction-via-type-system-tooling.md](ai-context-reduction-via-type-system-tooling.md) — parent research recommending this pipeline
- `swift-primitives/.build/public-api-graph.json` — raw data
- `swift-primitives/.build/api-analysis.md` — full automated analysis report
- `swift-primitives/Scripts/extract-symbol-graphs.sh` — extraction script
- `swift-primitives/Scripts/distill-symbol-graphs.py` — distillation script
- `swift-primitives/Scripts/analyze-api-graph.py` — analysis script
