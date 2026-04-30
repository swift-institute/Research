---
date: 2026-04-23
session_objective: Finish the coenttb URL-hygiene push tail, write + dispatch the superrepo dismantle handoff, and handle the Phase II.5 premise-break escalation that surfaced when a fresh session's pre-execution readiness check contradicted the heritage-transfer investigation's scope facts; close with supervisor review of the v1.2.0 plan consolidation
packages:
  - coenttb/swift-epub-rendering
  - coenttb/swift-epub
  - coenttb/swift-date-parsing
  - coenttb/swift-email
  - coenttb/swift-syndication
  - swift-institute/Research
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: no_action
    description: "AI 1 (path-dep-ecosystem-lifecycle Tier 2 research) deferred — concrete write-up overhead exceeds value at present; trigger pending if hazard surfaces in another workstream. The hazard's mitigation is operationally captured by [HANDOFF-036] Recipe-and-Path-Math Empirical Verification (added 2026-04-30)."
  - type: no_action
    description: "AI 2 (git-history-transfer-patterns recipe correction update) deferred — superseded by [RES-024] Empirical-Reproduction Requirement for Git-Recipe Claims (added 2026-04-30). The corrected recipe shape (rm+checkout primary) is now embedded in the rule's worked example."
  - type: no_action
    description: "AI 3 ([SUPER-015] provenance note) — added inline as 'Empirical-Provenance Note (Compression-at-Pivot)' addendum to supervise/SKILL.md on 2026-04-30 alongside [SUPER-029] / [SUPER-030]."
  - supervise
  - handoff
status: pending
---

# Phase II.5 premise-break, supervisor-block compression at architectural pivot, and plan review

## What Happened

Continued the multi-week ecosystem rollout. This session handled two distinct arcs after the morning's CI-centralization tail:

**Coenttb URL-hygiene pushes + deferrals (mid-session)**: inspected 8 coenttb repos with ahead-of-origin commits. 4 pushed cleanly (`swift-epub-rendering`, `swift-epub`, `swift-date-parsing`, `swift-email`) — pure URL-hygiene or URL-hygiene + hygiene-only config, zero source/structural ride-along. 4 deferred (`swift-form-coding` has an absolute-path symlink leak `Packages/swift-url-form-coding -> /Users/coen/Developer/...`; `swift-authenticating` has Router source changes below URL-hygiene; `pointfree-url-form-coding` has a structural RFC-2388 refactor; `swift-documents` has a structural async-filesystem feature). `swift-syndication` surfaced a separate mystery: remote `coenttb/swift-syndication` returns 404 on GitHub while local filter-repo'd state (240K .git) + backup remain intact. Parked as investigation workstream.

**Superrepo dismantle handoff** (written + dispatched + supervised): authored `HANDOFF-superrepo-dismantle.md` as branching brief for a fresh session to execute. Fresh session escalated twice (untracked-content relocation + swift-standards local/remote divergence); both handled via principal direction per [SUPER-012]. Outcome captured in parallel reflection `2026-04-23-superrepo-dismantle-and-phase-0-5-remediation.md`.

**Phase II.5 premise-break escalation + supervisor response** (load-bearing): user pivoted to broader coenttb → swift-institute transfer; sequential handoff written for new chat. Fresh session halted at pre-execution readiness — Phase II.5's operational plan rested on a scope fact ("placeholders are ~10-commit scaffolds") that turned out false. Live `gh`/`git` verification found all 9 existing `swift-foundations/*` destinations carrying 14–49 commits of substantive ecosystem work (`Rendering`→`Render` rename, `HTML.__DocumentProtocol` hoist, `Rendering.View.Body` adoption). The "auto-safe placeholder delete" classification in Recipe 3 was invalidated for 9 of 18 destinations. `/supervise` invoked on the escalation: classified the 5 blockers (a/b/c: class (c) → user; d: execution-path only; e: expected per Rule 6), surfaced Q1 (canonical-history strategy) / Q2 (WIP disposition) / Q3 (swift-html-to-pdf branch) to user. User answered: Q1 = rename-and-reconcile variant with aggressive squash on ecosystem work (preserve coenttb heritage untouched, apply ecosystem as single squashed commit); Q2 = per-case triage, default commit; Q3 = branch 1.1 is canonical (fast-forward main to 1.1). Ground-rules block compressed per [SUPER-015] at the architectural-pivot boundary — 6 rules → 6 rules with #2 and #4 rewritten using merges notation to absorb Q1/Q2/Q3 decisions.

**Supervisor review of v1.2.0 plan consolidation**: user produced `coenttb-ecosystem-heritage-transfer-plan.md` v1.2.0 consolidating the revised plan per `[META-016]`. Independent supervisor review commissioned; surfaced 2 Critical findings — (i) recipe step (v) `git checkout ecosystem/main -- .` misses files present in HEAD but absent in ecosystem (result is union, not ecosystem state), (ii) ecosystem-sibling Package.swifts carry 7+ `.package(path: "../../...")` deps that don't resolve for external consumers. Plus 1 High (stale "two force-push points" text contradicting v1.2.0's retraction), 2 Medium, 2 Low. User empirically verified both Criticals (scratch-repo reproduction of deletion gap; `swift-foundations/swift-html-render/Package.swift:66-72` grep). Closing Q1/Q2 on fix paths: endorsed Option B (post-transfer URL-hygiene sweep as named Phase-V analog, matching 81-package `github-organization-migration-swift-file-system` precedent) + rm+checkout recipe variant primary with plumbing as footnote. Closing note identified that the Phase-V sweep should batch two grep-shapes: ecosystem path-deps AND transferred-alongside URL-deps to old coenttb URLs.

## Handoff triage per [REFL-009]

Scanned `/Users/coen/Developer/HANDOFF*.md` — 15 files.

| File | Outcome |
|---|---|
| `HANDOFF.md` | annotated-and-left — updated in-session with 2026-04-23-evening progress + compressed supervisor block + Q1/Q2/Q3 decisions in `[RESOLVED]` sub-section of Open Questions |
| `HANDOFF-superrepo-dismantle.md` | **already deleted** by parallel-session `/reflect-session` per [REFL-009] (all 9 ground-rule entries verified end-to-end) |
| `HANDOFF-ci-permission-architecture.md` | **already deleted** by parallel-session `/reflect-session` per [REFL-009] (investigation + execution complete, no supervisor block so no verification gate) |
| `HANDOFF-heritage-transfers-and-history-strategy.md` | annotated-and-left — marked SUPERSEDED by `coenttb-ecosystem-heritage-transfer-plan.md` per [META-016]; retained as historical reference per [REFL-009] disposition rules |
| `HANDOFF-swift-testing-successor-migration.md` | annotated-and-left — investigation Findings landed; execution DEFERRED per user direction (swift-testing shadows Apple Testing) |
| 10 out-of-scope files | out-of-session-scope; not touched |

Summary: 15 scanned, 0 deleted this pass (2 were already deleted by sibling session), 3 annotated-or-touched-this-session, 10 out-of-scope.

No `/audit` invoked this session per [REFL-010]; audit findings untouched.

## What Worked and What Didn't

**Worked**:

- **`/supervise` compression-at-pivot per `[SUPER-015]`**: the architectural-pivot boundary (recipe going from "delete placeholder + transfer" to "rename-and-reconcile") triggered compression exactly as the skill predicts. 6 original rules → 6 compressed rules with #2 and #4 each absorbing a Q-decision via `(merges #N-old, Q-decision)` notation. Compressed rule #2 ("MUST triage per-case, default commit") is *stronger* than the original ("MUST NOT ride-along-push") because the user's live direction supplied a protocol the original rule lacked. Compression-as-strengthening, not just size-management. First empirical worked example of the rule I've participated in.

- **Fresh-session escalation discipline on the premise break**: subordinate halted at pre-execution readiness rather than force-fitting the recipe onto a broken premise. Ground Rule 6 (`ask:` on unexpected state) functioning exactly as designed. Five blockers surfaced with evidence, no silent decisions. The destructive-workstream-escalation memory (saved 2026-04-22) paid off: the subordinate explicitly framed the 3 options with "Remediate-first default per `feedback_destructive_workstream_escalation`; no 'Recommended' label on destructive paths." Self-correcting supervision.

- **Supervisor review caught 2 Criticals that three same-day plan revisions missed**: reviewer-trace-recipe against edge cases found the `git checkout X -- .` deletion gap and the path-dep hazard. Both empirically verifiable. Pattern: authors-encode-mental-model; reviewers-trace-tool-semantics. Tier-2 research per `[RES-020]` benefits from independent reviewer pass distinct from author, even on same-day tight-iteration plans.

- **Coenttb URL-hygiene clean-subset discipline**: read each repo's commits before pushing. Caught `swift-form-coding`'s absolute-path symlink leak and `swift-authenticating`'s source-file ride-along before publishing. Default-to-DEFER when anything below URL-hygiene isn't pure hygiene worked cleanly.

**Didn't work**:

- **Phase II.5 investigation's scope facts were stale at execution time**: "placeholders are ~10-commit scaffolds" was authored without verification and didn't refresh across the week. Per `[META-015]` Findings Verification Sweep, pre-execution scope-fact verification is the gap; v1.2.0 added a Verification Stamp but the 2026-04-22 original didn't.

- **Recipe deletion gap slipped past three same-day revisions**: the `git checkout <ref> -- .` semantic (copies files FROM ref INTO working tree; does NOT delete files present only in HEAD) is a classic git trap. Author-velocity missed it; supervisor trace caught it on first pass. Worth codifying as a recipe-review heuristic.

- **Path-dep hazard is a recurring blind spot across workstreams**: surfaced FIRST this week in the CI migration investigation (swift-ietf/swift-rfc-3986 Linux build failure on `.package(path: "../../swift-primitives/swift-standard-library-extensions")`), then AGAIN in the Phase II.5 Package.swift review (7+ path-deps in `swift-foundations/swift-html-render/Package.swift:66-72`). Same class, different workstream. Ecosystem lacks a codified rule for "when path-deps must be URL-ified before publishing."

- **swift-syndication mystery unresolved**: remote 404 cause unknown. Parked.

## Patterns and Root Causes

**Pattern 1 — Premise-staleness is the dominant multi-day-plan failure mode**. Research documents and investigation plans accrete over days or weeks; scope facts (*"what's at the destination?"*, *"what's in the source's git state?"*, *"how many commits do the placeholders carry?"*) were true when authored but can silently go stale before execution. Plan text reads as authoritative even when its facts don't. `[META-015]` Findings Verification Sweep is the existing corpus-level answer; per-plan, the discipline is "verify scope facts immediately before execution, not at authoring time" — missing as an explicit recipe step. Today's Phase II.5 halt is the empirical argument for codifying pre-execution verification as a first-class step in any transfer/destructive plan. The subagent halting on verification was *the right behavior*; the plan should have invited that verification up front rather than requiring it as ad-hoc pushback.

**Pattern 2 — Path-dep hazard recurs because it's an ecosystem-lifecycle question, not a package-specific fix**. Package.swifts adopt `.package(path: "../../...")` for local monorepo-dev convenience; the form breaks for external consumers on publishing. Surfaced three ways this week alone: CI Linux builds (swift-rfc-3986), Phase II.5 ecosystem siblings (swift-html-render), heritage-transfer recipe review. The fix isn't per-package and isn't reactive — it's an ecosystem rule: *before publishing any package to a public destination, path-deps MUST be URL-ified or the consumer must be co-located with the dep in a monorepo checkout.* Currently handled ad hoc via commit-by-commit reactive fixing. Worth codifying as a Tier-2 research doc + a `sync-path-to-url.sh`-style check.

**Pattern 3 — Compression-at-pivot is a real scaling mechanism for supervisor blocks, not just size management**. `[SUPER-015]` predicts that architectural pivots produce supersession events that merge-and-rewrite rules; today provided the worked example. The compressed rule #2 is stronger than the original because user direction supplied a protocol the original lacked — compression is *constraint strengthening via consolidation*, not just de-duplication. The `(merges #N-old, Q-decision)` notation preserves an audit trail the reader can reconstruct. A future principal reviewing the block can trace the evolution.

**Pattern 4 — Independent reviewer catches what author-velocity missed, even on same-day iterations**. The v1.2.0 plan went through three same-day revisions; none caught the deletion gap or the path-dep hazard. Independent supervisor review found both in ~30 minutes. The pattern is structural, not about competence: fast-iteration authoring is velocity-optimized (keep the model coherent, land the shape); review is verification-optimized (trace the recipe, check edge cases, verify claims against live state). Neither substitutes for the other. `[RES-020]` Tier 2+ research benefits from a reviewer pass distinct from author; the same-day iteration cycle is not a substitute.

**Pattern 5 — Feedback memory from yesterday worked in practice today**. The `feedback_destructive_workstream_escalation` memory (saved 2026-04-22 after the superrepo dismantle's Phase 0.5a escalation) prescribed: *"no 'Recommended' label on destructive paths; include Remediate-first option; default assumption is preserve, not destroy."* Today's Phase II.5 escalation honored the memory verbatim — the fresh session's 3-option presentation explicitly cited the memory and framed Remediate-first as default. Self-correcting supervision via feedback memory closes a loop that yesterday's `/reflections-processing` opened, one day later in practice.

## Action Items

Max 3 per `[REFL-004]`:

1. **[research]** `swift-institute/Research/path-dep-ecosystem-lifecycle.md` (or similar): open a Tier-2 research doc establishing when `.package(path: "../../...")` must be URL-ified in the ecosystem lifecycle, what the pre-publish check looks like, and whether `Scripts/sync-path-to-url.sh` (or a `--check` mode on an existing sync script) is the right enforcement mechanism. Hazard has surfaced in 3 distinct workstreams in the last 7 days.

2. **[research]** `swift-institute/Research/git-history-transfer-patterns.md` — update with corrected rename-and-reconcile recipe. The v1.2.0 plan drafted it but with the deletion gap; the canonical Tier-2 doc on transfer patterns should carry the corrected recipe as rm+checkout primary + plumbing footnote variant, not leave it only in one plan doc. Cite this reflection as provenance for the recipe correction.

3. **[skill]** supervise: add a provenance note to `[SUPER-015]` citing the 2026-04-23 compression-at-pivot event (6 rules → 6 rules with #2 and #4 rewritten via merges-notation absorbing Q1/Q2/Q3 decisions) as the empirical worked example of *"compression as constraint strengthening, not just size management."* The rule itself is correct; an anchored example grounds future invocations.
