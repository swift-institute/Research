# Small Packages Audit: Implementation & Naming
**Date:** 2026-03-20
**Scope:** 30 packages, [API-NAME-001], [API-NAME-002], [IMPL-002]/[PATTERN-017], [API-IMPL-005]
**Mode:** READ-ONLY

## Summary

| # | Package | Files | Verdict | Findings |
|---|---------|-------|---------|----------|
| 1 | swift-algebra-primitives | 15 | CLEAN | 0 |
| 2 | swift-algebra-modular-primitives | 20 | FINDING | 3 |
| 3 | swift-algebra-module-primitives | 6 | CLEAN | 0 |
| 4 | swift-algebra-affine-primitives | 2 | CLEAN | 0 |
| 5 | swift-algebra-cardinal-primitives | 2 | CLEAN | 0 |
| 6 | swift-algebra-field-primitives | 7 | CLEAN | 0 |
| 7 | swift-algebra-group-primitives | 8 | CLEAN | 0 |
| 8 | swift-algebra-law-primitives | 12 | CLEAN | 0 |
| 9 | swift-algebra-magma-primitives | 4 | CLEAN | 0 |
| 10 | swift-algebra-monoid-primitives | 5 | CLEAN | 0 |
| 11 | swift-algebra-ring-primitives | 7 | CLEAN | 0 |
| 12 | swift-algebra-semiring-primitives | 7 | CLEAN | 0 |
| 13 | swift-affine-geometry-primitives | 8 | CLEAN | 0 |
| 14 | swift-cyclic-index-primitives | 3 | CLEAN | 0 |
| 15 | swift-property-primitives | 12 | CLEAN | 0 |
| 16 | swift-ownership-primitives | 16 | CLEAN | 0 |
| 17 | swift-identity-primitives | 4 | CLEAN | 0 |
| 18 | swift-string-primitives | 6 | CLEAN | 0 |
| 19 | swift-text-primitives | 11 | FINDING | 4 |
| 20 | swift-source-primitives | 8 | FINDING | 3 |
| 21 | swift-logic-primitives | 8 | CLEAN | 0 |
| 22 | swift-optic-primitives | 9 | CLEAN | 0 |
| 23 | swift-symmetry-primitives | 9 | FINDING | 4 |
| 24 | swift-effect-primitives | 10 | FINDING | 3 |
| 25 | swift-serializer-primitives | 16 | CLEAN | 0 |
| 26 | swift-x86-primitives | 15 | FINDING | 6 |
| 27 | swift-arm-primitives | 13 | FINDING | 3 |
| 28 | swift-cpu-primitives | 17 | FINDING | 3 |
| 29 | swift-system-primitives | 10 | CLEAN | 0 |
| 30 | swift-loader-primitives | 9 | CLEAN | 0 |

**Total findings: 29** (8 packages with findings, 22 clean)

---

## 1. swift-algebra-primitives (15 files)

CLEAN -- no findings.

All types use `Algebra` namespace or are top-level algebraic types (Bound, Boundary, Either, Endpoint, Gradient, Monotonicity, Pair, Parity, Polarity, Product, Sign, Ternary). File-per-type structure is correct. No `.rawValue` at call sites.

---

## 2. swift-algebra-modular-primitives (20 files)

### IMPL-002 / PATTERN-017: .rawValue at call sites (3 findings)

**F2.1** `Algebra.Z+Arithmetic.swift:59` -- `.rawValue.rawValue` chain at multiplication call site:
```swift
let (product, overflow) = lhs.rawValue.rawValue.multipliedReportingOverflow(by: rhs.rawValue.rawValue)
```
This is boundary code (implementing modular multiplication), but the double `.rawValue.rawValue` unwrapping is a signal that an operation is missing on the inner type. The outer `.rawValue` unwraps `Tagged`, the inner unwraps `Ordinal`. Consider a `.multipliedReportingOverflow(by:)` on `Ordinal` or a tagged-aware multiplication.

**F2.2** `Algebra.Z+Arithmetic.swift:61` -- `.rawValue` at result construction:
```swift
return Self(__unchecked: (), Ordinal(product % Tag.capacity.rawValue))
```
`Tag.capacity.rawValue` escapes the Cardinal wrapper. The modulo should be expressible through Cardinal's API.

**F2.3** `Algebra.Z+Primality.swift:10,29,30` -- `.rawValue` for `Int(bitPattern:)` conversions throughout `isPrime` and `inverse`. These are algorithmic internals doing integer math; this is defensible boundary code, but the pattern repeats across 3 functions (6 occurrences total).

---

## 3. swift-algebra-module-primitives (6 files)

CLEAN -- no findings.

Proper `Algebra.Module` and `Algebra.VectorSpace` nesting. One type per file.

---

## 4. swift-algebra-affine-primitives (2 files)

CLEAN -- no findings.

---

## 5. swift-algebra-cardinal-primitives (2 files)

CLEAN -- no findings.

---

## 6. swift-algebra-field-primitives (7 files)

CLEAN -- no findings.

All types nested under `Algebra.Field`. File naming matches type structure.

---

## 7. swift-algebra-group-primitives (8 files)

CLEAN -- no findings.

---

## 8. swift-algebra-law-primitives (12 files)

CLEAN -- no findings.

All law types nested under `Algebra.Law`. Clean Nest.Name pattern throughout.

---

## 9. swift-algebra-magma-primitives (4 files)

CLEAN -- no findings.

---

## 10. swift-algebra-monoid-primitives (5 files)

CLEAN -- no findings.

---

## 11. swift-algebra-ring-primitives (7 files)

CLEAN -- no findings.

---

## 12. swift-algebra-semiring-primitives (7 files)

CLEAN -- no findings.

---

## 13. swift-affine-geometry-primitives (8 files)

CLEAN -- no findings.

All types nested under `Affine.Continuous`. File-per-type maintained.

---

## 14. swift-cyclic-index-primitives (3 files)

CLEAN -- no findings.

Types use `Index<Tag>.Cyclic<N>` typealias and `Tagged.Modular` nesting. Clean API design.

---

## 15. swift-property-primitives (12 files)

CLEAN -- no findings.

Deep nesting (`Property.View.Typed.Valued.Valued`) correctly reflected in file names. One type per file.

---

## 16. swift-ownership-primitives (16 files)

CLEAN -- no findings.

All types under `Ownership.*` namespace. File naming matches. One type per file.

---

## 17. swift-identity-primitives (4 files)

CLEAN -- no findings.

`Tagged` is the core type. `.rawValue` usage in `Tagged.swift` is internal to the type definition (boundary code by definition). The `rawValue.description` in `CustomStringConvertible` is standard protocol conformance.

---

## 18. swift-string-primitives (6 files)

CLEAN -- no findings.

All types nested under `String`. Platform string types with proper `String.View`, `String.Char` nesting.

---

## 19. swift-text-primitives (11 files)

### PATTERN-017: .rawValue at call sites (4 findings)

**F19.1** `Text.Line.Number.swift:32` -- `rawValue` is a public stored property on a non-Tagged struct:
```swift
public let rawValue: UInt
```
`Text.Line.Number` is a hand-rolled struct with a public `rawValue`. This breaks the principle of confining `.rawValue` to boundary code. Consumers must use `.rawValue` to do anything useful (e.g., `Int(lineNumber.rawValue)`). Should either be a `Tagged<Text.Line, UInt>` or provide domain-typed accessors.

**F19.2** `Text.Location.swift:68-69` -- `.rawValue` at Codable serialization boundary:
```swift
try container.encode(line.rawValue, forKey: .line)
try container.encode(column.rawValue.rawValue, forKey: .column)
```
The double `.rawValue.rawValue` for column (unwrapping `Tagged<Text, Cardinal>` then `Cardinal`) is a boundary concern (Codable) but indicates missing Codable conformance on the inner types.

**F19.3** `Text.Line.Map.swift:103,117,130` -- `.rawValue` used in line map resolution:
```swift
let lineIndex = Int(lineNumber.rawValue) - 1
```
This repeats 3 times. An `Int` conversion accessor or subscript on `Text.Line.Number` would eliminate these.

**F19.4** `Text.Line.Map.swift:107,120` -- `.rawValue` chain for column computation:
```swift
Cardinal(UInt(displacement.vector.rawValue + 1))
```
Unwraps `Affine.Discrete.Vector` to get the raw Int. Suggests a missing convenience on the vector type.

---

## 20. swift-source-primitives (8 files)

### PATTERN-017: .rawValue at call sites (3 findings)

**F20.1** `Source.Location.swift:90,96` -- `.rawValue` in computed property accessors:
```swift
public var line: Int { Int(position.line.rawValue) }
public var column: Int { Int(bitPattern: position.column.rawValue.rawValue) }
```
These convenience accessors exist specifically to wrap the `.rawValue` chain, which is good practice. However, the double `.rawValue.rawValue` for column indicates the same issue as F19.2.

**F20.2** `Source.Location.swift:139-140` -- Same `.rawValue` chain in Codable:
```swift
try container.encode(position.line.rawValue, forKey: .line)
try container.encode(position.column.rawValue.rawValue, forKey: .column)
```

**F20.3** `Source.Manager.swift:97,106,119,122,123` -- `id.rawValue` used as array index 5 times:
```swift
files[id.rawValue]
contents[id.rawValue]
```
`Source.File.ID.rawValue` is `internal`, so this is package-internal boundary code. Acceptable, but a subscript `files[id]` pattern would be cleaner.

---

## 21. swift-logic-primitives (8 files)

CLEAN -- no findings.

Proper `Logic` and `Logic.Ternary` nesting across two targets. File-per-type maintained.

---

## 22. swift-optic-primitives (9 files)

CLEAN -- no findings.

All types nested under `Optic` (`Optic.Affine`, `Optic.Iso`, `Optic.Lens`, `Optic.Prism`, `Optic.Traversal`). No `.rawValue` at call sites.

---

## 23. swift-symmetry-primitives (9 files)

### API-NAME-001: Top-level type names (3 findings)

**F23.1** `Rotation.swift` -- `Rotation` is a top-level `public struct`:
```swift
public struct Rotation<let N: Int, Scalar> {
```
Per [API-NAME-001], this should be `Symmetry.Rotation` (nested under the `Symmetry` namespace defined in `Symmetry.swift`).

**F23.2** `Shear.swift` -- `Shear` is a top-level `public struct`:
```swift
public struct Shear<let N: Int, Scalar: FloatingPoint> {
```
Should be `Symmetry.Shear`.

**F23.3** `Rotation.Phase.swift` -- `Phase` is a top-level `public enum`:
```swift
public enum Phase: Ordinal, Sendable, Hashable, CaseIterable {
```
File is named `Rotation.Phase.swift` suggesting it should be `Rotation.Phase` or `Symmetry.Rotation.Phase`. Currently a top-level enum with no namespace.

### API-IMPL-005: File naming mismatch (1 finding)

**F23.4** `Affine.Transform.swift` -- File comment says `Geometry.AffineTransform+Symmetry.swift` but actual filename is `Affine.Transform.swift`. The file contains extensions on `Affine.Transform` from another package, not a type declaration. This is an extension file with a stale comment, not a type-per-file issue. Low severity.

---

## 24. swift-effect-primitives (10 files)

### API-NAME-001: Hoisted protocol compound names (3 findings)

**F24.1** `Effect.Protocol.swift` -- Protocol hoisted to module level as `__EffectProtocol`:
```swift
public protocol __EffectProtocol: Sendable {
```
This is a known Swift limitation workaround (protocols cannot be nested in enums). The double-underscore prefix and `Effect.Protocol` typealias mitigate the naming issue. Documented as workaround.

**F24.2** `Effect.Handler.swift` -- Protocol hoisted as `__EffectHandler`:
```swift
public protocol __EffectHandler: Sendable {
```
Same workaround pattern.

**F24.3** `Effect.Continuation.swift` -- Protocol hoisted as `__EffectContinuation`:
```swift
public protocol __EffectContinuation<Value, Failure>: ~Copyable, Sendable {
```
Same workaround pattern.

**Note:** All three have corresponding `Effect.*.Protocol` typealiases. The workaround is well-documented. These are "known limitation" findings, not actionable violations.

---

## 25. swift-serializer-primitives (16 files)

CLEAN -- no findings.

Three-target structure (`Serializer Primitives Core`, `Serialization Primitives`, `Serializer Primitives`). All types properly nested: `Serializer.Protocol`, `Serializer.Builder`, `Serialization.Parsing.Prefix.Witness`, etc. Deep nesting correctly reflected in file names.

---

## 26. swift-x86-primitives (15 files)

### PATTERN-017: .rawValue on RawRepresentable types at call sites (3 findings)

**F26.1** `CPU.X86.Identification.swift:38,72,73` -- `.rawValue` when calling C shim:
```swift
leaf.rawValue,
subleaf.rawValue,
```
This is C-interop boundary code (passing to `swift_x86_identification_query_v1`). Acceptable boundary usage.

**F26.2** All 4 newtypes (`Leaf`, `Register`, `Subleaf`, `Processor.ID`, `Random.Seed`, `Random.Value`) use public `RawRepresentable` with exposed `rawValue`. These are hardware register types where the raw integer IS the domain value. The RawRepresentable pattern is deliberate for C interop.

### API-NAME-001: RawRepresentable types with init(rawValue:) (3 findings)

**F26.3** `CPU.X86.Identification.Leaf` -- public `init(rawValue: UInt32)` and `init(_ rawValue: UInt32)`:
The parameter label `rawValue` in the convenience init `init(_ rawValue: UInt32)` shadows the semantic intent. This is a minor naming concern on these hardware types.

**F26.4** Same pattern on `Register`, `Subleaf`, `Processor.ID`, `Random.Seed`, `Random.Value` -- all 6 types have `init(_ rawValue: UInt32/UInt64)` with the parameter named `rawValue`. Consider a domain-meaningful label like `init(_ value: UInt32)`.

**F26.5** These types are NOT Tagged -- they are standalone RawRepresentable structs. The `.rawValue` property is their public API surface by design. This is a deliberate choice for hardware types that ARE their raw value. Noted but not necessarily a violation for this domain.

---

## 27. swift-arm-primitives (13 files)

### PATTERN-017: .rawValue at C-interop boundary (3 findings)

**F27.1** `CPU.ARM.Register.swift:31,42,53` -- `.rawValue` when calling C shim:
```swift
.init(swift_arm_register_read_v1(System.frequency.rawValue))
```
This is C-interop boundary code. The `System.rawValue` extracts the Int32 register identifier for the C function.

**F27.2** Same RawRepresentable pattern as x86 on `Counter.Frequency`, `Counter.Value` types. Hardware types where raw value IS the domain value.

**F27.3** `CPU.ARM.Register.System` uses `rawValue: Int32` to map to C enum values. Boundary code by definition.

---

## 28. swift-cpu-primitives (17 files)

### PATTERN-017: .rawValue at C-interop boundary (3 findings)

**F28.1** `CPU.Integrity.Cyclic.Castagnoli.swift:47` -- `.rawValue` extracting seed for C shim:
```swift
seed.rawValue
```
C-interop boundary code.

**F28.2** `CPU.Timestamp` and `CPU.Integrity.Cyclic.Checksum` -- RawRepresentable types with exposed `.rawValue`. Same hardware type pattern as x86/arm.

**F28.3** All hardware types (`Timestamp`, `Checksum`) conform to `Binary.Serializable` which likely needs raw value access. This is systematic boundary code.

---

## 29. swift-system-primitives (10 files)

CLEAN -- no findings.

Types use `Tagged<System.Memory, Cardinal>` and `Tagged<System.Processor, Cardinal>` via typealiases. Deep nesting: `System.Topology.NUMA.Node`, `System.Topology.NUMA.State`. No `.rawValue` at call sites (all access goes through convenience `Int(_ capacity:)` initializers).

---

## 30. swift-loader-primitives (9 files)

CLEAN -- no findings.

All types nested under `Loader`: `Loader.Library.Handle`, `Loader.Section.Bounds`, `Loader.Section.Name`, `Loader.Symbol.Scope`, `Loader.Error`, `Loader.Message`. The `.rawValue` usage on `Handle` is inside `==` operator implementation (boundary code). Clean Nest.Name pattern throughout.

---

## Cross-Cutting Observations

### Hardware types and RawRepresentable (x86, arm, cpu)

All three hardware packages (x86, arm, cpu) use standalone `RawRepresentable` structs rather than `Tagged`. This is a deliberate design choice for types whose domain IS a raw integer (register values, timestamps, checksums). The `.rawValue` exposure is inherent to `RawRepresentable` conformance. These are not Tagged wrappers for type safety -- they ARE their raw values, with the struct providing name-based disambiguation.

**Recommendation:** No change needed. Hardware register types are a legitimate domain where `RawRepresentable` + public `rawValue` is the correct pattern.

### Text.Line.Number is a hand-rolled Tagged

`Text.Line.Number` duplicates what `Tagged<Text.Line, UInt>` would provide (stored `rawValue: UInt`, manual `Comparable`, manual `ExpressibleByIntegerLiteral`). Converting to Tagged would eliminate the boilerplate and eliminate the public `.rawValue` at call sites.

### Symmetry top-level types

`Rotation`, `Shear`, and `Phase` are the only top-level non-namespaced types found across all 30 packages. Every other package correctly nests types under a namespace enum. This is the most actionable finding category.
