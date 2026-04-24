# Array Name Shadowing and @_exported Import Precedence

<!--
---
version: 2.0.0
last_updated: 2026-04-04
status: DECISION
---
-->

## Context

The ecosystem's `Array<Element: ~Copyable>` in `Array_Primitives_Core` shadows
`Swift.Array`. Throughout the ecosystem, code uses full disambiguation:

- `Array_Primitives_Core.Array` — when the custom type is intended
- `Swift.Array` — when the stdlib type is intended

This disambiguation is verbose and disproportionately costly given that most code
in the ecosystem _means_ the custom `Array` when it says `Array`.

The desired behavior: importing `Array_Primitives` should make bare `Array` resolve
to the custom type. `Swift.Array` should require explicit qualification only when
the stdlib type is actually needed.

### Current Module Structure

```
Array_Primitives (umbrella)
├── @_exported import Array_Primitives_Core      ← type definition (Array<E>)
├── @_exported import Array_Dynamic_Primitives   ← .append(), .drain(), Sequence/Collection
├── @_exported import Array_Fixed_Primitives     ← subscripts, iterators for .Fixed
├── @_exported import Array_Static_Primitives
├── @_exported import Array_Small_Primitives
└── @_exported import Array_Bounded_Primitives   ← also @_exported imports Core

Array_Primitives_Core (type definition)
├── @_exported import Standard_Library_Extensions
├── @_exported import Bit_Primitives
├── @_exported import Index_Primitives
├── @_exported import Collection_Primitives
├── @_exported import Buffer_Linear_Primitives
├── @_exported import Buffer_Linear_Inline_Primitives
├── @_exported import Ordinal_Primitives
└── @_exported import Cardinal_Primitives
```

## Question

1. In which contexts does `@_exported import` give the re-exported `Array` type
   sufficient precedence to shadow `Swift.Array`?
2. Can we eliminate the need for `Array_Primitives_Core.Array` disambiguation by
   restructuring the export mechanism?

## Analysis

### Swift Name Resolution Order

Swift's unqualified name lookup proceeds in this order:

1. **Local scope** — function parameters, local bindings
2. **Type scope** — members, extensions of the enclosing type
3. **Current module** — types/functions declared in the module being compiled
4. **Explicitly imported modules** — via `import M`
5. **Implicitly imported module** — the `Swift` standard library

When a name is found at multiple levels, the higher-priority level wins. The `Swift`
module is implicitly imported at the _lowest_ precedence. Any explicitly imported
module providing the same name shadows it.

### The @_exported Question

`@_exported import M` in module U makes M's declarations visible to U's consumers.
The critical question: when consumer C does `import U`, does M's `Array` appear at
the _same_ precedence level as U's own declarations, or at a lower (transitively
imported) level?

**Hypothesis A**: `@_exported` makes re-exported symbols appear at the "explicitly
imported" level, shadowing `Swift.Array` (implicit level).

**Hypothesis B**: `@_exported` makes symbols _visible_ but at lower precedence than
explicitly imported symbols, requiring disambiguation.

**Hypothesis C**: The behavior differs by context — extension declarations, type
expressions, and generic constraints may have different lookup rules.

### Experimental Results

Companion experiment: `swift-institute/Experiments/exported-import-name-shadowing/`

**Hypothesis A is CONFIRMED across all tested scenarios.** Bare `Array` resolves
to `Core.Array` (the custom type) in every context tested:

| Scenario | Chain depth | Result |
|----------|-------------|--------|
| 1. Umbrella (`@_exported import Core`) | 1 level | Core.Array — all contexts ✓ |
| 2. Direct `import Core` | 0 levels | Core.Array — all contexts ✓ |
| 3. Umbrella + typealias | 1 level | Core.Array — unnecessary; @_exported suffices ✓ |
| 4. Deep chain (3 levels of `@_exported`) | 3 levels | Core.Array — all contexts ✓ |
| 5. Multi-path (2 siblings re-exporting Core) | 2 paths | Core.Array — no ambiguity ✓ |
| 6. Edge cases (conformances, sugar) | 1 level | Core.Array in all type contexts ✓ |
| 7. Type identity verification | 1 level | `[T]` = Swift.Array, `Array<T>` = Core.Array ✓ |

**Contexts tested per scenario:**
- Expression context: `let x = Array<Int>()`
- Custom API access: `Array<Int>.isCustom` (only exists on Core.Array)
- Nested type access: `Array<Int>.Nested()`
- Type annotation: `let x: Array<Int> = ...`
- Generic return type: `func f() -> Array<T>`
- Extension declaration: `extension Array { ... }`
- Protocol conformance: `extension Array: CustomStringConvertible`
- Conditional conformance: `extension Array: Equatable where Element: Equatable`

**Key finding on `[T]` sugar:**
- `[T]` is syntactic sugar hardwired to `Swift.Array<T>` — it is NOT affected by
  name shadowing
- `Array<T>` resolves to `Core.Array<T>` (the custom type)
- These are truly distinct types — assigning `[Int]` to `Array<Int>` is a type error
- `Swift.Array<T>` remains accessible with explicit qualification

### Options Re-evaluated

| Option | Verdict |
|--------|---------|
| 1. Umbrella typealias | **Unnecessary** — @_exported already provides precedence |
| 2. Core typealias | **Unnecessary** |
| 3. Selective @_exported | **Unnecessary** |
| 4. Status quo + remove defensive qualifications | **CHOSEN** |

## Outcome

**Status**: DECISION

**The existing `@_exported import` pattern already works.** The
`Array_Primitives_Core.Array` qualifications throughout the ecosystem are
defensive — they were never required by the compiler. Bare `Array` already
resolves to the custom type in all contexts when any module in the `@_exported`
chain is imported.

### Action Items

1. **Remove `Array_Primitives_Core.Array` qualifications** in source code where
   bare `Array` suffices. The two active instances in `swift-array-primitives`:
   - `Array+ExpressibleByArrayLiteral.swift:3`: `extension Array_Primitives_Core.Array:` → `extension Array:`
   - `Array.Dynamic.swift:52`: `Array_Primitives_Core.Array<Element>` → `Self`

2. **Update documentation** in `Array.swift:22-23`:
   - Old: "Use `Swift.Array` or `Array_Primitives_Core.Array` to disambiguate"
   - New: Bare `Array` resolves to this type; use `Swift.Array` for stdlib

3. **Audit ecosystem** for other `Array_Primitives_Core.Array` or
   `Array_Primitives.Array` qualifications that can be simplified

4. **Keep `Swift.Array` qualifications** — these are correct and intentional
   (e.g., `Swift.Array(tree.preOrder)` in tree-primitives, `Swift.Array(self.prefix(10))`
   in bitset-primitives)

### Convention

When importing any module that re-exports `Array_Primitives_Core`:
- **Bare `Array`** → resolves to the ecosystem's `Array<Element: ~Copyable>`
- **`Swift.Array`** → required when stdlib Array is specifically needed
- **`[T]` sugar** → always `Swift.Array<T>` (compiler-hardwired, unaffected by shadowing)
- **`Array_Primitives_Core.Array`** → never needed; remove from codebase

## References

- Experiment: `swift-institute/Experiments/exported-import-name-shadowing/`
- [SE-0444: Member Import Visibility](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md)
- `swift-array-primitives/Sources/Array Primitives/exports.swift` — umbrella exports
- `swift-array-primitives/Sources/Array Primitives Core/Array.swift` — type definition
