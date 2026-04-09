# Corpus Meta-Analysis Phase 1a: Research Staleness Detection

**Date**: 2026-04-08
**Scope**: All IN_PROGRESS research documents across 6 repositories
**IDs**: [META-001], [META-002]

---

## Summary

| Metric | Count |
|--------|-------|
| Total IN_PROGRESS documents found | 22 |
| OK (< 21 days) | 14 |
| SHOULD triage (21-42 days) | 8 |
| MUST triage (> 42 days) | 0 |
| UNKNOWN status (missing metadata) | 3 |
| Metadata inconsistency (frontmatter/body mismatch) | 1 |

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
| 16 | swift-institute | document-infrastructure-ergonomic-audit.md | 2026-03-17 | 22 | **SHOULD** | RECOMMENDATION |
| 17 | rule-law | soort-of-aanduiding-domain-analysis.md | 2026-03-17 | 22 | **SHOULD** | DECISION |
| 18 | swift-institute | next-steps-parsers.md | 2026-03-16 | 23 | **SHOULD** | DEFERRED |
| 19 | swift-institute | primitives-public-api-graph-analysis.md | 2026-03-15 | 24 | **SHOULD** | DEFERRED |
| 20 | swift-nl-wetgever | questionnaire-patterns-for-statute-evaluation.md | 2026-03-15 | 24 | **SHOULD** | DEFERRED |
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

### 16. document-infrastructure-ergonomic-audit.md (22 days)

**Recommended status**: RECOMMENDATION

**Rationale**: Analysis is complete. Four phases are defined. Decisions were already made on 2026-03-17 (no separate L2 package, legal docs to rule-legal, recursive clauses, CSS baseline still open). The Outcome section has resolved questions and a clear phased implementation plan. Only the CSS baseline vs PDF.HTML.Configuration question remains open, which is a minor sub-question not blocking the overall recommendation.

---

### 17. soort-of-aanduiding-domain-analysis.md (22 days)

**Recommended status**: DECISION

**Rationale**: **Metadata inconsistency detected.** Frontmatter says `status: IN_PROGRESS` but the Outcome section (line 259) explicitly says `"Status: DECISION -- Two protocols, associated type, statuten as source of truth"`. The analysis is complete and a concrete two-protocol model with associated type is specified. The frontmatter was never updated to match.

**Action**: Update frontmatter `status: IN_PROGRESS` to `status: DECISION`.

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

### 20. questionnaire-patterns-for-statute-evaluation.md (24 days)

**Recommended status**: DEFERRED

**Rationale**: Research into questionnaire-guided statute evaluation is comprehensive (v4.0.0, 660+ lines). Next steps are defined (builder modification, conclusion types, tracked type, gating enum). However, the conclusion-types-converged-plan.md (also in swift-nl-wetgever/Research/) represents a later convergence. This document's next steps are subsumed by the converged plan.

**Blocker**: Conclusion types macro architecture not yet implemented.
**Resumption trigger**: When `@Lid` macro work begins per converged plan.

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

## Documents with UNKNOWN Status (Missing Metadata)

These documents exist in Research directories but have no `status:` field in frontmatter, requiring metadata audit per [META-002].

| # | Repository | Document | Notes |
|---|-----------|----------|-------|
| 1 | rule-law | aandeelhoudersregister-comparative-analysis.md | Has `**Date**: 2026-03-16` in body but no YAML frontmatter at all. Reads as a complete comparative analysis with priority action items. Likely should be RECOMMENDATION or DECISION. |
| 2 | swift-nl-wetgever | conclusion-types-converged-plan.md | No frontmatter. Reads as a converged plan (DECISION). Title says "Converged Plan". |
| 3 | swift-nl-wetgever | conclusion-types-discussion-transcript.md | No frontmatter. Discussion transcript between Claude and ChatGPT. Should be tagged as supporting material or DECISION (the discussion reached convergence). |

---

## Metadata Quality Notes

1. **Date field inconsistency**: Some documents use `last_updated:`, others use `date:`, others use `created:` without `last_updated:`. Documents #11-13 (swiftpm-build-plugins, nonsending-callasfunction, swift-64-dev) use `date:` as their only temporal field. Documents #5, #6, #7, #16 use `created:` without `last_updated:`. For staleness detection, `date:` and `created:` were treated as `last_updated:` equivalents when no `last_updated:` was present.

2. **Frontmatter format inconsistency**: Most documents use HTML-comment-wrapped YAML (`<!-- --- ... --- -->`). A few use bare YAML (`--- ... ---`). Both formats function correctly for status detection.

3. **Body vs frontmatter status divergence**: Document #17 (soort-of-aanduiding-domain-analysis.md) has `status: IN_PROGRESS` in frontmatter but `"Status: DECISION"` in the Outcome section. Frontmatter is treated as authoritative per convention, but this indicates the document was resolved without updating the frontmatter.
