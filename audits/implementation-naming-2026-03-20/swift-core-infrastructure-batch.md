# Core Infrastructure Batch Audit: Implementation & Naming

**Date**: 2026-03-20
**Auditor**: Claude (read-only)
**Skills applied**: [API-NAME-001], [API-NAME-002], [IMPL-002], [IMPL-010], [PATTERN-017], [PATTERN-021], [API-IMPL-005]
**Packages**: ordinal, cardinal, finite, index, vector, comparison, equation, collection, input, hash

## Combined Summary

| Package | Files | Findings | Critical | High | Medium | Low | Clean |
|---------|-------|----------|----------|------|--------|-----|-------|
| swift-ordinal-primitives | 37 | 1 | 0 | 0 | 0 | 1 | Yes |
| swift-cardinal-primitives | 21 | 1 | 0 | 0 | 0 | 1 | Yes |
| swift-finite-primitives | 25 | 2 | 0 | 0 | 0 | 2 | Yes |
| swift-index-primitives | 3 | 0 | 0 | 0 | 0 | 0 | Yes |
| swift-vector-primitives | 19 | 1 | 0 | 0 | 0 | 1 | Yes |
| swift-comparison-primitives | 34 | 1 | 0 | 0 | 0 | 1 | Yes |
| swift-equation-primitives | 26 | 1 | 0 | 0 | 0 | 1 | Yes |
| swift-collection-primitives | 27 | 2 | 0 | 0 | 1 | 1 | No |
| swift-input-primitives | 23 | 0 | 0 | 0 | 0 | 0 | Yes |
| swift-hash-primitives | 27 | 1 | 0 | 0 | 0 | 1 | Yes |
| **Totals** | **242** | **10** | **0** | **0** | **1** | **9** | |

**Overall verdict**: Exceptionally clean infrastructure. 9 of 10 packages are fully clean. The single MEDIUM finding is an `.rawValue` usage in consumer-facing code in `Collection.Rotated`. All other `.rawValue` and `__unchecked` usage is correctly confined to boundary code (type definitions, stdlib integration, cross-type operators).

---

## 1. swift-ordinal-primitives (37 files)

### Architecture

Three modules:
- **Ordinal Primitives Core** (14 files): `Ordinal` struct, operations, cross-domain operators
- **Ordinal Primitives** (6 files): `Tagged<Tag, Ordinal>` extensions
- **Ordinal Primitives Standard Library Integration** (17 files): stdlib bridging

### Naming [API-NAME-001] [API-NAME-002]

All types follow `Nest.Name` correctly:
- `Ordinal`, `Ordinal.Error`, `Ordinal.Advance`, `Ordinal.Retreat`, `Ordinal.Successor`, `Ordinal.Predecessor`, `Ordinal.Distance`
- `Ordinal.Protocol` (protocol nested in extension)
- No compound type names. No compound method/property names.
- `.advance`, `.retreat`, `.successor`, `.predecessor`, `.distance` use nested accessors per [API-NAME-002].

### .rawValue Usage [IMPL-002] [PATTERN-017]

All `.rawValue` access is correctly confined to boundary code:
- `Ordinal.swift`: operator definitions (`==`, `<`, `<=`, `>`, `>=`) -- these ARE the boundary
- `Ordinal+Cardinal.swift`: cross-type comparison operators -- boundary by definition
- `Ordinal.Advance.swift`, `Ordinal.Retreat.swift`, `Ordinal.Distance.swift`, `Ordinal.Successor.swift`, `Ordinal.Predecessor.swift`: arithmetic implementations -- these define the typed operations that eliminate `.rawValue` at consumer call sites
- `Ordinal+CustomStringConvertible.swift`: `rawValue.description` -- stdlib bridge (boundary)
- SLI subscripts: `Int(bitPattern: position.ordinal)` -- stdlib boundary, using typed `Int(bitPattern:)` overload

### Int(bitPattern:) Usage [IMPL-010]

All `Int(bitPattern:)` usage is in SLI (Standard Library Integration) files -- exactly the boundary overloads where this is appropriate: `Array+Ordinal.swift`, `InlineArray+Ordinal.swift`, `ContiguousArray+Ordinal.swift`, pointer subscripts, `Span`/`MutableSpan` initializers.

### __unchecked Usage [PATTERN-021]

`__unchecked` appears in `Tagged` construction within `Ordinal.Protocol` conformance -- this is the canonical lift from raw to tagged, correctly annotated.

### One Type Per File [API-IMPL-005]

Compliant. Each file contains one type or one extension set.

### Findings

**[ORD-001]** LOW -- `Ordinal+Cardinal.swift` contains both protocol conformances (`Equation.Protocol`, `Comparison.Protocol`, `Hash.Protocol`) and cross-type operators. These are logically related (both are "Ordinal in the context of Cardinal") but mixing conformance declarations with free functions is a minor organization note. Not a violation since the file is named for the cross-type relationship.

---

## 2. swift-cardinal-primitives (21 files)

### Architecture

Three modules:
- **Cardinal Primitives Core** (7 files): `Cardinal` struct, operations
- **Cardinal Primitives** (4 files): `Tagged<Tag, Cardinal>` extensions
- **Cardinal Primitives Standard Library Integration** (10 files): stdlib bridging

### Naming [API-NAME-001] [API-NAME-002]

All types follow `Nest.Name` correctly:
- `Cardinal`, `Cardinal.Error`, `Cardinal.Add`, `Cardinal.Subtract`
- `Cardinal.Protocol`
- `.add`, `.subtract` use nested accessors per [API-NAME-002].

### .rawValue Usage [IMPL-002] [PATTERN-017]

All `.rawValue` access is in boundary code:
- `Cardinal.swift`: operator/comparison implementations
- `Cardinal.Add.swift`, `Cardinal.Subtract.swift`: arithmetic implementations
- `Cardinal+CustomStringConvertible.swift`: stdlib bridge
- SLI `Int(bitPattern:)` conversions

### Findings

**[CARD-001]** LOW -- `Cardinal.swift` contains both `struct Cardinal` and multiple extension blocks (operators, comparisons, protocol conformances `Equation.Protocol`, `Comparison.Protocol`). Per [API-IMPL-005] a file should contain one type. Here the main type definition shares the file with operators and conformances. The operators are on `Cardinal` itself so this is borderline acceptable, but conformance declarations could be in separate files for strict compliance.

---

## 3. swift-finite-primitives (25 files)

### Architecture

Two modules:
- **Finite Primitives Core** (10 files): `Finite` namespace, `Ordinal.Finite`, `Finite.Enumerable`, etc.
- **Finite Primitives** (15 files): Algebra group witnesses, `Finite.Enumerable` conformances

### Naming [API-NAME-001] [API-NAME-002]

Types follow `Nest.Name` correctly:
- `Finite`, `Finite.Bound<N>`, `Finite.Capacity`, `Finite.Enumerable`, `Finite.Bounded`, `Finite.Enumeration`
- `Ordinal.Finite<N>` (typealias to `Tagged<Finite.Bound<N>, Ordinal>`)
- `Index<Element>.Bounded<N>` (typealias to `Tagged<Tag, Ordinal.Finite<N>>`)

### .rawValue Usage [IMPL-002] [PATTERN-017]

No problematic `.rawValue` usage. All index arithmetic goes through typed operations (`Int(bitPattern:)` in `Finite.Enumeration`'s `RandomAccessCollection` conformance -- correct boundary code).

### __unchecked Usage [PATTERN-021]

`__unchecked` in `Tagged+Ordinal.Finite.swift` for constructing bounded ordinals -- correct boundary code with documented preconditions.

### Findings

**[FIN-001]** LOW -- `Tagged+Ordinal.Finite.swift` is 211 lines with construction, bounds, successor/predecessor, offset, distance, complement, injection/projection, and product isomorphism all in one file. While technically one type (`Tagged where Tag == Finite.Bound<N>, RawValue == Ordinal`), the conceptual surface is very wide. Consider splitting into `Tagged+Ordinal.Finite.Construction.swift`, `Tagged+Ordinal.Finite.Navigation.swift`, `Tagged+Ordinal.Finite.Isomorphism.swift`.

**[FIN-002]** LOW -- `Comparison+Finite.swift` introduces `Comparison.Value<Payload>` typealias in addition to the `Finite.Enumerable` conformance. Two logical concepts in one file. The typealias is unrelated to finiteness -- it should be in a `Comparison.Value.swift` file in comparison-primitives or in the finite-primitives with a clearer name like `Comparison+Finite+Value.swift`.

---

## 4. swift-index-primitives (3 files)

### Architecture

Two modules:
- **Index Primitives Core** (2 files): `Index` typealias, exports
- **Index Primitives** (1 file): exports

### Naming [API-NAME-001]

`Index<Element>` is a typealias for `Tagged<Element, Ordinal>`. Clean and correct.

### Findings

No findings. This is a minimal, perfectly clean package.

---

## 5. swift-vector-primitives (19 files)

### Architecture

Three modules:
- **Vector Primitives Core** (12 files): `Vector<Bound>`, iteration patterns, drop/prefix
- **Vector Primitives Standard Library Integration** (5 files): pointer/buffer index overloads
- **Vector Primitives** (2 files): exports

### Naming [API-NAME-001] [API-NAME-002]

Types follow `Nest.Name` correctly:
- `Vector<Bound>`, `Vector.Iterator`, `Vector.Reversed`, `Vector.Reversed.Iterator`
- `Vector.Drop`, `Vector.Prefix`, `Vector.ForEach`, `Vector.Drain`
- `.forEach`, `.drain`, `.drop`, `.prefix` all use nested accessors per [API-NAME-002].

### .rawValue Usage [IMPL-002] [PATTERN-017]

No consumer-facing `.rawValue`. All boundary code in SLI files uses `Int(bitPattern:)` for stdlib interop.

### Findings

**[VEC-001]** LOW -- `Vector.swift` is 432 lines containing `Vector`, `Vector.Iterator`, `Vector.Reversed`, `Vector.Reversed.Iterator`, plus `Sendable`/`Copyable` conformances. The doc comment explains this is necessary ("declared inline so that they properly inherit the `~Copyable` constraint from `Bound` per [PATTERN-022]"). This is a correct design constraint, not a violation -- but worth noting the file size. No action needed.

---

## 6. swift-comparison-primitives (34 files)

### Architecture

Three modules:
- **Comparison Primitives Core** (12 files): `Comparison` enum, `Comparison.Protocol`, Property.View extensions
- **Comparison Primitives** (2 files): `Tagged` conformance, exports
- **Comparison Primitives Standard Library Integration** (20 files): `Swift.Comparable` bridge, per-type conformances

### Naming [API-NAME-001] [API-NAME-002]

Types follow `Nest.Name` correctly:
- `Comparison`, `Comparison.Protocol`, `Comparison.Compare`, `Comparison.Clamp`
- `.compare`, `.clamp` use nested accessors per [API-NAME-002].
- `Comparison.Compare.swift`, `Comparison.Clamp.swift` are tag-only files (the operations live in `+Property.View` files).

### .rawValue Usage [IMPL-002] [PATTERN-017]

`.rawValue` appears in `Comparison.Protocol+Identity.Tagged.swift` line 17: `lhs.rawValue < rhs.rawValue`. This is the Tagged forwarding implementation (boundary code for the protocol conformance). Correct.

### Findings

**[CMP-001]** LOW -- `Comparison+Swift.Comparable.swift` contains 10 integer conformances plus a `Comparison.init(comparing:to:)` initializer. Mixing conformance declarations with an initializer. The initializer could live in its own file for strict [API-IMPL-005], but grouping all stdlib bridging in one file is pragmatic.

---

## 7. swift-equation-primitives (26 files)

### Architecture

Three modules:
- **Equation Primitives Core** (3 files): `Equation` enum, `Equation.Protocol`, exports
- **Equation Primitives** (2 files): `Tagged` conformance, exports
- **Equation Primitives Standard Library Integration** (21 files): per-type conformances

### Naming [API-NAME-001]

Types follow `Nest.Name` correctly:
- `Equation`, `Equation.Protocol`

### .rawValue Usage [IMPL-002] [PATTERN-017]

`.rawValue` in `Equation.Protocol+Identity.Tagged.swift` line 17: `lhs.rawValue == rhs.rawValue`. Tagged forwarding -- correct boundary code.

### Findings

**[EQ-001]** LOW -- `Equation.Protocol+Swift.Equatable.swift` contains 15 retroactive conformances (integers + Bool, String, Character, Double, Float) in one file. Same pattern as comparison -- pragmatic grouping, minor [API-IMPL-005] note.

---

## 8. swift-collection-primitives (27 files)

### Architecture

Single module:
- **Collection Primitives** (27 files): `Collection` namespace, protocols, tag types, Property.View extensions

### Naming [API-NAME-001] [API-NAME-002]

Types follow `Nest.Name` correctly:
- `Collection`, `Collection.Protocol`, `Collection.Indexed`, `Collection.Bidirectional`
- `Collection.Access.Random`, `Collection.Slice`, `Collection.Slice.Protocol`
- `Collection.ForEach`, `Collection.Count`, `Collection.Min`, `Collection.Max`
- `Collection.Remove`, `Collection.Remove.Last`, `Collection.Clearable`
- `Collection.Rotated` (typealias for hoisted `__CollectionRotated`)
- `.count`, `.remove`, `.forEach`, `.min`, `.max`, `.slice` all use nested accessors.

### .rawValue Usage [IMPL-002] [PATTERN-017]

**[COL-001]** MEDIUM -- `Collection.Rotated.swift` lines 59 and 99:
```swift
let offsetValue = startOffset.vector.rawValue        // line 59
(try! (end - start)).vector.rawValue                 // line 99
```
These are in the `Rotated` type's initializer and `distance(from:to:)` method. The `.vector.rawValue` pattern accesses the raw `Int` from an `Offset` (which is `Tagged<Tag, Affine.Discrete.Vector>`). This is consumer-facing code in a concrete type, not a boundary overload definition. The `Rotated` type bridges into stdlib `RandomAccessCollection` which requires `Int`-based APIs -- this is effectively a stdlib integration boundary, but the `.rawValue` access is two levels deep (`.vector.rawValue`). Consider adding an `Int(bitPattern:)` or `Int(clamping:)` overload for `Offset` to avoid the double-unwrap.

### __unchecked Usage

`__unchecked` in `Collection.Count.swift` for constructing `Index<Base.Element>.Count` from computed values -- correct (the count is derived from valid iteration).

### One Type Per File [API-IMPL-005]

**[COL-002]** LOW -- `Collection.Rotated.swift` contains both `__CollectionRotated` (hoisted struct) and the `Collection.Rotated` typealias. The hoisting is documented as necessary due to Swift's limitation on protocol-nested types. Acceptable.

---

## 9. swift-input-primitives (23 files)

### Architecture

Single module:
- **Input Primitives** (23 files): `Input` namespace, protocols, concrete types, error types

### Naming [API-NAME-001] [API-NAME-002]

Types follow `Nest.Name` correctly:
- `Input`, `Input.Stream`, `Input.Stream.Protocol`, `Input.Stream.Error`
- `Input.Protocol`, `Input.Access`, `Input.Access.Random`, `Input.Access.Error`
- `Input.Remove`, `Input.Remove.Error`, `Input.Restore`, `Input.Restore.Error`
- `Input.Buffer`, `Input.Slice`, `Input.Slice.Error`
- `.remove`, `.restore`, `.access` all use nested accessors per [API-NAME-002].
- `Input.Streaming` typealias for `Input.Stream.Protocol` -- ergonomic alias, documented.

### .rawValue Usage [IMPL-002] [PATTERN-017]

No `.rawValue` usage in this package. All typed arithmetic uses the Index/Cardinal/Ordinal typed operations.

### Int(bitPattern:) Usage [IMPL-010]

`Int(bitPattern:)` in `Input.Slice.swift` for converting typed indices to raw `Int` storage -- correct boundary code (the `_position`, `_start`, `_end` raw `Int` storage is a documented workaround for a Swift runtime bug).

### __unchecked Usage

`__unchecked` in `Input.Slice.swift` for index construction from raw `Int` storage -- correct (the raw values are maintained by slice invariants).

### One Type Per File [API-IMPL-005]

Compliant. Each file contains one type or protocol, with error types in separate files.

### Findings

No findings. This package is perfectly clean.

---

## 10. swift-hash-primitives (27 files)

### Architecture

Three modules:
- **Hash Primitives Core** (4 files): `Hash` enum, `Hash.Protocol`, `Hash.Value`, exports
- **Hash Primitives** (2 files): `Tagged` conformance, exports
- **Hash Primitives Standard Library Integration** (21 files): per-type conformances

### Naming [API-NAME-001]

Types follow `Nest.Name` correctly:
- `Hash`, `Hash.Protocol`, `Hash.Value`

### .rawValue Usage [IMPL-002] [PATTERN-017]

`.rawValue` in `Hash.Protocol+Identity.Tagged.swift` line 17: `rawValue.hash(into:)`. Tagged forwarding -- correct boundary code.

### Findings

**[HASH-001]** LOW -- Same pattern as equation and comparison: `Hash.Protocol+Swift.Hashable.swift` contains 15 retroactive conformances in one file. Pragmatic grouping.

---

## Cross-Package Observations

### Pattern Consistency

All 10 packages follow identical patterns:
1. **Core module**: Type definitions with `.rawValue` confined to operator/arithmetic implementations
2. **Tagged module** (where applicable): `Tagged` protocol conformances that forward through `.rawValue` -- correct boundary code
3. **SLI module** (where applicable): `Int(bitPattern:)` for stdlib interop -- correct boundary overloads

### .rawValue Discipline

The `.rawValue` discipline across these 10 packages is exemplary. The only instance where `.rawValue` appears in non-boundary code is `Collection.Rotated` (COL-001), and even that is at a stdlib bridge boundary. All other `.rawValue` usage is in:
- Type-defining operator implementations (the types that DEFINE the typed arithmetic)
- `Tagged` protocol conformance forwarding
- `Int(bitPattern:)` boundary overloads in SLI

### __unchecked Discipline

All `__unchecked` usage is either:
- `Tagged.init(__unchecked:)` at the canonical lift point from raw to tagged
- Documented construction from invariant-maintained raw storage (e.g., `Input.Slice`)

### Typed Throws

All throwing functions use typed throws per [API-ERR-001]:
- `throws(Ordinal.Error)`, `throws(Cardinal.Error)`, `throws(Vector.Error)`
- `throws(Input.Stream.Error)`, `throws(Input.Remove.Error<Element>)`, `throws(Input.Restore.Error)`, `throws(Input.Access.Error<Element>)`
- `throws(Input.Slice<Base>.Error)`

No untyped `throws` detected.
