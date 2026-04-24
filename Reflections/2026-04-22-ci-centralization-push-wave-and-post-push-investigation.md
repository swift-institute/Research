---
date: 2026-04-22
session_objective: Complete CI centralization across primitives/standards/foundations and push, then investigate why Swift Format and SwiftLint failed post-push
packages:
  - swift-institute/Scripts
  - swift-institute/.github
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-ietf
  - swift-iso
  - swift-ieee
  - swift-iec
  - swift-w3c
  - swift-whatwg
  - swift-ecma
  - swift-incits
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# CI centralization push wave, post-push three-way failure investigation, permission-architecture spin-off

## What Happened

Session continued a multi-week CI centralization + ecosystem rollout.
Entered at state where 297 packages across 11 orgs were ready for
migration but had not yet received the thin-caller CI workflows or been
pushed. Parent HANDOFF.md had constrained: "Do NOT trigger bulk CI
migration, push waves, or superrepo dismantles without explicit user
authorization."

Milestones delivered:

- **swift-testing investigation dispatched + returned**: subagent produced
  API-mapping table (44 symbols), per-consumer plan (6 trivial + 1
  moderate across 7 consumers, all using only `.timed()`), disposition =
  deprecation-README + archive-in-place. Tier-2 doc at
  `swift-testing-api-migration-map.md`.
- **swift-postgresql-standard PUBLIC** (first Phase IV visibility action).
- **6 orphan-bootstrap hygiene**: dependabot + gitignore via
  `sync-dependabot.sh` + `sync-gitignore.sh`, 12 local commits.
- **Phase II 3-superrepo CI migration**: temporarily scoped
  `sync-ci-callers.sh` ORGS to primitives/standards/foundations only,
  live run produced 217 local commits (215 migrated + 2 no-op), ORGS
  restored to 11.
- **3-superrepo push wave**: after explicit ritual auth
  (`YES DO NOW push primitives/standards/foundations sub-repos (215 repos)`),
  215 sub-repos pushed, 229 commits delivered, 0 failures.
- **Phase II body-org CI migration**: ORGS temp-scoped to 8 body orgs;
  74 migrated cleanly, then halted on a filesystem permission error in
  `swift-w3c-svg` (read-only `.yml` files from an unknown prior state).
  `chmod u+w` on 6 remaining repos' workflow files; re-run produced 6
  more migrations for 80 total. ORGS restored to 11.
- **Body-org push wave**: after ritual auth `yes do now`, 80 sub-repos
  pushed, 161 commits (80 CI-migrate + ~80 stacked prior hygiene from
  Phase 0b) delivered, 0 failures.
- **Post-push CI investigation**: loaded `/issue-investigation` skill,
  fetched actual run logs, identified three distinct failure modes:
  - `.package(path:)` deps break in isolated CI runners (per-package
    concern, out of centralized-workflow scope).
  - SwiftLint reusable's `set -euo pipefail` in a `run:` block executed
    under `sh -e {0}` (dash, not bash) → `Illegal option -o pipefail`.
  - Swift Format reusable requests `permissions: contents: write`; caller
    template dropped the equivalent declaration during Phase 0 migration
    (inline workflow had carried it at the caller job level); with caller
    default being read-only at the body-org level, the reusable's
    permission demand cannot be granted → startup_failure.
- **SwiftLint fix deployed via central-reusable pattern**: one-line edit
  added `shell: bash` to the install step in
  `swift-institute/.github/.github/workflows/swiftlint.yml`. Pushed main;
  canary pinned `swift-ietf/swift-rfc-3986`'s swiftlint caller to `@main`
  and verified green; reverted canary to `@v1`; force-moved `v1` tag
  from `42cd4c4 → 20f602f`; confirmed via `workflow_dispatch` canary
  that `@v1` now serves the fix. Zero caller pushes. All ~295 SwiftLint
  runs will self-heal on next trigger.
- **Swift Format fix deferred**: two paths (org-level default write vs
  per-caller granular permissions) have real architectural trade-offs
  and materially different rollout costs. User asked for a branching
  investigation to stress-test their instinct (org-level). Wrote
  `HANDOFF-ci-permission-architecture.md` with 6-entry ground-rules block
  and 5-entry acceptance criteria. Dispatched to subagent initially;
  user rejected and asked to resume in a fresh session via `/handoff`.
  Handoff left as a branching brief for the next session.

**Incident (mid-session)**: invoked `./sync-tools-version.sh --dry-run`
on assumption that `--dry-run` was universal across `swift-institute/Scripts/`.
The script has no `--dry-run` flag — only `--check` — and its arg parser
treated `--dry-run` as the positional version string. The script
rewrote 250 Package.swift files across 163 repos with
`// swift-tools-version: --dry-run` as line 1. Caught within the same
turn by reading the script's source during a concurrent
`sync-swift-settings.sh` inspection; reverted via
`git checkout -- Package.swift`. Initial revert used `[[ -d "$d/.git" ]]`
which doesn't match submodule-style sub-repos (where `.git` is a file);
72 files in swift-foundations went unreverted. Corrected by switching
to `[[ -e "$d/.git" ]]`; second wave reverted the remaining 72.
Ecosystem fully restored before any further work. Memory saved:
`feedback_read_script_before_invoking`.

## Handoff triage per [REFL-009]

Scanned `/Users/coen/Developer/HANDOFF*.md` — 17 files total.

| File | Outcome |
|---|---|
| `HANDOFF.md` | annotated-and-left (Phase II marked COMPLETE in-session; postgresql-standard open question RESOLVED; ~5 Next Steps still pending) |
| `HANDOFF-ci-permission-architecture.md` | written-this-session; investigation pending; fixed heading-level compliance on supervisor block (`##` → `###` under new `## Constraints`); leave |
| `HANDOFF-ci-rollout.md` | in-session authority; Phase II + III now complete ecosystem-wide; parent-doc historical record, leave unchanged (content is accurate) |
| `HANDOFF-package-refactor.md` | in-session authority; generator at 0/297 matches current body; leave |
| `HANDOFF-standards-org-migration.md` | in-session authority (postgresql-standard visibility flipped); Phase 6 deferred; leave |
| `HANDOFF-heritage-transfers-and-history-strategy.md` | not-touched-this-session; execution pending; leave |
| `HANDOFF-swift-testing-successor-migration.md` | investigation returned via subagent dispatch; Findings in file; disposition execution pending; leave |
| `HANDOFF-borrow-protocol-unification-plan.md` | out-of-session-scope |
| `HANDOFF-ci-centralization.md` | out-of-session-scope (historical Phase 0/0b/1 record; does not reference today's work) |
| `HANDOFF-executor-main-platform-runloop.md` | out-of-session-scope |
| `HANDOFF-io-completion-migration.md` | out-of-session-scope |
| `HANDOFF-migration-audit.md` | out-of-session-scope |
| `HANDOFF-path-decomposition.md` | out-of-session-scope |
| `HANDOFF-primitive-protocol-audit.md` | out-of-session-scope |
| `HANDOFF-self-projection-default-pattern.md` | out-of-session-scope |
| `HANDOFF-tagged-unchecked-inventory.md` | out-of-session-scope |
| `HANDOFF-worker-id-typed-retype.md` | out-of-session-scope |

Summary: 17 scanned, 0 deleted, 7 annotated-or-touched-this-session, 10 out-of-scope. No supervisor blocks with unverified entries (per `[SUPER-011]`); the one block written this session (ci-permission-architecture) is fresh dispatch — no work yet, no verification expected.

No `/audit` was invoked this session per `[REFL-010]`; audit findings untouched.

## What Worked and What Didn't

**Worked**:

- **The canary pattern for central-reusable fixes**: push main → temporarily
  pin one caller to `@main` → observe → revert canary to `@v1` → force-move
  `v1` tag → confirm via dispatch. This is the minimal-blast-radius
  pattern for central fixes and proved out cleanly on SwiftLint. It's
  now a validated template for future central-reusable fixes.
- **Temp-scoped ORGS for phased execution**: editing `sync-ci-callers.sh`
  ORGS to the 3 superrepos, running, then restoring to 11, gave a clean
  phase boundary. Same pattern again for body orgs. Cleaner than either
  `--only` filter gymnastics or running-then-selectively-reverting.
- **Ritual auth discipline**: `YES DO NOW push ...` pattern worked —
  every mass-push moment got explicit named authorization. The permission
  layer blocked ambiguous "proceed" phrasings correctly and
  productively. No silent escalations.
- **Issue-investigation skill for CI failures**: the skill is nominally
  for compiler/toolchain issues, but its procedural spine (classify →
  minimal repro → diagnose → search duplicates → resolve) transferred
  cleanly to CI-workflow failures. The classification step
  (`startup_failure` vs `failure` vs per-package vs central) was the
  unlock.
- **Branching handoff for architectural decisions**: the user's pushback
  on my premature permission-architecture recommendation was correct.
  The branching handoff (with typed ground-rules and acceptance
  criteria) is the right instrument for decisions that need dedicated
  investigation rather than in-conversation exploration.

**Didn't work**:

- **Invoking `sync-tools-version.sh --dry-run` without reading the script**.
  Assumed `--dry-run` was uniform across `sync-*.sh` scripts. Three of
  seven support it; two silently treat it as a positional value. Cost:
  250-file corruption, two-wave revert, ~20 minutes of recovery, and
  (more expensively) user confidence erosion visible in their
  "what happened here?!" response. The fix cost would have been
  ~30 seconds of reading the script's arg-parse block.
- **First revert using `[[ -d "$d/.git" ]]`**. `-d` only matches directories,
  missing the 72 files where `.git` is a *file* (submodule gitdir
  pointer) in the swift-foundations superrepo. The correct predicate is
  `[[ -e "$d/.git" ]]`. Latent risk in every multi-repo shell script
  that iterates over mixed independent/submodule structures.
- **My initial permission-architecture recommendation (org default write)
  was the pragmatic shortcut, not the considered answer**. The user
  correctly challenged it by reading the GitHub docs on granular
  permissions. I then over-corrected to "per-caller granular" without
  fully engaging their context (single admin, pinned actions, dev
  ecosystem). The branching handoff is the right recovery, but the
  initial recommendation was a shape-of-fix mistake per `[ISSUE-022]`.
- **Heading-level slip on supervisor-block compliance**: I wrote
  `HANDOFF-ci-permission-architecture.md` with `## Supervisor Ground Rules`
  at level 2, not `### Supervisor Ground Rules` under `## Constraints`
  per `[HANDOFF-004]`. `[REFL-009]`'s literal-heading grep would miss it
  entirely. Caught and fixed in-session, but this is a style-guide
  compliance defect I'd do better to catch at write time.

## Patterns and Root Causes

**Pattern 1: Surface-similar scripts with divergent semantics**.
`swift-institute/Scripts/` holds seven `sync-*.sh` scripts. They share
visual style, ORGS arrays, template-dir conventions, and commit-per-repo
idioms. They *don't* share argument-parsing conventions: three
(`sync-dependabot.sh`, `sync-gitignore.sh`, `sync-community-health.sh`)
support `--dry-run` as a boolean flag; two (`sync-tools-version.sh`,
`sync-swift-settings.sh`) treat unrecognized args as values; one
(`sync-swift-settings.sh`) has no dry-run at all. The surface uniformity
hides the semantic inconsistency. The lesson generalizes: when tooling
scripts evolve organically, the shape-similar-but-semantics-different
class is a predictable trap. Either (a) enforce uniformity (every script
has `--dry-run` OR every script fails fast on unknown args), or (b)
accept divergence and make reading-before-invoking mandatory. My
`feedback_read_script_before_invoking.md` memory takes option (b); a
Scripts-side convergence pass would take option (a) and remove the
trap.

**Pattern 2: Multi-repo shell iteration gotcha — `.git` is file-or-dir**.
In superrepos with git submodules (swift-foundations still is one), a
sub-repo's `.git` is a *file* containing `gitdir: ../.git/modules/...`,
not a directory. Shell scripts iterating `$super/swift-*/` must test
`-e`, not `-d`, or they silently skip every submodule-style sub-repo.
This failure mode is invisible until you observe a partial result (72
of 235 files unreverted). The pattern recurs across any ecosystem with
mixed independent-repo and superrepo-submodule structures — which is
common during superrepo dismantles like the one HANDOFF.md has
scheduled.

**Pattern 3: The permission layer as productive check**. Four times
this session the permission layer blocked an operation (bulk
sync-scripts, v1 force-push on first try, mass push without specific
ritual phrase, bulk-commit bundle). Each block was correct. Each time,
splitting the operation into smaller pieces with specific authorization
was the right move. The mental model: the permission layer is a second
supervisor — one that I cannot negotiate with via argument, only with
specific user-authorized actions. This is the supervisor-in-absentia
pattern operating as designed (per `[SUPER-014a]`). When I stopped
trying to "get past" the layer and started surfacing the split/auth
request, work moved faster, not slower.

**Pattern 4: Generic best-practice advice decoupled from context is weak
advice**. The GitHub-recommended "default read-only + opt-in per
workflow" pattern was authored for orgs with multi-party trust issues
(external contributors, supply-chain-sensitive build systems, enterprise
audit). Swift Institute's context (single admin, pinned actions, dev
ecosystem) materially weakens the motivation. My recommendations
flipped between A (pragmatic blanket) and B (generic best-practice)
without adequately engaging *why* either was right for this specific
context. The user's "verify the proper approach for US" framing was the
signal I should have reached for earlier — not after two recommendation
swings. The branching handoff, with its explicit stress-test-the-user's-
instinct ground rule, recovers this.

**Pattern 5: Supervisor-block compliance is easy to slip on**. Writing a
handoff with a ground-rules block is normal; writing it under the
canonical `## Constraints` > `### Supervisor Ground Rules` heading
hierarchy per `[HANDOFF-004]` + `[HANDOFF-012]` requires one beat of
skill-recall at write-time. `[REFL-009]`'s detection depends on the
literal heading. One-line compliance defect per handoff — fixable by
either a writer-side checklist in the skill, or a more-forgiving
detector in `[REFL-009]`.

## Action Items

- [ ] **[package]** swift-institute/Scripts: Standardize argument parsing across `sync-*.sh`. Either every script accepts `--dry-run` uniformly (adds it to `sync-tools-version.sh` and `sync-swift-settings.sh`), or every script fails fast on unrecognized positional args (so `sync-tools-version.sh --dry-run` errors instead of silently treating `--dry-run` as the value). The current inconsistency silently corrupted 250 Package.swift files on 2026-04-22.
- [ ] **[skill]** issue-investigation: Add a pattern entry for "multi-repo shell iteration detection gotcha" — use `[[ -e "$d/.git" ]]` (matches file or directory), not `[[ -d "$d/.git" ]]` (directory only), when iterating over sub-repos that may mix independent and submodule layouts. Covers any script walking superrepos during/after migration work.
- [ ] **[blog]** CI failure taxonomy after a mass workflow-migration: three distinct layers of failure (caller-side permission declaration, central-reusable shell-interpreter portability, per-package dep-resolution) surfaced from one push wave. The investigation pattern — `gh run view --log-failed` → pattern-match error classes → diff working-vs-broken workflow file versions → identify root cause per class — is a reusable playbook worth writing up.
