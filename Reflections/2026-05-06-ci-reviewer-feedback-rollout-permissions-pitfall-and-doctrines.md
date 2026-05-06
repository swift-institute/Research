---
date: 2026-05-06
session_objective: Process reviewer feedback waves on the centralized CI/CD corpus (H1–H4, M1–M7, lows), execute the resulting decision-framework items (M3 DocC-on-Linux), codify principal-stated doctrines, and dispatch the cross-ecosystem-reuse research investigation
packages:
  - swift-institute/.github
  - swift-primitives/.github
  - swift-institute/Skills
  - swift-institute/Research
status: pending
---

# CI reviewer-feedback rollout, the permissions-chain pitfall, and two newly-codified doctrines

## What Happened

Continuation of the 2026-05-05 audit-driven CI/CD cohort. The session opened
with the full reviewer feedback paste (H1 footgun delete, H2 sparse-checkout
substitutions, H4 shell-injection fixes, M1 `create-github-app-token@v3`
upgrade, M2 workflow-level permissions hardening, M3 DocC-on-Linux migration,
M4 apple-simulator collapse proposal, M5–M7 deferrals, plus several lows).
Closed with `/reflect-session` + `/handoff CI/CD security review`.

**Cohort B Phase 1 — ci-ok aggregator** (commits `7085a18` universal +
`a96ef44` L1 wrapper). `jq --exit-status 'all(.result == "success" or .result
== "skipped")' <<< "$NEEDS_JSON"` against `toJson(needs)`; `if: ${{ always()
&& !github.event.repository.private }}`. Verified via canary on
swift-tagged-primitives.

**Cohort A1 — harden-runner audit-mode floor** (commits `3cd2e77` universal +
`0da5d4f` L1 + `3305980` lint-readme files). step-security/harden-runner
@v2.19.1 SHA-pinned, `egress-policy: audit`, applied to every job in the
universal reusable + L1 wrapper + the three lint-readme workflows. Codified
as `[CI-080]` (audit-mode floor + 1–2-week observation gate before
block-mode flip).

**M2 attempted and reverted** (`d1472bc` + `e37de6f` added; `ed688ca` +
`8df9286` reverted). Workflow-level `permissions: {}` deny-all default
applied to all 22 in-scope workflows. Both repos' next dispatches produced
`startup_failure`. Root cause: workflow_call chain is intersection-based —
caller_grant ∩ reusable_top_level ∩ reusable_per_job. Top-level `{}` on a
reusable caps the intersection at zero; per-job `contents: read` exceeds
zero → startup failure at parse time. Lesson saved as memory
`feedback_top_level_permissions_on_reusables.md` (07:54 → 08:22).

**M3 — DocC on Linux** (`d2bbd9c` migration + `7ac400d` fix-forward).
swift-docs.yml moved from `runs-on: macos-26` + `xcrun docc convert` →
`runs-on: ubuntu-latest` + `container: swift:${{ inputs.swift-version }}` +
`docc convert`. Fix-forward added `defaults.run.shell: bash` at job level —
`swift:6.3` container's default shell is `sh -e`, where `set -o pipefail`
is bash-only. Shape now matches every other linux-container job in the
corpus (`feedback_swift_image_minimal.md` from 2026-05-05).

**Reviewer-feedback waves processed in-session**:

| Item | Disposition | Commits |
|------|-------------|---------|
| H1 sync-ci-callers footgun | DELETE | `6e48342` (script + templates removed) |
| H2 curl-piped helper scripts | SPARSE-CHECKOUT | `f2a7b7d` + `2dcb888` + `70120c0` + `9806b93` (4 sites) |
| H4 shell-injection in input handlers | env: + `"$VAR"` PATTERN | `e6f6584` + `ab91a27` + `3305980` (5 files) |
| M1 `create-github-app-token@v1` → `@v3` | UPGRADE | `3305980` (3 readme workflows) |
| M2 workflow-level `permissions: {}` | ATTEMPTED → REVERTED | see above |
| M3 DocC on Linux | EXECUTED | see above |
| M4 collapse apple-simulator matrix | REJECT (uniform doctrine) | no commit |
| M5 advisory-graduation aggregator | DEFERRED | no commit |
| M6 cron-audit-base contract narrowing (H3) | DEFERRED | no commit |
| M7 release workflow + cosign (Cohort C) | DEFERRED until first tag | no commit |

**`git add -A` mistake → adoption recovery**. Cohort A1's mass commit
(`3cd2e77`) accidentally swept three untracked "Do Not Touch" lint-readme-*
files from a parallel SwiftLint-rollout supervisor's worktree into my
commit. Reactive `git rm --cached` was harness-denied. User authorized
"adopt" — I added M1+M2+H4+harden-runner fixes to the three files in
`3305980`. Memory rule for this scenario already existed at the time of
the mistake (`feedback_triage_dirty_worktree.md`, 2026-05-05): the
violation was a memory-consultation gap, not a missing rule.

**Two doctrines codified mid-session**:

1. **Uniform platform matrix doctrine** (`feedback_uniform_platform_matrix_doctrine.md`,
   08:34). Principal direction: *"for platforms, this is something we'll
   want to centralize and apply uniformly for now, so deriving from
   package.swift is not what we want, we want to have a broad matrix that
   ALL packages must adhere to. if package.swift doesn't support it, the
   package.swift is likely wrong."* Drove M4 REJECT.
2. **CI priority axes** (`feedback_ci_priority_axes.md`, 07:54).
   Correctness > security > speed; cost is NOT an axis (public-only repos
   = unlimited free runner minutes). Drove the decision-framework
   resolution that fed M3 GO + M4 REJECT + branch-protection-minimal.

**Cross-ecosystem reuse investigation dispatched**
(`HANDOFF-ci-cd-cross-ecosystem-reuse.md`). Branching investigation per
[HANDOFF-005] / [RES-020] Tier 2. Six questions across L2/L3 wrapper
justification, 11 sub-org routing, cross-org bot, third-party reuse,
bot-service expansion, migration shape. Findings exceeded 300 lines so
promoted to standalone `swift-institute/Research/ci-cd-cross-ecosystem-reuse.md`
v1.0.0 RECOMMENDATION; `_index.json` updated. Most consequential finding:
the architecture is already cross-ecosystem-ready — remaining work is
bookkeeping (org-secret + App-install coverage on the 13 orgs not yet
verified) plus codification of the empirical absences as `[CI-004a]` +
`[CI-004b]` skill amendments.

**Skill amendments landed** (`2823033` in `swift-institute/Skills`):
`[CI-080]` harden-runner audit-mode floor + block-mode-flip protocol added
to ci-cd-workflows. (`[CI-044]` Tool-Binary Cache + `[CI-070]` Composite-Action
Call-Site Eligibility landed yesterday in `9f36bd9`.) `last_reviewed`
bumped 2026-05-05 → 2026-05-06.

**Memory entries authored / refreshed today** (4 files):
`feedback_ci_priority_axes.md`, `feedback_top_level_permissions_on_reusables.md`,
`feedback_uniform_platform_matrix_doctrine.md`,
`project_pending_cicd_security_handoff.md` (queued followup for the
security-only handoff the user asked me to remind them of).

**HANDOFF scan**: 32 `HANDOFF-*.md` files at `/Users/coen/Developer` root.
Of those, 1 was authored / completed in this session
(`HANDOFF-ci-cd-cross-ecosystem-reuse.md` — Findings appended, RECOMMENDATION
promoted, **eligible for deletion** under [REFL-009] standard rule).
1 is from a parallel SwiftLint-rollout supervisor running concurrently
(`HANDOFF-r1r4-cleanup-wave-1.md`, May 6 08:44, in-flight) — out of this
session's cleanup authority per [REFL-009a]'s in-flight-conservativism
rule (no-touch). The remaining 30 are out-of-session-scope: from earlier
sessions (May 1–5), unrelated to today's CI/CD work.

**AUDIT scan**: 6 `AUDIT-*.md` files. The relevant one
(`AUDIT-centralized-ci-quality-and-refactor-inventory.md`) was the audit
brief that drove the F-series + PM-series cohorts; its Findings section
already carries RESOLVED markers from 2026-05-05. Today's reviewer
feedback was a separate reviewer-conducted review (NOT an in-session
`/audit` invocation), so [REFL-010] does not apply — disposition is
captured by commits and this reflection. Other AUDIT files are unrelated
to today's session.

## What Worked and What Didn't

**Worked**:

- **Decision framework with explicit priority axes**. Once the principal
  stated *"correctness > security > speed; cost is not a factor,"* the
  M4 REJECT became immediate (collapsing apple-simulator matrix would
  trade coverage for speed; speed loses) and the Cohort C DEFER became
  immediate (release workflow + cosign optimize for tag stability and
  attestation, neither of which is on the present roadmap). Without the
  axes, every decision item required ad-hoc principal arbitration; with
  them, all six items resolved in one pass.
- **Per-cohort canary verification before next cohort**. Cohort B Phase 1
  ci-ok went out via swift-tagged-primitives canary before Cohort A1
  shipped; Cohort A1 went out before M2 was attempted; M2 failed cleanly
  in canary (not against a tagged release) and was reverted within
  minutes. Per-cohort canary discipline absorbed the M2 failure with no
  downstream impact.
- **Branching investigation dispatch composability**. The cross-ecosystem
  reuse handoff (`HANDOFF-ci-cd-cross-ecosystem-reuse.md`) was authored
  in parallel with the in-session cohort execution; the parent session
  did not wait. Investigation returned with a concrete Tier 2
  RECOMMENDATION, including proposed `[CI-004a]` / `[CI-004b]` skill
  amendments that compose additively with the queued security handoff.
  No conflict on `Do Not Touch` files.
- **Memory-as-codification mid-session**. Three new feedback memories
  authored as the session produced their occasions
  (priority axes from the principal's framing message; uniform matrix
  from the M4 decision; permissions chain from the M2 failure). Future
  sessions consume these without needing to re-derive the rules.

**Didn't work**:

- **The M2 bulk-add was a category error**. Adding workflow-level
  `permissions: {}` to all 22 workflows in a single commit conflated two
  cases: standalone workflows (where deny-all + per-job grants is the
  correct security shape) and `workflow_call` reusables (where deny-all
  caps the intersection at zero). The Python script that did the bulk
  add did not distinguish trigger shape. A pre-commit canary on a single
  reusable would have surfaced the failure before the bulk commit; a
  pre-commit canary on a single standalone would have at minimum
  surfaced any per-job-grant gaps. Bulk-add discipline failed twice in
  one cohort.
- **The `git add -A` mistake**. The Cohort A1 mass commit `3cd2e77`
  accidentally captured three lint-readme-* files from a sibling
  agent's worktree because `git add -A` reads the entire working tree
  state, not just the files I intended to stage. The rule existed
  (`feedback_triage_dirty_worktree.md`); I did not consult it before
  the commit. The recovery (adoption with M1+M2+H4 fixes) was clean
  but it was recovery, not avoidance — the discipline should have
  fired pre-commit.
- **`harden-runner` block-mode protocol underspecified at codification
  time**. `[CI-080]` is correct but the audit-mode → block-mode flip
  protocol is described as "1–2 weeks of observation" without naming
  the concrete signals to look for, the dashboards to consult, or the
  threshold for "egress is now well-characterized." That gap will
  surface in 1–2 weeks when the flip is dispatched and the next agent
  has to re-derive the protocol. (Action item below.)

**Mixed**:

- **The reviewer-feedback paste as decision input**. Rich, well-classified
  feedback drove a clean cohort. But the M4 (collapse simulator) and M2
  (top-level permissions) items both required principal arbitration to
  resolve — the reviewer's framing biased toward "do this for cost/speed"
  in ways that conflicted with the principal's priority axes. Reviewers
  default to common-CI-wisdom (cost-conscious matrices, security-best-practice
  permissions) without knowing the specific axes for this ecosystem.
  Going forward, reviewer feedback is decision input, not decision output;
  arbitration against the priority axes is mandatory before action.

## Patterns and Root Causes

**Pattern 1: workflow_call permissions chain pitfalls are silent at
single-file scope and explosive at fleet scope.** A standalone workflow
with `permissions: {}` and per-job grants is a clean security improvement
in isolation. A reusable workflow with `permissions: {}` is a startup
failure in isolation. A bulk-add that mixes both produces a fleet-wide
outage at parse time. The intersection rule
(caller_grant ∩ reusable_top_level ∩ reusable_per_job) is non-obvious
because the *reusable's* top-level acts as a ceiling on the *caller's*
grant, which inverts the typical workflow-permissions mental model where
the workflow itself is the floor. Today's M2 incident is the second time
this class of pitfall has surfaced in this corpus (cf.
`feedback_workflow_call_permissions_chain.md` from 2026-05-05's
`continue-on-error` incident). The pattern: workflow_call composition
introduces parse-time-evaluated coupling between caller and reusable that
is invisible to per-file linting and only surfaces under bulk-rollout.
The fix at the skill level is a typed rule per workflow trigger shape
([on: workflow_call] vs [on: schedule|workflow_dispatch]) that prescribes
the correct top-level-permissions disposition; the rule must be
prescriptive enough that a Python bulk-add script can branch on trigger
shape rather than blanket-applying.

**Pattern 2: principal doctrine codification timing**. The uniform
matrix doctrine and the priority-axes principle were both stated by the
principal *during decision-framework discussion* — not in advance, not in
documentation. Both were captured into memory mid-session within minutes
of the statement. The pattern: principal direction issued as resolution
of a specific decision item is also a *general principle* that will drive
many future decisions. If the general principle is not codified
(memory + skill amendment) at statement time, every future decision in
that class re-rasies the question; the principal effectively re-states
the doctrine each time. Mid-session codification dissolves this. Today's
two memory entries for those doctrines pay forward — the next CI cohort
that touches platform matrices or weights cost against security gets the
answer from memory, not from re-asking. Skill-level codification (action
item below) hardens this further.

**Pattern 3: reviewer-feedback default biases against ecosystem-specific
constraints**. Reviewers operate on common-CI-wisdom priors (matrix-cost
matters; permissions deny-all is best-practice; release attestation
matters). For this ecosystem, several of those priors are wrong: cost is
not an axis (public repos, free minutes); release attestation is
premature (no tag yet); matrix coverage is the spec, not the cost
center. The pattern: external-reviewer feedback is a check on
ecosystem-specific blind spots ("what would a reviewer with no prior
context flag?") AND a source of potentially-misaligned defaults
("what does the typical CI reviewer expect?"). Both are valuable; the
key is to resolve through the ecosystem's stated priority axes rather
than treat reviewer feedback as authoritative. Today's session did this
correctly for M4 (REJECT against axes) and Cohort C (DEFER against
roadmap), and incorrectly for M2 (ACCEPT-then-revert when the trigger-shape
distinction was not respected). The lesson: reviewer feedback survives
arbitration against priority axes, not the reverse.

**Pattern 4: bulk operations multiply the cost of memory-consultation
gaps**. The `git add -A` mistake captured three files because the
working tree state was beyond my view. The relevant memory rule existed.
A 10-second memory-grep before `git add` would have caught it. This is
the [REFL-006] post-commit-memory-scan rule applied pre-commit: bulk
git operations (especially `add -A`, `commit -am`, `push --all`) deserve
a pre-operation feedback-memory grep proportional to their blast radius.
A `git add` of three named files in a single package is low-radius and
forgiving; a `git add -A` across an entire repository is high-radius and
catches sibling-agent state. Pattern provenance is consistent with the
existing rule's framing — the gap was operational, not definitional.

**Pattern 5: cross-ecosystem-reuse architecture vs activation timing**.
The investigation finding ("architecture is already cross-ecosystem-ready;
remaining work is bookkeeping") inverts the prior framing
(`feedback_workspace_scope_l1_only.md`: "active workspace scope is L1
only"). Both are simultaneously correct: the *centralization mechanism*
(three-tier reusable chain + composite actions + org bot + orgs.yaml)
is L1-active because L1 is the only org with App installed and secrets
provisioned, while the *centralization design* (universal reusable
callable from any public org-rooted repo) is org-agnostic and was
designed for fleet rollout from day one. The pattern: ecosystem-scope
framings often conflate *activation* with *capability*. Distinguishing
them prevents two failure modes: under-using the existing capability
("we'd have to rebuild that to extend to L2") and over-claiming
activation status ("L1-only means the L2 repos are safe").

## Action Items

- [ ] **[skill]** ci-cd-workflows: add a typed rule (proposed `[CI-090]`)
  prescribing top-level-permissions disposition by workflow trigger shape:
  `on: workflow_call` → no top-level `permissions:` block (or set to
  permissive max for any combined dispatch path), per-job grants only;
  `on: schedule|workflow_dispatch` (standalone) → `permissions: {}`
  top-level + per-job grants required on every job. Cite
  `feedback_top_level_permissions_on_reusables.md` for provenance and
  the M2 incident (`d1472bc`/`e37de6f` reverted by `ed688ca`/`8df9286`)
  as the worked example.
- [ ] **[skill]** ci-cd-workflows: codify the uniform-platform-matrix
  doctrine as a typed rule (proposed `[CI-091]`): the CI matrix is the
  canonical platform contract; packages MUST conform to the matrix, not
  the reverse. Per-package opt-out via `Package.swift`'s `platforms:`
  declaration is forbidden as a matrix-derivation source. Cite
  `feedback_uniform_platform_matrix_doctrine.md` for provenance and M4
  REJECT as the worked example.
- [ ] **[skill]** ci-cd-workflows: incorporate `[CI-004a]` (no L2/L3
  wrapper without documented invariants beyond the universal matrix) and
  `[CI-004b]` (3-tier direct routing for spec-authority sub-orgs) per
  the `swift-institute/Research/ci-cd-cross-ecosystem-reuse.md` v1.0.0
  RECOMMENDATION. The amendments are concrete and ready to land; the
  `lint-org-bot-coverage.yml` advisory linter named in Q5 is a separate
  Phase 0 deliverable, not a skill amendment.
