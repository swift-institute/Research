# Validation receipt: [CI-040]

Date: 2026-05-14
Rule: cache-policy (no .build cache outside L1 carve-out)
Placement: workflow-validator (single-repo multi-file integrity check sub-shape)
Detection method: workflow validator — Python script + reusable workflow

## Synthetic fixtures

| Scenario | Expected | Got |
|---|---:|---:|
| pass/no-cache | 0 | 0 |
| pass/binary-cache | 0 | 0 |
| fail/build-cache-simple | 1 | 1 |
| fail/build-cache-with-keys | 1 | 1 |
| edge/l1-embedded-carveout | 0 | 0 |
| edge/no-cache-step | 0 | 0 |

6/6 PASS.

## Ground truth — production state

| Target | Findings | Notes |
|---|---:|---|
| `swift-institute/.github` | 0 | SwiftLint binary cache + lychee binary cache (both [CI-044] permitted) |
| `swift-primitives/.github` | 0 | L1 embedded carve-out detected correctly |
| `swift-foundations/.github` | 0 | No cache uses |
| `swift-standards/.github` | 0 | No cache uses |

Baseline 0/0. Validator confirms steady state post-2026-05-04 cleanups (resolved `44b5acb` + `2d1f6b8`). Per `[PROMOTE-004]` budget of 10: well under.

## Outcome record

`swift-institute/Audits/PROMOTE-CI-040-2026-05-14.md`
