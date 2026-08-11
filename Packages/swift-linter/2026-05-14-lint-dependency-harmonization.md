---
status: RECOMMENDATION
research_tier: 2
applies_to:
  - swift-foundations/swift-linter
  - swift-standards/swift-spm-standard
date: 2026-05-14
supersedes:
  - HANDOFF-phase-3-workspace-discover-and-run-execute.md L121 (citation `[ARCH-LAYER-011]` was wrong; this note replaces the cited rationale)
extends:
  - 2026-05-12-swift-linter-unified-consumer-manifest.md (Migration Analysis §1, Lint.Dependency origin)
  - 2026-05-12-swift-spm-primitives-design.md (F-A2.10 Defer disposition)
references:
  - swift-spm-standard v0.3 commits 29a6d3e + cbde5cd (manifest surface + back-fill)
---

# Lint.Dependency Harmonization with L2 Package.Dependency

## Context

A handoff item ("Lint.Dependency harmonization with L2 | `[ARCH-LAYER-011]` standalone arc | Post-cascade-soak") flagged Lint.Dependency for follow-up. The cited skill ID is wrong — `[ARCH-LAYER-011]` is the Apple-Foundation rule, unrelated to SwiftPM dependency typing. The actual question is whether the consumer-facing `Lint.Dependency` (introduced 2026-05-12 as part of Shape γ) and the L2 `Package.Dependency` (landed today in `swift-spm-standard` v0.3) should converge.

State at 2026-05-14:

- `swift-linter` Package.swift line 40 already declares `.package(path: "../../swift-standards/swift-spm-standard")`.
- `Linter Core` target imports `SPM_Standard` (`Lint.File.Single.Extractor.swift:14`).
- The AST extractor (`Lint.File.Single.Extractor.dependencies`, line 53–95) **already returns `[Package.Dependency]`** — i.e., `Lint.Dependency` exists as the consumer DSL but is converted to the L2 type before any downstream processing in `Lint.File.Single.materialize` (line 247–280).
- `Lint.Dependency` (`Sources/Linter/Lint.Dependency.swift`, 111 lines) lives in the public `Linter` umbrella target. The umbrella does NOT depend on SPM Standard (`Package.swift` line 113–126).

Prior research: the unified-manifest doc (Shape γ §936) introduced `Lint.Dependency` as ~80 LOC of "public surface in the Linter product." It predates `swift-spm-standard` v0.3 (the L2 type didn't exist when Shape γ landed). The SPM-primitives design doc (line 498) explicitly flags `Lint.Dependency.swift` as a defer target for typed-primitive uptake.

## Question

Should `Lint.Dependency` and `Package.Dependency` (L2) harmonize, and if so, how?

Sub-questions:
1. Is `Lint.Dependency` a different DOMAIN concept, or the same concept as `Package.Dependency`?
2. If same, why does `Lint.Dependency` exist at all today?
3. What's the call-site cost of the four harmonization options (A–D)?
4. What does Shape γ AST extraction REQUIRE from the consumer-facing type?

## Analysis

### Q1 — Same domain or different?

**Same domain.** Both types model "a SwiftPM `.package(...)` clause": a source (path / url / registry), a name, and the products imported. `Lint.Dependency.Kind` (`.path` / `.url(URI, from:)` / `.urlRange(URI, Range)`) is a strict subset of `Package.Dependency.Source` (`.path` / `.url(_, Requirement)` / `.registry(_, Requirement)`). The L2 type is strictly more general:

| Capability                     | `Lint.Dependency`                           | `Package.Dependency`                                  |
|--------------------------------|---------------------------------------------|-------------------------------------------------------|
| `.package(path:)`              | yes                                         | yes                                                   |
| `.package(url:from:)`          | yes (`.url(URI, from: Version.Semantic)`)  | yes (`.url(String, .from(Version))`)                  |
| `.package(url:)` range         | yes (`Range<Version.Semantic>`, half-open) | yes (range via `..<` overload on `Requirement`)       |
| `.package(url:exact:)`         | no                                          | yes                                                   |
| `.package(url:branch:)`        | no                                          | yes                                                   |
| `.package(url:revision:)`      | no                                          | yes                                                   |
| `.package(id:...)` registry    | no                                          | yes (SE-0292)                                         |
| Typed `Package.Name`           | no (derived inside extractor)              | yes (`name: Package.Name`)                            |
| Typed product names            | yes (`[Product.Name]`)                      | yes (`[Product.Name]`)                                |
| Typed URI                      | yes (`URI`)                                 | no (`Swift.String` — see Q4)                          |

### Q2 — Why does `Lint.Dependency` exist at all today?

Three reasons, two of which are now moot:

1. **Historical**: it predates `swift-spm-standard` (which landed today, 2026-05-14). When Shape γ was designed (2026-05-12), no L2 SwiftPM dependency type existed; the linter had to grow its own.
2. **AST-extraction call-site shape**: Shape γ requires consumers to write `.package(...)` calls in a *literal array argument* that swift-linter can walk syntactically. This places a structural constraint on the call-site, not the value type — any factory whose call shape matches the documented forms in `Extractor.parsePackageCall` (lines 132–241) will work.
3. **Typed primitives at the call site**: `Lint.Dependency` accepts typed `URI` and `Version.Semantic` literals via Standard Library Integration string-literal conformances — a usability win the L2 type currently lacks (see Q4).

Reason 1 is gone. Reason 2 binds the *call-site shape* not the *type identity*. Reason 3 is the only live argument for keeping a separate type — and it's addressable by adding string-literal-typed factories on `Package.Dependency.Source` itself (which v0.3 already partially does).

### Q3 — Option costs

| Option | Description                                                                  | Public-surface delta                           | Engine-internal delta            | Risk |
|--------|------------------------------------------------------------------------------|------------------------------------------------|----------------------------------|------|
| A      | Delete `Lint.Dependency`; consumers write `Package.Dependency` directly.    | Breaking — every Shape γ consumer rewrites     | Extractor returns `Package.Dependency` (already does) | High — 14 consumers + canary; loses the URI/Version typed-literal ergonomics |
| B      | Make `Lint.Dependency` a thin typealias / re-export over `Package.Dependency`. | Source-stable IF call-site DSL preserved      | Type identity merges; call-site factories live on `Package.Dependency` | Medium — needs the L2 type to grow `URI`/`Version.Semantic`-typed factories |
| **C**  | **Keep `Lint.Dependency` AS the public DSL; re-shape it to mirror `Package.Dependency` 1:1; document it as a thin DSL wrapper; converter lives at the boundary (already does).** | None — current consumer call-sites unchanged   | None — extractor already converts | **Low** — codifies status quo as deliberate, drives future widening (registry / branch / revision) on schedule |
| D      | Both types stay, add bidirectional conversion at L3 (already exists one-way). | None                                           | Add reverse conversion if needed | Low but doesn't solve the duplication |
| E      | Different domain — no work needed.                                           | n/a                                            | n/a                              | n/a — eliminated by Q1 |

### Q4 — What does Shape γ extraction require?

The extractor (lines 132–241) requires:
- A literal array of `.package(...)` calls in the `dependencies:` argument.
- Recognized labels: `path:`, `url:`, `from:`, `products:`, plus unlabeled positional for `..<` ranges.
- String literals for path/url/from/range; array of string literals for products.

It does **not** require `Lint.Dependency` to be a distinct type. It does **not** care about the typed `URI` / `Version.Semantic` at the call site (it parses the raw `Swift.String` from the AST and converts itself). The typed-literal ergonomics on `Lint.Dependency` are a *consumer-facing* benefit at *Swift compile time of the eval project* (phase 2), not a phase-1 extraction requirement.

Therefore: harmonization to `Package.Dependency` (option B or C) is mechanically safe IF the consumer call-site shape is preserved.

## Outcome

**Status: RECOMMENDATION**

**Recommended option: C — keep `Lint.Dependency` as a thin public DSL, re-shape to mirror `Package.Dependency` 1:1, document the relationship, defer the L1/L2 unification.**

Rationale:

1. The harmonization the handoff item asked for **is already 90% done internally**. Lint.Dependency exists as a public consumer-facing DSL; everything downstream (`Lint.File.Single.Extractor.dependencies`, `materialize`) speaks `Package.Dependency`. The only mismatch is the public-facing type name and a small shape gap (no registry / no branch / no revision / no exact).
2. Option B (alias/re-export) requires the L2 type to grow the typed-`URI` / typed-`Version.Semantic` call-site ergonomics that Lint.Dependency provides via Standard Library Integration. That's a worthwhile L2 enhancement but it's **the L2 type's pull-up problem**, not a Lint problem.
3. Option A (delete + force consumers to write `Package.Dependency` directly) breaks 15 consumer call-sites for no semantic gain — and forfeits the typed-URI/typed-Version literal ergonomics the consumer DSL provides today.
4. Option C is documentation work plus a small shape-widening: add registry / branch / revision / exact factories on `Lint.Dependency` to match `Package.Dependency.Source`. Cost: ~30 LOC. Benefit: the public surface tracks the L2 type's capabilities; consumers gain the four missing forms; the boundary conversion stays trivial.

### Migration plan (Option C)

1. **Document `Lint.Dependency` as a thin DSL over `Package.Dependency`** in the doc-comment header. Reference `swift-spm-standard` as the wire-format authority. Add a `// Note: harmonized with Package.Dependency per Research/2026-05-14-lint-dependency-harmonization.md` line.
2. **Widen `Lint.Dependency.Kind` and add factories** to cover the four missing SwiftPM forms: `.package(url:exact:)`, `.package(url:branch:)`, `.package(url:revision:)`, `.package(id:...)` (registry). Each new factory calls through to a corresponding `Package.Dependency.Source` constructor when the boundary converter (currently inline in the extractor) runs. *Estimated effort: 30 LOC + tests.*
3. **Add an explicit converter** `extension Package.Dependency { init(_: Lint.Dependency) }` in `Linter Core` (where `SPM_Standard` is already imported). The extractor currently builds `Package.Dependency` from raw AST strings; the converter formalizes the value-level path for any future caller.
4. **Pull-up follow-up (separate arc, defer-track)**: file an issue against `swift-spm-standard` to add typed-URI / typed-Version-Semantic factory overloads on `Package.Dependency.Source`. Once those land, evaluate whether Option B (alias) becomes attractive — the only remaining barrier is then API-surface clutter, not capability.

### Why NOT option B today

The L2 type currently uses `Swift.String` for URLs (`Package.Dependency.Source.url(Swift.String, ...)`). The Lint DSL uses `URI`. Replacing the Lint DSL with the L2 type would force consumers to either drop the typed `URI` literal at the call site or convert manually. That's a regression in the typed-primitives audit direction (see `swift-foundations/swift-linter/Research/2026-05-12-typed-primitive-adoption-audit.md`). The right fix is to widen the L2 type, then revisit. Option C buys us the documentation alignment and the shape-parity widening NOW without forcing a premature L2 ergonomic decision.

## Open Questions

1. **Should `Package.Dependency.Source` adopt typed `URI`?** The L2 doc-comment notes "the URL is the literal string the consumer wrote" — a deliberate stay-strings choice. Worth a separate research note (`URI`-vs-`Swift.String` at the L2 wire-format boundary) before option B becomes viable. *Owner: principal.*
2. **Does any non-linter consumer want to construct `Lint.Dependency` programmatically?** If yes, a `Package.Dependency → Lint.Dependency` reverse conversion is needed. Current evidence: no — `Lint.Dependency` is consumed exclusively by AST extraction. *Owner: principal — confirm before adding the reverse converter.*
3. **Does the parent-chain manifest format need to expose dependencies?** The Lint.Manifest wire format (Role B in the unified-manifest doc) currently doesn't carry deps. If it ever does, harmonizing on `Package.Dependency` becomes load-bearing for the manifest's Codable shape. *Watch this — it's the path that would force option B.*

## References

- `/Users/coen/Developer/swift-foundations/swift-linter/Sources/Linter/Lint.Dependency.swift` (111 lines; the public DSL)
- `/Users/coen/Developer/swift-foundations/swift-linter/Sources/Linter/Lint.run.swift:114–127` (the consumer entry point that takes `[Lint.Dependency]`)
- `/Users/coen/Developer/swift-foundations/swift-linter/Sources/Linter Core/Lint.File.Single.Extractor.swift:14, 53–95, 132–241` (AST extractor returning `[Package.Dependency]`)
- `/Users/coen/Developer/swift-foundations/swift-linter/Sources/Linter Core/Lint.File.Single.swift:247–280` (materialize step using `Package.Dependency` end-to-end)
- `/Users/coen/Developer/swift-foundations/swift-linter/Package.swift:40, 104` (`swift-spm-standard` declared + `SPM Standard` linked into `Linter Core`)
- `/Users/coen/Developer/swift-standards/swift-spm-standard/Sources/SPM Standard/Package.Dependency.swift` (L2 type, 88 lines)
- `/Users/coen/Developer/swift-standards/swift-spm-standard/Sources/SPM Standard/Package.Dependency.Source+Factory.swift` (the labeled factory overloads)
- `/Users/coen/Developer/swift-institute/Research/2026-05-12-swift-linter-unified-consumer-manifest.md:777, 936` (Shape γ origin of `Lint.Dependency`)
- `/Users/coen/Developer/swift-institute/Research/2026-05-12-swift-spm-primitives-design.md:42, 195, 498` (defer disposition tying Lint.Dependency to the L1/L2 typed-primitive direction)
- `/Users/coen/Developer/swift-primitives/swift-carrier-primitives/Lint.swift` (canary consumer demonstrating call-site shape)
