---
date: 2026-05-06
session_objective: Investigate the CI/CD security posture of the swift-institute + swift-primitives stack per HANDOFF-ci-cd-security-review.md, land the resulting RECOMMENDATION + companion skill amendments + bot-installations manifest, and execute the cohort-cleanup wave to close out the security review.
packages:
  - swift-institute/Research
  - swift-institute/Skills
  - swift-institute/.github
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: SkillUpdate [REFL-015] Parser-Pass on Structured-Data Files (entry 12 AI 1; the v1.0.0 manifest top-level structural defect worked example). NoAction [CI-053] rule-coverage gap already covered by existing placeholder in ci-cd-workflows. v1.2.0 follow-on research is package-owner work.
---

# CI/CD security review investigation, cohort cleanup, and bot-installations enumeration

## What Happened

Continuation of today's CI/CD reviewer-feedback cohort. The earlier
session (separately reflected at
`2026-05-06-ci-reviewer-feedback-rollout-permissions-pitfall-and-doctrines.md`)
closed reviewer items H1–H4 / M1–M7 and dispatched the
cross-ecosystem-reuse Tier 2 investigation. This session was scoped to a
companion comprehensive security walkthrough of the entire CI/CD stack —
dispatched as `HANDOFF-ci-cd-security-review.md` (branching investigation
per `[HANDOFF-005]`, Tier 2 per `[RES-020]`).

**Investigation phase**. Five-scope analysis as briefed: per-component
matrix (23 workflows / 5 composites / 5 helper scripts), threat model
(6 paths labeled plausible-vs-speculative), gap inventory (initially 9
gaps — G1–G9), branch-protection minimal proposal (exact `gh api` shape
+ three-wave order), cohort sequencing (6-phase, 12 per-action gates).
Findings exceeded ~300 lines (final 952) so promoted to standalone
`swift-institute/Research/ci-cd-security-review.md` v1.0.0
RECOMMENDATION; `_index.json` updated per `[RES-003c]`.

Top-level finding: **single architectural chokepoint = branch protection
on `swift-institute/.github` and `swift-primitives/.github`**. Without
it, the bot's 17-org write capability (T3) collapses to "push access on
those two repos." Threat paths T2/T3/T5 all reduce to the same chokepoint
unless protection lands.

**v1.1.0 surgical-revision pass**. The principal supplied an independent
8-issue assessment which produced eight surgical additions to the doc,
no restructuring, no conclusions reversed:
  - §Scope 4 `enforce_admins` trade-off paragraph
  - §Scope 4 Wave 1 verification extended (gh api GET + JSON diff)
  - §Scope 4 forward-reference to L2/L3 wrapper repos
  - §Scope 3 NEW G10 (bot installation permissions audit) →
    NEW Cohort F
  - NEW `[CI-082]` proposal (binary-install version-bump protocol)
  - §Scope 3 G7 generalization to "callers in any branch-protected
    layer-wrapper repo" (so the rule survives the L2/L3 wrapper rollout)
  - §Scope 2 T4a Dependabot-for-Actions partial mitigation note
  - §Scope 5 Phase 5 audit-log review cadence (quarterly)

Authorization-gate count 12 → 13 (Cohort F adds one). Final document
1133 lines.

**Cleanup wave (Research repo, 2 commits + 1 push)**:
  - `e087a02` — research: ci-cd-security-review v1.1.0 (RECOMMENDATION)
  - `5e1790b` — research(reflections): add 2026-05-06 ci-reviewer-feedback rollout (the prior session's reflection, principal-authored)
  - Push: `fb36fa2..5e1790b` to `origin/main` of `swift-institute/Research`
  - `HANDOFF-ci-cd-security-review.md` deleted per `[REFL-009]`

The brief's step #2 (commit `ci-cd-cross-ecosystem-reuse.md v1.1.0`) was
a no-op — that cohort was already at v1.1.1 on origin (`fb36fa2`) from
a prior `/reflect-session` cleanup-authority firing. Surfaced rather
than silently substituted, per `[HANDOFF-016]` proposal-staleness axis.

**Skill amendments (Skills repo, 1 commit + 1 push)**:
  - `796e510` — `[CI-080]` block-mode-flip protocol detail (replaced
    6-step sketch with 7-step protocol: 2-cycle observation window,
    harvest mechanism via `gh run view`, per-workflow allowlist
    canonical set, container-job caveat, commit-message documentation
    requirement); added `[CI-081]` audit-step shell-input
    trust-boundary pattern (generalized to "callers in any
    branch-protected layer-wrapper repo"); added `[CI-082]`
    binary-install version-bump protocol; added `[CI-090]`
    reusable-vs-standalone permissions-shape (M2 incident codified);
    added `[CI-091]` uniform-platform-matrix doctrine (M4 REJECT
    codified).

**G10 bot-installations enumeration**. Single-org probe (`swift-primitives`)
revealed 17 declared permissions including `secrets:write`,
`members:write`, `administration:write` — substantially broader than
the security review's lower-bound inference (5). Per-org loop blocked
by sandbox after the probe; surfaced the partial result as a load-bearing
G10 finding rather than continuing without authorization. Authored
manifest skeleton at `swift-institute/.github/.github/actions/read-orgs/bot-installations.yaml`
with `swift-primitives` ENUMERATED + 16 `PENDING_ENUMERATION` rows.

Principal completed the remaining 16 enumeration calls out-of-band
+ trimmed `secrets:write` and `members:write` across all 17 orgs via
App-owner edit. Manifest population directive followed: single commit
restructured the file with all 17 rows ENUMERATED (uniform 15-perm
declared block), keep-the-10 decision documented once at header,
`inferred_min` (5) + `kept_over_inferred_min` (10) + `trimmed` (2)
trailing blocks.

The first manifest write hit a YAML parse error — top-level sequence
followed by mapping keys is invalid YAML. Restructured under
`installations:` mapping key. Caught pre-commit via `yq` validation;
no shipping defect.

`aafbe80` committed; pushed under explicit `YES DO NOW push G10 manifest`
to `origin/main` of `swift-institute/.github`. Skills `796e510` pushed
under `YES push Skills 796e510`.

**Authorization-trail audit (record-keeping)**. Principal asked for the
authorization trail behind two prior commits on `swift-institute/.github`
(`5044547` Q4 third-party disclaimer + `8cbe5c0` lint-org-bot-coverage
advisory linter). Both authored by the principal directly at 09:27 today
(before this subordinate session began). No explicit `YES DO NOW <name>`
gate reconstructible from session memory or git log. Surfaced as a
**rule-coverage gap**: single-repo edits to centralized-infra repos
sit between `[CI-050]`'s ≥3-consumer-repo trigger and `[CI-052]`'s
visibility/tag trigger — uncovered. Principal accepted the analysis
and routed the gap through discipline review.

**HANDOFF scan** (workspace root, 27 `HANDOFF-*.md` + 6 `AUDIT-*.md` =
33 files). Of those, 1 was authored / completed in this session
(`HANDOFF-ci-cd-security-review.md` — Findings appended,
RECOMMENDATION promoted, eligible for deletion under `[REFL-009]`
standard rule, **deleted post-push**). 2 are explicitly in-flight per
the dispatch brief (`HANDOFF-rollout-phase-1.md`,
`HANDOFF-r1r4-cleanup-wave-1.md`) — out of cleanup authority per
`[REFL-009a]` no-touch. The remaining 30 are out-of-session-scope:
authored before today's CI/CD security work, no completion signals
encountered in this session's work, ages range 1–14 days. Conservative
read of `[REFL-009]` bounded-cleanup-authority leaves all of them
unchanged. None triggered the `[REFL-009]` stale-override exception
(closure signals not determinable from this session's context).

**No `/audit` invocations** in this session, so `[REFL-010]` is N/A.

## What Worked and What Didn't

**Worked**:

- **Five-scope investigation discipline produced a doc that survived an
  independent assessment**. The brief structured the work along five
  explicit deliverables; each scope was independently answerable; the
  resulting document was comprehensive enough that the principal's
  independent assessment surfaced 8 issues but reversed 0 conclusions.
  The structural finding (single chokepoint = branch protection on host
  repos) held under scrutiny because it was grounded in the per-component
  matrix's literal token-mint shapes, not in narrative claims.
- **v1.0.0 → v1.1.0 surgical-revision discipline**. Eight assessment
  issues mapped 1:1 to eight surgical edits; no restructuring; no
  conclusions reversed. Authorization-gate count adjusted (12 → 13)
  rather than the document's framing. This is a clean shape for
  high-stakes research docs: v1.0.0 establishes the architecture, an
  independent assessment surfaces issues, v1.1.0 lands surgical
  additions without restructuring. Preserves trust.
- **Per-action-gate discipline held throughout**. Did not push
  branch protection. Did not add Dependabot config. Did not author
  L2/L3 wrappers. Did not authorize my own pushes. Did not auto-trim
  bot permissions. Each push that landed had an explicit
  `YES DO NOW <name>` gate; each deferred action was logged in the
  end-of-batch report's "explicitly NOT authorized" list.
- **State-vs-brief staleness recognition**. The cleanup wave's step #2
  was a no-op because the cross-ecosystem-reuse cohort had advanced
  v1.1.0 → v1.1.1 in a prior `/reflect-session` firing. Recognized via
  `git log -5` before commit-message draft; surfaced as a discrepancy
  with the brief rather than silently substituted. This is `[HANDOFF-016]`'s
  proposal-staleness axis applied at batch-execution time.
- **Single-org probe → load-bearing G10 finding**. Sandbox blocked the
  per-org loop after the swift-primitives probe; surfaced the partial
  enumeration as an actionable finding rather than waiting for the full
  loop. The probe alone was sufficient to file a load-bearing
  observation (17 declared perms with `secrets:write` + `members:write`
  unexercised), which led directly to the principal's trim. Partial
  data + clear finding > full data delayed.

**Didn't work**:

- **YAML structural validation absent on first manifest write**. The
  v1.0.0 manifest shipped with a top-level sequence + sibling mapping
  keys — invalid YAML. The defect was caught pre-commit by routine
  `yq` parsing; the cost was a single restructure pass. But the
  underlying gap is real: I treated the file as documentational ("looks
  YAML-like") rather than as a parseable artifact. For any new YAML or
  JSON file authored in a session, a parser-pass should run before the
  file is considered complete. The cost is seconds; the cost of
  shipping a parse-error file (had it landed) would be the next agent
  re-investigating "why doesn't yq read this?" plus a rewrite.
- **Authorization-trail audit revealed I had no answer to the
  per-action-gate question for prior commits**. The principal's
  record-keeping ask exposed that I couldn't reconstruct the gate
  classification for `5044547` + `8cbe5c0` — both were authored by the
  principal directly, before today's subordinate session began, and the
  only signal of authorization was git author identity (a heuristic).
  This isn't a discipline failure (the principal can self-authorize
  their own commits), but it surfaced a real corpus gap: the codified
  gate classes (`[CI-050]` ≥3-consumer-repo edit, `[CI-052]`
  visibility/tag) don't cover single-repo edits to centralized-infra
  repos, even though those edits have real blast radius via `@main`
  pinning.

**Mixed**:

- **Hook-blocked enumeration loop**. The sandbox blocked the bulk
  per-org loop after the single-org probe succeeded. The block was
  principled (it asked for explicit per-action confirmation of the
  fan-out, given the probe had revealed scope-broader-than-expected),
  but it also forced a pause-and-escalate in the middle of a
  discoverable read-only operation. Going forward: announcing the
  fan-out scope BEFORE the probe (explicit "I'll probe 1, then loop 16
  if probe is informative") might reduce the discontinuity.

## Patterns and Root Causes

**Pattern 1: assessment-driven revision is a clean shape for high-stakes
research docs**. The flow `v1.0.0 (architecture-first draft) →
independent assessment (n issues, may reverse some conclusions) →
v1.1.0 (surgical additions, no restructuring)` preserved the
architectural finding while extending detail. The discipline that
makes this work: the assessment surfaces issues, the revision *adds*
rather than *replaces*, and the doc's version-bump policy is "minor
bump = surgical adds; major bump = restructuring". Today's v1.0.0 →
v1.1.0 was 8 issues, 0 reversals → minor bump. If any issue had
reversed a conclusion, the right move would have been v2.0.0 with
a Changelog entry that explicitly notes which v1.x conclusion is
withdrawn. The pattern generalizes to any doc the ecosystem treats
as authoritative — research RECOMMENDATIONs especially, where
downstream cohorts cite the doc as provenance.

**Pattern 2: rule-coverage gaps surface via audits-of-discipline, not
just via failures**. The authorization-trail audit on `5044547` +
`8cbe5c0` was an audit of *discipline coverage*, not of *whether a
violation occurred*. It revealed a class of edit (single-repo to
centralized-infra) that's currently uncovered by `[CI-050]` /
`[CI-052]` even though the blast radius via `@main` pinning is real.
This is a different failure mode from "rule was violated": the rule
*didn't apply*, and the lack-of-application was itself the finding.
The pattern: when a session pushes commits to a centralized-infra
repo, asking "what gate authorized this class of edit?" can surface
coverage gaps that no compliance audit would catch (because compliance
audits check whether THE existing rules were followed, not whether the
existing rules cover the class). Today's surface: principal's
record-keeping ask was the trigger; in future sessions, a sub-agent
auditing its own pushes against the codified gate classes would
self-discover the same gap.

**Pattern 3: structural validation belongs in the toolchain, not in
human review**. The v1.0.0 manifest's top-level-shape defect was a
pure parse error any YAML library would catch. I shipped the file
without running a parser pass because the file "looked right" — a
human-reviewer reading would not catch it because the indentation was
consistent and the keys were well-named. This generalizes to all
structured-data files: JSON, YAML, TOML, schema-validated Markdown
frontmatter. For any new such file authored in a session, a routine
"parse it before considering complete" check closes the class
mechanically. Today the cost was a single restructure pass; the
underlying gap (no parser-pass discipline) is mechanical to close.

**Pattern 4: load-bearing partial findings beat delayed full findings**.
The G10 enumeration was scoped at "all 17 orgs"; sandbox blocked the
loop after 1. The probe alone revealed (a) `secrets:write` and
`members:write` granted unexercised, (b) the bot's installation
permissions are substantially broader than the workflow corpus
needs. That observation didn't require all 17 orgs to be load-bearing
— uniform-or-not-uniform was a separable question, and the
worst-case-uniform interpretation (broad perms across all 17) was
strictly more conservative than any non-uniform finding could be.
Surfacing the partial result at the right framing got the principal
a trim across all 17 orgs within hours; waiting for full enumeration
would have delayed the trim by however long the per-action
authorization for the loop took. Pattern: when a partial result is
worst-case-actionable, surface it at the worst-case framing rather
than waiting for completeness.

## Action Items

- [ ] **[skill]** reflect-session: add a [REFL-014] rule (or extend
  [REFL-006]) — when a session authors any structured-data file (YAML /
  JSON / TOML / schema-validated Markdown frontmatter), run a parser
  pass (`yq`, `python3 -c "import yaml; yaml.safe_load(...)"`,
  `python3 -m json.tool`, etc.) before considering the file complete.
  The pre-commit Edit/Write tools touch the file; the parser pass
  should fire before the next reference (read, commit, ls). Today's
  v1.0.0 manifest shipped a top-level structural defect that any
  parser would have caught in a second.

- [ ] **[skill]** ci-cd-workflows: open the `[CI-053]` rule-coverage
  gap as a documented-but-deferred entry — single-repo edits to
  centralized-infra repos (`swift-institute/.github`,
  `swift-primitives/.github`, `swift-standards/.github`,
  `swift-foundations/.github`) have real `@main`-pinning blast radius
  but are currently uncovered by `[CI-050]` (≥3-consumer-repo trigger)
  and `[CI-052]` (visibility/tag trigger). Per principal's batch-close
  guidance ("do not draft the rule without explicit direction"), this
  is NOT a draft-the-rule item; it IS a "document the gap so the next
  audit-of-discipline doesn't re-discover it." A `[CI-053]` placeholder
  cross-reference in the existing rule corpus (e.g., a one-line note
  under `[CI-052]` reading "single-repo centralized-infra edits sit
  between `[CI-050]` and this rule and are presently uncovered;
  principal-deferred 2026-05-06") closes the rediscovery cycle without
  prescribing the resolution.

- [ ] **[research]** v1.2.0 follow-on for `ci-cd-security-review.md`:
  G10 closure note. The manifest landed (`aafbe80` pushed); two perms
  trimmed; remaining 10 deliberately-kept under dev-ergonomics
  rationale with two named revisit triggers (workflow exercises the
  grant; or branch protection on swift-institute/.github lands). Worth
  a brief v1.2.0 status update so the doc's G10 entry reflects the
  partial-resolution state rather than "unaddressed." Not urgent —
  fold into the next revision the doc gets, not a separate dispatch.
