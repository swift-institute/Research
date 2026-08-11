# Validation receipt: [CI-030] + [CI-059]

Date: 2026-05-14
Rules: CI-030 (intra-Institute reusable refs MUST pin to `@main`), CI-059 (per-repo `ci.yml` `uses:` invocations of intra-Institute reusables MUST include `secrets: inherit`)
Detection target: YAML workflow files at `<repo>/.github/workflows/ci.yml` (per-package consumers; gated on `Package.swift` co-presence)
Detection method: workflow validator (compose-in-script with `[GH-REPO-074]` via `validate-thin-callers.py`)
Pilot: seventeenth pilot of `/promote-rule` (first paired-rule pilot under sixth-calibration atomic-Phase-7 shape)

## Validator + reusable workflow

- Script: `swift-institute/.github/.github/scripts/validate-thin-callers.py` (extended; +iter_jobs / +check_ci_030 / +check_ci_059)
- Reusable workflow: `swift-institute/.github/.github/workflows/validate-thin-callers.yml` (header amended)
- Test harness: `swift-institute/.github/.github/scripts/tests/run.sh` registers `ci-030 → CI-030` and `ci-059 → CI-059`

## Synthetic fixtures

| Pack | Kind | Scenario | Expected | Actual | Status |
|---|---|---|---:|---:|---|
| ci-030 | pass | swift-foo-primitives | 0 | 0 | PASS |
| ci-030 | pass | swift-mixed-third-party | 0 | 0 | PASS |
| ci-030 | fail | swift-tag-pinned | ≥1 | 1 | PASS |
| ci-030 | fail | swift-sha-pinned | ≥1 | 1 | PASS |
| ci-030 | edge | swift-tool-reusable | 0 | 0 | PASS |
| ci-030 | edge | swift-third-party-reusable | 0 | 0 | PASS |
| ci-059 | pass | swift-foo-primitives | 0 | 0 | PASS |
| ci-059 | pass | swift-multi-job | 0 | 0 | PASS |
| ci-059 | fail | swift-missing-secrets | ≥1 | 1 | PASS |
| ci-059 | fail | swift-explicit-forwarding | ≥1 | 1 | PASS |
| ci-059 | edge | swift-tool-reusable | 0 | 0 | PASS |
| ci-059 | edge | swift-third-party-only | 0 | 0 | PASS |

12/12 fixtures pass. Full harness 108/108 pass (96 prior + 12 new).

## Ground-truth probe (ecosystem baseline)

Workspace-wide scan across every per-package consumer repo with `Package.swift` + `.github/workflows/ci.yml`:

| Org-mirror scope | Repos in scope | GH-REPO-074 findings | CI-030 findings | CI-059 findings |
|---|---:|---:|---:|---:|
| `swift-primitives/swift-*` | (subset of 240 union) | 0 | 0 | 0 |
| `swift-standards/swift-*` | (subset of 240 union) | 0 | 0 | 0 |
| `swift-foundations/swift-*` | (subset of 240 union) | 0 | 0 | 0 |
| **Total scanned** | **240** | **0** | **0** | **0** |

The wrapper-host repos (`swift-institute/.github`, `swift-primitives/.github`, `swift-standards/.github`, `swift-foundations/.github`) have no `.github/workflows/ci.yml` and are correctly out of validator scope (the script gates on `Package.swift` + `ci.yml` co-presence per [GH-REPO-074] scope).

Legal-domain top-level dirs (`rule-law`, `swift-law`, `swift-nl-wetgever`, `swift-us-nv-legislature`) lack per-package shape at the top level (they hold sub-repos as siblings) and are correctly out of scope.

**Baseline: 0/240 ecosystem-wide.** Both rules ship with self-firing triggers ACTIVE (the existing `validate-thin-callers.yml` self-fires on push/PR; the extended checks inherit).

## Steady-state explanation

The post-uniformity-sweep state of the ecosystem is the result of:

1. **`@main` pinning** ([CI-030]): All consumer `ci.yml` files were authored or migrated under the `@main`-only pin convention since the centralization rollout (per [CI-001] / `swift-institute/Research/ci-centralization-strategy.md`).
2. **`secrets: inherit` uniformity** ([CI-059]): Phase B7c mass-rollout (130 surgical commits) + post-B7 uniformity sweep (swift-carrier-primitives `928ab6c`) closed the L1 ecosystem at 132/132 identical shape (per `[CI-059]`'s historical provenance, now in `Audits/PROMOTE-CI-030-CI-059-2026-05-14.md` Discipline reference).

Both rules are regression-prevention: any new consumer drifting from the canonical shape, OR any in-place edit reintroducing a tag pin / SHA pin / `secrets:` block / `secrets:` omission, will trigger the validator. Without mechanization, these regressions are silent until the next manual ecosystem sweep.

## Counts vs `[PROMOTE-004]` budget

| Level | Diagnostic count budget | Observed |
|---|---:|---:|
| Hard (default per `[PROMOTE-004]`) | 10 | 0 |

Well under budget. Regression-prevention pilots typically baseline clean; the budget applies to ground-truth-finding pilots (which surface real ecosystem gaps for batch-fix).

## Cross-references

- Outcome record: `swift-institute/Audits/PROMOTE-CI-030-CI-059-2026-05-14.md`
- Predecessor receipts:
  - `promote-GH-REPO-074-validation-2026-05-14.md` (pilot 7 — original validate-thin-callers shipping; baseline 0/317)
  - `promote-CI-040-validation-2026-05-14.md` (pilot 14 — first compose-in-script precedent; baseline 0/4 wrapper-host)
  - `promote-CI-042-validation-2026-05-14.md` (pilot 16 — first compose-in-script extension; same script as pilot 14)
- Skill rules: `swift-institute/Skills/ci-cd-workflows/SKILL.md` `[CI-030]`, `[CI-059]`, `[CI-031]` (amended)
