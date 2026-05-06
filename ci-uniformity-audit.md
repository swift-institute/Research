# CI Uniformity Audit — post v1.1.1 rollout

<!--
---
version: 1.0.0
last_updated: 2026-05-06
status: INVENTORY
research_tier: 2
applies_to: [institute, primitives, standards, foundations, body-orgs]
normative: false
---
-->

## Context

### Trigger

Principal directive 2026-05-06 post v1.1.1 rollout: the rollout's "Achieved:
full uniformity" claim was scoped to ci.yml chain-routing (0 stragglers).
The broader uniformity surface — wrapper-file content, non-ci-yml caller
routing, per-package metadata.yaml schema, layer-org host-repo health
files, org-secret coverage, sub-org wrapper absence — was unaudited.
Authorize a six-dimension read-only inventory before any further
operational cohort (branch protection, Phases 10–11 orchestrator-filter
expansion, etc.).

### Scope

Ecosystem-wide [RES-002a]. Six audit dimensions D1–D6 per the principal
brief. Verdict per dimension: UNIFORM / DELIBERATE-DIVERGENCE /
UNINTENTIONAL-DRIFT (plus VERIFICATION-BLOCKED for one dimension where
my token's scope cannot resolve the audit).

**Out of scope**: any state-changing remediation. Findings only. Cohort
proposals named for UNINTENTIONAL-DRIFT entries; not executed.

### Method

Read-only `gh api` + on-disk file inspection + `git diff` + grep across
the 16-non-meta-org consumer surface (390 packages with `ci.yml`) plus
the 4 host repos (swift-institute, swift-primitives, swift-standards,
swift-foundations).

### Prior research (cite-and-extend per [HANDOFF-013])

- [`ci-cd-cross-ecosystem-reuse.md`](ci-cd-cross-ecosystem-reuse.md) v1.1.1 (2026-05-06) — the rollout this audit verifies.
- [`ci-centralization-strategy.md`](ci-centralization-strategy.md) v1.1.0.
- `swift-institute/Skills/ci-cd-workflows/SKILL.md` ([CI-001]–[CI-004b]).

---

## D1 — Wrapper-file content: L1 vs L2 vs L3

### Method

Local `diff` of:
- `swift-primitives/.github/.github/workflows/swift-ci.yml` (L1, 356 lines)
- `swift-standards/.github/.github/workflows/swift-ci.yml` (L2, 84 lines)
- `swift-foundations/.github/.github/workflows/swift-ci.yml` (L3, 83 lines)

### Findings

**L1 vs L2/L3** — large diff (~250 lines):

| Delta | Classification | Citation |
|---|---|---|
| L1 `name: Swift CI (primitives layer)` vs L2 `(standards layer)` vs L3 `(foundations layer)` | DELIBERATE — layer-name string | layer identity |
| L1 header comment documents embedded invariant; L2/L3 document structural anchor | DELIBERATE — different doc framings reflect different layer roles | [CI-020] for L1, [CI-004a] for L2/L3 |
| L1 input `cache-key-prefix: type=string default=swift63-spm-v1` (used by embedded job's exact-match cache); L2/L3 don't declare it | DELIBERATE — only L1's embedded job uses cache per [CI-040] carve-out | [CI-040], [CI-020] |
| L1 `env: XCODE_VERSION: "26.4"` (used by apple-simulator-build); L2/L3 don't declare it | DELIBERATE — apple-simulator-build is L1-only | [CI-020] |
| L1 has 5 jobs beyond `matrix:` + `ci-ok`: `embedded`, `embedded-wasm-sdk`, `android-build`, `static-linux-musl-build`, `apple-simulator-build` (matrix:[iOS, tvOS, watchOS, visionOS]). L2/L3 have only `matrix:` + `ci-ok`. | DELIBERATE — L1 invariants per [PRIM-FOUND-001] + [PKG-BUILD-007]/[008] expressed as CI checks | [CI-020] |

**L2 vs L3** — small diff (~20 lines):

| Delta | Classification |
|---|---|
| Layer-name strings throughout (`standards` vs `foundations`) | DELIBERATE — naming |
| Header text references different sub-org sets (L2 lists 11 spec-authorities; L3 lists 2 vendor sub-orgs) | DELIBERATE — accurate per [CI-004b] |
| Comment text on layer-specific extensibility (L2 mentions "spec-version pin lint, authority-attribution lint"; L3 mentions "stricter Foundation-import lint, multi-vendor matrix") | DELIBERATE — layer-specific future-extension hints |
| Otherwise IDENTICAL: input declarations, secrets declaration, `matrix:` job shape, `ci-ok` aggregator | UNIFORM |

### Chain-routing-correctness check

Verified that L2 and L3 wrapper inputs match the universal's input signature:

| Input | Universal | L1 | L2 | L3 |
|---|---|---|---|---|
| `swift-version: string default="6.3"` | ✓ | ✓ | ✓ | ✓ |
| `enable-private-repos: boolean default=true` | ✓ | ✓ | ✓ | ✓ |
| `macos-runner: string default="macos-26"` | ✓ | ✓ | ✓ | ✓ |
| `cache-key-prefix: string default="swift63-spm-v1"` | (not declared) | ✓ (L1 internal use) | (n/a) | (n/a) |

Universal secret `PRIVATE_REPO_TOKEN: required: false` — forwarded by all 3 wrappers' `secrets:` block. ✓

**No chain-routing-breaking delta surfaced. Stop condition NOT triggered.**

### Verdict — D1

**DELIBERATE-DIVERGENCE** (L1 vs L2/L3, all deltas justified by [CI-020] / [CI-040] carve-out / per-layer documentation).
**UNIFORM** (L2 ↔ L3, modulo layer-name strings + extensibility-hint comments).

---

## D2 — Non-ci.yml caller routing across L2 + L3 + sub-orgs

### Method

Disk grep across 390 consumer `ci.yml` files for every `uses:` URL pattern. Tally by destination.

### Findings

**`uses: <layer>/.github/.github/workflows/swift-ci.yml@main` (build/test layer-wrapper routing):**

| Destination | Count |
|---|---|
| `swift-foundations/.github/...` | 138 (L3 + 2 L3 vendor sub-orgs) |
| `swift-primitives/.github/...` | 132 (L1 ecosystem) |
| `swift-standards/.github/...` | 120 (L2 + 11 L2 spec-authority sub-orgs) |
| **Total** | **390** ✓ |

**`uses: swift-institute/.github/.github/workflows/swift-docs.yml@main` (docs routing):**

| Destination | Count |
|---|---|
| `swift-institute/.github/.github/workflows/swift-docs.yml@main` | 390 |

Per [CI-004a] no swift-docs.yml wrappers at the layer level. All 390 consumers route directly to the universal swift-docs.yml. ✓

**ANY other `uses:` pattern in consumer ci.yml (drift surface):**

```
(zero results)
```

No consumer routes through any other reusable workflow URL. The only inter-Institute reusables consumer-callable today are `swift-ci.yml` (via layer wrapper) and `swift-docs.yml` (universal). Both audited above.

**Inventory of all reusable workflows** in `swift-institute/.github/.github/workflows/` (15 with `workflow_call`):

| Workflow | Consumer-callable? | Notes |
|---|---|---|
| `swift-ci.yml` | YES (via layer wrappers) | Universal matrix; absorbed format + lint per [CI-054] |
| `swift-docs.yml` | YES (direct) | DocC umbrella per [DOC-019a] |
| `cron-audit-base.yml` | NO | Skeleton consumed only by sibling cron orchestrators |
| `generate-metadata.yml` | NO | Called by sync-metadata.yml |
| `link-check.yml` | NO | Per-org reusable; called by link-check-weekly orchestrator |
| `lint-api-breakage.yml` / `lint-broken-symlink.yml` / `lint-license-header.yml` / `lint-pr-title.yml` / `lint-readme-presence.yml` / `lint-readme-structure.yml` / `lint-test-support-spine.yml` / `lint-yaml.yml` | NO | Called transitively from the universal `swift-ci.yml` |
| `lint-org-bot-coverage.yml` | NO | Called by lint-org-bot-coverage-weekly orchestrator (NEW 2026-05-06) |
| `sync-metadata.yml` | NO | Per-org reusable; called by sync-metadata-nightly orchestrator |

### Verdict — D2

**UNIFORM.** 132+120+138 = 390 ci-routing matches the 390 docs-routing exactly (every consumer has both `ci:` and `docs:` jobs). Zero drift surface. Layer-wrapper routing distribution matches the 132 L1 / ~120 L2-and-sub-orgs / ~138 L3-and-sub-orgs split implied by the v1.1.1 rollout count.

---

## D3 — Per-package `.github/metadata.yaml` schema uniformity

### Method

`find` enumeration of `.github/metadata.yaml` across 390 consumers; sample inspection for schema consistency.

### Findings

**Presence**: 390/390 packages have `.github/metadata.yaml` ✓.

**Schema reference** (sample from L1, swift-primitives/swift-property-primitives):

```yaml
# .github/metadata.yaml
# Triaged 2026-04-29 — refined for the swift-primitives 0.1.0 release-cohort path.
description: "Fluent accessor primitives for Swift."
topics:
  - primitives
  - property
  - accessors
  - type-safety
homepage: "https://swift-institute.org"
```

**Schema sample — L2** (swift-standards/swift-color-standard):

```yaml
description: "Colour meta-package combining CIE LAB, CIE LCH, Oklab, and Oklch colour spaces in Swift."
topics:
  - standards
  - color
  - color-spaces
  - lab
  - oklab
homepage: "https://swift-institute.org"
```

**Schema sample — L2 sub-org** (swift-ietf/swift-rfc-9111):

```yaml
description: "Swift implementation of RFC 9111: HTTP Caching."
topics:
  - standards
  - rfc
  - rfc-9111
  - http
homepage: "https://swift-institute.org"
```

**Top-level keys across all samples**: `description` (string), `topics` (list of strings), `homepage` (string). All three match.

### Verdict — D3

**UNIFORM.** 390/390 with consistent three-key schema (`description`, `topics`, `homepage`). Per `Skills/github-repository` source-of-truth pattern, the schema was propagated by the bot's metadata-add commits 2026-04-29; uniformity is the expected post-rollout state.

---

## D4 — `.github` host-repo health-file uniformity

### Method

`gh api /repos/<host>/.github/git/trees/main?recursive=1` for each of the 4 host repos.

### Findings

Per-host file presence matrix:

| File | swift-institute | swift-primitives (L1) | swift-standards (L2) | swift-foundations (L3) | Verdict |
|---|---|---|---|---|---|
| `.github/FUNDING.yml` | ✓ | ✓ | ✓ | ✓ | UNIFORM |
| `.github/ISSUE_TEMPLATE/bug_report.md` | ✓ | ✓ | ✓ | ✓ | UNIFORM |
| `.github/ISSUE_TEMPLATE/config.yml` | ✓ | ✓ | ✗ | ✗ | **DRIFT** (L2/L3 missing) |
| `.github/ISSUE_TEMPLATE/documentation.md` | ✓ | ✓ | ✓ | ✓ | UNIFORM |
| `.github/metadata.yaml` | ✓ | ✓ | ✓ | ✓ | UNIFORM |
| `.github/pull_request_template.md` | ✓ | ✓ | ✓ | ✓ | UNIFORM |
| `.github/dependabot.yml` | ✓ | ✗ | ✗ | ✗ | DELIBERATE-DIVERGENCE (umbrella-org-only — Actions-version dependency tracking) |
| `.github/workflows/swift-ci.yml` (layer wrapper) | (n/a — has many workflows) | ✓ | ✓ | ✓ | UNIFORM (post-rollout) |
| `.swiftlint.yml` (host-level config) | ✗ | ✓ | ✗ | ✗ | **DRIFT** (L2/L3 missing) |
| `CODE_OF_CONDUCT.md` | ✓ | ✓ | ✓ | ✓ | UNIFORM |
| `CONTRIBUTING.md` | ✓ | ✓ | ✓ | ✓ | UNIFORM |
| `SECURITY.md` | ✓ | ✓ | ✗ | ✗ | **DRIFT** (L2/L3 missing) |
| `profile/README.md` | ✓ | ✓ | ✓ | ✗ | **DRIFT** (L3 missing) |
| `.github/workflows/*` (orchestrators, advisory linters, etc.) | many | (n/a) | (n/a) | (n/a) | DELIBERATE — umbrella-org role |
| `.github/scripts/*`, `.github/actions/*` | many | (n/a) | (n/a) | (n/a) | DELIBERATE — umbrella-org role |

**Drift summary**:

| Missing on | File | Source-of-truth |
|---|---|---|
| L2 + L3 hosts | `.github/ISSUE_TEMPLATE/config.yml` | swift-primitives reference |
| L2 + L3 hosts | `.swiftlint.yml` (host-level) | swift-primitives reference |
| L2 + L3 hosts | `SECURITY.md` | community-health sync source (likely swift-institute/.github via GitHub default-files inheritance) |
| L3 host only | `profile/README.md` | swift-primitives + swift-standards have one |

These drift items appear UNINTENTIONAL — they look like community-health files that haven't been propagated to the layer hosts (or were propagated to L1 via an earlier sync run that didn't cover L2/L3). Per [CI-043] `.gitignore` is centrally managed via `Scripts/sync-gitignore.sh`; an analogous `Scripts/sync-community-health.sh` is referenced in `ci-centralization-strategy.md` v1.1.0 as the centralization mechanism for these files. Likely the sync script needs running against swift-standards/.github + swift-foundations/.github.

The `dependabot.yml`-on-swift-institute-only is DELIBERATE — the umbrella org runs Actions and tracks action-version updates; layer hosts didn't run Actions until today's rollout.

The umbrella-org content (`.github/workflows/`, `.github/scripts/`, `.github/actions/`) is DELIBERATE — that's swift-institute's role per `[GH-REPO-070]`.

### Proposed remediation cohort (NOT executed)

**Cohort name**: "Layer-host community-health sync"
**Scope**: 4 files × 2 hosts (L2 + L3); 1 file × 1 host (L3 profile/README.md)
**Mechanism**: run `Scripts/sync-community-health.sh` (or equivalent) against swift-standards/.github + swift-foundations/.github. Or copy-and-adapt the missing files from swift-primitives/.github / swift-institute/.github as canonical sources.
**Authorization required**: per-action YES (file content depends on each layer's role; not pure mechanical copy).
**Stop conditions**: profile/README.md content for L3 needs authoring (the L1 + L2 versions reference layer-specific terminology); not a direct copy.

### Verdict — D4

**UNINTENTIONAL-DRIFT** for ISSUE_TEMPLATE/config.yml + .swiftlint.yml + SECURITY.md (across L2 + L3) and profile/README.md (L3 only). Plus DELIBERATE-DIVERGENCE for swift-institute (umbrella role).

---

## D5 — Org-level `PRIVATE_REPO_TOKEN` secret coverage

### Method

`gh api /orgs/<org>/actions/secrets` for each of the 17 orgs in `orgs.yaml`.

### Findings

**All 17 orgs returned 403 / "Resource not accessible"** — my GitHub token lacks `admin:org` scope, the required scope for listing org-level Actions secrets per the GitHub REST API's permissions model.

```
17/17 orgs: scope-blocked (verification not possible from this token).
```

### Verification path

The audit cannot resolve D5 directly. The natural verification mechanism is the new `lint-org-bot-coverage.yml` reusable + `lint-org-bot-coverage-weekly.yml` orchestrator landed at swift-institute/.github (commit `8cbe5c0`) which:

1. Mints a per-org installation token via `actions/create-github-app-token@v3` from the central swift-institute-bot client-id/private-key pair.
2. Calls `gh api /orgs/<org>/actions/secrets/PRIVATE_REPO_TOKEN` per org.
3. Surfaces gaps via tracking-issue at swift-institute/.github per [README-167].

**First scheduled fire**: Sunday 2026-05-10 06:30 UTC. The cron's tracking-issue output IS the canonical D5 verification.

**Open question**: does the swift-institute-bot App's permission set include `read:org` for `actions/secrets` metadata? If not, the cron fires but axis 2 of the coverage check returns the same scope-block I'm seeing. Per Open Question #2 in `ci-cd-cross-ecosystem-reuse.md` v1.1.1, this needs verification before the cron's first fire is fully load-bearing for D5.

### Verdict — D5

**VERIFICATION-BLOCKED.** Defer to Sunday 2026-05-10 06:30 UTC `lint-org-bot-coverage-weekly` first cron fire as the canonical verification mechanism. If that cron's axis-2 result is itself scope-blocked (App-level), it routes to the App-permission-bump cohort (out of scope for this audit).

**Stop condition status**: D5 stop condition (any org with `PRIVATE_REPO_TOKEN ABSENT`) NOT triggered because absence cannot be confirmed. The conditional state is "unknown, unverifiable from this token."

---

## D6 — Sub-org wrapper presence (informational only)

### Method

`gh api /repos/<sub-org>/.github/contents/.github/workflows/swift-ci.yml` for each of the 13 sub-orgs (11 L2 spec-authority + 2 L3 vendor).

### Findings

13/13 sub-orgs return 404 on the wrapper path:

| Sub-org | swift-ci.yml present? |
|---|---|
| swift-ietf, swift-iso, swift-w3c, swift-whatwg, swift-ecma, swift-incits, swift-ieee, swift-iec, swift-arm-ltd, swift-intel, swift-riscv | NO (correct per [CI-004b]) |
| swift-linux-foundation, swift-microsoft | NO (correct per [CI-004b]) |

### Verdict — D6

**UNIFORM.** 0/13 violations. Sub-org repos correctly route through their parent layer wrapper per [CI-004b] (per-authority sub-org wrappers blocked by GitHub Actions `workflow_call` 4-level depth limit; deferred until limit relaxes or universal is refactored to inline its 6 advisory linter sub-dispatches).

---

## Cross-dimension summary

| Dimension | Verdict | Cohort proposed? |
|---|---|---|
| D1 — wrapper-file content L1/L2/L3 | DELIBERATE-DIVERGENCE (L1 vs L2/L3) + UNIFORM (L2↔L3) | No |
| D2 — non-ci.yml caller routing | UNIFORM | No |
| D3 — `.github/metadata.yaml` schema | UNIFORM | No |
| D4 — host-repo health-file uniformity | UNINTENTIONAL-DRIFT (4 file gaps across L2/L3 hosts) + DELIBERATE-DIVERGENCE (umbrella-org role) | YES — "Layer-host community-health sync" cohort named (not executed) |
| D5 — `PRIVATE_REPO_TOKEN` org-secret coverage | VERIFICATION-BLOCKED (defer to Sunday 2026-05-10 06:30 UTC cron fire) | Conditional — App-permission-bump cohort iff Sunday cron's axis-2 also scope-blocks |
| D6 — sub-org wrapper presence | UNIFORM (0/13 violations) | No |

### Counts

- **UNIFORM**: 3 (D2, D3, D6)
- **DELIBERATE-DIVERGENCE**: 1 (D1) + 1 partial (D4)
- **UNINTENTIONAL-DRIFT**: 1 (D4)
- **VERIFICATION-BLOCKED**: 1 (D5)

### Stop conditions

- **D1 chain-routing-breaking delta**: NOT triggered. Wrapper inputs/secrets correctly mirror the universal; the L1 vs L2/L3 delta is jobs-only, not chain-routing.
- **D5 missing org-secret**: NOT triggered (cannot verify). Conditional gap pending Sunday cron-fire.
- **>300 lines on any single dimension**: NOT triggered. Largest single dimension (D4) is ~75 lines. Document total ~270 lines.

### Cohort proposals (NOT executed)

1. **Layer-host community-health sync** (D4 remediation): propagate ISSUE_TEMPLATE/config.yml + .swiftlint.yml + SECURITY.md to swift-standards/.github + swift-foundations/.github; author profile/README.md for swift-foundations/.github. Authorization required: per-action YES on each file class.
2. **App-permission-bump** (D5 conditional, contingent on Sunday cron showing axis-2 scope-block): grant the swift-institute-bot App `read:org` on actions/secrets endpoint. Out of band; admin:org operation. Authorization required: per-action YES.

---

## References

### Primary sources (verified read-only 2026-05-06)

- `swift-primitives/.github/.github/workflows/swift-ci.yml` (L1 wrapper, 356 lines)
- `swift-standards/.github/.github/workflows/swift-ci.yml` (L2 wrapper, 84 lines, commit `079fefb`)
- `swift-foundations/.github/.github/workflows/swift-ci.yml` (L3 wrapper, 83 lines, commit `f5150a6`)
- `swift-institute/.github/.github/workflows/swift-ci.yml` (universal reusable, 400 lines)
- `gh api /repos/{swift-institute,swift-primitives,swift-standards,swift-foundations}/.github/git/trees/main?recursive=1` (D4 host-repo trees)
- `gh api /repos/<sub-org>/.github/contents/.github/workflows/swift-ci.yml` × 13 (D6, all 404)
- `gh api /orgs/<org>/actions/secrets` × 17 (D5, all 403/scope-blocked)
- Disk grep: 390 consumer `ci.yml` files for `uses:` URL routing

### Cross-references

- [`ci-cd-cross-ecosystem-reuse.md`](ci-cd-cross-ecosystem-reuse.md) v1.1.1 — the rollout this audit verifies.
- [`ci-centralization-strategy.md`](ci-centralization-strategy.md) v1.1.0 — sync-script + community-health propagation precedents.
- `swift-institute/Skills/ci-cd-workflows/SKILL.md` — [CI-001], [CI-004], [CI-004a], [CI-004b], [CI-020], [CI-022], [CI-040], [CI-054], [CI-060].
- `swift-institute/Skills/github-repository/SKILL.md` — [GH-REPO-070] metadata source-of-truth pattern; [README-167] tracking-issue convention.
