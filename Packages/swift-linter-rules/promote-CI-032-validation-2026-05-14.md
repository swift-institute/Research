# Validation receipt: [CI-032]

Date: 2026-05-14
Rule: visibility-gate
Placement: workflow-validator (single-repo multi-file integrity check sub-shape)
Detection method: workflow validator — Python script + reusable workflow

## Synthetic fixtures

| Scenario | Expected | Got |
|---|---:|---:|
| pass/simple-gated | 0 | 0 |
| pass/compound-gated | 0 | 0 |
| fail/missing-single | 1 | 1 |
| fail/missing-multi | 3 | 3 |
| edge/scheduled-only | 0 | 0 |
| edge/disabled-job | 0 | 0 |

6/6 PASS.

## Ground truth — production state

| Target | Findings | Notes |
|---|---:|---|
| `swift-institute/.github` | 11 | Orchestrator-only-callable reusables (cron-audit-base, generate-metadata, link-check, lint-org-bot-coverage, lint-readme-presence, lint-readme-structure, lint-skill-descriptions, sync-discussion-threads, sync-metadata) |
| `swift-primitives/.github` | 0 | All in-scope reusables gated |
| `swift-foundations/.github` | (deferred — wrapper repo present, probe queued) | — |
| `swift-standards/.github` | (deferred — wrapper repo present, probe queued) | — |

Per `[PROMOTE-004]` budget of 10 on hard level: 11 findings above threshold. Branch 1 iteration-loop (real violations spread → batch-fix). Branch-selection rationale and per-rule shape detail in outcome record.

## Outcome record

`swift-institute/Audits/PROMOTE-CI-032-2026-05-14.md`
