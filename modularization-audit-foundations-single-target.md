# Modularization Audit: swift-foundations Single-Target Packages

**Date**: 2026-03-20
**Scope**: 39 single-target packages in swift-foundations
**Rules**: MOD-008 (split decision), MOD-011 (test support), MOD-006 (dep minimization), MOD-010 (stdlib isolation), MOD-DOMAIN (coherence)

## Summary Table

| Package | Files | Ext Deps | Tests | Test Support | Findings |
|---------|------:|:--------:|:-----:|:------------:|----------|
| swift-abstract-syntax-tree | 1 | 2 | Y | — | STUB: 0 bytes of source content |
| swift-backend | 1 | 2 | Y | — | STUB: 0 bytes of source content |
| swift-clocks | 1 | 2 | N | — | Re-export facade; no tests |
| swift-color | 1 | 1 | Y | — | Re-export facade |
| swift-compiler | 0 | 0 | Y | — | EMPTY: no source directory, no source files |
| swift-console | 10 | 5 | Y | N | MOD-006: unused dep (buffer-primitives) |
| swift-copy-on-write | 1+2 | 1 | Y | — | Has macro target (not single-target) |
| swift-decimals | 25 | 2 | Y | N | MOD-008: at threshold (25 files) |
| swift-dependency-analysis | 20+2 | 6 | Y | N | Has CLI target; Foundation import |
| swift-diagnostic | 1 | 9 | Y | — | STUB: 0 bytes; 9 unused deps |
| swift-driver | 1+1 | 10 | Y | — | STUB: 0 bytes in Driver; 10 unused deps; has exec target |
| swift-emailaddress | 1 | 1 | Y | — | Re-export facade |
| swift-environment | 7 | 2 | Y | — | PASS |
| swift-epub | 1 | 1 | Y | — | Re-export facade |
| swift-html | 9 | 9 | Y | N | PASS (deps justified by imports) |
| swift-identities | 4 | 3 | Y | — | PASS |
| swift-intermediate-representation | 1 | 3 | Y | — | STUB: 0 bytes of source content |
| swift-ip-address | 1 | 2 | Y | — | Re-export facade |
| swift-json | 11 | 3 | Y | N | MOD-010: 4 stdlib extension files |
| swift-json-feed | 1 | 1 | Y | — | Re-export facade |
| swift-lexer | 1 | 2 | Y | — | STUB: 0 bytes of source content |
| swift-locale | 1 | 1 | Y | — | Re-export facade |
| swift-memory | 23 | 2 | Y | N | PASS |
| swift-module | 1 | 2 | Y | — | STUB: 0 bytes of source content |
| swift-numerics | 3 | 2 | Y | — | PASS |
| swift-paths | 9 | 2 | Y | — | PASS |
| swift-pools | 11 | 2 | Y | — | PASS |
| swift-random | 2 | 4 | Y | — | Re-export facade |
| swift-rss | 1 | 1 | Y | — | Re-export facade |
| swift-source | 4 | 1 | Y | — | PASS |
| swift-strings | 5 | 2 | N | — | MOD-010: 2 stdlib extension files; no tests |
| swift-svg | 2 | 2 | Y | — | PASS |
| swift-symbol | 1 | 3 | Y | — | STUB: 0 bytes of source content |
| swift-syntax | 1 | 1 | Y | — | STUB: 0 bytes of source content |
| swift-systems | 2 | 4 | Y | — | Re-export facade with topology logic |
| swift-time | 1 | 3 | Y | — | Re-export facade |
| swift-type | 1 | 3 | Y | — | STUB: 0 bytes of source content |
| swift-uri | 1 | 1 | Y | — | Re-export facade |
| swift-xml | 16 | 2 | Y | — | MOD-010: 4 stdlib extension files |

## Aggregate Statistics

- **PASS**: 10 packages
- **Re-export facades**: 13 packages (single-file re-exports of lower-layer products)
- **STUB (0 bytes)**: 9 packages (empty source files with declared dependencies)
- **EMPTY (no sources)**: 1 package (swift-compiler)
- **Findings**: 6 packages with actionable findings

---

## Detailed Findings

### MOD-008: Split Decision

**swift-decimals** (25 files, 2 deps) — AT THRESHOLD

25 files is exactly the review threshold. The file structure is coherent: `Decimal.Operation.{Add,Compare,Divide,Multiply,Fuse,Order}` plus `Decimal.Text.{Parse,Render,Style,Error}` plus core types. The text rendering cluster (5 files) could be a separate module but this is a judgement call. No action required unless growth continues.

**swift-memory** (23 files, 2 deps) — WITHIN BOUNDS

23 files below threshold. Coherent domain: `Memory.Map.*` (6 files), `Memory.Allocation.*` (6 files), plus core types. No split needed.

### MOD-006: Dependency Minimization

**swift-console** (10 files, 5 deps)

The `Buffer Linear Inline Primitives` product from `swift-buffer-primitives` is declared as a target dependency but never imported in any source file. The `Console.Input.Reader` uses `ContiguousArray` (stdlib) and `Input.Buffer` (from Terminal Input Primitives), not buffer-primitives types.

Recommendation: Remove `swift-buffer-primitives` from Package.swift dependencies and `Buffer Linear Inline Primitives` from the target's dependency list.

**swift-diagnostic** (1 file, 9 deps) — STUB WITH UNUSED DEPS

The single source file `Diagnostic.swift` is 0 bytes. All 9 declared dependencies (swift-driver-primitives, swift-lexer, swift-syntax, swift-abstract-syntax-tree, swift-module, swift-symbol, swift-type, swift-intermediate-representation, swift-backend) are completely unused. This is a placeholder package.

**swift-driver** (1 file main + 1 file exec, 10 deps) — STUB WITH UNUSED DEPS

`Driver.swift` is 0 bytes. All 10 declared dependencies are unused. The executable target `swiftc` depends on Driver but `swiftc.swift` is also 0 bytes. Placeholder package.

### MOD-010: StdLib Integration Isolation

**swift-json** (11 files, 3 deps) — 4 stdlib extensions

Files: `Bool+JSON.swift`, `Int+JSON.swift`, `Double+JSON.swift`, `String+JSON.swift`. These extend `Bool`, `Int`, `Double`, and `String` with `init?(_ json: JSON)` convenience initializers. Additionally, `JSON.Serializable.swift` extends `Optional`, `Array`, `Dictionary`, `Int`, `Double`, `Bool`, `String` with `JSON.Serializable` conformances.

These are domain-coupled (they require `JSON` types in their signatures) so isolating them into a separate StdLib Integration module is reasonable but not urgent. They add public API surface to stdlib types in every consumer's namespace.

**swift-xml** (16 files, 2 deps) — 4 stdlib extensions

Files: `Bool+XML.swift`, `Int+XML.swift`, `Double+XML.swift`, `String+XML.swift`. Identical pattern to JSON: `init?(_ xml: XML)` convenience initializers on stdlib types. `XML.Serializable.swift` adds conformances.

Same assessment: domain-coupled but adds public API surface to stdlib types. A `XML StdLib Integration` module would let consumers opt in.

**swift-strings** (5 files, 2 deps) — 2 stdlib extension files

Files: `Swift.String+Primitives.swift` and `ISO_9899.String+Primitives.swift`. These bridge `Swift.String` and `ISO_9899.String` to/from `String_Primitives.String`. This is the core purpose of the package so isolation would defeat its reason for existence. No action needed.

### MOD-011: Test Support Product

Packages meeting the criteria (10+ files AND 3+ external deps):

| Package | Files | Deps | Has Test Support |
|---------|------:|-----:|:----------------:|
| swift-console | 10 | 5 | N |
| swift-dependency-analysis | 20 | 6 | N |
| swift-json | 11 | 3 | N |

None of these provide a test support product. Of these, `swift-json` is the most likely candidate — downstream packages testing JSON serialization would benefit from test fixtures and assertion helpers. `swift-dependency-analysis` is a developer tool unlikely to have downstream test consumers.

### Structural Observations (Not Rule Violations)

**9 stub packages with 0 bytes of source**: swift-abstract-syntax-tree, swift-backend, swift-intermediate-representation, swift-lexer, swift-module, swift-symbol, swift-syntax, swift-type, swift-diagnostic. These form a compiler toolchain package family. All have declared dependencies but no implementation. They appear to be placeholders for a future compiler infrastructure.

**1 empty package**: swift-compiler has no Sources subdirectory at all — only a `.DS_Store` file. Its test target is named "Console Tests" (likely a copy-paste error from swift-console).

**13 re-export facades**: These are 1-file packages that `@_exported import` lower-layer modules (primitives or standards) to provide ergonomic umbrella imports at the foundations layer. This is an intentional architectural pattern, not a violation.

**2 packages without tests**: swift-clocks (re-export facade) and swift-strings (5 files, 2 deps). swift-strings has substantive bridge logic and should have tests.

**Foundation usage**: swift-dependency-analysis imports Foundation in 4 source files (`Package.Manifest.swift`, `Package.analyze.swift`, CLI files). This is acceptable at Layer 3 per CLAUDE.md ("Foundation imports are discouraged but not absolutely forbidden at this layer") but notable given it is a developer tool that reads Package.swift files via Process/FileManager.

---

## Action Items

| Priority | Package | Finding | Action |
|----------|---------|---------|--------|
| LOW | swift-console | MOD-006: unused buffer-primitives dep | Remove from Package.swift |
| LOW | swift-json | MOD-010: 4 stdlib extensions | Consider StdLib Integration module |
| LOW | swift-xml | MOD-010: 4 stdlib extensions | Consider StdLib Integration module |
| LOW | swift-json | MOD-011: no test support | Consider adding test fixtures product |
| INFO | swift-diagnostic | 9 unused deps (stub) | Clean up or leave as placeholder |
| INFO | swift-driver | 10 unused deps (stub) | Clean up or leave as placeholder |
| INFO | swift-compiler | No sources, wrong test name | Fix test target name; add Sources/Compiler/ |
| INFO | swift-strings | No tests | Add test target |

No MOD-008 FAIL violations found (no package exceeds 40 files). The largest main target is swift-decimals at 25 files (at threshold, coherent domain).
