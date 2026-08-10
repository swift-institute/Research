# Array.Protocol forEach Redesign

**Tier**: 2 — Investigation
**Date**: 2026-03-17
**Status**: Implemented

## Problem

Three candidates named `forEach` exist on every `Array` conformer:

| # | Source | Kind | Mutability | Closure parameter |
|---|--------|------|------------|-------------------|
| 1 | `Array.Protocol+defaults` | method | non-mutating | `(Index) -> Void` |
| 2 | `Collection.Protocol+ForEach` | property | `mutating _read` | `(borrowing Element) -> Void` |
| 3 | Concrete types (Dynamic, Fixed, Static, Small) | property | `mutating _read` | `(borrowing Element) -> Void` |

In non-mutating contexts, only #1 is available. When #1's `Void` constraint fails (because `withElement<R>` propagates a non-Void inner return like `Set.insert`'s tuple), the compiler evaluates all three, finds all failing for different reasons, and reports "ambiguous" instead of the real error.

Additionally, #1 iterates **indices**, contradicting stdlib's `Sequence.forEach` which iterates **elements** (SE-0032, stdlib `Sequence.swift:850-858`).

## Root Cause

The method `func forEach(_ body: (Index) -> Void)` on `Array.Protocol` serves a different semantic role than the Property.View `forEach` on collections. The method yields indices; the property yields elements. Sharing the name `forEach` creates both semantic confusion and compiler ambiguity.

## Options Evaluated

### Option A: Rename to `forEachIndex`

**Rejected** — violates [API-NAME-002] (no compound identifiers). `forEachIndex` is a compound name combining `forEach` and `Index`.

### Option B: Remove method, provide `array.indices.forEach { }`

Requires `var indices: Vector<Index>` on Array types. Vector infrastructure exists (`(.zero..<count)` produces `Vector<Index<Element>>` via `Index.Count+Vector.swift`).

**Problem**: swift-array-primitives does not depend on swift-vector-primitives. Adding the dependency for a single property is disproportionate. Deferred — consumers who need index iteration via Vector can import vector-primitives directly and write `(.zero..<array.count).forEach { }`.

### Option C: Replace index method with element method

Replace the index-yielding `func forEach(_ body: (Index) -> Void)` with an element-yielding `func forEach(_ body: (borrowing Element) -> Void)`. Add `forEach.index { }` as a nested accessor on Property.View for index iteration.

**Selected** — this option:
1. Aligns `forEach` with stdlib semantics (elements, not indices)
2. Uses nested accessor `.forEach.index` per [API-NAME-002]
3. The method is non-mutating; the Property.View `.index` variant is for mutating contexts
4. Eliminates the three-way ambiguity

### Option D: Closure parameter type disambiguation

Overload `forEach` for both `(Index) -> Void` and `(borrowing Element) -> Void`. **Rejected** — fragile type inference, ambiguity without explicit type annotations.

## Design

### Resolution behavior

When both a non-mutating method `func forEach(_ body: (borrowing Element) -> Void)` (from protocol default) and a mutating property `var forEach: Property.View.Typed<Element>` (with `callAsFunction(_ body: (borrowing Base.Element) -> Void)`) exist:

- **Non-mutating context**: Property requires `mutating _read` → unavailable. Method selected. No ambiguity.
- **Mutating context**: Property shadows protocol method (Swift: concrete members take precedence over protocol defaults). `array.forEach { }` resolves via property + callAsFunction. Same behavior (element iteration, borrowing).
- **Mutating, qualified**: `array.forEach.borrowing { }`, `array.forEach.consuming { }`, `array.forEach.index { }` — property access, then named method on Property.View.Typed.

### API surface after redesign

```swift
// Non-mutating element iteration (method on Array.Protocol):
array.forEach { element in ... }

// Mutating element iteration (Property.View callAsFunction):
array.forEach { element in ... }        // same syntax, property path
array.forEach.borrowing { element in }  // explicit borrowing
array.forEach.consuming { element in }  // consuming (clears collection)

// Mutating index iteration (nested accessor per [API-NAME-002]):
array.forEach.index { idx in ... }

// Non-mutating index iteration (no new dependency needed):
// Option 1: Import vector-primitives, use (.zero..<array.count).forEach { }
// Option 2: Manual startIndex/endIndex/index(after:) loop
```

### `withElement(at:)` unchanged

`withElement(at:)` remains useful for per-index element access. When index iteration is combined with element access, the pattern becomes:

```swift
array.forEach.index { idx in
    array.withElement(at: idx) { element in ... }
}
```

## Ecosystem Usage Scan

### Production call sites using `forEach + withElement` pattern

| Repository | Count | Files |
|------------|-------|-------|
| rule-law | 14 | `Besloten Vennootschap.Aandeelhoudersregister.swift` (single file) |
| swift-primitives (Sources) | 0 | Only experiments and documentation |
| swift-standards | 0 | — |
| swift-foundations | 0 | — |
| swift-nl-wetgever | 0 | — |
| swift-us-nv-legislature | 0 | — |
| **Total** | **14** | **1 file** |

### Migration impact

All 14 production call sites are in `Besloten Vennootschap.Aandeelhoudersregister.swift`:
- **13 read-only**: Collapse from two-step `forEach { idx in withElement(at: idx) { } }` to single-step `forEach { element in }`
- **1 index-needing** (`overdracht`): Uses `forEach.index { idx in withElement(at: idx) { } }` (mutating method, Property.View available)

### Property.View forEach patterns (unaffected)

172+ call sites across swift-primitives use `.forEach.borrowing { }` and `.forEach.consuming { }` via Property.View. These are element iteration and are not affected by the redesign.

## Implementation

### Files changed

1. `Array.Protocol+defaults.swift`: Replace index-yielding `forEach` with element-yielding `forEach`. Add `.index` method on Property.View.Typed.
2. `Collection.ForEach+Property.View.swift`: Add `.index` method on base Property.View.
3. `Array.Protocol.swift`: Update doc comment.
4. `Besloten Vennootschap.Aandeelhoudersregister.swift`: Migrate 14 call sites.

### No new dependencies

`var indices: Vector<Index>` deferred — requires adding swift-vector-primitives dependency. Consumers needing non-mutating index iteration can use `(.zero..<count).forEach` via direct vector-primitives import or manual index loop.
