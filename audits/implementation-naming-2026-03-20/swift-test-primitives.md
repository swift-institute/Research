# swift-test-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (read-only)
**Scope**: 56 source files across 4 modules
**Skills**: [API-NAME-001], [API-NAME-002], [IMPL-002], [IMPL-010], [PATTERN-017], [PATTERN-021], [API-IMPL-005]

## Summary Table

| ID | Severity | Rule | File | Line | Description |
|----|----------|------|------|------|-------------|
| TEST-001 | MEDIUM | [IMPL-002] | Test.Issue.Kind.swift | 49 | `.rawValue` access on `Test.Expectation.ID` |
| TEST-002 | MEDIUM | [IMPL-002] | Test.Event.swift | 122 | `.rawValue` access on `Test.Case.ID` |
| TEST-003 | MEDIUM | [IMPL-002] | Test.Benchmark.Trend.swift | 29,42 | `.rawValue` on `Interpretation` struct |
| TEST-004 | LOW | [API-IMPL-005] | Test.Expression.Value.swift | 76-84 | `OptionalProtocol` helper protocol in same file as `Test.Expression.Value` |
| TEST-005 | LOW | [API-IMPL-005] | Test.Benchmark.Measurement.swift | 155-161 | `Sample.Metric` extension in same file as `Test.Benchmark.Measurement` |
| TEST-006 | LOW | [PATTERN-021] | Test.Benchmark.Complexity+evidence.swift | various | Raw `Int` and `Double` arithmetic (acceptable — pure math) |
| TEST-007 | MEDIUM | [API-NAME-002] | Test.Snapshot.Strategy+Description.swift | 70 | `dump` is a property name that mirrors stdlib function — borderline |

## Findings

### TEST-001 — `.rawValue` at Call Site

**File**: `Sources/Test Primitives Core/Test.Issue.Kind.swift`, line 49
**Rule**: [IMPL-002], [PATTERN-017]

```swift
case .expectationFailed(let id):
    return "Expectation failed (id: \(id.rawValue))"
```

The `id` is a `Tagged<Test.Expectation, UInt64>` and `.rawValue` is accessed for string interpolation. This should use a `CustomStringConvertible` conformance on the `Tagged` type instead, or interpolate `id` directly if it already conforms.

### TEST-002 — `.rawValue` at Call Site

**File**: `Sources/Test Primitives Core/Test.Event.swift`, line 122
**Rule**: [IMPL-002], [PATTERN-017]

```swift
parts.append("case:\(caseID.rawValue)")
```

Same pattern as TEST-001 — accessing `.rawValue` on `Tagged<Test.Case, UInt64>` for debug output. Should interpolate the tagged value directly.

### TEST-003 — `.rawValue` on Interpretation Struct

**File**: `Sources/Test Primitives Core/Test.Benchmark.Trend.swift`, lines 29, 42
**Rule**: [IMPL-002], [PATTERN-017]

```swift
public init(rawValue: Swift.String) {
    self.rawValue = rawValue
}
// ...
public var description: Swift.String { rawValue }
```

`Trend.Interpretation` uses a raw `String` backing with a public `rawValue` property. Since `Interpretation` is not a `Tagged` wrapper but a custom struct with factory constants, the `rawValue` naming is the conventional pattern for `RawRepresentable`-style types. The `description` accessor extracts `.rawValue` at a call site (line 42). This is borderline — the type defines its own `rawValue`, so it's not violating the intent of [PATTERN-017] which targets wrapper-type `.rawValue` leakage. **Borderline acceptable** given the type's design as a string-backed discriminant.

### TEST-004 — Helper Protocol in Type File

**File**: `Sources/Test Primitives Core/Test.Expression.Value.swift`, lines 76-84
**Rule**: [API-IMPL-005]

`OptionalProtocol` is an `internal` helper protocol defined alongside `Test.Expression.Value`. Strictly, this is a second type declaration in the file. Since it's `internal` and exclusively serves this type, the pragmatic impact is minimal, but per [API-IMPL-005] it should be in its own file.

### TEST-005 — Foreign Type Extension in Type File

**File**: `Sources/Test Primitives Core/Test.Benchmark.Measurement.swift`, lines 155-161
**Rule**: [API-IMPL-005]

An extension on `Sample.Metric` (a type from `Sample_Primitives`) is defined in the `Measurement` file:

```swift
extension Sample.Metric {
    public func extract(from measurement: Test.Benchmark.Measurement) -> Duration { ... }
}
```

This extends a foreign type in a file named for a local type. Per [API-IMPL-005], this integration extension should live in its own file (e.g., `Sample.Metric+Test.Benchmark.Measurement.swift`).

### TEST-006 — Raw Int/Double Arithmetic in Evidence Construction [ACCEPTABLE]

**File**: `Sources/Test Primitives Core/Test.Benchmark.Complexity+evidence.swift`
**Rule**: [PATTERN-021]

The evidence construction function uses extensive raw `Int` and `Double` arithmetic for statistical computation (log-log regression, growth ratios, Mann-Kendall). This is pure math code operating on `[Duration]` and `[(size: Int, metric: Duration)]` data points. Typed arithmetic primitives (Index, Cardinal, etc.) are not applicable to floating-point statistical computation. **Acceptable**.

### TEST-007 — `dump` Property Name

**File**: `Sources/Test Snapshot Primitives/Test.Snapshot.Strategy+Description.swift`, line 70
**Rule**: [API-NAME-002]

```swift
public static var dump: Self { ... }
```

The property is named `dump` which mirrors `Swift.dump()`. This is a static factory on `Strategy`, so the call site reads `Strategy.dump` which is clear. Not a compound name violation, but worth noting as a name that shadows a stdlib function.

## Clean Areas

### Naming ([API-NAME-001], [API-NAME-002])

Excellent namespace hierarchy:
- `Test.Case`, `Test.ID`, `Test.Text`, `Test.Expression`, `Test.Expectation`, `Test.Issue`, `Test.Trait`, `Test.Event`, `Test.Attachment`, `Test.Benchmark`
- `Test.Text.Segment`, `Test.Text.Segment.Style`
- `Test.Expression.Value`, `Test.Expectation.Failure`
- `Test.Issue.Kind`, `Test.Trait.Kind`, `Test.Event.Kind`, `Test.Event.Result`
- `Test.Benchmark.Measurement`, `Test.Benchmark.Iteration`, `Test.Benchmark.Evaluation`, `Test.Benchmark.Configuration`, `Test.Benchmark.Trend`, `Test.Benchmark.Error`, `Test.Benchmark.Complexity`
- `Test.Benchmark.Complexity.Class`, `Test.Benchmark.Complexity.Exponent`, `Test.Benchmark.Complexity.Candidate`, `Test.Benchmark.Complexity.Candidate.Fit`, `Test.Benchmark.Complexity.Evidence`
- `Test.Snapshot`, `Test.Snapshot.Strategy`, `Test.Snapshot.Diffing`, `Test.Snapshot.Diff`, `Test.Snapshot.Diff.Result`, `Test.Snapshot.Diff.Result.StructuralOperation`, `Test.Snapshot.Result`, `Test.Snapshot.Recording`, `Test.Snapshot.Redaction`, `Test.Snapshot.Inline`, `Test.Snapshot.Faceted`, `Test.Snapshot.Faceted.Result`
- No compound type names.

No compound method/property names. Factory methods use clean patterns: `.timeLimit()`, `.tag()`, `.enabled(if:)`, `.disabled()`, `.bug()`, `.serialized`, `.exclusive(group:)`, `.timed()`.

### `Int(bitPattern:)` ([IMPL-010])

No `Int(bitPattern:)` usage. The package operates in the `String`, `Duration`, `Double` domains, not memory/pointer domains.

### Typed Throws ([API-ERR-001])

`Test.Benchmark.Error` uses typed throws correctly.

### One Type Per File ([API-IMPL-005])

Generally well-organized with one type per file. The exceptions noted (TEST-004, TEST-005) are minor.

## Verdict

**Very Good**. Two `.rawValue` call-site usages in debug output (TEST-001, TEST-002) are the primary findings — they should use direct interpolation of the `Tagged` value. The package has outstanding namespace hierarchy depth (6 levels: `Test.Benchmark.Complexity.Candidate.Fit`) while maintaining readability. No naming violations.
