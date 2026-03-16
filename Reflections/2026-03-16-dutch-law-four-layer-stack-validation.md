---
date: 2026-03-16
session_objective: Establish and validate the four-layer Dutch law encoding stack, from namespace through legislature to composition and product layers
packages:
  - burgerlijk-wetboek-core
  - burgerlijk-wetboek-boek-2
  - burgerlijk-wetboek
  - rule-burgerlijk-wetboek-2
  - rule-besloten-vennootschap
status: pending
---

# Dutch Law Four-Layer Stack Validation

## What Happened

The session had three major phases:

**Phase 1: EU statute reorganization.** Migrated `swift-law-statute-european-union` from a monolithic Package.swift (20 statute targets) to 20 standalone packages under a new `swift-eu-legislation` GitHub org. Each package got its own Package.swift, infra files, git repo, and was pushed to GitHub as a private repo. Purely mechanical reorganization — no code modernization.

**Phase 2: Namespace packaging for BW2.** Identified that bare `Artikel N` exports from statute packages would collide at the composition layer. Designed and implemented a three-package pattern:
- `burgerlijk-wetboek-core` — `public enum \`Burgerlijk Wetboek\` {}` + `typealias BW`
- `burgerlijk-wetboek-boek-2` — all 2,767 files transformed to nest under `extension \`Burgerlijk Wetboek\`.\`2\``
- `burgerlijk-wetboek` (umbrella) — `@_exported import` of core + all 10 books

The bulk transformation required three script iterations:
1. Initial script had a logic bug (unreachable mixed-file branch) — extension-only files caught mixed files
2. Fix script caused double-wrapping on files already wrapped by script 1
3. De-duplication script cleaned up, plus 2 manual fixes for Artikel 24 cross-references needing fully qualified paths

**Phase 3: Layer stack validation.** Scaffolded the composition layer (`rule-law-nl/rule-burgerlijk-wetboek-2`) and product layer (`rule-legal-nl/rule-besloten-vennootschap` with `Aandeelhoudersregister` target). Fixed relative path issues after the composition package moved to its final location under `rule-law/rule-law-nl/`. Full chain compiles: product → composition → legislature → namespace.

Key design decisions:
- Canonical namespace uses full legal name (`` `Burgerlijk Wetboek` ``) with abbreviation as typealias (`BW`)
- `rule-` prefix for composition packages (e.g., `rule-burgerlijk-wetboek-2`)
- `rule-law-nl` and `rule-legal-nl` are GitHub organizations, not single packages
- Judiciary (case law) will follow the same 1-repo-per-unit, zero-cross-dependency, `Bool?` dependency inversion pattern as legislature
- Case law repos do NOT depend on statute repos — cross-references are `Bool?` inputs

Formalized everything in the statute-encoding skill: [LEG-ENC-040] through [LEG-ENC-045].

## What Worked and What Didn't

**Worked well:**
- The namespace pattern (`BW.\`2\`.\`Artikel 1\`.\`1\``) is elegant and compiles cleanly
- The three-package pattern (core/per-book/umbrella) generalizes to other multi-book statutes (WvSr, WvSv, Rv, WvK)
- The four-layer architecture is clean — each layer has a clear responsibility and license boundary
- Dependency inversion for cross-references (Bool? inputs) keeps leaf packages genuinely independent

**Didn't work well:**
- The bulk transformation scripts were fragile. Three iterations to get right because Python script logic had an unreachable branch (`elif has_extension` caught mixed files before `elif has_top_level_struct and has_extension`). This is a classic short-circuit evaluation bug. Should have tested on a small sample first.
- Relative paths in Package.swift are brittle across moves. When `rule-burgerlijk-wetboek-2` moved from `/Users/coen/Developer/rule-law-nl/` to `/Users/coen/Developer/rule-law/rule-law-nl/`, all relative paths broke. Absolute paths would be more robust but less portable.
- The `Artikel 24` cross-references (`` `Artikel 24`.\`1\`.Aanwijzing `` in enum associated values) required manual fixing. Bare type names in extension bodies don't resolve to the extended type's members — they go through module-level lookup, which no longer finds them after nesting.

## Patterns and Root Causes

**Pattern: namespace introduction cascades.** Adding a namespace wrapper to an existing codebase is not just "wrap in extension." It changes name resolution semantics. Inside `struct Foo { }`, `Foo` resolves to Self. Inside `extension Namespace.Foo { }`, bare `Foo` may not resolve because it's not at module level anymore. This is a Swift-specific gotcha: extensions don't automatically bring the extended type's parent namespace into scope for unqualified lookup of sibling types.

**Pattern: mixed-file detection needs structural parsing, not regex.** The initial script tried to classify files as "coordinator" vs "extension" based on regex presence of `public struct` and `extension`. But a file can have BOTH (struct + error extension). The regex approach couldn't distinguish "file has extensions because it defines Error types for its own struct" from "file IS an extension of another struct." A proper fix would be brace-matching to find the struct's closing brace, or better, using SwiftSyntax.

**Pattern: bulk transformations need a verify step.** The script reported "680 coordinators, 2085 extensions" which looked plausible, but the double-wrapping wasn't caught until build time. A post-transform verification (e.g., "no file has two `extension BW.\`2\` {` lines") would have caught this immediately.

**Pattern: layer boundaries clarify design questions.** The question "where does the Aandeelhoudersregister struct live?" was ambiguous before the layers were explicit. Once we had four named layers with clear responsibilities, the answer was obvious: the register is a product (Layer 4), statute encoding is legislature (Layer 2), and domain types shared across products go in composition (Layer 3).

## Action Items

- [ ] **[skill]** statute-encoding: Add guidance on name resolution after namespace nesting — warn that bare type names in extension bodies may not resolve, recommend fully qualified paths or `Self` for self-references in associated values [LEG-ENC-043 addendum]
- [ ] **[research]** Should all single-statute packages (advocatenwet, alcoholwet, etc.) also get a namespace enum for composition compatibility? Currently only multi-book statutes have namespaces. If single statutes get composed too, they'll need the same treatment.
- [ ] **[skill]** statute-encoding: Add judiciary encoding pattern — 1 repo per verdict, same `Bool?`/`@Splat`/`Arguments` pattern, zero cross-dependencies, `Bool?` dependency inversion for statute cross-references [LEG-ENC-050 series]
