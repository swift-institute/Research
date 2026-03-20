# swift-set-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (automated)
**Package**: `/Users/coen/Developer/swift-primitives/swift-set-primitives/`
**Scope**: [API-NAME-001], [API-NAME-002], [IMPL-INTENT], [IMPL-002], [IMPL-010], [IMPL-020], [IMPL-050], [PATTERN-017], [PATTERN-021], [API-IMPL-005]
**Files reviewed**: 31 source files across 3 modules

## Summary Table

| ID | Severity | Rule | Location | Description |
|----|----------|------|----------|-------------|
| [SET-001] | **LOW** | [API-IMPL-005] | `Set.swift:36-94` | Three type declarations in one file (Set, Ordered, Fixed) |
| [SET-002] | **LOW** | [API-IMPL-005] | `Set.Ordered.Error.swift:22-153` | Three hoisted error enums in one file |
| [SET-003] | **INFO** | [API-NAME-002] | `Set.Protocol+defaults.swift` | 7 stdlib-convention compound names (isDisjoint, isSubset, etc.) |
| [SET-004] | **INFO** | [API-NAME-002] | `Set.Protocol+algebra.swift` | symmetricDifference is a stdlib-convention compound name |
| [SET-005] | **LOW** | [API-NAME-002] | Multiple files | `withElement` is a compound method name (our invention) |
| [SET-006] | **LOW** | [API-NAME-002] | Multiple files | `withMutableSpan` is a compound method name (our invention) |
| [SET-007] | **LOW** | [API-NAME-002] | Multiple files | `withUnsafeBufferPointer` / `withUnsafeMutableBufferPointer` are stdlib-convention |
| [SET-008] | **LOW** | [API-NAME-002] | Multiple files | `makeIterator` / `makeUnique` / `ensureUnique` are stdlib-convention |
| [SET-009] | **LOW** | [API-NAME-002] | Multiple files | `removeAll` is a stdlib-convention compound name |
| [SET-010] | **INFO** | [IMPL-010] | `Set.Ordered.Error.swift:51,106,150` | `Int(bitPattern:)` in error descriptions (boundary code) |
| [SET-011] | **INFO** | [IMPL-010] | 4 `*Copyable.swift` files | `Int(bitPattern: count)` in `underestimatedCount` (boundary code) |
| [SET-012] | **MEDIUM** | [PATTERN-021] | `Set.Ordered Copyable.swift:88` | `hashTable.insert(__unchecked: ...)` in non-boundary code |
| [SET-013] | **MEDIUM** | [PATTERN-021] | `Set.Ordered.Fixed.swift:86` | `hashTable.insert(__unchecked: ...)` in non-boundary code |
| [SET-014] | **MEDIUM** | [PATTERN-021] | `Set.Ordered.Small.swift:91,160` | `_heapHashTable!.insert(__unchecked: ...)` in non-boundary code |
| [SET-015] | **MEDIUM** | [PATTERN-021] | `Set.Ordered.Static.swift:103` | `_hashTable.insert(__unchecked: ...)` in non-boundary code |
| [SET-016] | **LOW** | [PATTERN-021] | `Set.Ordered.Fixed Copyable.swift:100` | `.init(__unchecked: (), Cardinal(...))` in arrayLiteral |
| [SET-017] | **INFO** | [PATTERN-017] | All files | No `.rawValue` usage anywhere -- fully compliant |
| [SET-018] | **PASS** | [API-NAME-001] | All files | Nest.Name pattern used throughout |
| [SET-019] | **PASS** | [API-ERR-001] | All files | All throwing functions use typed throws |
| [SET-020] | **PASS** | [IMPL-020] | `drain`, `remove`, `algebra.symmetric` | Property.View / verb-as-property pattern used correctly |
| [SET-021] | **PASS** | [IMPL-050] | `Set.Ordered.Static` | Bounded indices (`Index<Element>.Bounded<capacity>`) for static-capacity |
| [SET-022] | **PASS** | [IMPL-INTENT] | All files | Code reads as intent throughout |
| [SET-023] | **PASS** | [IMPL-002] | All files | Typed arithmetic used consistently (Index, Count, Ordinal, Cardinal) |

**Totals**: 5 MEDIUM, 8 LOW, 4 INFO, 6 PASS

---

## Detailed Findings

### [SET-001] Three type declarations in Set.swift [LOW / API-IMPL-005]

**File**: `Sources/Set Primitives Core/Set.swift:36-94`

Three types declared in one file: `Set` (enum, line 36), `Set.Ordered` (struct, line 45), `Set.Ordered.Fixed` (struct, line 73).

**Mitigation**: These are nested declarations -- Swift requires the parent type to contain nested types syntactically. Splitting would require hoisting + typealias (like the error types). The current approach is pragmatic and arguably the canonical pattern for nested types. This is an inherent tension with [API-IMPL-005] for deeply nested type hierarchies.

**Verdict**: Acceptable as-is. The nesting is structural, not accidental bundling.

---

### [SET-002] Three hoisted error enums in one file [LOW / API-IMPL-005]

**File**: `Sources/Set Primitives Core/Set.Ordered.Error.swift:22-153`

Three error enums (`__SetOrderedError`, `__SetOrderedFixedError`, `__SetOrderedInlineError`) plus their nested payload structs (Bounds, Empty, Overflow, InvalidCapacity) and typealias re-exports. Total: 3 enums + 8 nested structs + 3 typealiases.

**Mitigation**: All three serve the same domain (set error types) and share the same structural pattern. Splitting into three files (`Set.Ordered.Error.swift`, `Set.Ordered.Fixed.Error.swift`, `Set.Ordered.Static.Error.swift`) would be more aligned with [API-IMPL-005].

**Verdict**: Consider splitting. Each error enum is independent enough to warrant its own file.

---

### [SET-003] stdlib-convention compound names in Set.Protocol [INFO / API-NAME-002]

**File**: `Sources/Set Primitives Core/Set.Protocol+defaults.swift`

Seven compound method names: `isDisjoint(with:)`, `isSubset(of:)`, `isSuperset(of:)`, `isStrictSubset(of:)`, `isStrictSuperset(of:)`, `isEqual(to:)`, `isEmpty`.

These mirror Swift stdlib `SetAlgebra` protocol names exactly. They are not our invention.

**Verdict**: Compliant. stdlib conventions are explicitly exempted per the audit brief.

---

### [SET-004] symmetricDifference is stdlib-convention [INFO / API-NAME-002]

**File**: `Sources/Set Ordered Primitives/Set.Protocol+algebra.swift:97`

`symmetricDifference` mirrors Swift stdlib's `SetAlgebra.symmetricDifference(_:)`.

**Verdict**: Compliant. stdlib convention.

Note: The package also provides an alternative nested accessor path: `set.algebra.symmetric.difference(other)` which fully complies with [API-NAME-002]. Both forms coexist.

---

### [SET-005] withElement is a compound method name [LOW / API-NAME-002]

**Files**: `Set.Ordered ~Copyable.swift:60,73`, `Set.Ordered.Fixed.swift:165,172`, `Set.Ordered.Small.swift:223,230`, `Set.Ordered.Static.swift:211,218`

`withElement(at:_:)` is our own invention (not an stdlib name). Under strict [API-NAME-002], this would be `element(at:).with { }` or similar nested accessor pattern.

However, `withElement` follows the established `with`-closure pattern from Swift (e.g., `withUnsafeBufferPointer`, `withContiguousStorageIfAvailable`). The `with` prefix signals closure-based borrowing access, which is idiomatic Swift for ~Copyable types.

**Verdict**: Borderline. The `with`-prefix closure pattern is an established Swift idiom for types that cannot return values. Renaming to a nested accessor would obscure the borrowing semantics. Acceptable as-is, but note the deviation.

---

### [SET-006] withMutableSpan is a compound method name [LOW / API-NAME-002]

**Files**: `Set.Ordered Copyable.swift:190`, `Set.Ordered.Fixed.swift:231`, `Set.Ordered.Small.swift:317`

Same rationale as [SET-005]. `withMutableSpan` follows the same `with`-closure idiom and mirrors stdlib patterns.

**Verdict**: Acceptable. Same rationale as [SET-005].

---

### [SET-007] withUnsafeBufferPointer / withUnsafeMutableBufferPointer [LOW / API-NAME-002]

**Files**: Multiple files behind `@_spi(Unsafe)`.

These are direct stdlib convention names (`UnsafeBufferPointer.withUnsafeBufferPointer`, etc.).

**Verdict**: Compliant. stdlib convention, behind `@_spi(Unsafe)`.

---

### [SET-008] makeIterator / makeUnique / ensureUnique [LOW / API-NAME-002]

stdlib conventions: `makeIterator()` is required by `IteratorProtocol`. `makeUnique()` and `ensureUnique()` follow the CoW pattern from stdlib (`isKnownUniquelyReferenced`).

**Verdict**: Compliant. stdlib conventions.

---

### [SET-009] removeAll is stdlib-convention [LOW / API-NAME-002]

`removeAll()` is required by `Sequence.Clearable` conformance and mirrors `RangeReplaceableCollection.removeAll()`.

**Verdict**: Compliant. stdlib/protocol convention.

---

### [SET-010] Int(bitPattern:) in error descriptions [INFO / IMPL-010]

**File**: `Sources/Set Primitives Core/Set.Ordered.Error.swift:51,106,150`

```swift
return "index \(Int(bitPattern: e.index)) out of bounds for count \(Int(bitPattern: e.count))"
```

These are in `CustomStringConvertible.description` -- converting typed `Index<Element>` and `Index<Element>.Count` to `Int` for human-readable output. This is legitimate boundary code (type system boundary to string representation).

**Verdict**: Compliant. Boundary code per [IMPL-010].

---

### [SET-011] Int(bitPattern:) in underestimatedCount [INFO / IMPL-010]

**Files**: `Set.Ordered Copyable.swift:304`, `Set.Ordered.Fixed Copyable.swift:69`, `Set.Ordered.Small Copyable.swift:82`, `Set.Ordered.Static Copyable.swift:82`

```swift
public var underestimatedCount: Int { Int(bitPattern: count) }
```

Converting typed `Count` to `Int` for `Swift.Sequence` protocol conformance. This is boundary code (typed domain to stdlib protocol requirement).

**Verdict**: Compliant. Boundary code per [IMPL-010].

---

### [SET-012] through [SET-015]: __unchecked in insert paths [MEDIUM / PATTERN-021]

**Files**:
- `Set.Ordered Copyable.swift:88` -- `hashTable.insert(__unchecked: (), position: index, hashValue: element.hashValue)`
- `Set.Ordered.Fixed.swift:86` -- same pattern
- `Set.Ordered.Small.swift:91,160` -- same pattern (insert + _buildHashTable)
- `Set.Ordered.Static.swift:103` -- same pattern

All five call sites use `insert(__unchecked:position:hashValue:)` on the hash table. The `__unchecked` parameter signals that the caller takes responsibility for invariants (position validity, no duplicate check). This is the hash table's internal API for skip-the-duplicate-check insertion.

The set layer has ALREADY performed the duplicate check before reaching this point. The `__unchecked` is intentional -- it avoids a redundant O(1) hash probe.

**Question**: Does the hash table expose a non-`__unchecked` insert? If so, using it would eliminate the `__unchecked` at the cost of a redundant probe. If not, this is the only API available.

**Verdict**: The `__unchecked` usage is locally justified (duplicate check already performed), but [PATTERN-021] prefers typed arithmetic over `__unchecked`. These call sites should be reviewed to determine if a safe `insert(position:hashValue:)` API exists on Hash.Table. If it does, prefer it. If not, the `__unchecked` is the correct choice and should be documented with a comment explaining why.

---

### [SET-016] __unchecked in Fixed arrayLiteral [LOW / PATTERN-021]

**File**: `Sources/Set Ordered Primitives/Set.Ordered.Fixed Copyable.swift:100`

```swift
self = try! Self(capacity: .init(__unchecked: (), Cardinal(UInt(elements.count))))
```

The `__unchecked` here creates an `Index<Element>.Count` from a `Cardinal` without validation. In an `arrayLiteral` context, `elements.count` is always a valid non-negative value, so the unchecked construction is safe.

**Verdict**: Acceptable but could be improved. If `Index<Element>.Count` has a failable init from `Cardinal`, using `try!` on it would be more self-documenting than `__unchecked`.

---

### [SET-017] No .rawValue usage [PASS / PATTERN-017]

Zero occurrences of `.rawValue` in the entire package. All typed wrappers are used via their typed APIs (`Index<Element>`, `Count`, `Ordinal`, `Cardinal`, `Bounded`).

**Verdict**: Fully compliant.

---

### [SET-018] Nest.Name pattern [PASS / API-NAME-001]

All types follow the Nest.Name pattern:
- `Set<Element>` (shadows Swift.Set intentionally)
- `Set.Ordered`
- `Set.Ordered.Fixed`
- `Set.Ordered.Static`
- `Set.Ordered.Small`
- `Set.Ordered.Algebra`
- `Set.Ordered.Algebra.Symmetric`
- `Set.Ordered.Iterator`
- `Set.Ordered.Indexed<Tag>`
- `Set.Ordered.Fixed.Indexed<Tag>`
- `Set.Ordered.Fixed.Iterator`
- `Set.Ordered.Small.Iterator`
- `Set.Ordered.Static.Iterator`
- `Set.Index` (typealias)
- `Set.Protocol` (typealias to hoisted `__SetProtocol`)
- `Set.Ordered.Error` (typealias to hoisted `__SetOrderedError`)
- `Set.Ordered.Fixed.Error` (typealias to hoisted `__SetOrderedFixedError`)
- `Set.Ordered.Static.Error` (typealias to hoisted `__SetOrderedInlineError`)

No compound type names anywhere.

**Verdict**: Fully compliant.

---

### [SET-019] Typed throws [PASS / API-ERR-001]

All throwing functions use typed throws:
- `throws(__SetOrderedError<Element>)`
- `throws(__SetOrderedFixedError<Element>)`
- `throws(__SetOrderedInlineError<Element>)`
- `throws(E)` for generic rethrow closures

No untyped `throws` on any public API.

**Verdict**: Fully compliant.

---

### [SET-020] Verb-as-property / Property.View pattern [PASS / IMPL-020]

The `drain` property uses `Property<Sequence.Drain, Self>.View` with `_read`/`_modify` accessors on all four variants (Ordered, Fixed, Small, Static). The `algebra` and `algebra.symmetric` accessors use the nested accessor pattern. The `remove` operations delegate to buffer's `remove.first()` and `remove.all()` via Property.View.

**Verdict**: Fully compliant.

---

### [SET-021] Bounded indices for static-capacity types [PASS / IMPL-050]

`Set.Ordered.Static` returns `Index<Element>.Bounded<capacity>` from `index(_:)` and `insert(_:)`. Subscript access accepts both `Index<Element>` and `Index<Element>.Bounded<capacity>`. The `element(at:)` method has overloads for both index types.

**Verdict**: Fully compliant.

---

### [SET-022] Intent over mechanism [PASS / IMPL-INTENT]

Code consistently reads as intent:
- `count.subtract.saturating(.one).map(Ordinal.init)` -- "count minus one, saturating, as ordinal"
- `buffer.count.map(Ordinal.init)` -- "buffer count as ordinal (for indexing)"
- `hashTable.remove.all(keepingCapacity: true)` -- "remove all from hash table, keep capacity"
- `_buffer.remove.first()` -- "remove first from buffer"

No raw pointer arithmetic, no manual memory management exposed to callers.

**Verdict**: Fully compliant.

---

### [SET-023] Typed arithmetic [PASS / IMPL-002]

All arithmetic uses typed wrappers:
- `Index<Element>` for positions
- `Index<Element>.Count` for sizes
- `Index<Element>.Bounded<capacity>` for static-capacity bounds
- `Ordinal` / `Cardinal` for conversions
- `.zero`, `.one` for typed constants
- `+=`, `<`, `>`, `==` operate on typed values

No raw `Int` arithmetic anywhere in the package.

**Verdict**: Fully compliant.

---

## Observations (Non-Findings)

1. **`Set.Ordered.Small` deinit workaround**: Well-documented compiler bug workaround (#86652 variant). The `_deinitWorkaround: AnyObject?` field and manual `remove.all()` via unsafe pointer are properly tracked with `WHEN TO REMOVE` comments.

2. **SIL exclusivity workaround in Small**: The local-variable extraction pattern for `_heapHashTable` mutations is repeated 3 times. Consider a helper method to reduce duplication, though the workaround comments are valuable for tracking.

3. **Algebra accessor stores copies**: `Algebra` and `Algebra.Symmetric` store `Buffer<Element>.Linear` and `Hash.Table<Element>` as copies (CoW value types). This avoids consuming/mutating the set but means the algebra accessor has O(1) creation cost (CoW ref bump only). Well-designed.

4. **No Foundation imports**: Zero Foundation imports anywhere. Fully compliant with [PRIM-FOUND-001].

5. **`reserveCapacity` vs `reserve`**: The public API is `reserve(_:)` (line 42 of `Set.Ordered ~Copyable.swift`), which delegates to `buffer.reserveCapacity(_:)`. The public name is clean; the compound name is on the buffer's API (different package).
