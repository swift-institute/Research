# Audit.md Restructuring Plan

**Date**: 2026-04-08
**Purpose**: Position each audit entry at the correct scope level per [AUDIT-002] location triage and [AUDIT-014] broad-then-narrow routing. Consolidate legacy files per [AUDIT-015]/[AUDIT-016].

## Execution Status

### Phase A — Canonical audit.md restructuring: COMPLETE

| Action | Status |
|--------|--------|
| Move "Prior Art Compliance — swift-io" from institute → swift-io/audit.md | DONE |
| Move "Ownership Transfer Compliance" from institute → swift-async-primitives/audit.md | DONE |
| Move "Accepted Compiler Warnings" findings #1-3 → swift-ordering-primitives/audit.md (NEW) | DONE |
| Move "Accepted Compiler Warnings" finding #4 → swift-buffer-primitives/audit.md (NEW) | DONE |
| Update _index.md for swift-ordering-primitives + swift-buffer-primitives | DONE |

### Phase D — Package-local legacy file consolidation: IN PROGRESS

| Package | Files | Status |
|---------|-------|--------|
| swift-buffer-primitives | dependency-reuse-audit.md, implementation-skill-audit.md, AUDIT-HANDOFF.md → audit.md Legacy section | DONE (manual) |
| swift-foundations/swift-io | AUDIT-intent.md (70 findings) → audit.md Legacy section | DONE |
| swift-foundations/swift-testing | 3 files (67 findings) → new audit.md | DONE |
| swift-sequence-primitives | audit-zero-allocation-nextspan.md → audit.md | DONE |
| swift-memory-primitives | 2 files → audit.md | DONE |
| swift-hash-table-primitives | typed-iteration-audit-remediation.md → audit.md | DONE |
| swift-ownership-primitives | audit-borrow-inout-stdlib-parity.md → audit.md | DONE |
| swift-binary-primitives | SE-0458 Audit Methodology.md, Strict Memory Safety Audit Template.md | SKIPPED (templates, not audits) |
| swift-machine-primitives | implementation-quality-audit-graph-machine-parser.md → audit.md | DONE |

### Phase B — Surveyed legacy file splitting: IN PROGRESS

| Legacy file | Target pkgs | Status |
|-------------|-------------|--------|
| audit-foundations.md | 17 foundations pkgs | DONE — 10 new audit.md + 3 appends; 8 new _index.md + 2 updated |
| audit-standards-p2.md | 3 standards pkgs | DONE — 3 audit.md created at swift-iso/ + swift-incits/ |
| audit-primitives.md | 11 primitives pkgs | DONE — 12 new audit.md + 1 append (swift-queue-primitives) |
| naming-implementation-audit-swift-tests-swift-testing.md | 2 pkgs | NOT STARTED (may conflict with Phase D swift-testing agent) |
| modularization-audit-foundations-batch-A.md | 12 pkgs | NOT STARTED |
| modularization-audit-foundations-batch-B.md | 16 pkgs | NOT STARTED |
| modularization-audit-foundations-single-target.md | ~16 pkgs with findings | NOT STARTED |
| modularization-audit-ecosystem-summary.md | KEEP at institute | NO ACTION NEEDED |
| modularization-audit-primitives-delta.md | KEEP at institute | NO ACTION NEEDED |
| naming-implementation-audit-remediation-prompt.md | → _work/ | NOT STARTED |

### Phase C — Unsurveyed legacy file classification: SURVEY IN PROGRESS

25 files being surveyed by background agent. Results will be written to `_work/audit-restructuring-phase-c-survey.md`.

### Remaining work for follow-up sessions

1. **Phase B remaining**: 4 modularization-audit files need splitting (~80+ target packages). These are the largest remaining items.
2. **Phase B cleanup**: After all splits are complete, delete the legacy files from swift-institute/Research/ and remove from _index.md.
3. **Phase C execution**: After survey completes, classify and execute moves for the 25 unsurveyed files.
4. **naming-implementation-audit-swift-tests-swift-testing.md**: Needs splitting after swift-testing Phase D agent completes (to avoid conflicts).
5. **naming-implementation-audit-remediation-prompt.md**: Move to `_work/` as a meta-instruction document.
6. **Verification**: After all agents complete, verify each new/modified audit.md has correct structure per [AUDIT-003] and each _index.md is up to date per [AUDIT-009].

---

## Scope Inventory

### Canonical audit.md files (11)

| Path | Size | Scope Correctness | Action Needed |
|------|------|-------------------|---------------|
| `swift-institute/Research/audit.md` | 1416 L | Ecosystem-wide (mostly correct) | 3 sections to split out |
| `swift-primitives/Research/audit.md` | 117 L | Superrepo-wide (correct) | Broad triage; per-package details already in `data/` files |
| `swift-primitives/swift-async-primitives/Research/audit.md` | 885 L | Package-specific (correct) | Already correctly positioned |
| `swift-primitives/swift-queue-primitives/Research/audit.md` | 21 L | Package-specific (correct) | — |
| `swift-primitives/swift-pool-primitives/Research/audit.md` | 212 L | Package-specific (correct) | Contains Legacy section; verify all consumed |
| `swift-primitives/swift-link-primitives/Research/audit.md` | 102 L | Package-specific (correct) | — |
| `swift-primitives/swift-structured-queries-primitives/Research/audit.md` | 98 L | Package-specific (correct) | — |
| `swift-foundations/swift-io/Research/audit.md` | 1417 L | Package-specific (correct) | — |
| `swift-foundations/swift-kernel/Research/audit.md` | — | Package-specific (correct) | — |
| `swift-foundations/swift-file-system/Research/audit.md` | — | Package-specific (correct) | — |
| `swift-foundations/swift-pools/Research/audit.md` | 72 L | Package-specific (correct) | — |

### Legacy `*-audit*.md` files at swift-institute/Research/ (35+)

**Surveyed by agent (10 files)** — see `audit-restructuring-legacy-survey.md`:
- audit-standards-p2.md (3 pkgs)
- audit-primitives.md (11 pkgs)
- audit-foundations.md (17 pkgs)
- modularization-audit-ecosystem-summary.md (KEEP at institute)
- modularization-audit-primitives-delta.md (KEEP at institute)
- modularization-audit-foundations-batch-A.md (12 pkgs)
- modularization-audit-foundations-batch-B.md (16 pkgs)
- modularization-audit-foundations-single-target.md (39 pkgs)
- naming-implementation-audit-swift-tests-swift-testing.md (2 pkgs)
- naming-implementation-audit-remediation-prompt.md (→ _work/)

**NOT yet surveyed (25 files)**:
- ascii-domain-ownership-audit.md
- async-pool-primitives-audit.md ← referenced by pool + async audit as "to be moved"
- concurrent-expansion-audit.md
- dependencies-ecosystem-adoption-audit.md
- effects-ecosystem-adoption-audit.md
- file-path-type-unification-audit.md
- foundations-dependency-utilization-audit.md
- generalized-audit-skill-design.md (NOT an audit — design research, keep)
- handoff-ascii-domain-ownership-audit.md
- io-prior-art-and-swift-io-design-audit.md ← referenced by institute/audit.md
- noncopyable-synchronization-ecosystem-audit.md
- nonsending-adoption-audit.md
- nonsending-ecosystem-migration-audit.md
- parsers-ecosystem-adoption-audit.md
- pdf-html-rendering-audit.md
- platform-compliance-audit.md
- primitives-index-audit.md
- rendering-architecture-audit.md
- rendering-packages-naming-implementation-audit.md
- sending-expansion-audit.md
- underscore-api-elimination-audit.md
- variant-naming-audit.md ← referenced by institute/audit.md
- witnesses-ecosystem-adoption-audit.md
- `audits/implementation-naming-2026-03-13/` (subdirectory)
- `audits/implementation-naming-2026-03-20/` (subdirectory)

### Legacy non-canonical audits elsewhere

- swift-primitives/swift-sequence-primitives/Research/audit-zero-allocation-nextspan.md
- swift-primitives/swift-memory-primitives/Research/Index Type Safety Audit.md
- swift-primitives/swift-memory-primitives/Research/Typed Index Integration Audit.md
- swift-primitives/swift-hash-table-primitives/Research/typed-iteration-audit-remediation.md
- swift-primitives/swift-ownership-primitives/Research/audit-borrow-inout-stdlib-parity.md
- swift-primitives/swift-binary-primitives/Research/SE-0458 Audit Methodology.md
- swift-primitives/swift-binary-primitives/Research/Strict Memory Safety Audit Template.md
- swift-primitives/swift-buffer-primitives/AUDIT-HANDOFF.md (outside Research/)
- swift-primitives/swift-machine-primitives/Research/implementation-quality-audit-graph-machine-parser.md
- swift-foundations/swift-testing/audit-tests.md (outside Research/)
- swift-foundations/swift-testing/audit-test-primitives.md (outside Research/)
- swift-foundations/swift-testing/audit-testing.md (outside Research/)
- swift-foundations/swift-io/AUDIT-intent.md (outside Research/)

---

## Phase A — Canonical audit.md files

### A1. Split institute/audit.md package-specific sections

| Source section (institute/audit.md lines) | Target | Rationale |
|-------------------------------------------|--------|-----------|
| "Prior Art Compliance — swift-io — 2026-03-25" (L613-664) | `swift-foundations/swift-io/Research/audit.md` | Entirely about swift-io. 72 concepts evaluated, CLEAN verdict. Per [AUDIT-002] should be at swift-io scope. |
| "Ownership Transfer Compliance — 2026-03-31" (L1270-1303) | `swift-primitives/swift-async-primitives/Research/audit.md` | Entirely about Bridge + Channel (swift-async-primitives). 0 violations. Per [AUDIT-002] should be at package scope. |
| "Accepted Compiler Warnings — 2026-03-25" findings #1-3 (L581-612) | `swift-primitives/swift-ordering-primitives/Research/audit.md` | Findings #1-3 are swift-ordering-primitives specific. |
| "Accepted Compiler Warnings — 2026-03-25" finding #4 (L600) | `swift-primitives/swift-buffer-primitives/Research/audit.md` | Finding #4 is 17 `consume buf` sites in swift-buffer-primitives small buffers. |

### A2. Cross-cutting sections that STAY at institute/audit.md

These have a genuine cross-cutting pattern analysis that does not belong to any one package — even though they contain per-package findings:

| Section | Lines | Reason to keep at institute |
|---------|-------|-----------------------------|
| Conversions — 2026-03-24 | L3-320 | Cross-cutting bare-Cardinal/Ordinal pattern across 3 superrepos. Per-phase remediation touches 6+ packages with sequential dependencies. |
| Memory Safety — 2026-03-25 | L321-580 | Cross-cutting 27-finding audit across 3 superrepos. Per-package triage table + systemic pattern analysis. |
| Variant Naming — 2026-03-25 | L667-890 | Cross-cutting 9-finding naming audit with ecosystem-wide sed/git-mv execution plan. |
| ASCII Serialization Migration — 2026-03-25 | L891-938 | Cross-cutting 8-finding migration plan across 73 conformers in swift-ascii + L1 primitives. |
| Path Type Compliance — 2026-03-31 | L939-1268 | Cross-cutting 58-finding audit across 8 packages with architectural decision (Path decomposition at L1). |
| Pre-Publication — 2026-04-02 | L1306-1416 | Cross-cutting 7-package publication blocker triage; the triage table IS the broad audit per [AUDIT-014]. |

### A3. Cross-cutting sections with optional per-package extraction

Within the A2 sections above, **per-package finding tables** could be duplicated as sections in each package's `Research/audit.md` if the user wants granular tracking. This is an additive, not destructive, restructuring: the institute section stays intact, and each affected package gets a scoped copy of its findings.

| Section | Could extract to |
|---------|------------------|
| Memory Safety → per-package findings | ~20 packages (memory, path, string, property, bit-vector, handle, lifetime, predicate, machine, foundations/async, foundations/file-system, foundations/memory, foundations/io, foundations/css) |
| Variant Naming → per-package findings | 6 packages (queue, heap, set, bitset, list, tree) |
| Path Type Compliance → per-package findings | 8 packages (windows-primitives, iso-9945, kernel, posix, windows, tests, source, file-system) |
| Pre-Publication → per-package sections | 7 packages (rfc-4648, rfc-9110, iso-8601, iso-32000, iso-3166, w3c-css, base62-primitives) |

---

## Phase B — Consolidate surveyed legacy files (10)

Per [AUDIT-015]: read each legacy file, extract findings, append as Legacy section in target package's `Research/audit.md`, delete source file, remove from `_index.md`.

Per [AUDIT-016]: these are all misplaced at swift-institute/Research/ but belong at package scope.

| Legacy file | Action | Targets |
|-------------|--------|---------|
| audit-standards-p2.md | Split → 3 files | swift-iso-9899, swift-iso-9945, swift-incits-4-1986 |
| audit-primitives.md | Split → 11+ files | queue, set, dict, list, stack, handle, binary, test, linux, windows, darwin, vector, ordinal primitives |
| audit-foundations.md | Split → 17 files | ascii, async, clocks, darwin, dependencies, environment, io, kernel, linux, memory, paths, pools, posix, strings, systems, witnesses, windows |
| modularization-audit-foundations-batch-A.md | Split → 12 files | translating, tests, io, html-rendering, markdown-html-rendering, plist, testing, async, darwin, dependencies, effects, file-system |
| modularization-audit-foundations-batch-B.md | Split → 16 files | linux, ascii, css, css-html-rendering, defunctionalize, dual, kernel, loader, parsers, pdf, pdf-html-rendering, pdf-rendering, posix, svg-rendering, windows, witnesses |
| modularization-audit-foundations-single-target.md | Split → ~16 files (stubs grouped) | console, json, xml, dependency-analysis, + 12 others with findings |
| naming-implementation-audit-swift-tests-swift-testing.md | Split → 2 files | tests, testing |
| modularization-audit-ecosystem-summary.md | **KEEP** at institute level | — |
| modularization-audit-primitives-delta.md | **KEEP** at institute level | — |
| naming-implementation-audit-remediation-prompt.md | Move → `_work/` | (meta-instruction, not an audit) |

---

## Phase C — Survey + consolidate remaining 25 legacy files

Requires subagent survey to classify scope (single-pkg / multi-pkg / ecosystem).

Best guesses from filenames:
- `io-prior-art-and-swift-io-design-audit.md` → swift-io (referenced from institute Prior Art section)
- `async-pool-primitives-audit.md` → swift-async-primitives + swift-pool-primitives (referenced in pool audit as pending move)
- `variant-naming-audit.md` → research document keyed to institute audit.md variant naming section (keep at institute)
- `pdf-html-rendering-audit.md` → swift-pdf-html-rendering
- `rendering-architecture-audit.md` → likely cross-cutting rendering stack
- `rendering-packages-naming-implementation-audit.md` → likely cross-cutting
- `primitives-index-audit.md` → swift-index-primitives or cross-cutting
- `parsers-ecosystem-adoption-audit.md` → swift-parsers + adopters (cross-cutting adoption survey — Discovery research, not audit per [AUDIT-011])
- `dependencies-ecosystem-adoption-audit.md` → Discovery research (not an audit)
- `effects-ecosystem-adoption-audit.md` → Discovery research
- `witnesses-ecosystem-adoption-audit.md` → Discovery research
- `nonsending-adoption-audit.md` → Discovery research
- `nonsending-ecosystem-migration-audit.md` → Discovery research
- `concurrent-expansion-audit.md` → likely cross-cutting
- `sending-expansion-audit.md` → likely cross-cutting
- `underscore-api-elimination-audit.md` → cross-cutting naming
- `file-path-type-unification-audit.md` → cross-cutting (ancestor of institute Path Type Compliance section?)
- `foundations-dependency-utilization-audit.md` → cross-cutting
- `platform-compliance-audit.md` → cross-cutting platform
- `ascii-domain-ownership-audit.md` + `handoff-ascii-domain-ownership-audit.md` → swift-ascii ecosystem
- `noncopyable-synchronization-ecosystem-audit.md` → Discovery research
- `audits/implementation-naming-2026-03-13/` — subdirectory, likely per-package
- `audits/implementation-naming-2026-03-20/` — subdirectory, per-package (already partially consumed by swift-pool-primitives)

Note: several "ecosystem-adoption-audit" files are actually Discovery research per [AUDIT-011] (no requirement IDs to check against). Those should NOT be classified as audits — they should be recategorized as research documents.

---

## Phase D — Consolidate package-local legacy files

13 non-canonical audit files inside package Research/ or outside Research/ altogether. Consolidate each into the package's `Research/audit.md` per [AUDIT-015]; delete sources; update `_index.md`.

---

## Risks and Open Questions

1. **Destination files don't exist yet**: Most target packages (e.g., swift-rfc-4648, swift-iso-9899, swift-environment, swift-translating) have no existing `Research/audit.md`. The split operation creates new files. This is expected per [AUDIT-014].

2. **Package path resolution**: Some targets are in swift-iso/ or swift-incits/ directories that don't match the `swift-foundations/` / `swift-primitives/` / `swift-standards/` patterns in CLAUDE.md. Need to verify actual paths before moving.

3. **_index.md updates**: Each affected package's `Research/_index.md` must get an `audit.md` entry per [AUDIT-009]. Institute `_index.md` loses entries for deleted legacy files.

4. **Git history preservation**: Per [AUDIT-005] "git preserves history". Section replacements and file deletions preserve history automatically. File splits do NOT preserve history cleanly — split content appears as "new file" in git log. Acceptable per rationale that the institute file remains as the source commit.

5. **Destructive operations**: Phase B/C/D delete source files. Must be done only after verifying the extract is complete and tests (if any) still pass.

6. **Scope creep potential**: Going from 11 canonical files to ~60+ files to touch (canonical + 35 legacy + 13 package-local + ~100 new destination files). This is ecosystem-wide restructuring.

---

## Recommended Phasing

| Phase | Scope | Risk | Effort |
|-------|-------|------|--------|
| **A** | Canonical audit.md files: 3 section moves from institute → swift-io, swift-async-primitives; 4 findings → swift-ordering-primitives + swift-buffer-primitives | LOW | Small |
| **B** | Surveyed legacy files: 10 files, ~130 target packages (some overlap). Mechanical split per survey table. | MEDIUM | Large |
| **C** | Unsurveyed legacy files: 25 files, unknown scope. Needs initial survey pass. | UNKNOWN | Large |
| **D** | Package-local legacy files: 13 files, consolidate in-place per [AUDIT-015]. | LOW | Small |
