# Validation receipt: [API-IMPL-020]

Date: 2026-05-15
Rule: leaf body typealias missing
Placement tier: institute
Pack: Linter Rule Conformance (NEW)
Detection method: regex pre-scan on the validation ladder (zero counts predicted and confirmed); test-target validation harness on the ground-truth probe (post-W4c-fix conformer packages).

## Validation ladder (zero counts predicted)

| Level | Package | Source files | Diagnostic count | Notes |
|-------|---------|--------------|------------------|-------|
| Simple | swift-tagged-primitives | 10 | 0 | clean — no Parser/Serializer/Coder conformers |
| Simple | swift-carrier-primitives | 44 | 0 | clean — no Parser/Serializer/Coder conformers |
| Simple | swift-pair-primitives | 5 | 0 | clean — no Parser/Serializer/Coder conformers |
| Medium | swift-property-primitives | 23 | 0 | clean — no Parser/Serializer/Coder conformers |
| Medium | swift-cardinal-primitives | 27 | 0 | clean — no Parser/Serializer/Coder conformers |
| Hard | swift-affine-primitives | 23 | 0 | clean — no Parser/Serializer/Coder conformers |
| Hard | swift-ordinal-primitives | 45 | 0 | clean — no Parser/Serializer/Coder conformers |

Regex pre-scan: `grep -rE ': Parser\.\`Protocol\`|: Serializer\.\`Protocol\`|: Coder\.\`Protocol\`'` returned 0 matches across all 7 ladder packages. Per Phase 6 of `lint-rule-promotion`, the AST rule returns ≤ 0 (also 0); validation passes without an AST walk. Cross-checked with the temporary test-target validation harness — 0 findings across all 7 ladder packages, confirming the regex prediction.

## Ground-truth probe (conformer packages — separate budget)

| Package | Source files | Diagnostic count | Class |
|---------|--------------|------------------|-------|
| swift-parser-primitives | 118 | 41 | live work — combinator leaf conformers |
| swift-serializer-primitives | 37 | 0 | clean — every conformer carries the typealias post-W4c-fix |
| swift-coder-primitives | 3 | 0 | clean — protocol declaration only, no leaf conformers |
| swift-binary-parser-primitives | 40 | 4 | live work — Binary.Parse.{Inline, Converting, Validated, Variable} |
| swift-binary-coder-primitives | 11 | 1 | live work — Binary.Coder+Coder.Protocol |
| swift-ascii-parser-primitives | 12 | 2 | live work — ASCII.{Decimal, Hexadecimal}.Parser |
| swift-ascii-serializer-primitives | 14 | 2 | live work — ASCII.{Decimal, Hexadecimal}.Serializer |

**Total ground-truth findings**: 50 across 7 conformer packages.

**Branch decision**: batch-fix (branch 1 of Phase 6's iteration loop).

Sampled findings inspected:
- `swift-parser-primitives/Sources/Parser Always Primitives/Parser.Always.swift:22` — `extension Parser.Always: Parser.\`Protocol\`` is a generic leaf conformer (`public struct Always<Input, Output>`), has `parse()` directly, missing `typealias Body = Never`. Real true-positive.
- `swift-binary-parser-primitives/Sources/Binary Integer Primitives/Binary.Parse.Inline.swift:35` — `extension Binary.Parse.Inline: Parser.\`Protocol\`` is a generic leaf conformer (`public struct Inline<let Count: Int, Element: FixedWidthInteger>`), has `parse()` directly, missing typealias. Real true-positive.
- `swift-ascii-parser-primitives/Sources/ASCII Decimal Parser Primitives/ASCII.Decimal.Parser.swift:27` — `extension ASCII.Decimal.Parser: Parser.\`Protocol\`` is a generic leaf conformer (`public struct Parser<Input: Collection.Slice.\`Protocol\`, T: FixedWidthInteger>`), has `parse()` directly, missing typealias. Real true-positive.

All 50 findings are generic leaf conformers exactly fitting the rule's literal Statement. The fix is mechanical: append `public typealias Body = Never` next to the existing associatedtype typealiases.

The 41 swift-parser-primitives findings are all combinator types (`Parser.Always`, `Parser.Byte`, `Parser.Conditional`, `Parser.Map.{Throwing, Transform}`, `Parser.Many.{Separated, Simple}`, `Parser.OneOf.{Sequence, Three, Two}`, `Parser.Optional`, `Parser.Optionally`, `Parser.Peek`, `Parser.Prefix.Through`, etc.) — the same body-typealias gap pattern that affected `Binary.LEB128.{Signed, Unsigned}` in the W4c-fix incident. Combinators are generic by construction.

**Follow-up batch-fix**: Phase 8's outcome record names per-package follow-ups; the work is mechanical, ~50 one-line additions across 6 packages. Not blocking on the rule landing — the rule is correctly catching live work the institute conventions require.

**Note on swift-parser-primitives' empirical status**: the W4c-fix incident only tracked `Binary.LEB128.{Signed, Unsigned}` because those were the link-failure trigger. The 41 swift-parser-primitives conformers are presumed to currently link because the package builds and tests run (the witness-emission failure mode is generic-conformer-specific and may not trigger for every shape). The rule's "minimum-safe pattern" guidance applies regardless: declare the typealias to make the conformance shape (leaf vs non-leaf) self-documenting and to immunize against future witness-emission regressions.

## Methodology notes

- Validation ladder regex pre-scan was the correct first-pass detection method (counts predicted-and-confirmed at 0).
- Test-target validation harness lives at `Tests/Linter Rule Conformance Tests/LeafBodyTypealias.Validation.swift`; deletes after this receipt is authored.
- Detection logic: extension inheritance clause matches `(host, name)` pairs in `[("Parser", "Protocol"), ("Serializer", "Protocol"), ("Coder", "Protocol")]`; trailing-two-segment match tolerates module qualification (`Parser_Primitives_Core.Parser.\`Protocol\``); skips when member block contains a `body` binding (non-leaf conformer) OR a `typealias Body = Never` / `Body = Swift.Never` declaration.
