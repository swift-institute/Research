# Validation receipt: [CI-010]

Date: 2026-05-14
Rule: CI-010 (universal CI matrix shape)
Placement: workflow-validator (centralized-config integrity check — new sub-shape)

Detection method: **workflow validator targeting a single canonical file**
(`swift-institute/.github/.github/workflows/swift-ci.yml`). Distinct from
the per-repo iteration shape of `validate-thin-callers.yml` /
`validate-package-shape.yml`: this validator targets ONE specific file in
ONE specific repo (the `.github` org-profile repo hosting the universal
reusable). Other repos are no-op'd (return 0 findings if no swift-ci.yml
is present).

## Synthetic-fixture validation

5 scenarios under `tests/fixtures/ci-010/`:

| Kind | Scenario | Expected | Got |
|---|---|---:|---:|
| pass | dot-github-canonical (4 matrix jobs + format gate) | 0 | 0 |
| fail | missing-windows (no windows-release job) | ≥1 | 1 |
| fail | nightly-not-tolerant (no continue-on-error) | ≥1 | 1 |
| fail | wrong-runner (macos-release runs on ubuntu) | ≥1 | 1 |
| edge | no-swift-ci (repo has no swift-ci.yml at all) | 0 | 0 |

5/5 pass. The validator detects (a) missing required jobs, (b) wrong runner
classes, (c) missing `continue-on-error: true` on the nightly job; it
correctly no-ops on repos that don't host the canonical reusable.

## Ground-truth validation

Run against the actual `swift-institute/.github` repo:

| Target | Findings |
|---|---:|
| `swift-institute/.github` (current swift-ci.yml) | 0 |

The matrix is clean: all four required jobs present, runners match, nightly
job has `continue-on-error: true`. The validator codifies the current
canonical shape and catches future regressions (matrix-shape changes that
might silently break ecosystem CI).

## Diagnostic-count assessment

Per `[PROMOTE-004]` budget of 10: 0 findings well under (single-target
validator). The synthetic fixtures (3 failure scenarios → 3 findings)
prove the validator's detection power independently of the now-clean
actual state.

## Validator infrastructure

- `swift-institute/.github/.github/scripts/validate-ci-matrix.py` — 105 lines, dependency-free except `pyyaml` (same as `validate-readme.py`).
- `swift-institute/.github/.github/workflows/validate-ci-matrix.yml` — reusable workflow following the canonical shape (harden-runner → mint-token → checkout-validator → resolve-target → clone-and-scan → aggregate). Default target is the invoking repo; `repo:` input overrides.
- `tests/fixtures/ci-010/` — 5 scenarios.
- Registered in `tests/run.sh` `validator_for` + `prefix_for` maps.

Total pilot time: ~25 minutes — within the 15-30 minute target for templated workflow-validator pilots.
