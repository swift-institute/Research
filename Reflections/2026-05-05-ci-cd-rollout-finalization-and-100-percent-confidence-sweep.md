---
date: 2026-05-05
session_objective: Finalize swift-primitives centralized CI/CD rollout (Phase B7 + F-deferred + Phase G), then sweep for 100% completeness across all rollout dimensions
packages:
  - swift-primitives
  - swift-institute
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: NoAction shape-uniformity-over-rule-permissiveness principle already implicit in [CI-031] Per-Package ci.yml + [CI-091] Uniform-Platform-Matrix Doctrine. NoAction org-side enumeration discipline candidate for audit skill but narrow scope. Background-subagent vs in-shell research deferred meta-investigation.
---

# CI/CD Rollout Finalization and 100% Confidence Sweep

## What Happened

Resumed the per-repo-workflow-drift rollout from `HANDOFF-eliminate-per-repo-workflow-drift.md`. Sequence:

1. **Required Workflows audit** (subagent): verdict NOT viable — two independent blockers (org-level rulesets gated to GitHub Team/Enterprise on Free plan; trigger support is `pull_request`/`merge_group` only, no `push`/`workflow_dispatch`). Per-repo `ci.yml` is the architecture's floor.
2. **Phase B7 execution**: B7b canary on `swift-witness-primitives` (`60ec221`); B7c mass-fanout to 130 consumers (128 in main pass + 2 dirty-skipped recovered with explicit per-file staging); B7d verification on `swift-property-primitives` (run 25340641989, 8/8 GREEN).
3. **F-deferred**: added [CI-059] `secrets: inherit` + [CI-060] org-level `PRIVATE_REPO_TOKEN` + free-plan visibility alignment in `swift-institute/Skills/ci-cd-workflows/SKILL.md` (`062c17c`).
4. **Phase G**: deleted `HANDOFF-eliminate-per-repo-workflow-drift.md`; spot-checked 3 consumers.
5. **Carrier uniformity** (supervisor flag): added `secrets: inherit` to `swift-carrier-primitives` (`928ab6c`); amended [CI-031] to drop the two-shape distinction; updated [CI-058]/[CI-059] cross-references (`7f30140`).
6. **graph-primitives R-chain catch-up** (`4875758`): flipped `.swift-format` UseShorthandTypeNames to false; restored 3 `Array<Payload>` lines in `Builder.swift` that the format pass had mechanically rewritten to `[Payload]`. Debug build now clean.
7. **graph-primitives SIGABRT investigation**: workarounds attempted (drop `@inlinable`; add `@_optimize(none)`) — both reverted at user pushback. Wrote `HANDOFF-graph-primitives-sigabrt-earlyperf-inliner.md` to dispatch separately.
8. **Ecosystem-wide UseShorthandTypeNames sweep**: 132/132 consumer .swift-format files at `false`; 1 outlier (workspace-mirror-root `swift-primitives/.swift-format`) flipped local-only.
9. **Org-side cleanup**: archived 5 superseded repos (posix, pointer, kernel, bound, deque); orphan-backup-pre-fork deleted by user (token scope blocked agent-side delete).
10. **100% completeness verification**: foreground sweep across 8 ci.yml-content invariants (132/132 ✓), 6 per-package config files (131/132 — gap surfaced: `swift-complex-primitives` missing metadata.yaml), git state (2 dirty, 0 unpushed). Backfilled complex's metadata.yaml (`f24f607`).
11. **Build sweep at scale**: dispatched 132-package serial debug-build sweep. First attempt via background subagent reported "Monitor armed" + early termination instead of executing the work; fell back to in-shell `Bash` with `run_in_background=true`. 56 minutes serial; **131/132 GREEN, 1 FAIL** (`swift-parser-machine-primitives` Tagged `.rawValue` API drift on lines 198 + 229 — confirmed pre-existing at HEAD~5).
12. **Save-progress** (`/quick-commit-and-push-all`): 9 commits, 8 push-only flushes (graph-primitives' parallel-session workaround captured among them).
13. **Finalization handoff** (`/handoff investigate ...`): wrote `HANDOFF-swift-primitives-scope-finalization.md` covering 4 remaining within-scope issues (graph SIGABRT in flight + parser-machine .rawValue + tagged Windows test + ownership Embedded build).

**HANDOFF scan** (per [REFL-009]):
- `HANDOFF-eliminate-per-repo-workflow-drift.md` — **deleted** (Phase G of own rollout, all Next Steps verified complete).
- `HANDOFF-graph-primitives-sigabrt-earlyperf-inliner.md` — **annotated-and-left** (in-flight via parallel /issue-investigation session; per [REFL-009a] in-flight conservativism wins over annotation).
- `HANDOFF-swift-primitives-scope-finalization.md` — **annotated-and-left** (just authored, no work yet).
- ~12 other `HANDOFF-*.md` at workspace root — **out-of-session-scope** per bounded-cleanup-authority; not touched by this session.

## What Worked and What Didn't

**Worked**:
- The audit-first → execute-with-knowledge sequencing. The Required Workflows audit collapsed the "should we eliminate ci.yml?" question definitively before B7c fired, preventing a wasted day of investigating an architecturally non-viable path.
- Single-pass content-uniformity sweep across 132 consumers (8 invariants in one Bash block) — high signal, sub-second cost. The "must appear" + "must not appear" pair is symmetric and catches both regression and incomplete-rollout failures.
- Parallel design at scale: cheap text checks in foreground while slow build sweep runs in background. Human-time-efficient.
- Org-side enumeration via `gh repo list` caught 5 superseded-but-live repos that were invisible to the on-disk fleet sweep. The on-disk fleet was 132; the org had 152 total (132 active + 11 already archived + 5 superseded-live + 4 deletable/non-consumers).

**Didn't work**:
- First workaround attempt for graph SIGABRT (drop `@inlinable` + add `@_optimize(none)`) — neither suppressed the EarlyPerfInliner mangler trip; the crash just moved from line 28 to line 88. User pushback ("I'm not sure that's correct") was right; both were reverted. The pattern is structural to the function's type signature, not the per-definition optimizer attribute.
- Background subagent for build verification: the dispatched agent reported "Monitor armed" + early termination after ~57s instead of running 132 sequential builds (~56 minutes). The natural-language brief was clear but interpreted as setup-monitoring rather than execute. Fallback to `Bash run_in_background` worked perfectly — same script, just no agent layer.
- My initial defense of carrier-as-no-secrets-block under the "minimum-floor" reading of [CI-031]. The supervisor flagged it as latent inconsistency; the user agreed with the supervisor's framing. I had to update both the consumer (carrier `928ab6c`) AND the rule ([CI-031] amendment dropping the two-shape distinction), plus adjacent rules ([CI-058], [CI-059]). The original rule's "two-shape pattern" was technically permissive but practically a drift incubator.

## Patterns and Root Causes

**Shape uniformity vs rule-permissiveness**. The [CI-031] reference shape originally distinguished "consumer with no private deps" (no `secrets:` block) from "consumer with private deps" (`secrets: inherit`). This was technically correct per the rule but practically created a 131+1 split where carrier-primitives drifted from 131 siblings — invisibly, until the supervisor framed it as defect. The general pattern: when N-1 of N items match shape A and 1 outlier matches an adjacent shape B that the rule explicitly permits, the outlier is latent drift even though rule-compliant. The rule should converge to a single canonical shape; permissive variants accumulate maintenance overhead disproportionate to their use. This generalizes across config files, code patterns, and architectural commitments. Related: [HANDOFF-018] reads opt-out clauses as preferences rather than permissions; this is the symmetric writer-side reading of rule-internal variants.

**Workspace-mirror enumeration is incomplete by construction**. The on-disk fleet (132 packages) is a SUBSET of the org's repo list (152 total). The 5 superseded-but-live repos that surfaced (`swift-bound`, `swift-deque`, `swift-kernel`, `swift-pointer`, `swift-posix-primitives`) carried pre-centralization or centralization-era workflow shapes — completely invisible to local-only sweeps. The 100%-confidence sweep only became truly 100% after also enumerating the org. Discipline: workspace-completeness audits MUST cross-check against the org's repo list (`gh repo list <org> --json name,isArchived,visibility,pushedAt`) and identify the symmetric difference. Per [HANDOFF-016]'s aggregated-count-with-embedded-property locus: the count of in-scope items depends on a property (mirrored vs unmirrored) that's invisible to in-workspace queries.

**Background-subagent vs in-shell run_in_background failure-mode asymmetry**. Both produce backgrounded execution from the agent's perspective. The subagent path failed for execution-heavy multi-step work (132 serial builds): it interpreted "dispatch this work" as "set up monitoring" and exited after ~57s with a confused "Monitor armed" message. The in-shell path (the same logic written as a Bash script with `run_in_background=true`) worked end-to-end. Hypothesis: subagents have richer goal-shape interpretation that can mis-route execution-heavy + monitoring-heavy task descriptions; in-shell scripts are unambiguous because they ARE the work, not a description of it. For execution-heavy serial sweeps, prefer the in-shell path; reserve subagents for genuinely cognitive subtasks (research, analysis, multi-step decisions).

## Action Items

- [ ] **[skill]** ci-cd-workflows: hoist the shape-uniformity-over-rule-permissiveness principle as a cross-cutting note in [CI-031] (or a new rule) — the carrier outlier was technically rule-compliant but practically drift; the post-amendment single-shape pattern is the durable fix. The general principle: when a rule's reference shape has multiple variants and the consumer fleet splits N-1 / 1 across them, the outlier is latent drift; converge the rule to a single shape unless the variant carries a load-bearing distinction.
- [ ] **[skill]** audit: add an org-side enumeration discipline rule for completeness sweeps — workspace-mirror fleet ≠ org fleet in general; cross-check via `gh repo list <org>` and surface the symmetric difference (unmirrored-but-live repos in the org, locally-mirrored-but-deleted-from-org). The 5 superseded-live findings would have been silent without this check.
- [ ] **[research]** Background-subagent vs in-shell `run_in_background` for execution-heavy serial sweeps — characterize when subagent dispatch fails (the "Monitor armed" pattern observed today) and when in-shell scripts are strictly safer. Reproduce the failure with a controlled prompt + measure the goal-interpretation drift; produce guidance on which path to choose for which task class.
