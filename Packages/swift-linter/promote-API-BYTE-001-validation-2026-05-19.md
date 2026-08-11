# Validation receipt: [API-BYTE-001]
Date: 2026-05-19
Rule: uint8 conforms to byte protocol
Placement tier: institute
Pack: Institute Linter Rule Byte
Source: `swift-foundations/swift-institute-linter-rules/Sources/Institute Linter Rule Byte/Lint.Rule.Byte.UInt8ConformsToByteProtocol.swift`

## Validation ladder (regex pre-scan)

Detection method: regex pre-scan (expected count ~0; future-prevention rule).

Pattern: `grep -rln 'extension UInt8.*Byte\.\`Protocol\`' Sources/`

| Level | Package | Diagnostic count | Notes |
|-------|---------|------------------|-------|
| Simple | swift-tagged-primitives | 0 | clean |
| Simple | swift-carrier-primitives | 0 | clean |
| Simple | swift-pair-primitives | 0 | clean |
| Medium | swift-property-primitives | 0 | clean |
| Medium | swift-cardinal-primitives | 0 | clean |
| Hard | swift-affine-primitives | 0 | clean |
| Hard | swift-ordinal-primitives | 0 | clean |

## Ground-truth probe (W2 cascade packages)

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

`swift test --filter Byte` on `swift-foundations/swift-institute-linter-rules`: 51 tests in 34 suites passed (0.055 s). Per-rule sub-suite "uint8 conforms to byte protocol Tests": 3 Unit + 3 Edge Case + 1 Integration + 1 Performance = 8 tests, all pass.

## Branch decision

Branch: future-prevention (no batch-fix needed). The sibling-form refactor at `swift-byte-primitives@fbccde4` already removed the historical precedent; the rule guards against regression.

## Outcome record

`swift-institute/Audits/PROMOTE-API-BYTE-001-2026-05-19.md`.
