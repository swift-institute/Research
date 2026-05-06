# CI/CD Security Review — swift-institute + swift-primitives Stack

<!--
---
version: 1.1.0
last_updated: 2026-05-06
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The 2026-05-06 reviewer-feedback wave surfaced 4 high-severity security findings
([H1] sync-ci-callers footgun, [H2] curl-piped audit scripts, [H3] arbitrary
audit-step shell, [H4] dispatch-input shell injection). H1/H2/H4 landed; M1/M3
landed; M2 attempted-and-reverted (workflow_call permissions chain pitfall);
Cohort A1 (`step-security/harden-runner` audit-mode floor, `[CI-080]`) landed;
Cohort B Phase 1 (`ci-ok` aggregator) landed. Branch-protection (Cohort B
Phase 2), block-mode flip (Cohort A2), release-workflow + cosign attestation
(Cohort C / M7), workflow-level `permissions:` hardening (M2 redo) remain
queued.

The principal asked for a comprehensive security-focused walkthrough of the
entire CI/CD stack as a single RECOMMENDATION that contextualizes the in-flight
cohorts and identifies any gaps reviewer feedback did not surface. Priority
axes per `feedback_ci_priority_axes.md`: correctness > security > speed; cost
is NOT an axis.

## Question

What is the present security posture of the swift-institute + swift-primitives
CI/CD stack — across workflows, composite actions, helper scripts, cron
orchestrators, and the org bot — and what cohorts close the residual gaps,
sequenced by marginal-risk-reduction × inverse-implementation-cost?

## Scope 1 — Stack Inventory + Per-Component Security Posture

### Stack overview

The stack comprises three classes of artifact across two repos:

| Repo | Workflows | Composite actions | Helper scripts |
|---|---|---|---|
| `swift-institute/.github/.github/` | 22 | 5 | 5 |
| `swift-primitives/.github/.github/` | 1 | 0 | 0 |

Total: 23 workflow files, 5 composite actions, 5 helper scripts. The
`swift-primitives` wrapper is the only layer wrapper today (`[CI-004]`); other
ecosystem orgs route directly through the universal reusable.

### Per-component matrix

Columns: **Action SHA-pin state** (✓ SHA-pinned; ✓ tag; ✗ branch); **Secret
scope** (which secrets readable in this component's job context); **Egress**
(which external domains the component contacts during normal operation);
**Token mint** (whether component invokes `actions/create-github-app-token@v3`
and the resulting scope); **Trigger surface** (events that fire the component).

#### Reusable workflows (workflow_call only)

| Workflow | SHAs | Secrets | Egress | Token mint | Trigger |
|---|---|---|---|---|---|
| `swift-institute/.github/.github/workflows/swift-ci.yml` (universal reusable) | harden-runner ✓ SHA / others ✓ tag (`actions/checkout@v6`, `actions/cache@v5`, `SwiftyLab/setup-swift@v1`) | `PRIVATE_REPO_TOKEN` only (declared `required: false`); fork-PR drops it per GitHub fork-secret rules | `swift.org` (Linux container fetch), `github.com` (clone, package resolve), `dl.dl.swift.org`, `archive.ubuntu.com`, `realm.com` (SwiftLint binary), `github.com/realm/SwiftLint/releases` | none | `workflow_call` only |
| `swift-primitives/.github/.github/workflows/swift-ci.yml` (L1 wrapper) | harden-runner ✓ SHA / others ✓ tag | `PRIVATE_REPO_TOKEN` | `swift.org` (5 SDK installs incl. wasm/android/static), `github.com`, `archive.ubuntu.com` | none | `workflow_call` only |
| `swift-institute/.github/.github/workflows/swift-docs.yml` | harden-runner ✓ SHA / `actions/checkout@v6` ✓ tag | `PRIVATE_REPO_TOKEN` | `github.com` (sparse-checkout of patch-umbrella-symbol-graph.py from `swift-institute/.github@main`), `archive.ubuntu.com` (apt python3) | none | `workflow_call` only |
| `swift-institute/.github/.github/workflows/cron-audit-base.yml` | harden-runner ✓ SHA / `actions/create-github-app-token@v3` ✓ tag / `actions/checkout@v6` ✓ tag / `actions/upload-artifact@v7` ✓ tag / `actions/download-artifact@v8` ✓ tag | sweep job: bot App secrets + scoped install token (`owner: ${{ matrix.org }}, repositories: ''` → ORG-WIDE token); report job: bot App secrets + token scoped to `swift-institute/.github` with `permission-issues: write` | sweep: `github.com` for bot install-token mint + per-org repo-list, plus arbitrary endpoints reachable by `inputs.audit-step` shell snippet; report: `github.com` (issue API) | yes — sweep mints **org-wide install token** per matrix.org; report mints **issues:write on swift-institute/.github** | `workflow_call` only |
| `swift-institute/.github/.github/workflows/sync-metadata.yml` | harden-runner ✓ SHA / `actions/create-github-app-token@v3` ✓ tag | bot App secrets + token scoped to `inputs.org` (or single repo) — `gh repo edit` capability requires **administration:write** install permission on the org | `github.com` (gh repo view, gh repo edit) | yes — minted per call; scope is `inputs.org` + empty repositories ⇒ all repos in install scope | `workflow_call` + `workflow_dispatch` |
| `swift-institute/.github/.github/workflows/generate-metadata.yml` | harden-runner ✓ SHA / `actions/create-github-app-token@v3` ✓ tag / `actions/checkout@v6` ✓ tag | bot App secrets + token scoped to `inputs.org` with **`permission-contents: write`** AND **`permission-pull-requests: write`** | `github.com` (gh api repos/<org>/.../pulls POST, git push to feature branches) | yes — **highest-privilege mint**: `contents:write + pull-requests:write` on entire org | `workflow_call` + `workflow_dispatch` |
| `swift-institute/.github/.github/workflows/lint-readme-presence.yml` | harden-runner ✓ SHA / `actions/create-github-app-token@v3` ✓ tag | bot App secrets + token scoped to `inputs.org`/`inputs.repo` | `github.com` (per-repo README presence checks) | yes — read-only metadata + contents | `workflow_call` + `workflow_dispatch` |
| `swift-institute/.github/.github/workflows/lint-readme-structure.yml` | harden-runner ✓ SHA / `actions/create-github-app-token@v3` ✓ tag | bot App secrets + token | `github.com` (per-repo README content) | yes — read | `workflow_call` + `workflow_dispatch` |
| `swift-institute/.github/.github/workflows/link-check.yml` | harden-runner ✓ SHA / `actions/cache@v5` ✓ tag / `actions/create-github-app-token@v3` ✓ tag | bot App secrets + token; minted for entire `inputs.org` when `inputs.repo` not set | every URL embedded in scanned consumer repos' Markdown / DocC / source-comment text — wide and partly attacker-influenced (e.g. lychee follows external links found in repo content) | yes — read; lychee uses token via `GITHUB_TOKEN` env (line 245), passed via env (not CLI flag) to keep token out of `ps` listing | `workflow_call` + `workflow_dispatch` |
| `swift-institute/.github/.github/workflows/lint-api-breakage.yml` | harden-runner ✓ SHA / `actions/checkout@v6` ✓ tag | `PRIVATE_REPO_TOKEN` | `swift.org`, `github.com` (full-history `fetch-depth: 0` checkout) | none | `workflow_call` only (transitive from `swift-ci.yml`) |
| `swift-institute/.github/.github/workflows/lint-license-header.yml` | harden-runner ✓ SHA / `actions/checkout@v6` ✓ tag | none required | `github.com` (sparse-checkout of audit-license-header.py) | none | `workflow_call` only |
| `swift-institute/.github/.github/workflows/lint-test-support-spine.yml` | harden-runner ✓ SHA / `actions/checkout@v6` ✓ tag | `PRIVATE_REPO_TOKEN` | `swift.org`, `github.com` | none | `workflow_call` only |
| `swift-institute/.github/.github/workflows/lint-yaml.yml` | harden-runner ✓ SHA / `actions/checkout@v6` ✓ tag | none | `github.com` | none | `workflow_call` only |
| `swift-institute/.github/.github/workflows/lint-broken-symlink.yml` | harden-runner ✓ SHA / `actions/checkout@v6` ✓ tag | none | `github.com` | none | `workflow_call` only |
| `swift-institute/.github/.github/workflows/lint-pr-title.yml` | harden-runner ✓ SHA | none | none (PR title via env var only — see Threat Model T6) | none | `workflow_call` only |

#### Cron orchestrators (schedule + workflow_dispatch)

Permissions inherited via `secrets: inherit` to the called reusables; the
orchestrator file itself reads `read-orgs` manifest, then dispatches per-org
matrix legs.

| Orchestrator | Cron | Calls | Notes |
|---|---|---|---|
| `link-check-weekly.yml` | `0 6 * * 1` | `link-check.yml` per-org via matrix | Token minted per matrix-org |
| `lint-readme-presence-weekly.yml` | `0 6 * * 1` | `lint-readme-presence.yml` per-org via matrix | **Hardcodes org list (lines 39–56) parallel to `read-orgs/orgs.yaml` — drift risk; see Gap G6.** |
| `lint-license-header-weekly.yml` | `40 6 * * 1` | `cron-audit-base.yml` with `audit-license-header.py` | `audit-step` is in-line shell; `audit-script-path` sparse-checked-out per H2 fix |
| `lint-test-support-spine-weekly.yml` | `30 6 * * 1` | `cron-audit-base.yml` with `audit-test-support-spine.py` | swift:6.3 container required (`swift package dump-package`) |
| `lint-mechanical-hygiene-weekly.yml` | `45 6 * * 1` | `cron-audit-base.yml` with in-line yamllint + symlink scan; no `audit-script-path` | Inlines `pip install --quiet yamllint` — see Gap G3 (unpinned pip install) |
| `submit-dep-graph-weekly.yml` | `50 6 * * 1` | direct sweep + report (not via cron-audit-base; uses `enumerate-org-public-repos` composite + `build-dep-graph-snapshot.py` helper) | Sweep mints **org-wide install token**; submits via `gh api -X POST repos/<target>/dependency-graph/snapshots`; report job mints separately for `permission-issues: write` |
| `sync-metadata-nightly.yml` | `0 4 * * *` | `sync-metadata.yml` per-org via matrix (default = all 17 active orgs from `orgs.yaml`) | Daily — broadest cadence in the stack |

#### Composite actions

All under `swift-institute/.github/.github/actions/` and consumed via
`@main` per `[CI-030]`.

| Composite | Inputs | Reads secret? | Network egress | Notes |
|---|---|---|---|---|
| `configure-private-repos` | `token` (caller-passed), `enabled` (string boolean) | NO — caller passes secret value via `with:` (composite limitation) | none directly; modifies `git config insteadOf` so subsequent SwiftPM resolves use token | **PRIVATE_REPO_TOKEN ends up embedded in `https://<token>@github.com/` URL form on disk, visible to the runner's process tree.** Acceptable because the runner is ephemeral and the token is install-scope. Note `feedback_composite_action_description_no_expressions.md`: descriptions cannot use `${{ }}` — confirmed clean. |
| `install-swift-sdk` | `platform`, `bundle-suffix`, `use-platform-version`, `sdk-id`, `output-env-var` | NO | `https://www.swift.org/api/v1/install/releases.json` (HTTPS GET); `https://download.swift.org/...` (artifact + checksum-verified install via `swift sdk install`) | Container-only; `apt-get install curl jq` via `apt-get` (no checksum on apt). `swift sdk install --checksum` IS verified — load-bearing supply-chain protection on the SDK artifact. |
| `enumerate-org-public-repos` | `org`, `visibility`, `exclude-forks`, `exclude-archived`, `gh-token` (caller-passed) | NO — caller-passed | `github.com` (`gh repo list`) | Output via heredoc-shaped `GITHUB_OUTPUT` delimiter (correct multiline pattern). |
| `upsert-tracking-issue` | `repo`, `title`, `title-prefix`, `body-file`, `label`, `gh-token` (caller-passed) | NO | `github.com` (gh issue list / edit / create) | Body-via-file pattern avoids `GITHUB_OUTPUT` heredoc issues for multiline content. Label fallback (try-with-label, fall back to no-label) is correct. |
| `read-orgs` | `filter` (jq expression), `include-archived` | NO | `github.com/mikefarah/yq/releases/...` (yq binary install on cache miss); no other egress at runtime | `${{ github.action_path }}/orgs.yaml` is the canonical 17-org manifest. yq install is HTTPS curl WITHOUT checksum verification — see Gap G4. |

#### Helper scripts (under `swift-institute/.github/.github/scripts/`)

| Script | Used by | Sparse-checked-out at runtime? | Risk surface |
|---|---|---|---|
| `audit-license-header.py` | `lint-license-header-weekly.yml` via `cron-audit-base.yml` | YES (sparse-checkout of `swift-institute/.github@main`) | Pure read of consumer Sources/**.swift; no shell exec; no network. |
| `audit-test-support-spine.py` | `lint-test-support-spine-weekly.yml` via `cron-audit-base.yml` | YES | Calls `swift package dump-package` (subprocess, controlled args); reads JSON. **Hardcodes principal-mode org dirs at `/Users/coen/Developer/swift-{primitives,standards,foundations,iso}` (lines 32–37); harmless when invoked in CI mode (`--package-dir`) but a finger-print of the dual-use script.** |
| `build-dep-graph-snapshot.py` | `submit-dep-graph-weekly.yml` | YES | Reads `swift package show-dependencies` JSON output, emits snapshot JSON for `POST /repos/<target>/dependency-graph/snapshots`. Pure data transformation. |
| `generate-metadata.sh` | `generate-metadata.yml` | YES (full checkout, not sparse) | **Performs `git push` and `gh api repos/<target>/pulls --method POST` — write operations. Highest-impact script in the stack.** |
| `patch-umbrella-symbol-graph.py` | `swift-docs.yml` | YES | Pure JSON transformation on symbol graph; no shell exec; no network. |

### Per-component summary

**Strengths:**
- `harden-runner` SHA-pinned `@a5ad31d6a139d249332a2605b85202e8c0b78450` is universal
  on every non-aggregator job per `[CI-080]` (Cohort A1 landing).
- All `actions/*` and third-party actions are major-tag-pinned per
  `[CI-013]` and `feedback_latest_versions_only.md`. None are branch-pinned.
- Every job declares `permissions: { contents: read }` at job level — minimal
  default for jobs that don't elevate. Bot-token-using jobs scope token via
  `actions/create-github-app-token@v3`'s `permission-*` inputs to narrow the
  install permissions to exactly what the job needs.
- No `pull_request_target` or `workflow_run` triggers anywhere in the stack
  (verified by grep across all 23 workflow files).
- Every ingress of repository content into `run:` blocks uses env-var
  indirection (PR title via `env: PR_TITLE`, base SHA via `env: BASE_SHA`)
  rather than direct `${{ }}` interpolation — closes the H4 class.
- Tokens passed to `git clone` URLs use `https://x-access-token:$GH_TOKEN@github.com/`
  (not `https://$GH_TOKEN@`). Consistent.
- lychee in `link-check.yml` reads token via `GITHUB_TOKEN` env var (line 245)
  rather than `--github-token` CLI arg — token does not appear in `ps` listings.

**Weaknesses (each enumerated as gaps in Scope 3):**
- Workflow-level `permissions:` hardening (M2 redo) absent — per-job grants
  cover correctness; workflow-level would add defense-in-depth at near-zero
  cost on non-reusable workflows.
- harden-runner is at audit-mode floor only; block-mode protocol from `[CI-080]`
  is underspecified (Cohort A2).
- No branch protection on `swift-institute/.github` or `swift-primitives/.github`
  today (Cohort B Phase 2). The corollary: **anyone with push access on
  `swift-institute/.github` can replace `generate-metadata.sh` and dispatch
  it to mint contents:write + pull-requests:write tokens on any of 17 orgs.**
- No release workflow / cosign attestation (Cohort C). Pre-tag, this is N/A.
- Two unpinned binary installs: `pip install yamllint` (no version pin),
  `mikefarah/yq` install via curl with no checksum (cache key locks `v4.45.4`
  on cache hit, but cold install just trusts HTTPS).
- `lint-readme-presence-weekly.yml` hardcodes the org list parallel to
  `orgs.yaml`. Drift hazard when a new org is added.

## Scope 2 — Threat Model

Five plausible attack paths through the stack to consequential targets. Each
labeled per `[RES-026]` discipline as **plausible** (documented in GitHub
Actions security docs, GHSA, or recent incident reports) or **speculative**
(possible but no documented analog). Citations follow.

### T1 — Private-org secrets exfiltration via fork-PR through cross-repo `secrets: inherit`

**Status: PLAUSIBLE (theory) but NOT REACHABLE (architecture).**

The classic path: a fork-PR triggers `pull_request` (NOT `pull_request_target`)
on a public consumer; the consumer's `ci.yml` says `secrets: inherit`; the
inherited org-level `PRIVATE_REPO_TOKEN` flows through to the universal
reusable; an attacker-controlled commit in the fork executes a malicious
build step that exfiltrates the token to an attacker-controlled endpoint.

**Why not reachable on this stack:**

1. GitHub Actions explicitly does **not** populate `secrets.*` for `pull_request`
   triggered from a fork on a public repo — confirmed by GitHub's own security
   docs ([Security guides — Pull request from a fork](https://docs.github.com/en/actions/reference/secrets-reference#using-secrets-in-github-actions)
   and the [SecureSDLC guide for `pull_request`](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-secrets)).
   So the inherited `PRIVATE_REPO_TOKEN` resolves to empty. The
   `configure-private-repos` composite then degrades to anonymous fetch (which
   is documented at `[CI-058]`'s "empty-token / anonymous-fetch fallback").
2. The build step in the consumer is `swift test -c debug` etc. — no shell
   tokens are interpolated from PR-controlled content into `run:` blocks.
3. harden-runner audit-mode (and block-mode, post-Cohort-A2) records every
   outbound connection.

**Chokepoints in place:** ✓ no `pull_request_target`; ✓ `secrets:` empty for
fork PRs by GitHub policy; ✓ harden-runner audit-mode. **Chokepoints absent:**
✗ block-mode (Cohort A2 queued).

### T2 — Write access to consumer repositories via compromised reusable workflow

**Status: PLAUSIBLE.**

Path: an attacker pushes a malicious commit to
`swift-institute/.github@main` or `swift-primitives/.github@main` (no branch
protection presently). All consumers pin reusables to `@main` per `[CI-030]`,
so the next consumer-side `push`/`pull_request` runs the malicious version.
The malicious version retrieves its `${{ secrets.GITHUB_TOKEN }}` (consumer's,
scoped per consumer's job-level `permissions:`) and uses it to push back to
the consumer.

**What the attacker would actually get:** the universal reusable's jobs all
declare `permissions: { contents: read }`. Per the [workflow_call permissions
intersection rule](https://docs.github.com/en/actions/using-workflows/reusing-workflows#access-and-permissions),
the called workflow's effective permissions are the **intersection** of (a)
caller's job-level permissions and (b) called workflow's job-level permissions.
With both declaring `contents: read`, the intersection is `contents: read` —
NO write access via GITHUB_TOKEN.

**Residual risk:** the malicious reusable could still run arbitrary code AS
THE BUILD on consumer repos, which means it can read any state on the runner
(including the consumer's source tree, but the source is already public on
public consumers). It also retains read access to `${{ secrets.PRIVATE_REPO_TOKEN }}`
forwarded via `secrets: inherit` — that token is org-level and grants read
access to private deps in the swift-primitives org. **Exfiltration of
`PRIVATE_REPO_TOKEN` IS the attack surface here.** harden-runner audit-mode
would log the exfil; block-mode would prevent it.

**Chokepoints in place:** ✓ `permissions:` intersection blocks writes;
✓ harden-runner audit-mode logs egress; ✓ no `pull_request_target`.
**Chokepoints absent:** ✗ branch protection on `swift-institute/.github` and
`swift-primitives/.github` (Cohort B Phase 2); ✗ harden-runner block-mode
(Cohort A2). **The combined absence is the single biggest risk in the stack.**

References: GitHub's own security advisory shape for compromised-reusable
attacks — see the [Reusable workflows security model](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-the-permissions-key)
and [GHSA-7p7q-5q8m-x8j9](https://github.com/sgoodluck/poc-actions-pr-target/security/advisories) (a
representative public PoC of the parallel `pull_request_target` class — not
this stack's exposure, but the canonical reference for the threat shape).

### T3 — `swift-institute-bot` App-token escalation across 17 orgs

**Status: PLAUSIBLE.**

The bot is installed on all 17 ecosystem orgs (`orgs.yaml` enumerates them).
The App's installation permissions on each org must be at least the union of
permissions any workflow `permission-*` flag requests. Specifically:
- `cron-audit-base.yml` sweep job: empty `repositories: ''` + no `permission-*`
  flags ⇒ token has the bot's full installation permissions for the org.
- `submit-dep-graph-weekly.yml` sweep: same pattern, comment claims "cross-org
  code:write per the App's permissions."
- `generate-metadata.yml`: `permission-contents: write` + `permission-pull-requests: write`
  on `inputs.org`.
- `sync-metadata.yml`: minted per `gh repo edit` call — needs `administration: write`
  on the install scope to flip repo settings, plus `metadata: read`.

**Inferred bot installation permissions** (lower bound from observed minting
behavior): contents:write, pull-requests:write, issues:write, administration:write,
metadata:read across all 17 orgs. That is a sweeping capability set.

**Attack path:**
1. Acquire `Actions: write` permission on `swift-institute/.github` (e.g., via
   compromised maintainer account).
2. Dispatch `generate-metadata.yml` with `org: <target-org>` (any of 17).
3. `actions/create-github-app-token@v3` mints a token for `<target-org>` with
   `contents:write + pull-requests:write`. Mint succeeds because the bot is
   installed on the target org with at least those permissions.
4. The dispatched workflow runs `bash institute-github/.github/scripts/generate-metadata.sh`
   from `swift-institute/.github@main` (line 73 of generate-metadata.yml).
   With branch protection absent, an attacker who already has push access on
   `swift-institute/.github` could replace the script body with arbitrary code.
5. The arbitrary script runs with the minted token; capable of `git push` to
   any repo in the target org and opening PRs with arbitrary content.

**Chokepoints in place:** ✓ token is install-scoped (the bot must be installed
on the target org); ✓ scoped via `permission-*` flags (only the requested
permissions are granted, even if the App's installation has more). **Chokepoints
absent:** ✗ branch protection on `swift-institute/.github`; ✗ workflow-level
`permissions:` floor (M2 redo); ✗ a rule that requires the bot's installation
on each org to declare a *minimum-necessary-permissions* posture and keeps it
under audit (the App's per-org installation permissions are not currently
documented in this corpus).

**Concrete exposure:** any attacker with push access to
`swift-institute/.github` (currently anyone the principal has invited as a
collaborator on that one repo) is one PR away from arbitrary write on all 17
orgs. **Branch protection is the only practical chokepoint.**

References: [GitHub Apps best practices — Use minimum permissions](https://docs.github.com/en/apps/creating-github-apps/setting-up-a-github-app/about-github-apps#permissions-and-events);
the `actions/create-github-app-token` documentation explicitly notes that the
final token's permissions are intersection-bounded by the App's installation
permissions, which is why the `permission-*` inputs are scope-down knobs not
scope-up knobs.

### T4 — Supply-chain compromise via unpinned action / curl-piped helper / docker pull

**Status: PLAUSIBLE.**

Three sub-paths:

**T4a — Action via major-tag.** `actions/checkout@v6`, `actions/cache@v5`,
`SwiftyLab/setup-swift@v1`, `actions/upload-artifact@v7`, `actions/download-artifact@v8`,
`actions/create-github-app-token@v3` — all major-tag-pinned. If the upstream
repo's tag is force-moved to point at a malicious commit (e.g., maintainer
account compromised), every consumer eats the malicious code on next run.
The skill rule `[CI-013]` and `feedback_latest_versions_only.md` permit
major-tag pinning specifically — accepting this risk in exchange for
maintainability. SHA-pinning every action increases the maintenance burden
substantially across many workflows. The trade-off is documented and
deliberate.

Partial mitigation: Dependabot for GitHub Actions (`package-ecosystem:
"github-actions"` in `dependabot.yml`) opens PRs when an action's *latest
release* moves, surfacing maintainer-account-compromise events that retag a
prior release as a side-effect of the version bump; both `.github` repos
already carry `dependabot.yml` per the centralized sync mechanism, so the
lever exists. Dependabot does NOT detect silent retag-of-existing-tag (the
canonical T4a vector); for that, harden-runner block-mode (G2) is the
operative chokepoint.

**T4b — curl-piped helper.** Two sites:
- `read-orgs/action.yml` line 93: `curl -fsSL "https://github.com/mikefarah/yq/releases/download/v4.45.4/yq_linux_amd64" -o /usr/local/bin/yq` — no checksum. `actions/cache@v5` keys on `v4.45.4`, so cache hit avoids re-fetch; cold install trusts HTTPS + GitHub-as-mirror only.
- `swift-ci.yml` lines 268–272: SwiftLint binary unzip from `https://github.com/realm/SwiftLint/releases/download/.../swiftlint_linux_amd64.zip` — no checksum.
- `lint-mechanical-hygiene-weekly.yml` line 71: `pip install --quiet yamllint` — no version pin, no `--require-hashes`. Pulls latest yamllint at sweep-run time.
- `link-check.yml` lines 158–161: lychee tarball curl + extract — no checksum.

GHSA precedent: [GHSA-2vpc-h9hg-9m92](https://github.com/advisories/GHSA-2vpc-h9hg-9m92)
(dependency confusion / supply-chain class). The yq, SwiftLint, lychee fetches
are HTTPS-only from a single mirror; if the mirror is compromised, runners
download arbitrary binaries.

**T4c — Docker container.** `swift:6.3` and `swiftlang/swift:nightly-main-jammy`
are unpinned by digest. A force-republish at the same tag runs in CI without
warning. The Apple Swift containers are operated by Apple; risk is low but
not zero.

**Chokepoints in place:** ✓ harden-runner audit-mode logs every outbound
connection (would surface mirror compromise). ✗ no SHA-pinning on actions or
binary mirror downloads; ✗ no digest-pinning on container images.

### T5 — Shell-injection via repo-controlled content into `run:`

**Status: PLAUSIBLE → MITIGATED.**

The H4 class. Every site where repo-controlled content (PR title, branch name,
matrix value, target name) reaches a `run:` block uses env-var indirection,
not `${{ }}` direct interpolation. Specifically:
- `lint-pr-title.yml:61`: `PR_TITLE: ${{ github.event.pull_request.title }}` — env, not interp.
- `lint-api-breakage.yml:77`: `BASE_SHA: ${{ github.event.pull_request.base.sha }}` — env.
- `link-check.yml:179–184`: `GH_TOKEN`, `DRY_RUN`, `SINGLE_REPO`, `INPUT_ORG`, `INPUT_VISIBILITY`, `ENUM_REPOS` — all env.
- `submit-dep-graph-weekly.yml:130–133`: same pattern.

**One residual: `cron-audit-base.yml:208`**

```yaml
- name: Run audit
  shell: bash
  env:
    GH_TOKEN: ${{ steps.token.outputs.token }}
    ORG: ${{ matrix.org }}
  run: ${{ inputs.audit-step }}
```

`inputs.audit-step` is a workflow_call STRING input that is interpolated
DIRECTLY into the `run:` body. The shell snippet is authored at workflow-file-
write time (each caller embeds its own audit-step inline in its `with:`
block). For this to be exploited, an attacker would need to (a) edit one of
the four caller workflows in `swift-institute/.github` and inject malicious
shell, OR (b) trigger the workflow with attacker-controlled `audit-step` input.
Path (b) is closed because no human-facing trigger forwards `audit-step`
freely — only the four scheduled cron callers invoke it, each with a
literal-string `audit-step` value. Path (a) reduces to "push to
`swift-institute/.github@main`" — the same chokepoint as T2/T3.

**This is documented in `[CI-080]`'s caveat about workflow_call permissions
chain orthogonality; the audit-step shell-input pattern is the
caller-trust-boundary equivalent.** No additional mitigation needed beyond
branch protection.

References: [GitHub Actions security hardening — Untrusted input](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-an-intermediate-environment-variable);
[GHSA-mcph-m25j-8j63](https://github.com/advisories/GHSA-mcph-m25j-8j63) (representative
PR-title shell-injection PoC on a different stack).

### T6 — Speculative paths

**Status: SPECULATIVE.**

- **Cache poisoning of `actions/cache@v5`-stored SwiftLint binary.** A repo
  can poison a cache that another repo reads — but only across repos owned
  by the same GitHub user/org. The `actions/cache` storage scope is
  per-repository, so cross-repo cache poisoning is not the canonical risk.
  Within a single repo, attacker would need write access to populate the
  cache key — same chokepoint as T2.
- **Dependabot or other apps assuming the bot's identity in PR comments.**
  The bot's commits are signed `swift-institute-bot@users.noreply.github.com`
  (per `generate-metadata.sh:198`); a malicious PR could spoof the email in
  its commits but not the verification. Out of scope.
- **Container-escape via swift toolchain bug.** Real but out of scope
  (not a CI/CD-stack-scoped issue).

## Scope 3 — Gap Inventory

Cross-references reviewer feedback (H1–H4 resolved), `[CI-001]`–`[CI-080]`,
prior-art survey's 3 candidates (harden-runner, conclusion-aggregator, OIDC
keyless), and cross-ecosystem-reuse findings against current state. Gaps are
labeled by **risk class** (correctness / secret-leak / supply-chain /
write-access-elevation) and **scope** (single repo / fleet) per the brief.

### G1 — Branch protection absent on `swift-institute/.github` and `swift-primitives/.github`

- **Risk class:** write-access-elevation
- **Scope:** fleet (all 17 orgs depend on `@main` ref of these two repos)
- **Status:** Cohort B Phase 2, queued.
- **Concrete impact:** T2 + T3 + T5 all reduce to "push to `<repo>@main`."
  Branch protection with `required_status_checks` pointing at `ci-ok` (Cohort
  B Phase 1, landed) gates `@main` to "PR + green CI + ≥1 review."
- **Resolution:** see Scope 4 — Branch-Protection Minimal Proposal.
- **Prerequisite:** `ci-ok` aggregator already lands per Cohort B Phase 1
  (universal `swift-ci.yml:380`, L1 wrapper `swift-ci.yml:341`). No further
  prerequisite.

### G2 — harden-runner block-mode flip protocol underspecified

- **Risk class:** supply-chain (T4b mitigation)
- **Scope:** fleet
- **Status:** Cohort A2, queued. `[CI-080]` codifies the floor (audit-mode)
  but the block-mode-flip procedure is sketchy at lines 818–823 ("wait ≥1
  week," "harvest egress logs," "build allowlists").
- **Concrete impact:** audit-mode logs egress but does not block. A
  compromised mirror (T4b) is detected post-hoc only.
- **Resolution detail (proposed amendment to `[CI-080]`):**
  1. Define the observation window precisely: **2 consecutive weekly cron
     sweep cycles** (covers the longest cadence in the stack —
     `*-weekly.yml` jobs at 06:00–06:50 UTC Monday) plus continuous
     PR-triggered runs in the same period.
  2. Define harvest mechanism: parse harden-runner job-summary output
     (per [step-security/harden-runner README — outbound network calls](https://github.com/step-security/harden-runner#detect-outbound-network-calls))
     across the last 14 days of runs via `gh run list` + `gh run view --json`
     scripted query. Aggregate to per-workflow allowlists.
  3. Define per-workflow allowlist canonical set:
     - `swift-ci.yml` matrix jobs: `github.com:443`, `*.actions.githubusercontent.com:443`,
       `archive.ubuntu.com:80`, `security.ubuntu.com:80`, `download.swift.org:443`,
       `swift.org:443`, `*.docker.io:443`, `*.cloudfront.net:443` (apt mirror CDN),
       `objects.githubusercontent.com:443` (release downloads).
     - `swift-ci.yml` lint job (additional): `github.com/realm/SwiftLint/releases/...:443`,
       `github.com/mikefarah/yq/releases/...:443`.
     - `swift-docs.yml`: subset of matrix's set.
     - `cron-audit-base.yml`: subset + `cli.github.com:443` (gh CLI install).
     - `submit-dep-graph-weekly.yml`: subset + outbound POST to `api.github.com:443`.
  4. Per-workflow flip is a single PR: change `egress-policy: audit` →
     `egress-policy: block` and add `allowed-endpoints: |` block.
  5. Canary sequence: `swift-ci.yml` first, observe one weekly cycle, then
     `swift-docs.yml`, then crons. Total flip wave: 4 PRs across 2–3 weeks.
  6. Container jobs (those running in `swift:6.3` etc.) where harden-runner
     reports "disabled" (no `CAP_NET_ADMIN`) — leave at audit-mode flag for
     now; track upstream resolution. Per `[CI-080]`'s "container jobs fall
     back to disabled with a warning — additive, never breaking."
- **Prerequisite:** ≥2 weeks of audit-mode observation post Cohort-A1 landing.
  Cohort A1 landed 2026-05-06; flip readiness = 2026-05-20 at earliest.

### G3 — Workflow-level `permissions:` floor absent (M2 redo)

- **Risk class:** write-access-elevation defense-in-depth
- **Scope:** fleet (every workflow file)
- **Status:** M2 attempted-and-reverted per `feedback_top_level_permissions_on_reusables.md`
  + `feedback_workflow_call_permissions_chain.md`.
- **Concrete impact:** workflow-level `permissions: {}` would deny every
  unspecified permission, giving defense-in-depth on standalone workflows.
  But on `workflow_call` reusables, top-level `permissions: {}` is rejected
  at parse time per the intersection rule — ALL callers' permissions are
  reduced to the empty intersection, breaking them.
- **Resolution detail (the M2-redo plan):**
  1. Standalone workflows (those with `on: schedule` or `on: workflow_dispatch`
     only — NO `workflow_call`): SAFE to add workflow-level
     `permissions: { contents: read }` (or `{}` for ones that take no contents
     at all). Affected files: `link-check-weekly.yml`,
     `lint-readme-presence-weekly.yml`, `lint-license-header-weekly.yml`,
     `lint-test-support-spine-weekly.yml`, `lint-mechanical-hygiene-weekly.yml`,
     `submit-dep-graph-weekly.yml`, `sync-metadata-nightly.yml`.
     7 workflows × 1-line workflow-level `permissions:` block = 7 surgical
     commits.
  2. Reusables (`workflow_call`): MUST NOT add workflow-level `permissions:` —
     keep the per-job grants exactly as today. Already correct.
  3. Composite actions: the `permissions:` key is not valid in composite-action
     YAML. N/A.
- **Provenance verification:** the M2 incident commit message will document
  that "M2 redo applies workflow-level permissions ONLY to standalone
  workflows; reusables retain per-job grants per workflow_call permissions
  intersection rule."
- **Prerequisite:** none.

### G4 — Unpinned binary-install supply-chain (yq, yamllint, SwiftLint, lychee)

- **Risk class:** supply-chain (T4b)
- **Scope:** fleet
- **Status:** unaddressed.
- **Concrete impact:** see T4b. Mirror compromise = silent runner compromise
  until detected by harden-runner block-mode (post-G2).
- **Resolution detail:**
  - yq: pin to a known SHA-256 of `yq_linux_amd64` for `v4.45.4`. Verification:
    `curl -fsSL ... | sha256sum -c -` against a hardcoded checksum; on
    mismatch, fail. The cache key already locks the version; the verification
    only runs on cache miss.
  - SwiftLint: same pattern — pin checksum of `swiftlint_linux_amd64.zip` for
    `0.63.2`.
  - lychee: same — pin checksum of `lychee-x86_64-unknown-linux-gnu.tar.gz`
    for `0.24.2`.
  - yamllint: `pip install yamllint==1.35.1 --require-hashes` with the
    PyPI hash record. Or skip pip and install via `apt-get install -y -qq yamllint`
    (Ubuntu provides 1.32.0 — adequate for this stack's checks). The latter
    is simpler.
  - Container images (`swift:6.3`, `swiftlang/swift:nightly-main-jammy`):
    deferred — Apple-operated, low risk, the digest-pinning maintenance
    burden is high. Document the deferral in a SKILL note.
- **`[RES-018]` check:** no new infrastructure proposed. Existing `actions/cache`
  + curl pattern extends with a `sha256sum -c` line per site. ~5 line edits
  total across 4 sites. **Composes with existing primitives.**
- **Maintenance protocol (proposed `[CI-082]` rule):** the per-site
  ~5-line edit is the one-time landing cost; the recurring cost is
  re-locking the SHA-256 on every version bump, which is where the
  protection rots if not codified. Propose `[CI-082] — Binary-Install
  Version-Bump Protocol`: when bumping a pinned binary's version
  (`SWIFTLINT_VERSION`, `LYCHEE_VERSION`, `yq` version literal, etc.),
  the same PR MUST (a) update the version env var or literal, (b)
  re-lock the SHA-256 in the same edit window via local
  `curl -fsSL <new-url> | sha256sum` and paste the digest into the
  `sha256sum -c` step, (c) verify CI fails on a deliberate
  digest-mismatch test before merge. The CI invariant: a workflow whose
  pinned checksum doesn't match the URL contents must fail-closed (no
  silent fallback to "trust the HTTPS"). The rule pairs with `[CI-013]`
  and `feedback_latest_versions_only.md` — those say "use the latest
  version"; `[CI-082]` says "and re-lock the digest when you do."
- **Prerequisite:** none.

### G5 — `lint-readme-presence-weekly.yml` hardcodes org list

- **Risk class:** correctness (drift); secondary supply-chain via "missed
  org sweep" coverage gap
- **Scope:** single workflow file
- **Status:** unaddressed.
- **Concrete impact:** lines 39–56 of `lint-readme-presence-weekly.yml`
  hardcode the 17-org list. `read-orgs/orgs.yaml` is the canonical source
  of truth (`read-orgs/orgs.yaml:1`–14 explicitly state this). When a new
  org is added (e.g., per the cross-ecosystem-reuse cohort proposing
  `swift-standards/.github` and `swift-foundations/.github` as L2/L3 layer
  wrappers), this workflow's list will drift.
- **Resolution detail:** replace the hardcoded matrix with a `config:` job
  using the `read-orgs` composite, mirroring the other 5 weekly orchestrators'
  `config:` → `audit:` (or `sweep:` → `report:`) shape. ~15-line edit.
- **Prerequisite:** none.

### G6 — Conclusion aggregator (`ci-ok`) excludes `embedded` job by design — verify exclusion is documented in branch-protection setup

- **Risk class:** correctness
- **Scope:** swift-primitives consumers (~132 repos)
- **Status:** by design per `[CI-080]`'s "excluded jobs" table; `embedded` is
  `continue-on-error: true` and not in `ci-ok` `needs:` list at the L1
  wrapper (`swift-primitives/.github/.github/workflows/swift-ci.yml:344`).
- **Concrete impact:** when branch protection lands (G1 / Cohort B Phase 2)
  and gates on `ci-ok`, embedded-buildability defects do NOT block merge.
  This is intended (nightly toolchain instability per `[CI-021]`) but is a
  known correctness trade-off. Documenting the trade-off in the branch-
  protection-setup memo prevents future "why isn't embedded gating?" rediscovery.
- **Resolution detail:** Scope 4's branch-protection PROPOSAL must explicitly
  enumerate the `ci-ok` `needs:` list and the rationale for what's excluded.
  No code change.
- **Prerequisite:** none.

### G7 — `audit-step` shell-input pattern is reusable-internal trust boundary, not a code-level mitigation

- **Risk class:** write-access-elevation (chained with G1)
- **Scope:** `cron-audit-base.yml` callers
- **Status:** documented in this review (T5); no separate mitigation.
- **Concrete impact:** the `inputs.audit-step` shell-injection vector is
  closed iff (a) only trusted workflows in `swift-institute/.github` invoke
  the reusable AND (b) `swift-institute/.github@main` is branch-protected.
  G1 closes both halves.
- **Resolution detail:** add a SKILL note documenting that the audit-step
  pattern's safety is a function of caller-trust + branch-protection, NOT
  in-workflow input sanitization. This is the kind of fact a future
  reviewer needs to know. Propose a new `[CI-081] — Audit-Step Shell-Input
  Trust-Boundary Pattern` whose statement reads: *"A reusable workflow that
  interpolates a `workflow_call` STRING input directly into a `run:` block
  (canonical example: `cron-audit-base.yml`'s `run: ${{ inputs.audit-step }}`
  pattern) MUST be invoked only by callers in any branch-protected
  layer-wrapper repo. The pattern's safety is a function of (a) caller-trust
  + (b) branch-protection on the calling workflow's repo, NOT in-workflow
  input sanitization."* The "branch-protected layer-wrapper repo" wording
  is deliberately general so the rule survives the L2/L3 wrapper rollout —
  once `swift-standards/.github` and `swift-foundations/.github` exist as
  layer wrappers per `ci-cd-cross-ecosystem-reuse.md` v1.1.0, callers from
  those repos satisfy `[CI-081]` without rule re-edit. Cross-reference to
  `[CI-080]` (orthogonal harden-runner mechanism), `[CI-001]` (three-tier
  workflow chain), `[CI-070]` (composite-action call-site eligibility — same
  trust-boundary class).
- **Prerequisite:** G1 landed (so the "branch-protected layer-wrapper repo"
  precondition is non-vacuous on the host repos).

### G8 — OIDC keyless attestation / cosign for tagged releases (Cohort C / M7)

- **Risk class:** supply-chain (downstream consumer integrity)
- **Scope:** future tagged releases (none today)
- **Status:** prior-art-and-pattern-survey RECOMMENDATION (Tier 2);
  deferred until first tag.
- **Concrete impact:** when a Swift Institute package is first tagged (e.g.,
  swift-witnesses-primitives at `0.1.0`), downstream consumers cannot
  cryptographically verify the artifact's origin. SwiftPM Trusted Publishers
  is being designed but not yet shipping; sigstore/cosign provides the
  near-term path. **Prerequisite is the first tag** — per
  `feedback_no_public_or_tag_without_explicit_yes.md`, that's an explicit
  authorization gate.
- **Resolution detail:** queued at Cohort C; do not provision until first tag
  is on the explicit-authorization roadmap.
- **`[RES-018]` check:** new infra (release workflow) — but the second
  consumer is "every future tag," and there's no existing primitive that
  composes for OIDC attestation. **Justified when first tag is in scope.**

### G9 — Lint-readme-* drift across consumer repos (queued in SwiftLint-rollout)

- **Risk class:** correctness
- **Scope:** out-of-scope for this review per "Do Not Touch" — the SwiftLint-
  rollout-supervisor's `HANDOFF-rollout-phase-1.md` and
  `HANDOFF-r1r4-cleanup-wave-1.md` cover it.
- **Status:** in-flight in parallel session; this review takes no action.
- **Resolution detail:** none from this review. Note inclusion only for
  cohort-sequencing completeness (Scope 5).

### G10 — Bot installation permissions audit

- **Risk class:** write-access-elevation
- **Scope:** fleet (all 17 ecosystem orgs in `read-orgs/orgs.yaml`)
- **Status:** unaddressed.
- **Concrete impact:** T3 establishes that the bot's *installation
  permissions* on each org are the upper bound on what
  `actions/create-github-app-token@v3` can mint — `permission-*` flags
  scope DOWN, not UP. The corollary is that the actual installed
  permissions on each of the 17 orgs are the true capability set, but
  **those installed permissions are not currently enumerated anywhere in
  this corpus**. Per-workflow scope-down inputs (`permission-contents: write`,
  `permission-pull-requests: write`, etc.) imply the installation must have
  AT LEAST those permissions — but it could have MORE, and over-permissioned
  installs widen the blast radius if the bot's App credentials leak (T3
  amplification).
- **Resolution detail:** per-org `gh api orgs/<org>/installations` →
  identify the swift-institute-bot installation ID → `gh api
  /orgs/<org>/installations/<id>` to retrieve the declared permission set.
  Build a manifest at `swift-institute/.github/.github/actions/read-orgs/bot-installations.yaml`
  (or a comment-pinned table in `orgs.yaml`) of declared permissions per
  org. Compare against the union of `permission-*` flags appearing in
  workflow files; flag any org whose declared permissions exceed the union
  (over-permissioned) or whose declared permissions are insufficient
  (under-permissioned — would surface as 403 at mint time, not silent).
  Re-run quarterly bundled with the audit-log cadence in G6/G7.
- **`[RES-018]` check:** no new infra; one new manifest file authored by a
  shell + gh-CLI script, no new automation primitive. Composes with
  `read-orgs` composite as the manifest's natural neighbor. ✓
- **Estimated time:** 1 hour to enumerate + 30 minutes to draft manifest.
- **Cohort:** **NEW Cohort F** (parallel to G4 / Cohort D).
- **Prerequisite:** principal-admin `admin:org` token to read each org's
  installation list (the agent's bot-token won't have `admin:org`); user-
  side enumeration via `gh auth refresh -h github.com -s admin:org` first.

### Summary of gap counts

| Gap | Risk class | Status | Cohort |
|---|---|---|---|
| G1 Branch protection | write-elev | queued | Cohort B Phase 2 |
| G2 Block-mode flip protocol | supply-chain | queued | Cohort A2 |
| G3 Workflow-level permissions floor | write-elev defense-in-depth | revisit | M2 redo |
| G4 Binary-install checksum verification | supply-chain | unaddressed | NEW Cohort D |
| G5 orgs.yaml drift in lint-readme-presence-weekly | correctness | unaddressed | NEW Cohort E |
| G6 ci-ok exclusion documentation | correctness | document only | bundled with G1 |
| G7 audit-step trust-boundary doc | write-elev (chained) | document only | bundled with G1 |
| G8 OIDC keyless attestation | supply-chain (downstream) | deferred | Cohort C / M7 |
| G9 lint-readme-* drift | correctness | parallel agent | out-of-scope |
| G10 Bot installation permissions audit | write-elev | unaddressed | NEW Cohort F |

## Scope 4 — Branch-Protection Minimal Proposal

This section specifies the EXACT `gh api` shape per repo. The harness denied a
prior unauthenticated attempt at branch-protection PUT; per
`feedback_no_public_or_tag_without_explicit_yes.md` and `[CI-052]`, the
principal's explicit per-action authorization is required to execute.
**This document is the proposal; execution is out of scope.**

### Public-repo scope

Branch protection applies to every public repo whose CI runs `ci-ok`. The
in-scope set today is:

| Repo set | Count | Required check |
|---|---|---|
| `swift-primitives/swift-*-primitives` (132 consumers per Phase B7c) | 132 | `ci-ok` (from L1 wrapper at `swift-primitives/.github/.github/workflows/swift-ci.yml:341`) |
| `swift-institute/.github` (the workflow-host repo itself) | 1 | none — see special case below |
| `swift-primitives/.github` (the L1-wrapper-host repo) | 1 | none — see special case below |

The 132 consumer repos all route their CI through the L1 wrapper, so the
required check name is `ci-ok` consistently.

For the two `.github` host repos, branch protection is necessary (T2/T3/T5
chokepoint) but those repos do NOT themselves run a build/test CI matrix
on push/PR — they host reusable workflows that fire elsewhere. The
required-checks set for them is the empty list; the protection is purely
about review + force-push prevention.

### Minimal protection definition

Per `[CI-080]` and Cohort B Phase 1 the gating contract is:
- `required_status_checks.contexts: [ci-ok]` — exactly one check, name does
  not interpolate per `swift-ci.yml:368–369`'s comment.
- `required_status_checks.strict: true` — require branches to be up-to-date
  before merging (i.e., the head commit must be tested, not an outdated copy).
- `required_pull_request_reviews.required_approving_review_count: 1` —
  one human review per PR.
- `enforce_admins: true` — admins not exempt from the rules. **Load-bearing**:
  the principal admin would otherwise have the ability to bypass T2/T3/T5
  protections, which defeats the purpose.

  Trade-off: setting `enforce_admins: true` removes the principal's
  emergency-bypass lever (e.g., a wedge requiring a direct push to fix CI
  itself). The alternative — `enforce_admins: false` — preserves that lever
  but also preserves the T2/T3/T5 chokepoint-bypass that branch protection
  was specified to close: an attacker who compromises the principal's
  account inherits the same bypass. Recommendation defaults to **`true`**
  on the priority axis (correctness > security > speed) — emergency-fix
  paths can route through a temporary protection-disable + targeted push +
  re-enable, which is one extra `gh api` call but logged in the audit trail.
  The principal explicitly chooses; both choices are defensible.
- `restrictions: null` — no push restrictions beyond what protection rules
  imply. Single-maintainer ecosystem; restrictions add friction without
  value.
- `allow_force_pushes: false` — prevent force-push to main, which is the
  T2/T3 entry point.
- `allow_deletions: false` — prevent branch deletion.

### Exact `gh api` call shape (per repo)

For consumer repos with the `ci-ok` check:

```bash
gh api -X PUT "repos/<owner>/<repo>/branches/main/protection" \
  --raw-field 'required_status_checks={"strict":true,"contexts":["ci-ok"]}' \
  --raw-field 'required_pull_request_reviews={"required_approving_review_count":1,"dismiss_stale_reviews":false,"require_code_owner_reviews":false}' \
  --field 'enforce_admins=true' \
  --raw-field 'restrictions=' \
  --field 'allow_force_pushes=false' \
  --field 'allow_deletions=false'
```

For the two `.github` host repos (no required check):

```bash
gh api -X PUT "repos/swift-institute/.github/branches/main/protection" \
  --raw-field 'required_status_checks=' \
  --raw-field 'required_pull_request_reviews={"required_approving_review_count":1,"dismiss_stale_reviews":false,"require_code_owner_reviews":false}' \
  --field 'enforce_admins=true' \
  --raw-field 'restrictions=' \
  --field 'allow_force_pushes=false' \
  --field 'allow_deletions=false'
```

(Same for `swift-primitives/.github`.)

References: [GitHub REST API — Update branch protection](https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#update-branch-protection).

### Provisioning order

Apply in three waves with verification between:

**Wave 1 — host repos (highest priority, smallest blast radius).**
1. `swift-institute/.github` ← protect main (no check).
2. `swift-primitives/.github` ← protect main (no check).

Each is a single repo. Verification: (1) after PUT succeeds, run
`gh api repos/<owner>/<repo>/branches/main/protection` and diff the response
against the expected JSON shape — catches `gh` CLI parameter-encoding gotchas
where flags like `--field` vs `--raw-field` silently coerce types
(observed: nested objects passed via `--field` get JSON-stringified, breaking
the protection record); (2) open a test PR; (3) attempt force-push to main —
expect both rejected.

**Forward-reference:** when the `ci-cd-cross-ecosystem-reuse.md` v1.1.0
cohort lands wrappers in `swift-standards/.github` and
`swift-foundations/.github`, those become 2 additional chokepoint repos and
join Wave 1 in the next protection refresh (same `gh api` shape, no required
check). The wave is structurally additive, not a re-protection of existing
repos.

**Wave 2 — canary consumers (4 repos covering the matrix shape).**
1. `swift-primitives/swift-tagged-primitives`
2. `swift-primitives/swift-property-primitives`
3. `swift-primitives/swift-witness-primitives`
4. `swift-primitives/swift-carrier-primitives`

(Listed in the brief — these are the canonical canaries from the Phase B7
rollout; both public CI flows are well-exercised.) Verify each PRs through
green `ci-ok` and that admin force-push is rejected.

**Wave 3 — fleet fanout (128 remaining swift-primitives consumers).**
Scripted via `gh repo list swift-primitives --visibility public --json nameWithOwner --jq` →
loop with the same `gh api -X PUT` shape. Per `[CI-051]` (surgical commits,
dirty-skip) — but for branch-protection PUT this maps to "skip if PUT fails
on a particular repo, log + continue."

### Authorization gate

Each wave is a separate "YES DO NOW PROTECT" per `[CI-052]` — branch-protection
flips are repo settings changes, externally observable, and partially
irreversible (PR history with admin-bypass commits would persist). The
principal authorizes:
- Wave 1 explicitly (`YES DO NOW PROTECT host-repos`).
- Wave 2 explicitly (`YES DO NOW PROTECT canaries`).
- Wave 3 explicitly (`YES DO NOW PROTECT fleet`).

Inferred authorization, "/loop" continuation, and auto-mode default are
**not sufficient** per the visibility/tag-class rule's spirit (`[CI-052]`).

## Scope 5 — Cohort Sequencing

Order surfaced cohorts by **marginal-risk-reduction × inverse-implementation-cost**.
Each cohort labeled with prerequisites and per-action authorization gates per
`[CI-050]` and `feedback_user_plan_is_roadmap_not_authorization.md`.

### Phase 1 — Land queued in-flight cohorts (no new dispatch)

**Phase 1.1 — Cohort B Phase 2 (branch protection, G1)**

| Attribute | Value |
|---|---|
| Marginal risk reduction | **highest in stack** — closes T2/T3/T5 entry point |
| Implementation cost | low (3 waves of `gh api -X PUT`) |
| Prerequisite | Cohort B Phase 1 (`ci-ok`) — ✓ landed |
| Per-action auth | per-wave (`YES DO NOW PROTECT host-repos / canaries / fleet`) |
| Estimated total time | 1–2 days (verification gates between waves) |

**Phase 1.2 — M2 redo (workflow-level permissions floor, G3)**

| Attribute | Value |
|---|---|
| Marginal risk reduction | low — defense-in-depth on standalone workflows only; reusables already correct |
| Implementation cost | very low (7 surgical commits, ~1 line each, no fanout) |
| Prerequisite | none |
| Per-action auth | one wave (`YES DO NOW push M2-redo`) — touches only `swift-institute/.github` |
| Estimated total time | 30 minutes |

These two are independent and can execute in parallel.

### Phase 2 — Block-mode flip (G2 / Cohort A2)

| Attribute | Value |
|---|---|
| Marginal risk reduction | high — closes T4b (binary mirror compromise) and T2 (egress-side) |
| Implementation cost | medium (per-workflow PRs with allowlists; verification across observation cycles) |
| Prerequisite | ≥2 weeks audit-mode observation — earliest 2026-05-20 |
| Per-action auth | per-canary + per-fleet-flip |
| Estimated total time | 2–3 weeks (driven by observation cycle, not commit volume) |

This phase requires the codified-block-mode-flip-protocol (G2 amendment to
`[CI-080]`) before execution. The amendment is small (~30 lines of skill
text) and lands as part of phase-2 PR1.

### Phase 3 — Binary-install checksum verification (G4 / NEW Cohort D) + Bot installation permissions audit (G10 / NEW Cohort F)

| Attribute | Value |
|---|---|
| Marginal risk reduction | medium — closes T4b residual after block-mode (block-mode catches connections, but checksums catch a malicious response from an allowed endpoint); G10 establishes the documented capability ceiling that T3 chokepoint analysis depends on |
| Implementation cost | low (G4: 4 sites × ~5-line edits + `[CI-082]` skill amendment; G10: ~1 hour to enumerate per-org bot installations + 30 min to draft manifest at `read-orgs/bot-installations.yaml`) |
| Prerequisite | G4: none — independent of G2; G10: principal-admin `gh auth refresh -h github.com -s admin:org` (the agent's bot-token cannot read installation lists) |
| Per-action auth | G4: one wave; G10: one wave (manifest land) — runs in parallel |
| Estimated total time | 1 day (G4) + 1.5 hours (G10), executable concurrently |

`[RES-018]` check: G4 composes with existing `actions/cache@v5` + curl
primitive; G10 composes with the `read-orgs` composite as the manifest's
natural neighbor (no new automation). ✓ both.

### Phase 4 — orgs.yaml drift fix (G5 / NEW Cohort E)

| Attribute | Value |
|---|---|
| Marginal risk reduction | low (correctness; not security per se) |
| Implementation cost | very low (~15-line edit to one workflow) |
| Prerequisite | none |
| Per-action auth | bundled with M2 redo wave OR separate one-PR wave |
| Estimated total time | 30 minutes |

### Phase 5 — Documentation cohort (G6 + G7)

| Attribute | Value |
|---|---|
| Marginal risk reduction | indirect — prevents future rediscovery cost |
| Implementation cost | very low (skill-text additions; no workflow edits) |
| Prerequisite | G1 landed (so doc text reflects branch-protection-in-place state) |
| Per-action auth | none (skill edits route through normal Skills cohort) |

This phase amends `[CI-080]` with the block-mode-flip protocol detail (G2)
and adds a new `[CI-081]` codifying the `audit-step` trust-boundary pattern
(G7). Bundles G6's branch-protection-setup memo as a cross-reference.

The Phase-5 SKILL note (in `[CI-080]` cross-references or a sibling note)
also adds one operational sentence: **"audit-log review cadence — run
`gh api orgs/<org>/audit-log` quarterly, looking for protection-bypass
events (`protected_branch.policy_override` / `protected_branch.destroy`)
and unexpected `installation.create_token` mints (token mints outside the
expected workflow-run windows)."** The cadence pairs with G10's quarterly
bot-installation-permissions audit so the principal runs both checks in
one sitting.

### Phase 6 — Cohort C / M7 (OIDC keyless attestation, G8)

| Attribute | Value |
|---|---|
| Marginal risk reduction | high (downstream consumer integrity) — but only when first tag exists |
| Implementation cost | medium (release workflow + cosign integration) |
| Prerequisite | first git tag on a Swift Institute package (per
`feedback_no_public_or_tag_without_explicit_yes.md`, separate explicit auth) |
| Per-action auth | bundled with first-tag authorization |

**This phase is gated on the principal's first-tag decision, which is itself
not on the immediate roadmap per the brief's parent context.** Hold pending
first tag.

### Sequenced phased plan

```
T+0       Phase 1.1 (branch protection wave 1: host repos)
T+0       Phase 1.2 (M2 redo, in parallel)
T+0+1d    Phase 1.1 wave 2 (canaries)
T+0+2d    Phase 1.1 wave 3 (fleet)
T+0+2d    Phase 4 (orgs.yaml drift)
T+0+3d    Phase 3 (binary checksums + bot-installations audit, parallel)
T+14d     [Block-mode observation window passes]
T+14d     Phase 2 PR1 (codify block-mode-flip-protocol; canary swift-ci.yml)
T+21d     Phase 2 PRs 2-N (fleet-flip block-mode)
T+21d     Phase 5 (documentation cohort: [CI-080] block-mode + [CI-081]
          audit-step + [CI-082] binary-install version-bump + audit-log
          quarterly cadence)
TBD       Phase 6 (Cohort C; gated on first-tag)
```

Total active-engagement time: ~3 weeks for Phases 1–5, with most of it being
the block-mode observation window (passive) rather than implementation effort.

### Per-phase principal authorization gates

| Phase | Gate count | Authorization shape |
|---|---|---|
| 1.1 | 3 | `YES DO NOW PROTECT host-repos`; `YES DO NOW PROTECT canaries`; `YES DO NOW PROTECT fleet` |
| 1.2 | 1 | `YES DO NOW push M2-redo` (single repo, low blast radius) |
| 2 | 5 | block-mode-flip skill amendment + canary + 3 fleet PRs (`YES DO NOW push block-mode <workflow>`) |
| 3 | 2 | binary checksums (`YES DO NOW push checksum-verification`); bot-installations audit + manifest (`YES DO NOW land bot-installations-manifest`) |
| 4 | 1 | orgs.yaml drift fix (`YES DO NOW push orgs-yaml-fix`) |
| 5 | 1 | documentation cohort (skills edits — normal Skills cohort flow) |
| 6 | TBD | gated on first-tag authorization |

Total per-action gates from T+0 to T+21d: 13.

## Outcome

**Status:** RECOMMENDATION (Tier 2, ecosystem-wide).

**Top-level verdict:** the stack is in **good security posture for its
maturity**. The recent reviewer-feedback wave (H1–H4) and Cohorts A1 + B
Phase 1 closed the most consequential ingress-side gaps. The remaining
architectural risk is **dominantly a single chokepoint**: branch protection
on the two `.github` host repos. Without it, T2/T3/T5 collapse to "push to
main"; with it, the bot's 17-org write capability and reusable-workflow
chain are gated on PR + green CI + 1 review + admin-included.

**Single highest-priority recommendation:** execute Cohort B Phase 2 (G1) as
soon as the principal authorizes it — Wave 1 (host repos) before Wave 2/3 in
particular, since the host repos are the chokepoint for everything else.

**Sequencing summary (also in §Phase 1.1–6 above):**

1. Cohort B Phase 2 (G1) — branch protection
2. M2 redo (G3) — workflow-level permissions on standalone workflows
3. Cohort A2 (G2) — harden-runner block-mode flip after observation window
4. NEW Cohort D (G4) — binary-install checksum verification (paired with `[CI-082]` version-bump protocol)
5. NEW Cohort F (G10) — bot installation permissions audit + manifest (parallel to Cohort D)
6. NEW Cohort E (G5) — orgs.yaml drift fix in lint-readme-presence-weekly
7. Documentation cohort (G6, G7, audit-log quarterly cadence) — skill amendments to `[CI-080]` + new `[CI-081]` (generalized to "any branch-protected layer-wrapper repo") + new `[CI-082]`
8. Cohort C / M7 (G8) — OIDC keyless attestation, gated on first tag

**No new ecosystem primitives recommended.** Per `[RES-018]`, every cohort
above either composes with existing infrastructure (G1 uses landed `ci-ok`;
G3 is per-job pattern extension; G4 extends `actions/cache` + curl pattern
with one verification line; G5 swaps a hardcoded matrix for the existing
`read-orgs` composite; G10 adds one manifest file as natural neighbor to
`read-orgs`) or is a documentation/skill amendment with zero new infra
(G2, G6, G7, plus the new `[CI-082]` version-bump protocol that pairs with
G4). The only candidate that introduces new infra is G8 (OIDC keyless /
cosign); per `[RES-018]`'s second-consumer check, the second consumer is
"every future tagged release" — clearly justified, but not until the first
tag exists.

**Threat-model strengths confirmed:**
- No `pull_request_target` or `workflow_run` triggers (T1 closed by
  architecture).
- Permissions intersection rule on workflow_call (T2 partially closed).
- Repository content into `run:` blocks consistently uses env-var indirection
  (T5 closed except for the audit-step pattern, which reduces to T2/T3
  chokepoint).
- harden-runner audit-mode floor universal (`[CI-080]` Cohort A1).
- Token-in-URL pattern uses `x-access-token:` form; lychee uses env-var
  not CLI flag (operational hygiene around `ps` listings).

**Threat-model gaps remaining (in priority order):**
- T2/T3/T5 single chokepoint = branch protection on host repos (G1).
- T4b binary-mirror integrity (G4 + G2).
- G3 defense-in-depth on standalone workflows.

**Composability with prior research:**
- `centralized-swift-ci-and-spine-gate.md`: this review consumes its
  centralization architecture as input. No conflicts.
- `ci-centralization-strategy.md` (Tier 2): this review consumes its
  Path B (`@main` ref strategy) as input; G1 (branch protection) is the
  natural next step in `@main`-pinning-with-protection.
- `ci-cd-prior-art-and-pattern-survey.md` v1.0.0: this review confirms its
  3 high-value candidates (harden-runner, conclusion-aggregator, OIDC
  keyless) — Cohort A1 + B Phase 1 landed two of them; Cohort A2 + Cohort C
  cover the third. No deviation from the survey's recommendations.
- `ci-cd-cross-ecosystem-reuse.md` v1.1.0: this review extends its
  `lint-org-bot-coverage.yml` advisory linter (Phase 3 deliverable) by
  noting that the bot's installation permissions ARE the upper-bound on
  `permission-*` scope-down — the lint should also assert each org's
  installation permissions match a documented minimum.

**Composability with skill rules:**
- `[CI-080]` block-mode-flip protocol: amend per G2; pair with audit-log
  quarterly review cadence per G6/G7 + G10.
- New `[CI-081]` proposal: codify the `audit-step` shell-input
  trust-boundary pattern per G7, generalized to "callers in any
  branch-protected layer-wrapper repo" so the rule survives the L2/L3
  wrapper rollout per `ci-cd-cross-ecosystem-reuse.md` v1.1.0.
- New `[CI-082]` proposal: codify the binary-install version-bump
  protocol per G4 (every version bump re-locks SHA-256 in the same PR;
  CI fails closed on digest mismatch).
- `[CI-050]`/`[CI-051]`/`[CI-052]` (mass-rollout discipline + visibility/tag
  authorization): Scope 4's branch-protection waves use these unchanged.

## Changelog

### v1.1.0 — 2026-05-06

Surgical revisions in response to independent-assessment pass (eight issues
raised; all resolved without restructuring). No conclusions reversed; the
v1.0.0 architectural finding (G1 branch protection on the two `.github` host
repos as the single chokepoint) is unchanged. Additions only.

- **§Scope 4 — `enforce_admins` trade-off paragraph.** v1.0.0 framed
  `enforce_admins: true` as load-bearing without acknowledging the
  emergency-bypass cost on a single-maintainer ecosystem. v1.1.0 adds a
  6-line trade-off paragraph: defaults to `true` on the priority axis
  (correctness > security > speed), but the principal explicitly chooses;
  emergency-fix paths route through temporary protection-disable + targeted
  push + re-enable (one extra `gh api`, logged in audit trail).
- **§Scope 4 — Wave 1 verification extended.** Adds: after PUT succeeds,
  `gh api repos/<owner>/<repo>/branches/main/protection` and diff against
  expected JSON shape — catches `gh` CLI parameter-encoding gotchas
  (`--field` vs `--raw-field` JSON-stringification of nested objects).
- **§Scope 4 — Wave 1 forward-reference to L2/L3 wrappers.** When
  `ci-cd-cross-ecosystem-reuse.md` v1.1.0 cohort lands wrappers in
  `swift-standards/.github` + `swift-foundations/.github`, those become 2
  additional chokepoint repos joining Wave 1 in the next protection refresh.
- **§Scope 3 — NEW G10 (Bot installation permissions audit).**
  Risk class: write-access-elevation; Scope: fleet (17 orgs); Status:
  unaddressed. Resolution: per-org `gh api orgs/<org>/installations/<id>`
  → manifest at `read-orgs/bot-installations.yaml`; flag
  over-permissioned installs. **NEW Cohort F**, parallel to Cohort D in
  Phase 3. Estimated 1.5 hours total.
- **§Scope 3 — G4 maintenance protocol (NEW `[CI-082]` proposal).**
  v1.0.0 noted the per-site one-time landing cost; v1.1.0 adds the
  recurring-cost protocol: every version bump re-locks SHA-256 in the
  same PR, CI fails closed on digest mismatch.
- **§Scope 3 — G7 generalization to "branch-protected layer-wrapper
  repo".** `[CI-081]` proposed text now reads "callers in any
  branch-protected layer-wrapper repo" instead of "trusted callers in
  swift-institute/.github" — the rule survives the L2/L3 wrapper rollout
  without re-edit.
- **§Scope 2 — T4a Dependabot addendum.** One-sentence note that
  Dependabot for GitHub Actions catches major-tag-creep PRs; both
  `.github` repos already carry `dependabot.yml`. Does not detect silent
  retag-of-existing-tag — that's harden-runner block-mode (G2) territory.
- **§Scope 5 — Phase 5 audit-log review cadence.** Documentation cohort
  now includes one operational sentence: quarterly `gh api
  orgs/<org>/audit-log` looking for `protected_branch.policy_override` /
  `protected_branch.destroy` and unexpected `installation.create_token`
  mints. Pairs with G10's quarterly cadence so principal runs both checks
  in one sitting.

Authorization-gate count: **12 → 13** (Cohort F adds one).

### v1.0.0 — 2026-05-06

Initial publication. Five-scope analysis: per-component matrix; threat
model with plausible/speculative labeling; nine gaps (G1–G9); branch-
protection minimal proposal with exact `gh api` shapes and three-wave
provisioning; six-phase cohort sequencing with 12 per-action authorization
gates over ~3 weeks. Top-level finding: the stack is in good security
posture for its maturity post Cohorts A1 + B Phase 1; the single
highest-priority remediation is branch protection on `swift-institute/.github`
and `swift-primitives/.github` (Cohort B Phase 2, queued).

## References

- `swift-institute/Skills/ci-cd-workflows/SKILL.md` — `[CI-001]`–`[CI-080]`
  rule corpus, including the universal-reusable architecture, harden-runner
  audit-mode floor, mass-rollout discipline, and visibility/tag authorization.
- `swift-institute/Research/ci-centralization-strategy.md` (v1.1.0,
  2026-04-22) — centralization architecture (Path B / `@main` ref strategy).
- `swift-institute/Research/ci-cd-prior-art-and-pattern-survey.md` (v1.0.0,
  2026-05-05) — harden-runner + conclusion-aggregator + OIDC keyless
  candidates.
- `swift-institute/Research/ci-cd-cross-ecosystem-reuse.md` (v1.1.0,
  2026-05-06) — cross-org bot coverage + L2/L3 layer-wrapper cohort.
- `swift-institute/Research/centralized-swift-ci-and-spine-gate.md` —
  original architecture rationale.
- [GitHub Actions security guides — Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [GitHub Actions — Reusing workflows: access and permissions](https://docs.github.com/en/actions/using-workflows/reusing-workflows#access-and-permissions)
- [GitHub REST API — Update branch protection](https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#update-branch-protection)
- [step-security/harden-runner — outbound network calls](https://github.com/step-security/harden-runner#detect-outbound-network-calls)
- [GitHub Apps best practices — minimum permissions](https://docs.github.com/en/apps/creating-github-apps/setting-up-a-github-app/about-github-apps#permissions-and-events)
- [GitHub Community discussion #69595 — Required Workflows trigger limitations](https://github.com/orgs/community/discussions/69595)

### Memory references

- `feedback_ci_priority_axes.md` — correctness > security > speed; cost not an axis.
- `feedback_top_level_permissions_on_reusables.md` — M2 incident lesson;
  workflow-level `permissions:` on reusables breaks workflow_call permissions
  intersection.
- `feedback_workflow_call_permissions_chain.md` — same; intersection rule.
- `feedback_workspace_scope_l1_only.md` — active workspace scope is
  swift-primitives only; L2/L3 not yet refactored.
- `feedback_no_public_or_tag_without_explicit_yes.md` — `[CI-052]`
  visibility/tag explicit-authorization rule.
- `feedback_user_plan_is_roadmap_not_authorization.md` — multi-step plans are
  roadmaps, not blanket authorization.
- `feedback_engagement_test_only_phase.md` — engagement pipeline produces
  drafts only; no posting (cited only as confirmation that Engagement / Blog /
  Audits private repos are out-of-scope for CI).
