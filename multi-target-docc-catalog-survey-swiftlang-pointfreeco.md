# Multi-Target DocC Catalog Patterns — swiftlang, apple, pointfreeco Survey

<!--
---
version: 1.0.0
last_updated: 2026-04-21
status: DECISION
tier: 1
scope: ecosystem-wide
applies_to: [swift-institute, all multi-target Swift packages]
---
-->

## Context

`docc-multi-target-documentation-aggregation.md` v1.1.0 recommends Option F
for the Swift Institute ecosystem — consolidate all `.docc` content under
the umbrella catalogue, leave variant catalogues empty. The principal
asked whether any other Swift community packages (swiftlang, Apple,
pointfreeco) use the same pattern or an alternative. This survey answers
that question with disk-level evidence from ten representative multi-target
packages.

The answer matters because Option F is novel within the Swift Institute
context; knowing whether it is also novel across the broader ecosystem
informs how we should describe and propose the pattern externally (blog
post, Swift-DocC feedback, etc.) and tells us whether other packages
have experienced and solved the same `@_exported`-doc-stripping
phenomenon that drove Option F.

## Question

Across a representative sample of multi-target Swift packages published
by swiftlang, Apple, and pointfreeco: how are `.docc` catalogues
distributed across targets? Are they distributed per target, consolidated
under an umbrella, or selectively placed on some targets and not others?
Is any package using a pattern structurally identical to the Swift
Institute's Option F?

## Analysis

### Methodology

For each surveyed package, two data points from the `main` branch:

1. Which `Sources/{target}/` directories exist (via `gh api repos/{repo}/contents/Sources`).
2. Which of those directories contain a `.docc` catalogue (via `gh api repos/{repo}/git/trees/main?recursive=1` filtered for paths ending in `.docc`).

For two packages (swift-collections, swift-nio) a third data point: the
contents of the umbrella catalogue's root page, to distinguish
"consolidated content" from "landing-page-that-links-to-variants."

Survey run: 2026-04-21.

### Findings per repository

#### apple/swift-collections — 12 targets, 9 `.docc` catalogues

Public targets have `.docc` except `RopeModule` and `SortedCollections`.
`InternalCollectionsUtilities` is internal. The umbrella `Collections`
target's source is a set of `reexports.swift` files (re-exporting each
sibling's API via `public import`), and its catalogue contains only
`Collections.md` — a landing page with six "Modules" entries, each linking
to a sibling catalogue path (`./bitcollections`, `./dequemodule`, etc.).
No per-symbol articles in the umbrella catalogue.

**Shape**: fully distributed. Every public target carries its own `.docc`.
The umbrella catalogue exists but hosts only a landing index that redirects
to sibling catalogues.

#### apple/swift-nio — 20+ targets, 5 `.docc` catalogues

Catalogues at NIO (umbrella, `Docs.docc`), NIOCore, NIOPosix,
NIOFileSystem, `_NIOFileSystem`. No catalogues at NIOConcurrencyHelpers,
NIOEmbedded, NIOFoundationCompat, NIOHTTP1, NIOTLS, NIOTestUtils,
NIOWebSocket, or the C shims / demo apps / test-support targets.

**Shape**: selective distribution. Only the umbrella, the two primary
engines (Core, Posix), and the FileSystem family ship catalogues.
Specialised modules (HTTP1, WebSocket, TLS, TestUtils) have none.

#### apple/swift-syntax — 20+ targets, 8 `.docc` catalogues

Catalogues at SwiftBasicFormat, SwiftIfConfig, SwiftLexicalLookup,
SwiftOperators, SwiftParser, SwiftSyntax (`Documentation.docc`),
SwiftSyntaxBuilder (`Documentation.docc`), SwiftSyntaxMacros. None at
SwiftCompilerPlugin, SwiftCompilerPluginMessageHandling, SwiftDiagnostics,
SwiftIDEUtils, SwiftSyntaxMacroExpansion, SwiftRefactor,
SwiftParserDiagnostics, or test-support targets.

**Shape**: selective distribution. Primary user-facing modules have
catalogues; internal / plugin / test-support modules do not. Naming
inconsistent — some `<Target>.docc`, some `Documentation.docc`.

#### apple/swift-algorithms — 1 target, 1 `.docc`

Single-target package; not informative for multi-target patterns.

#### apple/swift-async-algorithms — 4 targets, 2 `.docc`

Catalogues at AsyncAlgorithms, AsyncSequenceValidation. None at
`AsyncAlgorithms_XCTest`, `_CAsyncSequenceValidationSupport`.

**Shape**: selective distribution. Primary public modules only.

#### pointfreeco/swift-composable-architecture — 2 targets, 1 `.docc`

Catalogue at ComposableArchitecture. None at ComposableArchitectureMacros
(plugin).

**Shape**: concentrated. The primary library target owns all docs; the
macros plugin target has none. Structurally equivalent to single-target
docs — there is nothing to consolidate because the second target is a
compile-time plugin.

#### pointfreeco/swift-dependencies — 5 targets, 1 `.docc`

Catalogue at Dependencies. None at DependenciesMacros,
DependenciesMacrosPlugin, DependenciesTestObserver, DependenciesTestSupport.

**Shape**: concentrated. Primary library carries everything; macros /
test-support targets are undocumented.

#### pointfreeco/swift-snapshot-testing — 3 targets, 2 `.docc`

Catalogues at InlineSnapshotTesting, SnapshotTesting. None at
SnapshotTestingCustomDump.

**Shape**: near-concentrated. Two public targets have catalogues; the
third (integration bridge) does not.

#### pointfreeco/swift-navigation — 5 targets, 4 `.docc`

Catalogues at AppKitNavigation, SwiftNavigation, SwiftUINavigation,
UIKitNavigation. None at UIKitNavigationShim.

**Shape**: fully distributed across four platform variants. Only the
shim target has no `.docc`.

#### pointfreeco/swift-case-paths — 3 targets, 2 `.docc`

Catalogues at CasePaths, CasePathsCore. None at CasePathsMacros.

**Shape**: near-concentrated. Public library targets each have a
catalogue; macros plugin does not.

### Pattern classification

Three patterns cover all ten surveyed packages:

| Pattern | Definition | Packages |
|---------|-----------|----------|
| **A — Fully distributed** | Every public user-facing target has its own `.docc`. Umbrella (if present) is a landing-link index to siblings. | swift-collections (9 of 9 public targets), swift-navigation (4 of 4 platform variants) |
| **B — Selectively distributed** | Primary user-facing targets have `.docc`; specialised / internal / plugin / test-support targets do not. | swift-nio (5 of ~20), swift-syntax (8 of ~20), swift-async-algorithms (2 of 4) |
| **C — Concentrated on primary target** | One public target owns all docs; macros / plugins / test-support do not. Equivalent to single-target docs because the excluded targets have no reader-facing API. | swift-composable-architecture, swift-dependencies, swift-case-paths, swift-snapshot-testing |

**None of the ten packages use Option F** — the Swift Institute's
pattern where the umbrella catalogue owns ALL the content (including
per-symbol articles for symbols declared in sibling targets) and variant
catalogues are empty. Option F is novel to this survey sample.

### Sub-pattern within A: umbrella-as-landing-index

swift-collections is the closest analogue: it has an umbrella target
(`Collections`) whose `.docc` exists but contains ONLY a landing page
that links to sibling catalogues via relative URLs. Readers land on the
umbrella for the navigation index, then click through to a sibling
catalogue for per-symbol reference. Sibling catalogues carry their own
full per-symbol documentation.

This is NOT Option F. In Option F, readers find per-symbol pages with
full docs inside the umbrella catalogue. In swift-collections' Pattern
A, readers navigate FROM the umbrella TO siblings; the per-symbol pages
live in siblings.

### Why the surveyed packages don't need Option F

Three reasons the surveyed packages do not hit the `@_exported`
doc-stripping problem that drove Option F:

1. **swift-collections uses `public import` re-exports, not `@_exported`**.
   The `reexports.swift` files in `Sources/Collections/` use plain
   `public import <SiblingModule>` — which exposes the sibling's API
   transitively but does not re-export symbols into the umbrella's own
   symbol graph. The umbrella's graph is nearly empty, so there is no
   "stripped re-export docs" problem to solve. The trade-off: consumers
   `import Collections` and get every sibling's API (same as `@_exported`),
   but the umbrella catalogue cannot host per-symbol content for
   sibling-declared symbols — the symbols aren't in the umbrella's graph.

2. **Selective-distribution packages (nio, syntax, async-algorithms)
   accept per-target catalogues as the reader UX**. They don't attempt
   consolidation. Readers navigate to whichever module they need; each
   module has its own self-contained docs page. The multi-catalogue
   sidebar is accepted, not fought.

3. **Concentrated packages (pointfreeco library-plus-macros) have
   nothing to consolidate** — the macros / plugins / test-support
   targets have no public types, so there are no sibling-target symbols
   to surface in the main catalogue.

The Swift Institute's `@_exported public import` umbrella pattern sits
outside all three: it wants `@_exported`'s transparency in the source
(consumers get everything with one import, no re-statement), but also
wants the umbrella catalogue to be a SINGLE-catalogue reference, which
`@_exported`'s doc-stripping behaviour blocks. Option F closes this with
symbol-graph patching.

### Why does the Swift Institute ecosystem differ?

The Institute's packages use `@_exported public import` in the umbrella
(per ecosystem convention) specifically to enable the consumer import
`import Property_Primitives` to surface all sibling types as first-class
members of the umbrella's public namespace. This is a STRONGER
transparency guarantee than swift-collections' `public import`: in
swift-collections, `Collections.Deque` is NOT the same symbol as
`DequeModule.Deque` (they share an identifier but live in different
modules); in Property_Primitives with `@_exported`, `Property_Primitives.Property`
IS `Property_Primitives_Core.Property` (same symbol, transparently
exposed).

The stronger transparency at the source level creates the documentation
problem: DocC sees `@_exported` re-exported symbols in the umbrella's
symbol graph but strips their docs. Swift-collections' weaker
transparency dodges the problem because the sibling symbols never enter
the umbrella's symbol graph in the first place.

Option F is the price of `@_exported`'s stronger transparency:
consolidate docs at the umbrella level to match the transparency at the
import level. Packages using the weaker `public import` re-export don't
pay this price, but also don't get the stronger consumer-side
transparency.

## Outcome

**Status**: DECISION (informational survey; no ecosystem-wide rule
change triggered).

### Key findings

1. **Option F is novel in this 10-package sample**. No swiftlang, Apple,
   or pointfreeco package in the survey consolidates per-symbol articles
   under an umbrella catalogue. The Swift Institute is using a pattern
   that is not present in the surveyed public ecosystem.

2. **Three patterns cover every package surveyed**: fully distributed
   (collections, navigation); selectively distributed (nio, syntax,
   async-algorithms); concentrated (TCA, dependencies, case-paths,
   snapshot-testing). All three tolerate multi-catalogue navigation.

3. **The closest analogue (swift-collections) uses `public import`
   re-exports, not `@_exported`**. This dodges the doc-stripping problem
   but also provides weaker consumer-side transparency — sibling types
   are accessible through the umbrella import but are not re-surfaced
   as first-class members of the umbrella's namespace. The Swift
   Institute's ecosystem convention uses the stronger `@_exported` and
   pays with the consolidation requirement.

4. **Option F is grounded in an architectural choice, not a universal
   best practice**. Packages using `public import` for re-exports do not
   need Option F; packages using `@_exported` do, if they want a single
   reader-facing catalogue. Swift Institute's `@_exported` convention
   makes Option F the right fit FOR THE ECOSYSTEM without making it
   universally applicable.

### Recommendations

| # | Recommendation | Priority | Rationale |
|---|---------------|----------|-----------|
| R1 | The `[DOC-019a]` multi-target consolidation rule in the `documentation` skill SHOULD clarify that the pattern is specific to `@_exported` umbrellas, NOT to every multi-target package | **Medium** | Packages using `public import` re-exports (as swift-collections does) don't benefit from Option F and shouldn't be pushed toward it. The skill should name the trigger condition. |
| R2 | The planned blog post on Option F SHOULD frame the pattern as the solution to `@_exported`'s doc-stripping, NOT as a general multi-target docs improvement | **Medium** | Generalising the pattern beyond its trigger condition would create confusion; swift-collections/swift-nio maintainers could read the post and wonder why their (working) distributed pattern is supposedly bad. Frame Option F as the specific fix for the specific problem. |
| R3 | The `modularization` skill's guidance on umbrella patterns MAY mention the import-style trade-off: `@_exported` gives stronger transparency but imposes Option F downstream; `public import` gives weaker transparency but avoids it | **Low** | Optional enrichment; not load-bearing for any current packages. |

### What this does NOT recommend

- **No change to the current Swift Institute ecosystem's `@_exported`
  umbrella convention.** The convention is load-bearing for the
  ecosystem's consumer import story; Option F pays the docs cost of
  that convention cleanly. Switching to `public import` re-exports
  would eliminate the Option F need but also weaken consumer
  transparency — a trade-off the ecosystem has explicitly chosen.
- **No adoption of Pattern A (distributed + umbrella landing index)
  for Swift Institute packages.** Pattern A works for swift-collections
  because readers accept multi-catalogue navigation; the Swift
  Institute's principal has explicitly rejected this UX for our
  ecosystem. Option F remains the right choice.

## References

### Surveyed repositories

- [apple/swift-collections](https://github.com/apple/swift-collections) — 9 of 9 public targets have `.docc`; Pattern A (fully distributed + umbrella landing index).
- [apple/swift-nio](https://github.com/apple/swift-nio) — 5 of 20+ targets; Pattern B (selective).
- [apple/swift-syntax](https://github.com/apple/swift-syntax) — 8 of 20+ targets; Pattern B.
- [apple/swift-algorithms](https://github.com/apple/swift-algorithms) — single target; N/A.
- [apple/swift-async-algorithms](https://github.com/apple/swift-async-algorithms) — 2 of 4; Pattern B.
- [pointfreeco/swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture) — 1 of 2; Pattern C (concentrated).
- [pointfreeco/swift-dependencies](https://github.com/pointfreeco/swift-dependencies) — 1 of 5; Pattern C.
- [pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) — 2 of 3; Pattern C/B.
- [pointfreeco/swift-navigation](https://github.com/pointfreeco/swift-navigation) — 4 of 5; Pattern A.
- [pointfreeco/swift-case-paths](https://github.com/pointfreeco/swift-case-paths) — 2 of 3; Pattern C.

### Internal cross-references

- [`docc-multi-target-documentation-aggregation.md`](docc-multi-target-documentation-aggregation.md) v1.1.0 — the Tier 2 research where Option F is defined. This survey complements it with empirical evidence from the broader ecosystem.
- `swift-institute/Skills/documentation/SKILL.md` `[DOC-019a]` — the skill rule codifying Option F. R1 above suggests a clarifying edit to name the trigger condition.

### Swift Evolution / DocC

- [SE-0409 Access-level modifiers on import declarations](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md) — the `public import` semantics surveyed above.
- [swiftlang/swift-docc#331](https://github.com/swiftlang/swift-docc/issues/331) — upstream tracking of `@_exported` re-export doc-stripping.
