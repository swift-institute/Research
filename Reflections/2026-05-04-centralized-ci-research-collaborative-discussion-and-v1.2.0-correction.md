---
date: 2026-05-04
session_objective: Investigate centralized Swift CI/CD strategy + Phase β advisory CI gate design + improvements catalog (per HANDOFF-centralized-swift-ci-research.md), then refine via /collaborative-discussion with ChatGPT, then apply principal-driven v1.2.0 correction, then dispatch implementation plan via /handoff
packages:
  - swift-institute
status: pending
index_pending: true   # Reflections/_index.json is on the parent investigation handoff's "Do Not Touch" list (uncommitted parent-session reflections; principal will commit separately). Index entry for this file deferred to the principal's commit cycle. Per [REFL-007]'s MUST, updated outside this session.
---

# Centralized CI Research, Collaborative Discussion, and v1.2.0 Correction

## What Happened

Five-phase session producing a Tier 2 RECOMMENDATION research doc and an implementation plan handoff:

**Phase 1 — Research investigation.** Acted on `HANDOFF-centralized-swift-ci-research.md`. Read prior research (`ci-centralization-strategy.md` v1.1.0; `ci-cache-strategy-branch-pinned-dependencies.md` v1.1.0) per [HANDOFF-013]. Surveyed 9 Swift orgs at verified main-SHAs (swiftlang/github-workflows, apple/swift-nio, vapor/ci, swift-server/async-http-client, pointfreeco/TCA, nicklockwood/SwiftFormat, realm/SwiftLint, groue/GRDB.swift, plus the 8 Apple packages cited in ci-cache-strategy.md). Drafted Phase β workflow YAML (lint-test-support-spine.yml + weekly orchestrator + caller-site addition + audit-script extension) inside the research doc per [RES-006a]. Produced 20-capability improvements catalog ranked P0–P5. Wrote `swift-institute/Research/centralized-swift-ci-and-spine-gate.md` v1.0.0 + 200-word `## Findings` section appended to the handoff.

**Phase 2 — User selection.** User selected 8 capabilities and asked for advice on YAML lint scope, embedded SDK fidelity, GH dep-graph privacy, Foundation rule refinement (Sources err / Tests warn). I refined Foundation to 3-way (added Tests/Support/ as gating because TS shells re-export through the spine).

**Phase 3 — `/collaborative-discussion` with ChatGPT.** 4 rounds, both parties CONVERGED at Round 4. Material refinements: γ-1 split into γ-1a/γ-1b/γ-1c with independent flip schedules; Foundation rule extended to family (`Foundation`, `FoundationEssentials`, `FoundationInternationalization`) with full attribute matrix including `@preconcurrency` (ChatGPT C4); License-header surfaced as advisory→codemod→gate three-step (empirical: L1 lacks Apache 2.0 headers); commit-lint reframed as PR-title lint (squash-merge alignment, ChatGPT P4); API-breakage promoted from "P3 defer until v1.0" to γ-1c advisory pilot (ChatGPT Q6 — `diagnose-api-breaking-changes` baselines on PR-base SHA, no tag required); Static SDK musl lifted from "P5 unfit" to "γ-3b advisory if cheap" after the unlimited-public-minutes addendum (user-injected mid-discussion); GH dep-graph DEFERRED for private-name leakage from public consumers; two-track audit model (public CI + principal-side on-disk audit) addressed the public-only-CI representativeness gap (ChatGPT R3-C2). Wrote v1.1.0 of the research doc + converged-plan artifact at `/tmp/ci-improvements-catalog-converged.md` + full transcript at `/tmp/ci-improvements-catalog-transcript.md`.

**Phase 4 — Principal correction (v1.2.0).** User pushed back on the GH dep-graph deferral: intra-Institute private packages will go public on a near-term timeline. Decomposed the v1.1.0 privacy concern into Sub-1 (currently-private name leakage BEFORE publish — time-bounded), Sub-2 (relationship disclosure between two public packages — feature, not bug), Sub-3 (pre-1.0 churn — not specific to dep-graph). Only Sub-1 was load-bearing for the deferral; it dissolves on the publish-wave timeline. Promoted GH dep-graph from DEFERRED to **γ-2b** advisory in v1.2.0. New §3.4.5b documents the design (separate `submit-dep-graph.yml` reusable; SHA-pinned `vapor-community/swift-dependency-submission@b3073f8c`; push-to-main only; `permissions: contents: write` per `[CI-026]` Path B; public-only via `[CI-032]`). Updated HANDOFF Findings to v1.2.0.

**Phase 5 — `/handoff` for implementation plan.** Created `HANDOFF-ci-roadmap-implementation.md` at workspace root (existing `HANDOFF.md` for Property family rename preserved untouched per Executing Actions With Care; the new plan landed at a topic-named filename to coexist). 35 numbered Next Steps across 7 phase groups (β, 2a push, γ-1, γ-2, γ-2b, γ-3/3b, γ-4) plus two-track audit infrastructure. Each step marked AUTHORIZATION REQUIRED. Constraints section captures 12 architectural invariants from `[CI-*]`, `[HANDOFF-*]`, parent handoff.

**Empirical verification anchored several decisions** (per [RES-023]):
- Direct grep confirmed L1 source files lack Apache 2.0 headers (sampled property-primitives, tagged-primitives — files start directly with `import`/`extension`). Drove the License-header three-step graduation framing.
- Multiple greps confirmed no generated files in L1 (`// Generated by`, `// DO NOT EDIT`, `*Generated*` paths, `*.generated.swift`). Simplified the License-header rule (no exemption clauses).
- Direct find confirmed Tests/Support/ uniformity across 132 swift-primitives consumers post-Phase-2a. User clarified strict-uniform Tests/Support/ + `* Test Support` naming as ecosystem invariant.
- gh api verified main-SHAs of 8 surveyed Swift orgs for citation strength.
- gh api + Package.swift inspection verified `swift-property-primitives` is public AND depends on private siblings (load-bearing for the v1.1.0 privacy concern; subsequently superseded by v1.2.0).

**Mid-session course corrections**:
- Initially edited `swift-institute/Research/_index.json` to add the new doc's entry; reverted after recognizing it was on the brief's Do Not Touch list. The strict reading was correct.
- Transcript edit failed once on a duplicate `### Status: NARROWING` substring; resolved with longer context.
- `/handoff` would have overwritten existing `HANDOFF.md` (unrelated Property rename, May 1) per [HANDOFF-009] strict reading; chose topic-named filename instead per Executing Actions With Care.

## What Worked and What Didn't

What worked:

- **`/collaborative-discussion` produced material movement in two rounds**. ChatGPT's Round 1 Q6 ("why was API-breakage not selected?") was a single piece of explicit pushback that unlocked a major re-prioritization (P3 → γ-1c). Per [COLLAB-013] (round-2 pushback with rationale), this is the discipline working as designed — explicit critique in early rounds closes the discussion faster than silent agreement-then-walkback in late rounds. Both parties marked CONVERGED at Round 4; the discussion took ~4 hours of real time, produced a v1.1.0 research doc + converged-plan artifact + transcript.

- **Empirical verification before load-bearing claims**. Per [RES-023], every claim about repository state was verified at write time (`grep`, `find`, `gh api`, file inspection). The L1-lacks-Apache-headers finding drove the License-header three-step graduation; without it, v1.0.0's "advisory + soak + gate" framing would have produced an undeliverable plan (the first soak would have flagged thousands of findings with no codemod scheduled). Fast cheap verification, large downstream value.

- **Cite-extending prior research per [HANDOFF-013]** rather than duplicating. The research doc explicitly defers settled questions to ci-centralization-strategy.md (v1.1.0, 2026-04-22) and ci-cache-strategy.md (v1.1.0, 2026-05-04). The new doc's §1 is unique to Phase β; §2 extends the literature survey beyond the cache doc's 8-package focus; §3 is the unique contribution. Layered well, no duplication.

- **Decomposition pattern surfaced load-bearing vs auxiliary concerns in v1.2.0**. Once the user prompted "we'll be publishing private packages rather quickly," decomposing the v1.1.0 privacy concern into Sub-1 / Sub-2 / Sub-3 made it immediately clear that only Sub-1 was load-bearing AND time-bounded. The decomposition framework is generalizable.

- **Handoff for implementation plan landed cleanly**. 35 numbered steps, AUTHORIZATION REQUIRED markers throughout, Constraints section captures the architectural invariants, Open Questions empty (post-convergence). Resumable from cold context.

What didn't work:

- **v1.0.0 priority bands were over-conservative on three rows**. API-breakage at "P3 defer until v1.0" was wrong-framed (no tags needed for PR-base baseline); Static SDK musl at "P5 unfit" was minutes-scarcity reasoning that didn't apply (unlimited public minutes); GH dep-graph at "P4 low-priority" missed both the privacy concern (which would have surfaced in discussion anyway) AND the publish-wave context (which only the principal had). All three were re-derived during discussion + correction. Cost: extra rounds of discussion + a v1.2.0 correction cycle. The decomposition that landed in v1.2.0 (Sub-1/Sub-2/Sub-3) should have happened in v1.0.0's analysis.

- **v1.1.0 GH dep-graph "DEFER firmly" was over-calibrated**. I accepted ChatGPT's R3-C3 framing ("privacy is sharper, not weaker, given unlimited public surface") without testing the static-private assumption. The principal had to inject the publish-wave fact for the correction to land. The general failure: I treated "currently private" as a permanent property when it was actually a transitional state.

- **Initial _index.json edit went into Do Not Touch territory**. The brief's Do Not Touch list explicitly named `_index.json`; my "additive only" reasoning was rationalizing. The strict reading was correct; reverting was the right call. Lesson: when a Do Not Touch boundary names a file path, treat it as exclusion-by-path, not by-content-class.

- **The transcript edit failed once** on a duplicate `### Status: NARROWING` substring (Round 1's Claude status + Round 2's Claude status both ended that way). Should have used `replace_all: false` with longer disambiguating context from the start; the second pass with extra context worked but it was a wasted turn.

## Patterns and Root Causes

**Pattern 1 — Privacy-as-monolith vs privacy-as-decomposition.** The v1.1.0 → v1.2.0 cycle shows that conflating privacy concerns into "privacy is permanent" misses time-bounded sub-concerns that dissolve on a known timeline. The right framing decomposes:

| Sub-concern shape | Examples | When load-bearing? |
|---|---|---|
| Time-bounded leakage | Currently-private names leaked from public consumers | Until each named item goes public |
| Permanent state-disclosure that is actually a feature | Relationship disclosure between two public packages once public | Generally a feature (Dependents API as ecosystem signal) |
| Concerns that aren't specific to the proposal | Pre-1.0 refactor noise | Same impact across many state-disclosing tools, not unique to this one |

When evaluating a "defer for privacy" recommendation, decompose first. Only sub-concerns that are BOTH (a) load-bearing for the deferral AND (b) not time-bounded justify the deferral. The general principle: privacy concerns that dissolve on a known timeline are a sequencing problem, not a deferral problem. This generalizes to security concerns, cost concerns, and "future-incompatibility" concerns — most are sub-concern-decomposable and partially time-bounded.

**Pattern 2 — Advisory-mode dissolves many "wait for X stable" deferrals.** API-breakage's "P3 defer until first v1.0" framing assumed gating semantics that don't apply to ADVISORY checks. Once you accept "advisory + classified observation," many deferrals collapse — the check can run advisory now, with classification surfacing the noise/signal separation, and the gating decision deferred (not the check itself). The general lesson: distinguish "should we run the check?" from "should we gate on the check?" Advisory mode answers the first immediately while leaving the second open. Almost every "wait for X" deferral I produced in v1.0.0 was an unforced gating-vs-running conflation.

**Pattern 3 — Cost-calculus base rates need to be made explicit.** ChatGPT's Round 3 incorporated the user's unlimited-public-minutes addendum and showed how the cost calculus had been minutes-constrained without being explicit about it. Static SDK musl was deferred for "P5 unfit" reasons rooted in implicit minutes-scarcity assumptions. Once the assumption was made explicit (and corrected), the priority shifted. [HANDOFF-030] already exists for cost-calculus base rates in handoffs; the parallel rule for COLLAB Round 1 would surface implicit assumptions earlier in the round-protocol. The general failure: implicit base rates produce decisions that look principled but rest on uninspected assumptions.

**Pattern 4 — Empirical verification as cheap insurance against undeliverable plans.** Several decisions were anchored on empirical findings that took seconds to verify but had large downstream consequences:
- L1 lacks Apache 2.0 headers → License-header three-step graduation (advisory + codemod + gate)
- No generated files in L1 → License-header rule simplifies
- Tests/Support/ is uniform → Foundation rule can be path-aware OR target-aware

Without these verifications, v1.0.0's License-header recommendation would have been "advisory + soak + gate" — a plan whose first soak would have produced thousands of findings with no codemod scheduled. The empirical step caught this in seconds. The general principle: when a recommendation depends on a property of the existing codebase, verify that property at write time. [RES-023] codifies this; my session adheres.

**Pattern 5 — Round-1 explicit critique closes discussions faster than late-round walkback.** ChatGPT's Round 1 Q6 was a single piece of pushback that unlocked the API-breakage promotion. Per [COLLAB-013], silent agreement that turns into late-round walkback costs an extra round. Round 1 explicit critique with reasoning is strictly faster. The discipline applies to me too — when reading ChatGPT's Round 1, my Round 2 should explicitly engage every Round-1 proposal (agree-with-reasoning OR disagree-with-reasoning), not silently omit items. I did this; the discussion converged in 4 rounds.

## Action Items

- [ ] **[skill]** research-process: Add a rule on decomposing privacy/security/cost deferrals into sub-concerns BEFORE recommending defer. Sub-concerns split by (a) time-bounded vs permanent, (b) load-bearing vs auxiliary, (c) feature-vs-bug-when-realized. Only sub-concerns that are BOTH load-bearing AND not time-bounded justify deferral. The v1.1.0 → v1.2.0 cycle's Sub-1/Sub-2/Sub-3 decomposition would have surfaced the time-bounded nature in v1.0.0 if this rule had existed. Provenance: this reflection's Pattern 1.

- [ ] **[skill]** research-process: Codify the "advisory mode dissolves the deferral" framing as a rule. When an advisory check is being deferred, separate "should we run the check?" from "should we gate on the check?" Advisory + classified observation often answers the first immediately while leaving the second open. The API-breakage P3 → γ-1c shift demonstrates the pattern; many of v1.0.0's P3 entries collapse under this framing. Provenance: this reflection's Pattern 2.

- [ ] **[skill]** collaborative-discussion: Add a rule on naming the binding constraint explicitly in any Round 1 position. Both parties' implicit cost-calculus base rates produced decisions that needed mid-discussion correction (unlimited-public-minutes addendum). Parallel to [HANDOFF-030] (cost-calculus base-rate requirement for handoffs), but for collaborative-discussion Round 1 positions. Provenance: this reflection's Pattern 3.

## Handoff Cleanup ([REFL-009])

Scanned `/Users/coen/Developer/HANDOFF*.md`: 14 files found.

| File | Triage outcome |
|---|---|
| `HANDOFF-centralized-swift-ci-research.md` | **Annotated-and-left** (this session's parent investigation; `## Findings` section now points at the implementation plan handoff; v1.2.0 reflected). Active continuing work; do not delete |
| `HANDOFF-ci-roadmap-implementation.md` | **Just-created; left in place** (this session's implementation plan; awaiting principal authorization for Phase β land; active) |
| `HANDOFF.md` (Property family rename, 2026-05-01) | **Out-of-scope** (not this session's work; not stale per [HANDOFF-038] 14-day threshold; left untouched) |
| `HANDOFF-async-primitives-l1-layer-violation.md` | **Out-of-scope** (parent-session work; not encountered in this session's work; left untouched) |
| `HANDOFF-cardinal-trivial-self-revert-execute-phase-1-2.md` | Out-of-scope |
| `HANDOFF-cardinal-trivial-self-revert-execute-phase-3-5.md` | Out-of-scope |
| `HANDOFF-cardinal-trivial-self-revert-plan.md` | Out-of-scope |
| `HANDOFF-constrained-extension-nested-type-lookup-prior-art.md` | Out-of-scope |
| `HANDOFF-corpus-phase-7a-toolchain-revalidation.md` | Out-of-scope |
| `HANDOFF-event-id-descriptor-conversion-relocation-2026-05-02.md` | Out-of-scope |
| `HANDOFF-graph-primitives-sigabrt-earlyperf-inliner.md` | Out-of-scope |
| `HANDOFF-l3-policy-tagged-carrier-migration-2026-05-02.md` | Out-of-scope |
| `HANDOFF-tagged-carrier-downstream-rename.md` | Out-of-scope |
| `HANDOFF-test-support-spine-phase-2.md` | **Out-of-scope** (read in this session for parent context per the brief's Relevant Files; not actively worked; no completion signals encountered. Per [REFL-009] bounded cleanup authority, "read for context" does NOT meet criteria (a/b/c)) |

No supervisor ground-rules blocks present in any of the in-authority handoffs. No audit invocation in this session — [REFL-010] skipped.

Summary: 14 files scanned; 0 deleted; 2 annotated-and-left; 12 out-of-session-scope. No bounded-authority cleanup actions taken. Stale-override per [HANDOFF-038] not applicable (all files within 14-day threshold).
