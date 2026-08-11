# Audit: swift-ascii-primitives

## Category B ASCII Migration — 2026-04-16

### Scope

- **Target**: 22 Category B L2 standards packages + L1/L2/L3 destination layers
- **Skill**: Release-readiness migration (Category B ASCII layer violations)
- **Plan**: [`ascii-migration-category-b.md`](ascii-migration-category-b.md) v3.0.0

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | CRITICAL | L2→L1 dep rule | All 22 Category B `Package.swift` | Zero `swift-foundations/swift-ascii` (L3) references remain | RESOLVED 2026-04-08 |
| 2 | CRITICAL | L2→L1 dep rule | `swift-iso-9945/Package.swift` | Cycle 2 (`iso-9945` → `swift-ascii`) eliminated; now depends on `swift-iso-9899` (L2→L2) | RESOLVED 2026-04-08 |
| 3 | HIGH | Release verification | `swift-file-system` build | `Swift.String(kernelString)` initializer missing at `File.System.Link.Read.Target.swift:119`, `File.System.Copy.Recursive.swift:211` — blocks Step 5 end-to-end verification | OPEN — not caused by Category B; kernel/string-primitives API regression from ecosystem overhaul |
| 4 | MEDIUM | Roadmap tracking | `swift-institute/Research/release-roadmap-swift-file-system.md` §3 | Cycle 2 resolved in code but not marked done in roadmap | OPEN |
| 5 | LOW | L3 cleanup | `swift-ascii` (L3) | Now re-exports both L1 (`Binary_ASCII_Serializable_Primitives`) and L2 (`INCITS_4_1986`) features it previously owned. Evaluate whether L3 should slim further or become a re-export shell. | DEFERRED — post-release decision (OQ3) |
| 6 | LOW | Witness migration | 77 `Binary.ASCII.Serializable` conformers across 22 packages | Deprecated protocol relocated to L1 as release shim; full `Parseable`/`Serializable` witness migration deferred | DEFERRED — tracked in `ascii-serialization-migration.md` |
| 7 | LOW | Test staleness | `swift-ascii/Tests/` | 4 test files had stale compound type names (`LineEndingDetection`, `StringClassification`, `CharacterClassification`, `NumericParsing`) from L2 INCITS renames | RESOLVED 2026-04-08 (commit `61cabf2`) |

### Summary

7 findings: 0 critical open, 1 high open (unrelated ecosystem regression), 1 medium open (roadmap bookkeeping), 0 low open.

**Category B migration is complete.** All 22 L2 standards packages depend on L1/L2 only. The single blocker for full closure is an unrelated `swift-file-system` build regression from the kernel/string-primitives ecosystem overhaul. Once that regression is resolved, Step 5 (end-to-end verification) and Step 6 (roadmap closeout) can be completed.
