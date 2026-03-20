# Remaining Packages Batch Audit

**Date**: 2026-03-20
**Rules**: [API-NAME-001] Nest.Name, [API-NAME-002] No compound methods/properties, [IMPL-002]/[PATTERN-017] No .rawValue at call sites, [API-IMPL-005] One type per file
**Scope**: 41 packages, READ-ONLY

## Summary Table

| # | Package | Status | Findings |
|---|---------|--------|----------|
| 1 | swift-clock-primitives | **2 findings** | [API-IMPL-005] Clock.Any.swift, Clock.Test.swift multi-type |
| 2 | swift-coder-primitives | CLEAN | |
| 3 | swift-continuation-primitives | STUB | No Sources directory |
| 4 | swift-decimal-primitives | **3 findings** | [API-NAME-002] extractExponent/extractCoefficient/coefficientMax; [API-IMPL-005] Decimal.Exponent.swift |
| 5 | swift-dependency-primitives | CLEAN | |
| 6 | swift-diagnostic-primitives | CLEAN | |
| 7 | swift-endian-primitives | STUB | No Sources directory |
| 8 | swift-error-primitives | CLEAN | |
| 9 | swift-handle-primitives | **2 findings** | [API-NAME-002] freeAll; [API-IMPL-005] acceptable nesting |
| 10 | swift-infinite-primitives | **1 finding** | [API-IMPL-005] Iterator nested in parent files (Cycle, Map, Zip, Scan) |
| 11 | swift-lexer-primitives | CLEAN | |
| 12 | swift-lifetime-primitives | CLEAN | |
| 13 | swift-locale-primitives | CLEAN | Placeholder/TODO, not a naming issue |
| 14 | swift-module-primitives | CLEAN | |
| 15 | swift-outcome-primitives | STUB | No Sources directory |
| 16 | swift-path-primitives | **2 findings** | [API-IMPL-005] Path.swift, Path.String.swift multi-type |
| 17 | swift-positioning-primitives | **2 findings** | [API-NAME-002] spaceBetween/spaceAround/spaceEvenly; [API-IMPL-005] Distribution + Space in same file |
| 18 | swift-predicate-primitives | **1 finding** | [API-NAME-002] forAll/forAny/forNone/atLeast/atMost |
| 19 | swift-random-primitives | CLEAN | |
| 20 | swift-range-primitives | CLEAN | |
| 21 | swift-reference-primitives | **1 finding** | [API-IMPL-005] Reference.Unowned.swift (4 type declarations) |
| 22 | swift-token-primitives | CLEAN | |
| 23 | swift-type-primitives | CLEAN | Empty source file |
| 24 | swift-bit-index-primitives | CLEAN | |
| 25 | swift-bit-pack-primitives | CLEAN | |
| 26 | swift-ascii-parser-primitives | CLEAN | |
| 27 | swift-ascii-serializer-primitives | CLEAN | |
| 28 | swift-symbol-primitives | STUB | Empty source file |
| 29 | swift-syntax-primitives | STUB | Empty source file |
| 30 | swift-intermediate-representation-primitives | STUB | Empty source file |
| 31 | swift-driver-primitives | STUB | Empty source file |
| 32 | swift-backend-primitives | STUB | Empty source file |
| 33 | swift-abstract-syntax-tree-primitives | STUB | Empty source file |
| 34 | swift-abi-primitives | STUB | No Sources directory |
| 35 | swift-network-primitives | STUB | No Sources directory |
| 36 | swift-riscv-primitives | STUB | No Sources directory |
| 37 | swift-scalar-primitives | STUB | No Sources directory |
| 38 | swift-slice-primitives | STUB | No Sources directory |
| 39 | swift-space-primitives | STUB | Sources directory exists but empty |
| 40 | swift-state-primitives | STUB | No Sources directory |
| 41 | swift-transform-primitives | STUB | No Sources directory |

**Totals**: 14 STUB, 16 CLEAN, 11 with findings (across 7 packages with substantive code)

---

## Per-Package Details

### 1. swift-clock-primitives (13 files)

**[API-IMPL-005] Clock.Any.swift** -- Contains both `Clock.Any<D>` (outer struct) and `Clock.Any.Instant` (nested struct) plus private `ConcreteBox` class at module level. The `Instant` nesting inside `Any` is acceptable (semantic child), but `ConcreteBox` is a separate private type in the same file. LOW -- private implementation detail.

**[API-IMPL-005] Clock.Test.swift** -- Contains `Clock.Test` (class), `Clock.Test.Suspension` (enum namespace), and `Clock.Test.Suspension.Error` (struct). The `Suspension` namespace + `Error` are semantically part of `Test`. LOW -- namespace + leaf error.

**[IMPL-002] rawValue usage** -- 13 occurrences. All are within boundary code: `Tagged+InstantProtocol.swift` (forwarding rawValue through Tagged), `Clock.Nanoseconds.swift` and `Clock.Offset.swift` (internal storage types). These are the Tagged boundary layer itself -- rawValue here IS the boundary code. ACCEPTABLE per [PATTERN-017].

**Naming**: All types follow Nest.Name (`Clock.Any`, `Clock.Continuous`, `Clock.Suspending`, `Clock.Test`, `Clock.Immediate`, `Clock.Unimplemented`, `Clock.Nanoseconds`, `Clock.Offset`). No compound type names.

### 2. swift-coder-primitives (3 files)

CLEAN.

Files: `Coder.swift` (namespace enum), `Coder.Protocol.swift` (protocol), `Codable.swift` (protocol + extensions). All follow Nest.Name. No rawValue leakage. No compound names.

### 3. swift-continuation-primitives

STUB -- no Sources directory.

### 4. swift-decimal-primitives (18 files)

**[API-NAME-002] Compound method names**:
- `extractExponent()` on Format32/64/128 -- could be computed property `exponent` or `extract.exponent()`
- `extractCoefficient()` on Format32/64/128 -- could be computed property `coefficient` or `extract.coefficient()`
- `coefficientMax()` static on Format32/64/128 -- could be static property `coefficient.max`

All three are public API on all three Format types (9 instances total).

**[API-IMPL-005] Decimal.Exponent.swift** -- Contains `Decimal.Exponent` (struct) plus three nested namespace enums: `Exponent.Format32`, `Exponent.Format64`, `Exponent.Format128`. These are format-limit namespaces. LOW -- static constant namespaces within the owning type's file.

**[IMPL-002] rawValue usage** -- 19 occurrences. All within `Decimal.Exponent` and `Decimal.Precision` boundary implementations (operator overloads, init, Int conversion). These types ARE the raw-value wrappers -- their arithmetic operators necessarily touch `.rawValue`. ACCEPTABLE per [PATTERN-017].

**Naming**: All types follow Nest.Name (`Decimal.Format32`, `Decimal.Format64`, `Decimal.Format128`, `Decimal.Class`, `Decimal.Compare`, `Decimal.Exponent`, `Decimal.Layout`, `Decimal.NaN`, `Decimal.Order`, `Decimal.Payload`, `Decimal.Precision`, `Decimal.Sign`, `Decimal.Test`). No compound type names.

### 5. swift-dependency-primitives (5 files)

CLEAN.

Note: `__DependencyKey` top-level typealias exists as documented workaround for Swift macro limitation. Naming deviation is justified and documented.

### 6. swift-diagnostic-primitives (3 files)

CLEAN.

`Diagnostic.Severity` rawValue comparison (`lhs.rawValue < rhs.rawValue`) is in the `Comparable` conformance -- this is boundary code for a RawRepresentable enum. ACCEPTABLE.

### 7. swift-endian-primitives

STUB -- no Sources directory.

### 8. swift-error-primitives (3 files)

CLEAN.

Types: `Error` (namespace), `Error.Code` (enum with posix/win32), `Error.Context` (diagnostic struct). All Nest.Name.

### 9. swift-handle-primitives (6 files)

**[API-NAME-002] Compound method name** on `Generation.Tracker`:
- `freeAll()` -- compound. Could be `free.all()` per [API-NAME-002].

Note: `isValid(_:)` and `isOccupied(at:)` follow Swift API guidelines for Bool-returning predicates. ACCEPTABLE.

**[API-IMPL-005]** All files contain one primary type. `Handle.Index.swift` contains `__HandleIndex<Phantom>` typealias (single declaration). Clean.

**[IMPL-002]** No rawValue leakage. Handle accesses go through typed accessors (`.index`, `.generation`).

### 10. swift-infinite-primitives (12 files)

**[API-IMPL-005] Iterator types nested in parent files**:
- `Infinite.Cycle.swift` contains `Cycle` + `Cycle.Iterator`
- `Infinite.Map.swift` contains `Map` + `Map.Iterator`
- `Infinite.Zip.swift` contains `Zip` + `Zip.Iterator`
- `Infinite.Scan.swift` contains `Scan` + `Scan.Iterator`

These are `~Copyable` iterators tightly coupled to their parent types. Splitting would create 4 additional files. LOW -- semantically one unit.

`__InfiniteObservableIterator` in `Infinite.Observable.Iterator.swift` is a module-level type with `__` prefix (protocol nesting workaround). Documented.

**Naming**: All types follow Nest.Name. No compound method names (`makeIterator` is Swift protocol requirement).

### 11. swift-lexer-primitives (7 files)

CLEAN.

Types: `Lexer` (namespace), `Lexer.Classify` (classification predicates), `Lexer.Error` (enum), `Lexer.Lexeme` (struct), `Lexer.Trivia` (enum). All Nest.Name.

`Lexer.Classify` methods (`isIdentifierStart`, `isIdentifierContinuation`, `isOperatorStart`, etc.) are camelCase but these are classification predicates -- the `is` prefix is Swift API convention. The compound names here mirror the grammar terminology (identifierStart, operatorContinuation). ACCEPTABLE.

### 12. swift-lifetime-primitives (4 files)

CLEAN.

Types: `Lifetime` (namespace), `Lifetime.Disposable` (protocol), `Lifetime.Lease<Value>` (struct), `Lifetime.Scoped<Value>` (struct). All Nest.Name.

`__LifetimeDisposable` is a documented protocol nesting workaround.

### 13. swift-locale-primitives (1 file)

CLEAN.

`Locale` (top-level struct). Placeholder with TODO. No naming issues.

### 14. swift-module-primitives (5 files)

CLEAN.

Types: `Module` (namespace), `Module.Import` (struct), `Module.Import.Visibility` (enum), `Module.Name` (struct). All Nest.Name.

### 15. swift-outcome-primitives

STUB -- no Sources directory.

### 16. swift-path-primitives (7 files)

**[API-IMPL-005] Path.swift** -- Contains `Path` (struct) and `Path.ConversionError` (enum). The error type could be in its own file.

**[API-IMPL-005] Path.String.swift** -- Contains 6 type declarations: `Path.String` (enum namespace), `Path.String.Conversion` (enum namespace), `Path.String.Conversion.Error` (enum), `Path.String.Error<Body>` (generic error), `Path.String.Scope` (struct), `Path.String.Array` (struct). This file is substantially oversized for the one-type-per-file rule.

**Naming**: Types follow Nest.Name (`Path.String`, `Path.Canonical`, `Path.Resolution`, `Path.Resolution.Error`, `Path.View`). `callAsFunction` methods are Swift protocol convention.

### 17. swift-positioning-primitives (1 file)

**[API-NAME-002] Compound static properties**:
- `.spaceBetween` -- should be `.space.between` or just use `.space(.between)` directly
- `.spaceAround` -- should be `.space.around` or just use `.space(.around)` directly
- `.spaceEvenly` -- should be `.space.evenly` or just use `.space(.evenly)` directly

These are convenience shorthands for `.space(.between)` etc. The compound names violate [API-NAME-002].

**[API-IMPL-005]** `Distribution.swift` contains `Distribution` (enum) and `Distribution.Space` (enum). LOW -- `Space` is a semantic child.

### 18. swift-predicate-primitives (13 files)

**[API-NAME-002] Compound method names** on `Predicate`:
- `forAll()` / `forAny()` / `forNone()` -- quantifier lifting methods. Could be `quantify.all()` / `quantify.any()` / `quantify.none()` or a `.for.all()` pattern.
- `atLeast(_:)` / `atMost(_:)` on `Predicate.Count` -- count bound methods. Could be `.at.least(_:)` / `.at.most(_:)`.

These are the primary API for predicate composition. 5 compound method names.

**Naming**: Type names all follow Nest.Name (`Predicate`, `Predicate.Contains`, `Predicate.Count`, `Predicate.Equal`, `Predicate.Greater`, `Predicate.Has`, `Predicate.In`, `Predicate.Is`, `Predicate.Less`, `Predicate.Matches`, `Predicate.Not`).

### 19. swift-random-primitives (3 files)

CLEAN.

Types: `Random` (namespace), `Random.Error` (enum), `Random.Generator` (struct). All Nest.Name.

### 20. swift-range-primitives (2 files)

CLEAN.

`Range.swift` in Core module + `exports.swift` in umbrella module.

### 21. swift-reference-primitives (6 files)

**[API-IMPL-005] Reference.Unowned.swift** -- Contains 4 type declarations: `Reference.Unowned<Object>` (struct), `Reference.Unowned.Sendable` (enum namespace -- note: shadows `Swift.Sendable`), `Reference.Unowned.Sendable.Checked` (struct), `Reference.Unowned.Sendable.Unchecked` (struct).

This is a deep namespace hierarchy in one file. The `Checked`/`Unchecked` variants warrant separate files per [API-IMPL-005]:
- `Reference.Unowned.swift` -> `Reference.Unowned`
- `Reference.Unowned.Sendable.swift` -> `Reference.Unowned.Sendable` namespace
- `Reference.Unowned.Sendable.Checked.swift` -> `Reference.Unowned.Sendable.Checked`
- `Reference.Unowned.Sendable.Unchecked.swift` -> `Reference.Unowned.Sendable.Unchecked`

### 22. swift-token-primitives (6 files)

CLEAN.

`Token.Keyword` rawValue comparison in `Comparable` conformance is boundary code. ACCEPTABLE.

Types: `Token` (namespace), `Token.Kind` (enum), `Token.Kind+Classification` (extension), `Token.Keyword` (enum), `Token.Keyword+Classification` (extension). All Nest.Name.

### 23. swift-type-primitives (1 file)

CLEAN.

`Type Primitives.swift` is an empty file (module placeholder).

### 24. swift-bit-index-primitives (4 files)

CLEAN.

Types: `Bit.Index` (typealias), `Bit.Index+Byte` (extension), `Bit+Affine.Discrete.Ratio` (extension). All Nest.Name. Uses typed arithmetic throughout -- no rawValue leakage.

### 25. swift-bit-pack-primitives (6 files)

CLEAN.

Types: `Bit.Pack<Word>` (struct), `Bit.Pack.Bits` (struct), `Bit.Pack.Location` (struct), `Bit.Pack.Words` (struct), `Bit.Index+Pack` (extension). All Nest.Name. Each type in its own file.

### 26. swift-ascii-parser-primitives (10 files, 4 modules)

CLEAN.

Types across modules: `ASCII.Parser` (namespace), `ASCII.Decimal.Parser` (struct), `ASCII.Decimal.Error` (enum), `ASCII.Hexadecimal.Parser` (struct), `ASCII.Hexadecimal.Error` (enum). All Nest.Name. One type per file. Typed throws throughout.

### 27. swift-ascii-serializer-primitives (8 files, 4 modules)

CLEAN.

Mirror structure of parser-primitives. Types: `ASCII.Serializer` (namespace), `ASCII.Decimal.Serializer` (struct), `ASCII.Hexadecimal.Serializer` (struct). All Nest.Name. One type per file.

### 28-33. Compiler pipeline stubs

All STUB -- empty source files (module placeholders):
- **swift-symbol-primitives**: `Symbol Primitives.swift` (empty)
- **swift-syntax-primitives**: `Syntax Primitives.swift` (empty)
- **swift-intermediate-representation-primitives**: `Intermediate Representation Primitives.swift` (empty)
- **swift-driver-primitives**: `Driver Primitives.swift` (empty)
- **swift-backend-primitives**: `Backend Primitives.swift` (empty)
- **swift-abstract-syntax-tree-primitives**: `Abstract Syntax Tree Primitives.swift` (empty)

### 34-41. Empty stubs (no Sources directory)

All STUB -- no Sources directory at all:
- **swift-abi-primitives**
- **swift-network-primitives**
- **swift-riscv-primitives**
- **swift-scalar-primitives**
- **swift-slice-primitives**
- **swift-state-primitives**
- **swift-transform-primitives**

One exception: **swift-space-primitives** has a Sources/Space Primitives/ directory but it is empty.

---

## Cross-Cutting Observations

### .rawValue Usage Summary

All rawValue usage across the 41 packages falls into two categories, both ACCEPTABLE per [PATTERN-017]:
1. **Tagged boundary code** (clock-primitives): `Tagged+InstantProtocol.swift` forwarding through Tagged's rawValue
2. **Value wrapper internals** (decimal-primitives): `Exponent` and `Precision` arithmetic operators on their own rawValue storage
3. **RawRepresentable conformances** (diagnostic-primitives, token-primitives): `Comparable` implementation on `rawValue: Int` enums

No consumer-facing rawValue leakage found.

### [API-NAME-002] Compound Name Pattern

Three categories of compound names found:

1. **Verb+Noun methods** (MEDIUM priority): `extractExponent()`, `extractCoefficient()`, `coefficientMax()` in decimal-primitives. These could be computed properties or nested accessors.

2. **Predicate quantifiers** (LOW priority): `forAll()`, `forAny()`, `forNone()`, `atLeast()`, `atMost()` in predicate-primitives. Standard logical terminology.

3. **Convenience shorthands** (LOW priority): `spaceBetween`, `spaceAround`, `spaceEvenly` in positioning-primitives. These duplicate the nested `.space(.between)` API.

### [API-IMPL-005] One Type Per File

Most violations are nested types (Iterator inside parent, namespace enums, error types). The only substantive violations are:
- **Path.String.swift** with 6 type declarations -- should be split
- **Reference.Unowned.swift** with 4 type declarations -- should be split

### Stub Packages

15 of 41 packages are stubs (no source code). Of these, 8 have no Sources directory at all, 6 have empty placeholder files, and 1 (swift-space-primitives) has an empty Sources subdirectory.
