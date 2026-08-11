# Validation receipt: [API-BYTE-006]
Date: 2026-05-19
Rule: uint8 forwarder missing disfavored
Placement tier: institute
Pack: Institute Linter Rule Byte
Source: `swift-foundations/swift-institute-linter-rules/Sources/Institute Linter Rule Byte/Lint.Rule.Byte.UInt8ForwarderMissingDisfavored.swift`

## Validation ladder (regex pre-scan)

Pattern: `grep -rE 'where Element == Byte' Sources/` (upper bound on byte-domain extension contexts; AST rule additionally requires UInt8 mention AND missing @_disfavoredOverload).

| Level | Package | byte-domain ext upper bound | Notes |
|-------|---------|------------------:|-------|
| Simple | swift-tagged-primitives | 0 | clean |
| Simple | swift-carrier-primitives | 0 | clean |
| Simple | swift-pair-primitives | 0 | clean |
| Medium | swift-property-primitives | 0 | clean |
| Medium | swift-cardinal-primitives | 0 | clean |
| Hard | swift-affine-primitives | 0 | clean |
| Hard | swift-ordinal-primitives | 0 | clean |

## Ground-truth probe

| Package | byte-domain extension upper bound |
|---------|----------------------------------:|
| swift-rfc-791 | 0 |
| swift-rfc-9293 | 0 |
| swift-rfc-7519 | 0 |
| swift-rfc-4648 | 0 |
| swift-iso-32000 | 0 |
| swift-incits-4-1986 | 0 |
| swift-ascii-primitives | 0 |
| swift-binary-primitives | **8** |
| swift-foundations/swift-ascii | 0 |

The 8 byte-domain extensions in swift-binary-primitives are W1 BSLI helpers (`Array+Byte.swift`, `Collection+Byte.swift`, `Numeric+Byte.swift`). Per the W1 outcome in `broader-l2-l3-byte-typing-gap-plan.md` the BSLI #3 UInt8 forwarder already carries `@_disfavoredOverload`. AST rule fire count is expected to be ≤ regex upper bound; the rule's exemption filters the compliant forwarders.

## Test suite

`swift test --filter Byte`: 51 tests pass. Per-rule sub-suite "uint8 forwarder missing disfavored Tests": 3 Unit + 4 Edge Case + 1 Integration + 1 Performance = 9 tests, all pass.

## Branch decision

Branch: future-prevention. The current ecosystem instances (W1 BSLI helpers) already carry `@_disfavoredOverload`; the rule prevents drift in byte-domain extensions added during the downstream mechanical sweep.

## Outcome record

`swift-institute/Audits/PROMOTE-API-BYTE-006-2026-05-19.md`.
