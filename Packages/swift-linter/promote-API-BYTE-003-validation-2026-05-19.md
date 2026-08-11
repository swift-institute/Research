# Validation receipt: [API-BYTE-003]
Date: 2026-05-19
Rule: binary serializable uint8 witness
Placement tier: institute
Pack: Institute Linter Rule Byte
Source: `swift-foundations/swift-institute-linter-rules/Sources/Institute Linter Rule Byte/Lint.Rule.Byte.BinarySerializableUInt8Witness.swift`

## Validation ladder (regex pre-scan)

Pattern: `grep -rE 'Buffer\.Element == UInt8|Source\.Element == UInt8|Bytes\.Element == UInt8' Sources/`

| Level | Package | Diagnostic count | Notes |
|-------|---------|------------------|-------|
| Simple | swift-tagged-primitives | 0 | clean |
| Simple | swift-carrier-primitives | 0 | clean |
| Simple | swift-pair-primitives | 0 | clean |
| Medium | swift-property-primitives | 0 | clean |
| Medium | swift-cardinal-primitives | 0 | clean |
| Hard | swift-affine-primitives | 0 | clean |
| Hard | swift-ordinal-primitives | 0 | clean |

## Ground-truth probe (work prioritization input for downstream sweep arc)

Regex upper-bound (AST fire count will be lower after `@_disfavoredOverload` exemption):

| Package | R3 regex upper bound |
|---------|---------------------:|
| swift-iso-32000 | **73** |
| swift-rfc-4648 | **52** |
| swift-ascii-primitives | **15** |
| swift-rfc-9293 | **13** |
| swift-incits-4-1986 | **6** |
| swift-binary-primitives | 3 |
| swift-rfc-7519 | 1 |
| swift-foundations/swift-ascii | 1 |
| swift-rfc-791 | 0 |

**Total**: 164 regex hits across 8 packages. AST-walk fire count expected lower (the 6 forwarders in `swift-binary-primitives` carry `@_disfavoredOverload` and will be exempted; the regex over-counts those).

## Test suite

`swift test --filter Byte`: 51 tests pass. Per-rule sub-suite "binary serializable uint8 witness Tests": 2 Unit + 3 Edge Case + 1 Integration + 1 Performance = 7 tests, all pass.

## Branch decision

Branch 1 (batch-fix). These are real true-positive witnesses from the W2 cascade. Per the principal's W2 PAUSE direction, the rule's surfacing IS the work-prioritization input for the next "mechanical sweep" arc. Per-package fire-count gives the sweep its work queue order (largest packages first: iso-32000, rfc-4648, ascii-primitives, …).

## Outcome record

`swift-institute/Audits/PROMOTE-API-BYTE-003-2026-05-19.md`.

---

## Amendment 2026-05-20 — Arc G Phase 7 coverage extension

Arc G's swift-primitives byte-lint validation surfaced a **coverage
observation** (class-c structural reveal): the rule's
`extensionConformsToSerializableLike` checked the inheritance clause
only — fired on the conformer-extension shape
`extension Foo: Binary.Serializable { ... }`, but NOT on the
**default-impl-extension shape** `extension Binary.Serializable { ... }`
(extended type IS the protocol; no inheritance clause).

The skill's `[API-BYTE-003]` Statement (*"witness implementations MUST
use Buffer.Element == Byte"*) covers both shapes by semantic intent —
default impls ARE witness implementations for any conformer without an
override. Statement scope > implementation scope.

### Coverage extension landed

Source: `swift-foundations/swift-institute-linter-rules/Sources/Institute Linter Rule Byte/Lint.Rule.Byte.BinarySerializableUInt8Witness.swift`

The gate now accepts EITHER path:

1. **Path 1 (existing)** — conformer-extension shape: inheritance
   clause names `Binary.Serializable` / `Binary.Parseable`.
2. **Path 2 (new)** — default-impl-extension shape: extended type IS
   `Binary.Serializable` / `Binary.Parseable` (covers both bare
   `extension Binary.Serializable { ... }` AND conditional
   `extension Binary.Serializable where Self: ... { ... }` shapes).

The per-function `@_disfavoredOverload` exemption applies unchanged
across both paths.

### Re-validation

Re-run of the Arc G test-target harness
(`Tests/Institute Linter Rule Byte Tests/Lint.Rule.Byte.ArcG.Validation.swift`)
across all 150 public swift-primitives packages after the extension:

| Rule | Before extension | After extension |
|------|-----------------:|----------------:|
| API-BYTE-003 | 0 | **0** |

Per-site breakdown for the 4 known default-impl-extension sites in
swift-binary-primitives:

| Site | Where-clause | `@_disfavoredOverload`? | Disposition |
|---|---|---|---|
| `Binary.Serializable.swift` (primary) | `Byte` | n/a | not flagged — Byte-typed |
| `Binary.Parseable+FixedWidthIntegerRaw.swift` (primary) | `Byte` | n/a | not flagged — Byte-typed |
| `Binary.Serializable+UInt8.swift` (SLI) | `UInt8` | yes | not flagged — exempt |
| `Binary.Parseable+UInt8.swift` (SLI) | `UInt8` | yes | not flagged — exempt |

Extension is **future-prevention**: 0 current FNs, 0 new firings; the
gate now catches future `extension Binary.Serializable { ... where
Buffer.Element == UInt8 ... }` placements that lack `@_disfavoredOverload`.

### Test-suite delta

Per-rule sub-suite "binary serializable uint8 witness Tests" extended:
2 → 5 Unit cases (added: bare default-impl on Binary.Serializable,
bare default-impl on Binary.Parseable, conditional default-impl
`where Self: RawRepresentable`). 3 → 6 Edge Case cases (added:
default-impl Byte-typed Binary.Serializable, default-impl
`@_disfavoredOverload` UInt8 Binary.Serializable, default-impl
Byte-typed Binary.Parseable). 13 tests total, all pass.
