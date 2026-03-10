<!--
---
version: 1.1.0
last_updated: 2026-03-10
status: SUPERSEDED
---
-->

# Investigation: Tagged Extension Duplication

## Problem Statement

For each primitive type (Cardinal, Ordinal, etc.), we currently need:
- `Tagged+{Type}.swift` - basic extensions
- `Tagged+{Type}.Add.swift` - addition operations
- `Tagged+{Type}.Subtract.swift` - subtraction operations

This scales linearly: N types × M operations = N×M files of near-identical boilerplate.

---

## Investigation Status: [EXP-004a] Incremental Construction

Following the Experiment Investigation methodology, exploring protocol-based generalization.

---

## Findings from Codebase Exploration

### Existing Proof: Protocol Constraints on RawValue Work

`/Users/coen/Developer/swift-primitives/swift-dimension-primitives/Sources/Dimension Primitives/Tagged+Arithmatic.swift:43`:
```swift
extension Tagged where RawValue: AdditiveArithmetic {
    @inlinable
    public static var zero: Self {
        Self(__unchecked: (), .zero)
    }
}
```

This proves `where RawValue: SomeProtocol` constraints work in Tagged extensions.

---

## Two Architectural Options

### Option A: Per-Type Nested Tags (Current Pattern)

Each type defines its own nested tag:
```swift
extension Tagged where RawValue == Cardinal {
    public enum Add {}      // Tagged<T, Cardinal>.Add
    public enum Subtract {} // Tagged<T, Cardinal>.Subtract
}

extension Tagged where RawValue == Ordinal {
    public enum Add {}      // Tagged<T, Ordinal>.Add - DIFFERENT type
    public enum Subtract {}
}
```

**Problem**: `Tagged<T, Cardinal>.Add` ≠ `Tagged<T, Ordinal>.Add`, so Property extensions cannot be shared.

### Option B: Shared Parameterized Tags (Recommended)

Define tags once, parameterized by type:
```swift
// In a shared module (e.g., swift-arithmetic-primitives or swift-policy-primitives)
public enum Addition<T> {}
public enum Subtraction<T> {}
```

Then:
```swift
extension Tagged where RawValue: PolicyAddable, Tag: ~Copyable {
    @inlinable
    public var add: Property<Addition<RawValue>, Self> {
        Property(self)
    }
}

extension Property {
    @inlinable
    public func saturating<T: ~Copyable, R: PolicyAddable>(_ other: Base) -> Base
    where Tag == Addition<R>, Base == Tagged<T, R> {
        Base(__unchecked: (), R.saturatingAdd(base.rawValue, other.rawValue))
    }
}
```

**Benefit**: Single Property extension works for ALL types conforming to `PolicyAddable`.

---

## Protocol Definitions Required

```swift
public protocol PolicyAddable: ~Copyable {
    associatedtype Error: Swift.Error
    static func saturatingAdd(_ lhs: Self, _ rhs: Self) -> Self
    static func exactAdd(_ lhs: Self, _ rhs: Self) throws(Error) -> Self
}

public protocol PolicySubtractable: ~Copyable {
    associatedtype Error: Swift.Error
    static func saturatingSub(_ lhs: Self, _ rhs: Self) -> Self
    static func exactSub(_ lhs: Self, _ rhs: Self) throws(Error) -> Self
}
```

---

## Scaling Comparison

| Scenario | Current (Per-Type Tags) | Proposed (Shared Tags) |
|----------|------------------------|------------------------|
| Add Cardinal | 3 files (~85 lines) | Protocol impl + 0 extra files |
| Add Ordinal | 3 files (~85 lines) | Protocol impl only (~20 lines) |
| Add Natural | 3 files (~85 lines) | Protocol impl only (~20 lines) |
| **Total for 3 types** | **9 files (~255 lines)** | **1 shared module + 3 protocol impls (~80 lines)** |

---

## Questions Requiring Empirical Verification

1. Does `where Tag == Addition<R>, Base == Tagged<T, R>` compile when `R` is protocol-constrained?
2. Does typed throws (`throws(R.Error)`) preserve the concrete error type?
3. Does this work with `~Copyable` constraints throughout?

---

## Non-Protocol Alternatives

### Option C: Swift Macros (Code Generation)

Define a macro that generates the boilerplate:

```swift
@PolicyArithmetic(add: true, subtract: true)
extension Tagged where RawValue == Cardinal, Tag: ~Copyable {}
```

Expands to:
```swift
extension Tagged where RawValue == Cardinal, Tag: ~Copyable {
    public enum Add {}
    public enum Subtract {}

    @inlinable public var add: Property<Add, Self> { Property(self) }
    @inlinable public var subtract: Property<Subtract, Self> { Property(self) }
}

extension Property where Tag == Tagged<T, Cardinal>.Add, Base == Tagged<T, Cardinal> {
    @inlinable public func saturating(_ other: Base) -> Base { ... }
    @inlinable public func exact(_ other: Base) throws(Cardinal.Error) -> Base { ... }
}
// ... subtract extension
```

**Pros:**
- No runtime overhead
- No protocol boilerplate on the conforming type
- Each type keeps its own nested tags
- Preserves typed throws precisely

**Cons:**
- Requires implementing a Swift macro package
- Less discoverable (implementation hidden in macro expansion)
- Macro debugging can be difficult

### Option D: External Code Generation (gyb/Sourcery)

Use template-based generation:

```
// Tagged+Operations.swift.gyb
% for type in ['Cardinal', 'Ordinal', 'Natural']:
extension Tagged where RawValue == ${type}, Tag: ~Copyable {
    public enum Add {}
    ...
}
% end
```

**Pros:**
- Simple templating
- Full control over generated code

**Cons:**
- External tooling dependency
- Build step complexity
- Generated files in repo (noise)

### Option E: Accept Duplication with Template Files

Keep the current pattern but use a "template" file as reference:

```
Tagged+TEMPLATE.Add.swift.txt  # Copy and adapt for each type
```

**Pros:**
- No tooling or protocol overhead
- Maximum explicitness
- Each type fully independent

**Cons:**
- Linear scaling: N types × M operations files
- Manual sync when patterns change

---

## Comparison Matrix

| Approach | Files for 5 types | Tooling | Type Safety | Discoverability |
|----------|-------------------|---------|-------------|-----------------|
| Current (duplication) | 15 files | None | Full | Excellent |
| Option B (protocols) | 1 shared + 5 impls | None | Full | Good |
| Option C (macros) | 1 macro + 5 usages | Macro pkg | Full | Moderate |
| Option D (gyb) | 1 template | gyb | Full | Moderate |
| Option E (template) | 15 files | None | Full | Excellent |

---

## Recommendation

**For 2-3 types**: Option E (accept duplication) - overhead of alternatives exceeds benefit

**For 4+ types**: Option B (protocols) - proven pattern in Dimension primitives, one-time setup cost

**If protocols are unacceptable**: Option C (macros) - cleanest non-protocol solution

---

## Outcome

**Status**: SUPERSEDED (2026-03-10)
**Superseded by**: `protocol-abstraction-for-phantom-typed-wrappers.md`
This research was absorbed into the protocol abstraction research. It remains as historical rationale.

## Next Step

Create experiment package to verify Option B compiles and behaves correctly before refactoring.
