# Validation receipt: [CI-080]

Date: 2026-05-14
Rule: harden-runner audit-mode floor (SHA-pinned, every in-scope job)
Placement: workflow-validator (single-repo multi-file integrity check sub-shape)
Detection method: workflow validator — Python script + reusable workflow

## Synthetic fixtures

| Scenario | Expected | Got |
|---|---:|---:|
| pass/sha-pinned | 0 | 0 |
| pass/uses-only-routing | 0 | 0 |
| pass/ci-ok-aggregator | 0 | 0 |
| fail/missing-harden-runner | 1 | 1 |
| fail/major-tag-pinned | 1 | 1 |
| edge/empty-steps | 0 | 0 |

6/6 PASS.

## Ground truth — production state

| Target | Findings | Notes |
|---|---:|---|
| `swift-institute/.github` | 3 | `config` jobs in 3 weekly orchestrators missing harden-runner as first step |
| `swift-primitives/.github` | 0 | Post Cohort-A1 rollout (2026-05-06 commits `3cd2e77` + `0da5d4f`) covers L1 |
| `swift-foundations/.github` | (deferred — wrapper present, probe queued) | — |
| `swift-standards/.github` | (deferred — wrapper present, probe queued) | — |

Per `[PROMOTE-004]` budget of 10 hard-level: 3 under budget. Branch 1 iteration-loop (real violations, batch-fix as separate authorized arc).

## Outcome record

`swift-institute/Audits/PROMOTE-CI-080-2026-05-14.md`
