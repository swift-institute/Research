# CI Centralization Strategy

<!--
---
version: 1.1.0
last_updated: 2026-04-22
status: RECOMMENDATION
research_tier: 2
applies_to: [institute, primitives, standards, foundations, body-orgs]
normative: false
---
-->

## Context

### Trigger

CI/CD configuration is duplicated across ~280 repositories in the three target
orgs (`swift-primitives`, `swift-standards`, `swift-foundations`). Phase 0 of
the centralization effort (recorded in `HANDOFF-ci-centralization.md`) polished
`swift-property-primitives` into a reference case study using reusable
workflows (`uses: swift-institute/.github/.github/workflows/…@main`). Before
rolling out to 280+ repos, Phase 1 is to evaluate alternative centralization
strategies and record a durable recommendation so Phase 2+ doesn't churn.

### Scope

Ecosystem-wide [RES-002a]. Affects every public and private repo across the
three target orgs. Out of scope: `coenttb/*`, external-compat packages
(`swift-testing`, `swift-tracing`, `swift-http-routing`), rule-law ecosystem,
`swift-institute` sub-repos.

### Empirical state (2026-04-21)

Verified from source for this document:

- `swift-institute` org plan: **Free**
  (`gh api orgs/swift-institute --jq .plan.name` → `"free"`).
- GitHub's "required workflows" feature is **deprecated as of January 2024**
  and replaced by repository rulesets
  (`gh api repos/swift-institute/.github/actions/required_workflows` returns
  HTTP 422 with: *"this feature is fully deprecated and creating required
  workflows is only available with repository rulesets. All existing workflows
  have been automatically migrated to rulesets."*).
- Repository rulesets and organization rulesets are restricted to GitHub
  Team / Enterprise plans per GitHub docs
  ([About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)).
- Local rename cascade has not propagated to GitHub remotes: `gh api
  repos/swift-primitives/swift-rendering-primitives` → 200; `.../swift-render-primitives`
  → 404.

## Question

Which centralization strategy should the three Swift Institute orgs adopt
for CI/CD across ~280 repos?

Sub-questions:

- Is the reusable-workflow pattern (Phase 0) the right long-term foundation,
  or an interim that should yield to a different approach?
- What CI-adjacent configuration can also centralize, and by which mechanism?
- What is the right ref strategy for caller workflows (`@main` vs. tag)?

## Analysis

### Option A — Reusable workflows (`workflow_call`)

**Description**: Caller repos include a thin `.github/workflows/ci.yml`
whose jobs use `uses: swift-institute/.github/.github/workflows/<name>.yml@<ref>`.
All build/test/lint logic lives in the central `swift-institute/.github` repo
and is consumed at run time. Current Phase 0 pattern.

Inputs and secrets flow through explicit `with:` and `secrets:` blocks. The
reusable workflow can declare `permissions:`, `timeout-minutes:`, and complex
multi-job matrices; the caller owns only triggers, concurrency, and overrides.

**Advantages**:

- Zero GitHub plan cost — a free-plan public `.github` repo serves every
  consumer.
- Validated: Phase 0 empirically tested on `property-primitives`
  (swift-format bundled in Swift 6.3 toolchain; prebuilt SwiftLint binary;
  full DocC pipeline), all exit codes and config-loading paths verified.
- Flexible per-repo customization via inputs — the reference case study shows
  `umbrella-module`, `exclude-modules`, `paths`, `swiftlint-version` as
  override points.
- Standard GitHub Actions mechanism since October 2021, documented at
  [Reusing workflows](https://docs.github.com/en/actions/how-tos/sharing-automations/reusing-workflows).

**Disadvantages**:

- Opt-in: each caller must declare the `uses:` reference. A repo with no
  caller gets no CI.
- Shared fate on the ref: `@main` means a compromise or regression in
  `swift-institute/.github@main` breaks every consumer simultaneously. Tag
  pinning mitigates this at a release-discipline cost.
- Caller file stays in every repo (cannot be removed without losing CI).

**Constraints**: GitHub Actions ecosystem only. Reusable workflows can call
other reusables (up to 4 levels deep per GitHub docs), but cannot be used
from GitLab / Bitbucket / Jenkins.

---

### Option B — Repository / organization rulesets

**Description**: GitHub's replacement for the deprecated "required workflows"
feature. A ruleset at the repo or org level can declare that certain checks
must pass before merge. Combined with a workflow file (inline or reusable),
the ruleset enforces that CI ran and passed. Rulesets can be scoped to
specific branches (e.g., `main`) and bypassed by named actors.

**Advantages**:

- **Enforcement** rather than convention — repos cannot merge bypassing CI
  without an explicit bypass path.
- Org-level rulesets apply to every repo in the org, including newly created
  ones, without per-repo setup.
- Co-exists with reusable workflows: the ruleset points at the same
  workflow file; rulesets enforce *that it ran*, reusables define *what it
  does*. They are complementary, not alternative.

**Disadvantages**:

- **Not available on GitHub Free** per GitHub's
  [ruleset docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets):
  repository rulesets require Team or Enterprise; organization rulesets
  require Enterprise. The swift-institute org is Free today.
- Requires ongoing plan spend — a commitment this research doesn't justify
  on its own.
- Does not replace workflow files; it only enforces they run. The workflow
  files themselves still need to exist in each repo (inline or as reusable
  callers). Rulesets are additive to Option A, not alternative to it.

**Constraints**: Plan gate. Rulesets configured at org level need
`admin:org` scope for API access
(`gh api orgs/swift-institute/rulesets` → 404 in this investigation due to
scope, not because rulesets don't exist — but the plan gate is independent).

---

### Option C — Git subtree / submodule of `.github/`

**Description**: Each consumer repo pulls a shared `.github/` directory as a
git subtree or submodule, vendoring the workflow files in-repo and synced via
`git subtree pull` or `git submodule update`.

**Advantages**:

- Each repo carries its own pinned copy at a specific commit.
- Works with any CI provider (no GitHub Actions lock-in).

**Disadvantages**:

- Poor developer experience: every clone / fresh checkout needs submodule
  init; subtree `pull` is error-prone with squashed histories; merge
  conflicts on the subtree path are tedious.
- No advantage over the sync-script model (Option D) for workflow
  distribution — both push files into each repo. Subtree adds a git-level
  machinery layer for no win.
- Prior research (`git-subtree-publication-pattern.md`, 2026-02-26, Tier 2
  DECISION) rejected subtree for package publication on similar grounds.
  The team's existing stance weighs against reintroducing it here.

**Constraints**: Requires contributors to have subtree / submodule familiarity
or tolerate the friction.

---

### Option D — Sync-script model

**Description**: Canonical template in `swift-institute/Scripts/` plus a
sync script that overwrites the target file in every sub-repo. Pattern
already established by:

- `sync-gitignore.sh` (2026-03-12 `gitignore-sync-strategy.md` DECISION)
- `sync-community-health.sh` (org-level community health files)
- `sync-dependabot.sh` (Phase 0b this session)
- `sync-skills.sh` (skills symlinks)
- `sync-swift-settings.sh` (Package.swift SwiftSettings)

**Advantages**:

- No runtime dependency on a central repo — once synced, each consumer runs
  independently. Survives `swift-institute/.github` outages.
- Works for any file: workflow YAML, config files, scripts. Already a
  team idiom with four sibling scripts.
- Explicit commit trail per sync. Easy to audit what changed when.

**Disadvantages**:

- Drift between syncs: a repo's local file can diverge until the next sync
  run. Not a problem for infrequently-changing configs; would be a problem
  for rapidly-iterated CI logic.
- Not reactive: changes to the canonical template propagate only when
  someone runs the sync script.
- Commit burst: a single template change produces N commits across N repos,
  which is noisy in dashboards and tool analytics.

**Constraints**: The maintainer (or CI job) must run the sync. If the
maintainer forgets, repos drift silently.

---

### Comparison

| Criterion                      | A: Reusable | B: Rulesets | C: Subtree | D: Sync-script |
|--------------------------------|-------------|-------------|-----------|----------------|
| Plan cost (2026-04-21)         | Free        | Team+       | Free       | Free           |
| Enforcement                    | No (opt-in) | Yes         | No        | No             |
| New-repo auto-coverage         | No          | Yes (org)   | No        | Yes on sync    |
| Latency of central change      | 0 s (next run) | 0 s      | Manual    | Manual         |
| Offline from central repo      | Breaks      | Breaks      | Works     | Works          |
| Blast radius of central compromise | High   | High        | Low       | Low            |
| DX for contributors            | Easy        | Easy        | Poor      | Easy           |
| Suits rapidly-iterating logic  | Yes         | Yes         | No        | No             |
| Suits per-repo static config   | No          | N/A         | Yes       | Yes            |
| Already in use in ecosystem    | Yes (Phase 0) | No        | No        | Yes (4 scripts) |

**Interpretation**: Options A and D are complementary along the "rapidly
iterating logic" vs. "per-repo static config" axis. Option B requires a plan
upgrade and is additive to A, not alternative. Option C offers no advantage
over D for workflow distribution.

---

### What else can centralize?

Phase 1's second question: which CI-adjacent configurations should move,
and under which mechanism?

| Artifact                        | Mechanism     | Status |
|---------------------------------|---------------|--------|
| Build/test/docs/format/lint workflows | A (reusable) | In place Phase 0 |
| `dependabot.yml`                | D (sync script) | Template + script delivered Phase 0b; sync deferred |
| `.gitignore`                    | D (sync script) | In place since 2026-03-12 (`sync-gitignore.sh`) |
| `.swift-format`, `.swiftlint.yml` | D (sync script) | In place via `sync-swift-settings.sh` and/or `sync-gitignore.sh` — verify coverage |
| Org-level community health (CODE_OF_CONDUCT, CONTRIBUTING, GOVERNANCE, etc.) | GitHub inheritance from `swift-institute/.github` | In place; `GOVERNANCE.md` added Phase 0b |
| `swift-tools-version` in Package.swift | D (sync script) candidate | Not yet automated; candidate for Phase 1 extension |
| `Package.swift` `platforms:` blocks | D (sync script) candidate | Not yet automated; candidate if drift becomes a problem |
| DocC build paths / umbrella names | A (workflow input — already `umbrella-module:` etc.) | In place via `swift-docs.yml` inputs |
| Release workflows (tag → GitHub Release) | A (reusable, future) | Not yet designed; Phase 1+ |

`swift-tools-version` is the most promising next candidate for sync — a
single line in every Package.swift that should move in lockstep across the
ecosystem when the toolchain floor bumps. `Package.swift platforms:` blocks
drift freely today; whether that's a problem is a Phase-2 observation.

---

## Prior art survey [RES-021]

- **Apple's own ecosystem**: `apple/swift-foundation`, `apple/swift-collections`,
  `apple/swift-syntax` use per-repo inline workflows, not reusable workflows.
  Each repo is large enough to justify its own CI config. Not directly
  applicable to a 280-repo ecosystem.
- **Large monorepos moving to reusables**:
  [microsoft/vscode](https://github.com/microsoft/vscode),
  [angular/angular](https://github.com/angular/angular) use `.github/`
  directories with org-level reusables + repo-level triggers — similar to
  Option A in shape. They operate at 10k+ star scale with paid plans, so
  they also layer rulesets on top (Option A + Option B hybrid).
- **The `.github` repo pattern** is documented by GitHub as
  [org community health defaults](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file).
  The extension to hosting reusable workflows there is a community idiom, not
  a formally-documented pattern, but is widely used (e.g.,
  [pointfreeco/.github](https://github.com/pointfreeco) for the
  `pointfreeco` org's shared workflows).
- **Contextualization step per [RES-021]**: "required workflows" (now
  rulesets) is universally adopted in enterprise CI systems (Jenkins shared
  libraries, GitLab CI `include:`, CircleCI orbs). In a Free-plan GitHub
  setting, Option A + Option D is the closest analogue that does not require
  plan escalation. The absence of enforcement is a real trade-off — repos
  can silently skip CI — but the cost of escalating plans for 280 repos is
  non-trivial, and the lint/format gates already enforce themselves at PR
  review time.

## Recommendation

**Status**: RECOMMENDATION.

### Primary strategy

**Adopt Option A (reusable workflows) as the foundational pattern** for
cross-cutting CI logic: build/test matrix, DocC, format, lint. Phase 0
validated this empirically on `property-primitives`; the reusables handle
version drift (swift-format bundled in Swift 6+), install optimization
(prebuilt SwiftLint binary), and full DocC aggregation. The design is in
production shape.

### Secondary strategy

**Adopt Option D (sync-script model) for operational per-repo configs**
that reusable workflows cannot address: `dependabot.yml`,
`.swift-format`, `.swiftlint.yml`, `.gitignore`, and future candidates like
`swift-tools-version`. The ecosystem already uses this pattern for four
other artifacts; Phase 0b added the fifth (`sync-dependabot.sh`). Continue
extending.

### Reject

- **Option B (rulesets)**: unavailable on the current Free plan and
  strictly additive to A rather than alternative. Revisit if/when the org
  upgrades to Team plan for some other reason.
- **Option C (subtree/submodule)**: no advantage over D for workflow
  distribution; poor DX; prior research already rejected subtree in a
  parallel decision.

### Ref strategy for callers

Phase 0 uses `@main`. Recommend moving to **`@v1` tag pinning** once Phase 0
lands to origin:

- Tag `swift-institute/.github@v1.0.0` after Phase 0 merges.
- Update `property-primitives` callers to `@v1`.
- Treat `@v1` as a rolling tag — bump it to the tip of main on reusable
  changes that are non-breaking.
- Bump to `@v2` for breaking changes in the reusable-workflow input surface.

This matches common reusable-workflow practice in the Actions ecosystem
(e.g., `actions/checkout@v6` — the user pins a major tag that tracks
compatible patches). It narrows the blast radius of a `@main` compromise
(Phase 0's one remaining open concern) without requiring per-SHA pin
discipline.

### Optional future layer

If the org later upgrades to Team plan for private-repo rulesets or other
reasons, add **Option B (rulesets) on top of Option A** to enforce that CI
runs on every PR. This is additive, not replacing. No need to wait for it
to start Phase 2.

---

## Implementation path

Phase-by-phase sequencing for acting on this recommendation:

1. **Phase 0 + 0b commit + push** (user action, unchanged from HANDOFF):
   push `swift-institute/.github` (central first) then `swift-property-primitives`.
2. **Tag `swift-institute/.github@v1.0.0`** once pushed. Update
   `property-primitives` callers from `@main` to `@v1`. Verify CI green.
3. **Run `sync-dependabot.sh`** across 280 repos (template + script already
   delivered Phase 0b; 282 of 283 would update per dry-run). Review the
   first handful of PRs it generates on unchanged repos to confirm
   expected behavior.
4. **Community-health file inheritance audit**: sweep the three orgs for
   local copies of `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`,
   `FUNDING.yml`, `GOVERNANCE.md`. Delete redundant local copies so they
   inherit from `swift-institute/.github`.
5. **GitHub remote-name reconciliation**: the 60-commit local rename cascade
   (`swift-rendering-primitives` → `swift-render-primitives` etc.) has not
   propagated to GitHub. Phase-2 rollout scripts must either rename via `gh
   api` first or key on the remote names. Sample-verified: old names
   still resolve; new names do not.
6. **Phase 2 (pilot)**: apply the reference-case pattern to one additional
   primitive (e.g., `swift-buffer-primitives`, `swift-render-primitives`
   after its GitHub rename). Verify CI green before batching.
7. **Phase 3 (rollout)**: script migration across remaining ~280 repos. Use
   the Phase 2 pilot as the template commit.
8. **Ongoing**: periodic `--dry-run` on each sync script to surface drift.
   Consider a weekly scheduled workflow in `swift-institute/.github` that
   runs all sync dry-runs and opens issues on drift.

---

## Permission scoping [added 2026-04-22]

Orthogonal axis to the centralization mechanism analysed above: once
reusable workflows (Option A) carry a `permissions:` declaration that
requests `contents: write` (e.g., the swift-format auto-commit
workflow), *where* should the matching grant be declared — at the
caller job level, or via org-level `default_workflow_permissions`?

### Mechanism

Reusable-workflow permissions follow an intersection rule: the
effective `GITHUB_TOKEN` scope for a job equals *intersection(caller's
permissions, reusable's declared permissions)*. If the caller inherits
the org default `read` and the reusable requests `write`, the
intersection collapses to `read` and GitHub's pre-flight validator
rejects the run with `startup_failure`
(<https://docs.github.com/en/actions/how-tos/sharing-automations/reusing-workflows#access-and-permissions>).

### Options

- **Path A — Org-level write default**: set `default_workflow_permissions
  = write` across the 11 orgs. Single point of maintenance; every
  workflow in every repo gets `contents: write` by default. Matches
  the pre-migration inline-workflow effective state.
- **Path B — Per-caller granular**: keep orgs read-only; declare
  `permissions: contents: write` at the caller job level of the
  swift-format caller template. Explicit, self-documenting. Aligned
  with GitHub's post-2023 default-read-plus-opt-in guidance.
- **Path C candidates** (all rejected or absorbed):
  - Per-repo `default_workflow_permissions`: strictly worse than A or B.
  - Architectural removal of auto-commit (PR-based instead): overkill
    for a format-on-push loop.
  - Replace `GITHUB_TOKEN` with a PAT/App in the auto-commit step:
    defer unless branch protection on `main` later blocks GITHUB_TOKEN.
  - Hybrid (org-read + per-caller overrides): this *is* Path B.

### Comparable-ecosystem survey (2026-04-22)

| Org / repo | Pattern | Evidence |
|---|---|---|
| `swiftlang/github-workflows` | Top-of-file caller-level permissions | `pull_request.yml` line 3 |
| `apple/swift-nio` | Top-of-file caller-level permissions; calls `swiftlang/github-workflows/.github/workflows/soundness.yml@0.0.10` (tag-pinned) | `pull_request.yml`, `main.yml` line 3 |
| `pointfreeco/swift-composable-architecture` | Job-level caller permissions | `format.yml` line 14 |
| `vapor/vapor` | Per-job permissions (read on test jobs, write on submit-dependencies) | `test.yml` |

All four declare permissions at the caller level (workflow or job).
None rely on org-level write defaults. apple/swift-nio's topology is
the closest shape-match to Swift Institute's many-repos-shared-
reusable pattern.

### Recommendation: Path B

Rationale (context-specific for Swift Institute, not generic best-practice appeal):

1. **Migration asymmetry.** B→A later is ~15 minutes (delete template
   block, flip 11 org defaults). A→B later scales with accumulated
   workflow complexity — audit every workflow in every repo for hidden
   `contents: write` reliance, retrofit per-caller declarations, then
   tighten org defaults. Start-of-project is the cheapest moment to
   pick B: callers are all template-generated from a single tool.
2. **Ecosystem calibration.** Unanimous per-caller declaration across
   the four surveyed Swift orgs is a signal about where long-lived
   ecosystems converge. Supporting data, not decisive on its own.
3. **Optionality.** B remains correct under all flip conditions below
   (external contributors, compliance, GitHub policy changes); A
   requires rework under any of them.

The user's initial instinct was Path A on maintenance grounds. The
single-admin / pinned-actions / no-compliance context legitimately
weakens the canonical least-privilege argument. The instinct was
overridden not on generic grounds but on the three specific points
above — with the explicit note that reversibility (not security) is
the load-bearing argument.

### Rollout outcome (2026-04-22)

Execution: edit `Scripts/ci-caller-templates/swift-format.yml.tmpl`
(+2 lines at caller job level), regenerate 297 callers via
`sync-ci-callers.sh`, push in phased waves (canary → 10 → 52 → 234).

Across all 297 migrated callers:

| Outcome | Count | Meaning |
|---|---|---|
| Success (verified green) | 87 | All public repos. Swift Format runs to completion; no more `startup_failure`. |
| Failure — billing annotated | 82 | Private repos where a run is created then halted with *"recent account payments have failed or your spending limit needs to be increased"*. |
| Private silent — no run | 59 | Private repos where the spending-limit block prevents run creation entirely; same root cause, different surface. |
| Actions fully disabled | 69 | Private repos where Actions is turned off at repo or org level; no runs, no annotations. |
| **Total** | **297** | |

**Path B is verified on 100% of repos where Actions can run.** The
permissions block is correctly encoded in every caller — the
ecosystem is in the right state the moment billing resolves, no
re-push needed.

### Private-repo billing/Actions state (durable note)

The 210 private repos split into three distinct layers of "blocked":

1. **Annotated billing failure** (82 repos): GitHub creates the run,
   then emits a billing annotation and fails it. Visible in the
   Actions UI with the standard payment-failure text.
2. **Silent billing halt** (59 repos): same root cause (spending
   limit), but GitHub does not create the run at all. Empty
   conclusion, no annotation. Distinguishable from (3) by
   `gh api repos/X/actions/permissions --jq .enabled` returning `true`.
3. **Actions fully disabled** (69 repos): Actions is off at the repo
   or inherited org level. `gh api repos/X/actions/permissions --jq
   .enabled` returns `false`. No runs ever attempt.

These three states pre-existed Path B and apply equally to the CI
(`swift-ci.yml`) and SwiftLint (`swiftlint.yml`) caller workflows —
they just don't surface as visibly because those reusables declare
`contents: read`, which works regardless of billing / Actions state
until a runner is actually needed. Future investigators reading this
section should NOT mistake these private-repo failures for Path B
regressions; they are pre-existing ecosystem conditions exposed, not
caused, by the rollout.

### Conditions to revisit

- External contributors with write access join the ecosystem →
  reinforces B, no change.
- Compliance / audit framework adoption → reinforces B, no change.
- >5 workflows emerge requiring `contents: write` → slight pressure
  to re-evaluate A; reusables already centralise logic, so only per-
  caller declarations distribute.
- Branch protection on `main` blocks `GITHUB_TOKEN` pushes →
  revisit the PAT/App auto-commit path, not A-vs-B.
- GitHub changes reusable-workflow permission semantics → revisit
  both; no signal currently.
- Billing resolves and private repos come online → verification
  back-fills automatically; nothing to re-execute.

Review cadence: annually, or on any flip condition above.

### Provenance

Investigation: `HANDOFF-ci-permission-architecture.md` (2026-04-22).
Findings section of that handoff carries the full threat-model detail
and decision log; this section consolidates the durable conclusion
per [META-016].

---

## References

Verified during this investigation:

- [HANDOFF-ci-centralization.md](/Users/coen/Developer/HANDOFF-ci-centralization.md) — Phase 0/0b execution record
- [git-subtree-publication-pattern.md](git-subtree-publication-pattern.md) — prior rejection of subtree for adjacent problem
- [gitignore-sync-strategy.md](gitignore-sync-strategy.md) — sync-script precedent
- [multi-repo-automation-design-patterns.md](multi-repo-automation-design-patterns.md) — batch-automation state-axis design

GitHub documentation:

- [Reusing workflows](https://docs.github.com/en/actions/how-tos/sharing-automations/reusing-workflows)
- [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [Creating a default community health file](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file)
- [Deprecation notice — required workflows](https://github.blog/2023-10-11-enforcing-code-reliability-by-requiring-workflows-with-github-repository-rules/) (January 2024 migration)

Empirical probes (2026-04-21):

- `gh api orgs/swift-institute --jq .plan.name` → `"free"`
- `gh api repos/swift-institute/.github/actions/required_workflows` → HTTP 422 deprecation notice
- `gh api repos/swift-institute/.github/rulesets` → `[]`
- `gh api repos/swift-primitives/swift-rendering-primitives` → 200 (old name still on GitHub)
- `gh api repos/swift-primitives/swift-render-primitives` → 404 (local rename unpropagated)
