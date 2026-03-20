# swift-standard-library-extensions Audit

**Date**: 2026-03-20
**Skills**: /implementation, /naming
**Scope**: 86 source files in `Sources/Standard Library Extensions/`
**Mode**: READ-ONLY

## Summary

| Severity | Count |
|----------|-------|
| HIGH     | 2     |
| MEDIUM   | 5     |
| LOW      | 4     |
| INFO     | 3     |

This package is predominantly well-structured. The vast majority of methods mirror stdlib naming conventions (`withUnsafeBufferPointer`, `withContiguousStorageIfAvailable`, `removeAll`, `compactMapKeys`, etc.) and correctly receive a naming pass. The findings below focus exclusively on names that are **our invention** (not stdlib-mandated) and structural issues.

## Findings

### HIGH

#### [SLIB-001] `String.CaseInsensitive` -- compound type name

**File**: `String.swift`, line 21
**Rule**: [API-NAME-001]

`String.CaseInsensitive` is a compound name. Under Nest.Name, this should be `String.Case.Insensitive` or a separate nesting approach. Note that `String.Case` already exists in the same file (line 63) as a transformation struct, so these two concepts collide. The design needs reconciliation: `String.Case` currently represents transformation styles (upper/lower/title), while `CaseInsensitive` is a wrapper for equality comparison. These are different domains occupying adjacent namespace slots.

**Current**:
```swift
public struct CaseInsensitive: Hashable, Comparable, Sendable { ... }
```

**Expected**: Either nest as `String.Case.Insensitive` (requires `String.Case` to become an enum namespace rather than a struct), or relocate `CaseInsensitive` into a more descriptive namespace.

---

#### [SLIB-002] `Set String.swift` -- file naming violates one-type-per-file

**File**: `Set String.swift`
**Rule**: [API-IMPL-005]

The filename `Set String.swift` does not follow the `Type.Nested.swift` convention. It contains `Set<String>.Swift` (a nested struct) plus a static accessor `.swift` on `Set<String>`. The file should be named `Set.String.Swift.swift` or similar to reflect its actual type.

Additionally, `Set<String>.Swift` uses a backtick-escaped keyword as a type name, which is unusual. The naming `Set<String>.swift` (lowercase accessor) returning `Set<String>.Swift` (uppercase type) creates a confusing API surface. Consider whether `Set<String>.keywords` (a static property) would be simpler than this namespace struct pattern.

---

### MEDIUM

#### [SLIB-003] `Array.Builder.swift` contains three `Builder` types -- violates one-type-per-file

**File**: `Array.Builder.swift`
**Rule**: [API-IMPL-005]

This file defines `Array.Builder`, `ArraySlice.Builder`, and `ContiguousArray.Builder` in a single file. Each should be in its own file:
- `Array.Builder.swift` -- `Array.Builder`
- `ArraySlice.Builder.swift` -- `ArraySlice.Builder`
- `ContiguousArray.Builder.swift` -- `ContiguousArray.Builder`

---

#### [SLIB-004] `String.Builder.swift` contains two `Builder` types

**File**: `String.Builder.swift`
**Rule**: [API-IMPL-005]

This file defines both `String.Builder` and `Substring.Builder`. `Substring.Builder` should be in its own file.

---

#### [SLIB-005] `Range.Builder.swift` contains two `Builder` types

**File**: `Range.Builder.swift`
**Rule**: [API-IMPL-005]

This file defines both `Range.Builder` and `ClosedRange.Builder`. `ClosedRange.Builder` should be in `ClosedRange.Builder.swift`.

---

#### [SLIB-006] `removingDuplicates()` -- our-invention compound method

**File**: `RangeReplaceableCollection.swift`, line 37
**Rule**: [API-NAME-002]

`removingDuplicates()` is not a stdlib method -- it is our invention. The compound name joins "removing" + "duplicates". However, this follows the Swift API Design Guidelines pattern of `-ing` for nonmutating variants (mirroring the hypothetical mutating `removeDuplicates()`), and `remove` gets a stdlib naming pass. This is borderline. A nested accessor alternative like `.removing.duplicates()` exists but may be over-engineered for a single method. Flagging for awareness.

---

#### [SLIB-007] `cartesianProduct` / `cartesianSquare` -- our-invention compound methods

**File**: `Set.swift`, lines 92, 116
**Rule**: [API-NAME-002]

`cartesianProduct(_:)` and `cartesianSquare()` are our invention. These are compound names. Under strict [API-NAME-002], they should use nested accessors: `set.cartesian.product(other)` and `set.cartesian.square()`. However, "Cartesian product" is a single mathematical concept (a proper noun + technical term), not two independent words. This is analogous to how `RFC_4122.UUID` mirrors spec terminology. Flagging for explicit decision: does mathematical terminology get the same pass as stdlib conventions?

---

### LOW

#### [SLIB-008] `isApproximatelyEqual(to:tolerance:)` -- matches Swift Numerics convention

**File**: `FloatingPoint.swift`, line 20
**Rule**: [API-NAME-002]

`isApproximatelyEqual` is a compound name but mirrors the Swift Numerics package convention (`FloatingPoint.isApproximatelyEqual(to:absoluteTolerance:)`). Gets a pass for mirroring ecosystem convention. No action needed.

---

#### [SLIB-009] `Bool.Builder` namespace has `All`, `Any`, `Count`, `One`, `None` as nested enums

**File**: `Bool.Builder.swift`
**Rule**: [API-IMPL-005]

`Bool.Builder` contains five `@resultBuilder` enums in a single file. Strictly, each is a distinct type and [API-IMPL-005] says one type per file. However, these are tightly coupled (all are result builders under the same `Builder` namespace enum), and splitting into `Bool.Builder.All.swift`, `Bool.Builder.Any.swift`, etc. may reduce cohesion. Flagging for explicit decision on whether namespace-internal sub-types are exempt from one-type-per-file.

---

#### [SLIB-010] `Result.Builder` namespace has `First` and `All` as nested enums

**File**: `Result.Builder.swift`
**Rule**: [API-IMPL-005]

Same pattern as [SLIB-009]. `Result.Builder` contains `First` and `All` result builder enums in one file.

---

#### [SLIB-011] `isSorted()` / `isSorted(by:)` -- our-invention compound method

**File**: `Sequence.swift`, lines 62, 83
**Rule**: [API-NAME-002]

`isSorted` joins "is" + "sorted". This follows the Swift API Design Guidelines `is`-prefix convention for boolean properties/methods (like `isEmpty`, `isMultiple(of:)`). The `is`-prefix is a well-established Swift pattern. Gets a pass.

---

### INFO

#### [SLIB-012] ~Copyable `Result` type shadows `Swift.Result`

**File**: `Result.swift`, line 12
**Rule**: N/A (design note)

The package defines a custom `Result<Success: ~Copyable, Failure: Error>` that shadows `Swift.Result`. This is intentional (to support noncopyable types), but consumers must use `Swift.Result` explicitly when they want the stdlib version. The `Result.Builder.swift` and `Result.swift` files both reference `Swift.Result` explicitly to disambiguate. This is well-handled.

---

#### [SLIB-013] 41 empty stub files

**Rule**: N/A (housekeeping)

41 of 86 files are empty stubs containing only `// Add utilities here` comments. Examples: `AnyBidirectionalCollection.swift`, `AnyCollection.swift`, `AnyHashable.swift`, `AnyIterator.swift`, etc. These serve as placeholders for future extensions. No naming or implementation concern, but they contribute to file count without adding functionality.

---

#### [SLIB-014] Typed throws `@_disfavoredOverload` pattern is consistent

**Rule**: N/A (positive observation)

The typed throws overloads for `withUnsafePointer`, `withUnsafeBytes`, `withUnsafeTemporaryAllocation`, `withTaskCancellationHandler`, `ManagedBuffer`, `Span`, `Array`, and `Collection` all correctly use `throws(E)` signatures with `@_disfavoredOverload` to avoid interfering with stdlib's native `rethrows` overloads. The pattern is consistent across all 7 files. All function names mirror stdlib exactly -- no naming findings.

---

## Methods receiving stdlib naming pass

The following compound method names are **not** findings because they mirror stdlib or Swift API Design Guidelines conventions:

| Method | Rationale |
|--------|-----------|
| `withUnsafeBufferPointer`, `withUnsafeMutableBufferPointer` | stdlib mirror |
| `withContiguousStorageIfAvailable` | stdlib mirror |
| `withUnsafePointer`, `withUnsafeMutablePointer` | stdlib mirror |
| `withUnsafeBytes`, `withUnsafeMutableBytes` | stdlib mirror |
| `withUnsafeTemporaryAllocation` | stdlib mirror |
| `withTaskCancellationHandler` | stdlib mirror |
| `withCheckedContinuation`, `withUnsafeContinuation` | stdlib mirror |
| `withUnsafeMutablePointerToElements/Header/Pointers` | stdlib mirror |
| `mapKeys`, `compactMapKeys` | mirrors stdlib `mapValues`/`compactMapValues` |
| `flatMap`, `flatMapError`, `mapError` | stdlib `Result` mirror |
| `buildExpression`, `buildPartialBlock`, `buildBlock`, etc. | `@resultBuilder` protocol |
| `isApproximatelyEqual` | Swift Numerics convention |
| `isSorted` | Swift `is`-prefix convention |
| `removingDuplicates` | Swift `-ing` nonmutating convention (flagged as [SLIB-006] for awareness) |
