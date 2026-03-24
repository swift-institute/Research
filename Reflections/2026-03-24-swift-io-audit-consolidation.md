---
date: 2026-03-24
session_objective: Consolidate scattered swift-io audit files into a single canonical audit.md per the new audit skill
packages:
  - swift-io
  - swift-institute
status: pending
---

# swift-io Audit Consolidation — From 3 Scattered Files to One Canonical Location

## What Happened

Session began with finding the prior swift-io audit artifacts: `swift-io-deep-audit.md` (v1, 85 findings), `swift-io-deep-audit-v2.md` (v2, 82 active findings), and swift-io sections within `modularization-audit-ecosystem-summary.md` — all living in `swift-institute/Research/`, not in swift-io's own Research directory.

After initial exploration, the user directed to the newly created audit skill ([AUDIT-*]). The [AUDIT-015] consolidate-on-contact procedure was followed: v2 deep audit findings were extracted as a Legacy section, both v1/v2 files were deleted, and a fresh Modularization audit was run against current code.

Fresh modularization audit found 13 findings (3 HIGH, 7 MEDIUM, 3 LOW) against 278 source files across 7 modules. Key discoveries: IO Core published as a product (MOD-001 violation), 2 undeclared MIV dependencies, and 3 oversized targets (76/61/52 files). Also confirmed significant structural improvements already completed: umbrella extraction to IO Executor, IO Core rename, dependency cleanup.

Non-modularization findings (~45) from the v2 deep audit were carried forward in the Legacy section, awaiting fresh audits under code-surface, implementation, and memory skills.

## What Worked and What Didn't

**Worked well**: The [AUDIT-015] consolidate-on-contact process is clean — it avoids a big-bang migration by consolidating only the package being actively audited. The version-pairs rule (consolidate newest, delete all) prevented extracting redundant data from v1. The section-per-skill structure in the output makes it clear which findings are fresh (verified against current code) vs. legacy (potentially stale).

**Worked well**: Parallel verification agents caught that several prior findings were already resolved (umbrella extraction, dependency cleanup, typed throws on Buffer.Pool). Without verification, the legacy section would have overstated the problem.

**Didn't work well**: Initial exploration was too broad before the user clarified the audit skill process. Three exploration agents ran when the user had a specific process in mind. The signal was in the first message ("think about how to best do that") but the user's intent became clear only on the second message.

**Didn't work well**: The verification agents produced some false positives around MIV violations — they reported modules available via `@_exported import` chains as "undeclared." Distinguishing genuine MIV violations from transitively-available modules requires reasoning about the full re-export chain, which the agents struggled with.

## Patterns and Root Causes

**Pattern: scope-level misplacement is the #1 audit file smell.** All three prior files were in `swift-institute/Research/` despite being package-specific. The audit skill's [AUDIT-002] location triage addresses this directly, but [AUDIT-015] doesn't explicitly cover handling files at the wrong scope level — it only checks "the target scope's Research/ directory." The consolidation still worked because the user directed to the correct files, but an automated staleness check per [AUDIT-010] would miss them entirely since it would only look in `swift-io/Research/`.

**Pattern: L3 naming conventions diverge from L1 but aren't documented.** [MOD-012] gives naming patterns with "Primitives" throughout (e.g., `{Domain} Primitives Core`), which is correct for L1. But L3 packages use `{Domain} Core`, `{Domain} Blocking`, etc. — no "Primitives" in names. The ecosystem summary already blessed this (section 4.4 explicitly says "IO Primitives → should be IO Core"), but the modularization skill itself doesn't codify the L3 adaptation.

**Pattern: `@_exported import enum Foo.Bar` is a pragmatic workaround for module/type name collisions.** The IO umbrella uses this to export the `IO` namespace enum from `IO_Core` without importing the whole module. This avoids ambiguity when the module and the type share the same name. No current skill documents this pattern.

## Action Items

- [ ] **[skill]** modularization: Add L3 naming convention guidance alongside L1 patterns in [MOD-012] — currently all examples use "Primitives" suffix which is L1-specific. L3 drops "Primitives" from all target names.
- [ ] **[skill]** audit: Extend [AUDIT-015] to cover files at wrong scope level — consolidation should also check parent scope directories (e.g., `swift-institute/Research/` for `{package}-*-audit*.md` patterns) when auditing a package.
- [ ] **[package]** swift-io: Fix HIGH findings — depublish IO Core product, add missing MIV dependency declarations (Async_Primitives to IO Executor, Identity_Primitives to IO Blocking).
