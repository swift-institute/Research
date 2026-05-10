---
date: 2026-05-05
session_objective: Execute the 5 Active Next Steps in HANDOFF-centralized-ci-deduplication.md (final cleanup pass + Xcode/macos centralization + 2 composite actions + 1 reusable workflow)
packages:
  - swift-institute/.github
  - swift-primitives/.github
  - swift-institute/Skills
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: NoAction 3 GitHub Actions context-availability rules already captured in feedback memories (composite_action_description_no_expressions, env_invalid_in_runs_on_container, scheduled_workflow_canary_gap). 3 architectural building blocks (configure-private-repos, install-swift-sdk, cron-audit-base) deferred to ci-cd-workflows expansion. download-artifact v5/v6/v7/v8 layout research deferred narrow investigation.
---

# Centralized CI deduplication — five-step cohort execution

## What Happened

Drove the centralized-CI deduplication handoff to closure across 25 commits (20 in swift-institute/.github + 5 in swift-primitives/.github) plus 5 audit-stream labels created via `gh label create`. Per-action authorization on every push; per-canary verification on every commit (typically `gh workflow run ci.yml --repo swift-primitives/swift-tagged-primitives --ref main`, with `--field dry-run=true` for the cron orchestrators in Step 5).

Step-by-step:

**Step 1 (Final cleanup pass)** — 8 commits + 5 labels.
- 1a `d898854`: `generate-metadata.sh --limit 500 → 2000` (drift residual to commit `879a9d5`).
- 1b.1 `3d428af`: `actions/upload-artifact@v4 → @v7` across 5 cron orchestrators. Canary GREEN.
- 1b.2 first attempt `25e479a`: `actions/download-artifact@v4 → @v8`. Canary FAILED — bash glob `/tmp/counts/*/*.txt` matched nothing.
- 1b.2 fix-forward attempt `6738fe6`: pinned to `@v7` (claimed Node-24-compliant + auto-decompress). Canary FAILED with the same glob mismatch.
- 1c.1 `5bdef3f`: full revert to `@v4` across all 5 sites. Canary GREEN.
- 1c.2 `e9b468e`: replaced `container: swift:${{ env.SWIFT_VERSION }}` with literal `swift:6.3` in 2 cron orchestrators (pre-existing parse-time bug from `ecf36e6` + `91dd8db`).
- 1c.3a (gh-API): created 5 audit-stream labels on swift-institute/.github (foundation-audit, license-audit, mechanical-hygiene, spine-audit, dep-graph) — none had existed.
- 1c.3b `ddf3b59`: added `||` label-missing fallback to 5 cron orchestrators' `gh issue create` calls (mirrors link-check + sync-metadata pattern).
- 1b.3 `3aea9a8`: `actions/create-github-app-token@v1 → @v3` across 15 tracked sites (10 files). Canary GREEN.

**Step 2 (Xcode + macos-26 centralization)** — 3 commits via principal's Option D (input for `runs-on:`, env for shell context).
- 2a `ad83500`: swift-institute universal swift-ci.yml — `inputs.macos-runner` + `env.XCODE_VERSION`.
- 2b `d9082eb`: swift-institute swift-docs.yml — same shape + new env block.
- 2c `cdc9071`: swift-primitives layer-wrapper swift-ci.yml — same shape + matrix delegate pass-through to universal.

**Step 3 (configure-private-repos composite action)** — 4 commits + 1 fix-forward.
- 3.1 `3ba3132`: composite action created at `swift-institute/.github/.github/actions/configure-private-repos/action.yml`.
- 3.1-fix `7dff105`: rewrote `inputs[*].description` text removing `${{ secrets.PRIVATE_REPO_TOKEN }}` and `${{ inputs.enable-private-repos }}` documentation references — GitHub Actions parses `${{ }}` in description fields and rejected the action at load time. First 3.2 canary surfaced this with `Unrecognized named-value: 'secrets'` on all 4 universal-matrix jobs at "Set up job".
- 3.2 `09842a7`: 4 sites in universal swift-ci.yml. Re-canary GREEN.
- 3.3 `9270080`: swift-docs.yml + lint-api-breakage.yml (2 sites, latter is PR-only-trigger so trusted in Option α).
- 3.4 `48fc126`: 5 sites in swift-primitives layer wrapper. Canary GREEN.

**Step 4 (install-swift-sdk composite action)** — 4 commits, no recovery rounds.
- 4.1 `5ad5396`: composite with 5 inputs (platform, bundle-suffix, use-platform-version, sdk-id, output-env-var). The `sdk-id` input supports a literal `${TAG}` token replaced via `sed` after releases.json lookup; `use-platform-version: 'true'` appends the platform record's `version` field for static-sdk's URL convention.
- 4.2 `0942067` (Wasm), 4.3 `e933bce` (Android), 4.4 `dbabe76` (Static-musl). Static-musl was the divergent case — verified Resolved version `0.1.0` correctly appended; SDK ID `x86_64-swift-linux-musl` correctly passed through (no `${TAG}` token).

**Step 5 (cron-audit-base reusable workflow)** — 5 commits, no recovery rounds.
- 5.1 `0a88822`: 299-line reusable with `envsubst`-based body templating. Inputs: `matrix-orgs` (JSON-array string parsed via `fromJSON()`), `container` (default empty = ubuntu-latest), `audit-script-url` (optional), `audit-step` (multi-line shell), `count-labels`, `issue-title-prefix`, `issue-label`, `issue-body-template`, `dry-run`.
- 5.2 `a382f98` (foundation, simplest case), 5.3 `0b88830` (license, with `${EXTRA}` for per-package detail), 5.4 `c7473bd` (spine, container override), 5.5 `542bfeb` (mechanical-hygiene, divergent multi-audit case).

Closed `HANDOFF-centralized-ci-deduplication.md` with status stamp + closure summary annotation per principal's authorization (file annotated, not deleted; successor handoff `HANDOFF-ci-action-version-tail.md` exists at workspace root).

**Handoff-file scan ([REFL-009]):** 19 `HANDOFF-*.md` files at workspace root. Cleanup authority covered exactly 1: `HANDOFF-centralized-ci-deduplication.md` (this session's primary handoff; annotated CLOSED + closure summary appended, NOT deleted per principal's annotate-supersede directive). The other 18 are out-of-session-scope (parallel-session work, principal's in-flight topics). The successor `HANDOFF-ci-action-version-tail.md` was pre-staged by the principal in parallel; not in this session's authority either.

**Untracked working-tree state ([REFL-013]):** 3 `lint-readme-*.yml` files at swift-institute/.github working tree remained untracked throughout all 25 commits — verified at session start (DO NOT TOUCH per sibling handoff) and preserved via file-specific `git add`. No silent disturbance.

**Memory feedback files pinned in parallel by principal during the session** (`originSessionId` stamp visible in each):
- `feedback_composite_action_description_no_expressions.md`
- `feedback_env_invalid_in_runs_on_container.md`
- `feedback_scheduled_workflow_canary_gap.md`

## What Worked and What Didn't

**Worked:**

The per-canary-per-commit + per-action-auth discipline was load-bearing. Three distinct defects surfaced via canary and were caught before they accumulated:
1. download-artifact@v8 glob mismatch (Step 1b.2) — surfaced because canary actually ran the report job with the new layout.
2. Composite action description-expression gotcha (Step 3.1) — surfaced because canary attempted to load the action.
3. Pre-existing env-in-container parse failure (Step 1c.2) — surfaced because my push to swift-institute/.github re-triggered workflow file parsing on the broken cron orchestrators that had been latent since `ecf36e6`.

The principal's "Mirror existing pattern verbatim from link-check.yml" instruction for the label-fallback (Step 1c.3b) prevented re-deriving the shape. I followed the verbatim mirror; it Just Worked.

The principal's Option D for Step 2 (input for `runs-on:`, env for shell) was the cleanest possible decomposition given the context-availability constraint. My initial Step 2 plan proposed env for both fields; the principal corrected it. Delta: I had read the GitHub Actions docs and noted `env.*` invalid in `runs-on:`, but flagged it as "needs principal direction" instead of proposing the correct Option-D shape. The principal proposed the structure I should have proposed.

**Didn't work:**

- I recommended revert too quickly on Step 1b.2 first failure. Principal pushed back: "Fair pushback. The revert framing was reflexive risk-aversion, not honest cost-benefit." That pushback was correct — the v7 fix-forward attempt was reasonable. It also failed (separately), so revert ended up being the right call. But the principal's process correction was real: I should not pre-commit to revert before the diagnosis is in hand.

- I claimed v7 would retain auto-decompress based on release-notes parsing. Empirical canary disproved this. The release notes attributed "no automatic decompression" specifically to v8.0.0; v7 in fact ALSO produces a layout incompatible with the existing `/tmp/counts/*/*.txt` glob. Mechanism unclear. This is a research-first axis, deferred to HANDOFF-ci-action-version-tail.md.

- I overcounted commits in the initial Step 5 closing report: said "24 swift-institute + 8 swift-primitives" when actual was 20 + 5 = 25. The principal's directive used the same numbers I'd reported in earlier intermediate reports; I caught the discrepancy when verifying via `git log` for the final closure summary. The lesson: state checks via `git log --oneline` produced the correct count in seconds; if I had run the state check earlier, my intermediate reports would have been correct. This is `[REFL-012]` (loop-counter verification is state verification) applied to my own narrative-counter accumulation across multi-step work.

## Patterns and Root Causes

**Pattern 1: Empirical canary > release-notes parsing for actions with multi-axis breaking changes.** download-artifact v5 → v6 → v7 → v8 introduced (at least) Node.js 24 runtime, ESM bundling, hash-mismatch enforcement, Content-Type-based decompression, and apparently *something else at v7* that produces an incompatible on-disk layout despite the release notes attributing only the decompression change to v8. Release notes summarize what the maintainers think changed; canary surfaces what actually changed. For actions with three-or-more breaking-change axes, the lesson generalizes: do not trust release-notes-driven analysis as a substitute for empirical canary; bound each canary to a single axis where possible.

**Pattern 2: Pre-existing latent bugs surface when work re-triggers parsing.** Two instances this session:
- `ecf36e6` (env-in-container) had been on remote main for hours/days but only failed when my push triggered workflow re-parsing on submit-dep-graph-weekly + lint-test-support-spine-weekly.
- The label-fallback gap (5 cron orchestrators missing `||` fallback after `gh issue create --label`) had been latent since each orchestrator was authored; surfaced only when 1c.2 fixed the parse-time error and the orchestrator could finally reach the label-create line.

This generalizes: any work that touches the parser's input (workflow YAML files, action.yml) can surface latent defects elsewhere. The verification strategy should be: after parser-touching work lands on remote, dispatch a probe of every workflow that re-parses on push, not only the workflow you intended to change. The principal's `[SUPER-014]`-adjacent verification gap — "scheduled-only workflows need their own gh workflow run --ref main dry-run" — is the same pattern at the scheduled-trigger axis.

**Pattern 3: GitHub Actions context-availability rules are field-specific, not action-type-specific.** Across the cohort I encountered three distinct context-availability constraints:
- `${{ ... }}` evaluates in composite action.yml `description:` fields (Step 3.1-fix).
- `env.*` is unavailable in `runs-on:` (Step 2 design).
- `env.*` is unavailable in `container:` (Step 1c.2 fix).

These are NOT consequences of the same underlying rule — composite actions have their own context-resolution semantics; runs-on resolves before workflow-level env binds; container similarly resolves at job-startup. Each is a separate field-by-field carve-out. The skill update needs to enumerate the constraints per field (which is what `feedback_env_invalid_in_runs_on_container.md` already does for two fields, and `feedback_composite_action_description_no_expressions.md` does for a third).

**Pattern 4: Per-action authorization preserved trust + structurally caught issues.** Across 25 commits the principal authorized each major step (1a, 1b.1, 1b.2 (×2 attempts), 1c.1, 1c.2, 1c.3a, 1c.3b, 1b.3, 2a/2b/2c, 3.1/3.2/3.3/3.4, 4.1/4.2/4.3/4.4, 5.1/5.2/5.3/5.4/5.5). The discipline was load-bearing in three places where it changed the outcome: the principal's pushback on premature revert (Step 1b.2), the option-D framing for Step 2 (which I had not proposed), and the bulk-push-class authorization for Step 5 (which I did not assume). Per-action auth is not bureaucratic friction at this work scale; it is the channel through which the principal's higher context informs the subordinate's local-context decisions.

## Action Items

- [ ] **[skill]** ci-cd-workflows: Codify the 3 GitHub Actions context-availability rules from this cohort's memory feedback files as new `[CI-XXX]` requirement IDs — composite action description fields parse `${{ }}` (cite `feedback_composite_action_description_no_expressions.md`), `env.*` invalid in `runs-on:` and `container:` (cite `feedback_env_invalid_in_runs_on_container.md`), scheduled-only workflows need explicit `gh workflow run` canary (cite `feedback_scheduled_workflow_canary_gap.md`). Promotes from feedback memory to skill normative requirements.
- [ ] **[skill]** ci-cd-workflows: Document the 3 new architectural building blocks added by this cohort — `configure-private-repos` composite action (11 invocation sites collapsed to 1 + 11), `install-swift-sdk` composite action (3 SDK-platform sites + the `${TAG}` substitution + `use-platform-version` static-sdk override), `cron-audit-base.yml` reusable workflow (4 cron orchestrators + the envsubst body-template substitution contract). Each warrants its own `[CI-XXX]` requirement ID with the input contract, call-site shape, and provenance pinned.
- [ ] **[research]** Empirical investigation: what's the actual on-disk layout difference for `actions/download-artifact` v5 / v6 / v7 / v8 when invoked with `path: /tmp/counts` and no `name:` filter? Release notes attribute "no automatic decompression" only to v8.0.0, but canary on v7 produced a layout that the existing `/tmp/counts/*/*.txt` glob also fails to match. Required input for `HANDOFF-ci-action-version-tail.md` ladder migration; protocol: trigger workflow_dispatch with a debug `ls -laR /tmp/counts` step at each major version, observe ground-truth, classify which version introduced which axis of layout change.
