# Validation receipt: [CI-099]

Date: 2026-05-14
Rule: CI-099 (`windows-release` job in canonical `swift-ci.yml` MUST stay gating; `continue-on-error: true` is forbidden — Windows is a first-class target platform whose visibility outweighs upstream-driven noise)
Detection target: single canonical file `swift-institute/.github/.github/workflows/swift-ci.yml`, single job `windows-release`
Detection method: workflow validator (compose-in-script with `[CI-010]` via `validate-ci-matrix.py`; centralized-config integrity check sub-shape)
Pilot: twentieth pilot of `/promote-rule` (smallest compose-in-script extension to date — 13 lines of detection code)

## Validator + reusable workflow

- Script: `swift-institute/.github/.github/scripts/validate-ci-matrix.py` (extended; +13 lines for `check_ci_099` parallel to existing `check_ci_010` nightly check)
- Reusable workflow: `swift-institute/.github/.github/workflows/validate-ci-matrix.yml` (header amended)
- Test harness: `swift-institute/.github/.github/scripts/tests/run.sh` registers `ci-099 → CI-099` (alongside `ci-010 → CI-010`)

## Synthetic fixtures

| Kind | Scenario | Expected | Actual | Status |
|---|---|---:|---:|---|
| pass | canonical-windows-gating | 0 | 0 | PASS |
| pass | windows-explicit-false | 0 | 0 | PASS |
| fail | windows-advisory | ≥1 | 1 | PASS |
| fail | windows-and-nightly-both-advisory | ≥1 | 1 | PASS |
| edge | no-swift-ci | 0 | 0 | PASS |
| edge | no-windows-job | 0 | 0 | PASS |

6/6 fixtures pass. Full harness 126/126 pass (120 prior + 6 new).

## Ground-truth probe

Scope: single canonical target (`swift-institute/.github/.github/workflows/swift-ci.yml`).

| Target | CI-010 findings | CI-099 findings |
|---|---:|---:|
| `swift-institute/.github` | 0 | 0 |

**Baseline: 0/0.** Live state of `swift-ci.yml:207` has no `continue-on-error` line on `windows-release` (default false → gating). The 2026-05-05 user-direction has held; the gate has never been flipped to advisory.

CI-010 regression check (extension safety): pilot 10's existing checks still pass after the script extension. No regression.

Self-firing triggers ACTIVE immediately (inherited from pilot 10's `validate-ci-matrix.yml` workflow; no batch-fix arc needed).

## Inverse-posture pairing with CI-010

| Job | Existing CI-010 check | New CI-099 check |
|---|---|---|
| `linux-nightly` | `continue-on-error is not True` → fire | (out of scope) |
| `windows-release` | (out of scope) | `continue-on-error is True` → fire |

The two checks sit literally next to each other in the script and encode the semantic distinction:
- `linux-nightly` — toolchain-instability noise; MUST be `continue-on-error: true` (advisory by design)
- `windows-release` — first-class target shipped to; MUST be `continue-on-error: false` (gating)

## Counts vs `[PROMOTE-004]` budget

| Level | Diagnostic count budget | Observed |
|---|---:|---:|
| Hard (default per `[PROMOTE-004]`) | 10 | 0 |

Well under budget. Regression-prevention pilot.

## Cross-references

- Outcome record: `swift-institute/Audits/PROMOTE-CI-099-2026-05-14.md`
- Predecessor receipts:
  - `promote-CI-010-validation-2026-05-14.md` (pilot 10 — anchor validator)
  - `promote-CI-105-validation-2026-05-14.md` (pilot 19 — adjacent `continue-on-error` rule on workflow_call'd jobs)
- Skill rules: `swift-institute/Skills/ci-cd-workflows/SKILL.md` `[CI-099]` (compressed), `[CI-010]` (Enforcement line amended)
- Memory predecessor: `feedback_windows_first_class_ci_gating.md`
