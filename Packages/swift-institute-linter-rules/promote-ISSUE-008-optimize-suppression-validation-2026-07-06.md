# Validation receipt: [ISSUE-008] optimize-suppression slice

Date: 2026-07-06
Rule: optimize suppression attribute
Placement tier: institute (pack: Institute Linter Rule Platform)

Detection method: full AST walk via the temporary test-target validation harness
(`OptimizeSuppression.Validation.swift`, deleted after the run) over Sources/ + Tests/ of
the 7 ladder packages PLUS swift-async-primitives (the known live-workaround package).

| Level | Package | Diagnostic count | Notes |
|-------|---------|------------------|-------|
| Simple | swift-tagged-primitives | 0 | clean |
| Simple | swift-carrier-primitives | 0 | clean |
| Simple | swift-pair-primitives | 0 | clean |
| Medium | swift-property-primitives | 0 | clean |
| Medium | swift-cardinal-primitives | 0 | clean |
| Hard | swift-affine-primitives | 0 | clean |
| Hard | swift-ordinal-primitives | 0 | clean |
| Ground truth | swift-async-primitives | 11 | all true positives — deliberate §A18/§A19 crash workarounds |

The pre-scan estimate of ~37 was inflated by comment/doc mentions of the attribute; the
AST-true count is 11 (10 files; Bounded.Storage carries 2). All 11 were converted to the
sanctioned exemption form in the same wave (`swift-linter:disable:next optimize
suppression attribute` + `REASON:` citing catalog §A19, [AUDIT-038] disposition-1) —
swift-async-primitives commit `8699564` (LOCAL; public push batched). Suppression handling
is central (`swift-linter` `Lint.Suppression` scanner; `:next` skips comment-only lines),
so the rule itself carries no exemption logic.

Test suite: 9 tests / 5 suites green on 6.3.2; full-package run after bundle entry +
citation hygiene: 916 tests / 248 suites green.

Outcome record: `swift-institute/Audits/PROMOTE-ISSUE-008-optimize-suppression-2026-07-06.md`.
