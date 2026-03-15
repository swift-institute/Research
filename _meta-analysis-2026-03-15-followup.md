# Meta-Analysis Follow-Up Actions — 2026-03-15

**Context**: A full corpus sweep per [META-019] was completed on 2026-03-15. Phases 1-6 executed, phases 7-9 deferred. All status updates and supersession markings are committed. This document captures the remaining work.

**Skills to invoke**: `research-meta-analysis` (for [META-017] scope migration protocol), `research-process` (for [RES-002a] scoping rules), `experiment-process` (for [EXP-002] experiment creation).

---

## 1. Scope Migrations [META-017] — HIGH PRIORITY

Use `git mv` to preserve history. Update `_index.md` in both source and destination. Update cross-references in other documents that point to the old path.

### Demotions (ecosystem → package-specific)

| Document | Current Path | Destination Path | Rationale |
|----------|-------------|-----------------|-----------|
| `iterative-tuple-rendering.md` | `swift-institute/Research/` | `swift-foundations/swift-pdf-html-rendering/Research/` | All findings are about `_Tuple` dispatch in one package |
| `markdown-rendering-organization-audit.md` | `swift-institute/Research/` | `swift-foundations/swift-markdown-html-rendering/Research/` | All 10 findings (F-1–F-10) are about files in that package |
| `markdown-direct-context-rendering.md` | `swift-institute/Research/` | `swift-foundations/swift-markdown-html-rendering/Research/` | Proposed solution is within that package |
| `markdown-action-rendering-performance-optimization.md` | `swift-institute/Research/` | `swift-foundations/swift-markdown-html-rendering/Research/` | Performance analysis of that package's pipeline |

**Note**: Create `swift-foundations/swift-markdown-html-rendering/Research/` if it doesn't exist. Also create `_index.md` per [RES-003c].

### Promotions (package → ecosystem)

| Document | Current Path | Destination Path | Rationale |
|----------|-------------|-----------------|-----------|
| `measurement-first-principles.md` | `swift-foundations/swift-tests/Research/` | `swift-institute/Research/` | Explicitly states "Scope: Ecosystem-wide" — designs measurement types for all layers |
| `benchmark-performance-modularization.md` | `swift-foundations/swift-tests/Research/` | `swift-institute/Research/` | Explicitly states "Scope: Ecosystem-wide" — decides where measurement types live |

### Package reassignment

| Document | Current Path | Destination Path | Rationale |
|----------|-------------|-----------------|-----------|
| `sample-witness-threading.md` | `swift-foundations/swift-tests/Research/` | `swift-primitives/swift-sample-primitives/Research/` | About Sample<T> API in sample-primitives, not about swift-tests |

### Standards root cleanup

| Document | Current Path | Destination Path | Rationale |
|----------|-------------|-----------------|-----------|
| `UNIFIED_GEOMETRY_TYPES.md` | `swift-standards/` (root) | `swift-institute/Research/` | Ecosystem-wide: spans standards, primitives, foundations |
| `UNIFIED_GEOMETRY_TYPES_RESEARCH.md` | `swift-standards/` (root) | `swift-institute/Research/` | Same as above |
| `UNIFIED_GEOMETRY_TYPES_CRITIQUE.md` | `swift-standards/` (root) | `swift-institute/Research/` | Same as above |
| `UNIFIED_GEOMETRY_TYPES_IMPLEMENTATION_PLAN.md` | `swift-standards/` (root) | `swift-institute/Research/` | Same as above |
| `STANDARD_IMPLEMENTATION_PATTERNS.md` | `swift-standards/` (root) | `swift-standards/Documentation.docc/` | Authoritative guide, not research |
| `NETWORKING_RFC_IMPLEMENTATION_PLAN.md` | `swift-standards/` (root) | `swift-standards/Research/` | Create Research/ directory |
| `PDF-SPACING-BUG-INVESTIGATION.md` | `swift-standards/` (root) | Delete or archive | Stale: references `coenttb/` paths from pre-migration era |

---

## 2. Experiment Spawning [META-018] — HIGH PRIORITY

### zero-copy-event-pipeline experiment

**Research doc**: `swift-institute/Research/zero-copy-event-pipeline.md`
**Finding**: Memory.Pool event pipeline (Phase 1 + Phase 2) design has zero empirical validation
**Experiment scope**: Validate pool sizing, contention under realistic poll load, backpressure when exhausted
**Location**: `swift-institute/Experiments/zero-copy-event-pipeline-validation/` per [EXP-002]

### Image embedding feasibility experiment

**Research doc**: `swift-foundations/swift-pdf/Research/swift-pdf-stack-audit.md` (F-4)
**Finding**: `image(source:alt:)` renders text stub, no actual image data embedding
**Experiment scope**: Can base64 data URI images be embedded in PDF content streams?
**Location**: `swift-foundations/swift-pdf/Experiments/image-embedding-feasibility/` per [EXP-002]

---

## 3. Index Freshness [META-008] — MEDIUM PRIORITY

### swift-primitives/Research/_index.md

Stale entries to fix:
- Associative Hashing Assessment: listed as IN_PROGRESS, actually DECISION
- Linear Collections Assessment: listed as IN_PROGRESS, actually DECISION
- Priority Hierarchical Assessment: listed as IN_PROGRESS, actually DECISION
- implicit-member-init-resolution-hazard: listed as IN_PROGRESS, actually DECISION
- tree-primitives-buffer-arena-migration: listed as IN_PROGRESS, actually DEFERRED
- Bit Collections Assessment: now RECOMMENDATION (changed this sweep)
- Resource Management Assessment: now RECOMMENDATION (changed this sweep)

### swift-primitives/Research/data structures/_index.md

Update status for Bit Collections and Resource Management (both now RECOMMENDATION).

### Package-level _index.md files

Full audit of all ~73 package-level _index.md files in swift-primitives was deferred. Run in Phase 8 of next sweep.

---

## 4. Consolidation — MEDIUM PRIORITY

### Feature flags consolidation

Four documents share the same date, methodology, and toolchain:
- `feature-flags-coroutine-borrow-accessors.md`
- `feature-flags-addressable-borrowinout.md`
- `feature-flags-compiler-source-analysis.md`
- `feature-flags-compiletime-struct-reparenting.md`

Consolidate into a single "Feature Flags Assessment" document. The `compiler-source-analysis.md` covers all 9 features from the compiler's perspective; the other three interpret subsets.

### Adopt S-6 into stack audit

`pdf-html-rendering-audit.md` (now SUPERSEDED) has one unique finding not tracked in `swift-pdf-stack-audit.md`: S-6 (break flags `avoidPageBreakAfter`, `forcePageBreakAfter`, `avoidPageBreakInside` as mutable Bool fields with set-check-reset pattern). Add as F-16 or cross-reference.

---

## 5. Research Document Creation — MEDIUM PRIORITY

### ~Copyable value-generic deinit bug

The experiment `swift-institute/Experiments/noncopyable-nested-deinit-chain/` exists but has no research document. Create one capturing: bug (#86652 variant), conditions (cross-package value-generic stored properties with @_rawLayout storage), the workaround (AnyObject? + mutable pointer deinit), and that the simplified experiment doesn't reproduce because it lacks @_rawLayout.

---

## 6. Deferred Phases (Next Sweep)

- **Phase 7**: Experiment revalidation on next toolchain upgrade (~12 BUG REPRODUCED experiments are HIGH priority)
- **Phase 8**: Full _index.md audit across all ~73 package-level indices in swift-primitives
- **Phase 9**: Blog pipeline stall check (25 "Ready for Drafting" ideas — check for >30-day stalls)
