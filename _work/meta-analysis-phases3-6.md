# Corpus Meta-Analysis: Phases 3-6

**Date**: 2026-04-08
**Scope**: swift-institute/Research/, swift-primitives/Research/, swift-institute/Experiments/
**Status**: COMPLETE (analysis only, no modifications)

---

## Phase 3: Supersession Detection

### 3a. Research Supersession by Skill Absorption [META-003]

RECOMMENDATION documents checked against skills in `/Users/coen/Developer/.claude/skills/`. A document is a supersession candidate when its recommendations are now codified as requirement IDs in a skill.

| Document | Skill | Evidence | Verdict |
|----------|-------|----------|---------|
| `implementation-patterns-skill.md` (DECISION) | **implementation** | Document explicitly designed the skill. Skill [IMPL-*] IDs now exist. | Already DECISION, no action needed |
| `documentation-skill-design.md` | **documentation** | Skill [DOC-001]...[DOC-053] covers all recommendations. | Already SUPERSEDED |
| `benchmark-implementation-conventions.md` | **benchmark** | 7 patterns extracted. Skill [BENCH-001]...[BENCH-009] codifies all. | **SUPERSESSION CANDIDATE** — recommendations are fully absorbed into benchmark skill |
| `skill-creation-process.md` | **skill-lifecycle** | Skill [SKILL-CREATE-*], [SKILL-LIFE-*] codifies the process. | **SUPERSESSION CANDIDATE** — recommendations absorbed into skill-lifecycle |
| `collaborative-llm-discussion.md` | **collaborative-discussion** | Skill [COLLAB-*] codifies the workflow. | **SUPERSESSION CANDIDATE** — recommendations absorbed into collaborative-discussion skill |
| `agent-handoff-patterns.md` | **handoff** | Skill [HANDOFF-*] codifies handoff protocol. | **SUPERSESSION CANDIDATE** — SBAR template, timing triggers, acceptance protocol all in skill |
| `session-reflection-meta-process.md` | **reflect-session** + **reflections-processing** | Skills [REFL-*] and [REFL-PROC-*] codify the two-phase pipeline. | **SUPERSESSION CANDIDATE** — full pipeline now in two skills |
| `generalized-audit-skill-design.md` | **audit** | Skill [AUDIT-001]...[AUDIT-010] implements the single-file design. | **SUPERSESSION CANDIDATE** — design now codified in audit skill |
| `readme-skill-design.md` | **readme** | Skill [README-*] codifies maturity tiers, badges, monorepo patterns. | **SUPERSESSION CANDIDATE** — fully absorbed |
| `academic-research-methodology.md` (DECISION) | **research-process** | [RES-020]...[RES-026] from this document are codified. | Already DECISION, but could be SUPERSEDED |
| `testing-conventions.md` (DECISION) | **testing** + **testing-swiftlang** + **testing-institute** | Testing conventions codified across three skills. | Already DECISION, but cross-reference as superseded by skills |

**swift-primitives RECOMMENDATION candidates**:

| Document | Skill | Evidence | Verdict |
|----------|-------|----------|---------|
| `intra-package-modularization-patterns.md` | **modularization** | 13 patterns. Skill [MOD-001]...[MOD-014] codifies the same patterns (Core, Constraint Isolation, Variant Decomposition, etc.). | **SUPERSESSION CANDIDATE** — patterns absorbed into modularization skill |
| `modularization-theoretical-foundations.md` | **modularization** | Literature foundations. Skill rationale sections cite Parnas, Baldwin-Clark. | **SUPERSESSION CANDIDATE** — theoretical grounding absorbed as rationale text in skill |
| `bounded-index-precondition-elimination.md` | **implementation** | Bounded indices. Skill [IMPL-050]...[IMPL-053] codifies bounded index patterns. | **SUPERSESSION CANDIDATE** — core recommendation absorbed |
| `cross-domain-init-overload-resolution-footgun.md` | **conversions** | Cross-domain init labeling. Skill [CONV-*] codifies labeled init convention. | Partial — check if labeling convention is fully covered |

**Total supersession candidates**: 10 documents (7 institute, 3 primitives)

### 3b. Experiment Supersession [META-007]

Three experiments marked "FIXED 6.2.4" in the _index.md:

| Experiment | _index.md Status | Source File Status | SUPERSEDED Header? | Action |
|------------|-----------------|-------------------|-------------------|--------|
| `noncopyable-inline-deinit` | FIXED 6.2.4 | `Status: BUG REPRODUCED (2026-01-20, Swift 6.2)` | **NO** | **FLAG** — needs SUPERSEDED header in source and _index.md |
| `noncopyable-accessor-incompatibility` | FIXED 6.2.4 | `Status: CONFIRMED (2026-01-20, Swift 6.2)` | **NO** | **FLAG** — needs SUPERSEDED header in source and _index.md |
| `value-generic-nested-type-bug` | FIXED 6.2.4 | `Status: CONFIRMED (2026-01-20, Swift 6.2)` | **NO** | **FLAG** — needs SUPERSEDED header in source and _index.md |

**Note**: These three experiments have the bug confirmed in their source files but the _index.md shows them as FIXED 6.2.4 — a status inconsistency. The source files still say BUG REPRODUCED/CONFIRMED with the old Swift 6.2 dates. Per [META-007], these should be marked SUPERSEDED (or at minimum FIXED) in their source files, with a note about the Swift version that resolved them.

Additionally, `noncopyable-inline-deinit` has detailed documentation in the _index.md itself (lines 177-199) about the bug's root cause and workaround — this content is valuable archival material but the status header needs updating.

---

## Phase 4: Consolidation Detection

### 4a. Research Consolidation [META-016]

Overlapping research clusters identified from _index.md:

**Cluster 1: Benchmark/Performance Testing** (4 documents)
- `benchmark-implementation-conventions.md` (RECOMMENDATION)
- `benchmarking-strategy.md` (RECOMMENDATION)
- `benchmark-serial-execution.md` (RECOMMENDATION)
- `benchmark-result-storage.md` (DECISION)
- `benchmark-inline-strategy.md` (IN_PROGRESS)
- `benchmark-performance-modularization.md` (MOSTLY IMPLEMENTED)

These 6 documents cover overlapping territory around performance testing. The benchmark skill [BENCH-001]...[BENCH-009] has absorbed the settled parts. Recommendation: consolidate the settled RECOMMENDATION/DECISION documents into a single `benchmark-conventions.md` (SUPERSEDED) with the skill as successor, keeping only `benchmark-inline-strategy.md` (IN_PROGRESS) and `benchmark-performance-modularization.md` (MOSTLY IMPLEMENTED) as active.

**Cluster 2: Comparative Analysis — Data Structure Primitives** (10 documents)
- `comparative-array-primitives.md`, `comparative-buffer-primitives.md`, `comparative-dictionary-primitives.md`, `comparative-hash-table-primitives.md`, `comparative-heap-primitives.md`, `comparative-list-stack-primitives.md`, `comparative-queue-primitives.md`, `comparative-set-primitives.md`, `comparative-slab-primitives.md`, `comparative-tree-graph-primitives.md`

These form a systematic series. The `ecosystem-data-structures-inventory.md` (DECISION) and the **ecosystem-data-structures** skill [DS-*] appear to absorb the decision layer. However, each comparative document has unique per-package detail. **Not a consolidation candidate** — the series is intentionally granular and several are already DECISION.

**Cluster 3: Parser Ecosystem** (6 documents)
- `parsers-ecosystem-adoption-audit.md` (RECOMMENDATION)
- `parsers-adoption-implementation-plan.md` (RECOMMENDATION)
- `parser-bridge-architecture.md` (IN_PROGRESS)
- `parser-bridge-ergonomics-assessment.md` (RECOMMENDATION)
- `parser-combinator-algebraic-foundations.md` (RECOMMENDATION)
- `parser-syntax-ergonomics-comparison.md` (RECOMMENDATION)
- `next-steps-parsers.md` (IN_PROGRESS)

Active work cluster. The audit, implementation plan, and next-steps could be consolidated once parser adoption completes. **Not urgent** — work is still IN_PROGRESS.

**Cluster 4: Feature Flags** (already consolidated)
- `feature-flags-addressable-borrowinout.md` (SUPERSEDED)
- `feature-flags-compiler-source-analysis.md` (SUPERSEDED)
- `feature-flags-compiletime-struct-reparenting.md` (SUPERSEDED)
- `feature-flags-coroutine-borrow-accessors.md` (SUPERSEDED)
- `feature-flags-assessment.md` (RECOMMENDATION) — consolidated survivor

Already handled. `feature-flags-assessment.md` is the consolidated version. The superseded documents should be verified as marked correctly. The subsequent `swift-6.3-ecosystem-opportunities.md` partially supersedes `feature-flags-assessment.md` for 6.3 features.

**Cluster 5: Stream/Async Isolation** (4 documents)
- `stream-isolation-preserving-operators.md` (RECOMMENDATION)
- `stream-isolation-propagation.md` (IN_PROGRESS)
- `async-stream-sendable-requirement.md` (IN_PROGRESS)
- `isolation-preserving-entry-point-api.md` (DECISION)
- `concrete-async-operator-types.md` (IN_PROGRESS)

Active work. Not a consolidation candidate yet.

### 4b. Experiment Consolidation [META-024]

**~Copyable constraint poisoning cluster** (6 experiments):

All 6 have already been consolidated:
- `noncopyable-multifile-poisoning` → SUPERSEDED → noncopyable-constraint-behavior
- `noncopyable-pointer-propagation` → SUPERSEDED → noncopyable-constraint-behavior
- `noncopyable-pointer-propagation-multifile` → SUPERSEDED → noncopyable-constraint-behavior
- `noncopyable-sequence-protocol-test` → SUPERSEDED → noncopyable-constraint-behavior
- `noncopyable-storage-poisoning` → SUPERSEDED → noncopyable-constraint-behavior
- `noncopyable-sequence-emit-module-bug` → SUPERSEDED → noncopyable-constraint-behavior

**Verdict**: Consolidation already completed. The _index.md shows all 6 as `SUPERSEDED → noncopyable-constraint-behavior` and the consolidated package exists at `Experiments/noncopyable-constraint-behavior/` with a README.md.

Additionally, `noncopyable-cross-module-propagation` and `noncopyable-protocol-workarounds` were also absorbed into the same consolidated experiment (8 total, matching the _index.md's "8 experiments" count for the CONSOLIDATED entry).

**No further experiment consolidation needed** for this cluster.

---

## Phase 5: Scope Migration [META-017]

Checking for obvious misscoped documents using _index.md summaries.

**Already migrated** (verified in _index.md):
- `pool-bounded-storage-refactor.md` → MOVED to swift-primitives/Research/ (package-specific, was in ecosystem-wide)
- `set-protocol-requirements.md` → MOVED to swift-primitives/Research/ (package-specific)
- `benchmark-serial-execution.md` — marked "Moved from swift-tests per [META-017]"

**Potential misscope candidates**:

| Document | Current Scope | Should Be | Rationale |
|----------|--------------|-----------|-----------|
| `swift-64-dev-compatibility-catalog.md` | swift-institute (ecosystem-wide) | swift-primitives | Topic says "swift-primitives" — compatibility issues in swift-primitives. But cataloguing issues that may affect multiple repos is arguably ecosystem-wide. **Borderline — keep as-is.** |
| `nonsending-callasfunction-inference-quirk.md` | swift-institute (ecosystem-wide) | Could be primitives-specific | Marked "Tier 1" but the quirk affects Async.Callback which is in async-primitives. However, the quirk is language-level (affects anyone using callAsFunction + nonsending). **Keep as-is.** |
| `string-primitives-shadowing.md` | swift-institute (ecosystem-wide) | Could be swift-primitives | Specifically about String_Primitives and Kernel_Primitives_Core. But the shadowing affects the entire ecosystem (IO/File/Async). **Keep as-is.** |

**Verdict**: No clear misscope issues found. Previous [META-017] migrations (pool-bounded-storage-refactor, set-protocol-requirements, benchmark-serial-execution) addressed the main cases.

**swift-primitives Research — reverse check** (package-specific items that are ecosystem-wide):

The primitives _index.md explicitly scopes itself as "primitives-wide research." Reviewing RECOMMENDATION documents:
- `collection-sequence-protocol-detachment.md` — protocol design affecting ecosystem-wide consumers. Already correctly placed (primitives protocol design = primitives scope).
- `iterator-span-buffer-elimination.md` — "ecosystem-wide nextSpan pattern audit (97 iterators)." This affects all layers. **Potential migration candidate** to swift-institute. However, the fix is in primitives iterator infrastructure. **Borderline — keep as-is** since the action items are in primitives.

---

## Phase 6: Research-Experiment Linkage [META-018]

### 6a. Unvalidated RECOMMENDATION Findings

Checked 10 key RECOMMENDATION documents for experiment coverage:

| Document | Has Experiments? | Gap |
|----------|-----------------|-----|
| `modern-concurrency-conventions.md` | Yes — references 9+ experiments. Claims "Verified: 2026-03-30" inline. | **Well-linked** |
| `sequence-operator-unification.md` | Yes — 3 experiments (20/20 variants). Explicit "No Experiments Remaining" section. | **Exemplary linkage** |
| `ownership-transfer-conventions.md` | Consolidation doc. References sending-mutex-noncopyable-region, noncopyable-operation-closure-pipeline. | **Adequate** |
| `string-path-type-unification.md` | Yes — phantom-tagged-string-unification (9 variants), tagged-escapable-accessor, tagged-two-level-lifetime. Extensive inline experiment citations. | **Exemplary linkage** |
| `feature-flags-assessment.md` | References 6 experiments for AddressableTypes. Other features have no experiments (by design — WAIT recommendations). | **Adequate** |
| `swift-6.3-ecosystem-opportunities.md` | No experiments cited. Recommendations are mechanical (flag removal, sed). | **Acceptable** — no experimental validation needed for flag audits |
| `discrete-scaling-morphisms.md` | No experiments found. | **GAP** — scaling factor design unvalidated |
| `benchmark-implementation-conventions.md` | No experiments. Patterns extracted from existing code, not hypotheses. | **Acceptable** — observational, not hypothesis-driven |
| `agent-handoff-patterns.md` | No experiments. Prior art survey (SBAR, ATC). | **Acceptable** — process research, not implementation hypothesis |
| `collaborative-llm-discussion.md` | No experiments. | **Acceptable** — workflow process, not implementation |

**Gap identified**: `discrete-scaling-morphisms.md` (RECOMMENDATION) has no experimental validation for its cross-domain scaling factor type design. If this informs actual type infrastructure, an experiment verifying the API ergonomics and type-checker behavior would be warranted.

### 6b. Experiment → Research Back-Propagation

Resolved experiments that should update research:

| Experiment | Status | Research to Update |
|------------|--------|--------------------|
| `noncopyable-inline-deinit` | FIXED 6.2.4 | `noncopyable-value-generic-deinit-bug.md` (already SUPERSEDED) — consistent |
| `noncopyable-accessor-incompatibility` | FIXED 6.2.4 | No dedicated research doc found. The fix may affect `feature-flags-assessment.md` (CoroutineAccessors recommendation). **Check if WAIT recommendation still valid given fix.** |
| `value-generic-nested-type-bug` | FIXED 6.2.4 | `noncopyable-value-generic-deinit-bug.md` (already SUPERSEDED) — consistent. Also `swift-6.3-ecosystem-opportunities.md` references `_deinitWorkaround` sites — **verify 36 sites are still needed or can now be removed.** |
| `se0461-concurrent-body-sensitivity` | CONFIRMED | `concurrent-expansion-audit.md` (COMPLETE) — research already accounts for this |
| `sending-mutex-noncopyable-region` | CONFIRMED (23 variants, 5/18 split) | `ownership-transfer-conventions.md` — Slot pattern documented there |

**Key back-propagation actions**:
1. `swift-6.3-ecosystem-opportunities.md` mentions "36 `_deinitWorkaround` sites pending #86652 verification" — the `value-generic-nested-type-bug` experiment is FIXED 6.2.4, so these 36 workaround sites may now be removable. The research should note this.
2. `feature-flags-assessment.md` recommends WAIT for CoroutineAccessors/BorrowAndMutateAccessors. The fix of `noncopyable-accessor-incompatibility` in 6.2.4 may change the calculus (the underlying _read/_modify issue may no longer be a blocker). Worth re-evaluating.

---

## Summary of Actions

### Priority 1: Status Updates (3b)
- [ ] `noncopyable-inline-deinit` source file: update status from BUG REPRODUCED to FIXED 6.2.4
- [ ] `noncopyable-accessor-incompatibility` source file: update status to FIXED 6.2.4
- [ ] `value-generic-nested-type-bug` source file: update status to FIXED 6.2.4

### Priority 2: Supersession Marking (3a)
- [ ] `benchmark-implementation-conventions.md` → SUPERSEDED by benchmark skill
- [ ] `skill-creation-process.md` → SUPERSEDED by skill-lifecycle skill
- [ ] `collaborative-llm-discussion.md` → SUPERSEDED by collaborative-discussion skill
- [ ] `agent-handoff-patterns.md` → SUPERSEDED by handoff skill
- [ ] `session-reflection-meta-process.md` → SUPERSEDED by reflect-session + reflections-processing skills
- [ ] `generalized-audit-skill-design.md` → SUPERSEDED by audit skill
- [ ] `readme-skill-design.md` → SUPERSEDED by readme skill
- [ ] (primitives) `intra-package-modularization-patterns.md` → SUPERSEDED by modularization skill
- [ ] (primitives) `modularization-theoretical-foundations.md` → SUPERSEDED by modularization skill
- [ ] (primitives) `bounded-index-precondition-elimination.md` → SUPERSEDED by implementation skill [IMPL-050..053]

### Priority 3: Research Consolidation (4a)
- [ ] Benchmark cluster: consolidate settled documents once `benchmark-inline-strategy.md` resolves

### Priority 4: Back-Propagation (6b)
- [ ] `swift-6.3-ecosystem-opportunities.md`: note that `_deinitWorkaround` sites may be removable (FIXED 6.2.4)
- [ ] `feature-flags-assessment.md`: re-evaluate CoroutineAccessors WAIT given accessor incompatibility fix

### No Action Needed
- Experiment consolidation (4b): ~Copyable constraint poisoning cluster already fully consolidated
- Scope migration (5): no misscoped documents found beyond already-migrated ones
- Experiment linkage (6a): one gap (`discrete-scaling-morphisms.md`) noted but low priority
