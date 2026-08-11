# Bit Vector Protocol Unification

<!--
---
version: 1.1.0
last_updated: 2026-02-12
status: RECOMMENDATION
tier: 2
---
-->

## Context

`Bit.Vector` has 5 variants (Vector, Bounded, Static, Inline, Dynamic) that share conceptual operations but implement them independently. This creates:

1. **API gaps**: `pop.first()` exists only on base `Bit.Vector` — not on Bounded, Static, Inline, or Dynamic. When `Buffer.Slab.Header` moved from `Bit.Vector` to `Bit.Vector.Bounded`, consume files broke because `pop.first()` was unavailable.

2. **Implementation duplication**: `popcount`, `isEmpty`, `isFull`, `ones`, `subscript`, `clearAll`/`setAll`, and `take` are reimplemented in each variant with near-identical word-scanning logic.

3. **Semantic drift**: `isEmpty` means "all bits false" on Vector/Static but means "_count == .zero" on Bounded/Inline/Dynamic. Consumers (Slab.Header) must work around this.

**Trigger**: Buffer-primitives compilation failure after switching `Slab.Header.bitmap` from `Bit.Vector` to `Bit.Vector.Bounded`. The immediate fix required rewriting consume logic because `Bit.Vector.Bounded` lacked `pop.first()`. This is symptomatic of a deeper problem.

## Question

How should common bit-vector operations be shared across all 5 variants to eliminate duplication and prevent API gaps?

## Constraints

| Constraint | Impact |
|-----------|--------|
| `Bit.Vector` is `~Copyable` | Protocol Self must support `~Copyable` — Swift 6 noncopyable generics are still maturing |
| `Bit.Vector.Static<N>` has value generic | Protocol conformance for generic types works, but associated types may complicate |
| `ones` returns different types per variant | Associated type or generic return needed |
| Property.View pattern (`pop`, `set`, `clear`) | Requires mutable pointer access (`&self`) — protocol must enable this |
| All variants store bits in `UInt` words | Common implementation backbone exists at word level |
| Some operations are variant-specific | `append`/`popLast` only on counted types; `resize` only on Dynamic |
| Consumers use concrete types, not generics | Main benefit is deduplication, not generic consumer code |

## Analysis

### Option A: `Bit.Vector.Protocol` — Full Protocol

Define a protocol with all shared operations as requirements.

```swift
extension Bit.Vector {
    public protocol `Protocol`: ~Copyable {
        subscript(index: Bit.Index) -> Bool { get set }
        var popcount: Bit.Index.Count { get }
        var isEmpty: Bool { get }
        var isFull: Bool { get }
        // ... ones, take, pop.first, etc.
    }
}
```

**Advantages**:
- Clean abstraction — each variant conforms, gets shared behavior
- Enables generic consumer code (`func foo<V: Bit.Vector.Protocol>`)
- Follows existing Swift Institute protocol patterns (Sequence.Consume.Protocol, etc.)

**Disadvantages**:
- `~Copyable` protocol conformance has compiler limitations (existential boxes, protocol extensions with mutating methods)
- `ones` returns different types per variant — needs an associated type or erased return
- `pop.first()` uses Property.View pattern requiring `&self` pointer — hard to express in protocol
- All 5 variants would need explicit conformance declarations
- Protocol witness tables add overhead for `@inlinable` code

### Option B: Word-Access Abstraction

All variants store bits in `UInt` words. Provide a minimal word-access protocol, then implement all derived operations as protocol extensions.

```swift
extension Bit.Vector {
    public protocol WordAccessible: ~Copyable {
        var wordCount: Int { get }
        var bitCapacity: Bit.Index.Count { get }
        subscript(wordAt index: Int) -> UInt { get set }
    }
}

extension Bit.Vector.WordAccessible {
    // All derived operations implemented ONCE:
    public var popcount: Bit.Index.Count { ... }
    public var isEmpty: Bool { ... }
    public var isFull: Bool { ... }
    public subscript(index: Bit.Index) -> Bool { get { ... } set { ... } }
    public var ones: Bit.Vector.Ones<Self> { ... }
    // pop.first() via mutating extension
}
```

**Advantages**:
- Minimal conformance burden — each variant only provides word access (3 requirements)
- All derived operations implemented once in protocol extension
- `popcount`, `isEmpty`, `isFull`, `ones`, `pop.first`, `zeros` all derived from word access
- No associated type complexity for return types
- Generic `Ones<Base>` iterator works for all conforming types

**Disadvantages**:
- Word-level subscript must be efficient — protocol witness overhead could hurt for `@inlinable`
- Still faces `~Copyable` protocol limitations
- Less expressive API surface at the protocol level
- Consumers rarely need to abstract over "any word-accessible bitmap"

### Option C: Static Methods on Shared Namespace

Instead of a protocol, provide static functions on `Bit.Vector` that operate on word buffers directly. Each variant calls these from its own methods.

```swift
extension Bit.Vector {
    @inlinable
    public static func popcount(
        words: UnsafeBufferPointer<UInt>,
        capacity: Bit.Index.Count
    ) -> Bit.Index.Count { ... }

    @inlinable
    public static func popFirst(
        words: UnsafeMutableBufferPointer<UInt>,
        capacity: Bit.Index.Count
    ) -> Bit.Index? { ... }

    @inlinable
    public static func ones(
        words: UnsafeBufferPointer<UInt>,
        capacity: Bit.Index.Count
    ) -> Bit.Vector.Ones.View { ... }
}
```

Each variant's methods delegate:

```swift
extension Bit.Vector.Bounded {
    @inlinable
    public var popcount: Bit.Index.Count {
        _storage.withUnsafeBufferPointer { words in
            Bit.Vector.popcount(words: words, capacity: _capacity)
        }
    }
}
```

**Advantages**:
- Zero protocol overhead — all `@inlinable`, direct word access
- No `~Copyable` protocol complications
- Each variant keeps its own API surface (no forced uniformity)
- Shared implementation without shared abstraction
- Works today with no compiler limitations
- Each variant can still have its own `isEmpty` semantics if needed

**Disadvantages**:
- Each variant still declares its own `popcount`, `isEmpty`, etc. (thin wrappers, but still N declarations)
- No generic consumer code possible
- No protocol conformance to check at compile time
- Maintenance burden: adding a new operation requires N wrapper declarations

### Option D: Macro-Based Code Generation

Use Swift macros to generate the duplicated methods.

```swift
@BitVectorOperations
public struct Bounded: Sendable { ... }
```

**Advantages**:
- Zero runtime overhead
- Single source of truth for operation implementations
- Can generate variant-specific specializations

**Disadvantages**:
- Swift macros add build complexity and are harder to debug
- Macros are not widely used in Swift Institute packages
- Generated code is harder to read and review
- Macro dependencies add weight to the package

### Option E: Status Quo with Targeted Additions

Keep the current approach. When a variant lacks an operation, add it to that variant.

**Advantages**:
- No architectural changes needed
- Each addition is small and reviewable
- No compiler limitation concerns

**Disadvantages**:
- Duplication continues to grow (currently ~5x for each new operation)
- Semantic drift persists (isEmpty means different things)
- Every new consumer requirement may trigger compilation failures in other packages
- No systematic way to ensure API parity

## Comparison

| Criterion | A: Protocol | B: Word-Access | C: Static Methods | D: Macros | E: Status Quo |
|-----------|:-----------:|:--------------:|:-----------------:|:---------:|:-------------:|
| Eliminates duplication | Full | Full | Partial (wrappers remain) | Full | No |
| ~Copyable compatibility | Risky | Risky | Safe | Safe | N/A |
| @inlinable performance | Witness overhead | Witness overhead | Zero overhead | Zero overhead | Zero overhead |
| Complexity to implement | High | Medium | Low | High | None |
| API parity enforcement | Compile-time | Compile-time | Manual | Compile-time | Manual |
| Generic consumer code | Yes | Yes | No | No | No |
| Semantic consistency | Enforced | Enforced | Opt-in | Enforced | Uncontrolled |
| Compiler maturity risk | High | High | None | Medium | None |

## Recommendation

**Option A: `Bit.Vector.Protocol`** — empirically validated via experiment.

### Experiment Results

`Experiments/bit-vector-protocol/` — **CONFIRMED** on Swift 6.2.3.

A `~Copyable` protocol with word-level requirements and `where Self: ~Copyable` default extensions works today. All operations — `popcount`, `allFalse`, `allTrue`, `clearAll`, `setAll`, `popFirst` (Wegner/Kernighan), `ones` iterator — compile and run correctly across:

- ~Copyable types (stand-in for `Bit.Vector`)
- Copyable types (stand-in for `Bit.Vector.Bounded`)
- Value-generic types (stand-in for `Bit.Vector.Static<N>`)
- Generic functions with `<V: BitVectorProtocol & ~Copyable>`
- Borrowing generic functions for read-only access

**One compiler bug**: subscript get/set as a default implementation in a `where Self: ~Copyable` extension crashes with "copy of noncopyable typed value" internal error. **Workaround**: declare subscript as a protocol *requirement* instead of a default. Each conformer provides the 5-line subscript implementation. This is acceptable — subscript is the only operation that isn't fully defaulted.

### Protocol Shape

```swift
extension Bit.Vector {
    public protocol `Protocol`: ~Copyable {
        var wordCount: Int { get }
        var bitCapacity: Bit.Index.Count { get }
        borrowing func word(at index: Int) -> UInt
        mutating func setWord(at index: Int, to value: UInt)
        subscript(index: Bit.Index) -> Bool { get set }  // requirement (compiler bug workaround)
    }
}
```

**Default implementations** (via `extension Bit.Vector.Protocol where Self: ~Copyable`):

| Operation | Category | Implementation |
|-----------|----------|----------------|
| `popcount` | Read-only | Hardware popcount per word |
| `allFalse` | Read-only | Word scan for any nonzero |
| `allTrue` | Read-only | Word scan with capacity mask |
| `ones` | Read-only | Copies words, returns `OnesSequence` |
| `clearAll()` | Mutating | Zero all words |
| `setAll()` | Mutating | Set all words with capacity mask |
| `popFirst()` | Mutating | Wegner/Kernighan lowest-bit extraction |

**Per-conformer requirements** (4-5 declarations each):

| Requirement | Lines | Notes |
|------------|-------|-------|
| `wordCount` | 1 | Stored or computed |
| `bitCapacity` | 1 | Stored or computed |
| `word(at:)` | 1 | Delegate to backing storage |
| `setWord(at:to:)` | 1 | Delegate to backing storage |
| `subscript` | 5 | Compiler bug workaround |

### Advantages Over Option C (Static Methods)

The experiment proved Option A works today, making it strictly superior to Option C:

1. **Compile-time parity enforcement** — adding a new default benefits all conformers automatically
2. **Generic consumer code** — functions generic over `Bit.Vector.Protocol & ~Copyable` work
3. **Semantic consistency** — `allFalse`/`allTrue` defined once with canonical semantics
4. **Less code** — ~9 lines per conformer vs ~3 lines × N operations in Option C

### Implementation Plan

**Phase 1: Protocol definition** in `swift-bit-vector-primitives`:
- Define `Bit.Vector.Protocol` with word-level requirements
- Implement all default extensions

**Phase 2: Conform existing types**:
- `Bit.Vector` — conform, remove duplicated method bodies
- `Bit.Vector.Bounded` — conform, remove duplicated method bodies
- `Bit.Vector.Static<N>` — conform, remove duplicated method bodies
- `Bit.Vector.Inline<N>` — conform, remove duplicated method bodies
- `Bit.Vector.Dynamic` — conform, remove duplicated method bodies

**Phase 3: Add missing operations**:
- `pop.first()` (via Property.View pattern) on all variants — delegates to `popFirst()` from protocol
- `zeros` iterator on variants that lack it

**Phase 4: Update consumers**:
- Buffer-primitives consume files: use `popFirst()` instead of linear scan
- Resolve `isEmpty`/`isFull` semantic drift

### Semantic Clarification

The protocol establishes canonical bitmap semantics:

| Property | Meaning | All variants |
|----------|---------|:------------:|
| `popcount` | Number of true bits | Yes |
| `allFalse` | All bits are false (`popcount == .zero`) | Yes |
| `allTrue` | All bits are true up to capacity | Yes |
| `count` | Number of appended bit positions | Counted types only |

Counted types (Bounded, Inline, Dynamic) retain their own `isEmpty`/`isFull` with count-based semantics. The protocol provides `allFalse`/`allTrue` with popcount-based semantics. No conflict — different names, different semantics.

## Compiler Bug

**Bug**: subscript get/set in `extension P where Self: ~Copyable` crashes with "copy of noncopyable typed value. This is a compiler bug."

**Reproduction**: `Experiments/bit-vector-protocol/` — change subscript from requirement to default implementation.

**Workaround**: Declare subscript as protocol requirement. Each conformer provides it.

**Impact**: Minimal. One 5-line implementation per conformer. All other operations default correctly.

## Next Steps

1. Implement `Bit.Vector.Protocol` in `swift-bit-vector-primitives`
2. Conform all 5 variants
3. Update buffer-primitives consume files to use `popFirst()`
4. File Swift compiler bug for subscript get/set in ~Copyable protocol extensions
5. Remove subscript requirement when compiler bug is fixed (make it a default)

## References

- `swift-bit-vector-primitives/Experiments/bit-vector-protocol/` — feasibility experiment (CONFIRMED)
- `swift-buffer-primitives/Sources/Buffer Slab Primitives/Buffer.Slab+Consume.swift` — trigger for this research
- `swift-bit-vector-primitives/Sources/Bit Vector Primitives/Bit.Vector+pop.swift` — existing `pop.first()` on base Vector
- `swift-buffer-primitives/Research/buffer-variant-parity-analysis.md` — prior art on API parity analysis
