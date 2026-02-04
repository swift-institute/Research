# Z.Modulo Ordinal.Finite Migration

## Motivation

`Algebra.Z.Modulo<let n: Int>` currently stores `residue: Int` and manually enforces the [0, n) invariant. This creates a class of bugs when n <= 0: `init(wrapping:)` traps on `value % 0`, and `negated` produces negative residues via `n - residue` when n = 0.

Replacing `residue: Int` with `position: Ordinal.Finite<n>` eliminates this class structurally. `Ordinal.Finite<0>` has no valid values, so `Z.Modulo<0>` becomes uninhabitable by construction. No runtime guard needed.

## Current Design

```swift
extension Algebra.Z {
    @frozen
    public struct Modulo<let n: Int>: Hashable, Comparable, Sendable {
        public let residue: Int  // manually constrained to [0, n)
    }
}
```

- `init(_ residue: Int) throws(Error)` — validates bounds at runtime.
- `init(wrapping value: Int)` — reduces via `%`, requires n > 0 guard.
- `init(__unchecked residue: Int)` — trust-me constructor.
- `negated` — computes `n - residue`, requires n > 0 guard.

## Proposed Design

```swift
extension Algebra.Z {
    @frozen
    public struct Modulo<let n: Int>: Hashable, Comparable, Sendable {
        public let position: Ordinal.Finite<n>
    }
}
```

The `Finite` type's bounded construction handles the invariant. `Ordinal.Finite<n>` represents values in [0, n) with the bound encoded in the type. `Ordinal.Finite<0>` is uninhabited.

## API Changes

### Storage

- `residue: Int` becomes `position: Ordinal.Finite<n>`.
- `residue` is preserved as a computed property for backward compatibility:

```swift
public var residue: Int { Int(position.rawValue.rawValue) }
```

### Initializers

- `init(wrapping:)` still needs `guard n > 0` for `% 0`, then constructs via `Ordinal.Finite<n>` from the reduced value.
- `init(_ residue: Int) throws(Error)` delegates to `Ordinal.Finite<n>` construction with appropriate error mapping.
- `init(__unchecked:)` wraps an `Ordinal.Finite<n>` directly.

### Arithmetic

Arithmetic operations extract the underlying `UInt` (via `rawValue`), compute in `Int`, and rewrap through `Ordinal.Finite<n>`. The bridging path is:

```
Ordinal.Finite<n> -> Ordinal -> UInt -> Int -> (compute) -> Int -> UInt -> Ordinal -> Ordinal.Finite<n>
```

### Finite.Enumerable

Conformance becomes trivial: delegates entirely to `Ordinal.Finite<n>`, which already conforms to `Finite.Enumerable`.

## Tradeoffs

**Benefits:**
- The [0, n) invariant is type-enforced. No runtime guards for n <= 0 in arithmetic.
- `Z.Modulo<0>` is uninhabited by construction. No special-case logic.
- `Finite.Enumerable` conformance is delegation, not reimplementation.

**Costs:**
- More indirection in arithmetic (UInt <-> Int bridging at each operation).
- The `Ordinal -> UInt -> Int` conversion path adds conceptual overhead.
- Slightly larger API surface for the same semantic content.

## Migration Path

Internal change only. If `residue` is preserved as a computed property returning `Int(position.rawValue.rawValue)`, all existing call sites and tests continue to work without modification.

The only breaking change would be if clients match against the stored property directly (e.g., in mirror-based serialization), which is unlikely for a `@frozen` struct with a single field.

## Open Question

Should `Z.Modulo<0>` be:

1. **An uninhabited type** (current `Finite<0>` behavior) — `Z.Modulo<0>` has no valid instances. Any attempt to create one is a type error or runtime trap. This is the natural consequence of the migration.

2. **A compile-time error** — requires Swift language support for `where n > 0` constraints on value generics. Not currently available.

Option 1 is achievable today and is the recommended path. Option 2 would be strictly better but depends on language evolution.
