# Phase C Survey: 25 Unsurveyed Legacy Audit Files

**Date**: 2026-04-08
**Source**: Agent survey of `Research/` files

## Summary

| Classification | Count | Action |
|---------------|-------|--------|
| Proper audits (requirement IDs + findings) | ~7 | MOVE to package audit.md |
| Discovery research (no requirement IDs) | ~11 | KEEP as research per [AUDIT-011]/[RES-012] |
| Superseded/handoff documents | ~5 | KEEP or ARCHIVE |
| Subdirectories with per-package files | 2 | Consolidate into package audit.md |

**Key insight**: Per [AUDIT-011], an audit must target skill requirement IDs and produce a findings table. The majority of these files are ecosystem adoption surveys, feasibility assessments, or design investigations — they are Discovery research per [RES-012] and should NOT be moved to package audit.md files. Their "audit" naming is misleading but the content is research.

## Classification

### Proper Audits — MOVE to package scope

| File | Scope | Target(s) | Notes |
|------|-------|-----------|-------|
| async-pool-primitives-audit.md | 2 packages | swift-async-primitives, swift-pool-primitives | Already partially consumed by swift-pool-primitives Legacy section; async portion pending |
| platform-compliance-audit.md | Multi-package | Various platform packages | Has requirement IDs [PLAT-ARCH-*] |
| primitives-index-audit.md | Multi-package | Index-related primitives | Has requirement IDs [IDX-*] |
| rendering-architecture-audit.md | Multi-package | Rendering stack packages | Has requirement IDs |
| underscore-api-elimination-audit.md | Multi-package | swift-file-system + others | Has requirement IDs [API-NAME-*] |
| concurrent-expansion-audit.md | Ecosystem | Cross-cutting concurrency | May be ecosystem-wide — verify |
| foundations-dependency-utilization-audit.md | Ecosystem | Cross-cutting dependency | May be ecosystem-wide — verify |

### Discovery Research — KEEP at institute level (rename if misleading)

| File | Why it's research, not audit |
|------|------------------------------|
| dependencies-ecosystem-adoption-audit.md | Adoption survey — no requirement IDs |
| effects-ecosystem-adoption-audit.md | Adoption survey |
| parsers-ecosystem-adoption-audit.md | Adoption survey |
| witnesses-ecosystem-adoption-audit.md | Adoption survey |
| nonsending-adoption-audit.md | Adoption/migration survey |
| nonsending-ecosystem-migration-audit.md | Migration inventory |
| sending-expansion-audit.md | Expansion inventory |
| file-path-type-unification-audit.md | Design investigation (ancestor of Path Type Compliance section in institute audit.md) |
| noncopyable-synchronization-ecosystem-audit.md | Ecosystem inventory |
| io-prior-art-and-swift-io-design-audit.md | Literature survey (referenced by relocated Prior Art section in swift-io/audit.md) |

### Handoff/Superseded — KEEP or ARCHIVE

| File | Notes |
|------|-------|
| ascii-domain-ownership-audit.md | Domain ownership design |
| handoff-ascii-domain-ownership-audit.md | Handoff companion |
| variant-naming-audit.md | Academic rationale for Variant Naming section in institute/audit.md — KEEP as reference |

### Subdirectories — Per-package consolidation

| Directory | Contents | Action |
|-----------|----------|--------|
| audits/implementation-naming-2026-03-13/ | 5 per-package implementation-naming audit files | Consolidate into each package's audit.md |
| audits/implementation-naming-2026-03-20/ | 51 per-package implementation-naming audit files | Consolidate into each package's audit.md; some already consumed (swift-pool-primitives) |

### Files NOT in scope

| File | Reason |
|------|--------|
| generalized-audit-skill-design.md | Design research for the audit skill itself — NOT an audit |
| pdf-html-rendering-audit.md | Check classification: may be proper audit or design doc |
| rendering-packages-naming-implementation-audit.md | Check: may be proper audit for rendering packages |

## Remaining Phase C Execution

**Proper audits to move** (~7 files): Extract per-package findings into package audit.md, following the same [AUDIT-015] consolidation procedure used in Phase D.

**async-pool-primitives-audit.md** is highest priority — the async-primitives portion was explicitly noted as "remains in place at the swift-institute scope until swift-async-primitives gets its own per-package Research/audit.md" (from swift-pool-primitives/Research/audit.md Legacy section). Now that swift-async-primitives HAS an audit.md, this can be completed.

**audits/ subdirectories** (~56 per-package files): Large volume but mechanical. Each file maps 1:1 to a package. Recommend batch processing via subagent.

**Discovery research** (~11 files): No action needed other than optionally renaming to remove misleading "audit" suffix. Low priority.
