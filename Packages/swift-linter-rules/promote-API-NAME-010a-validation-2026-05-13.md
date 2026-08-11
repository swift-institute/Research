# Validation receipt: [API-NAME-010a]

Date: 2026-05-13
Rule: nested tag
Placement tier: institute
Rule file: `swift-foundations/swift-institute-linter-rules/Sources/Linter Rule Naming/Lint.Rule.Naming.NestedTag.swift`

## Pipeline summary

Pilot invocation of the `lint-rule-promotion` skill on `[API-NAME-010a]`. Phase 1 triage → MECHANIZE (PASS / PASS / PASS on scope / principle / counterexample). Phases 3-5 produced visitor + 15-test suite passing in 0.005s.

## Detection method

Pre-scan: regex grep `\b(enum|struct)[[:space:]]+Tag\b` across each validation package's `Sources/` tree. Zero candidates surfaced; therefore no AST follow-up needed. The detection-method choice and methodology lesson are recorded in the outcome record.

## Validation results

| Level | Package | Diagnostic count | Notes |
|-------|---------|------------------|-------|
| Simple | swift-tagged-primitives | 0 | clean |
| Simple | swift-carrier-primitives | 0 | clean |
| Simple | swift-pair-primitives | 0 | clean |
| Medium | swift-property-primitives | 0 | clean |
| Medium | swift-cardinal-primitives | 0 | clean |
| Hard | swift-affine-primitives | 0 | clean |
| Hard | swift-ordinal-primitives | 0 | clean |

Origin-package cross-check (out-of-ladder): `swift-order-primitives` (where commit `733da36` introduced and then removed the rule's defect) also clean. The historical incident has been resolved before the rule landed in the skill corpus.

## Interpretation

Zero counts across all 7 validation packages match the prediction recorded in the prior `lint-rule-promotion` design discussion: the rule's only documented incident was already fixed before the rule was authored, and the rule-compliant subset of the ecosystem (pure-public packages) does not contain the violation pattern.

This is the expected shape for a rule whose function is *future-prevention*. The rule will fire on any next instance of the pattern at PR time; the validation ladder confirms it does not fire on existing rule-compliant code.

## Decision

Proceed to Phase 7 integration. Diagnostic-count budget per `[PROMOTE-004]` (10) is well under; no iteration loop needed.

## Cross-references

- Rule source: `swift-foundations/swift-institute-linter-rules/Sources/Linter Rule Naming/Lint.Rule.Naming.NestedTag.swift`
- Test suite: `swift-foundations/swift-institute-linter-rules/Tests/Linter Rule Naming Tests/Lint.Rule.Naming.NestedTag Tests.swift` (15 tests, 8 Unit / 7 Edge Case)
- Skill rule: `swift-institute/Skills/code-surface/SKILL.md:1082-1119`
- Outcome record: `swift-institute/Audits/PROMOTE-API-NAME-010a-2026-05-13.md`
- Origin incident: commit `733da36` on `swift-primitives/swift-order-primitives` (2026-05-13)
