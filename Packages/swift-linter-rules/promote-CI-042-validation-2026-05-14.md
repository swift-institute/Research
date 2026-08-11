# Validation receipt: [CI-042]

Date: 2026-05-14
Rule: no restore-keys partial-prefix matching (exact-match-only cache hits)
Placement: workflow-validator (single-repo multi-file integrity check; extends pilot 14's validate-cache-policy.py)
Detection method: workflow validator — Python script (extended) + reusable workflow (regex broadened)

## Synthetic fixtures

| Scenario | Expected | Got |
|---|---:|---:|
| pass/exact-match-only | 0 | 0 |
| pass/no-cache-step | 0 | 0 |
| fail/restore-keys-tool-binary | 1 | 1 |
| fail/restore-keys-build | 1 | 1 |
| fail/multiline-restore-keys | 1 | 1 |
| fail/multi-cache-mixed | 1 | 1 |
| edge/restore-keys-on-non-cache-action | 0 | 0 |
| edge/sha-pinned-actions-cache | 0 | 0 |

8/8 PASS.

## Ground truth — production state

| Target | CI-042 Findings |
|---|---:|
| `swift-institute/.github` | 0 |
| `swift-primitives/.github` | 0 |
| `swift-foundations/.github` | 0 |
| `swift-standards/.github` | 0 |

Baseline 0/0. Both historical violations cited in `[CI-040]`'s Known Non-Conformances subsection (resolved `44b5acb` + `2d1f6b8`, 2026-05-04) ARE the only [CI-042]-shaped violations the rule has ever surfaced. Validator confirms steady state.

Per `[PROMOTE-004]` budget of 10: well under.

## Outcome record

`swift-institute/Audits/PROMOTE-CI-042-2026-05-14.md`
