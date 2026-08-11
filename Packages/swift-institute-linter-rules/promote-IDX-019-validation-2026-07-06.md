# Validation receipt: [IDX-019]

Date: 2026-07-06
Rule: sli literal
Placement tier: institute (pack: Institute Linter Rule Idiom)

Detection method: regex pre-scan (`Ordinal\(UInt\([0-9]`, strictly broader than the AST
rule) sized the field — 92 files ecosystem-wide carry the broader pattern, but sampling
showed all ladder hits are bare `Ordinal(UInt(N))` (out of scope) or doc-comment trivia —
followed by a full AST walk via the temporary test-target validation harness
(`SliLiteral.Validation.swift`, deleted after the run) over Sources/ AND Tests/ of each
ladder package.

| Level | Package | Diagnostic count | Notes |
|-------|---------|------------------|-------|
| Simple | swift-tagged-primitives | 0 | clean |
| Simple | swift-carrier-primitives | 0 | clean |
| Simple | swift-pair-primitives | 0 | clean |
| Medium | swift-property-primitives | 0 | clean |
| Medium | swift-cardinal-primitives | 0 | clean |
| Hard | swift-affine-primitives | 0 | 22 broader-regex hits are all bare `Ordinal(UInt(N))` — out of scope by design |
| Hard | swift-ordinal-primitives | 0 | clean |

Test suite: 10 tests / 5 suites green on 6.3.2 (`--filter "sli literal"`): 4 Unit (fires:
subscript, Tagged form, plain let, bare `Index(Ordinal(UInt(7)))`) + 6 Edge Case (no fire:
identifier arg, `_unchecked:` label, bare `Ordinal(UInt(5))`, no wrapper chain, `UInt(0)`
alone, member-access arg).

Outcome record: `swift-institute/Audits/PROMOTE-IDX-019-2026-07-06.md`.
