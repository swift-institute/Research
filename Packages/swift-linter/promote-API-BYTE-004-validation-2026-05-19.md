# Validation receipt: [API-BYTE-004]
Date: 2026-05-19
Rule: binary serializable rawvalue uint8
Placement tier: institute
Pack: Institute Linter Rule Byte
Source: `swift-foundations/swift-institute-linter-rules/Sources/Institute Linter Rule Byte/Lint.Rule.Byte.BinarySerializableRawValueUInt8.swift`

## Validation ladder (regex pre-scan)

Pattern: `grep -rE 'rawValue: UInt8' Sources/`

| Level | Package | Diagnostic count | Notes |
|-------|---------|------------------|-------|
| Simple | swift-tagged-primitives | 0 | clean |
| Simple | swift-carrier-primitives | 0 | clean |
| Simple | swift-pair-primitives | 0 | clean |
| Medium | swift-property-primitives | 0 | clean |
| Medium | swift-cardinal-primitives | 0 | clean |
| Hard | swift-affine-primitives | 0 | clean |
| Hard | swift-ordinal-primitives | 0 | clean |

## Ground-truth probe (per-site dispositions per W2 rubric)

| Package | R4 count |
|---------|---------:|
| swift-rfc-791 | **7** |
| swift-rfc-9293 | **6** |
| swift-rfc-7519 | 0 |
| swift-rfc-4648 | 0 |
| swift-iso-32000 | 0 |
| swift-incits-4-1986 | 0 |
| swift-ascii-primitives | 0 |
| swift-binary-primitives | 0 |
| swift-foundations/swift-ascii | 0 |

**Total**: 13 review-prompts across 2 packages. Each requires per-site domain classification under the W2 rubric (`broader-l2-l3-byte-typing-gap-plan.md` § "Discrimination refinement"):

**RFC 791 per-type dispositions** (from plan doc):

| Type | rawValue | Disposition |
|---|---|---|
| Flags | UInt8 (bit field) | retype to Byte ✓ (landed `cde98cb`) |
| TTL | UInt8 (decrement) | STAYS UInt8 ✓ (landed `cde98cb`) |
| IHL | UInt8 (× 4) | STAYS UInt8 |
| Precedence | UInt8 (3-bit) | retype to Byte |
| Protocol | UInt8 (catalog) | retype to Byte |
| TypeOfService | UInt8 (bit field) | retype to Byte |
| Version | UInt8 (literal) | retype to Byte |

5 outstanding in rfc-791 (Flags + TTL already landed); 6 outstanding in rfc-9293 await per-type analysis.

## Test suite

`swift test --filter Byte`: 51 tests pass. Per-rule sub-suite "binary serializable rawvalue uint8 Tests": 3 Unit + 3 Edge Case + 1 Integration + 1 Performance = 8 tests, all pass.

## Branch decision

Branch 1 (batch-fix) with **per-site disposition**. The rule's mechanical fire surfaces the question; each finding requires writer judgment under the W2 rubric (arithmetic-domain stays UInt8, byte-domain retypes to Byte). AST cannot mechanize the classification (cross-function-body arithmetic detection out of scope).

## Outcome record

`swift-institute/Audits/PROMOTE-API-BYTE-004-2026-05-19.md`.
