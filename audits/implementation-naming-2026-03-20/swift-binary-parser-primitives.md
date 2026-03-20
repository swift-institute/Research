# swift-binary-parser-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Scope**: 50 files across 10 modules
**Rules**: [API-NAME-001], [API-NAME-002], [IMPL-002], [IMPL-010], [IMPL-020], [IMPL-050], [PATTERN-017], [PATTERN-021], [API-IMPL-005]

---

## Summary Table

| ID | Severity | Rule | File | Line(s) | Description |
|----|----------|------|------|---------|-------------|
| BPAR-001 | HIGH | [PATTERN-017] | Binary.Bytes.Input+subscript.swift | 11-13 | `.rawValue.rawValue` double extraction at call site |
| BPAR-002 | HIGH | [IMPL-010] | Binary.Bytes.Input+subscript.swift | 12-13 | `Int(bitPattern: count.rawValue)` and `Int(bitPattern: position)` at call site |
| BPAR-003 | MEDIUM | [IMPL-010] | Binary.Bytes.Input+properties.swift | 5 | `Cardinal(UInt(storage.count))` chain for totalCount |
| BPAR-004 | MEDIUM | [IMPL-010] | Binary.Bytes.Input+mutation.swift | 14 | `storage[Int(bitPattern: position)]` raw indexing |
| BPAR-005 | MEDIUM | [IMPL-002] | Binary.Bytes.withBorrowed.swift | 34-38 | Module-level `let _two/_four/_eight` typed count constants via `Cardinal(N)` chain |
| BPAR-006 | MEDIUM | [IMPL-010] | Binary.Bytes.withBorrowed.swift | 100, 156, 185, 341, 354, etc. | Repeated `Index<UInt8>.Count(Cardinal(UInt(n)))` at interpreter call sites |
| BPAR-007 | MEDIUM | [API-NAME-002] | Binary.Bytes.withBorrowed.swift | 45-46, 171 | `withBorrowed` compound property/method name |
| BPAR-008 | LOW | [IMPL-010] | Binary.Bytes.withBorrowed.swift | 184, 187-189 | `Int(bitPattern: savedCheckpoint)` for position restore |
| BPAR-009 | LOW | [IMPL-010] | Binary.Bytes.Machine.Run.swift | 291-399 | Repeated `Index<UInt8>.Count(Cardinal(N))` without using shared constants |
| BPAR-010 | LOW | [API-NAME-002] | Binary.Bytes.withBorrowed.swift | 48 | `WithBorrowed` compound type name |
| BPAR-011 | LOW | [API-NAME-002] | Binary.Coder.swift | 71, 86, 95, 107 | Compound method names: `decodeWhole`, `decodePrefix`, `encodeToArray`, `encodeAppending` |
| BPAR-012 | LOW | [PATTERN-017] | Binary.Bytes.Input+properties.swift | 20 | `Index<UInt8>.Count(position)` — constructing Count from Index |
| BPAR-013 | LOW | [API-IMPL-005] | Binary.Bytes.Input+subscript.swift | 20-30 | `starts(with:)` function in same file as subscript |
| BPAR-014 | INFO | [IMPL-002] | Binary.Bytes.withBorrowed.swift | 288 | `view.position = Int(bitPattern: savedCheckpoint)` — position assignment through Int conversion |
| BPAR-015 | INFO | [API-IMPL-005] | Binary.Parse.Converting.swift | 43-52 | `Error` enum nested in same file as `Converting` struct |
| BPAR-016 | INFO | [API-IMPL-005] | Binary.Parse.Validated.swift | 47-56 | `Error` enum nested in same file as `Validated` struct |
| BPAR-017 | MEDIUM | [IMPL-010] | Input.View (design) | — | `Input.View.position` typed as `Int` (not `Index<UInt8>`), forcing `Int(bitPattern:)` at every checkpoint restore |
| BPAR-018 | LOW | [API-IMPL-005] | Binary.Bytes.Machine.swift | 40-54 | 5 typealiases in Machine namespace file |

---

## Findings

### BPAR-001 — Double `.rawValue` extraction [PATTERN-017]

**File**: `Binary Input Primitives/Binary.Bytes.Input+subscript.swift`, lines 11-13
**Code**:
```swift
let offsetInt = offset.rawValue.rawValue
precondition(offsetInt >= 0 && offsetInt < Int(bitPattern: count.rawValue), "offset out of bounds")
return storage[Int(bitPattern: position) + offsetInt]
```

This is a triple violation: `.rawValue.rawValue` extracts through two layers of wrapping, `Int(bitPattern: count.rawValue)` extracts the cardinal's raw value, and `Int(bitPattern: position)` converts the index to Int. Per [IMPL-002] and [PATTERN-017], none of these extractions should appear at this level. The subscript should delegate to typed boundary infrastructure.

### BPAR-002 — `Int(bitPattern:)` at subscript call site [IMPL-010]

Same location as BPAR-001. The `Int(bitPattern:)` conversions should be in boundary overloads on `Array` subscript or a `pointer(at:)` style accessor, not inline in the subscript body.

### BPAR-003 — `Cardinal(UInt(...))` chain for totalCount [IMPL-010]

**File**: `Binary Input Primitives/Binary.Bytes.Input+properties.swift`, line 5
**Code**: `Index<UInt8>.Count(Cardinal(UInt(storage.count)))`

The chain `Cardinal(UInt(storage.count))` converts stdlib's `Int` count through two intermediate types. This is a boundary conversion that should be a single overload: `Index<UInt8>.Count(storage)` or `Index<UInt8>.Count(intCount: storage.count)`.

### BPAR-004 — Raw array indexing via `Int(bitPattern:)` [IMPL-010]

**File**: `Binary Input Primitives/Binary.Bytes.Input+mutation.swift`, line 14
**Code**: `let byte = storage[Int(bitPattern: position)]`

Direct Int conversion of `position` (an `Index<UInt8>`) for stdlib array subscript. This is a boundary point, but it appears in every access method. A `storage.element(at: position)` boundary extension would centralize this.

### BPAR-005 — Module-level typed count constants [IMPL-002]

**File**: `Binary Borrowed Primitives/Binary.Bytes.withBorrowed.swift`, lines 34-38
**Code**:
```swift
let _two: Index<UInt8>.Count = Index<UInt8>.Count(Cardinal(2))
let _four: Index<UInt8>.Count = Index<UInt8>.Count(Cardinal(4))
let _eight: Index<UInt8>.Count = Index<UInt8>.Count(Cardinal(8))
```

These avoid repeated construction, which is good. But the construction chain `Index<UInt8>.Count(Cardinal(N))` reveals a missing integer literal conformance or convenience init on `Index.Count`. The ideal expression would be `.two`, `.four`, `.eight` as named constants on `Index<UInt8>.Count`, or integer literal conformance so `let _two: Index<UInt8>.Count = 2` works.

### BPAR-006 — Repeated `Cardinal(UInt(n))` in interpreter [IMPL-010]

**File**: `Binary.Bytes.withBorrowed.swift`, throughout the interpreter (lines 100, 156, 341, 354, 379, 450, etc.)
**Code**: `let need = Index<UInt8>.Count(Cardinal(UInt(n)))`

This chain appears ~20 times across the two interpreter copies (array and contiguous). Each occurrence converts an `Int` count from the instruction enum into a typed count. This should be a single boundary function: `Index<UInt8>.Count(intCount: n)` or similar.

### BPAR-007 — `withBorrowed` compound property name [API-NAME-002]

**File**: `Binary Borrowed Primitives/Binary.Bytes.withBorrowed.swift`, lines 45-46
**Code**: `public static var withBorrowed: WithBorrowed { WithBorrowed() }`

The property `withBorrowed` and type `WithBorrowed` are compound names. Per [API-NAME-002], this would ideally be nested: `Binary.Bytes.borrow(bytes, parser)` or `Binary.Bytes.parse.borrowed(bytes, parser)`. However, the `with` prefix is a Swift convention for scoped access (`withUnsafe*`), which partially justifies the pattern.

### BPAR-008 — `Int(bitPattern:)` for checkpoint position restore [IMPL-010]

**File**: `Binary.Bytes.withBorrowed.swift`, lines 288, 295, 303, 308 (and duplicated in contiguous variant)
**Code**: `view.position = Int(bitPattern: savedCheckpoint)`

This converts `Index<UInt8>` to `Int` for `Input.View.position` assignment. The root cause is BPAR-017: `Input.View.position` is typed as `Int` rather than `Index<UInt8>`.

### BPAR-009 — Non-shared typed count constants in Machine.Run [IMPL-010]

**File**: `Binary Machine Primitives/Binary.Bytes.Machine.Run.swift`, lines 291-399
**Code**: `Index<UInt8>.Count(Cardinal(2))`, `Index<UInt8>.Count(Cardinal(4))`, `Index<UInt8>.Count(Cardinal(8))`

The `run()` method reconstructs typed count constants inline instead of reusing the `_two`, `_four`, `_eight` constants from `withBorrowed`. These constants should be shared or the construction chain should be eliminated via infrastructure.

### BPAR-010 — `WithBorrowed` compound type name [API-NAME-002]

**File**: `Binary.Bytes.withBorrowed.swift`, line 48
**Code**: `public struct WithBorrowed: Sendable`

The type name `WithBorrowed` is a compound name. If the accessor pattern were restructured (e.g., `Binary.Bytes.Borrow` or a Property-based accessor), this would follow [API-NAME-001].

### BPAR-011 — Compound method names on Coder [API-NAME-002]

**File**: `Binary Coder Primitives/Binary.Coder.swift`, lines 71, 86, 95, 107
**Code**: `decodeWhole`, `decodePrefix`, `encodeToArray`, `encodeAppending`

All four are compound identifiers. The ideal pattern per [API-NAME-002] would be:
- `coder.decode.whole(bytes)` / `coder.decode.prefix(&input)`
- `coder.encode.array(value)` / `coder.encode.appending(value, to: &buffer)`

### BPAR-015, BPAR-016 — Error enums in same file as parent type [API-IMPL-005]

**Files**: `Binary.Parse.Converting.swift` and `Binary.Parse.Validated.swift`

Both files declare their `Error` enum in the same file as the parent struct. Per strict [API-IMPL-005], these should be in `Binary.Parse.Converting.Error.swift` and `Binary.Parse.Validated.Error.swift`. However, Error enums are typically small (3-5 cases) and tightly coupled.

### BPAR-017 — `Input.View.position` typed as `Int` [IMPL-010]

**Root cause finding** (not directly a file-level finding):

`Binary.Bytes.Input.View.position` is stored/accessed as `Int` rather than `Index<UInt8>`. This forces every checkpoint save/restore in the interpreter to go through `Int(bitPattern:)` conversions. If `position` were typed as `Index<UInt8>`, BPAR-008 and BPAR-014 would be eliminated. The design note in the file explains this is a lifetime checker constraint — computed property reads on `Input.View` are forbidden inside the interpreter.

---

## Clean Areas

- **Namespace structure**: All types follow `Binary.X.Y.Z` nesting (`Binary.Bytes.Machine`, `Binary.Parse.Access`, `Binary.Bytes.Input`, etc.). No compound public type names (except noted findings).
- **Typed throws**: All parsing operations use typed throws (`throws(Machine.Fault)`, `throws(Failure)`, `throws(Input.Stream.Error)`).
- **Property.View / parse accessor**: `Binary.Parse.Access` provides the nested accessor pattern (`parser.parse.whole(bytes)`, `parser.parse.prefix(bytes)`).
- **No Foundation**: No Foundation imports anywhere.
- **Typed arithmetic**: The interpreter correctly uses typed operations: `consumed += .one`, `remaining < .one`, `total.subtract.saturating(...)`, `consumed < total`, `.zero..<_eight` range iteration.
- **Machine reuse**: Correctly depends on `Machine_Primitives` rather than reimplementing type erasure. `Binary.Bytes.Machine` provides typealiases to the shared infrastructure.
- **Error types**: `Binary.Bytes.Machine.Fault`, `Binary.Parse.Converting.Error`, `Binary.Parse.Validated.Error` are all typed enums with domain-meaningful cases.
- **Workaround documentation**: The interpreter's design constraints (no computed property reads on `Input.View`, inlined interpreter) are thoroughly documented with rationale.
