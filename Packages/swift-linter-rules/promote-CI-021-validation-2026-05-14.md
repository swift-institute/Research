# Validation receipt: [CI-021]

Date: 2026-05-14
Rule: CI-021 (embedded job in layer-wrapper swift-ci.yml MUST carry `continue-on-error: true` during 6.4-dev window)
Target: `<repo>/.github/workflows/swift-ci.yml`, single named job `embedded`
Method: workflow validator (centralized-config integrity check; single-job)
Pilot: twenty-third — first Architectural→Mechanical promotion this session

## Synthetic fixtures: 6/6 PASS

## Ground-truth: 0 findings on swift-primitives/.github (live `continue-on-error: true` at swift-ci.yml:77)

## Cross-references

- Outcome: `Audits/PROMOTE-CI-021-2026-05-14.md`
