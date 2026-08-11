# Validation receipt: [API-BYTE-005]
Date: 2026-05-19
Rule: uint8 ascii extension
Placement tier: institute
Pack: Institute Linter Rule Byte
Source: `swift-foundations/swift-institute-linter-rules/Sources/Institute Linter Rule Byte/Lint.Rule.Byte.UInt8AsciiExtension.swift`

## Validation ladder (regex pre-scan)

Pattern: `grep -rE 'extension UInt8\.ASCII|extension UInt8 \{[^}]*static.*ascii' Sources/`

| Level | Package | Diagnostic count | Notes |
|-------|---------|------------------|-------|
| Simple | swift-tagged-primitives | 0 | clean |
| Simple | swift-carrier-primitives | 0 | clean |
| Simple | swift-pair-primitives | 0 | clean |
| Medium | swift-property-primitives | 0 | clean |
| Medium | swift-cardinal-primitives | 0 | clean |
| Hard | swift-affine-primitives | 0 | clean |
| Hard | swift-ordinal-primitives | 0 | clean |

## Ground-truth probe

| Package | Diagnostic count |
|---------|------------------|
| swift-rfc-791 | 0 |
| swift-rfc-9293 | 0 |
| swift-rfc-7519 | 0 |
| swift-rfc-4648 | 0 |
| swift-iso-32000 | 0 |
| swift-incits-4-1986 | 0 |
| swift-ascii-primitives | 0 |
| swift-binary-primitives | 0 |
| swift-foundations/swift-ascii | 0 |

## Test suite

`swift test --filter Byte`: 51 tests pass. Per-rule sub-suite "uint8 ascii extension Tests": 3 Unit + 3 Edge Case + 1 Integration + 1 Performance = 8 tests, all pass.

## Branch decision

Branch: future-prevention. W4 wrapper deletion already removed the only historical instances; the rule prevents regression after the W3 revert event.

## Outcome record

`swift-institute/Audits/PROMOTE-API-BYTE-005-2026-05-19.md`.
