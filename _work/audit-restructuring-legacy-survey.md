# Legacy Audit Files Restructuring Survey

**Survey Date**: 2026-04-08  
**Survey Scope**: 10 legacy audit files at swift-institute/Research/ level  
**Purpose**: Classify each file by scope and target package(s) to support AUDIT-014/AUDIT-016 restructuring (moving package-specific content into each package's Research/audit.md)

---

## File-by-File Analysis

### 1. audit-standards-p2.md

**Date**: 2026-04-03 (git log)  
**Status**: ACTIVE audit (pre-publication code quality check)  
**Scope Type**: (b) Broad triage over 3 specific packages with per-package sections  
**Target Packages**:
- `swift-iso-9899` (ISO C Standard Library) — 38 source files; violations: 2 multi-type files, 1 compound type name, 2 missing doc comments
- `swift-iso-9945` (POSIX) — 99 source files; violations: 7 multi-type files, 4 methods-in-body violations, ~20 missing doc comments  
- `swift-incits-4-1986` (US-ASCII) — 16 source files; violations: 7 compound type names, 0 multi-type files

**Summary**: Pre-publication API audit covering P0–P3 checks (Foundation imports, multi-type files, compound names, methods-in-body, doc comments). Identifies 15+ actionable violations across 3 standards packages with specific file paths and remediation actions.

**Staleness Indicators**: DATE: 2026-04-03 (current, 5 days old); STATUS: ACTIVE; RESOLVED: 3 (PASS), OPEN: 15+ (FAIL across three packages); no DEFERRED markers

**Provenance**: No consolidation markers; stands alone as P2 audit  
**References**: Not referenced in any current audit.md; this is a standalone institute-level report

**Merge Target**: Split into three package-specific documents:
- `https://github.com/swift-iso/swift-iso-9899/blob/main/Research/audit.md` (P2 portion)
- `https://github.com/swift-iso/swift-iso-9945/blob/main/Research/audit.md` (P2 portion)
- `https://github.com/swift-incits/swift-incits-4-1986/blob/main/Research/audit.md` (P2 portion)

---

### 2. audit-primitives.md

**Date**: 2026-04-03 (git log)  
**Status**: COMPLETE audit (pre-publication dependency tree scan)  
**Scope Type**: (b) Broad triage over 73 transitively-reachable packages, filtered to 5 with violations  
**Target Packages** (only those with violations listed):
- `swift-queue-primitives` — Queue.Error.swift has 11 error enums (P1 multi-type, justified as `__`-prefixed internals)
- `swift-set-primitives` — Set.Ordered.Error.swift has 3 error enums
- `swift-dictionary-primitives` — Dictionary.Ordered.Error.swift has 3 error enums  
- `swift-list-primitives` — List.Linked.Error.swift has 4 error enums
- `swift-stack-primitives` — Stack.Error.swift has 2 error enums
- `swift-handle-primitives` — SlotAddress top-level compound name (P1)
- `swift-binary-primitives` — SignDisplayStrategy compound name (P1)
- `swift-test-primitives` — StructuralOperation compound name (P1)
- Platform packages (linux, windows, darwin primitives) — methods-in-body violations
- `swift-vector-primitives` — 30 items in struct body (mitigating design note per PATTERN-022)
- `swift-ordinal-primitives` — 6 operators/static properties in body

**Summary**: Dependency tree audit from swift-file-system downstream, covering 73 packages via BFS. Identifies 5 multi-type files (error groupings, justified), 3 compound type names, and 6+ platform/container methods-in-body violations. Recommends accepting error groupings as-is or splitting only the largest.

**Staleness Indicators**: DATE: 2026-04-03 (current); STATUS: COMPLETE; RESOLVED: 0 (P0 clean), OPEN: 5 multi-type + 3 compounds + 6 methods-in-body; no RESOLVED/DEFERRED counts

**Provenance**: Explicitly notes exclusion of swift-base62-primitives (already audited and fixed)  
**References**: Not referenced in any current audit.md; standalone institute-level report

**Merge Target**: Distribute per-package findings to each of the 11 packages listed above:
- Each primitives package gets a section in Research/audit.md documenting P0–P2 findings
- Error groupings can be bundled by package (queue, set, dictionary, list, stack each get their Error.swift section)
- Platform packages (linux, windows, darwin, vector, ordinal) get their own sections

---

### 3. modularization-audit-ecosystem-summary.md

**Date**: 2026-03-20 (content header)  
**Status**: COMPLETE audit (ecosystem-wide modularization sweep)  
**Scope Type**: (a) Truly ecosystem-wide cross-cutting patterns — NOT package-specific  
**Cross-Cutting Nature**: 
- Covers 199 packages across swift-primitives (132) + swift-foundations (67)
- Establishes ecosystem consensus on MOD-001 through MOD-014 rules
- Identifies systemic patterns (platform packages, MemberImportVisibility, umbrella-as-implementation anti-pattern, L1 naming at L3)
- Documents 5 exemplary L3 packages as reference implementations
- Provides Layer 3 naming conventions adapted from Layer 1

**Summary**: Executive summary and rule-compliance matrix covering both layers. Top 10 ecosystem-wide findings, systemic pattern analysis (platform packages, MemberImportVisibility, oversized single targets), Layer 3 observations, and tier-1/2/3/4 remediation roadmap.

**Staleness Indicators**: DATE: 2026-03-20; STATUS: COMPLETE; OPEN: 68 FAIL + 18 REVIEW + 34 ADVISORY (counts); no RESOLVED/DEFERRED

**Provenance**: Central document; lists 7 cross-references to batch files and subordinate reports  
**References**: Likely referenced in every package's audit.md that underwent modularization review

**Merge Target**: KEEP at institute level — this is the authoritative ecosystem policy document. It does NOT belong in any single package. Update it as policy decisions are made across the ecosystem.

**Notes**: This is the Rosetta Stone for modularization decisions. The 5 exemplary packages (swift-dependencies, swift-tests, swift-html-rendering, swift-parsers, swift-pdf) should reference this document as the policy baseline. Per AUDIT-014 (broad-then-narrow routing), this is the "broad" policy document that feeds into per-package audit.md files.

---

### 4. modularization-audit-foundations-batch-B.md

**Date**: 2026-03-20 (content header)  
**Status**: COMPLETE audit (16 L3 packages)  
**Scope Type**: (b) Broad triage over 16 swift-foundations packages with per-package compliance tables  
**Target Packages**:
- `swift-linux` — 3 peer products, 4 FAIL (MOD-001/002/005/011); platform pattern exception
- `swift-ascii` — 34 files, 1 FAIL (MOD-011: test support not published), 1 REVIEW (MOD-008: at threshold)
- `swift-css` — 2 peer products, PASS-heavy
- `swift-css-html-rendering` — **515 files** (CRITICAL from ecosystem summary), 2 FAIL + REVIEW
- `swift-defunctionalize` — 3 targets with macros
- `swift-dual` — 3 targets with macros
- `swift-kernel` — 63 files, PASS-heavy, test support exemplary
- `swift-loader` — 2 targets with C shim
- `swift-parsers` — 13 files, PASS-heavy, exemplary
- `swift-pdf` — 1 file, PASS-heavy, exemplary
- `swift-pdf-html-rendering` — 58 files, PASS
- `swift-pdf-rendering` — 34 files, PASS
- `swift-posix` — 2 peer products
- `swift-svg-rendering` — 22 files, PASS, exemplary
- `swift-windows` — 2 peer products

**Summary**: 16 L3 package compliance audit against MOD-001 through MOD-014. Table format with per-rule verdicts for each package. Identifies platform pattern as ecosystem-wide exception, flags MOD-011 (test support) as widespread gap, notes exemplary packages.

**Staleness Indicators**: DATE: 2026-03-20; STATUS: COMPLETE; RESOLVED/OPEN counts absent (verdict-based structure); no DEFERRED

**Provenance**: Part of ecosystem-wide audit; feeds into ecosystem summary  
**References**: Cross-referenced in ecosystem-summary.md (line 204-209)

**Merge Target**: Split into 16 package-specific audit.md files, each keeping their MOD-* compliance table and findings. Exemplary packages (swift-parsers, swift-pdf, swift-svg-rendering) should keep their PASS-heavy tables as reference for future audits.

---

### 5. naming-implementation-audit-swift-tests-swift-testing.md

**Date**: 2026-03-26 (last_updated header)  
**Status**: RECOMMENDATION (remediation tracker)  
**Scope Type**: (c) Entirely about 2 specific packages  
**Target Packages**:
- `swift-tests` (L3 Foundations) — 46 violations (9 compound types, 23 compound methods/properties, 14 implementation)
- `swift-testing` (L3 Foundations) — 42 violations (17 compound types, 13 compound methods/properties, 12 implementation)

**Summary**: 100%-strict naming + implementation audit of swift-tests and swift-testing against /naming and /implementation skills. 88 total violations organized by priority: P1 (active defects: 2), P2 (public compound types: 26), P3 (deprecated typealiases: 4), P4 (public compound methods: 36), P5 (private compounds: 14), P6 (implementation: 26).

**Staleness Indicators**: DATE: 2026-03-26 (12 days old); STATUS: RECOMMENDATION (not yet applied); RESOLVED: 0, OPEN: 88 violations; no DEFERRED

**Provenance**: No consolidation markers; stands alone as a detailed remediation tracker with specific code locations  
**References**: Referenced in naming-implementation-audit-remediation-prompt.md (below)

**Merge Target**: Split into two:
- `https://github.com/swift-foundations/swift-tests/blob/main/Research/audit.md` — 46 violations
- `https://github.com/swift-foundations/swift-testing/blob/main/Research/audit.md` — 42 violations

Each should keep the same priority-group structure and code locations for actionable guidance.

---

### 6. modularization-audit-foundations-single-target.md

**Date**: 2026-03-20 (content header)  
**Status**: COMPLETE audit (39 L3 single-target packages)  
**Scope Type**: (b) Broad triage over 39 swift-foundations packages (single-target or near-single-target)  
**Target Packages** (all 39 listed with summary rows):
- **Re-export facades** (13 packages): clocks, color, emailaddress, epub, ip-address, json-feed, locale, random, rss, time, uri, systems, copy-on-write — intentional architectural artifacts
- **Stub/placeholder packages** (10 packages): abstract-syntax-tree, backend, compiler, diagnostic, driver, intermediate-representation, lexer, module, symbol, syntax, type — compiler toolchain family; 0 bytes or no sources
- **Standard packages** (16 packages): console, copy-on-write, decimals, dependency-analysis, environment, html, identities, json, memory, numerics, paths, pools, source, strings, svg, xml
  - Notable findings: swift-console (MOD-006: unused dep), swift-json (MOD-010: stdlib extensions, MOD-011: no test support), swift-xml (MOD-010: stdlib extensions), swift-dependency-analysis (Foundation imports, MOD-011: no test support)

**Summary**: 39 L3 single-target package inventory with MOD-006/008/010/011 focus. Aggregate: 10 PASS, 13 re-export facades, 9 stubs (0 bytes), 1 empty, 6 with actionable findings. Recommends removing buffer-primitives from swift-console deps, considering StdLib Integration modules for JSON/XML, cleaning stub deps.

**Staleness Indicators**: DATE: 2026-03-20; STATUS: COMPLETE; RESOLVED/OPEN counts absent (verdict-based); no DEFERRED

**Provenance**: Part of ecosystem-wide audit; feeds into ecosystem summary  
**References**: Cross-referenced in ecosystem-summary.md (line 208-209)

**Merge Target**: Split into 39 package-specific audit.md files. Re-export facades should document their pattern as intentional. Stub packages can be merged into single document or marked as placeholder. Standard packages should each get their MOD-* findings extracted.

---

### 7. audit-foundations.md

**Date**: 2026-04-03 (content header)  
**Status**: ACTIVE audit (pre-publication code quality sweep)  
**Scope Type**: (b) Broad triage over 17 specific packages (swift-file-system dependency tree) with per-package findings  
**Target Packages**:
- `swift-ascii` — compound naming, no violations noted in detail
- `swift-async` — 5 async sequence types with 3-type files (Iterator/Transform pattern, justified), 2 documented workarounds for API-NAME-001
- `swift-clocks` — not detailed
- `swift-darwin` — not detailed  
- `swift-dependencies` — not detailed
- `swift-environment` — **REAL VIOLATION**: 3 untyped throws functions should be `throws(Kernel.Environment.Error)`
- `swift-io` — **WORST OFFENDER**: 42 umbrella files, 12+ methods-in-body (P2: CRITICAL from ecosystem summary), depth=4
- `swift-kernel` — 63 files, mostly PASS; 8 members-in-body (Context type) — acceptable for stored properties
- `swift-linux` — platform layer, conditional compilation pattern
- `swift-memory` — 3 compound accessor types (ByteStats, AllocationStats, PeakValues), 10 3-type files (justified patterns)
- `swift-paths` — Type + Error pattern (4 files): Path, Path.Component, Path.Component.Extension, Path.Component.Stem — systematic; policy decision needed
- `swift-pools` — not detailed
- `swift-posix` — platform layer
- `swift-strings` — not detailed
- `swift-systems` — not detailed
- `swift-witnesses` — macro implementation (1494 lines, 13 types, justified per PATTERN-022)
- `swift-windows` — platform layer

**Summary**: Pre-publication P0–P2 audit of swift-file-system dependency tree (17 packages, 605 source files). P0: Clean (zero Foundation imports). P1: 30 multi-type files (3 severe, 10 moderate, 17 minor), 5 compound names (2 documented, 3 real), 3 untyped throws (1 real violation). P2: 35 types with methods-in-body (concentrated in swift-io). 1 MUST FIX before publication (swift-environment typed throws).

**Staleness Indicators**: DATE: 2026-04-03; STATUS: ACTIVE; RESOLVED: 1 (P0 clean), OPEN: 30 multi-type + 5 compounds + 3 throws + 35 methods-in-body; no DEFERRED

**Provenance**: No consolidation markers; stands alone  
**References**: Not referenced in current audit.md; companion to audit-standards-p2.md and audit-primitives.md

**Merge Target**: Split into 17 package-specific audit.md files with per-package findings extracted:
- `swift-environment/Research/audit.md` — typed throws violation (MUST FIX)
- `swift-memory/Research/audit.md` — 3 compound names, 10 multi-type files
- `swift-paths/Research/audit.md` — Type+Error pattern policy decision
- `swift-io/Research/audit.md` — umbrella impl files (CRITICAL), methods-in-body
- Each other package gets their section (Platform packages cluster findings)

---

### 8. naming-implementation-audit-remediation-prompt.md

**Date**: 2026-03-03 (last_updated header)  
**Status**: GUIDANCE document (meta-prompt for remediation work)  
**Scope Type**: (c) Describes work for 2 packages (swift-tests, swift-testing) via reference to separate audit file  
**Referenced Packages**: Indirect — tells user to read naming-implementation-audit-swift-tests-swift-testing.md  
**Content**: Pre-written prompt text to paste into Claude Code for executing the 88 fixes from audit #5. Includes priority-group guidance, commit strategy, and specific code locations.

**Summary**: Remediation instruction document, not an audit. Serves as a task guide for implementing findings from audit #5. No standalone findings; entirely meta-instructional.

**Staleness Indicators**: DATE: 2026-03-03 (oldest file); STATUS: GUIDANCE (not yet applied); RESOLVED: depends on audit implementation

**Provenance**: References naming-implementation-audit-swift-tests-swift-testing.md (points to R5)  
**References**: Is referenced BY swift-institute team as a runbook

**Merge Target**: This is a **meta-document** that should live at `https://github.com/swift-foundations/Research/tree/main/_work/` as a working artifact or instruction guide. It does NOT belong in any single package. Keep at institute level or in a _work directory for ongoing remediation tracking.

**Notes**: Once remediation of audit #5 is complete, this document can be archived or deleted. It's a bridge document between audit and implementation.

---

### 9. modularization-audit-foundations-batch-A.md

**Date**: 2026-03-20 (content header)  
**Status**: COMPLETE audit (12 HIGH+MEDIUM complexity L3 packages)  
**Scope Type**: (b) Broad triage over 12 swift-foundations packages with detailed per-package compliance tables and findings  
**Target Packages**:
- `swift-translating` — 9 sources, **6 FAIL** (MOD-001/002/005/011/012/013): no Core, compound target names, umbrella has impl, missing MARK
- `swift-tests` — 8 sources, **2 FAIL** (MOD-002/008), **2 PASS** (MOD-011/013 exemplary): variants duplicate deps, Performance 45 files
- `swift-io` — 7 sources, **5 FAIL** (MOD-001/002/005/007/013): no Core (misnamed "Primitives"), umbrella 42 impl, depth=4, no MARK
- `swift-html-rendering` — 5 sources, **3 FAIL** (MOD-001/012/013): no Core, naming diverges, no MARK
- `swift-markdown-html-rendering` — 4 sources, **3 FAIL** (MOD-001/005/008): no Core, no umbrella, 59 files single target
- `swift-plist` — 4 sources, **2 FAIL** (MOD-001/005): Core misnamed "Primitives", umbrella has impl
- `swift-testing` — 4 sources, **2 FAIL** (MOD-008/013): umbrella 8 impl files, no MARK
- `swift-async` — 3 sources, **3 FAIL** (MOD-001/005/008): no Core, no umbrella, Async Stream 55 files
- `swift-darwin` — 3 sources, **3 FAIL** (MOD-001/005/007): no Core, no umbrella, no tests
- `swift-dependencies` — 3 sources, **1 FAIL** (MOD-002): good overall, exemplary trait usage
- `swift-effects` — 3 sources, **1 FAIL** (MOD-002): good overall, minor dep gap
- `swift-file-system` — 3 sources, **3 FAIL** (MOD-001/005/012): Core misnamed "Primitives", no umbrella

**Summary**: Detailed 12-package compliance audit showing HIGH/MEDIUM complexity patterns. Documents failures in Core/umbrella/naming patterns at L3, identifies swift-tests and swift-dependencies as exemplary implementations. Batch A shows the worst-case structures; Batch B shows standard/simple patterns.

**Staleness Indicators**: DATE: 2026-03-20; STATUS: COMPLETE; RESOLVED/OPEN counts per-package (2-6 FAIL per package); no DEFERRED

**Provenance**: Part of ecosystem-wide audit; feeds into ecosystem summary  
**References**: Cross-referenced in ecosystem-summary.md (line 204-207)

**Merge Target**: Split into 12 package-specific audit.md files. Exemplary packages (swift-tests, swift-dependencies) should keep their detailed tables. Failing packages (swift-translating, swift-io, swift-async) should get their findings extracted with priority remediation actions from ecosystem-summary.md Tier 1/2 roadmap.

---

### 10. modularization-audit-primitives-delta.md

**Date**: 2026-03-20 (created header)  
**Status**: COMPLETE (delta check against prior audit)  
**Scope Type**: (a) Meta-analysis across 132 swift-primitives packages — ecosystem policy document  
**Cross-Cutting Nature**: 
- Verifies stability of 2026-03-14 audit (no Package.swift changes in 6 days)
- Confirms 5 top findings remain OPEN (MOD-004, MOD-002, MOD-008, MOD-005, MOD-001)
- Tallies ecosystem-wide violation counts: 68 FAIL, 18 REVIEW, 14 ADVISORY unchanged
- Analyzes MOD-002 as systemic pattern driven by Swift 6's MemberImportVisibility
- Explains why violations remain open (policy questions, not implementation debt)

**Summary**: Delta report confirming primitives audit validity. No structural drift. Identifies MOD-002 (23 packages) and MOD-011 (22 packages) as most widespread. Explains that drift happens if Package.swift files change — none have since audit.

**Staleness Indicators**: DATE: 2026-03-20 (delta from 2026-03-14); STATUS: COMPLETE; OPEN: 68 FAIL + 18 REVIEW (unchanged), 4 of 5 top findings still OPEN; no RESOLVED/DEFERRED

**Provenance**: Explicitly compares against prior audit (2026-03-14, modularization-audit/SUMMARY.md in swift-primitives repo)  
**References**: Would be referenced when validating whether ecosystem-summary.md findings are still valid

**Merge Target**: KEEP at institute level. This is a **meta-policy validation document** that tracks ecosystem stability. It should live at `Research/` or in `_work/` as a durable artifact. Not package-specific. Update it monthly to detect drift across the 132 primitives packages.

**Notes**: This is the "early warning system" for modularization drift. The fact that no Package.swift files changed in 6 days suggests good stability. Keep this as an institute-level health check.

---

## Summary Table

| File | Date | Scope Type | Packages | Status | Open Violations | Merge Target |
|------|------|-----------|----------|--------|-----------------|---|
| 1. audit-standards-p2.md | 2026-04-03 | (b) 3 packages | swift-iso-9899, swift-iso-9945, swift-incits-4-1986 | ACTIVE | 15+ violations | Split into 3 package audit.md |
| 2. audit-primitives.md | 2026-04-03 | (b) 11 packages (73 scanned) | queue, set, dict, list, stack, handle, binary, test, linux, windows, darwin, vector, ordinal primitives | COMPLETE | 14 violations | Distribute to 11 package audit.md |
| 3. modularization-audit-ecosystem-summary.md | 2026-03-20 | (a) ECOSYSTEM POLICY | 199 packages (policy, not per-package) | COMPLETE | 68 FAIL + 18 REVIEW + 34 ADVISORY | **KEEP at institute level** |
| 4. modularization-audit-foundations-batch-B.md | 2026-03-20 | (b) 16 packages | swift-linux, swift-ascii, swift-css, swift-css-html-rendering, swift-defunctionalize, swift-dual, swift-kernel, swift-loader, swift-parsers, swift-pdf, swift-pdf-html-rendering, swift-pdf-rendering, swift-posix, swift-svg-rendering, swift-windows, swift-witnesses | COMPLETE | ~8 FAIL (platform pattern accepted) | Split into 16 package audit.md |
| 5. naming-implementation-audit-swift-tests-swift-testing.md | 2026-03-26 | (c) 2 packages | swift-tests, swift-testing | RECOMMENDATION | 88 violations (46+42) | Split into 2 package audit.md |
| 6. modularization-audit-foundations-single-target.md | 2026-03-20 | (b) 39 packages | All 39 L3 single-target packages (incl. stubs, facades) | COMPLETE | 6 with findings (rest PASS/facade) | Split into 39 package audit.md |
| 7. audit-foundations.md | 2026-04-03 | (b) 17 packages | swift-ascii through swift-windows (swift-file-system dependency tree) | ACTIVE | 1 MUST FIX (swift-environment), ~35 findings | Split into 17 package audit.md |
| 8. naming-implementation-audit-remediation-prompt.md | 2026-03-03 | (meta) Guide for audit #5 | Indirect (swift-tests, swift-testing) | GUIDANCE | N/A (instruction, not audit) | Keep in _work/ or archive |
| 9. modularization-audit-foundations-batch-A.md | 2026-03-20 | (b) 12 packages | swift-translating, swift-tests, swift-io, swift-html-rendering, swift-markdown-html-rendering, swift-plist, swift-testing, swift-async, swift-darwin, swift-dependencies, swift-effects, swift-file-system | COMPLETE | ~30 FAIL (2-6 per package) | Split into 12 package audit.md |
| 10. modularization-audit-primitives-delta.md | 2026-03-20 | (a) ECOSYSTEM META-CHECK | 132 primitives packages (policy, not per-package) | COMPLETE | Unchanged from 2026-03-14 | **KEEP at institute level** |

---

## Restructuring Guidance

### Category 1: KEEP AT INSTITUTE LEVEL (Ecosystem Policy)
These are the "broad" documents per AUDIT-014; they do NOT belong in any package.

1. **modularization-audit-ecosystem-summary.md** — Central policy baseline for MOD-001 through MOD-014; referenced by all packages
2. **modularization-audit-primitives-delta.md** — Ecosystem health check; tracks stability across 132 packages

### Category 2: KEEP IN _WORK/ (Meta/Instructional)
Working artifacts that guide remediation but are not package audits.

1. **naming-implementation-audit-remediation-prompt.md** — Instruction guide for implementing audit #5; archive after completion

### Category 3: SPLIT BY PACKAGE (Package-Specific Audits)
Move each finding into the target package's Research/audit.md.

1. **audit-standards-p2.md** → 3 packages (swift-iso-9899, swift-iso-9945, swift-incits-4-1986)
2. **audit-primitives.md** → 11 packages (queue, set, dict, list, stack, handle, binary, test, linux, windows, darwin, vector, ordinal primitives)
3. **modularization-audit-foundations-batch-B.md** → 16 packages
4. **naming-implementation-audit-swift-tests-swift-testing.md** → 2 packages (swift-tests, swift-testing)
5. **modularization-audit-foundations-single-target.md** → 39 packages (all L3 single-target)
6. **audit-foundations.md** → 17 packages (swift-ascii through swift-windows)
7. **modularization-audit-foundations-batch-A.md** → 12 packages (swift-translating through swift-file-system)

**Total packages to be restructured**: 132 packages (some appear in multiple audits and should consolidate findings)

---

## Key Observations

1. **Consolidation points**: swift-tests, swift-testing, swift-io appear in multiple audits. Their final Research/audit.md should contain findings from both modularization and naming/implementation audits.

2. **Platform pattern**: swift-linux, swift-windows, swift-darwin, swift-posix appear across multiple audits. The "no Core, peer products" pattern is an accepted ecosystem-wide exception (per MOD-001 deviation).

3. **Exemplary packages**: swift-tests, swift-dependencies, swift-html-rendering, swift-parsers, swift-pdf, swift-svg-rendering, swift-pdf-rendering are consistently PASS or RECOMMENDATION. Their audit.md should document what compliance looks like.

4. **Tier 1 remediation** (from ecosystem-summary.md): swift-css-html-rendering (515-file monolith), swift-io (umbrella 42 impl files), swift-heap-primitives (Sequence conformance in Core) are CRITICAL and should be prioritized.

5. **MUST FIX before publication**: swift-environment (typed throws violations) — from audit-foundations.md

6. **Systematic gaps**: MOD-011 (Test Support products missing) affects 22 L1 + 9 L3 packages; MOD-013 (MARK comments missing) affects 15 L1 + 4 L3 packages. These can be batch-fixed after package-specific audits are in place.

