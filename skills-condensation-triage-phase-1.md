# Skills Condensation — Phase 1 Triage Queue

> **Status**: RECOMMENDATION
> **Date**: 2026-05-05
> **Phase**: 1 of an ecosystem-wide skills condensation cycle
> **Scope**: Triage of pending reflections in `swift-institute/Research/Reflections/` to destinations (skill update / research topic / package insight / memory candidate / delete / requires user).
> **Successor**: Phase 2 (per-skill condensation per `skill-lifecycle`) is dispatched separately after this phase reports back. Phase 2 takes this queue grouped by target skill and applies condensation per [SKILL-LIFE-*].
> **Provenance**: dispatched via `HANDOFF-skills-corpus-condensation-phase-1.md` (workspace root); follows `reflections-processing/SKILL.md` [REFL-PROC-*] protocol with one explicit override (see Protocol Deviation).

---

## Context

The dispatching brief premise (`HANDOFF-skills-corpus-condensation-phase-1.md`, "## Issue") was that 264 pending reflections had accumulated since the last triage cycle, oldest dated 2026-02-12. The premise was empirically false — a [HANDOFF-013a] writer-side prior-research grep failure on the dispatch side: the count was derived from `ls *.md | wc -l` (total file count = 263, off-by-one rounded to 264), not from `_index.json` filtered by `status == "pending"`. The dispatcher acknowledged the failure mode at the principal/supervisor turn and authorized a re-derived scope: process all actually-pending reflections in a single serial pass.

**Re-derived scope** (verified against `Reflections/_index.json` generatedAt 2026-05-05):

| Status | Count |
|---|---:|
| pending | **21** |
| processed | 241 |
| superseded | 1 |
| **total** | **263** |

The 241 already-processed entries carry concrete `triage_outcomes` in their YAML (verified by sampling `2026-02-12-bit-vector-zeros-…` which records skill_update + no_action + package_insight outcomes from `processed_date: 2026-02-13`); they are not in this queue's scope. Re-triaging them would be a separate cycle (corpus-meta-analysis on the Reflections corpus per [META-019] — explicitly out-of-scope per the original brief's exclusion list).

**The 21 actually-pending** span 2026-04-30 → 2026-05-05 (a 5-day window), all post-dating the most recent triage cycle (`2026-04-30-corpus-meta-analysis-and-phase-11-completion.md` itself, which absorbed Phases 10 + 1a + 5 + 9 + 11 + 12-inline plus its own 17-reflection backlog).

This document IS the triage deliverable; there is no separate "calibration vs parallel" split (the original brief's directive collapsed at N=21 — no parallel pass to authorize after a calibration sample).

---

## Protocol Deviation

Per [HANDOFF-037] (probe-list vs Do-Not-Touch internal contradiction surfacing) and the supervisor's authorization on this dispatch, this triage **deviates from [REFL-PROC-002] step 4 ("Mark the entry as processed (update YAML: `status: processed`, add `processed_date` and `triage_outcomes`)")** in the following way:

| Default per [REFL-PROC-002] | This Phase 1 deviation |
|---|---|
| Update each reflection's YAML frontmatter with `status: processed`, `processed_date`, `triage_outcomes` | **Do not** modify reflection YAML frontmatter |
| Mark in `_index.json` to mirror the YAML | Update `_index.json` with an **overlay status field** (`triagedPhase1: true`, `triagedPhase1Date: 2026-05-05`) — leave the per-entry `status` field at `pending` |
| Reflection file is the source-of-truth for triage state | This document IS the source-of-truth for triage state until Phase 2 absorbs each entry |

**Why**: Phase 2 (per-skill condensation) may invalidate individual triage decisions when a reflection turns out to belong to a different destination than triaged here. Unwinding 21 per-file YAML edits is an order of magnitude more expensive than amending one queue document. The phasing exists to keep rollback cheap. Per-reflection YAML updates happen in Phase 2 *after* the destination is verified by absorption (skill-rule landing / research doc creation / package insight write / explicit delete).

**Reflection deletion**: per the brief's binding constraint "MUST NOT delete reflection files in this phase", category (e) entries below are queued for Phase-2-driven deletion *after* their resolved/superseded status is verified against current code or skill state — not deleted in this phase.

---

## Distribution

| Destination | Count | % |
|---|---:|---:|
| (a) skill update | 44 | 74.6% |
| (b) research topic | 8 | 13.6% |
| (c) package insight | 4 | 6.8% |
| (d) memory candidate | 0 | 0% |
| (e) delete (resolved/superseded) | 3 | 5.1% |
| (f) REQUIRES USER (rule refutation / shipped-skill deprecation / published-research supersession) | 0 | 0% |
| **total queue entries** | **59** | |

Source: 21 reflections × 3 action items each (~63 raw) → consolidated and supersession-pruned per [REFL-PROC-002a] / [META-016] to **59 queue entries**.

**Consolidations applied** (2 total):

1. **Cross-platform vocabulary placement (Path X arc)**: `2026-04-30-path-x-completion-cycles-19-23-and-g6.md` AI3 (typealias-via-L3 namespace anchor pattern documentation) + `2026-04-30-path-x-multi-cycle-kernel-primitives-removal.md` AI3 (cross-platform vocabulary L2-vs-L3 placement decision tree) → ONE research topic at `swift-foundations/swift-kernel/Research/cross-platform-vocabulary-placement-decision-tree.md` covering both the decision tree (when L2 vs L3) and the canonical solution form (typealias-via-L3 namespace anchor).
2. **[HANDOFF-016] premise-staleness extension**: `2026-05-05-swift-87136-pr-shipping-and-six-round-adversarial-discussion.md` AI3 ("local-environment claims rot fastest" sub-axis) + `2026-05-05-swift-primitives-scope-finalization-canary-and-frozen.md` AI2 ("verification-command baseline at session start" sub-rule) → ONE skill update extending [HANDOFF-016] with both facets (the verification-command baseline IS the mechanism for catching local-environment-claims rot at resume time).

**Supersessions applied** (3 total):

1. `2026-05-04-per-repo-workflow-drift-rollout-c-d-b8-fnow.md` AI1 (schedule [CI-059]/[CI-060] F-deferred rules once Phase B7 closes) → **superseded** by `2026-05-05-ci-cd-rollout-finalization-and-100-percent-confidence-sweep.md` which records B7 LANDED + F-deferred LANDED in commit `062c17c`. Rules are in the skill; AI is resolved.
2. `2026-05-04-per-repo-workflow-drift-rollout-c-d-b8-fnow.md` AI2 (graph SIGABRT root-cause investigation) → **superseded** by `2026-05-05-swift-primitives-scope-finalization-canary-and-frozen.md` which records BUILD VERIFIED GREEN under sibling-handoff `Vector_Primitives` migration. Crash is no longer reproducing; investigation is moot.
3. `2026-05-01-property-readiness-and-ownership-public-flip.md` AI3 (Transfer.Retained.Outgoing missing deinit + verify same pattern doesn't exist elsewhere) → **resolved**: fix shipped in commit `0d5b399`; reflection itself confirms siblings already verified (Transfer.Value uses Latch's deinit; Transfer.Erased uses explicit destroy). All three category-(e) entries below are queued for Phase-2 deletion only after Phase-2 verifies the resolution against current code.

---

## Queue

### (a) Skill Updates — 44 entries

Grouped by target skill, alphabetical. Each entry: source reflection → target skill / specific rule (if known) → one-line summary.

#### audit (1)

- **`2026-05-05-ci-cd-rollout-finalization-and-100-percent-confidence-sweep.md`** AI2 → audit / new rule → **org-side enumeration discipline**: workspace-mirror fleet ≠ org fleet; completeness sweeps MUST cross-check via `gh repo list <org>` and surface the symmetric difference (unmirrored-but-live; locally-mirrored-but-deleted-from-org). Provenance: 5 superseded-but-live repos found in swift-primitives org during 100%-confidence sweep.

#### ci-cd-workflows (4)

- **`2026-05-04-test-support-spine-strict-rollout-and-mod-024.md`** AI1 → ci-cd-workflows / new rule → **derive package-classification from audit JSON, not hand-curated arrays**: tools that classify packages by capability MUST derive from audit-script JSON output, not from hand-curated priority lists. Provenance: `EXISTING_TS_PRIORITY` 2 false positives → broken anchor refs in 2 downstream packages.
- **`2026-05-04-principal-side-cicd-centralization-supervision.md`** AI1 → ci-cd-workflows / amend [CI-050] or [CI-056] (or new rule) → **empirical canary verification of platform API runtime semantics BEFORE mass rollouts**: GitHub Actions secret-passing, `workflow_call` boundaries, etc. require a single-canary empirical test before fan-out, not docs-reading. Provenance: B7 secrets-inheritance wrong-mental-model near-miss across 132 repos.
- **`2026-05-04-primitives-ci-cd-straggler-cleanup-and-private-repo-creation.md`** AI1 → ci-cd-workflows / [CI-031] extension or new [CI-NNN] → **DocC-catalog → docs-job coupling explicit rule**: a package's `ci.yml` MUST include the docs job (per [DOC-019a]) iff the package contains a `.docc` catalog; coupling is currently implicit precedent.
- **`2026-05-05-ci-cd-rollout-finalization-and-100-percent-confidence-sweep.md`** AI1 → ci-cd-workflows / amend [CI-031] or new cross-cutting note → **shape-uniformity-over-rule-permissiveness**: when a rule's reference shape has multiple variants and consumers split N-1 / 1, the outlier is latent drift; converge to a single canonical shape unless the variant carries a load-bearing distinction. Provenance: carrier-primitives outlier on `secrets:` block.

#### code-surface (1)

- **`2026-05-01-wave-4c-completion-and-finding-6-8-rewire.md`** AI2 → code-surface / new rule → **typed-parameters principle beyond Descriptor**: when a typed L2 form takes `Type1, Type2, Int32` and the Int32 represents a platform-namespaced constant set, the Int32 MUST get a `RawRepresentable<Int32>` typed wrapper mirroring any existing peer (e.g., Option.Name mirrors Option.Level). Provenance: principal mid-flight correction during Wave 4c-Socket Main.

#### experiment-process (2)

- **`2026-04-30-phase-1b-stale-triage-and-deferred-fixed-codification.md`** AI1 → experiment-process / extend [EXP-006c] or new [EXP-006d] → **FIXED-verdict caveat for never-empirically-failed reducers**: when a FIXED verdict applies to a reducer whose pre-history is unverified (e.g., package-config blocked compile so original investigation never produced a verifiable signal), the verdict line MUST include an "investigation never produced a verifiable signal" caveat. Provenance: `bit-packed-crash` reducer's Package.swift was rejected by SwiftPM since tools-version 5.4.
- **`2026-05-04-per-repo-workflow-drift-rollout-c-d-b8-fnow.md`** AI3 → experiment-process / extend [EXP-006b] → **compiler-behavior experiments combine empirical variants + verbatim swiftlang/swift source citations**: when an experiment's hypothesis is about Swift language behavior, strongest evidence form is empirical variants AND verbatim line-citations from `swiftlang/swift` source pinned to a specific commit SHA. Provenance: shorthand-syntax-with-shadowing experiment + KnownStdlibTypes.def:51 citation.

#### github-repository (1)

- **`2026-05-01-property-launch-and-cohort-readme-audience-inversion-sweep.md`** AI1 → github-repository / new rule → **thin-caller schema-validation**: when `Scripts/sync-ci-callers.sh` regenerates callers, validate that each caller's `secrets:` and `with:` blocks are accepted by the centralized workflow's `workflow_call:` declaration. Schema mismatch currently produces `startup_failure` with no diagnostic. Provenance: 2026-05-01 property launch lost ~30 min to silent rejection.

#### handoff (3)

- **`2026-04-30-phase-1b-stale-triage-and-deferred-fixed-codification.md`** AI2 → handoff / extend [HANDOFF-007] → **program-shape vs investigation-shape distinction in token budget**: multi-session program briefs (e.g., Tier 2 skill-corpus-cleanup) structurally exceed the 800-token max because the deliverable scope IS the brief. Either relax the max for program-shape with explicit wave-splitting on dispatch, or require pre-write-time wave-splitting. Both options have trade-offs worth deciding.
- **CONSOLIDATED**: `2026-05-05-swift-87136-pr-shipping-and-six-round-adversarial-discussion.md` AI3 + `2026-05-05-swift-primitives-scope-finalization-canary-and-frozen.md` AI2 → handoff / extend [HANDOFF-016] → **premise-staleness extensions (two facets)**: (a) "local-environment claims rot fastest" sub-axis — directory existence, toolchain installed, build dir state, git status of cited untracked files, run at session-start alongside cited-file-paths verification; (b) "verification-command baseline" sub-rule — when a brief lists a mechanical verification command for a deferred/in-flight item, run it as a baseline check at session start, before accepting the framing. The verification-command baseline IS the mechanism for catching local-environment-claims rot.
- **`2026-05-05-swift-primitives-scope-finalization-canary-and-frozen.md`** AI3 → handoff / extend [HANDOFF-018] → **offered options need trade-off surfacing sub-rule**: when a brief lists an option ("X is an option", "Y or Z"), the implementer SHOULD surface the trade-off the option resolves before applying it mechanically. Provenance: `#if !os(Windows)` drafted before canary trade-off was surfaced for Item 3.

#### implementation (2)

- **`2026-05-02-glob-l1-relocation-and-premise-inversion-research-gate.md`** AI1 → implementation / new guidance line → **BSD sed `\b` doesn't work**: BSD sed (macOS default) does not support `\b` word boundary; use `[^A-Za-z_]` boundary classes or explicit context. Same applies to `sed -E`. Recurs across rename cycles.
- **`2026-05-05-swiftlang-swift-87136-comment-and-pr-prep.md`** AI3 → implementation / new [IMPL-NNN] → **subtractive-first for structural defect fixes**: when fixing a structural defect (stale assertion, dead code, broken invariant), the first-cut MUST be the maximally subtractive option: delete the broken construct and let the surrounding structure carry the rationale via the PR description, not via a replacement code comment. Replacement comments added only if a specific code reader (not a PR reviewer) would be confused without them.

#### issue-investigation (3)

- **`2026-05-01-spm-stall-comprehensive-mirror-mitigation.md`** AI1 → issue-investigation / new rule (complements [ISSUE-013]) → **negative-experimental-conclusion-without-coverage-scope**: when reporting a negative experimental result, the conclusion sentence MUST cite the experiment's coverage scope alongside the result. E.g., "Mirror experiment with swift-syntax mirrored alone (1-of-5 URL deps in closure): did NOT resolve the stall. Comprehensive coverage not tested."
- **`2026-05-05-swiftlang-swift-87136-comment-and-pr-prep.md`** AI2 → issue-investigation / new [ISSUE-NNN] → **mechanical validation via installed dev toolchain**: when local `llvm-lit` cannot run end-to-end (stale build dir, SDK upgrade-induced cmake regenerate failure), mechanical validation recovers ~80% of lit's verification value at ~5% of the cost. Procedure: extract test files via `split-file`; run RUN: line invocations manually against installed dev toolchain.
- **`2026-05-05-swift-primitives-scope-finalization-canary-and-frozen.md`** AI1 → issue-investigation / extend [ISSUE-008] with fifth resolution path → **canary on continue-on-error CI jobs for compile-time bugs with no source-side workaround**: when a compile-time compiler bug's source-side workaround would require unacceptable API change, leave the failing test/code as a canary on `continue-on-error` jobs; document canary semantics in source; track upstream bug. Provenance: swiftlang/swift#87136 + Tagged "Windows test" canary.

#### modularization (3)

- **`2026-04-30-path-x-completion-cycles-19-23-and-g6.md`** AI2 → modularization / new [MOD-NNN] → **namespace-identity unification pattern**: document `ISO_9945.Kernel ≡ Kernel` (typealias) as a cross-platform name resolution mechanism without explicit L3 typealias chains. Provenance: Cycles 19-23 G6 ratified.
- **`2026-05-02-glob-l1-relocation-and-premise-inversion-research-gate.md`** AI2 → modularization / new guidance → **namespace-anchor caveat**: when iterating files of a relocated namespace via shell glob, `X.*.swift` does NOT match `X.swift` (the namespace anchor file). Handle the anchor file explicitly. Verify post-loop with `grep -L new-pattern X*.swift` to catch missed files. Recurs across relocation cycles.
- **`2026-05-04-test-support-spine-strict-rollout-and-mod-024.md`** AI2 → modularization / extend [MOD-024] → **path-fixup note for testTarget name vs directory drift**: SPM auto-detection breaks once `Tests/Support/` co-exists with mismatched-name test directory. Add explicit `path: "Tests/<Actual Dir>"` to testTarget. Provenance: 2 of 48 primitives (format, position).

#### platform (3)

- **`2026-04-30-path-x-completion-cycles-19-23-and-g6.md`** AI1 → platform / new [PLAT-ARCH-NNN] → **L2-platform-extension surface inventory before classifying L3**: before classifying a cross-platform type as L3-placed, grep for `extension Kernel.X` across L2 spec packages. If non-empty, the type must live at L2 (or below) — L2 cannot upward-import L3. Naming this rule prevents the Cycle 23/G6.B mis-placement pattern.
- **`2026-05-01-wave-4c-completion-and-finding-6-8-rewire.md`** AI1 → platform / new rule → **skill-text-precedes-code cross-audit gate**: when a skill revision proposes new architectural shape (composition direction, layer skipping, typealias chain, namespace identity), the revision MUST cross-reference all sibling composition rules ([PLAT-ARCH-008c], [PLAT-ARCH-008e], [PLAT-ARCH-008j]) at edit time and verify the proposed shape doesn't contradict any. Provenance: Prerequisite I → wrong-skill-then-wrong-code at `f703ad3`.
- **`2026-05-02-multi-envelope-execution-research-doc-layering-blindspot-and-empirical-classification-corrections.md`** AI2 → platform / guidance attached to [PLAT-ARCH-008e] → **Class A vs Class B classification is empirical (declaration site), not nominal (usage site or naming intuition)**: future flip-style cycles applying the Wave 3.5-Final-Atomic taxonomy MUST run the "where is this type ACTUALLY declared?" check at pre-flight rather than classifying by intuition.

#### readme (4)

- **`2026-05-01-readme-skill-family-v3-design-and-cleanup.md`** AI1 → readme/ci-automation / extend [README-162] → **count-claim consistency lint**: when an org profile cites "N packages" in 1-liner / opening / footer / catalog, all four must agree on N AND N must equal the actual catalog row count. Provenance: 2026-05-01 swift-foundations 129/130/137 disagreement.
- **`2026-05-01-readme-skill-family-v3-design-and-cleanup.md`** AI2 → readme/SKILL.md / new universal meta-rule → **speculative-family flagging**: families with zero existing instances at design time MUST be flagged "speculative — pending validation" in the changelog AND in the family file's frontmatter, AND the design MUST identify the validation criterion. Family B and Family D would have been flagged on day 1.
- **`2026-05-01-readme-skill-family-v3-design-and-cleanup.md`** AI3 → readme/sub-package / tighten [README-006] → **dep-list-completeness for composition one-liners**: when a Tier 1+ one-liner says "composes A, B, C", the listed names MUST equal the full dep list in `Package.swift` (or be explicitly marked subset with "(among others)"). Catches the swift-geometry-primitives 4-of-7 defect class.
- **`2026-05-01-property-launch-and-cohort-readme-audience-inversion-sweep.md`** AI2 → readme / extend [README-016] → **Installation-snippet pre-tag rule**: `from: "X.Y.Z"` in Package.swift Installation snippets is forbidden when no X.Y.Z tag exists. Pre-tag state requires `branch: "main"` (or equivalent). Provenance: cohort-wide 4-repo `from: "0.1.0"` → `branch: "main"` fix.

#### reflections-processing (1)

- **`2026-04-30-corpus-meta-analysis-and-phase-11-completion.md`** AI1 → reflections-processing / new rule → **pace-gradient + topic-clustering pre-pass discipline for ≥10 entries**: when a `/reflections-processing` invocation has 10+ pending entries, the agent MUST run [REFL-PROC-002a] topic-clustering pre-pass across ALL pending entries upfront — not just within predefined clusters — and identify supersession opportunities before processing entries individually. Provenance: 16-entry batch where pre-pass was applied retroactively at entry 6.

#### release-readiness (2)

- **`2026-05-01-property-launch-and-cohort-readme-audience-inversion-sweep.md`** AI3 → release-readiness / extend Phase 2 audit → **discovery-lens pass per [README-023]**: per-paragraph "cover with your hand — does the reader skip and still decide?" check during Phase 2; per-section "is this evaluator-shaped or author-shaped?" gut-check. Catches cohort-wide audience-inversion class on future cohorts before launch.
- **`2026-05-01-property-readiness-and-ownership-public-flip.md`** AI1 → release-readiness / new post-flip step → **first-public-CI baseline verification**: covers (a) cohort-canonical lint configs (`.swiftlint.yml`, `.swift-format`) match sibling packages — strict-default lint without parent_config produces hundreds of violations; (b) the centralized workflow's continue-on-error matrix — run-level `conclusion` is the gate, not job-level status; reactive source-patching on gated job failures is unnecessary churn.

#### research-process (1)

- **`2026-05-02-multi-envelope-execution-research-doc-layering-blindspot-and-empirical-classification-corrections.md`** AI1 → research-process / new quality gate → **three-axis verification for L1-redesign research-then-dispatch deliverables**: research docs proposing L1 redesigns MUST verify (1) type-system shape, (2) Package.swift import constraints, (3) consumer-cascade impact. Item 1.5 Phase 2 BLOCKER is the canonical failure (research doc structurally invalid at L1 because proposed field types couldn't be imported there).

#### skill-lifecycle (1)

- **`2026-04-30-corpus-meta-analysis-and-phase-11-completion.md`** AI2 → skill-lifecycle / new rule → **post-Edit content verification after substantive edits**: after editing a skill SKILL.md to add or modify a requirement (substantive content edit per [SKILL-LIFE-004]), the writer MUST verify the new content is present via `grep -c '{distinctive-marker}' {file}` before committing. Edit-tool success messages do not guarantee the edit was applied. Cross-references [REFL-006] re-verify-after-edit (this is the per-edit instance).

#### supervise (7)

- **`2026-04-30-path-x-multi-cycle-kernel-primitives-removal.md`** AI1 → supervise / new rule → **precondition check before "Cycle X precedent applies" reasoning**: before authorizing an L3 destination based on a prior cycle's L3-success, audit the L2 platform-extension surface of the candidate type — if multiple platform L2 packages have pre-existing extensions binding to the type, document the precondition mismatch and either include the L2 cascade refactor in scope explicitly, or recommend a different placement honoring the L2 binding.
- **`2026-04-30-path-x-multi-cycle-kernel-primitives-removal.md`** AI2 → supervise / [SUPER-002] amendment → **forbidden implicit guardrails**: ground-rules blocks per [SUPER-002] MUST NOT add `MUST NOT push` / `MUST NOT publish` / `MUST NOT modify CI` entries unless the user explicitly requested the constraint OR a load-bearing ecosystem rule covers it. Default for pre-release private repos is push-as-you-go; supervisor extrapolation beyond user direction creates accumulating batches that need explicit unblocking turns.
- **`2026-05-01-link-check-orchestrator-and-mentor-question-execution-drift.md`** AI1 → supervise / new rule → **auto-mode is meta-permission about cadence, not authorization**: auto-mode is meta-permission about cadence, not authorization for new architectural decisions or cross-repo writes. Mentor-perspective questions ("is X advisable?", "does Y matter?") remain strategy questions whose answer is analysis, not action. Authorization requires explicit user imperatives.
- **`2026-05-02-supervisor-multi-envelope-parallel-dispatch-and-verification-rhythm.md`** AI1 → supervise / extend [SUPER-009] → **empirical-verification rhythm with two extensions**: (a) warning classification — `swift build` warnings indicating incorrect runtime behavior (`infinite recursion`, `will be deinitialized immediately`, `unreachable code`) MUST be treated as defects, not noise; (b) pre-dispatch experiment + research consultation — before dispatching any cycle that touches an established architectural pattern (L2/L3 layering, cross-platform composition, ownership semantics), supervisor MUST grep `swift-institute/Research/` + `swift-institute/Experiments/_index.json` for related work. Provenance: ~10 cycles reported "GREEN" with 16 self-recursing method bodies + L3-policy-layering investigation completed BEFORE this session, not consulted.
- **`2026-05-02-supervisor-multi-envelope-parallel-dispatch-and-verification-rhythm.md`** AI2 → supervise / new rule → **premise-inversion handling protocol (reframe-not-defend)**: when subordinate pre-flight surfaces a stale-framing dispatch, supervisor MUST reframe without defending the original framing, document the reframe in research/audit doc as load-bearing artifact, then re-dispose. Item 1.5 + Item 3.5 both executed correctly; codify the discipline.
- **`2026-05-02-supervisor-multi-envelope-parallel-dispatch-and-verification-rhythm.md`** AI3 → supervise / new rule → **edit-zone non-overlap discipline for N>1 parallel dispatch**: each dispatch's MUST NOT clauses MUST enumerate all other in-flight dispatches' edit zones; subordinates MUST self-classify cross-package diffs as "other subordinate's work" before triggering ground-rule violation. Provenance: N=2 across ~10 cycle-equivalents with zero edit-zone collisions.
- **`2026-05-04-principal-side-cicd-centralization-supervision.md`** AI3 → supervise (or handoff) / new rule → **explicit-scope expression in shared-infra authorizations**: when authorizing a mass operation on shared infrastructure, name orgs/repos explicitly that ARE in scope, AND name orgs/repos explicitly that are OUT of scope. Implicit-count phrasing ("all 132 consumers") leaks mental scope into the executable plan. Provenance: B5 sibling-org callers near-miss.

#### swift-forums-review (1)

- **`2026-05-01-property-readiness-and-ownership-public-flip.md`** AI2 → swift-forums-review / new post-triage step → **post-triage critical re-assessment**: after [FREVIEW-018] anchor verification, ask of each load-bearing critique: "does the prescribed fix translate cleanly?" Specific shapes to catch: (i) prescription conflicts with the type's stated purpose; (ii) prescription conflicts with existing-ecosystem namespaces; (iii) prescription creates new API consistency problems. 2026-05-01 ownership pass downgraded 6 of 11 critiques on this second pass.

#### swift-institute (1)

- **`2026-05-01-link-check-orchestrator-and-mentor-question-execution-drift.md`** AI2 → swift-institute / new rule (could route to ci-cd-workflows if better fit) → **pre-proposal infrastructure audit before CI/automation architecture**: grep `swift-institute/.github/.github/workflows/` for existing reusable workflows, `Scripts/` for existing sync-* propagation scripts, and `secrets` references for existing bot-app patterns before proposing CI/automation architecture. Three architectural proposals were made in one session before the right shape (mirror `sync-metadata-nightly.yml`) was identified — visible in the existing workspace from the start.

#### swift-pull-request (3)

- **`2026-05-05-swift-87136-pr-shipping-and-six-round-adversarial-discussion.md`** AI1 → swift-pull-request / new note → **HEREDOC body-escaping for `gh pr create --body`**: single-quoted heredoc (`<<'EOF'`) preserves all characters literally, INCLUDING backslashes; backtick escaping in `<<'EOF'` produces literal `\`...\`` in the output. Provide a working template with unescaped backticks as the canonical form.
- **`2026-05-05-swift-87136-pr-shipping-and-six-round-adversarial-discussion.md`** AI2 → swift-pull-request / new rule → **enumerative non-regression evidence for pure-deletion PRs**: when a deletion's reachability is bounded by a feature flag (e.g., `InternalImportsByDefault`), grep the test suite for the flag in combination with the affected code path. If no existing test triggers the combination, the deletion is non-regressing by construction — strictly stronger than sample-of-one local test run, and cheaper. Procedure: enumerate via grep before falling back to test-running.
- **`2026-05-05-swiftlang-swift-87136-comment-and-pr-prep.md`** AI1 → swift-pull-request / new [SWIFT-PR-NNN] → **PR Body Claim Audit**: every claim in a PR body MUST cite a specific file:line, commit SHA, or empirical observation. Temporal markers ("predates", "no longer", "always since"), causal markers ("because", "due to"), and quantifier markers ("always", "never", "every") require explicit evidence. Provenance: "predates IIBD (SE-0409)" v1 walkback (assertion added Feb 2024; SE-0409 accepted late 2023; the temporal claim was wrong-by-direction).

---

### (b) Research Topics — 8 entries

- **`2026-04-30-corpus-meta-analysis-and-phase-11-completion.md`** AI3 → `swift-institute/Research/corpus-drift-taxonomy.md` (Tier 2, NEW) → enumerate distinct corpus-drift modes observed (index-vs-disk drift, YAML-vs-index status drift, layer-level container violations, format-version drift, forbidden subdirectory leftovers, ID-uniqueness violations) organized by drift class with per-class detection mechanism, mapped to existing [META-*] phases.
- **CONSOLIDATED**: `2026-04-30-path-x-completion-cycles-19-23-and-g6.md` AI3 + `2026-04-30-path-x-multi-cycle-kernel-primitives-removal.md` AI3 → `swift-foundations/swift-kernel/Research/cross-platform-vocabulary-placement-decision-tree.md` (Tier 2, NEW) → covers (i) decision tree for L2-vs-L3 placement (L2 platform-extension surface inventory as load-bearing precondition; reference cases Cycle 23 Completion / Cycle 22 Terminal / G6.B Event / G6.C Wakeup) AND (ii) the typealias-via-L3 namespace anchor pattern as terminal form citing G6.D as reference implementation.
- **`2026-05-01-wave-4c-completion-and-finding-6-8-rewire.md`** AI3 → ecosystem-wide (destination TBD; likely `swift-institute/Research/`) (Tier 2, NEW) → **post-Path-X test namespace drift survey**: 107 test files at swift-iso-9945 alone use `Kernel.X` (L3-unifier) where `ISO_9945.Kernel.X` (L2 spec) is required; survey grep across all `Tests/` directories to inventory remaining cleanup scope.
- **`2026-05-01-spm-stall-comprehensive-mirror-mitigation.md`** AI2 → `swift-institute/Research/` (Tier 2 or Tier 3, NEW) → **when to ship workspace-side mitigation vs file upstream SwiftPM/compiler bug**: the SPM-stall is real upstream and worth filing eventually, but the structural mitigation closes the immediate need; timing/justification of upstream filing in this class of case is non-obvious.
- **`2026-05-02-glob-l1-relocation-and-premise-inversion-research-gate.md`** AI3 → `swift-institute/Research/` or per-package (Tier 1 or 2, NEW) → **cross-platform package-dependency audit**: grep `swift-microsoft/*/Package.swift` and `swift-windows*/Package.swift` for `swift-iso-*` / `swift-posix*` deps; each is a candidate for the same Item 3.5 pattern (Windows-side package depending on POSIX-named package for platform-agnostic vocabulary).
- **`2026-05-02-multi-envelope-execution-research-doc-layering-blindspot-and-empirical-classification-corrections.md`** AI3 → `swift-institute/Research/` (Tier 2, NEW) → **Sendable absorption pattern generalization**: when a parent type is `@unchecked Sendable` for distinct safety reasons, child types held inside it can drop `Sendable` without observable safety change. Investigate ecosystem for other instances (witness-closure types, ~Copyable wrappers held inside @unchecked Sendable parents). Item 1.5 Path δ may be the first deliberate application.
- **`2026-05-04-test-support-spine-strict-rollout-and-mod-024.md`** AI3 → `swift-institute/Research/` (Tier 2, NEW) → **ecosystem build-health snapshot**: `swift-array-primitives` main module rot (`~Copyable` errors) blocks `swift-cache-primitives` + `swift-parser-primitives` test builds; `swift-symmetry-primitives` test target type-inference timeouts. Survey rest of swift-primitives for similar latent rot, sequence the fix-list, inform Phase 2b/c/d ordering.
- **`2026-05-04-principal-side-cicd-centralization-supervision.md`** AI2 → per-package or `swift-institute/Research/` (Tier 1, NEW) → **standalone Swift Format silent no-op root-cause investigation**: pre-rollout standalone reusable was 0.235s no-op on at least property-primitives (CI step listed, status SUCCESS, files unmodified). Needs minimal-reproducer + diagnosis BEFORE the deferred B5 deletes the broken pattern.
- **`2026-05-05-ci-cd-rollout-finalization-and-100-percent-confidence-sweep.md`** AI3 → `swift-institute/Research/` (Tier 1, NEW) → **background-subagent vs in-shell run_in_background characterization**: characterize when subagent dispatch fails (the "Monitor armed" pattern) and when in-shell scripts are strictly safer. Reproduce the failure with controlled prompt, measure goal-interpretation drift, produce guidance per task class.

---

### (c) Package Insights — 4 entries

- **`2026-04-30-phase-1b-stale-triage-and-deferred-fixed-codification.md`** AI3 → `swift-tagged-primitives/Research/_Package-Insights.md` (CREATE if absent) → parallel-session `/tmp/reval-results.txt` flagged 3 `UNEXPECTED_PASS` revalidations on Swift 6.3.1 — `tagged-literal-consumer-opt-in`, `tagged-literal-footgun-6-3-revalidation`, `tagged-literal-safe-marker`. All "expected failure but run clean" — likely additional silent FIXED verdicts in the same class as `bit-packed-crash` + `equatable-crash`. Worth a follow-up cycle to confirm fix scope and update `swift-6.3-fix-status.md`.
- **`2026-05-01-link-check-orchestrator-and-mentor-question-execution-drift.md`** AI3 → `swift-institute/.github/Research/_Package-Insights.md` (CREATE if absent) → link-check.yml needs **close-on-clean logic**: when a target repo had a previously-open `Link Check Report` issue and the current scan returns clean, post a comment ("Resolved by re-scan on YYYY-MM-DD") and close the issue. Today required two manual closes; future maintainers shouldn't.
- **`2026-05-01-spm-stall-comprehensive-mirror-mitigation.md`** AI3 → `coenttb/swift-package-mirrors/Research/_Package-Insights.md` (CREATE if absent; private repo) → **maintenance protocol for new URL deps**: when a new URL dep appears in our workspace closure, the mirror map needs a new entry. Probably a CI step or doc note in the repo's README; current `Scripts/verify.sh` only checks existing mappings, not coverage of new URLs.
- **`2026-05-04-primitives-ci-cd-straggler-cleanup-and-private-repo-creation.md`** AI2 → `swift-glob-primitives/Research/_Package-Insights.md` (CREATE if absent) → **DocC catalog adoption checklist**: when a `.docc` catalog is later added to swift-glob-primitives, the docs job MUST be added to `.github/workflows/ci.yml` per [DOC-019a]. Current `ci.yml` is ci-only because no catalog exists yet.

---

### (d) Memory Candidates — 0 entries

(none)

Per the auto-memory rules in CLAUDE.md, memory is reserved for user/feedback/project/reference items not derivable from code or git. None of the 21 reflections' action items meet this bar — they are all skill rules, research topics, or package insights. The reflections themselves remain in `Research/Reflections/` as durable provenance artifacts.

---

### (e) Delete (Resolved/Superseded) — 3 entries

These action items are resolved by subsequent sessions or by code changes that landed before triage. Phase 2 verifies the resolution against current code before applying any delete.

- **`2026-05-01-property-readiness-and-ownership-public-flip.md`** AI3 → **RESOLVED** in commit `0d5b399` (Transfer.Retained.Outgoing missing abandoned-path deinit fix shipped + regression test); reflection itself confirms siblings already verified (Transfer.Value uses Latch's deinit; Transfer.Erased uses explicit destroy; only Retained had the gap). No remaining action.
- **`2026-05-04-per-repo-workflow-drift-rollout-c-d-b8-fnow.md`** AI1 → **SUPERSEDED** by `2026-05-05-ci-cd-rollout-finalization-and-100-percent-confidence-sweep.md`: F-deferred rules [CI-059] (`secrets: inherit` consumer pattern) + [CI-060] (org-level `PRIVATE_REPO_TOKEN`) LANDED in commit `062c17c`. AI condition ("schedule … once Phase B7 closes") is satisfied; rules are in the skill.
- **`2026-05-04-per-repo-workflow-drift-rollout-c-d-b8-fnow.md`** AI2 → **SUPERSEDED** by `2026-05-05-swift-primitives-scope-finalization-canary-and-frozen.md`: graph SIGABRT recorded BUILD VERIFIED GREEN under sibling-handoff `Vector_Primitives` migration (Graph.Sequential.nodes shifted from `some Swift.Sequence<Node<Tag>>` to concrete `Vector_Primitives.Vector<Node<Tag>>`). The migration is structurally correct and sidesteps the Swift 6.3.1 `PerformanceSILLinker` SIL-deserialization mismatch. Crash is no longer reproducing; investigation moot. (Note: the upstream Swift 6.3.1 `PerformanceSILLinker` issue may still warrant a separate filing — that's a different action and would surface as a (b) research topic if pursued, not as a continuation of this AI.)

---

### (f) REQUIRES USER — 0 entries

No reflection encodes a rule REFUTATION (proposes that an existing skill rule is wrong, replace it), shipped-skill DEPRECATION (delete an active skill), or PUBLISHED-RESEARCH SUPERSESSION (replace a published research doc) per the supervisor block's class-c definition. Two items are worth Phase-2 author awareness but did not meet the escalation threshold:

1. `2026-04-30-path-x-multi-cycle-kernel-primitives-removal.md` AI2 (supervise: forbidden implicit push-restriction guardrails) narrows the supervisor's authoring envelope and touches the high-stakes user-discretion area (no push without YES). It's classified (a) skill update because it's an extension to [SUPER-002], not a refutation; Phase 2 can re-classify if the rule's framing turns out to conflict with `feedback_no_public_or_tag_without_explicit_yes.md` semantics.
2. `2026-05-05-ci-cd-rollout-finalization-and-100-percent-confidence-sweep.md` AI1 (ci-cd-workflows: shape-uniformity-over-rule-permissiveness) effectively retires the two-shape variant of [CI-031]; the retirement was already DONE in this session's commit `7f30140`. The action item now reads as "codify the retirement as a cross-cutting note" — clarification, not refutation. Phase 2 can verify that [CI-031]'s amendment captures the discipline.

---

## Deferred — Out-of-Index

One reflection on disk is **not** in `Reflections/_index.json` and was deliberately excluded from this triage cycle. Recording the deferral so the audit trail shows it was a decision, not an oversight.

- **File**: `Reflections/2026-05-04-centralized-ci-research-collaborative-discussion-and-v1.2.0-correction.md`
- **Self-flag (verbatim from the reflection's YAML frontmatter)**:
  ```yaml
  index_pending: true   # Reflections/_index.json is on the parent investigation handoff's
                       # "Do Not Touch" list (uncommitted parent-session reflections;
                       # principal will commit separately). Index entry for this file
                       # deferred to the principal's commit cycle. Per [REFL-007]'s MUST,
                       # updated outside this session.
  ```
- **Reason**: the reflection's authoring agent explicitly deferred index-entry creation to a parent session that holds authority over its own commit boundary (the `HANDOFF-centralized-swift-ci-research.md` arc, which also has uncommitted `Research/_index.json` modifications and an untracked top-level research doc body — all parent-session WIP).
- **Decision**: **Acknowledged by supervisor (parent of this dispatch); deferral honored.** The Phase 1 cycle does not (a) classify this reflection's action items, (b) modify `Reflections/_index.json` for it, or (c) modify any of the parent session's WIP artifacts. The 22nd reflection will enter triage when its authoring parent commits its index entry; a Phase-1-supplement or the next routine `/reflections-processing` invocation will pick it up.
- **Why this matters as policy**: respecting the `index_pending: true` convention preserves its meaning for future cross-session deferrals. Routine override would erode the signal.

---

## Phase 2 Dispatch Notes

For the principal/agent dispatching Phase 2 (per-skill condensation per `skill-lifecycle`):

- **Group by target skill, not by source reflection.** The (a) section is already organized this way. supervise has the largest cluster (7 entries) and is the natural first dispatch unit — it covers premise-inversion handling, parallel-dispatch coordination, auto-mode authorization, scope-expression discipline, and verification rhythm. Land them as one cohesive amendment cycle to preserve cross-rule consistency.
- **Single-skill clusters with internal dependencies**: handoff (3 entries; the consolidated [HANDOFF-016] entry depends on no other rule); readme (4 entries; all extend existing rules); ci-cd-workflows (4 entries; one of them is "shape-uniformity" which is already partly DONE per #21).
- **Pre-commit ID-uniqueness scan per [REFL-PROC-016] is mandatory** when this many new requirement IDs land. Estimated ~50 new IDs across ~17 skills; the `grep | sort | uniq -d` scan must run on each skill's file set before the commit lands.
- **Topic-cluster pre-pass per [REFL-PROC-002a] was applied**: the 21-reflection set was small enough that no within-set supersession occurred during Phase 1 triage. Phase 2 should still run the pre-pass per skill to catch within-skill rule-rule consistency issues (especially in supervise where 7 rules land together).
- **Generalization requirement per [REFL-PROC-005a]**: each Phase 2 skill rule MUST be generalized — origin incident as one example, not the rule's definition. The summaries in this queue are scoped to the origin incident; Phase 2 must elevate them to general principles.
- **Verification per [META-015]**: before integrating each rule, verify the reflection's claim is still accurate against current code state. Several reflections reference state that has since evolved (e.g., the Path X cycles' workspace state changed across the 5-day window).
- **Deletion timing**: (e) entries are queued for Phase 2 deletion AFTER the resolution is verified against current code/skill state. Do not delete in Phase 1.

---

## Index Update

Per the Protocol Deviation, `swift-institute/Research/Reflections/_index.json` is updated with an overlay status field on each of the 21 entries:

- `triagedPhase1: true`
- `triagedPhase1Date: "2026-05-05"`
- `triagedPhase1Doc: "Research/skills-condensation-triage-phase-1.md"`

Per-entry `status` field remains `pending` until Phase 2 absorbs each entry. After Phase 2 verifies the destination, the per-entry YAML and the per-entry `status` field both flip to `processed` (or, for category-(e) entries, the file is deleted and the index entry's status flips to `superseded` with `supersededBy` citing the absorbing artifact).

---

## Cross-References

- `swift-institute/Skills/reflections-processing/SKILL.md` [REFL-PROC-*] (governing protocol; this triage applied [REFL-PROC-002a] pre-pass and [REFL-PROC-016] pre-commit ID-uniqueness scan deferred to Phase 2)
- `swift-institute/Skills/skill-lifecycle/SKILL.md` [SKILL-LIFE-*] (Phase 2 governing skill)
- `swift-institute/Skills/corpus-meta-analysis/SKILL.md` [META-*] ([META-016] consolidation applied; [META-019] full corpus sweep is out-of-scope per dispatching brief)
- `swift-institute/Skills/handoff/SKILL.md` [HANDOFF-013a], [HANDOFF-016], [HANDOFF-037] (premise-staleness diagnosis, Protocol Deviation rationale)
- `swift-institute/Skills/supervise/SKILL.md` [SUPER-014a] (in-absentia interaction model; principal/supervisor was live throughout, so degenerate case did not apply)
- `HANDOFF-skills-corpus-condensation-phase-1.md` (workspace root; the dispatching brief)
