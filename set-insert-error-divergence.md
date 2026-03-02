# Set Insert Error Divergence

<!--
---
version: 1.0.0
last_updated: 2026-03-02
status: DECISION
tier: 2
---
-->

## Context

`Set.Protocol` (`__SetProtocol`) provides 10 defaults from 3 requirements (`contains`, `forEach`, `count`). Non-mutating algebra operations (`union`, `intersection`, `subtract`, `symmetricDifference`) compose from `forEach` + `contains` and return `Set.Ordered` — C1 does not block them. See `set-protocol-requirements.md` (v3.0.0, DECISION).

**C1** (insert error divergence) blocks mutating algebra (`formUnion`, `formSymmetricDifference`) from being protocol defaults. The `insert` method has three dimensions of divergence across the four set variants.

**Trigger**: After implementing Option C (count + algebra defaults), the remaining question is whether C1 can be resolved to unlock mutating algebra or self-returning algebra operations.

## Question

Can `insert` signatures be unified across all four set variants? If so, what protocol hierarchy enables mutating algebra as protocol defaults?

## Analysis

### Signature Inventory

**insert** — three dimensions of divergence:

| Variant | Throws | Error type | Return index |
|---------|--------|-----------|-------------|
| Ordered | No | — | `Index<Element>` |
| Fixed | Yes | `__SetOrderedFixedError<Element>` | `Index<Element>` |
| Static | Yes | `__SetOrderedInlineError<Element>` | `Index<Element>.Bounded<capacity>` |
| Small | No | — | `Index<Element>` |

| Dimension | Variants affected | Nature |
|-----------|------------------|--------|
| D1: Throwing vs non-throwing | Fixed, Static throw; Ordered, Small don't | Growable vs bounded storage |
| D2: Error type divergence | Fixed and Static use different error types | Variant-specific overflow semantics |
| D3: Return index type | Static returns `Bounded<capacity>`, others return `Index<Element>` | Compile-time capacity bound |

**remove** — fully uniform:

All four: `mutating func remove(_ element: Element) -> Element?`. No divergence.

### What C1 Resolution Would Unlock

| Operation | Requires | Current status | C1 resolution enables |
|-----------|----------|---------------|----------------------|
| `formUnion` | `insert` on self | Not available | Default on Set.Growable/Mutable |
| `formSymmetricDifference` | `insert` + `remove` on self | Not available | Default on Set.Growable/Mutable |
| `formSubtract` | `remove` on self | Not available | Already unlockable via `remove` alone |
| `formIntersection` | `remove` on self | Not available | Already unlockable via `remove` alone |
| `intersection` → Self | `init()` + `insert` | Returns `Set.Ordered` | Self-returning on conformers |
| `subtract` → Self | `init()` + `insert` | Returns `Set.Ordered` | Self-returning on conformers |

Key observation: `formSubtract` and `formIntersection` only need `remove` (which is uniform). They don't need C1 resolution at all.

### D1 Resolution: Growable vs Bounded

D1 (throwing vs non-throwing) reflects a genuine architectural difference:

- **Growable** (Ordered, Small): insert always succeeds (storage expands)
- **Bounded** (Fixed, Static): insert may fail (capacity exceeded)

This is not a workaround or legacy — it's the defining characteristic of bounded storage. A protocol that requires non-throwing `insert` cannot accommodate bounded variants. A protocol that requires throwing `insert` forces unnecessary `try` on growable variants.

**Resolution path**: `associatedtype InsertError: Error` with typed throws.

```swift
protocol __SetGrowableProtocol: __SetMutableProtocol {
    associatedtype InsertError: Error
    @discardableResult
    mutating func insert(_ element: Element) throws(InsertError) -> (inserted: Bool, index: Index<Element>)
}
```

Ordered/Small: `InsertError = Never` → `throws(Never)` → non-throwing at call site.
Fixed: `InsertError = __SetOrderedFixedError<Element>` → `throws` at call site.

This handles D1 and D2 cleanly.

### D3 Resolution: Bounded Index

Static's `insert` returns `Index<Element>.Bounded<capacity>`, not `Index<Element>`. This is a compile-time guarantee that the index is within bounds.

If the protocol requirement specifies `Index<Element>`, Static needs a witness that returns `Index<Element>`. Two paths:

**Path A**: Static provides a second `insert` overload returning `Index<Element>`:

The bounded index can be converted to an unbounded index (it's a narrowing guarantee, not a different type). Static would have two overloads: the concrete `insert` returning `Bounded<capacity>` and the protocol witness returning `Index<Element>`.

**Path B**: The protocol uses an associated type for the index:

```swift
associatedtype InsertIndex
mutating func insert(_ element: Element) throws(InsertError) -> (inserted: Bool, index: InsertIndex)
```

This complicates generic code — callers can't use the index without knowing its type.

**Path C**: The protocol discards the index entirely:

```swift
@discardableResult
mutating func insert(_ element: Element) throws(InsertError) -> Bool
```

Simplest, but loses information. The `@discardableResult` pattern (used by Swift.SetAlgebra) returns the full tuple but allows ignoring it. A `Bool`-only requirement would require wrapper methods on each variant.

**Evaluation**: Path A is the cleanest. Adding an unbounded overload to Static is a concrete change (one method), and the bounded version remains available for direct Static usage. The protocol witness uses the unbounded overload.

### Option A: Two-Tier Refinement (Set.Mutable + Set.Growable)

```swift
// Tier 2: remove-only mutation
public protocol __SetMutableProtocol: __SetProtocol & ~Copyable {
    mutating func remove(_ element: Element) -> Element?
}

extension Set where Element: ~Copyable {
    public typealias Mutable = __SetMutableProtocol
}

// Tier 3: full mutation (growable)
public protocol __SetGrowableProtocol: __SetMutableProtocol & ~Copyable {
    @discardableResult
    mutating func insert(_ element: Element) -> (inserted: Bool, index: Index<Element>)
}

extension Set where Element: ~Copyable {
    public typealias Growable = __SetGrowableProtocol
}
```

**Conformances**:

| Variant | Set.Protocol | Set.Mutable | Set.Growable |
|---------|-------------|------------|-------------|
| Ordered | Unconditional | `where Element: Copyable` | `where Element: Copyable` |
| Fixed | Unconditional | `where Element: Copyable` | No — insert throws |
| Static | Unconditional | Unconditional | No — insert throws |
| Small | Unconditional | `where Element: Copyable` | `where Element: Copyable` |

**Defaults on Set.Mutable** (2):
- `formSubtract` — iterate other, remove from self
- `formIntersection` — collect non-members, remove from self

**Defaults on Set.Growable** (2):
- `formUnion` — iterate other, insert into self
- `formSymmetricDifference` — collect elements in one-but-not-both, then insert/remove

**Pros**:
- Honest about architectural difference: growable vs bounded
- `remove` uniformity exploited immediately
- Fixed/Static excluded from Growable — correct (can't grow)
- `formSubtract`/`formIntersection` available on ALL four variants

**Cons**:
- 2 new protocols, 2 new typealiases, 8 new conformance declarations
- Only 4 new defaults total
- Architectural complexity for limited gain
- `formIntersection` needs temporary storage (can't remove during forEach)

### Option B: Single Refinement (Set.Mutable only)

Only add `Set.Mutable` with `remove`. Skip `Set.Growable`.

```swift
public protocol __SetMutableProtocol: __SetProtocol & ~Copyable {
    mutating func remove(_ element: Element) -> Element?
}
```

**Defaults** (2):
- `formSubtract` — `other.forEach { element in _ = self.remove(element) }`
- `formIntersection` — collect non-members, remove

**Pros**:
- 1 protocol, simpler
- `remove` is genuinely uniform — no D1/D2/D3 issues
- Ships without resolving C1

**Cons**:
- No `formUnion`, `formSymmetricDifference`
- Same architectural investment as Option A minus 2 defaults

### Option C: Accept Divergence (Status Quo)

Don't create refinement protocols. Non-mutating algebra (already implemented) covers all practical use cases. Mutating algebra added as concrete methods on individual variants when needed.

**Rationale**:
- Non-mutating `subtract` returning `Set.Ordered` covers 90%+ of use cases
- `formSubtract` (mutating) is easily written at the call site: `other.forEach { _ = self.remove($0) }`
- `formUnion` for growable variants is trivially: `other.forEach { self.insert($0) }`
- Protocol-level mutating defaults add complexity for rarely-used operations
- The Array.Protocol precedent: primitives protocols unify READ operations, not mutations

### Comparison

| Criterion | A: Mutable + Growable | B: Mutable only | C: Status quo |
|-----------|----------------------|-----------------|---------------|
| New protocols | 2 | 1 | 0 |
| New conformances | 8 | 4 | 0 |
| New defaults | 4 | 2 | 0 |
| C1 resolved | Partially (Growable excludes Fixed/Static) | N/A | No |
| Mutation on Fixed/Static | `formSubtract`, `formIntersection` | Same | None |
| Mutation on Ordered/Small | All 4 form* operations | `formSubtract`, `formIntersection` | None |
| Architectural complexity | High | Medium | None |
| Precedent alignment | No precedent (Array.Protocol has no Mutable) | No precedent | Matches Array.Protocol |

### Value Assessment

The practical demand for mutating protocol defaults is low:

1. **Concrete mutating methods exist**: Each variant already has concrete `insert` and `remove`. Code working with a specific variant type can call them directly.

2. **Generic code over sets is primarily read-only**: The value of `Set.Protocol` is writing functions like `func overlap<A: Set.Protocol, B: Set.Protocol>(_ a: A, _ b: B) -> Bool` — these are read operations. Generic code that mutates sets is rare (you usually know the concrete type when mutating).

3. **Non-mutating algebra covers the generic case**: `fixed.intersection(ordered)` returning `Set.Ordered` is sufficient. The caller can then construct a `Fixed` from the result if needed.

4. **Array.Protocol precedent**: `Array.Protocol` does NOT provide `append`, `remove`, or mutating operations, even though all array variants have them with uniform signatures. The design principle: primitives protocols unify queries, not mutations.

## Outcome

**Decision**: Option C — Accept divergence. C1 is a well-understood constraint that correctly reflects the architectural difference between growable and bounded sets.

### Rationale

1. **C1 is not a bug**: The insert divergence (throwing vs non-throwing, different error types, bounded vs unbounded index) reflects genuine semantic differences between set variants. Growable sets (Ordered, Small) guarantee insertion succeeds. Bounded sets (Fixed, Static) may reject insertions. A protocol that erases this distinction loses safety information.

2. **Non-mutating algebra is implemented**: 4 algebra defaults returning `Set.Ordered` are available on all variants via the protocol. This is the correct generic interface — algebra over heterogeneous set types should produce a growable result.

3. **Mutating operations are concrete**: When working with a known variant type, concrete `insert`/`remove` methods are available with their correct signatures. The protocol doesn't need to provide these.

4. **Low demand, high cost**: 2 refinement protocols + 8 conformances for 4 defaults that are trivially written at the call site. The architectural complexity is not justified.

5. **Precedent**: Array.Protocol provides read-only access (subscript + Collection.Bidirectional). It does not attempt to unify `append`, `insert`, or `remove` across array variants. This is the correct precedent for primitives protocols.

### Future Considerations

If demand for generic mutating set operations materializes, **Option B (Set.Mutable with remove-only)** is the recommended first step:
- `remove` is uniform — zero unification issues
- Enables `formSubtract` and `formIntersection`
- Does not require resolving C1
- Additive: compatible with current Set.Protocol

`Set.Growable` (Option A) should only be pursued if generic `formUnion` across multiple set types becomes a demonstrated need.

## References

- `set-protocol-abstraction.md` — v2.1.0, DECISION. C1 originally identified here.
- `set-protocol-requirements.md` — v3.0.0, DECISION. Option D2 (Set.Mutable) analysis, compositional tiers.
- `Set.Ordered.Error.swift` — error type declarations.
- Swift stdlib `SetAlgebra.swift` — `insert` returns `(inserted: Bool, memberAfterInsert: Element)`, non-throwing.
- Array.Protocol — read-only precedent (no mutating operations in protocol).
