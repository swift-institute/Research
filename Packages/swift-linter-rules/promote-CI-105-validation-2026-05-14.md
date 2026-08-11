# Validation receipt: [CI-105]

Date: 2026-05-14
Rule: CI-105 (`continue-on-error: true` MUST NOT co-exist with `uses:` at the same job level — GitHub Actions parser rejects the shape with `Unexpected value 'continue-on-error'` causing `startup_failure`)
Detection target: `<repo>/.github/workflows/*.yml,yaml` — per-job structural check
Detection method: workflow validator (PyYAML per-job inspection; single-repo multi-file integrity check sub-shape)
Pilot: nineteenth pilot of `/promote-rule`

## Validator + reusable workflow

- Script: `swift-institute/.github/.github/scripts/validate-continue-on-error.py` (~115 lines; new; `chmod +x` applied)
- Reusable workflow: `swift-institute/.github/.github/workflows/validate-continue-on-error.yml` (new; self-firing `push:` / `pull_request:` triggers ACTIVE)
- Test harness: `swift-institute/.github/.github/scripts/tests/run.sh` registers `ci-105 → CI-105`

## Synthetic fixtures

| Kind | Scenario | Expected | Actual | Status |
|---|---|---:|---:|---|
| pass | swift-continue-on-regular-job | 0 | 0 | PASS |
| pass | swift-continue-on-step | 0 | 0 | PASS |
| fail | swift-continue-on-uses-job | ≥1 | 1 | PASS |
| fail | swift-multi-job-violation | ≥1 | 1 | PASS |
| edge | swift-no-continue-on-error | 0 | 0 | PASS |
| edge | swift-reusable-with-regular-job-coe | 0 | 0 | PASS |

6/6 fixtures pass. Full harness 120/120 pass (114 prior + 6 new).

## Ground-truth probe

Scope: 4 layer-wrapper-host repos.

| Target | CI-105 findings |
|---|---:|
| `swift-institute/.github` | 0 |
| `swift-primitives/.github` | 0 |
| `swift-standards/.github` | 0 |
| `swift-foundations/.github` | 0 |

**Baseline: 0/4 wrapper-host repos.**

Pre-validation inspection enumerated every `continue-on-error` usage across the wrapper-host workflows and confirmed each is in scope of one of the rule's named carve-outs (regular job with `runs-on:`/`steps:`, or step-level on `actions/download-artifact`). None co-exists with `uses:` at the same job level.

Pilot 19 is **regression-prevention**: the validator catches re-introduction of the 2026-05-05 incident class (commit `33f638b` broke every consumer CI's startup; fix `b5d8445` reverted within hours). The current ecosystem state is clean; the rule preserves that state going forward.

Self-firing triggers ACTIVE immediately (no batch-fix arc needed; mirrors pilots 14, 16, 17 discipline).

## Counts vs `[PROMOTE-004]` budget

| Level | Diagnostic count budget | Observed |
|---|---:|---:|
| Hard (default per `[PROMOTE-004]`) | 10 | 0 |

Well under budget. Regression-prevention pilots typically baseline at 0.

## Statement-amendment optionality

The rule's Statement scopes to `continue-on-error: true` (literal). The Rationale notes that `: false` on a `uses:` job would also be rejected by Actions parser (same `Unexpected value` error). The pilot followed the wording-only carve-out: validator implements the literal Statement; broader detection is a Statement-amendment candidate per [SKILL-LIFE-003].

The amendment was NOT applied in-pilot — the scope difference is narrow (any sane consumer writes `: true`, not `: false`), the title accurately reflects the principle (workflow_call structural restriction), and the validator's current detection covers every observed real-world case. Future Statement-amendment optional; for now, the literal Statement stands.

This contrasts with pilot 18 ([CI-082]) where the Statement-amendment WAS applied in-pilot because the title fundamentally under-emphasized the principle. Pilot 19's title-vs-principle alignment is already accurate.

## Cross-references

- Outcome record: `swift-institute/Audits/PROMOTE-CI-105-2026-05-14.md`
- Predecessor receipts:
  - `promote-CI-080-validation-2026-05-14.md` (pilot 15 — first PyYAML-walk per-job validator)
  - `promote-CI-032-validation-2026-05-14.md` (pilot 13 — single-repo multi-file integrity check sub-shape)
- Skill rule: `swift-institute/Skills/ci-cd-workflows/SKILL.md` `[CI-105]` (compressed)
- Source authority: `swift-institute/Research/centralized-swift-ci-and-spine-gate.md` §3.5.1
- Memory predecessor: `feedback_continue_on_error_invalid_on_uses.md`
