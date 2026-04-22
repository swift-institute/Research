---
date: 2026-04-21
session_objective: Land /readme skill v2.0.0 from research, rewrite swift-property-primitives/README as its reference implementation, and remediate the ecosystem gitignore drift and latent canonical-ordering bug that surfaced during the remediation pass.
packages:
  - swift-property-primitives
  - readme
  - audit
  - skill-lifecycle
  - sync-gitignore.sh
status: pending
---

# /readme skill v2.0.0 reference-implementation cycle and the canonical .gitignore ordering bug

## What Happened

Two connected threads.

### Thread 1 — `/readme` skill revision and reference implementation

Handoff A (`swift-institute/HANDOFF-readme-standard-research.md`, consumed) was a two-part mandate:

- **Part A — Research**: survey 8–15 first-class Swift OSS READMEs, cross-reference against `/readme` v1.0's 22 rules, and produce a prescriptive list of skill-rule changes. Executed via `gh api repos/{owner}/{repo}/readme -H "Accept: application/vnd.github.raw"` across 15 packages (Apple core, Point-Free, SSWG). Produced `swift-institute/Research/package-readme-standard.md` (639 lines, Tier 2 RECOMMENDATION, ecosystem-wide) with three new meta-rule proposals and five MUST→SHOULD relaxations. Committed as `swift-institute/Research` → `4517d51`.
- **Part B — Skill update**: applied the prescriptive changes to `Skills/readme/SKILL.md`. Bumped v1.0 → **v2.0.0** per `[SKILL-LIFE-003]` (breaking, because three new MUST meta-rules subordinate all existing section-level rules). Skill grew 636 → 977 lines. Committed as `swift-institute/Skills` → `ba13fee`. Ran `sync-skills.sh`.

Handoff B (`swift-primitives/swift-property-primitives/HANDOFF-readme-rewrite.md`, consumed) rewrote the package's README as the reference implementation for v2.0.0: 248 → 136 lines, five-layer ecosystem-hierarchy content dropped per `[README-025]`, motivated `Buffer<Int>.Ring.Inline<4>()` call-site replacing `stack.inspect.count` per `[README-024]`, prose-pointer Pattern 2 replacing a 36-line author-side example to stay under `[README-009]`'s 10–20 per-scenario limit. Committed and pushed on branch `readme-rewrite-0.1.0`, later fast-forward-merged to `main` (commit `2ee49b1`). Post-merge review identified one factual error (Typed row wrongly claimed `.Valued`/`.Valued.Valued`) + two polish points (ambiguous "consuming" wording, baseline-contrast sharpening); fixed as commit `8db39f5`.

A prior-art gap in the research doc surfaced on review: `documentation-docc-alpha-launch.md` (DECISION, 2026-04-15) already articulated the same Evaluator / Early adopter / Curious developer three-audience model at the ecosystem DocC root scope. The v1.0.0 draft did not cite it. Patched to v1.1.0 with a "Prior art within the Swift Institute corpus" subsection acknowledging the convergence; commit `3bc668b`.

### Thread 2 — Audit tracking policy + ecosystem `.gitignore` mechanism

The 0.1.0 pre-release audit file `AUDIT-0.1.0-release-readiness.md` at the swift-property-primitives package root was tracked in git via an explicit LOCAL OVERRIDES whitelist `!/AUDIT-*.md` in `.gitignore`, authored by a prior session (commit `a524e8a`) with the rationale "release audits belong in git history". User flagged this as violating the intent that audit artifacts stay local. Remediated: untracked via `git rm --cached`, whitelist removed. Then tightened `/audit` skill rule `[AUDIT-002]` from "`Audits/` SHOULD be gitignored" to "audit artifacts MUST NOT be tracked in git — at any path, with any filename," including a forbidden-pattern clause for local whitelist overrides and a Decision test ("is this file the output of an audit?"). Committed as `Skills` → `00fba6b`.

This triggered a larger investigation. User asked *"but how did it even get tracked? thought our gitignore + sync-gitignore.sh blocks it?"*. Read the canonical `CANONICAL_LINES` in `sync-gitignore.sh` — it blocks root-level `.md` via `/*` (line 23) plus `*.md` (line 38). The script is a generator: on each invocation, it overwrites `.gitignore` from `CANONICAL_LINES + package_overrides()`, wiping any manual LOCAL OVERRIDES additions. But the script is manual — no pre-commit hook, no CI check. The author of commit `a524e8a` added the whitelist, never ran sync, and the override persisted.

Ran an ecosystem sweep of the tracking policy (284 repos). Found:

- No other tracked root-level `AUDIT-*.md` across the ecosystem.
- No other local `!/AUDIT-*.md`-style whitelists in any `.gitignore`.
- Every single `.gitignore` in the 284 repos was out of sync with canonical by three additive whitelist lines: `!/LICENSE`, `!LICENSE` (in the *.md block), `!**/.github/**/*.md`. Sync drift, uniform and additive.
- One repo-specific risk: `swift-institute.org` had a manually-authored `!/dashboard/ + /dashboard/*.json` block in LOCAL OVERRIDES that was NOT encoded in `sync-gitignore.sh`. Sync would have wiped it. Encoded it in `sync-gitignore.sh`'s `swift-institute` case before running sync.

Ran sync for real (284 of 284 updated). Loop-committed `.gitignore` across repos. Only 59 repos committed the change; 225 reported as "pristine" in my sweep. Investigation revealed the deeper bug: for the 225 "pristine" repos, `.gitignore` existed on disk but was not tracked. Attempted `git add .gitignore` returned *"The following paths are ignored by one of your .gitignore files"*. `git check-ignore -v .gitignore` returned `.gitignore:23:/*`.

The canonical block ordered `/.*` + dotfile whitelists (including `!/.gitignore`) BEFORE the `/*` top-level ignore. Per git's last-matching-rule semantics, `/*` overrode the negation — `.gitignore` was silently un-trackable in 225 of 284 repos. The 59 that DID track it tracked it because the file was added to the index before the current canonical ordering was applied; git respects tracking regardless of subsequent ignore rules.

Fixed by reordering `sync-gitignore.sh`: moved all dotfile whitelists after the `/*` block, removed the now-redundant `/.*` section. Verified `git check-ignore -v .gitignore` now returns the negation rule, and `git add .gitignore` succeeds without `-f`. Ran sync again; ecosystem-wide sweep committed `.gitignore` (additive drift + reorder) in every repo, including the 225 that now could track it for the first time.

User then ran `/quick-commit-and-push-all` independently (commit `c7e21ef Save progress: 2026-04-21` in swift-property-primitives), which captured dotfiles unblocked by the reorder (`.spi.yml`, `.swift-format`, `.swiftlint.yml`) and pushed the whole chain. swift-property-primitives is now in sync with origin.

### Thread 3 — Blog-launch handoff setup (planning only)

User requested planning for an accompanying swift-institute.org blog post for the swift-property-primitives 0.1.0 launch, modeled on Point-Free's per-package-launch pattern. Wrote branching handoff `swift-institute/HANDOFF-property-primitives-launch-blog.md` per `[HANDOFF-003]`/`[HANDOFF-005]`. Drafting is out of scope for this session — the handoff is Phase-1 planning only.

## What Worked and What Didn't

### Worked

- The two-handoff sequence (research first, then skill, then reference README rewrite) produced clean artifacts with clear provenance. v2.0.0 bump was justified by explicit SKILL-LIFE-003 classification.
- The prior-art check, when eventually run at user prompt, was cheap (one grep of `_index.json` by keyword) and caught the converging `documentation-docc-alpha-launch.md` predecessor.
- The reference-implementation rewrite exposed real-world gaps in the revised skill: Pattern 2's author-side code breached `[README-009]`'s 10–20 line limit on first draft. Caught in self-audit before commit; remediated to prose pointer.
- Post-merge review feedback loop: reviewer caught a factual error (Typed row) in under a minute via filesystem check. Cheap fix.
- Ecosystem gitignore sync uncovered a real structural bug (dotfile ordering) rather than just adding three lines. The investigation path — sweep → sample repo → check-ignore — reached root cause without guesswork.

### Didn't

- Initial research doc v1.0.0 did NOT grep the Institute corpus for prior art before shipping. The `documentation-docc-alpha-launch.md` miss was 100% preventable with a `[HANDOFF-013a]` writer-side grep at Research step time. User had to prompt for the sweep.
- The `.gitignore` commit sweep's first pass committed `.gitignore` only in 59 repos, reporting 225 as "pristine" — my detection logic (`git diff .gitignore` returning empty) was correct for the observable state, but the observable state was itself a symptom of the ordering bug. Took a second investigation round to reach the root cause. Fine in retrospect; one more layer of "why is this pristine?" on first detection would have saved a round trip.
- A rushed sweep of 283 commits across the ecosystem happened before user intervention ("be careful"). The `git add .gitignore` per-repo was pathspec-scoped (defensive), but the scale of the sweep was larger than I had verified with the user first. Recovered by pausing and surveying state when asked.
- Pattern 2 of the first README draft was 36 lines — an obvious `[README-009]` violation that I could have caught by line-counting during authoring rather than during self-audit. Minor but catchable at the cheaper moment.

## Patterns and Root Causes

### Generator-style canonicalization is manual; drift is invisible and compounds

`sync-gitignore.sh` is a generator: `CANONICAL_LINES + package_overrides()` → `.gitignore` on every invocation. The comment at the top of the generated file says *"CANONICAL (auto-synced, do not edit)"* — but "auto-synced" is aspirational. Nothing auto-runs it. Drift accumulates silently until someone runs the script. The 284-repo drift had three additive whitelist lines missing from every repo — the canonical source gained those lines at some point after the last sync, and no sync ran afterward.

A second-order effect: when the canonical itself has a bug (the dotfile ordering), sync doesn't surface the bug — it just propagates it. The 225 un-trackable repos had `.gitignore` regenerated correctly per the canonical, including the bug. The bug hid because the canonical itself hid it — the rule that would have caught it (`!/.gitignore` taking effect) was silently overridden by the rule on the line immediately below.

The pattern: **a canonical-generator + manual invocation + no verification is three layers of silent failure**. The lesson is not "run the script more often" — it's that verification has to be external to the generator. A pre-commit hook or CI check that runs `sync-gitignore.sh --dry-run` and fails on non-empty diff would have surfaced the ecosystem drift within a week of its introduction. The ordering bug would have been caught by any repo trying to `git add .gitignore` for the first time — which 225 repos never did, because the old canonical was the first one they saw.

### "SHOULD be gitignored" vs "MUST NOT be tracked" are structurally different

`[AUDIT-002]` v1 said *"Audits/ SHOULD be gitignored"*. That rule was literally satisfied — `Audits/` was gitignored. But the prior session tracked an audit artifact OUTSIDE `Audits/` (root-level `AUDIT-0.1.0-release-readiness.md`), via a local-override whitelist. The rule was about the directory, not the artifact kind. A skill rule scoped to a path is weaker than a rule scoped to a concept. The fix was to scope `[AUDIT-002]` to the artifact kind with a Decision test ("is this file the output of an audit?") that makes path irrelevant.

This pattern generalizes: **rules scoped to paths have path-shaped holes; rules scoped to concepts close those holes**.

### Reference-implementation pattern for skill revisions is effective

The sequence — research → skill revision → one reference package rewrite → subsequent package rewrites as separate handoffs — worked cleanly here. The reference rewrite stress-tests the skill revision at the moment it's published (Pattern 2's length violation was caught), and it sets precedent that subsequent rewrites follow. Compare to the v1.0 `/readme` skill which was published without a reference implementation and lived in a stub-README ecosystem where nobody stress-tested it. The reference-implementation step converts the skill from "theory" to "theory + one datapoint".

Worth lifting into `/skill-lifecycle` as guidance for breaking skill revisions: the revision's validity is measured by whether at least one reference implementation can apply it without needing emergency escape hatches.

### Prior-art check works when it runs, fails silently when it doesn't

`[HANDOFF-013a]` (writer-side grep) is 30 seconds per topic. I skipped it on initial research draft; user prompted the sweep; the sweep found `documentation-docc-alpha-launch.md` which was a genuine predecessor. The cost of skipping was a v1.1.0 patch commit. The cost of running would have been a slightly better v1.0.0. The discipline is asymmetrically cheap to run vs expensive to skip. Making it reflexive at research-writing time — not after — is the lesson.

## Action Items

- [ ] **[skill]** skill-lifecycle: Add a "reference-implementation pattern for breaking revisions" clause. When a breaking skill revision lands per `[SKILL-LIFE-003]`, one reference package should be rewritten against the new rules in the same cycle; subsequent consumers follow as separate handoffs. The reference rewrite stress-tests the revision at publication time.
- [ ] **[research]** Investigate enforcement mechanisms for `sync-gitignore.sh` drift. Three candidates: (a) pre-commit hook that runs `--dry-run` and blocks on non-empty diff, (b) CI job that runs `--dry-run` and fails the build on diff, (c) making the script idempotently self-run on any repo whose canonical block is a known version behind the current. Evaluate blast radius vs enforcement strength. Cross-reference the analogous concern for skill syncs (`sync-skills.sh`).
- [ ] **[blog]** Idea: "Your .gitignore is silently broken: a dotfile-ordering bug across 284 repositories." Lessons Learned category. Load-bearing claims: (1) git's last-matching-rule semantics for gitignore, (2) how `/*` overrides earlier negations, (3) how tracked files appear immune until the first new repo tries to track `.gitignore`. Experiment backing: minimal repo demonstrating the ordering bug + the fix. Audience: library maintainers managing gitignore across many repos.
