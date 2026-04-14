# Corpus Meta-Analysis Phase 1a: Research Staleness Detection

**Date**: 2026-04-08
**Scope**: All IN_PROGRESS research documents across 6 repositories
**IDs**: [META-001], [META-002]

---

## Summary

| Metric | Count |
|--------|-------|
| Total IN_PROGRESS documents found | 19 |
| OK (< 21 days) | 14 |
| SHOULD triage (21-42 days) | 5 |
| MUST triage (> 42 days) | 0 |
| UNKNOWN status (missing metadata) | 0 |
| Metadata inconsistency (frontmatter/body mismatch) | 0 |

---

## IN_PROGRESS Documents: Staleness Table

| # | Repository | Document | Last Updated | Age (days) | Classification | Triage Recommendation |
|---|-----------|----------|--------------|------------|----------------|----------------------|
| 1 | swift-institute | handle-vs-arena-position-unification.md | 2026-04-01 | 7 | OK | -- |
| 2 | swift-institute | treereduce-swift-feasibility.md | 2026-03-31 | 8 | OK | -- |
| 3 | swift-institute | claude-code-swift-rewrite-feasibility.md | 2026-04-01 | 7 | OK | -- |
| 4 | swift-institute | path-decomposition-delegation-strategy.md | 2026-04-01 | 7 | OK | -- |
| 5 | swift-institute | transfer-cell-cancellation-propagation.md | 2026-03-31 | 8 | OK | -- |
| 6 | swift-institute | async-mutex-rawlayout-inline-storage.md | 2026-03-31 | 8 | OK | -- |
| 7 | swift-institute | concrete-async-operator-types.md | 2026-03-31 | 8 | OK | -- |
| 8 | swift-institute | async-stream-sendable-requirement.md | 2026-03-30 | 9 | OK | -- |
| 9 | swift-institute | test-console-output-elegance.md | 2026-03-27 | 12 | OK | -- |
| 10 | swift-institute | skill-as-input-composition-pattern.md | 2026-03-26 | 13 | OK | -- |
| 11 | swift-institute | swiftpm-build-plugins-for-xfrontend-flags.md | 2026-03-22 | 17 | OK | -- |
| 12 | swift-institute | nonsending-callasfunction-inference-quirk.md | 2026-03-22 | 17 | OK | -- |
| 13 | swift-institute | swift-64-dev-compatibility-catalog.md | 2026-03-22 | 17 | OK | -- |
| 14 | swift-institute | span-view-integration-strategy.md | 2026-03-19 | 20 | OK | -- |
| 15 | swift-institute | knowledge-encoding-end-state-literature-review.md | 2026-03-18 | 21 | **SHOULD** | DEFERRED |
| 18 | swift-institute | next-steps-parsers.md | 2026-03-16 | 23 | **SHOULD** | DEFERRED |
| 19 | swift-institute | primitives-public-api-graph-analysis.md | 2026-03-15 | 24 | **SHOULD** | DEFERRED |
| 21 | swift-institute | test-support-snapshot-strategy-sharing.md | 2026-03-14 | 25 | **SHOULD** | DEFERRED |
| 22 | swift-institute | developer-tool-package-architecture.md | 2026-03-13 | 26 | **SHOULD** | DEFERRED |

---

## Triage Rationale for SHOULD-Triage Documents

### 15. knowledge-encoding-end-state-literature-review.md (21 days)

**Recommended status**: DEFERRED

**Rationale**: Literature review is substantively complete -- identifies 15 intellectual traditions, 4 gaps for further investigation. The gaps (unified theory, scale evidence, composition theory, LLM implications) are long-horizon research topics, not blocking any implementation. No immediate consumer exists.

**Blocker**: None -- this is a pure academic exercise with no implementation dependency.
**Resumption trigger**: When preparing publications or blog posts about the Swift Institute's approach.

---

### 18. next-steps-parsers.md (23 days)

**Recommended status**: DEFERRED

**Rationale**: Tracking document for parser ecosystem migration. Status verified on 2026-03-16 shows 14 packages complete, 1 bifurcated (WHATWG URL), 2 not started (RFC 9112, RFC 9111), 18 remaining `.split()` calls. Work is well-defined but low priority relative to current IO/async/ownership focus areas.

**Blocker**: Capacity -- parser migration is not on the critical path.
**Resumption trigger**: When HTTP layer work (RFC 9112/9111) begins.

---

### 19. primitives-public-api-graph-analysis.md (24 days)

**Recommended status**: DEFERRED

**Rationale**: Symbol graph extraction pipeline works (115/132 packages, 13,262 symbols). Key findings are documented (parser/serializer asymmetry, isolated modules, orphaned protocols, empty modules). Follow-up drill-downs are defined but not blocking anything.

**Blocker**: None -- low priority relative to current work.
**Resumption trigger**: When developer tooling (swift-dependency-analysis) is built, this data feeds into it.

---

### 21. test-support-snapshot-strategy-sharing.md (25 days)

**Recommended status**: DEFERRED

**Rationale**: Fundamental tension identified (test support needs parent product, snapshot strategies need swift-testing deps, nested packages cannot share). Three promising directions documented (Option F generic strategy, Option E trait-gated via SE-0450, Option B parent dep). Resolution depends on SE-0450 stabilization (package traits).

**Blocker**: SE-0450 (Swift Package Manager package traits) not yet stabilized.
**Resumption trigger**: SE-0450 accepted/implemented, or decision to relax the nested-package principle.

---

### 22. developer-tool-package-architecture.md (26 days)

**Recommended status**: DEFERRED

**Rationale**: Design is substantively complete -- 5 decisions made, 6 implementation phases defined, open design questions (Q1-Q5) documented. No implementation has started. This is a greenfield package with no current consumers.

**Blocker**: Capacity -- no immediate need for swift-dependency-analysis.
**Resumption trigger**: When ecosystem grows enough that manual dependency auditing becomes impractical, or when primitives-public-api-graph-analysis data is integrated.

---

## Metadata Quality Notes

1. **Date field inconsistency**: Some documents use `last_updated:`, others use `date:`, others use `created:` without `last_updated:`. Documents #11-13 (swiftpm-build-plugins, nonsending-callasfunction, swift-64-dev) use `date:` as their only temporal field. Documents #5, #6, #7 use `created:` without `last_updated:`. For staleness detection, `date:` and `created:` were treated as `last_updated:` equivalents when no `last_updated:` was present.

2. **Frontmatter format inconsistency**: Most documents use HTML-comment-wrapped YAML (`<!-- --- ... --- -->`). A few use bare YAML (`--- ... ---`). Both formats function correctly for status detection.

