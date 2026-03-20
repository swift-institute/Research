# swift-formatting-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: implementation [IMPL-*], naming [API-NAME-*]
**Scope**: All `.swift` files in `Sources/`

---

## Summary Table

| ID | Severity | Requirement | File | Title |
|----|----------|-------------|------|-------|
| FMT-001 | CRITICAL | [API-NAME-001] | FormatStyle.swift:20 | `FormatStyle` is a compound name; should be `Format.Style` |
| FMT-002 | CRITICAL | [API-NAME-001] | Format.FloatingPoint.swift:23 | `FloatingPoint` shadows `Swift.FloatingPoint`; should be `Format.Decimal` or similar |
| FMT-003 | HIGH | [API-NAME-001] | Format.Numeric.SignDisplayStrategy.swift:15 | `SignDisplayStrategy` is a compound name; should be `Sign.Display` or `Sign.Strategy` |
| FMT-004 | HIGH | [API-NAME-001] | Format.Numeric.DecimalSeparatorStrategy.swift:15 | `DecimalSeparatorStrategy` is a compound name; should be `Separator.Strategy` or `Separator.Display` |
| FMT-005 | MEDIUM | [API-NAME-002] | FormatStyle.swift:22-25 | `FormatInput` / `FormatOutput` are compound associated type names |
| FMT-006 | MEDIUM | [API-NAME-002] | Format.FloatingPoint.swift:27 | `shouldRound` is a compound property name |
| FMT-007 | MEDIUM | [API-NAME-002] | Format.FloatingPoint.swift:28 | `precisionDigits` is a compound property name |
| FMT-008 | MEDIUM | [API-NAME-002] | Format.FloatingPoint.swift:88 | `formatWithPrecision` is a compound method name |
| FMT-009 | LOW | [IMPL-INTENT] | Format.FloatingPoint.swift:96-118 | Manual digit-by-digit precision formatting reads as mechanism, not intent |
| FMT-010 | LOW | [API-IMPL-005] | FormatStyle.swift:36-80 | `BinaryFloatingPoint.formatted` and `BinaryInteger.formatted` extensions are in the protocol file instead of separate files |
| FMT-011 | LOW | [API-IMPL-005] | Format.FloatingPoint.swift:190-207 | `BinaryFloatingPoint.formatted(_ format: Format.FloatingPoint)` extension is in the type file instead of a separate file |
| FMT-012 | INFO | [API-NAME-001] | Formatting.swift:12 | `Format` namespace is well-formed |
| FMT-013 | INFO | — | Format.Numeric.Notation.swift:15 | `Notation` enum follows Nest.Name correctly |
| FMT-014 | LOW | [API-NAME-002] | Format.Numeric.Notation.swift:20 | `compactName` is a compound case name |

**Totals**: 2 CRITICAL, 2 HIGH, 4 MEDIUM, 4 LOW, 2 INFO

---

## Findings

### Finding [FMT-001]: `FormatStyle` is a compound type name — CRITICAL

**File**: `FormatStyle.swift:20`
**Requirement**: [API-NAME-001] — All types MUST use the Nest.Name pattern. Compound type names are forbidden.

`FormatStyle` is a compound name joining "Format" and "Style". Under [API-NAME-001] this should be `Format.Style`, nested inside the existing `Format` namespace enum.

**Current**:
```swift
public protocol FormatStyle<FormatInput, FormatOutput>: Sendable { ... }
```

**Expected**:
```swift
extension Format {
    public protocol Style<Input, Output>: Sendable { ... }
}
```

This also requires a new file name: `Format.Style.swift`.

**Note**: This change would also fix FMT-005 (the associated types would become `Input` and `Output` instead of `FormatInput` / `FormatOutput`).

---

### Finding [FMT-002]: `FloatingPoint` shadows `Swift.FloatingPoint` — CRITICAL

**File**: `Format.FloatingPoint.swift:23`
**Requirement**: [API-NAME-001] — Types implementing specifications MUST mirror specification terminology. Types MUST NOT shadow standard library names.

`Format.FloatingPoint` shadows `Swift.FloatingPoint`. The file itself works around this at line 55 and 88 with explicit `Swift.BinaryFloatingPoint` qualification. This is a naming conflict that forces disambiguation at every use site.

**Current**:
```swift
extension Format {
    public struct FloatingPoint: Sendable { ... }
}
```

**Proposed alternatives** (in decreasing preference):
1. `Format.Decimal` — describes what it formats (decimal representation)
2. `Format.Number` — aligns with the `.number` static property already in use
3. `Format.Real` — mathematical term for non-integer numbers

The `.number` and `.percent` static properties already exist on the type, and consumer call sites use `.number` — so `Format.Number` would be the most consistent rename. However, `Format.Numeric` already exists as a namespace. This needs a design decision about whether `Format.Number` (the formatter struct) and `Format.Numeric` (the configuration namespace) should merge or remain distinct.

---

### Finding [FMT-003]: `SignDisplayStrategy` is a compound name — HIGH

**File**: `Format.Numeric.SignDisplayStrategy.swift:15`
**Requirement**: [API-NAME-001]

`SignDisplayStrategy` joins three words into a single compound name. Under Nest.Name this should decompose.

**Current**:
```swift
extension Format.Numeric {
    public enum SignDisplayStrategy: Sendable, Equatable { ... }
}
```

**Proposed**:
```swift
extension Format.Numeric {
    public enum Sign: Sendable, Equatable {
        // or nest further: Format.Numeric.Sign.Display
    }
}
```

The cases (`automatic`, `never`, `always`) would work naturally under `Format.Numeric.Sign`.

---

### Finding [FMT-004]: `DecimalSeparatorStrategy` is a compound name — HIGH

**File**: `Format.Numeric.DecimalSeparatorStrategy.swift:15`
**Requirement**: [API-NAME-001]

`DecimalSeparatorStrategy` joins three words. Under Nest.Name this should decompose.

**Current**:
```swift
extension Format.Numeric {
    public enum DecimalSeparatorStrategy: Sendable, Equatable { ... }
}
```

**Proposed**:
```swift
extension Format.Numeric {
    public enum Separator: Sendable, Equatable { ... }
}
```

Or, if more granularity is needed: `Format.Numeric.Separator` with cases `automatic` and `always`.

---

### Finding [FMT-005]: `FormatInput` / `FormatOutput` are compound associated type names — MEDIUM

**File**: `FormatStyle.swift:22-25`
**Requirement**: [API-NAME-002] — Methods and properties MUST NOT use compound names.

Associated type names `FormatInput` and `FormatOutput` are compound identifiers. If the protocol is renamed to `Format.Style` per FMT-001, these naturally become `Input` and `Output`.

**Current**:
```swift
associatedtype FormatInput
associatedtype FormatOutput
```

**Expected** (after FMT-001 fix):
```swift
associatedtype Input
associatedtype Output
```

---

### Finding [FMT-006]: `shouldRound` is a compound property name — MEDIUM

**File**: `Format.FloatingPoint.swift:27`
**Requirement**: [API-NAME-002]

`shouldRound` is a compound property. Under [API-NAME-002], properties should use simple names or nested accessors.

**Current**:
```swift
public let shouldRound: Bool
```

**Proposed**: `isRounded: Bool` (follows Swift API Guidelines for Boolean properties) or expose rounding as a nested configuration.

---

### Finding [FMT-007]: `precisionDigits` is a compound property name — MEDIUM

**File**: `Format.FloatingPoint.swift:28`
**Requirement**: [API-NAME-002]

`precisionDigits` joins two words into a compound property name.

**Current**:
```swift
public let precisionDigits: Int?
```

**Proposed**: `precision: Int?` — the type context (`Format.FloatingPoint`) already establishes that precision refers to digits. The `precision(_ digits: Int)` chaining method at line 183 already uses this simpler name.

---

### Finding [FMT-008]: `formatWithPrecision` is a compound method name — MEDIUM

**File**: `Format.FloatingPoint.swift:88`
**Requirement**: [API-NAME-002]

`formatWithPrecision` joins three words into a compound method name.

**Current**:
```swift
static func formatWithPrecision<T: Swift.BinaryFloatingPoint>(_ value: T, precision: Int) -> String
```

**Proposed**: Since this is an internal helper, rename to `format(_:precision:)` — the parameter label already communicates the precision aspect:
```swift
static func format<T: Swift.BinaryFloatingPoint>(_ value: T, precision: Int) -> String
```

---

### Finding [FMT-009]: Manual digit-by-digit precision formatting reads as mechanism — LOW

**File**: `Format.FloatingPoint.swift:96-118`
**Requirement**: [IMPL-INTENT] — Code reads as intent, not mechanism.

The `formatWithPrecision` method manually multiplies by powers of 10, rounds, extracts integer/fractional parts, and builds a string digit-by-digit. This is ~30 lines of mechanism-heavy arithmetic.

```swift
var multiplier: T = 1
for _ in 0..<precision {
    multiplier *= 10
}
let rounded = (absValue * multiplier).rounded() / multiplier
// ... digit extraction loop ...
```

This reads as "how to format" rather than "format with N decimal places." A higher-intent approach might use String interpolation with a format specifier or extract named operations (`scaled`, `rounded`, `digits`). However, since Foundation is forbidden ([PRIM-FOUND-001]), and Swift has no stdlib decimal formatting, this manual implementation may be necessary. The severity is LOW because it is isolated inside a single `@usableFromInline` helper.

---

### Finding [FMT-010]: Multiple extensions in protocol file — LOW

**File**: `FormatStyle.swift:36-80`
**Requirement**: [API-IMPL-005] — One type per file.

The `FormatStyle.swift` file contains:
1. The `FormatStyle` protocol (line 20)
2. A `BinaryFloatingPoint` extension with `formatted` (line 36)
3. A `BinaryInteger` extension with `formatted` (line 60)

The two `formatted` extensions on stdlib protocols should each be in their own file:
- `BinaryFloatingPoint+Format.Style.swift`
- `BinaryInteger+Format.Style.swift`

---

### Finding [FMT-011]: Extension in type file — LOW

**File**: `Format.FloatingPoint.swift:190-207`
**Requirement**: [API-IMPL-005]

The `BinaryFloatingPoint.formatted(_ format: Format.FloatingPoint)` extension is defined in the same file as `Format.FloatingPoint`. This should be in a separate file:
- `BinaryFloatingPoint+Format.FloatingPoint.swift`

---

### Finding [FMT-014]: `compactName` is a compound case name — LOW

**File**: `Format.Numeric.Notation.swift:20`
**Requirement**: [API-NAME-002]

The enum case `compactName` is a compound name. Under [API-NAME-002], this should decompose. However, enum cases have limited nesting options in Swift (no nested cases), so alternatives are:
- `.compact` (if no ambiguity with other compact representations)
- Document as accepted deviation if the full meaning requires both words

---

## Structural Observations

### What is well-formed

1. **`Format` namespace enum** (FMT-012) — Clean Nest.Name pattern. All types nest correctly under `Format`.
2. **`Format.Numeric` sub-namespace** — Good decomposition of numeric configuration types.
3. **`Format.Numeric.Notation`** (FMT-013) — Simple, non-compound name, correctly nested.
4. **File naming** — Files follow the `Namespace.Type.swift` convention (e.g., `Format.Numeric.Notation.swift`).
5. **`Tagged+Formatting.swift`** — Extension file is correctly separated and named.

### Design tension: `FormatStyle` protocol location

The `FormatStyle` protocol in `FormatStyle.swift` is a top-level protocol, not nested under `Format`. This creates two parallel APIs:
- `FormatStyle` protocol with generic `formatted(_:)` on `BinaryFloatingPoint` / `BinaryInteger`
- `Format.FloatingPoint` struct with a concrete `formatted(_:)` on `BinaryFloatingPoint`

The `Format.FloatingPoint` struct does NOT conform to `FormatStyle` (documented at line 13: "Does not conform to `FormatStyle` because it works across multiple input types"). This means the package has two independent formatting mechanisms. If the protocol were `Format.Style`, this tension would be more visible and might prompt unification.

### Test file naming

- `Formatting Tests.swift` — Empty file with wrong boilerplate header ("File.swift", "swift-standards"). Should be cleaned up or removed.
- `FloatingPoint+Formatting Tests.swift` — Well-structured test suite following [TEST-004] parallel namespace pattern.
