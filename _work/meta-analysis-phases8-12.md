# Corpus Meta-Analysis: Phases 8-12 — Supplementary Checks

**Date**: 2026-04-08
**Scope**: [META-025], [META-026], [META-008], [META-009], [META-010], [META-011], [META-012], [META-020], [META-021]

---

## Phase 8: Discovery Coverage [META-025]

### Milestone Tags

No version tags exist in any of the three superrepos:

| Repository | Tags | Finding |
|------------|------|---------|
| swift-primitives | 0 | No release milestones tagged |
| swift-foundations | 0 | No release milestones tagged |
| swift-standards | 0 | No release milestones tagged |

**Verdict**: Phase 8 is **not applicable** — no milestone releases have been cut, so post-milestone discovery experiments cannot be assessed. When version tags are introduced, this check should be revisited.

---

## Phase 9: Claim/Assumption Audit [META-026]

### Inventory

All `[CLAIM-*]` and `[ASSUMP-*]` identifiers are scoped to swift-institute Experiments only. Zero found in any Research directory or in swift-primitives Experiments.

#### CLAIM IDs Found

| ID | Source Experiment(s) | Status |
|----|---------------------|--------|
| CLAIM-001 | consuming-iteration-pattern, noncopyable-access-patterns (V01), noncopyable-access-patterns (V02, V03), foreach-consuming-accessor | CONFIRMED in all |
| CLAIM-002 | consuming-iteration-pattern, noncopyable-access-patterns (V01), noncopyable-access-patterns (V02, V03), foreach-consuming-accessor | CONFIRMED in all |
| CLAIM-003 | consuming-iteration-pattern, noncopyable-access-patterns (V01), noncopyable-access-patterns (V02, V03), foreach-consuming-accessor | CONFIRMED in all |
| CLAIM-004 | consuming-iteration-pattern, noncopyable-access-patterns (V01), noncopyable-access-patterns (V02, V03), foreach-consuming-accessor | V01: CONFIRMED; V02/V03: REFUTED then CONFIRMED with state-tracking |
| CLAIM-005 | consuming-iteration-pattern, noncopyable-access-patterns (V01), noncopyable-access-patterns (V02, V03), foreach-consuming-accessor | V01: REFUTED (tuples cannot contain ~Copyable); V02/V03: CONFIRMED |

### Findings

| # | Finding | Severity |
|---|---------|----------|
| 9-1 | **Duplicate CLAIM IDs across experiments**: CLAIM-001 through CLAIM-005 are reused with DIFFERENT meanings across consuming-iteration-pattern (V01) and foreach-consuming-accessor (V02/V03). V01 CLAIM-004 is "Iterator deinit cleanup" while V02/V03 CLAIM-004 is "consuming can consume original container". IDs are not globally unique. | HIGH |
| 9-2 | **No ASSUMP-* identifiers found anywhere**: The `[ASSUMP-*]` namespace is completely unused across the entire corpus. | INFO |
| 9-3 | **Claims only in consolidated experiments**: All claims exist in experiments that were SUPERSEDED into `noncopyable-access-patterns`. The consolidated experiment carries forward all claims from absorbed experiments, but the original experiment directories still exist with their own copies. | LOW |
| 9-4 | **No claims in Research documents**: No research document declares claims that are then validated by experiments. The claim/validation linkage is experiment-internal only. | MEDIUM |

---

## Phase 10: Index Freshness [META-008], [META-009]

### Research Indices

| Location | Files on Disk | Index Rows | Missing from Index | Phantom Entries |
|----------|--------------|------------|-------------------|-----------------|
| swift-institute/Research/ | 235 | 226 | 9 | 0 |
| swift-primitives/Research/ | 52 (excl. audit.md) | 16 (+38 in sub-tables) | 3 | 0 |
| swift-standards/Research/ | 1 | 1 | 0 | 0 |
| swift-foundations/Research/ | 2 | 2 | 0 | 0 |

#### swift-institute/Research/ — 9 Missing Files

| File | Nature |
|------|--------|
| `_Package-Insights.md` | Work artifact (underscore-prefixed) |
| `_meta-analysis-2026-03-15-followup.md` | Work artifact (underscore-prefixed) |
| `_scratch-domain-first-prior-art.md` | Work artifact (underscore-prefixed) |
| `apple-http-api-proposal-patterns.md` | Unindexed research |
| `apple-http-middleware-chain-isolation.md` | Unindexed research |
| `apple-http-outputspan-writer-pattern.md` | Unindexed research |
| `apple-http-withclient-scoped-pattern.md` | Unindexed research |
| `claurst-analysis.md` | Unindexed research |
| `claurst-rust-patterns.md` | Unindexed research |

**Note**: 3 are underscore-prefixed work files (reasonable to exclude). 6 are genuine research documents missing from the index.

#### swift-primitives/Research/ — 3 Missing Files

| File | Nature |
|------|--------|
| `_Package-Insights.md` | Work artifact |
| `linked-list-cursor-and-arena-backing-improvements.md` | Unindexed research |
| `linked-list-theoretical-perfect.md` | Unindexed research |

### Experiments Indices

| Location | Dirs on Disk | Index Rows | Missing from Index | Phantom Entries |
|----------|-------------|------------|-------------------|-----------------|
| swift-institute/Experiments/ | 131 | ~125 listed | 6 | 0 |
| swift-primitives/Experiments/ | 28 | ~26 listed | 2 | 0 |
| swift-foundations/Experiments/ | 7 | **NO _index.md** | ALL 7 | N/A |

#### swift-institute/Experiments/ — 6 Missing Directories

| Directory |
|-----------|
| `async-closure-noncopyable-escaping` |
| `async-let-typed-throws` |
| `callasfunction-noncopyable-consuming-sending` |
| `mutablespan-async-read` |
| `sending-vs-sendable-structured-concurrency` |
| `span-async-parameter` |

#### swift-primitives/Experiments/ — 2 Missing Directories

| Directory |
|-----------|
| `link-topology-element-free` |
| `sendable-noncopyable-conditional-conformance` |

#### swift-foundations/Experiments/ — [META-009] CONFIRMED OPEN

The `swift-foundations/Experiments/` directory has 7 experiment directories and NO `_index.md`:

1. `async-let-noncopyable-transfer`
2. `executor-preference-noncopyable`
3. `noncopyable-actor-driver-ownership`
4. `noncopyable-driver-witness`
5. `runtime-noncopyable-shutdown`
6. `sending-continuation-dispatch`
7. `taskgroup-executor-preference-noncopyable`

**Action required**: Create `_index.md` listing all 7 experiments.

---

## Phase 11: Infrastructure

### References [META-010] — COMPLETE

All 6 required `.bib` files exist in `References/`:

| File | Present |
|------|---------|
| `swift-evolution.bib` | YES |
| `programming-languages.bib` | YES |
| `type-theory.bib` | YES |
| `category-theory.bib` | YES |
| `api-usability.bib` | YES |
| `methodology.bib` | YES |

### Reflections [META-011]

| Location | Total | Processed | Pending | % Pending |
|----------|-------|-----------|---------|-----------|
| swift-institute/Research/Reflections/ | 104 | 57 | 46 | 44% |

**Finding**: 46 unprocessed reflections in swift-institute is a significant backlog. At the current rate of ~1 reflection per session, this represents weeks of unprocessed insight. The most recent pending reflections include entries dated 2026-04-08 (today), while some pending entries date back to early April and late March. A dedicated reflections-processing session is recommended.

### Blog Pipeline [META-012]

Blog index at `Blog/_index.md` reviewed.

#### "Ready for Drafting" Items >30 Days Stalled

All items in the "Ready for Drafting" section were captured on or before 2026-03-26. Today is 2026-04-08, so items captured before 2026-03-09 are stalled >30 days.

| ID | Title | Captured | Days Stalled |
|----|-------|----------|-------------|
| BLOG-IDEA-007 | Consuming Iterators for ~Copyable Collections | 2026-01-23 | 75 |
| BLOG-IDEA-010 | Phantom Types Meet Affine Geometry: Index Type Design | 2026-01-23 | 75 |
| BLOG-IDEA-014 | Combining ~Copyable and ~Escapable for Lifetime Safety | 2026-01-23 | 75 |
| BLOG-IDEA-024 | The Pointer Acquisition Problem | 2026-01-23 | 75 |
| BLOG-IDEA-025 | Why you can't build a ~Escapable Pointer | 2026-01-24 | 74 |
| BLOG-IDEA-026 | BorrowingSequence: Span-Based Iteration | 2026-01-24 | 74 |
| BLOG-IDEA-032 | Why We Don't Have io.Reader | 2026-03-26 | 13 (NOT stalled) |

**6 blog ideas** have been "Ready for Drafting" for >70 days without progressing. The "Prioritized" section (triaged 2026-03-15) contains 5 more items captured 2026-01-23 to 2026-03-10.

#### "In Progress" Status

4 items are marked "In Progress" — typed throws series (3 parts, started 2026-03-11) and associated type trap (started 2026-03-13). Both have been in progress for ~28 days.

#### Published

Zero posts published to date.

---

## Phase 12: Skill + Audit Health

### Skill Review Freshness [META-020]

Today is 2026-04-08. Implementation skills stale after 90 days, process skills after 180 days.

#### Implementation Skills (90-day threshold = stale if before 2026-01-08)

| Skill | Last Reviewed | Days Since | Status |
|-------|--------------|-----------|--------|
| swift-pull-request | 2026-03-24 | 15 | OK |
| package-export | 2026-03-20 | 19 | OK |
| ecosystem-data-structures | 2026-03-26 | 13 | OK |
| modularization | 2026-04-03 | 5 | OK |
| code-surface | 2026-03-20 | 19 | OK |
| issue-investigation | 2026-03-31 | 8 | OK |
| audit | 2026-03-26 | 13 | OK |
| document-markup | 2026-03-20 | 19 | OK |
| documentation | 2026-03-20 | 19 | OK |
| conversions | 2026-03-20 | 19 | OK |
| existing-infrastructure | 2026-03-20 | 19 | OK |
| implementation | 2026-04-01 | 7 | OK |
| memory-safety | 2026-03-25 | 14 | OK |
| platform | 2026-03-20 | 19 | OK |
| testing | 2026-03-27 | 12 | OK |
| testing-swiftlang | 2026-03-27 | 12 | OK |
| testing-institute | 2026-03-27 | 12 | OK |
| benchmark | 2026-03-27 | 12 | OK |
| swift-institute | 2026-03-20 | 19 | OK |
| swift-institute-core | 2026-03-27 | 12 | OK |
| handoff | 2026-03-26 | 13 | OK |
| primitives | 2026-03-26 | 13 | OK |

**All implementation skills are within the 90-day window.** All were reviewed in the March 2026 skill overhaul.

#### Process Skills (180-day threshold = stale if before 2025-10-10)

| Skill | Last Reviewed | Days Since | Status |
|-------|--------------|-----------|--------|
| collaborative-discussion | 2026-03-20 | 19 | OK |
| experiment-process | 2026-03-20 | 19 | OK |
| research-process | 2026-03-20 | 19 | OK |
| reflect-session | 2026-03-31 | 8 | OK |
| reflections-processing | 2026-03-20 | 19 | OK |
| corpus-meta-analysis | 2026-04-01 | 7 | OK |
| skill-lifecycle | 2026-03-20 | 19 | OK |
| blog-process | 2026-03-20 | 19 | OK |
| quick-commit-and-push-all | 2026-03-20 | 19 | OK |
| readme | 2026-03-20 | 19 | OK |

**All process skills are within the 180-day window.**

#### Superseded Skill Retention

No `superseded_by` fields found in any skill YAML frontmatter. No retained superseded directories to clean up.

### Audit Staleness [META-021]

#### audit.md Files Found

- `Research/audit.md` — Ecosystem-wide
- `https://github.com/swift-primitives/Research/blob/main/audit.md` — Primitives-wide
- 40 package-level audit.md files in swift-foundations
- ~150 package-level audit.md files in swift-primitives

#### Section Date Analysis (>60 days = stale if before 2026-02-07)

| Audit File | Oldest Section | Date | Days Old | Stale? |
|-----------|----------------|------|----------|--------|
| swift-institute/Research/audit.md | Conversions | 2026-03-24 | 15 | NO |
| swift-institute/Research/audit.md | Memory Safety | 2026-03-25 | 14 | NO |
| swift-institute/Research/audit.md | Variant Naming | 2026-03-25 | 14 | NO |
| swift-institute/Research/audit.md | ASCII Serialization | 2026-03-25 | 14 | NO |
| swift-primitives/Research/audit.md | Modularization (Import Precision) | 2026-04-03 | 5 | NO |
| swift-io/Research/audit.md | Code Surface | 2026-04-02 | 6 | NO |
| swift-kernel/Research/audit.md | Code Surface | 2026-03-24 | 15 | NO |
| swift-testing/Research/audit.md | Legacy (Consolidated) | 2026-04-08 | 0 | NO |

**No audit sections exceed the 60-day staleness threshold.** All ecosystem-level and sampled package-level audits were created or refreshed in the March-April 2026 audit campaign.

---

## Summary of Findings

### Critical (Action Required)

| # | Phase | Finding | Action |
|---|-------|---------|--------|
| 10-1 | 10 | swift-foundations/Experiments/ has NO `_index.md` — 7 experiments unlisted [META-009] | Create `_index.md` |
| 11-1 | 11 | 46 unprocessed reflections in swift-institute (44% of total) [META-011] | Run reflections-processing session |
| 12-1 | 12 | 6 blog ideas stalled >70 days in "Ready for Drafting" [META-012] | Triage: draft, demote to "Needs More Context", or archive |

### Medium

| # | Phase | Finding | Action |
|---|-------|---------|--------|
| 9-1 | 9 | CLAIM IDs not globally unique — same IDs reused with different meanings across experiments | Define namespacing convention if CLAIM system is kept |
| 10-2 | 10 | 6 research docs missing from swift-institute Research index | Add to `_index.md` |
| 10-3 | 10 | 6 experiments missing from swift-institute Experiments index | Add to `_index.md` |
| 10-4 | 10 | 2 experiments missing from swift-primitives Experiments index | Add to `_index.md` |
| 10-5 | 10 | 2 research docs missing from swift-primitives Research index | Add to `_index.md` |

### Low / Informational

| # | Phase | Finding | Action |
|---|-------|---------|--------|
| 8-1 | 8 | No version tags exist in any superrepo — discovery coverage check N/A | Monitor for first release |
| 9-2 | 9 | ASSUMP-* namespace completely unused | Consider deprecating or documenting intended use |
| 9-4 | 9 | Claims exist only inside experiments, never linked from Research | Consider Research → Experiment claim linkage |
| 11-2 | 11 | All References/.bib files present | No action |
| 12-2 | 12 | All skills within review cadence | No action |
| 12-3 | 12 | No stale audit sections (all <60 days) | No action |
| 12-4 | 12 | No superseded skills with retained directories | No action |
