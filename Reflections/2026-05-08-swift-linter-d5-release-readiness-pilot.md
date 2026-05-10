---
date: 2026-05-08
session_objective: Execute D5 release-readiness pilot per [RELEASE-001/003] for swift-linter as the cohort pilot — author 5-phase brief, Phase 4 skill-incorporation backlog, Phase 2 post-X1 fresh-eyes audit pass; recommend GO / CONDITIONAL GO / NO-GO without executing per-action gates
packages:
  - swift-foundations/swift-linter
  - swift-primitives/swift-linter-primitives
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-manifests
  - swift-primitives/swift-manifest-primitives
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: NoAction code-surface Tier 1 item 1.17 ([API-NAME-002] extension to struct-field property names) part of cohort backlog tracked separately. NoAction release-readiness Tier 1 items 1.20/1.21 covered by ongoing release-readiness skill work + [RELEASE-001a]/[RELEASE-001b] precedents. Engine-shape vs primitives-shape calibration research deferred. SUPERSEDED on Phase 0 self-verification claim by 2026-05-08 X2 entry.
---

# swift-linter D5 Release-Readiness Pilot — Multi-Source Skill Backlog Authoring

## What Happened

D5 was the second pilot launch in the institute's 0.1.0 release-cohort
discipline (carrier-primitives 2026-04-29 was the first). The dispatch
brief at `HANDOFF-d5-release-readiness-pilot-swift-linter.md` directed
the 5-phase release-readiness pilot per `[RELEASE-001/003]`, with strict
"Do Not Touch" boundaries on `Sources/`, `Tests/`, `Package.swift`,
README/LICENSE, `.github/`, and explicit prohibition on executing any
`[RELEASE-004]` per-action gate.

Three durable artifacts authored:

- `swift-foundations/swift-linter/AUDIT-0.1.0-release-readiness.md` (427
  lines, gitignored per `[RELEASE-006]`) — the 5-phase brief.
- `swift-institute/Research/swift-linter-launch-skill-incorporation-backlog.md`
  (156 lines) — Phase 4 backlog with 22 Tier 1 items + 11 Tier 2 + 10
  Tier 3 + 8 Tier 4 + 8 package-local follow-ups.
- `swift-foundations/swift-linter/Audits/audit.md` (218 → 441 lines) —
  appended `# 0.1.0 Final Pre-Release Scan — 2026-05-08` section with 7
  per-skill `## {Skill} — 2026-05-08` sub-sections following the
  append-rather-than-overwrite convention from `[RELEASE-002]` Phase 1.

Phase 0 baseline: HEAD `a55c7f0` matches origin/main; `swift build`
green (152.65s); `swift test` 10/10 passed. Per `feedback_private_repos_no_ci_runs`,
substituted the CI-green gate with local clean-build verification on
Swift 6.3 macOS, deferring Swift 6.4-dev nightly + Linux Docker matrix
to public CI post-flip.

Phase 0 §Synthesis Verification re-verified all 13 swift-linter-slice
HIGH findings from the workspace-level audit synthesis at
`swift-institute/Audits/2026-05-07-swift-linter-cohort-independent-audit.md`
(commit `f841ff5`) against post-X1 state — all 13 RESOLVED with cited
SHAs.

Phase 1 enumerated 9 gaps with disposition: 5 PASS, 2 DEFERRED (DocC,
Contributor section), 1 MISSING-but-out-of-scope (swift-linter Test
Support spine — Constraint #4 prohibited applying), 1 POST-TAG fix
(README "Adopting the `Lint/` shape" worked example mixes Manifest +
Configuration shapes), 1 PRE-FLIP cross-cohort prerequisite (DOC15:
swift-primitives/.github visibility flip required for
swift-tagged-primitives nested-package consumer chain to resolve).

Phase 2 fresh-eyes pass surfaced 0 CRITICAL, 0 HIGH, 2 MEDIUM, 5+ LOW
— all pre-X1 HIGH findings resolved with residual at MEDIUM/LOW. The
2 MEDIUM items are: (a) `Lint.Manifest.{enabledRuleIDs, disabledRuleIDs,
excludedPaths}` struct-field compound identifiers (under-covered by the
existing `[API-NAME-002]` sub-rule which targets method/argument labels),
(b) swift-linter Test Support spine missing.

Phase 4 backlog Tier 1 has THREE provenance sources per Ground Rule #3:
(i) the 16 amendments LANDED 2026-05-07 via skill commit `650aa2b` from
/reflections-processing 2026-05-07 — verified each against current
skill files; (ii) Phase 2 audit findings — 2 MEDIUM items surfaced 1
new Tier 1 item (1.17, struct-field extension to existing sub-rule);
(iii) X1 Implementation Notes premise-staleness items — supervisor
brief-author missed multi-form rename shape; partial CI verification
convention; cross-package consumer cascade discovery → 4 new Tier 1
items (1.18 [MOD-024] self-applies-to-pilot, 1.19 [AUDIT-*] per-skill
priority calibration, 1.20 [RELEASE-001] partial-verification convention,
1.21 [RELEASE-004] cross-cohort visibility prerequisite).

Final recommendation: **CONDITIONAL GO** with 7 items explicitly
accept-as-known. All 10 acceptance criteria PASS; `[SUPER-011]`
verification stamp landed in HANDOFF-d5 Implementation Notes.

## What Worked and What Didn't

**Worked**:

- **The brief-and-backlog separation**: authoring the brief first
  established the gap inventory + final recommendation; authoring the
  backlog second consumed the brief's references and added the new
  skill-amendment candidates surfaced by the brief's own Phase 2 work.
  The two artifacts compose: brief states the position; backlog states
  the rule-set deltas required for the next cohort package's audit.

- **Three-source Tier 1 derivation per Ground Rule #3**: dispatch brief
  named the three provenance sources explicitly (i/ii/iii); having the
  list externalized prevented the natural anchor-bias toward source (i)
  alone. Sources (ii) and (iii) each produced novel Tier 1 candidates
  (5 new items total) that would have been missed if the backlog were
  authored as "verify the 16 LANDED items from /reflections-processing."

- **Append-rather-than-overwrite for audit.md**: the file now has 8
  pre-X1 (`## {Skill} — 2026-05-07`) sections + 7 post-X1
  (`## {Skill} — 2026-05-08`) sub-sections under a new
  `# 0.1.0 Final Pre-Release Scan — 2026-05-08` H1, plus the original
  `## Cross-Skill Observations`. Pre-X1 finding statuses are not
  overwritten; the post-X1 sub-sections cite RESOLVED with SHAs. This
  worked smoothly and is itself a Tier 2 backlog item (2.2) — codify the
  convention in `[AUDIT-*]` or `[RELEASE-002]`.

- **CI-substitution pattern explicitly cited**: the brief's Phase 0 §Build
  & Test gates the work behind `feedback_private_repos_no_ci_runs` with
  a worked-example. Tier 1 item 1.20 promotes this from feedback-memory
  to a Phase 0 sub-rule of `[RELEASE-001]`.

**Didn't work**:

- **Acceptance-criterion verification phrasing for column-cell counts**:
  Criterion #7 verification initially read `grep -c 'Provenance' …
  shows ≥1 per row` — but the backlog's table cells don't repeat the
  word "Provenance" (it's only in the column header). Caught
  mid-stamping; corrected to `grep -c '^| 1\.'` (Tier 1 row count = 22)
  + `grep -c 'Reflections/\|Audits/\|HANDOFF-x1\|swift-institute/Skills'`
  (58 path-mention citations). The original phrasing would have falsely
  reported "4 matches" (one per Tier table header) when the verification
  intent was per-row coverage.

- **Premise of brief Phase 4 Summary undercounted Tier 1**: the brief's
  Phase 4 Summary said "Tier 1: N items derived from THREE provenance
  sources" without committing to N. The backlog produced N=22 (16
  LANDED + 5 OPEN skill amendments + 1 OPEN cross-package corrective
  action). Briefer's deliberate undercommit was correct (avoid
  pre-judging the count); the gap is that the brief doesn't enumerate
  the OPEN items — readers must turn to the backlog. Acceptable but
  worth noting for next cohort package's brief.

## Patterns and Root Causes

**Pattern: pilot-launch produces meta-skill amendments at the rate of
~1 amendment per 1-2 acceptance-criteria-verification turns**. Carrier
2026-04-29 produced 12 Tier 1 items across 4 passes; swift-linter
2026-05-08 produced 5 OPEN Tier 1 items + verified 16 LANDED + 1
cross-package corrective action against 7 phases of work. Both
pilots' rate is consistent: each verification step against the
release-readiness rule-set reveals one or more under-specified
clauses. The release-readiness skill is itself young (carrier was
its seeding case; swift-linter is its second exercise), so this rate
should taper as the rule-set saturates against the diversity of
package shapes.

**Root cause for pattern**: the release-readiness skill's per-skill
priority table in Phase 2 is shape-aware in spirit but not in rule.
The carrier brief calibrated against `code-surface` and
`memory-safety` (primitives-shape, ~Copyable/~Escapable heavy);
swift-linter calibrated against `code-surface`, `implementation`,
`modularization`, `readme`, `documentation`, `testing` (engine-shape,
no ~Copyable surface). The brief assigned HIGH priority to those 6
skills explicitly, but the rule has no anchor for "calibrate to package
shape." Tier 1 item 1.19 promotes this from de-facto practice to an
audit-skill rule.

**Pattern: the "self-applies-to-the-pilot" gap on cohort-wide structural
rules**. `[MOD-024]` strict mode was added 2026-05-04 with the directive
"every package with at least one test target MUST publish a Test Support
product." X1 wave installed the spine in 3 of 5 cohort packages; the
swift-linter-primitives spine pre-existed; swift-linter ITSELF — the
PILOT — is the uncovered package. The release-readiness brief surfaces
this as Phase 1 #6 with a CONDITIONAL GO accept-as-known disposition.
Tier 1 item 1.18 amends `[MOD-024]` to require self-applies-to-the-pilot
verification when the rule is added to a skill via /reflections-processing.

**Root cause**: rules added during /reflections-processing 2026-05-04
were derived from the broader institute corpus; the swift-linter cohort's
pilot relevance was not part of the derivation. Codifying the
verification step prevents future skill-additions from skipping the pilot.

**Pattern: the brief-authoring agent and the executing-supervisor
agent's verification-text discipline**. Initial criterion-7 verification
text used `grep -c 'Provenance'` — a phrase the agent intuited would
match per-row but actually matches only column headers. The
discrepancy was caught at stamp-time, not draft-time. This is the
[REFL-012] loop-counter-vs-state-verification pattern at a smaller
scale: counting "Provenance" mentions is a counter; counting Tier 1
rows (22) plus path-mention citations (58) is the state. The brief's
acceptance-criteria verification table is the natural place to enforce
state-checks; future briefs should default to row-count + content-grep
shapes rather than keyword-presence shapes.

## Action Items

- [ ] **[skill]** code-surface: Land Tier 1 item 1.17 — extend the
  `[API-NAME-002]` sub-rule for namespace-implicit-prefix removal to
  cover **struct-field property names** uniformly. Cite `Lint.Manifest.
  {enabledRuleIDs, disabledRuleIDs, excludedPaths}` as worked example.
  Block on next cohort package's audit until LANDED.
- [ ] **[skill]** release-readiness: Land Tier 1 items 1.20 (Phase 0
  partial-verification convention for private-repo CI substitute) and
  1.21 (`[RELEASE-004]` Stage 2 cross-cohort visibility prerequisite —
  enumerate `// parent:` URL targets and require pre-flip on referenced
  external repos). Both block on next cohort package's audit; both have
  worked-example provenance in this brief's Phase 0 §Build & Test and
  Phase 3 §Cross-cohort visibility prerequisite.
- [ ] **[research]** Investigate engine-shape vs primitives-shape
  audit-priority calibration as the third per-skill-priority anchor
  for `[RELEASE-001]` Phase 2 (Tier 1 item 1.19, currently classified as
  audit-skill amendment). Survey: what shape would "applications-shape"
  look like? Does the standards-shape match primitives-shape or
  engine-shape? The carrier+linter dataset is N=2; a third pilot's
  calibration anchor would either confirm or invalidate the binary.
