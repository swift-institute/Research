# Private-Repo Secret Management at Ecosystem Scale

<!--
---
version: 0.2.0
last_updated: 2026-06-04
status: IN_PROGRESS
research_tier: 2
scope: ecosystem-wide
---
-->

## Context

The swift-institute ecosystem is growing from 17 orgs (verified state, 2026-05-06)
toward a 1000+ org footprint on a short horizon. `PRIVATE_REPO_TOKEN` — the
credential that authenticates consumer CI's private-repo dependency clones via
the `configure-private-repos` composite — is currently provisioned as an
org-level secret, manually set via the GitHub web UI per org per the principal's
standing rule (`feedback_no_gh_cli_admin_scope.md`). At 17 orgs, the
operational burden is ~2 hours/year on quarterly rotation cycles. At 1000+ orgs,
that scales linearly to ~120 hours/year on rotation alone — untenable.

This research evaluates architectural options for managing this credential at
scale, balancing security, maintainability, and scalability with the principal's
priority axes per `feedback_ci_priority_axes.md` (correctness > security >
speed; cost not an axis on the public-only CI surface).

The G10 cohort (`swift-institute/Research/ci-cd-security-review.md` v1.1.0 §
Cohort F; manifest at `swift-institute/.github/.github/actions/read-orgs/bot-installations.yaml`)
established **Option A** — bot-driven read-only verification via
`organization_secrets:read` consumed by `lint-org-bot-coverage-weekly`.
Option A executed 2026-05-06 (App-owner permission grant). It closes the
silent-failure-mode detection gap but does NOT address the ongoing rotation
burden or the per-org provisioning cost. At 1000+ org scale, Option A is
adequate as a bridge, untenable as a terminal state.

Open Question #2 from `swift-institute/Research/ci-cd-cross-ecosystem-reuse.md`
v1.1.1 anticipated this research.

## Question

At ecosystem scale (1000+ orgs, single-maintainer-with-bot), what architecture
distributes the credential that authenticates private-repo dependency clones
in consumer CI?

Evaluation criteria:
- **Security**: threat model + blast radius + worst-case recovery cost
- **Maintainability**: rotation cycle, gap-detection, incident recovery
- **Scalability**: one-time setup cost, ongoing burden as N grows, per-new-org
  marginal cost

## Options Under Evaluation

This document is a SEED. Each option is sketched here; full analysis deferred
to a dedicated investigation session.

### Option A — Status quo + bot-driven verification (CURRENT)

Org-level `PRIVATE_REPO_TOKEN` per org; manual provisioning via web UI; bot's
`organization_secrets:read` permission used by Sunday cron
(`lint-org-bot-coverage-weekly`) to verify provisioning state across all orgs.

**Status**: executed 2026-05-06.

**At N=1000**: untenable as terminal state. ~120h/year rotation; ~33h cumulative
provisioning. Bridge only.

### Option B — Distribute App credentials, mint per-run tokens

Each org receives `SWIFT_INSTITUTE_BOT_APP_ID` + `SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY`
as org-level secrets (replacing `PRIVATE_REPO_TOKEN`). `configure-private-repos`
composite refactored to mint a per-run install token via
`actions/create-github-app-token@v3`. Per-run tokens auto-expire (~1h).

**Pros**: Per-run tokens auto-expire — strictly better security shape than
long-lived PAT. Centralized App-key rotation (single web-UI act at App-owner
page). No quarterly rotation cycle.

**Cons**: Per-org provisioning burden persists (2 secrets per org instead of
1). App private key now distributed to N orgs' secret stores — leak surface
scales linearly with N.

**Sub-question**: Is there a way to authorize only swift-institute/.github to
mint tokens without distributing App credentials to consumers? Per current
understanding of GitHub Actions secrets-inheritance rules: NO (the universal
swift-ci.yml runs in caller's secret context when called via `workflow_call`).
Verify empirically.

### Option C — Bot writes secrets (centralized rotation)

Bot's installation grants `organization_secrets:write` across all orgs. A
scheduled workflow in `swift-institute/.github` mints PATs (or fine-grained
tokens) and writes them as `PRIVATE_REPO_TOKEN` to each org's secrets via
`gh api orgs/<org>/actions/secrets`. Auto-rotates on schedule. Onboarding new
org: install bot + done; bot self-provisions on first cron-fire.

**Pros**: Zero per-org rotation burden. Constant-cost onboarding. Operationally
cleanest at scale.

**Cons**: `organization_secrets:write` is a sweeping capability — App-key leak
enables ecosystem-wide secret rotation attack, including supply-chain
compromise via attacker-controlled token redirection. The catastrophic baseline
exists today via `contents: write` (which is necessary for orchestrators), but
secrets-write adds a stealth-rotation vector that direct-push doesn't have.

### Option C-split — Two-App separation of duties

`swift-institute-bot` keeps current permissions (no secrets-write). New
`swift-institute-secrets-bot` App: SOLE permission `organization_secrets:write`,
narrow installation scope, separate App private key stored in a different
vault. Compromise of one App's key does not cascade to the other.

**Pros**: Bounds blast radius — secret-rotation attacks require leaking the
secrets-bot key specifically. Forces separation in audit trails. Defense-in-depth
beyond the contents-write baseline.

**Cons**: Two Apps to maintain, two key-management practices, two installation
flows per onboarding (~2 min instead of ~1 min per org).

### Option E — OIDC keyless auth + external secret manager

GitHub Actions OIDC tokens exchanged for per-run credentials at HashiCorp Vault
/ AWS Secrets Manager / Azure Key Vault / Doppler / equivalent.
`PRIVATE_REPO_TOKEN` value lives in the secret manager only — not in any
GitHub org-level secret store. `configure-private-repos` exchanges OIDC token
for a per-run credential.

**Pros**: Industry-standard above ~100 orgs. Zero org-level secrets to manage.
Per-run credentials with fine-grained policies. Single source of truth. Audit
trail in secret manager. Removes the GitHub-side App-key-leak risk for THIS
credential entirely (App key still relevant for other bot operations).

**Cons**: New infrastructure dependency. Requires choosing and operating a
secret manager. Higher upfront cost; lower per-org marginal cost. Migration
cost from existing PAT pattern.

**Sub-question**: Which secret manager fits this ecosystem? Self-hosted Vault,
hosted Doppler, cloud-native (AWS/Azure/GCP), or a GitHub-native solution if
one exists or is roadmapped.

## Common Worst Case — App-Key Leak Baseline

The bot already has `contents: write` on every org. If the App private key
leaks today (pre-Option-A, post-Option-A, or under any of B/C/C-split below),
an attacker can mint `contents: write` tokens and push malicious code to
private-dep repos. This is the existing catastrophic baseline.

Each option's incremental risk over this baseline:
| Option | Marginal worst-case | Mitigation surface |
|---|---|---|
| A | none (read-only secrets metadata) | none needed beyond baseline |
| B | none (per-run tokens auto-expire; baseline unchanged) | App-key storage hygiene |
| C | non-zero — secrets:write enables stealth-rotation supply-chain compromise | branch protection on swift-institute/.github + audit-log monitoring + hardware-vault for App key |
| C-split | bounded — secrets-rotation requires leaking the SECONDARY App's key separately | two-key separation; baseline mitigations on both |
| E | removes GitHub-side App-key-leak risk for THIS credential | Vault-side key hygiene; OIDC trust policy correctness |

Threat model formalization deferred per [RES-022] / [RES-024] in the dedicated
session.

## Decision Criteria

The dedicated investigation session must produce verdicts on:

1. Operational footprint at N=17, N=100, N=1000 for each option (one-time
   setup, ongoing burden, per-new-org marginal). Empirical or modeled.
2. Threat model with explicit blast radius enumeration per option.
3. Migration cost from current state (Option A executed; bridges to terminal
   state).
4. Required mitigations per option (branch protection, hardware vault,
   monitoring cadence, etc.).
5. Decision: terminal state recommendation + phased migration path with
   per-phase principal authorization gates per `[CI-052]`.

## Sub-Questions to Verify Empirically

1. Can a `workflow_call` reusable in swift-institute/.github access its own
   org's secrets without `secrets: inherit`? Per current understanding: NO
   (caller's secret context wins). Verify empirically — affects feasibility of
   Option B alternatives.
2. Does `gh api orgs/<org>/actions/secrets/PRIVATE_REPO_TOKEN` distinguish
   404-not-found from 403-no-access in a useful way for workflow-level
   coverage probes? Affects `lint-org-bot-coverage-weekly` axis-2 logic.
3. Empirical per-org burden of GitHub web-UI secret provisioning — sample 5
   orgs, time the operation, calibrate the N=1000 projection.
4. Which secret managers have the lowest friction for the ecosystem's likely
   deployment shape (self-hosted vs hosted; cost model; OIDC integration
   maturity)?
5. Does GitHub have native or roadmapped solutions that obviate this question
   entirely (e.g., a "private package registry with built-in auth," or
   organization-level App credentials that don't require per-installation
   distribution)?

## Prior Art to Survey

Per `[RES-021]` Tier 2 prior-art survey requirement:

- Apple's `swiftlang/*` org CI patterns — private-dep auth at scale
- Microsoft's `azure-sdk-for-*` org CI patterns
- HashiCorp's `terraform-providers` org CI patterns (200+ provider repos, similar shape)
- Rust's `rust-lang/*` and `crates.io` ecosystem auth model
- Apache Foundation org CI patterns
- GitHub's own Actions-best-practices documentation on secret management at scale
- sigstore / OIDC-related GitHub Actions documentation
- Empirical: companies with 1000+ org GitHub footprints (Fortune 500 with
  multiple BUs) — how do they manage CI credentials? Public conference talks,
  engineering blog posts, GitHub-published case studies.

## References

- `swift-institute/Research/ci-cd-security-review.md` v1.1.0 — security review
  establishing G10 / Cohort F; consumes this research's outcome as input for
  the threat-model section.
- `swift-institute/Research/ci-cd-cross-ecosystem-reuse.md` v1.1.1 —
  Open Question #2; anticipates this research.
- `swift-institute/Research/ci-cd-prior-art-and-pattern-survey.md` v1.0.0 —
  general CI prior-art; section on credential management may have starting
  points for the prior-art survey above.
- `swift-institute/Research/ci-uniformity-audit.md` v1.0.0 — D5 dimension
  flagged this verification gap; closure depends on this research's outcome.
- `swift-institute/.github/.github/actions/read-orgs/bot-installations.yaml` —
  G10 manifest (empirical bot-permission state across 17 orgs).
- `swift-institute/Skills/ci-cd-workflows/SKILL.md` § `[CI-058]`–`[CI-060]`
  (free-plan visibility, bot scope), `[CI-080]` (block-mode protocol).
- Memory: `feedback_no_gh_cli_admin_scope.md` (admin operations via web UI
  only); `feedback_no_public_or_tag_without_explicit_yes.md`
  (visibility/tag authorization); `feedback_ci_priority_axes.md`
  (correctness > security > speed; cost not an axis).
- GitHub docs: Reusable workflows secrets-inheritance rules;
  `actions/create-github-app-token@v3` documentation; OIDC for GitHub Actions
  documentation; Organization secrets API documentation.
- step-security/harden-runner egress-policy patterns (relevant to Vault
  egress in Option E if pursued).

## Executed State (2026-06-04 — Option B live for CI dependency resolution)

Option B is no longer a sketch: the α arc (HANDOFF-ci-private-dep-access,
principal-ruled) executed it for the `swift package resolve` path. The
`configure-private-repos` composite mints per-job installation tokens
(contents:read, auto-expiring, auto-revoked) for the three dependency-owning
layer orgs via `actions/create-github-app-token@v3` and applies env-scoped
org-prefixed insteadOf rules; `PRIVATE_REPO_TOKEN` remains the github.com-wide
fallback. Chain commits: swift-institute/.github `5a776e9`+`d5c4b8e`,
layer wrappers `828ff44`/`be64e20` (L1), `ba0a229` (L2), `a1f4b58` (L3);
docs-path secret-transport wrappers per [CI-004a] v2 + [CI-109]; sub-org
pattern (ii) per the [CI-059] caveat (validator `d56e36a`). Both ID-name
eras are accepted ([CI-*] dual-name contract): `SWIFT_INSTITUTE_BOT_APP_CLIENT_ID`
preferred, legacy `SWIFT_INSTITUTE_BOT_APP_ID` fallback.

Option B's open sub-question is now answered empirically: there is NO way to
authorize only swift-institute/.github to mint without distributing App
credentials — and stronger, `secrets: inherit` does not deliver org secrets
across an org boundary at all ([CI-109], byte-primitives run 26959288611:
"Configured 0" cross-org-inherit vs "Configured 4" explicit-forward).

**Legacy-tier degradation finding (strengthens deprovision-after-soak)**:
two orgs so far (swift-primitives, swift-ietf) carry a `PRIVATE_REPO_TOKEN`
that is axis-2-extant but DELIVERS empty/invisible to public-repo runs —
the exists-but-doesn't-deliver class. The legacy tier is degraded across
orgs, not one; the App route obsoletes it for resolution.

### Provisioning runbook (per org; web UI per [CI-098])

1. Org → Settings → Secrets and variables → **Actions** (NOT Dependabot).
2. Create **two** org secrets, visibility **"Public repositories"**:
   - `SWIFT_INSTITUTE_BOT_APP_CLIENT_ID` — the swift-institute-bot App's
     Client ID (preferred name; the legacy numeric-App-ID era name
     `SWIFT_INSTITUTE_BOT_APP_ID` also works — client-id wins if both exist).
   - `SWIFT_INSTITUTE_BOT_APP_PRIVATE_KEY` — a PEM private key of the App.
3. **PEM handling**: GitHub Apps support multiple active private keys —
   generating a fresh key for a new org does NOT invalidate keys already in
   use elsewhere (revocation is only by explicit deletion on the App page).
   Reusing the existing PEM and generating a new one are both safe.
4. **Sub-orgs need the SECRETS only — no App installation step**: mints
   target the dependency-OWNING layer orgs (`owner:` =
   swift-primitives/standards/foundations, where the App is installed);
   the consumer org's installation state is never consulted by the mint.
5. **No code change**: the tolerant contract picks the secrets up on the
   next run.
6. **Verify** via the composite's echo in any public consumer's next run:
   - `Configured 4` — three mints + a delivering legacy token.
   - `Configured 3` — three mints; the org's legacy token is empty/dead
     (expected on degraded-legacy orgs; NOT a partial failure).
   - `Configured 1` — no App secrets delivered (wrong section, wrong
     visibility class, or name typo); legacy only.
   - `Configured 0` — nothing delivers (pre-provisioning state).
7. **Visibility note (free plan)**: org secrets cannot reach private repos
   at all, and never need to — [CI-032] gates CI off on private repos.
   Never request all-repositories visibility.

Provisioned 2026-06-04: swift-primitives (pre-existing, legacy-era name),
swift-institute (pre-existing), swift-standards, swift-foundations,
swift-ietf, swift-iso, swift-w3c, swift-whatwg, swift-incits, swift-ieee,
swift-iec. The six zero-public sub-orgs (swift-ecma, swift-arm-ltd,
swift-intel, swift-riscv, swift-linux-foundation, swift-microsoft) use this
runbook when they first gain a public package.

## Outcome

**Status**: IN_PROGRESS (seed; § Executed State records Option B live for
CI resolution as of 2026-06-04 — the Option C/D/E evaluation and the
PRIVATE_REPO_TOKEN deprovision decision remain open). Outcome deferred to
dedicated investigation session. Resume in a separate chat.

When that session opens, the agent should:

1. Read this seed end-to-end before doing any new work per `[HANDOFF-013]`.
2. Verify the empirical sub-questions (§ "Sub-Questions to Verify Empirically")
   before pursuing analytical sections.
3. Conduct the prior-art survey (§ "Prior Art to Survey") per `[RES-021]`.
4. Produce per-option operational and threat-model analyses.
5. Bump version to 1.0.0 (or 0.2.0 if intermediate); change status to
   `RECOMMENDATION` or `DECISION`; promote to terminal state.
6. Update `_index.json`'s `statusDetail` with the consolidated verdict.
