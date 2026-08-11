# Validation receipt: [TEST-005]

Date: 2026-05-14
Rule: TEST-005 (test category suites)
Placement: AST rule, institute-tier `Linter Rule Framework` pack
Detection: literal reading — every top-level `@Suite struct X` MUST contain nested `@Suite struct` declarations for all four canonical sub-suites (Unit, `Edge Case`, Integration, Performance)

## Synthetic test-suite validation (10 cases)

**Unit suite** (5 cases):

| Test | Expected | Got |
|---|---:|---:|
| canonical four-category structure passes | 0 | 0 |
| legacy flat shape with no categories is flagged | 1 | 1 |
| partial conformance missing Performance is flagged | 1 | 1 |
| partial conformance missing two categories is flagged | 1 | 1 |
| top-level `@Suite enum` (struct-only scope) | 0 | 0 |

**`Edge Case` suite** (5 cases):

| Test | Expected | Got |
|---|---:|---:|
| extension-form file (no top-level @Suite struct) | 0 | 0 |
| nested @Suite struct (not top-level) | 0 | 0 |
| struct without @Suite attribute | 0 | 0 |
| `@Suite(.serialized)` trait variant for Performance | 0 | 0 |
| empty source | 0 | 0 |

10/10 pass in 0.004 seconds.

## Ladder approximation (via earlier Python prototype)

| Package | Missing categories | Findings |
|---|---|---:|
| swift-tagged-primitives | — | 0 |
| swift-carrier-primitives | — | 0 |
| swift-pair-primitives | Integration, Performance | 2 |
| swift-property-primitives | Performance | 1 |
| swift-cardinal-primitives | all four (legacy flat) | 4 |
| swift-affine-primitives | all four (legacy flat) | 4 |
| swift-ordinal-primitives | all four (legacy flat) | 4 |

15 findings — real violations. Per iteration-loop branch 1: ship and batch-fix.

## Ecosystem-wide probe

Aggregate finding count under the literal per-package reading: **~876 missing-category findings across 268 of 302 repos with `Tests/`** (~89% of test-having repos have at least one missing category).

Note: the AST rule fires per-file (per top-level @Suite struct), not per-package. The 876 number was computed by the Python prototype's per-package aggregate. The AST rule's per-file count will be higher (each file with a top-level @Suite missing categories generates one finding).

## Architecture note

This rule is AST-native — it inspects `@Suite struct X {}` declarations in Swift code via SwiftSyntax. Building it as a Python workflow-validator was a categorical misframing corrected during the pilot per principal direction. The script layer is reserved for non-Swift detection targets (YAML, filenames, filesystem structure); Swift code analysis lives in the AST linter.
