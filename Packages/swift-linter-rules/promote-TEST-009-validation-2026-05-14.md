# Validation receipt: [TEST-009]

Date: 2026-05-14
Rule: TEST-009 (test file naming convention)
Placement: workflow-validator, per-package iteration sub-shape

Detection method: filename pattern check (` Tests.swift$` suffix expected; compound `XYZTests.swift` form flagged). Carve-outs match the existing `validate-file-naming.py` patterns ([API-IMPL-006]/[API-IMPL-007]): Tests/Support/, /Fixtures/, `+`-extension form, where-clause shape, build-system files.

## Synthetic-fixture validation

| Kind | Scenario | Expected | Got |
|---|---|---:|---:|
| pass | swift-foo-primitives (canonical) | 0 | 0 |
| fail | swift-compound-names | ≥1 | 1 |
| fail | swift-dot-before-tests | ≥1 | 1 |
| edge | swift-extension-file | 0 | 0 |
| edge | swift-fixture-type | 0 | 0 |

5/5 pass.

## Canonical seven (validation ladder)

| Level | Package | Findings |
|-------|---------|---------:|
| Simple | swift-tagged-primitives | 0 |
| Simple | swift-carrier-primitives | 0 |
| Simple | swift-pair-primitives | 0 |
| Medium | swift-property-primitives | 0 |
| Medium | swift-cardinal-primitives | 2 |
| Hard | swift-affine-primitives | 5 |
| Hard | swift-ordinal-primitives | 5 |

12 findings. Per [PROMOTE-004] inspection: all real violations (legacy XCTest-style compound names like `TaggedCardinalTests.swift`, `OrdinalPositionTests.swift`).

## Expanded ecosystem probe

Across every per-package repo with `Package.swift` + `Tests/`:

| Metric | Value |
|---|---:|
| Total candidate violations | **391** |
| Violating repos | 128 |

Top violators: `swift-postgresql-standard` (72), `swift-rfc-791` (14), `swift-rfc-9112` (12), `swift-standards` (12), `swift-rfc-4648`/`swift-rfc-9110` (11), `swift-pdf-html-render`/`swift-base62-primitives` (10).

Per iteration-loop branch 1 (real violations spread across the ecosystem): validator ships, surface findings, batch-fix as separate user-authorized arc.
