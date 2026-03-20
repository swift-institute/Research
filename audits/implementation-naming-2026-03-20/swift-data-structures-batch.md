# Implementation & Naming Audit — Data Structures Batch

**Date**: 2026-03-20
**Scope**: 11 packages under `/Users/coen/Developer/swift-primitives/`
**Skills**: [API-NAME-001], [API-NAME-002], [IMPL-002], [IMPL-010], [IMPL-020], [PATTERN-017], [API-IMPL-005]
**Status**: READ-ONLY audit, no modifications made

## Combined Summary

| Package | Files | Findings | Critical | Medium | Low |
|---------|-------|----------|----------|--------|-----|
| swift-terminal-primitives | 32 | 3 | 0 | 1 | 2 |
| swift-complex-primitives | 28 | 2 | 0 | 1 | 1 |
| swift-numeric-primitives | 28 | 0 | 0 | 0 | 0 |
| swift-bit-primitives | 28 | 2 | 0 | 1 | 1 |
| swift-parser-machine-primitives | 28 | 2 | 0 | 1 | 1 |
| swift-stack-primitives | 19 | 0 | 0 | 0 | 0 |
| swift-slab-primitives | 11 | 0 | 0 | 0 | 0 |
| swift-list-primitives | 12 | 0 | 0 | 0 | 0 |
| swift-bitset-primitives | 22 | 2 | 0 | 1 | 1 |
| swift-layout-primitives | 14 | 5 | 0 | 2 | 3 |
| swift-rendering-primitives | 37 | 2 | 0 | 1 | 1 |
| **Total** | **259** | **18** | **0** | **8** | **10** |

---

## 1. swift-terminal-primitives (32 files)

### [TERM-001] [API-NAME-002] Compound enum cases in Terminal.Input.Mouse.Kind — LOW

**File**: `Sources/Terminal Input Primitives/Terminal.Input.Mouse.Kind.swift`, lines 28-37
**Finding**: Enum cases `scrollUp`, `scrollDown`, `scrollLeft`, `scrollRight` are compound identifiers. Under strict [API-NAME-002], these should use a nested accessor pattern (e.g., `scroll.up`).
**Mitigation**: These mirror terminal specification terminology (SGR mouse encoding). Enum cases are not methods/properties, so [API-NAME-002] applies weakly. The compound form is defensible as specification-mirroring.

### [TERM-002] [API-NAME-002] Compound enum cases in Terminal.Error.Operation — MEDIUM

**File**: `Sources/Terminal Primitives/Terminal.Error.swift`, lines 37-46
**Finding**: Cases `querySize`, `enterRaw`, `exitRaw`, `enableVT` are compound identifiers. Under [API-NAME-002], these should be nested (e.g., `.query.size`, `.enter.raw`). However, error operation enums are commonly flat.
**Mitigation**: Could restructure as nested enums (e.g., `Operation.query` namespace with `.size` case), but the current form is readable and the error type is small.

### [TERM-003] [API-NAME-002] Compound enum cases in Terminal.Input.Key.Code — LOW

**File**: `Sources/Terminal Input Primitives/Terminal.Input.Key.Code.swift`, lines 40-41
**Finding**: Cases `pageUp`, `pageDown` are compound identifiers. Under strict [API-NAME-002], these should use nested form (e.g., `page.up`, `page.down`).
**Mitigation**: These are universally recognized key names in terminal specification terminology. Splitting would reduce clarity.

---

## 2. swift-complex-primitives (28 files)

### [CMPLX-001] [PATTERN-017] .rawValue in non-boundary domain logic — MEDIUM

**File**: `Sources/Complex Primitives/Complex+Polar.swift`, lines 90-91
**Finding**: The `init(length:phase:)` initializer accesses `length.rawValue` and `phase.rawValue` directly to extract the underlying scalar for trigonometric computation. Under [PATTERN-017], `.rawValue` should be confined to boundary code (type conversions, serialization), not used in domain logic.
**Resolution**: `Modulus.Value` and `Radian` should provide typed accessor methods or unwrapping APIs that avoid exposing `.rawValue` at the call site. Alternatively, the trigonometric functions should accept the tagged type directly.

Note: The `.rawValue` usages in `Complex.Modulus.swift` (lines 37-56) are compliant — they are boundary overloads implementing arithmetic operators on `Tagged`, which is the correct pattern.

### [CMPLX-002] [API-IMPL-005] Namespace + typealias in same file — LOW

**File**: `Sources/Complex Primitives/Complex.Modulus.swift`
**Finding**: File contains `Complex.Number.Modulus` (enum namespace) and the `Complex.Number.Modulus.Value` typealias. Under strict [API-IMPL-005], each type should be in its own file. The typealias is a single-line projection of `Tagged`, so this is borderline.

---

## 3. swift-numeric-primitives (28 files)

**No findings.** Clean implementation. Accessor pattern (`value.shifted`, `value.rotation`, `value.saturating`) follows [API-NAME-002]. One-type-per-file respected. No `.rawValue` usage. No `Int(bitPattern:)`.

---

## 4. swift-bit-primitives (28 files)

### [BIT-001] [PATTERN-017] .rawValue in Bit+Finite.Enumerable — MEDIUM

**File**: `Sources/Bit Primitives/Bit+Finite.Enumerable.swift`, line 25
**Finding**: `self = Self(rawValue: UInt8(truncatingIfNeeded: ordinal.rawValue))!` — accesses `ordinal.rawValue` to construct a Bit from an ordinal. The `ordinal` is an `Index`-typed value; extracting `.rawValue` here is non-boundary usage in domain logic. Should use a typed conversion instead.

Note: The `.rawValue` usages in `Bitwise Operators.swift` (lines 12-30), `Bit+Comparable.swift` (line 9), and `Bit+Normalizing.swift` (line 19) are compliant — they are boundary overloads implementing operators and protocol conformances on `RawRepresentable`, which is the correct pattern. The `Int(bitPattern:)` in `FixedWidthInteger+Cardinal.swift` (lines 22, 33) is also compliant — it appears in boundary shift operator overloads.

### [BIT-002] [API-IMPL-005] File naming inconsistency — LOW

**File**: `Sources/Bit Boolean Primitives/Bitwise Operators.swift`
**Finding**: File is named `Bitwise Operators.swift` but the header comment says `File.swift` (Xcode default). The file name does not follow the `Type.Extension.swift` pattern used elsewhere (e.g., `Bit Boolean Operations.swift`). Should be `Bit+Bitwise.swift` or similar.

---

## 5. swift-parser-machine-primitives (28 files)

### [PMACH-001] [PATTERN-017] .rawValue in memoization runtime — MEDIUM

**File**: `Sources/Parser Machine Memoization Primitives/Parser.Machine.Run.Memoization.swift`, lines 195, 226
**Finding**: `current.rawValue` used twice — once to construct a `MemoKey` and once for frame metadata. The `current` is a `Node.ID` (typed identifier). Accessing `.rawValue` in the memoization runtime is non-boundary domain logic. Should use the typed identifier directly or provide a hash-compatible accessor on `Node.ID`.

### [PMACH-002] [API-IMPL-005] Multiple types in Parser.Machine.Compiled.swift — LOW

**File**: `Sources/Parser Machine Compile Primitives/Parser.Machine.Compiled.swift`
**Finding**: File contains `Parser.Machine.Compiled<P>`, `Parser.Machine.Compiled.Result`, and `Parser.Machine.Compiled.Cache`. Under [API-IMPL-005], each type should have its own file. `Result` and `Cache` are closely coupled `@usableFromInline` internal types, but the rule is unconditional. Should split to `Parser.Machine.Compiled.Result.swift` and `Parser.Machine.Compiled.Cache.swift`.

---

## 6. swift-stack-primitives (19 files)

**No findings.** Clean implementation. Uses Property.View pattern for drain. Nested types (`Stack.Static`, `Stack.Small`, `Stack.Bounded`) follow PATTERN-022 (declared in same file as parent). No `.rawValue` usage. No compound identifiers.

---

## 7. swift-slab-primitives (11 files)

**No findings.** Clean implementation. Uses Property.View pattern for drain. Typed `Index<Element>` / `Index<Tag>` throughout with `.retag()` for cross-domain conversion. No `.rawValue` at call sites. One-type-per-file respected (nested types in `Slab.swift` per PATTERN-022).

---

## 8. swift-list-primitives (12 files)

**No findings.** Clean implementation. Nested accessor pattern (`_buffer.insert.front()`, `_buffer.remove.back()`) exemplifies [API-NAME-002] compliance. No `.rawValue` usage. One-type-per-file respected.

---

## 9. swift-bitset-primitives (22 files)

### [BSET-001] [API-IMPL-005] Bitset.Algebra.Symmetric storage duplication — MEDIUM

**File**: `Sources/Bitset Primitives/Bitset.Algebra.Symmetric.swift`
**Finding**: `Bitset.Algebra.Symmetric` has its own `storage: ContiguousArray<UInt>`, `capacity: Int`, and `wordCount: Int` stored properties that duplicate `Bitset`'s internal state. Same pattern repeats across `Bitset.Fixed.Algebra.Symmetric`, `Bitset.Static.Algebra.Symmetric`, `Bitset.Small.Algebra.Symmetric`. The algebra namespace types are constructed by copying storage from the parent. This creates maintenance coupling — any change to Bitset's storage representation must be mirrored across all algebra types.

### [BSET-002] [PATTERN-017] Double-underscore internal error types — LOW

**Files**: `Bitset.swift` line 44 (`__BitsetError`), `Bitset.Small.swift` line 155 (`__BitsetSmallError`)
**Finding**: Error types use double-underscore prefix convention. While these are not public API, the standard pattern is `Bitset.Error` nested under the type. The current files `Bitset.Error.swift` and `Bitset.Small.Error.swift` exist but contain the `__BitsetError` / `__BitsetSmallError` types rather than properly nested `Bitset.Error`.

---

## 10. swift-layout-primitives (14 files)

### [LAY-001] [API-NAME-002] Compound static let names in Alignment — LOW

**File**: `Sources/Layout Primitives/Alignment.swift`, lines 41-65
**Finding**: Static presets `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing` are compound identifiers. Under strict [API-NAME-002], these would be `top.leading`, `top.trailing`, etc.
**Mitigation**: These follow SwiftUI naming conventions (`Alignment.topLeading`). The compound form is the de facto standard for 2D alignment presets. Applying [API-NAME-002] strictly would deviate from industry convention.

### [LAY-002] [API-NAME-002] Compound static let names in Corner — LOW

**File**: `Sources/Layout Primitives/Corner.swift`, lines 128-137
**Finding**: Same pattern as LAY-001 — `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`. Same mitigation applies.

### [LAY-003] [API-NAME-002] Compound enum cases in Direction — MEDIUM

**File**: `Sources/Layout Primitives/Direction.swift`, lines 22, 25
**Finding**: Enum cases `leftToRight` and `rightToLeft` are compound identifiers. Under [API-NAME-002], these should use a nested pattern. The type provides `.ltr` and `.rtl` shorthand aliases (lines 32, 35), which partially mitigate.
**Resolution**: Consider making `.ltr` / `.rtl` the primary cases and deprecating the compound forms.

### [LAY-004] [API-NAME-002] Compound enum cases in Layout.Grid.Lazy.Columns — LOW

**File**: `Sources/Layout Primitives/Layout.Grid.Lazy.swift`, lines 88, 94
**Finding**: Cases `autoFill(minWidth:)` and `autoFit(minWidth:)` are compound identifiers. These mirror CSS grid terminology exactly (`auto-fill`, `auto-fit`).

### [LAY-005] [API-IMPL-005] Multiple types in Corner.swift — MEDIUM

**File**: `Sources/Layout Primitives/Corner.swift`
**Finding**: File contains `Corner` (struct, line 23), `Horizontal.Alignment.Side` (enum, line 44), `Vertical.Alignment.Side` (enum, line 88), and a `Region.Corner` init extension (line 247). Under [API-IMPL-005], `Horizontal.Alignment.Side` and `Vertical.Alignment.Side` should each be in their own files (`Horizontal.Alignment.Side.swift`, `Vertical.Alignment.Side.swift`). The `Region.Corner` init extension should also be in a separate file.

---

## 11. swift-rendering-primitives (37 files)

### [REND-001] [API-IMPL-005] Multiple nested types in Rendering.Style.swift — MEDIUM

**File**: `Sources/Rendering Primitives Core/Rendering.Style.swift`
**Finding**: File contains `Rendering.Style` (struct), `Rendering.Style.Font` (struct, line 8), `Rendering.Style.Font.Weight` (enum, line 12), and `Rendering.Style.Color` (enum, line 20). Under [API-IMPL-005], each should be in its own file: `Rendering.Style.Font.swift`, `Rendering.Style.Font.Weight.swift`, `Rendering.Style.Color.swift`.

### [REND-002] [API-IMPL-005] Large single-type file — LOW

**File**: `Sources/Rendering Primitives Core/Rendering.Context.swift` (216 lines)
**Finding**: While technically a single type (`Rendering.Context`), the file contains the full iterative rendering engine, interpret loop, and stack management. Could benefit from splitting rendering engine logic into `Rendering.Context+Rendering.swift` and interpret logic into `Rendering.Context+Interpret.swift` for maintainability.

---

## Cross-Package Observations

### Clean Packages (no findings)

The following packages demonstrate exemplary compliance:
- **swift-numeric-primitives**: Nested accessor pattern (`value.shifted`, `value.rotation`, `value.saturating`) is textbook [API-NAME-002].
- **swift-stack-primitives**: Property.View pattern for drain. Clean file decomposition.
- **swift-slab-primitives**: Typed `Index<Element>` throughout. No `.rawValue` leakage.
- **swift-list-primitives**: Nested accessor pattern (`_buffer.insert.front()`) is excellent.

### Recurring Patterns

1. **Compound enum cases** (9 findings across 4 packages): Most are specification-mirroring (`scrollUp`, `pageDown`, `leftToRight`, `autoFill`). [API-NAME-002] says "methods and properties MUST NOT use compound names" but does not explicitly address enum cases. Consider clarifying the rule's scope.

2. **`.rawValue` in boundary vs. domain code** (initially many flagged, most rescinded): Operator overloads on `Tagged`/`RawRepresentable`, protocol conformances, and type conversion functions are legitimate boundary code under [PATTERN-017]. The three genuine violations are in `Complex+Polar.swift` (polar conversion math), `Bit+Finite.Enumerable.swift` (ordinal construction), and `Parser.Machine.Run.Memoization.swift` (runtime logic).

3. **One-type-per-file** (4 findings): Violations involve small auxiliary types (`Style.Font`, `Style.Color`, `Alignment.Side`) co-located with their parent. PATTERN-022 allows nested type declarations in the same file as the parent, but [API-IMPL-005] is unconditional. The tension between these two rules should be resolved.
