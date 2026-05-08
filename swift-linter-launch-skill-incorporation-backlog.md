---
date: 2026-05-08
status: PLAN
tier: 2
scope: cross-cohort
---

# swift-linter-Launch Skill-Incorporation Backlog

## Issue

`swift-linter` is the **pilot launch** in the swift-linter 5-package
release cohort (swift-linter → swift-linter-rules → swift-manifests →
swift-manifest-primitives → swift-linter-primitives). Per [RELEASE-003],
the pilot's launch arc IS the learning event: lessons feed back into the
skills system before subsequent tags so the next four packages' audits
run against an updated rule set.

This document inventories the skill / convention / research follow-ups
whose **provenance is the swift-linter cohort work** (pre-publishable
discovery, /reflections-processing 2026-05-07 cohort, independent audit
synthesis 2026-05-07, X1 bundled pre-publishable polish wave 2026-05-08,
release-readiness brief 2026-05-08). It is the canonical source the
swift-linter Phase 4 gate references at
`swift-foundations/swift-linter/AUDIT-0.1.0-release-readiness.md`.

Scope filter: items whose root reflection is one of —

- `Reflections/2026-05-06-swift-linter-ai-harness-mission-staging.md`
- `Reflections/2026-05-07-d1-readme-and-driver-repair.md`
- `Reflections/2026-05-07-d4-linter-rules-predicate-narrowing-and-readme-repair.md`
- `Reflections/2026-05-07-d7-path-filter-runtime-enforcement.md`
- `Reflections/2026-05-07-d7p-typed-throughout-correction.md`
- `Reflections/2026-05-07-dep-pass-audit-and-cleanup-execution.md`
- `Reflections/2026-05-07-lint-manifest-drop-and-array-builder-inference.md`
- `Reflections/2026-05-07-pre-publishable-polish-stream-2.md`
- `Reflections/2026-05-07-result-builder-map-anomaly-refuted.md`
- `Reflections/2026-05-07-stdlib-map-actor-isolation-investigation.md`
- `Reflections/2026-05-07-supervisor-seat-swift-linter-cohort-orchestration.md`
- `Reflections/2026-05-07-swift-linter-architecture-cohort-execution.md`
- `Reflections/2026-05-07-swift-linter-code-surface-cleanup-cohort-and-mirror-config-unblock.md`
- `Reflections/2026-05-07-swift-linter-modularization-cohort-completion.md`
- `Reflections/2026-05-07-swift-linter-pre-publishable-discovery-investigation.md`
- `Reflections/2026-05-07-tagged-primitives-lint-workflow-removal.md`

Plus three audit-derived sources:

- `swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md` (f841ff5)
- `HANDOFF-x1-pre-publishable-polish-wave.md` `## Implementation Notes`
- `swift-foundations/swift-linter/AUDIT-0.1.0-release-readiness.md` (Phase 0–3)

## Tiers

- **Tier 1** — Direct skill amendments. Block downstream package tags
  in this cohort; the swift-linter-rules / swift-manifests /
  swift-manifest-primitives / swift-linter-primitives audits will
  reference these rule IDs.
- **Tier 2** — Process / craft skill improvements (handoff, supervise,
  reflections-processing, audit). Improve future launches; do not
  block this cohort's tags.
- **Tier 3** — Research investigations. Open new questions; not rule
  changes.
- **Tier 4** — Speculative / consolidation. Lower priority; demand-
  driven studies; ecosystem-package extraction watchflags.

## Tier 1 — Direct skill amendments (blocking next tag)

| # | Target | Statement | Provenance | Status |
|---|--------|-----------|------------|--------|
| 1.1 | `handoff` skill | Add `[HANDOFF-041]` Acceptance-Criterion Grep Anchoring — heading-anchored vs substring-anchored verification when criterion text references a structural element. | `Reflections/2026-05-07-d1-readme-and-driver-repair.md` | LANDED 2026-05-07 (skill commit `650aa2b` in swift-institute/Skills) |
| 1.2 | `handoff` skill | Add `[HANDOFF-042]` Pre-Existing Code in Scope Existence Verification — ls-verify rows claiming artifact existence at handoff-write time. | `Reflections/2026-05-07-pre-publishable-polish-stream-2.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.3 | `handoff` skill | Add `[HANDOFF-043]` Multi-Cohort Orchestration Pattern — sequential cohorts each with its own dispatching handoff + carry-forwards table + per-phase sign-off + load-bearing observable invariant. | `Reflections/2026-05-07-supervisor-seat-swift-linter-cohort-orchestration.md` + 3 cohort execution reflections | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.4 | `supervise` skill | Add `[SUPER-031]` CI-Failure Attribution from Aggregator Output — read failed-job log, not aggregator labels (`lint`/`build`/`test` collide across distinct tools). | `Reflections/2026-05-07-supervisor-seat-swift-linter-cohort-orchestration.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.5 | `supervise` skill | Add `[SUPER-032]` Push-Bundle Discipline at Terminal Authorization — interleaved pushes degrade the terminal signal's information shape. | `Reflections/2026-05-07-pre-publishable-polish-stream-2.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.6 | `supervise` skill | Add `[SUPER-033]` In-Absentia + User-Intent-Primary Cascade Composition — lowest-loss interpretation + transparent surface for `ask:` triggers within routine cascades. | `Reflections/2026-05-07-d4-linter-rules-predicate-narrowing-and-readme-repair.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.7 | `implementation` skill (style.md) | Add `[IMPL-103]` SyntaxVisitor for Descendant Search in SwiftSyntax — manual children-cast silently truncates at non-ExprSyntax intermediate nodes. | `Reflections/2026-05-07-d4-linter-rules-predicate-narrowing-and-readme-repair.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.8 | `implementation` skill (style.md) | Add `[IMPL-104]` Leading-Dot Inference at Top-Level Multi-Overload Result-Builder Positions — Array.Builder's 4 `buildExpression` overloads break leading-dot at top-level; fully-qualified factories required. | `Reflections/2026-05-07-lint-manifest-drop-and-array-builder-inference.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.9 | `implementation` skill (style.md) | Add `[IMPL-105]` Overload Accepting Existing Protocol Over New Wrapper Type — when value-add is shape, not semantics. | `Reflections/2026-05-07-result-builder-map-anomaly-refuted.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.10 | `code-surface` skill | Add `[API-NAME-009]` Educational-Diagnostic Message Format — `[<rule_id>] <citation>: <description>`. | `Reflections/2026-05-07-swift-linter-modularization-cohort-completion.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.11 | `code-surface` skill | Add `[API-NAME-002]` sub-rule for namespace-implicit-prefix removal — peer-shape parity within namespace, not domain-phrase coherence outside. | `Reflections/2026-05-07-swift-linter-code-surface-cleanup-cohort-and-mirror-config-unblock.md` + `feedback_namespace_implicit_prefix_removal.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.12 | `research-process` skill | Add `[RES-027]` Loose-End Follow-Up Requires Extant or Immediate Experiment Package — close-out cites or creates ≤1-hour refutation experiment; loose ends without follow-up become architectural multipliers. | `Reflections/2026-05-07-result-builder-map-anomaly-refuted.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.13 | `research-process` skill | Add `[RES-028]` Smallest-Isolation-First Heuristic for Build-Target-Scoped Investigations — composes with `[RES-013a]`/`[RES-023]` for mechanism-claim verification. | `Reflections/2026-05-07-stdlib-map-actor-isolation-investigation.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.14 | `readme` skill (ci-automation.md) | Add `[README-170]` Composed-Example Empirical Validation — real call-site citation per composed type OR full `swift build` of extracted scratch package. | `Reflections/2026-05-07-d1-readme-and-driver-repair.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.15 | `release-readiness` skill | Add `[RELEASE-007]` Empirical Example-Compile Gate — Phase 3 mandatory extract-and-compile for every customer-facing example. | `Reflections/2026-05-07-swift-linter-pre-publishable-discovery-investigation.md` + `Reflections/2026-05-07-supervisor-seat-swift-linter-cohort-orchestration.md` (subsuming) | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.16 | `release-readiness` skill | Add `[RELEASE-008]` Filter-Parameter Runtime-Enforcement Test Gate — every public-API filter parameter has end-to-end integration test verifying runtime narrows behavior. | `Reflections/2026-05-07-swift-linter-pre-publishable-discovery-investigation.md` | LANDED 2026-05-07 (skill commit `650aa2b`) |
| 1.17 | `code-surface` skill | Promote the namespace-implicit-prefix sub-rule of `[API-NAME-002]` (1.11) to also cover **struct-field property names** (not just method/argument labels). The post-X1 fresh-eyes audit found `Lint.Manifest.{enabledRuleIDs, disabledRuleIDs, excludedPaths}` — three compound field names where the namespace `Lint.Manifest` already supplies the discriminator and `{enabled, disabled, excluded}` paired with bare `ruleIDs / paths` is the institute-correct form. The current sub-rule is shaped around method/argument labels; struct fields are the under-covered surface. **Proposed**: extend the `[API-NAME-002]` sub-rule decision-table to apply uniformly to struct-field names; cite `Lint.Manifest` as the worked example. | swift-linter D5 brief Phase 2 §Phase 2 Summary (2 MEDIUM compound-identifier items in `Lint.Manifest` fields) | LANDED `adceacb` 2026-05-08 (skill commit in swift-institute/Skills) |
| 1.18 | `modularization` skill | Add a corrective action: **swift-linter itself currently lacks a Test Support target** despite the X1 wave installing the `[MOD-024]` spine in 3 of 5 cohort packages. swift-linter's audit Phase 1 gap #6 escalates this as a structural gap (not a correctness defect). The release-readiness brief recommends CONDITIONAL GO with this item accept-as-known, but the next cohort packages' audits MUST verify `[MOD-024]` strict-mode compliance and surface the gap consistently. **Proposed**: amend `[MOD-024]` to add a "self-applies-to-the-pilot" verification step — when the rule is added to a skill via /reflections-processing, the dispatch authoring next-cohort audits MUST verify the rule applies to the pilot first, before the next cohort's packages. | swift-linter D5 brief Phase 1 #6 + `2026-05-04-test-support-spine-strict-rollout-and-mod-024.md` | LANDED `adceacb` 2026-05-08 (skill commit in swift-institute/Skills) |
| 1.19 | `audit` skill | Add a sub-rule for **per-skill priority calibration in pilot release-readiness Phase 2**: when the pilot is the FIRST package of a cohort, the per-skill priority table MUST inflate priority for skills where the pilot has zero-or-low coverage compared to the cohort precedent. swift-linter's Phase 2 priority table inflated `code-surface`, `implementation`, `modularization`, `readme`, `documentation`, `testing` to HIGH because the cohort had not yet absorbed the post-X1 cleanup pass. The carrier precedent calibrated against `code-surface` and `memory-safety` (primitives shape); the linter calibration is engine-shape. **Proposed**: amend `[AUDIT-*]` (or release-readiness `[RELEASE-001]` Phase 2 procedure) to require the per-skill-priority table cite the package shape and the rationale per skill, with the cohort precedent cited as the calibration anchor. | swift-linter D5 brief Phase 2 §Per-Skill Priority + carrier precedent | LANDED `adceacb` 2026-05-08 (skill commit in swift-institute/Skills — added as `[AUDIT-032]`) |
| 1.20 | `release-readiness` skill | Add a **partial-verification convention** to `[RELEASE-001]` Phase 0: when private-repo CI signal is unreliable per `feedback_private_repos_no_ci_runs`, substitute the CI-green gate with local clean-build verification on the principal toolchain (Swift 6.3 macOS) + explicit deferral of remaining matrix entries (Swift 6.4-dev nightly + Linux Docker) to public CI post-flip. The brief's substitution shape is: (a) cite `feedback_private_repos_no_ci_runs` for the rationale, (b) execute clean-build locally + record result, (c) defer matrix entries to a named post-flip dispatch. **Proposed**: codify this as a Phase 0 sub-rule applying when repo visibility is PRIVATE at brief-authoring time. | swift-linter D5 brief Phase 0 §Build & Test (CI-Green Substitute) | LANDED `adceacb` 2026-05-08 (skill commit in swift-institute/Skills — added as `[RELEASE-001a]`) |
| 1.21 | `release-readiness` skill | Add a **cross-cohort visibility prerequisite** clause to `[RELEASE-004]` per-action authorization gates: when a pilot package's nested-package consumers (e.g., swift-tagged-primitives `Lint/main.swift` in this cohort) inherit configuration via `// parent: <URL>` directives pointing to repositories OUTSIDE the cohort, those external repositories MUST also be flipped to public BEFORE the pilot's launch is consumer-experience-complete. **Proposed**: extend `[RELEASE-004]` Stage 2 (Repo Visibility Flip) checklist to require enumerating + verifying cross-repo URL references. | swift-linter D5 brief Phase 1 #9 + Phase 3 §Cross-cohort visibility prerequisite (DOC15) | LANDED `adceacb` 2026-05-08 (skill commit in swift-institute/Skills — added as `[RELEASE-004a]`) |
| 1.22 | (cross-package corrective action, not a skill amendment) | swift-linter is missing a `Linter Test Support` target per `[MOD-024]`. Cohort precedent (X1 wave) installed Test Support spine in 3 of 5 packages (swift-linter-primitives pre-existed; manifest-primitives, manifests, linter-rules added in X1; swift-linter itself is the uncovered package). **Disposition**: post-tag follow-up dispatch (CONDITIONAL GO accept-as-known per the D5 brief). The next cohort package's audit MUST verify swift-linter's spine has been added before the cohort's third package tags. | swift-linter D5 brief Phase 1 #6 + audit synthesis Top-5 | OPEN — post-tag follow-up dispatch |

## Tier 2 — Process improvements (handoff, supervise, audit, reflections-processing)

| # | Target | Statement | Provenance | Status |
|---|--------|-----------|------------|--------|
| 2.1 | `release-readiness` skill | Codify the **forums-review pre-mortem** as a SHOULD-step in `[RELEASE-002]` Phase 4 for pilot launches. The carrier precedent ran a forums-review re-simulation; the swift-linter brief explicitly DEFERS this step (final recommendation §Predicted Forums-Review Reception) per Phase 4 backlog Tier 2. **Proposed**: clarify that pilot-launch briefs MAY defer the forums-review re-simulation but the deferral MUST be cited in the final recommendation with rationale (e.g., "forums-review skill not yet calibrated for tooling packages"). | swift-linter D5 brief Final §Predicted Forums-Review Reception | OPEN |
| 2.2 | `audit` skill | Codify a **post-cohort-launch fresh-eyes pass** convention for the audit skill: when an X-wave bundled remediation lands across multiple cohort packages, the next dispatch's audit pass MUST distinguish "RESOLVED <SHA>" findings from new findings introduced by the wave, and append a new dated `## {Skill} — <DATE>` section per skill in `<package>/Audits/audit.md` rather than overwriting prior dated sections. The swift-linter audit.md has 7 pre-X1 (2026-05-07) sections AND 7 post-X1 (2026-05-08) sections by Phase 2 design. **Proposed**: amend `[AUDIT-*]` (or `[RELEASE-002]` Phase 1 procedure) to formalize the append-rather-than-overwrite convention. | swift-linter D5 brief Phase 2 Procedure | OPEN |
| 2.3 | `handoff` skill | Add a **premise-staleness register** sub-rule for handoffs that span >24 hours of intervening work: when a brief's premise references a state that has since changed (e.g., "Manifest.NestedPackage.DispatchError lives in swift-manifest-primitives" but the type was relocated to swift-manifests), the executing agent MUST surface the staleness in Implementation Notes with (a) the brief premise verbatim, (b) the actual current state, (c) the corrective action taken. The X1 Implementation Notes captured 3 such items inline; codifying the convention prevents future briefs from carrying through stale assumptions silently. | `HANDOFF-x1-pre-publishable-polish-wave.md` §Premise-Staleness | OPEN |
| 2.4 | `reflections-processing` skill | Add a **cohort-batch-triage** convention: when /reflections-processing runs against >5 reflections from a single cohort (e.g., the 13 reflections from the swift-linter cohort processed 2026-05-07), the resulting skill commit SHOULD use a single bundled commit per `[REFL-PROC-016]` rather than per-skill commits. The 2026-05-07 cohort processed 13 reflections into 12 new IDs across 7 skills as one commit (`650aa2b`); cohort-batch reduces commit-noise and surfaces the cohort's load-bearing patterns at a glance. | swift-institute/Skills@`650aa2b` (2026-05-07 cohort triage) | LANDED 2026-05-07 (de facto via the 650aa2b commit; the convention is descriptive, not prescriptive — codify formally in next /reflections-processing iteration) |
| 2.5 | `supervise` skill | Codify the **pilot-cohort dispatch shape** observed in this cohort: principal authorizes (a) discovery handoff → (b) /reflections-processing → (c) workspace-level independent audit synthesis → (d) X-wave bundled remediation → (e) push authorization → (f) release-readiness pilot brief → (g) per-action authorization gates. Each step has its own handoff; each handoff has its own ground-rules block. The cohort orchestration pattern at `[HANDOFF-043]` covers (a)–(d); the release-readiness pilot at `[RELEASE-003]` covers (f); but the FULL pilot-cohort dispatch shape connecting all 7 steps is not yet codified. **Proposed**: add a `[SUPER-*]` rule cross-referencing `[HANDOFF-043]` and `[RELEASE-003]` and naming the canonical step sequence. | `Reflections/2026-05-07-supervisor-seat-swift-linter-cohort-orchestration.md` | OPEN |
| 2.6 | `audit` skill | Add a **public-API-rename-window opening** convention: when an audit recommends a rename that cascades across consumer call sites (e.g., the X1 multi-form rule renames cascading into swift-tagged-primitives' Lint nested package), the audit synthesis MUST flag the rename window's blast radius in §Recommendation Sequencing and the dispatch handoff MUST land all consumer cascades in the same wave. The X1 wave correctly bundled the cascade; codifying prevents future audits from leaving consumer cascades unstated. | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §6.B | OPEN |
| 2.7 | `release-readiness` skill | Extend `[RELEASE-002]` Phase 0 §"CI green" gate with the **CI-substitution pattern** observed in this brief: the cohort's CI infrastructure does not run on private repos (`feedback_private_repos_no_ci_runs`); the brief substitutes with local clean-build + tests on the principal toolchain. **Proposed**: amend `[RELEASE-002]` Phase 0 to admit the CI-substitution pattern explicitly with a worked example. | swift-linter D5 brief Phase 0 §Build & Test | OPEN |
| 2.8 | `release-readiness` skill | Add a **launch-blog draft authorization** sub-step to `[RELEASE-004]` Stage 3: distinguish (i) blog-repo push (routine; `feedback_blog_publish_two_steps`) from (ii) swift-institute.org public-site push (per-action authorization). The swift-linter brief's Stage 3 names both levels, but the carrier precedent's blog-publish sequencing is more granular than the current rule text. **Proposed**: codify the two-level distinction in `[RELEASE-004]` Stage 3. | swift-linter D5 brief Phase 3 §Stage 3 + carrier precedent | OPEN |
| 2.9 | `audit` skill | Add a **prior-pass-finding re-verification** convention: when a release-readiness brief's Phase 0 verifies prior discovery / audit findings against the post-remediation state, the verification table MUST cite the resolving commit SHA (or "RESOLVED via X-wave") for each prior-pass finding. The swift-linter brief's Phase 0 §Synthesis Verification table cites SHAs for all 13 swift-linter-slice HIGH findings; codifying the convention prevents silently-resolved findings from being treated as carry-forwards in subsequent passes. | swift-linter D5 brief Phase 0 §Discovery + Synthesis Verification | OPEN |
| 2.10 | `audit` skill | Add a **cohort-level audit synthesis** companion document convention: when /audit dispatches against multiple cohort packages in a single pass, the workspace-level synthesis at `swift-institute/Audits/<DATE>-<topic>-cohort-independent-audit.md` is the durable corpus artifact; per-package `<package>/Audits/audit.md` is gitignored. The swift-linter cohort produced both; the relationship between the two is not codified in the audit skill. **Proposed**: amend `[AUDIT-002]` to name the workspace-level synthesis as the durable corpus artifact and per-package audit.md as the per-package working file. | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md (worked precedent) | OPEN |
| 2.11 | `handoff` skill | Add a **Constraint #4 boundary specification** sub-rule for release-readiness handoffs: when the dispatch is a release-readiness brief authoring (NOT code remediation), the Do-Not-Touch list MUST include `Sources/`, `Tests/`, `Package.swift`, `README.md`, `LICENSE.md`, `.github/`, `.gitignore`, `.github/metadata.yaml`. Code fixes ARE escalation territory per Ground Rule #5 (release-readiness handoff). **Proposed**: codify the canonical Do-Not-Touch list in handoff `[HANDOFF-005]` (branching template) for release-readiness mode. | swift-linter D5 brief §Do Not Touch | OPEN |

## Tier 3 — Research investigations

| # | Title | Statement | Provenance | Status |
|---|-------|-----------|------------|--------|
| 3.1 | swift-diagnostic-reporting extraction watchflag | Document the audit's `swift-diagnostic-reporting` ecosystem-package candidate (text + SARIF reporters) as an open watchflag per the audit synthesis §3.E Escalation 1. (a) is met (composition-of-existing failure: lint reporters couple non-lint consumers to Linter_Primitives + SwiftSyntax); (b) is unmet (no current second consumer). Survey: every diagnostic-emitting tool (compiler, formatter, codemod) — when does the second consumer materialize? | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §3.E | OPEN — demand-gated |
| 3.2 | swift-tagged-json extraction escalation | Document the audit's `swift-tagged-json` ecosystem-package candidate as a class-(c) escalation per Ground Rule #7 (a met, b unmet today). The Lint.Manifest doc comment cites this as the natural-home gap; manual unwrap is the workaround. Principal decides whether (i) accept the workaround with a tracked extraction watchflag, or (ii) authorize the new package on (a) alone with hurdle-rate note. | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §3.E Escalation 2 + `Lint.Manifest.swift` doc-comment | OPEN — escalation pending |
| 3.3 | Logger primitive ecosystem package | The audit observed swift-linter's library `print(...)` diagnostic emission bypassing the typed Reporter pipeline; X1 Phase E item 12 routes through Diagnostic.emit but a Logger primitive does not yet exist in the ecosystem. Research: should `swift-logger-primitives` be a new L1 package? When does it earn its keep beyond the lint-cohort use? | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §3 #11 | OPEN |
| 3.4 | Visitor pattern extraction study | The audit observed 12-fold duplication of the Visitor class shape across swift-linter-rules (each rule's Visitor is structurally identical: init, walk, append). Research: would a base class or generic helper at swift-linter-primitives reduce duplication without coupling rules to a fragile shared API? Risk: shared base couples rules; hard to abstract without losing per-rule customization. | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §3 #9 | OPEN — defer post-tag |
| 3.5 | Lint.Source.Walker ecosystem-promotion study | Walker's Swift source-file discovery via glob + standard exclusions is general (formatters, doc generators, codemod tools all want this). Research: extend swift-file-system with `File.Glob.SwiftSources` preset, OR new `swift-source-walker` L3 package. [RES-018] gate (b) currently unmet; survey ecosystem for second consumer. | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §3 #3 | OPEN — demand-gated |
| 3.6 | Lint.Finding typealias evaluation per [API-NAME-004a] | The audit observed `Lint.Finding = Diagnostic.Record` typealias as a borderline case for [API-NAME-004] / [API-NAME-004a]. Lint extends Diagnostic.Record in NO novel way — Lint.Finding is identity-only. Strict reading: violates [API-NAME-004]. Research: does the cohort-wide pattern (Lint, swift-pdf, swift-json) of typealiased adoption violate [API-NAME-004]? Survey + recommendation. | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §4.E | OPEN |
| 3.7 | Pre-publishable discovery investigation as a pre-launch convention | The discovery investigation (`HANDOFF-pre-publishable-inventory-and-planning.md` §Findings) surfaced 8 inventory categories + D1–D9 sequence + 4 strategic decisions BEFORE the audit synthesis was authored. Research: should pre-publishable discovery be a named step in the release-readiness skill, with its own template? The carrier precedent did NOT have a separate discovery investigation — the audit synthesis substituted. Determine which shape is correct for which package class. | `Reflections/2026-05-07-swift-linter-pre-publishable-discovery-investigation.md` | OPEN |
| 3.8 | Mirror config unblock pattern (cohort sweep) | The cohort's code-surface cleanup drove a mirror-config unblock: `feedback_namespace_implicit_prefix_removal` flag 2 adjudication revealed that the namespace-implicit-prefix sub-rule applies asymmetrically across the cohort (swift-manifest-primitives is strongest; swift-linter has 11 violations). Research: is this the universal cohort-shape pattern (each cohort has one strongest member + N-1 violators), or specific to engine-shape cohorts? | `Reflections/2026-05-07-swift-linter-code-surface-cleanup-cohort-and-mirror-config-unblock.md` | OPEN |
| 3.9 | Sub-product split-decision rubric (already authored) | The cohort produced `swift-institute/Research/2026-05-07-package-extraction-defect-catalog.md` and `swift-institute/Research/sub-product split-decision rubric (priority order)`. Verify: is the rubric absorbed into a skill rule, or does it remain a Research artifact? If absorbed, cite which skill ID. If not, this is a Tier 1 candidate. | `99e1610` Research: sub-product split-decision rubric | OPEN — verify absorption |
| 3.10 | Single-file Lint.swift deprecation decision | The cohort produced `swift-institute/Research/2026-05-07-single-file-lint-swift-deprecation-decision.md`. Verify the decision is reflected in the canonical Lint.swift file at swift-institute/.github (Tier 1) and swift-primitives/.github (Tier 2) per the file-based canonical pattern. | `swift-institute/Research/2026-05-07-single-file-lint-swift-deprecation-decision.md` | OPEN — verify chain |

## Tier 4 — Speculative / consolidation

| # | Title | Statement | Provenance | Status |
|---|-------|-----------|------------|--------|
| 4.1 | Engine-shape vs primitives-shape audit-priority calibration | The carrier precedent's release-readiness audit calibrated against `code-surface` and `memory-safety` (primitives-shape package). The swift-linter brief's Phase 2 priority table calibrates against `code-surface`, `implementation`, `modularization`, `readme`, `documentation`, `testing` (engine-shape). Is there a third (e.g., standards-shape, applications-shape) calibration that should be documented? | swift-linter D5 brief Phase 2 §Per-Skill Priority | OPEN — survey demand-gated |
| 4.2 | Linter Core decomposition (Engine + Manifest + Walker split) | The audit noted swift-linter's Linter Core target hosts Engine + Manifest + Walker; future decomposition could split into 3 sibling targets per [MOD-*]. Cost-of-staying: small (one large target stays cohesive); cost-of-moving: 3 target moves + product graph reshape. **Defer post-tag** unless a consumer requests narrow imports. | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §6.C | OPEN — defer post-tag |
| 4.3 | Linter Reporter Format extraction to shared Core target | Lint.Reporter.Format enum currently lives in Linter Reporter Text; SARIF reporter consumes it via cross-target dependency. Future: extract Format to a shared Core target. Cost: small; benefit: removes cross-target dep. | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §6.C + swift-linter Modularization #4 | OPEN |
| 4.4 | Reporter naming symmetry (Lint.Reporter.Text variant) | The X1 Phase E item 11 partially resolved this by extracting Lint.Reporter.Text. Future: ensure full symmetry — Lint.Reporter (namespace) hosts Lint.Reporter.Text (text variant) AND Lint.Reporter.SARIF (SARIF variant); no methods at Lint.Reporter level. | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §4.E + §6.C | OPEN |
| 4.5 | Documentation history-flavor trim ecosystem-wide | Three packages cite implementation-history phases ("Phase 1.5 / 1.6", "v2", "PoC of …", HANDOFF citation) in DocC. Per `feedback_blog_voice` adjacent reasoning, history belongs in commit messages and Research/, not in DocC. Survey: how many cohort packages have this drift? | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §5.D | OPEN |
| 4.6 | Span-bytes-to-array helper (file for swift-file-system) | Five sites across swift-manifests + swift-linter use the same span-to-array copy pattern per `feedback_span_indexed_over_unsafe_pointer`. File for swift-file-system ownership: `File.Read.bytes()` convenience or `Span<UInt8>.array()` extension. | swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md §3 #10 | OPEN — file for swift-file-system |
| 4.7 | DocC catalog absence across cohort | DOC9, DOC10 (discovery): no DocC catalogs in any of 5 ecosystem packages. Per Decision 8 deferred-but-named (Phase 5 / 0.2 dispatch). The carrier precedent shipped DocC at 0.1.0; the linter cohort defers. Survey: when does the cohort earn DocC? | swift-linter D5 brief Phase 1 #4 | DEFERRED — Decision 8 |
| 4.8 | lint.yml CI workflow failing pre-X1 | swift-linter's lint.yml CI workflow has been failing for 3 prior pushes (not X1-introduced). Per the brief Final Recommendation §5, this is a 0.1.0 accept-as-known item; post-flip triage will surface root cause. Survey: is this swift-linter-specific or cohort-wide CI infrastructure drift? | swift-linter D5 brief Phase 3 #4 + X1 Implementation Notes §CI Signal Notes | OPEN — post-flip triage |

## Package-local follow-ups (in swift-linter, not skill changes)

These are tracked here for completeness but live in the package, not the
skill system. They belong to the swift-linter audit's Phase 1 / 2 /
post-tag dispatch.

| # | Item | Provenance | Status |
|---|------|------------|--------|
| P.1 | swift-linter Test Support spine missing per `[MOD-024]`. Disposition: post-tag follow-up dispatch (cohort precedent installed Test Support in 3 of 5 cohort packages). | swift-linter D5 brief Phase 1 #6 | OPEN — post-tag |
| P.2 | README "Adopting the `Lint/` shape" worked example uses `Lint.Manifest(enabledRuleIDs:excludedPaths:)` but actual nested-package consumers use `Lint.Configuration { ... }` per swift-tagged-primitives/Lint/main.swift. Disposition: post-tag README sweep. | swift-linter D5 brief Phase 1 #7 | OPEN — post-tag |
| P.3 | Documentation.docc/ scaffolding absent. Disposition: deferred per Decision 8. | swift-linter D5 brief Phase 1 #4 + DOC10 (discovery) | DEFERRED — Decision 8 |
| P.4 | Contributor section absent in README. Disposition: defer until cohort opens to external contribution. | swift-linter D5 brief Phase 1 #5 | OPEN — pattern matches carrier precedent |
| P.5 | `homepageUrl` and `repositoryTopics` empty/null on `gh repo view`. Disposition: pre-flip `gh repo edit` step per `[GH-REPO-*]`. | swift-linter D5 brief Phase 3 #7 | OPEN — pre-flip |
| P.6 | Build warnings: `public import of 'SwiftSyntax' was not used` (Lint.Run.swift) and `public import of 'ISO_9945_Kernel_Terminal' was not used` (Lint.Reporter.swift). Both pre-X1; non-blocking. Disposition: post-tag declassification to internal. | swift-linter D5 brief Phase 0 §Build warnings | OPEN — post-tag |
| P.7 | `Lint.Run.Error.nonUTF8` declared but never thrown (PR15). Disposition: 0.2 cleanup. | swift-linter D5 brief Phase 0 §Discovery (PR15) | OPEN — 0.2 |
| P.8 | Lint.Manifest field compound identifiers (`enabledRuleIDs`, `disabledRuleIDs`, `excludedPaths`). Wire-format-stable rename candidate. Disposition: 0.2 (decoupled from JSON wire-format consumers). | swift-linter D5 brief Phase 2 Summary + Final Recommendation #2 | OPEN — 0.2 |

## Procedure for landing a Tier 1 item

1. Update the relevant skill file in
   `/Users/coen/Developer/swift-institute/Skills/<skill>/`
   (or the appropriate sub-file for cohorted skills).
2. Bump the skill's `last_reviewed` per `[SKILL-LIFE-004]`.
3. Run `/Users/coen/Developer/swift-institute/Scripts/sync-skills.sh`
   to regenerate the `~/.claude/skills/` symlinks.
4. Annotate the matching row in this backlog: change `Status` from
   `OPEN` to `LANDED <commit-sha> <date>`.
5. Cross-link from the skill commit message back to this backlog and
   the originating reflection.

## Procedure for deferring a Tier 1 item

If a Tier 1 item is intentionally deferred past the swift-linter 0.1.0
tag (and therefore past the next package's audit), annotate the row:

```
Status: DEFERRED <date> — <one-line rationale> — re-evaluate at <trigger>
```

The downstream audit MUST cite the deferral when running against the
un-amended skill rule.

## Net assessment

The Tier 1 list contains **22 items**. As of 2026-05-08:

- **16 items LANDED 2026-05-07** (skill commit `650aa2b` in
  `swift-institute/Skills`):
  - 3 handoff: `[HANDOFF-041]`, `[HANDOFF-042]`, `[HANDOFF-043]` (1.1, 1.2, 1.3)
  - 3 supervise: `[SUPER-031]`, `[SUPER-032]`, `[SUPER-033]` (1.4, 1.5, 1.6)
  - 3 implementation: `[IMPL-103]`, `[IMPL-104]`, `[IMPL-105]` (1.7, 1.8, 1.9)
  - 1 code-surface: `[API-NAME-009]` (1.10) + 1 sub-rule of `[API-NAME-002]` (1.11)
  - 2 research-process: `[RES-027]`, `[RES-028]` (1.12, 1.13)
  - 1 readme: `[README-170]` (1.14)
  - 2 release-readiness: `[RELEASE-007]`, `[RELEASE-008]` (1.15, 1.16)
- **5 items LANDED 2026-05-08** (skill commit `adceacb` in
  `swift-institute/Skills`):
  - 1 code-surface: extension to `[API-NAME-002]` sub-rule for struct-field property names (1.17)
  - 1 modularization: `[MOD-024]` self-applies-to-pilot verification step (1.18)
  - 1 audit: `[AUDIT-032]` per-skill priority calibration (1.19)
  - 2 release-readiness: `[RELEASE-001a]` Phase 0 partial-verification (1.20), `[RELEASE-004a]` cross-cohort visibility prerequisite (1.21)
- **1 item OPEN — corrective action**:
  - 1.22 (swift-linter Test Support spine; cross-package, not a skill change)

Outstanding Tier 1 items: 1 (cross-package corrective action only — all
five skill amendments now landed).

The next cohort package's audit (swift-linter-rules / swift-manifests /
swift-manifest-primitives / swift-linter-primitives — sequencing TBD)
MUST EITHER cite each open Tier 1 item in its disposition table OR
verify that the item has landed before the audit pass commences.

Per `[RELEASE-003]`, the principal MAY choose to tag swift-linter 0.1.0
with the 6 open Tier 1 items still open, then process the backlog
before the cohort's subsequent tags. The pilot's audit is a snapshot
against the rule set at audit time; landing Tier 1 items afterward
does NOT retroactively edit the pilot's findings.

## References

- `swift-foundations/swift-linter/AUDIT-0.1.0-release-readiness.md` — the
  D5 release-readiness brief that gates on this backlog at Phase 4.
- `swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md`
  (commit `f841ff5`) — the workspace-level audit synthesis covering all
  5 cohort packages.
- `HANDOFF-x1-pre-publishable-polish-wave.md` `## Implementation Notes`
  — the X1 wave's per-phase commit SHAs and premise-staleness register.
- `swift-institute/Research/carrier-launch-skill-incorporation-backlog.md`
  — the carrier-primitives precedent (12 Tier 1 items, all RESOLVED 2026-04-30).
- `swift-institute/Skills@650aa2b` — the 12-amendments skill commit
  from /reflections-processing 2026-05-07 (Tier 1 items 1.1–1.16).
- `swift-institute/Skills@adceacb` — the 5-amendments skill commit
  from the focused-dispatch landing 2026-05-08 (Tier 1 items 1.17–1.21).
- All 16 reflections enumerated under "Issue / Scope filter."
