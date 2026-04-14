# Modularization Audit: swift-primitives Delta Report

<!--
---
version: 1.0.0
created: 2026-03-20
status: COMPLETE
prior_audit: 2026-03-14, modularization-audit/SUMMARY.md
scope: swift-primitives
---
-->

## 1. Delta Summary

**Prior audit**: 2026-03-14 (132 packages, 14 MOD-* rules)
**Delta check**: 2026-03-20

**No Package.swift files changed since 2026-03-14.** Git log confirms zero structural modifications to any package manifest across all 132 packages. All findings from the prior audit remain structurally valid.

---

## 2. Top Findings Verification

Five highest-impact findings verified against current code:

| # | Finding | Prior Status | Current Status | Evidence |
|---|---------|-------------|----------------|----------|
| 1 | **MOD-004** swift-heap-primitives: `Swift.Sequence` conformance in Core | FAIL | **STILL OPEN** | `Heap Copyable.swift:239` still contains `extension Heap: Swift.Sequence where Element: Copyable` in Core target. Guarded by `where Element: Copyable` but structurally violates MOD-004 — conformance should be in Heap Binary Primitives variant. |
| 2 | **MOD-002** swift-storage-primitives: 7 variants independently declare Property Primitives | FAIL | **STILL OPEN** | Package.swift lines 85, 94, 104, 114, 123, 133, 153 — all 7 variants declare `.product(name: "Property Primitives", ...)` independently instead of receiving it through Core re-exports. |
| 3 | **MOD-008** swift-standard-library-extensions: 86-file monolith | FAIL | **STILL OPEN** | 86 Swift files in single target across 15+ stdlib domains. No decomposition. |
| 4 | **MOD-005** swift-heap-primitives: umbrella omits Heap Binary Primitives | FAIL | **STILL OPEN** | `exports.swift` re-exports Core, Fixed, Static, Small, Min, Max, MinMax — but NOT `Heap_Binary_Primitives`. |
| 5 | **MOD-001** platform packages (darwin/linux/windows): no Core target | FAIL | **STILL OPEN** | All three use namespace-root pattern, no Core, no umbrella. Structure unchanged. |

---

## 3. Skill Updates Since Audit

The modularization skill was updated with **MOD-014** (Cross-Package Trait Integration, SE-0450) after the original audit. The original audit found MOD-014 N/A for all 132 packages. This remains correct — trait-gated integration is primarily relevant at Layer 3 (Foundations) where cross-package optional integration occurs.

---

## 4. Remaining Open Findings (from prior audit)

### By Rule (unchanged counts)

| Rule | Open Violations | Description |
|------|----------------|-------------|
| MOD-011 | 22 | Missing Test Support product |
| MOD-002 | 17 | External deps not centralized through Core |
| MOD-013 | 15 | Missing MARK comments in Package.swift |
| MOD-005 | 8 | Missing or non-compliant umbrella target |
| MOD-001 | 7 | Missing Core target |
| MOD-008 | 6 | Single target exceeds split threshold |
| MOD-006 | 4 | Dependency minimization violations |
| MOD-012 | 3 | Target naming convention violations |
| MOD-004 | 1 | Constraint isolation violation |
| MOD-009 | 1 | Inline variant dependency direction |
| MOD-003 | 1 | Variant targets not published as products |
| MOD-007 | 0 | (borderline: swift-machine-primitives depth 5-6) |
| MOD-010 | 2 | StdLib extensions not isolated |
| MOD-014 | 0 | (N/A for all primitives packages) |

**Total**: 68 FAIL + 18 REVIEW + 14 ADVISORY — all unchanged.

### Top 10 Packages Requiring Attention (unchanged)

1. **swift-storage-primitives** (T14) — 4 findings (MOD-002, MOD-009, MOD-013, MOD-006)
2. **swift-heap-primitives** (T16) — 4 findings (MOD-004, MOD-005, MOD-011, MOD-013)
3. **swift-memory-primitives** (T13) — 3 findings (MOD-002, MOD-005/006, MOD-013)
4. **swift-parser-machine-primitives** (T20) — 3 findings (MOD-002, MOD-006, MOD-011)
5. **swift-binary-parser-primitives** (T20) — 3 findings (MOD-001, MOD-002, MOD-012)
6. **swift-property-primitives** (T0) — 4 findings (MOD-001, MOD-005, MOD-011, MOD-012)
7. **swift-standard-library-extensions** (T0) — 2 findings (MOD-008, MOD-010)
8. **swift-stack-primitives** (T16) — 3 findings (MOD-003, MOD-011, MOD-013)
9. **Platform packages** (darwin/linux/windows, T18) — 5+ findings each
10. **swift-set-primitives** (T17) — 3 findings (MOD-002, MOD-006, MOD-013)

---

## 5. MOD-002 Systemic Pattern: MemberImportVisibility

The most widespread violation (17 packages) appears driven by Swift 6's `MemberImportVisibility` requirement where transitive imports are not automatically visible to downstream targets. This is a policy question:

**Option A**: Accept redundancy as necessary for Swift 6
**Option B**: Use `@_exported import` in Core's `exports.swift` to make transitive deps visible (already the recommended pattern)

Most packages that follow MOD-002 correctly use Option B via `exports.swift`. The violating packages could be fixed by adding the missing `@_exported import` statements to their Core targets.

---

## 6. Conclusion

The swift-primitives modularization audit from 2026-03-14 remains fully current. No structural changes have occurred. All 68 FAIL violations, 18 REVIEW items, and 14 ADVISORY observations stand as documented in `swift-primitives/Research/modularization-audit/SUMMARY.md` and batch files A-J.

**Cross-reference**: Full audit details in `https://github.com/swift-primitives/Research/tree/main/modularization-audit/`
