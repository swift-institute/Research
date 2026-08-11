# Property.View Protocol Delegation

<!--
---
version: 1.0.0
last_updated: 2026-02-12
status: DECISION
tier: 2
---
-->

## Context

**Trigger**: During implementation of `Bit.Vector.Protocol`, we discovered that Property.View accessors (`pop`, `set`, `clear`) and their methods (`pop.first()`, `set.all()`, `clear.all()`) were duplicated across every conforming type. Each type declared its own `var pop: Property<Tag, Self>.View` accessor and each had a corresponding `extension Property.View where Tag == ..., Base == ConcreteType` with identical method bodies delegating to the same underlying operation.

**Constraints**: Property.View holds `UnsafeMutablePointer<Base>` where `Base: ~Copyable`. The pattern must work for ~Copyable, Copyable, and value-generic conformers. Protocol defaults must provide `_read`/`_modify` coroutines that yield `Property<Tag, Self>.View`.

**Scope**: Primitives-wide. Applies to any package where a `~Copyable` protocol's conformers share verb-as-property operations via Property.View.

## Question

When multiple types conform to a `~Copyable` protocol and share the same Property.View operations, should the Property.View accessors and methods be:

(A) Declared per concrete type with `Base == ConcreteType` constraints, or
(B) Provided as protocol defaults with `Base: Protocol & ~Copyable` constraints?

## Analysis

### Option A: Per-Concrete-Type (Status Quo Ante)

Each conformer declares its own accessor and Property.View extension:

```swift
// Repeated for EVERY conformer
extension Bit.Vector {
    public var pop: Property<Pop, Self>.View {
        mutating _read { yield unsafe Property<Pop, Self>.View(&self) }
        mutating _modify { var view = unsafe ...; yield &view }
    }
}

extension Property.View where Tag == Bit.Vector.Pop, Base == Bit.Vector {
    public func first() -> Bit.Index? {
        unsafe base.pointee.popFirst()
    }
}

// Same again for Bit.Vector.Static...
extension Bit.Vector.Static {
    public var pop: Property<Bit.Vector.Pop, Self>.View { ... }
}

extension Property.View where Tag == Bit.Vector.Pop {
    public func first<let wordCount: Int>()
        -> Bit.Index? where Base == Bit.Vector.Static<wordCount> { ... }
}

// Same again for Bounded, Inline, Dynamic...
```

**Advantages**:
- No protocol required — works for unrelated types sharing a tag
- Per-type specialization is straightforward

**Disadvantages**:
- N accessors + N Property.View extensions for N conformers, all identical
- Adding a new conformer requires copying boilerplate
- Value-generic conformers need awkward method-level `where Base ==` constraints
- Method bodies are identical — pure duplication

### Option B: Protocol Delegation (Chosen)

Protocol provides accessors as defaults. Property.View extensions use protocol constraint:

```swift
// Once, on the protocol
extension MyProtocol where Self: ~Copyable {
    public var pop: Property<Pop, Self>.View {
        mutating _read { yield unsafe Property<Pop, Self>.View(&self) }
        mutating _modify { var view = unsafe ...; yield &view }
    }
}

// Once, with protocol constraint
extension Property.View where Tag == Pop, Base: MyProtocol & ~Copyable {
    public func first() -> Bit.Index? {
        unsafe base.pointee.popFirst()
    }
}

// All conformers get pop.first() automatically. Zero boilerplate per type.
```

**Advantages**:
- Single declaration serves all conformers (current and future)
- Adding a new conformer requires zero Property.View boilerplate
- Value-generic conformers work without method-level `where` constraints
- Per-type specialization still possible: a concrete `Base == ConcreteType` extension can add type-specific methods (e.g., `set.returning(_:)` on Dynamic) that coexist with the protocol-level defaults

**Disadvantages**:
- Requires a protocol — not applicable when types are unrelated
- Protocol must provide the underlying operations as requirements or defaults (e.g., `popFirst()`, `setAll()`, `clearAll()`)

### Option C: Protocol Defaults for Accessors Only

Protocol provides `var pop/set/clear` but Property.View methods remain per-type.

**Rejected**: This eliminates accessor duplication but not method duplication. Methods are where the semantic logic lives. Half-measure with no principled boundary.

## Comparison

| Criterion | A: Per-Type | B: Protocol Delegation | C: Accessors Only |
|-----------|-------------|------------------------|-------------------|
| Boilerplate per conformer | 2 blocks (accessor + extension) per operation | Zero | 1 block (extension) per operation |
| New conformer cost | Copy N accessors + N extensions | Zero | Copy N extensions |
| Value-generic support | Awkward method-level `where` | Automatic | Awkward method-level `where` |
| Per-type specialization | Natural | Additive (concrete extensions coexist) | Natural |
| Protocol requirement | None | Required | Required |
| Tested configurations | Production use | Experiment CONFIRMED: ~Copyable, Copyable, value-generic, `some Protocol` | N/A |

## Compiler Constraints

1. **`where Self: ~Copyable` on protocol extensions**: Required. Without it, the compiler adds implicit `Self: Copyable`, preventing ~Copyable conformers from accessing the defaults.

2. **`Base: Protocol & ~Copyable` on Property.View extensions**: The `& ~Copyable` is required so the extension covers both Copyable and ~Copyable conformers. Without it, `Base` is implicitly `Copyable`-constrained.

3. **Per-type overrides shadow protocol defaults**: If a conformer declares its own `var set: Property<Set, Self>.View`, it shadows the protocol default. Methods on `Property.View where Base == ConcreteType` still resolve through the overriding accessor. **This means per-type overrides are unnecessary when the accessor body is identical** — they can be removed and the protocol default serves the type. Dynamic-specific methods like `set.returning(_:)` (constrained `where Base == Dynamic`) resolve through the protocol-provided accessor because `Self == Dynamic` at the call site.

4. **Backtick escaping for `Protocol` name**: When a protocol is named `` `Protocol` `` inside a namespace (e.g., `Bit.Vector.Protocol`), all usage sites must escape with backticks: `Bit.Vector.\`Protocol\``. Swift interprets unescaped `.Protocol` as the existential metatype.

## Semantic Boundary

Not all operations can be protocol-delegated. The pattern applies when:

- The operation is expressible purely through protocol requirements
- The semantics are identical across all conformers

It does NOT apply when:

- Operations check type-specific state not in the protocol (e.g., bounds-checking against `_count` in container types vs `bitCapacity` in bitmap types)
- Return types differ per conformer (e.g., `ones` returns `Ones.View` vs `Ones.Static<N>` vs `Ones.Bounded`)
- Operations require type-specific initializers or growth behavior

## Outcome

**Status**: DECISION

**Choice**: Option B — Protocol Delegation.

**Implementation**: Implemented in `Bit.Vector.Protocol+defaults.swift`. The protocol provides:
- Three accessor defaults (`var pop`, `var set`, `var clear`) as `_read`/`_modify` coroutines
- Three Property.View extension methods (`pop.first()`, `set.all()`, `clear.all()`) with `Base: Bit.Vector.\`Protocol\` & ~Copyable` constraints

This replaced 5 per-type files (10 extension blocks) with 2 extension blocks (1 for accessors, 3 for methods = 4 total, but in a single conceptual unit).

**Promotion target**: This pattern should be formalized as an implementation rule in the **implementation** skill, extending [IMPL-021] (Property vs Property.View) with guidance on when to use protocol constraints vs concrete type constraints.

**Rule sketch for implementation skill**:

> **[IMPL-02x] Property.View Protocol Delegation**
>
> When a `~Copyable` protocol's conformers share Property.View operations with identical semantics, the accessors and Property.View methods MUST be provided as protocol defaults with `Base: Protocol & ~Copyable` constraints. Per-type accessors MUST NOT duplicate the protocol default. Per-type Property.View extensions MAY add type-specific methods that coexist with protocol-level defaults.

## Validated By

- **Experiment**: `swift-bit-vector-primitives/Experiments/property-view-protocol-constraint/`
  - 6 variants tested: protocol default accessors, protocol-constrained Property.View methods, ~Copyable conformer, Copyable conformer, value-generic conformer, `some Protocol` generic function
  - All CONFIRMED (swift-DEVELOPMENT-SNAPSHOT-2026-02-11-a, macOS 26.0, arm64)
- **Production**: `swift-bit-vector-primitives` — 62 compilation units, 70 tests passing

## References

- [IMPL-020] Verb-as-Property with callAsFunction
- [IMPL-021] Property vs Property.View
- [IMPL-022] _read + _modify for Mutating Property Accessors
- [IMPL-023] Core Logic in Static Methods
- Experiment: `swift-bit-vector-primitives/Experiments/property-view-protocol-constraint/`
- Implementation: `swift-bit-vector-primitives/Sources/.../Bit.Vector.Protocol+defaults.swift`
