# Validation receipt: [DS-026] (part (a)-DIRECT)
Date: 2026-07-06
Rule: carrier column bound (`Lint.Rule.Tower.CarrierColumnBound`)
Placement tier: primitives (`Primitives Linter Rule Tower` pack; `Bundle.primitives`)
Scope: [DS-026] predicate part (a), DIRECT type-level bound only — the per-file / per-AST-decidable slice. Inherited-(a) + parts (b)/(c)/(d)/(e) remain script-enforced (`Scripts/adt-decoupling-classify.py`).

Detection method: full-AST walk via test-target validation harness (Phase-6 default —
SwiftParser + `visitor.walk()`, same data flow as the lint CLI). The prebuilt
`swift-linter` binary cannot exercise a brand-new rule (its rule set is compiled
in); the branch-built test target is the faithful scoped runner and does not
perturb the prebuilt binary or land a `Lint.swift` in any consumer package.

## Scoped-runner counts (exact)

| Level | Target | files | findings | Notes |
|-------|--------|------:|---------:|-------|
| Ground truth | pre-reshape `Array.swift` (git `98ed3fb`) | 1 | **1** | real FAIL: `public struct Array<S: Store.`Protocol` & Buffer.`Protocol` & ~Copyable>` — the rule FIRES |
| Simple | swift-array-primitives (at-target) | 16 | 0 | clean (reshaped `__Array<S: ~Copyable>`) |
| Legacy | swift-bitset-primitives (legacy / no column axis) | 18 | 0 | informative negative — no `S` axis, correctly does NOT fire |
| Legacy | swift-hash-table-primitives (legacy / keyed on Element) | 22 | 0 | informative negative — no `S` axis, correctly does NOT fire |
| Whole tree | ALL `swift-*-primitives/Sources` | 3235 | **0** | ecosystem-wide clean; 0 false positives |

Unit suite (`Lint.Rule.Tower.CarrierColumnBound Tests.swift`): 11/11 pass —
4 Unit (fire), 3 Edge Case (silent), 4 Negative (silent). Full Tower test
target: 29/29 pass. Aggregate `Linter Primitives Rules` bundle: builds clean.

## Reading

This is the [API-NAME-010a]-shape outcome: a **future-prevention** rule that
fires 0× on the compliant live tree (the W1/W2 reshape moved every carrier's
capability bound off the type onto its extensions; the 2 legacy families lack an
`S` column axis entirely, so this sub-check is correctly silent on them). 0 live
findings is not a weak rule — the FAIL shape is git-history-real (fired 1×) and
syntactically unambiguous. The rule LOCKS IN the W1/W2 reshape invariant against
regression. Diagnostic-count budget ([PROMOTE-004]) not triggered (0 ≪ 10).

Toolchain: Swift 6.3.2-class (ambient default). Build: 6.3.2 target.
