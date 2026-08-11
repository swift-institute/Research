# Z Constructor Design

<!--
---
version: 1.0.0
last_updated: 2026-02-06
status: DECISION
---
-->

## Context

`Algebra.Z<n>` = `Tagged<Residue<n>, Ordinal>` needs public constructors for creating residue class elements. The current constructors (commented out) accept `Int`, which violates the Swift Institute convention of using domain types (`Ordinal`, `Cardinal`) in public APIs. Additionally, any `init(_ : Int)` would conflict with the inherited `init(_ position: Int) throws(Ordinal.Error)` from `Tagged+Ordinal.swift`.

**Trigger**: Uncommmenting the `Int`-based constructors caused ambiguity with inherited `Tagged<_, Ordinal>` constructors.

## Question

What constructors should `Algebra.Z<n>` provide, using only domain types?

## Inherited Constructors

`Tagged+Ordinal.swift` already provides these on ALL `Tagged<_, Ordinal>`:

| Constructor | Behavior |
|---|---|
| `init(_ position: Ordinal)` | Direct wrap, no validation |
| `init(_ position: Int) throws(Ordinal.Error)` | Checks non-negative, wraps |

For `Algebra.Z<n>`, the inherited `init(_ : Ordinal)` is effectively an unchecked constructor — it accepts any `Ordinal`, including values >= n. This is equivalent to Cyclic's `init(__unchecked:)`.

## Cyclic Constructors (for reference)

`Cyclic.Group.Static<N>.Element` (not Tagged, no inheritance conflicts):

| Constructor | Input | Behavior |
|---|---|---|
| `init(_ position: Ordinal) throws(Error)` | Ordinal | Bounds check |
| `init(__unchecked position: Ordinal)` | Ordinal | No validation |
| `init(wrapping position: Ordinal)` | Ordinal | Modular reduction |

## Analysis

### What construction modes are needed?

1. **Bounds-checked**: Given an `Ordinal`, verify it's in [0, n). Throws if not.
2. **Wrapping/reducing**: Given an `Ordinal`, reduce modulo n. Total function.
3. **Unchecked**: Given an `Ordinal` known to be in bounds. No validation.

### What's already covered by inheritance?

Mode 3 (unchecked) is already covered: `init(_ position: Ordinal)` from `Tagged+Ordinal.swift` wraps any `Ordinal` into `Tagged` without validation.

### What needs to be added?

Modes 1 and 2. Both must avoid signature collision with inherited `init(_ : Ordinal)`.

### Option A: Labeled Constructors

```swift
extension Tagged where Tag: Algebra.Residual, RawValue == Ordinal {
    /// Bounds-checked construction.
    /// - Throws: Error.bounds if residue >= n.
    public init(checking residue: Ordinal) throws(Error) {
        let n = Tag.capacity
        guard residue < Cardinal(UInt(n)) else {
            throw .bounds(residue)
        }
        self.init(__unchecked: (), residue)
    }

    /// Modular reduction. Total for all ordinals.
    public init(wrapping residue: Ordinal) {
        let n = Cardinal(UInt(Tag.capacity))
        self.init(__unchecked: (), residue % n)
    }
}
```

| Criterion | Assessment |
|---|---|
| Conflict with inherited? | No — `checking:` and `wrapping:` labels distinguish |
| Int-free? | Yes — Ordinal only |
| Discoverable? | Good — labels communicate intent |
| Consistent with Cyclic? | `wrapping:` matches; `checking:` replaces unlabeled throwing |

### Option B: Overload Unlabeled with Throws

```swift
extension Tagged where Tag: Algebra.Residual, RawValue == Ordinal {
    public init(_ residue: Ordinal) throws(Error) { ... }
    public init(wrapping residue: Ordinal) { ... }
}
```

Rejected: `init(_ : Ordinal) throws(Error)` vs inherited `init(_ : Ordinal)` (non-throwing). Swift prefers the non-throwing overload in non-`try` contexts, meaning the bounds check is silently skipped. Error-prone.

### Option C: Only Wrapping

Provide only `init(wrapping:)`. If the user wants bounds checking, they check manually before using the inherited unchecked `init(_:)`.

```swift
extension Tagged where Tag: Algebra.Residual, RawValue == Ordinal {
    public init(wrapping residue: Ordinal) { ... }
}
```

| Criterion | Assessment |
|---|---|
| Minimal API | Yes — one constructor |
| Bounds-checked path? | Manual — user must check themselves |
| Sufficient? | Arguably — `.zero`, `.one`, arithmetic, and `wrapping` cover most use cases |

## Error Type Consideration

The current `Error.bounds(Int)` uses `Int` as the associated value. With Ordinal-based constructors, this should become `Error.bounds(Ordinal)` for consistency.

The `Error.modulus` case (n <= 0) is unnecessary when the modulus is a compile-time generic parameter `let n: Int`. The type `Algebra.Z<0>` or `Algebra.Z<-1>` could be handled via precondition rather than a thrown error — the programmer chose the modulus at compile time. However, this is better addressed separately since `Error` is shared with runtime arithmetic operations.

## Evaluation

| Criterion | Weight | Option A | Option B | Option C |
|---|---|---|---|---|
| No ambiguity | Critical | Clean | Dangerous | Clean |
| No Int | Critical | Yes | Yes | Yes |
| Discoverable API | High | Two clear entry points | Confusing overloads | Minimal |
| Bounds-checked path | Medium | Explicit | Fragile | Manual |
| API surface size | Low | Two constructors | Two constructors | One constructor |

## Decision

**Option A: Labeled constructors with Ordinal.**

```swift
extension Tagged where Tag: Algebra.Residual, RawValue == Ordinal {
    /// Creates a residue class element with bounds checking.
    ///
    /// - Parameter residue: Must be in [0, n).
    /// - Throws: `Error.bounds` if residue >= n.
    @inlinable
    public init(checking residue: Ordinal) throws(Error) {
        let n = Cardinal(UInt(Tag.capacity))
        guard residue < n else {
            throw .bounds(residue)
        }
        self.init(__unchecked: (), residue)
    }

    /// Creates a residue class element via modular reduction.
    ///
    /// Reduces any ordinal to its canonical representative in [0, n).
    /// Total function — never throws.
    ///
    /// - Parameter residue: Any ordinal value.
    @inlinable
    public init(wrapping residue: Ordinal) {
        let n = Cardinal(UInt(Tag.capacity))
        self.init(__unchecked: (), residue % n)
    }
}
```

### Construction modes summary for Algebra.Z<n>

| Mode | Syntax | Source |
|---|---|---|
| Unchecked | `Algebra.Z<5>(someOrdinal)` | Inherited from `Tagged+Ordinal` |
| Bounds-checked | `try Algebra.Z<5>(checking: someOrdinal)` | New |
| Wrapping | `Algebra.Z<5>(wrapping: someOrdinal)` | New |
| Identity elements | `.zero`, `.one` | ordinal-primitives / algebra-modular |

### Error type change

`Error.bounds(Int)` → `Error.bounds(Ordinal)` to match.

## References

- `swift-ordinal-primitives/Sources/Ordinal Primitives/Tagged+Ordinal.swift:16-43` — inherited constructors
- `swift-cyclic-primitives/Sources/Cyclic Primitives/Cyclic.Group.Static.swift:86-120` — Cyclic constructors
- `swift-algebra-modular-primitives/Sources/Algebra Modular Primitives/Algebra.Z.Error.swift` — Error type
