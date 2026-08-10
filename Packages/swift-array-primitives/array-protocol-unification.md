# Array Protocol Unification

<!--
---
version: 1.1.0
last_updated: 2026-02-23
status: RECOMMENDATION
tier: 7
---
-->

## Context

`Array` has 5 variants (Dynamic, Fixed, Static, Small, Bounded) that share navigation and sizing operations but implement them independently. This creates:

1. **Implementation duplication**: `count`, `isEmpty`, `startIndex`, `endIndex`, `index(after:)`, `index(before:)`, `withElement`, `subscript`, `forEachIndex` are reimplemented in each variant with near-identical logic.

2. **API gaps**: `Array.Bounded` is a stub with 0% public API coverage. When operations are added to one variant, others may not receive them.

3. **No generic consumer code**: Functions that only need navigation/sizing (e.g., algorithms that iterate by index) cannot abstract over "any Array variant."

**Trigger**: Operations audit (`Research/array-operations-audit.md`, 2026-02-16) identified systematic duplication across all 5 variants and complete absence of public API on `Array.Bounded`.

## Question

How should common array operations be shared across all 5 variants to eliminate duplication, prevent API gaps, and enable generic navigation code?

## Constraints

| Constraint | Impact |
|-----------|--------|
| `Array<Element: ~Copyable>` is generic | Protocol Self must support `~Copyable` |
| `associatedtype Element: ~Copyable` NOT supported | Protocol CANNOT include Element-typed operations (subscript, withElement, forEach) |
| `Array.Bounded<N>` uses `Algebra.Z<N>` index | Protocol needs `associatedtype Index` to accommodate different index types |
| `Array.Static<N>` and `Array.Small<N>` have value generics | Protocol conformance for value-generic types must work |
| Protocol subscript { _read _modify } NOT supported | Protocols only support `{ get set }` accessor declarations |
| Some operations are variant-specific | `append`/`removeLast` only on variable-count types |
| Production types use `Index<Element>` (typed index) | Protocol's `count` type must be plain `Int` or typed `Index.Count` |

### Critical Limitation: No ~Copyable Associated Types

Swift 6.2 does NOT support `associatedtype Element: ~Copyable`. This was tested with and without `.enableExperimentalFeature("NoncopyableGenerics")`. The error:

```
error: cannot suppress 'Copyable' requirement of an associated type
```

**Consequence**: The protocol can unify **navigation and sizing** but NOT element access. Subscript, `withElement`, `forEach`, and any operation that returns or borrows `Element` must remain per-variant.

This differs from `Bit.Vector.Protocol`, where `Element` was always `Bool` (Copyable), allowing subscript to be a protocol requirement.

A refined protocol with `associatedtype Element` (implicitly Copyable) was also tested but is not viable: ~Copyable types cannot conform to it, defeating the purpose of unification.

## Analysis

### Option A: `Array.Protocol` — Navigation + Sizing Protocol

Define a `~Copyable` protocol that unifies the operations that do NOT depend on `Element`:

```swift
public protocol __ArrayProtocol: ~Copyable {
    associatedtype Index: Comparable
    var count: Int { get }
    var startIndex: Index { get }
    var endIndex: Index { get }
    func index(after i: Index) -> Index
    func index(before i: Index) -> Index
}

extension Array {
    public typealias `Protocol` = __ArrayProtocol
}
```

**Default implementations** (via `extension __ArrayProtocol where Self: ~Copyable`):

| Operation | Category | Implementation |
|-----------|----------|----------------|
| `isEmpty` | Read-only | `count == 0` (or typed: `count == .zero`) |
| `forEachIndex` | Index iteration | Walk from startIndex to endIndex |
| `indices` | Index collection | Collect via `forEachIndex` |

**Per-conformer requirements** (5 declarations each):

| Requirement | Lines | Notes |
|------------|-------|-------|
| `count` | 1 | Delegate to buffer |
| `startIndex` | 1 | `.zero` for most; `Index(0)` for Bounded |
| `endIndex` | 1 | `count.map(Ordinal.init)` for most |
| `index(after:)` | 1 | Successor operation |
| `index(before:)` | 1 | Predecessor operation |

**Advantages**:
- Works for ALL variants including ~Copyable types
- Default `isEmpty` eliminates duplication
- `forEachIndex` enables generic index-based iteration
- Enforces API parity for navigation at compile time
- Generic functions `<V: Array.Protocol & ~Copyable>` work
- Borrowing generic functions work
- Different Index types (Int vs BoundedIndex) via associated type

**Disadvantages**:
- Cannot include subscript or element-typed operations
- Less powerful than Bit.Vector.Protocol (which unified subscript)
- Navigation-only — most of the "interesting" operations stay per-variant
- Small deduplication benefit (5 one-liners × 5 variants = 25 lines saved)

### Option B: Static Methods on Shared Namespace

Instead of a protocol, provide static navigation functions. Each variant calls these from its own methods.

**Advantages**:
- Zero protocol overhead
- No compiler limitations
- No `~Copyable` complications

**Disadvantages**:
- Navigation functions are already trivial (one-liners)
- No generic consumer code
- No compile-time API parity enforcement
- Adds complexity without clear benefit

### Option C: Macro-Based Code Generation

Use Swift macros to generate the duplicated methods.

**Advantages**:
- Zero runtime overhead
- Could generate element-typed operations too

**Disadvantages**:
- Macros add build complexity
- Not used elsewhere in Swift Institute
- Over-engineered for the problem size

### Option D: Status Quo with Targeted Additions

Keep current approach. When a variant lacks an operation, add it to that variant.

**Advantages**:
- No architectural changes
- Each addition is small

**Disadvantages**:
- Duplication continues
- No generic navigation code
- API gaps persist (Bounded has 0% coverage)

## Comparison

| Criterion | A: Protocol | B: Static | C: Macros | D: Status Quo |
|-----------|:-----------:|:---------:|:---------:|:-------------:|
| Eliminates nav duplication | Full | Partial | Full | No |
| Element access unification | No | No | Yes | No |
| ~Copyable compatibility | Yes | N/A | Yes | N/A |
| Complexity to implement | Low | Low | High | None |
| API parity enforcement | Compile-time | Manual | Compile-time | Manual |
| Generic consumer code | Yes | No | No | No |
| Deduplication scope | Navigation only | Navigation only | All operations | None |

## Recommendation

**Option A: `Array.Protocol`** — empirically validated via experiment.

### Experiment Results

`Experiments/array-protocol/` — **CONFIRMED** on Swift 6.2.

A `~Copyable` protocol with `associatedtype Index: Comparable` and `where Self: ~Copyable` default extensions works today. Navigation and sizing operations compile and run correctly across:

- ~Copyable types (stand-in for `Array`, `Array.Static`, `Array.Small`)
- Copyable types (stand-in for `Array.Fixed`)
- Value-generic types (stand-in for `Array.Static<N>`, `Array.Bounded<N>`)
- Generic functions with `<V: __ArrayProtocol & ~Copyable>`
- Borrowing generic functions for read-only access
- Types with different Index types (Int vs BoundedIndex<N>)
- ~Copyable elements (navigation works; element access stays per-variant)

### Protocol Shape

```swift
public protocol __ArrayProtocol: ~Copyable {
    associatedtype Index: Comparable
    var count: Index.Count { get }
    var startIndex: Index { get }
    var endIndex: Index { get }
    func index(after i: Index) -> Index
    func index(before i: Index) -> Index
}

extension Array {
    public typealias `Protocol` = __ArrayProtocol
}
```

### Advantages Over Status Quo

1. **Compile-time parity enforcement** — adding a new requirement benefits all conformers
2. **Generic navigation code** — functions generic over `Array.Protocol & ~Copyable` work
3. **Default isEmpty** — defined once with canonical semantics
4. **Forced completeness** — `Array.Bounded` must implement all requirements to conform

### Why Less Powerful Than Bit.Vector.Protocol

| Aspect | Bit.Vector | Array |
|--------|-----------|-------|
| Element type | Always `Bool` (Copyable) | Generic `Element: ~Copyable` |
| `associatedtype Element` | Not needed | Not possible (`~Copyable` suppression fails) |
| Subscript in protocol | Yes (requirement, compiler bug workaround) | No (requires Element type) |
| Default operations | 7 (popcount, allFalse, allTrue, ones, clearAll, setAll, popFirst) | 2 (isEmpty, forEachIndex) |
| Deduplication scope | All word-scanning operations | Navigation only |

The fundamental difference: Bit.Vector variants share a **common representation** (UInt words) and a **common element type** (Bool). Array variants share a **common shape** (indexed, counted) but differ in element type, storage, and most operations.

### Negative Results (Documented for Future Reference)

| What was tested | Result | Error message |
|----------------|--------|---------------|
| `associatedtype Element: ~Copyable` | NOT SUPPORTED | "cannot suppress 'Copyable' requirement of an associated type" |
| `.enableExperimentalFeature("NoncopyableGenerics")` | No effect | Same error |
| Refined protocol with `associatedtype Element` | NOT VIABLE | ~Copyable types can't conform |
| Protocol subscript `{ _read _modify }` | NOT SUPPORTED | "expected get or set in a protocol property" |

These should be re-tested when Swift gains support for ~Copyable associated types.

### Implementation Plan

**Phase 1: Protocol definition** in `swift-array-primitives`:
- Define `__ArrayProtocol` in `Sources/Array Primitives Core/`
- Add `extension Array { public typealias Protocol = __ArrayProtocol }`
- Implement default extensions (isEmpty, forEachIndex)

**Phase 2: Conform existing types**:
- `Array` (Dynamic) — conform, verify defaults work
- `Array.Fixed` — conform, verify defaults work
- `Array.Static<capacity>` — conform, verify defaults work
- `Array.Small<inlineCapacity>` — conform, verify defaults work
- `Array.Bounded<N>` — conform (requires implementing count, startIndex, endIndex, index navigation first)

**Phase 3: Complete Array.Bounded**:
- Implement subscript, count, isEmpty, initializer, iteration
- Array.Bounded is the highest-priority gap per the operations audit

**Phase 4: Future — revisit when Swift supports ~Copyable associated types**:
- Add `associatedtype Element: ~Copyable` to protocol
- Move subscript from per-variant to protocol requirement
- Move withElement to protocol default
- Move forEach to protocol default

## References

- `swift-array-primitives/Experiments/array-protocol/` — feasibility experiment (CONFIRMED)
- `swift-array-primitives/Research/array-operations-audit.md` — operations gap analysis
- `swift-bit-vector-primitives/Research/bit-vector-protocol-unification.md` — prior art
- `swift-bit-vector-primitives/Experiments/bit-vector-protocol/` — Bit.Vector experiment
- `swift-effect-primitives/Sources/Effect Primitives/Effect.Protocol.swift` — hoisted protocol pattern

## Changelog

### v1.1.0 (2026-02-23)

**Phase 4 is now unlocked.** `SuppressedAssociatedTypes` (adopted in sequence-primitives on 2026-02-12) enables `associatedtype Element: ~Copyable`. The current `__ArrayProtocol` already has `associatedtype Element: ~Copyable` and subscript access — the "Negative Results" documented in v1.0.0 are resolved.

The remaining blocker for full hierarchy unification is that `Collection.Protocol: Sequence.Protocol` prevents `__ArrayProtocol` from conforming to `Collection.Protocol`. This is addressed by a separate research document: `swift-primitives/Research/collection-sequence-protocol-detachment.md` (RECOMMENDATION, 2026-02-23), which recommends removing `Sequence.Protocol` inheritance from `Collection.Protocol`.

Once the detachment is implemented, `__ArrayProtocol` can conform to `Collection.Protocol` (or `Collection.Bidirectional`), fully unifying the protocol hierarchy.
