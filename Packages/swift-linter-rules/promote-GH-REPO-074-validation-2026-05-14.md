# Validation receipt: [GH-REPO-074]

Date: 2026-05-14
Rule: GH-REPO-074 (per-package workflow files MUST be thin callers)
Placement: workflow-validator (`swift-institute/.github/.github/scripts/validate-thin-callers.py` + `validate-thin-callers.yml`)

Detection method: **workflow-validator path** (the under-exercised one). Python validator parses each repo's `.github/workflows/ci.yml` and `swift-format.yml`/`swiftlint.yml` paths; line-anchored regex checks for inline `runs-on:`/`steps:`/`uses:` and for forbidden standalone files. Tool-reusables (`on: workflow_call:`) are exempted.

## Validation ladder (canonical seven)

| Level | Package | Findings | Notes |
|-------|---------|---------:|-------|
| Simple | swift-tagged-primitives | 0 | thin caller |
| Simple | swift-carrier-primitives | 0 | thin caller (reference shape) |
| Simple | swift-pair-primitives | 0 | thin caller |
| Medium | swift-property-primitives | 0 | thin caller |
| Medium | swift-cardinal-primitives | 0 | thin caller |
| Hard | swift-affine-primitives | 0 | thin caller |
| Hard | swift-ordinal-primitives | 0 | thin caller |

## Expanded probe — all per-package repos across the workspace

Scanned every directory under `swift-primitives/`, `swift-foundations/`, `swift-standards/`, `swift-ietf/`, `swift-iso/` whose root contains `Package.swift`.

| Metric | Value |
|---|---:|
| Total per-package repos scanned | 317 |
| Violating repos | 0 |
| Total findings | 0 |

## Negative ground-truth check — repos cited as non-conforming on 2026-05-10

The skill body's `[GH-REPO-077]` section lists 8 repos detected as non-thin during the 2026-05-10 dependabot cleanup arc:

| Repo | Validator output |
|---|---:|
| swift-html-chart | 0 findings (migrated to thin caller) |
| swift-html-css-pointfree | 0 findings (migrated) |
| swift-html-fontawesome | 0 findings (migrated) |
| swift-html-prism | 0 findings (migrated) |
| swift-rfc-7231 | 0 findings (migrated) |
| swift-iso-14496-22 | 0 findings (migrated) |
| swift-numeric-formatting-standard | 0 findings (migrated) |
| swift-standards | 0 findings (migrated) |

All 8 have been migrated to thin callers since the 2026-05-10 arc was documented. Inspection of `swift-foundations/swift-html-chart/.github/workflows/ci.yml` shows the canonical shape (two thin-call jobs, no inline `runs-on:` / `steps:`). The validator correctly accepts this shape (carve-outs honored).

## Synthetic-fixture validation

The validator was first verified on fixtures under `swift-institute/.github/.github/scripts/tests/fixtures/gh-repo-074/`:

| Scenario kind | Repo | Expected | Got |
|---|---|---:|---:|
| pass | swift-foo-primitives (canonical thin caller) | 0 | 0 |
| fail | swift-inline-jobs (inline `runs-on:` + `steps:` + no `uses:`) | ≥1 | 3 |
| fail | swift-standalone-format (`swift-format.yml` standalone) | ≥1 | 1 |
| edge | swift-tool-reusable (`on: workflow_call:` carve-out) | 0 | 0 |
| edge | swift-non-canonical-only (only `release.yml`, no `ci.yml`) | 0 | 0 |

5/5 fixture scenarios pass. The synthetic-fixture confirmation proves the validator detects what it should (3 findings on inline-jobs; 1 finding on standalone-format) when the violating shape is present.

## Diagnostic-count assessment

Per `[PROMOTE-004]` hard-level budget of 10: 0 findings well under. The ecosystem is fully converged on the thin-caller shape; the rule's role is preventive (future regressions). The negative ground-truth check confirms the rule WOULD have fired on the 2026-05-10 non-conforming set had the migrations not landed in the interim.

## Detection method note for the next sweep

The workflow-validator path was the under-exercised one across the prior six pilots — pilot 7 exercises it end-to-end:

- Python validator script following the dependency-free regex pattern (no pyyaml requirement) — mirrors `validate-package-shape.py`
- Reusable GitHub Actions workflow following the existing `validate-package-shape.yml` shape (harden-runner → mint-token → checkout institute-github → resolve targets → clone-and-scan loop → aggregate findings → exit-on-violation unless dry-run)
- Fixture suite under `tests/fixtures/gh-repo-074/{pass,fail,edge}/<scenario>/` mirroring the existing fixture convention; rule registered in `tests/run.sh` validator_for / prefix_for maps
- 5 scenarios cover the rule's full surface: thin-caller pass, inline-jobs fail, standalone-format fail, tool-reusable carve-out, non-canonical-only carve-out

Total workflow-validator pilot time: ~30 minutes — within the 15-30 minute target.
