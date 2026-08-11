# Validation receipt: [CI-082]

Date: 2026-05-14
Rule: CI-082 (workflow steps fetching versioned binaries via curl MUST verify via `sha256sum -c` in the same `run:` block before installation; verification exit code MUST NOT be swallowed; version bumps MUST re-lock the digest in the same PR)
Detection target: `<repo>/.github/workflows/*.yml,yaml` — per-step `run:` blocks
Detection method: workflow validator (per-step shell-content inspection; single-repo multi-file integrity check sub-shape)
Pilot: eighteenth pilot of `/promote-rule` (first pilot to apply Pass-A wording-only carve-out at the title level with in-pilot Statement amendment)

## Validator + reusable workflow

- Script: `swift-institute/.github/.github/scripts/validate-binary-install-checksum.py` (~165 lines; new; `chmod +x` applied)
- Reusable workflow: `swift-institute/.github/.github/workflows/validate-binary-install-checksum.yml` (new; self-firing `push:` / `pull_request:` triggers DEFERRED pending batch-fix on 4 baseline findings; `workflow_call:` + `workflow_dispatch:` triggers active)
- Test harness: `swift-institute/.github/.github/scripts/tests/run.sh` registers `ci-082 → CI-082`

## Synthetic fixtures

| Kind | Scenario | Expected | Actual | Status |
|---|---|---:|---:|---|
| pass | swift-checksum-verified | 0 | 0 | PASS |
| pass | swift-keyring-with-checksum | 0 | 0 | PASS |
| fail | swift-missing-checksum | ≥1 | 1 | PASS |
| fail | swift-pipe-to-bash | ≥1 | 1 | PASS |
| edge | swift-data-only-curl | 0 | 0 | PASS |
| edge | swift-apt-only-install | 0 | 0 | PASS |

6/6 fixtures pass. Full harness 114/114 pass (108 prior + 6 new).

## Ground-truth probe

Scope: 4 layer-wrapper-host repos (`swift-institute/.github`, `swift-primitives/.github`, `swift-standards/.github`, `swift-foundations/.github`).

| Target | CI-082 findings |
|---|---:|
| `swift-institute/.github` | **4** |
| `swift-primitives/.github` | 0 |
| `swift-standards/.github` | 0 |
| `swift-foundations/.github` | 0 |

Per-finding detail on `swift-institute/.github`:

| # | File | Job | Step | Pattern | Pattern detail |
|---|---|---|---|---|---|
| 1 | `swift-ci.yml` | `lint` | "Install SwiftLint ${{ env.SWIFTLINT_VERSION }}" | B (curl+install without sha256sum) | `curl -fsSL -o /tmp/swiftlint.zip ...` + `unzip` + `mv .../swiftlint /usr/local/bin/` + `chmod +x` |
| 2 | `link-check.yml` | `scan` | "Install lychee ${{ env.LYCHEE_VERSION }}" | B (curl+install without sha256sum) | `curl -sSL ".../lychee-...tar.gz"` + `mv .../lychee /usr/local/bin/lychee` (note `-sSL`, not `-fsSL`) |
| 3 | `submit-dep-graph-weekly.yml` | `sweep` | "Install dependencies (curl, python3, gh, jq)" | B (curl+install without sha256sum) | `curl -fsSL .../githubcli-archive-keyring.gpg \| tee /etc/apt/keyrings/...` — keyring install (trust root for downstream apt-get install gh) |
| 4 | `cron-audit-base.yml` | `sweep` | "Install dependencies" | B (curl+install without sha256sum) | Same keyring fetch pattern as #3 |

**Baseline: 4 findings on 1 wrapper-host repo (`swift-institute/.github`).** Self-firing DEFERRED pending batch-fix arc (USER YES required).

## Phase-1-projection vs Phase-6-actual gap

Phase 1 inventory's grep regex (`curl.*-fsSL\|wget`) was narrower than the validator's regex (`-fsSL`, `-sSL`, `--fail --silent --location`, `-Lf`, `-fL`). The validator caught `link-check.yml`'s `curl -sSL` install that Phase 1 missed. Phase 1 projected 3 findings; Phase 6 measured 4.

This is a [HANDOFF-016] "metric-freshness" sub-axis: Phase-1 projection regex was preliminary; Phase-6 measurement uses the validator's authoritative regex. The deliverable shape (DEFERRED self-firing pending batch-fix) is unchanged at baseline 3 vs 4 — but the methodology lesson stands: Phase 1 inventory regexes SHOULD mirror validator regex breadth, or Phase 1 should explicitly defer count-commitment to Phase 6.

## Counts vs `[PROMOTE-004]` budget

| Level | Diagnostic count budget | Observed |
|---|---:|---:|
| Hard (default per `[PROMOTE-004]`) | 10 | 4 |

Under budget. Surface-finding pilot (not regression-prevention); the 4 findings are real ecosystem gaps queued for batch-fix.

## Pending batch-fix arc

**CI-082 batch-fix** (USER AUTHORIZATION REQUIRED before proceeding):

4 jobs across 4 workflow files in `swift-institute/.github`:

1. `swift-ci.yml` `lint` job: add `SWIFTLINT_SHA256` env var + `sha256sum -c` step between curl and unzip.
2. `link-check.yml` `scan` job: add `LYCHEE_SHA256` env var + `sha256sum -c` step between curl and mv.
3. `submit-dep-graph-weekly.yml` `sweep` job: add `GH_KEYRING_SHA256` env var + fetch-to-tempfile + `sha256sum -c` step before placing keyring in `/etc/apt/keyrings/`.
4. `cron-audit-base.yml` `sweep` job: same pattern as #3.

Per-fix protocol per [CI-082]'s version-bump procedure:
- Compute upstream digest locally: `curl -fsSL <url> | sha256sum`.
- Paste into the env var.
- Add the `sha256sum -c` gate.
- Verify CI fails with a deliberate digest-mismatch test before merging.

After batch-fix lands, uncomment the deferred `push:` / `pull_request:` self-firing triggers in `validate-binary-install-checksum.yml`.

## Cross-references

- Outcome record: `swift-institute/Audits/PROMOTE-CI-082-2026-05-14.md`
- Predecessor receipts:
  - `promote-CI-080-validation-2026-05-14.md` (pilot 15 — thematic neighbor; DEFERRED-self-fire pattern)
  - `promote-CI-040-validation-2026-05-14.md` (pilot 14 — single-repo multi-file integrity check sub-shape; reused here)
- Skill rule: `swift-institute/Skills/ci-cd-workflows/SKILL.md` `[CI-082]` (compressed; title amended)
- Source authority: `swift-institute/Research/ci-cd-security-review.md` G4
