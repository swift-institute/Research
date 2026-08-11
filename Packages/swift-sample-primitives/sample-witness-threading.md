# Sample Witness Threading

<!--
---
version: 1.0.0
last_updated: 2026-02-28
status: RECOMMENDATION
tier: 2
---
-->

## Context

The first-principles research ([measurement-first-principles](measurement-first-principles.md)) proposed `Sample<T: Comparable>` with tiered conditional extensions and an `Averageable` protocol for mean computation. However, the Swift Institute ecosystem prefers **value witnesses** over protocols for algebraic capabilities (see ecosystem analysis below). This research investigates how `Sample<T>` should thread witnesses for its statistical operations.

**Trigger**: [RES-001] Pattern selection — the choice between protocol constraints, value witness parameters, and stored witnesses fundamentally shapes the API.
**Scope**: Cross-package — affects how sample-primitives integrates with algebra-primitives and ordering-primitives.

## Question

How should `Sample<T>` provide statistical operations that require capabilities beyond `Comparable` (mean, sum, standard deviation), given the ecosystem preference for value witnesses?

---

## Ecosystem Witness Patterns (Surveyed)

### Pattern 1: Static property witness

Types provide their own algebraic witness as a static computed property:

```swift
// Cardinal+Monoid.swift
extension Cardinal {
    public static var monoid: Algebra.Monoid<Self>.Commutative {
        .init(monoid: .init(identity: .zero, combining: { $0 + $1 }))
    }
}
```

Convenience methods delegate to the witness:

```swift
// Rotation+Algebra.swift
public func concatenating(_ other: Self) -> Self {
    Self.group.combining(self, other)
}
```

### Pattern 2: Witness parameter (the Ordering pattern)

`Ordering.Comparator<T>` is a reified first-class comparator:

```swift
public struct Comparator<T: ~Copyable>: Sendable {
    internal let compare: @Sendable (borrowing T, borrowing T) -> Comparison
}
```

Generic algorithms take it as a parameter:

```swift
// Collection.Min+Property.View.swift
public func index(by comparator: Ordering.Comparator<Base.Element>) -> Base.Index?
```

### Pattern 3: Dual overload (protocol + witness)

The ecosystem provides BOTH protocol-constrained convenience AND witness-parameterized flexibility:

```swift
// Convenience: for Comparison.Protocol types
extension Property.View
where Base.Element: Comparison.`Protocol` {
    public func callAsFunction() -> Base.Element? {
        self(by: .ascending)  // delegates to witness version
    }
}

// Universal: takes witness parameter
extension Property.View {
    public func callAsFunction(by comparator: Ordering.Comparator<Base.Element>) -> Base.Element? {
        // implementation using comparator
    }
}
```

### Pattern 4: Composite witnesses store sub-witnesses

Higher-level witnesses compose lower-level ones:

```swift
public struct Field<Element: Sendable>: Sendable, Witness.`Protocol` {
    public var additive: Algebra.Group<Element>.Abelian     // stored witness
    public var multiplicative: Algebra.Monoid<Element>.Commutative  // stored witness
    public var reciprocal: @Sendable (Element) throws(Error) -> Element
}
```

### Current foundations precedent

`IO.Blocking.Threads.Aggregate` and `Pool.Blocking.Metrics` use **no witness patterns** — plain structs with direct imperative accumulation. The algebra witness infrastructure has not yet been adopted in the foundations layer.

---

## Analysis

### What Sample<T> needs

| Operation | Required capability | Existing witness? |
|-----------|-------------------|------------------|
| min, max, percentile, median | Ordering | `Ordering.Comparator<T>` |
| sorted storage | Ordering | `Ordering.Comparator<T>` |
| sum | Addition + zero | `Algebra.Monoid<T>` (additive) |
| mean | Addition + zero + division by Int | **None** — `Algebra.Module<Int, T>` provides scaling but not division |
| stddev | Double conversion + sqrt | **None** |

### The division-by-Int gap

`Algebra.Module<Int, T>` provides `scaling: (Int, T) -> T` — scalar *multiplication*. Mean needs `T / Int` — scalar *division*. These are related only if Int has multiplicative inverse, which it doesn't (Int is a Ring, not a Field).

`Algebra.VectorSpace<Double, T>` would provide division (fields have inverses), but that requires `T` to be scalable by `Double`, which is too strong — it would exclude `Int`.

There is no existing witness that captures exactly "T / Int."

---

### Option A: New Witness Type (`Sample.Averaging`)

Define a custom witness type specific to sample statistics:

```swift
extension Sample {
    @frozen
    public struct Averaging<Element: Sendable>: Sendable, Witness.`Protocol` {
        public var zero: Element
        public var adding: @Sendable (Element, Element) -> Element
        public var dividing: @Sendable (Element, Int) -> Element
    }
}
```

With static factories for known types:

```swift
extension Sample.Averaging where Element == Duration {
    public static var duration: Self {
        .init(zero: .zero, adding: +, dividing: /)
    }
}
extension Sample.Averaging where Element == Double {
    public static var real: Self {
        .init(zero: 0, adding: +, dividing: { $0 / Double($1) })
    }
}
extension Sample.Averaging where Element == Int {
    public static var integer: Self {
        .init(zero: 0, adding: +, dividing: /)
    }
}
extension Sample.Averaging where Element == UInt64 {
    public static var natural: Self {
        .init(zero: 0, adding: +, dividing: { $0 / UInt64($1) })
    }
}
```

API:

```swift
// Witness parameter version (universal)
sample.mean(using: .duration)    // Duration
sample.mean(using: .real)        // Double
sample.mean(using: .integer)     // Int

// Convenience overloads for common types (dual overload pattern)
extension Sample where Element == Duration {
    public var mean: Duration { mean(using: .duration) }
}
extension Sample where Element == Double {
    public var mean: Double { mean(using: .real) }
}
```

**Advantages:**
- Follows ecosystem witness pattern exactly
- Composable — users define custom witnesses for their own types
- No new protocol — pure value witness
- Dual overload pattern matches Comparison/Ordering precedent
- Custom `Averaging` captures exactly what's needed — no over-abstraction

**Disadvantages:**
- New witness type specific to Sample (not reusable across the algebra hierarchy)
- Convenience overloads needed for ergonomic call sites on common types
- Caller must know which witness to use (`.duration` vs `.real`)

---

### Option B: Algebra.Group Witness for Sum + Closure for Division

Use existing `Algebra.Group<T>.Abelian` for addition/zero, plus a bare closure for division:

```swift
public func mean(
    group: Algebra.Group<Element>.Abelian,
    dividing: @escaping @Sendable (Element, Int) -> Element
) -> Element
```

With convenience:

```swift
extension Sample where Element == Duration {
    public var mean: Duration {
        mean(group: .duration, dividing: /)
    }
}
```

**Advantages:**
- Reuses existing algebra infrastructure for sum
- Division is the only truly new capability

**Disadvantages:**
- Two separate parameters is awkward
- `Algebra.Group<Duration>.Abelian` doesn't exist yet — would need to be defined somewhere
- Mixing witness + bare closure is inconsistent

---

### Option C: Protocol (`Averageable`)

Define a protocol:

```swift
public protocol Averageable: AdditiveArithmetic {
    static func / (lhs: Self, rhs: Int) -> Self
}
extension Duration: Averageable {}
extension Double: Averageable { /* ... */ }
extension Int: Averageable {}
```

API:

```swift
extension Sample where Element: Averageable {
    public var mean: Element { ... }
}
```

**Advantages:**
- Simplest call site: `sample.mean`
- Compile-time safety — `.mean` only available when `Element` supports it
- No witness threading needed

**Disadvantages:**
- Against ecosystem preference for value witnesses
- One conformance per type — can't have "average Int via integer division" AND "average Int via Double promotion"
- Protocol retroactive conformance on stdlib types may have fragility concerns
- Adds a new public protocol to maintain forever

---

### Option D: Stored Witness on Sample

`Sample` stores the witness at construction time:

```swift
public struct Sample<Element: Sendable> {
    public let values: [Element]
    internal let comparator: Ordering.Comparator<Element>
    internal let averaging: Averaging<Element>?  // nil if not averageable
}
```

**Advantages:**
- Operations are simple property accesses: `sample.mean`
- Witness resolved once at construction

**Disadvantages:**
- Makes `Sample` larger (stores closures)
- Two `Sample<Duration>` values created with different witnesses are semantically different
- Optional averaging adds runtime nil-checking
- Breaks the value-type simplicity — Sample becomes a "configured" object
- Not how the ecosystem works — other types don't store their witnesses

---

### Option E: Ordering Witness for Sort + Averaging Witness for Arithmetic (Fully Witnessed)

Extend Option A to also use `Ordering.Comparator<Element>` for the sort dimension:

```swift
public struct Sample<Element: Sendable>: Sendable {
    public let values: [Element]
    @usableFromInline let sorted: [Element]

    // Sort via witness at construction
    public init(_ values: [Element], sortedBy comparator: Ordering.Comparator<Element>) {
        self.values = values
        self.sorted = values.sorted { comparator($0, $1) != .greater }
    }
}

// Convenience for Comparison.Protocol types
extension Sample where Element: Comparison.`Protocol` {
    public init(_ values: [Element]) {
        self.init(values, sortedBy: .ascending)
    }
}

// Percentile — no witness needed, already sorted at init
extension Sample {
    public func percentile(_ p: Double) -> Element? { ... }
    public var min: Element? { sorted.first }
    public var max: Element? { sorted.last }
    public var median: Element? { percentile(0.5) }
}

// Mean — witness parameter
extension Sample {
    public func mean(using averaging: Averaging<Element>) -> Element { ... }
}

// Convenience for Duration
extension Sample where Element == Duration {
    public var mean: Duration { mean(using: .duration) }
}
```

**Advantages:**
- Both dimensions (ordering + arithmetic) use witnesses consistently
- Ordering witness at init means sorted storage is always available
- Convenience constructors for `Comparison.Protocol` types
- Convenience properties for common `Element` types
- Matches ecosystem dual-overload pattern on both axes
- Sample itself stores no witnesses — ordering is resolved into sorted array at init

**Disadvantages:**
- `init(_ values:, sortedBy:)` is more verbose than `init(_ values:)` for non-Comparable types
- Two layers of convenience needed (one for init, one for mean)

---

## Comparison

| Criterion | A: Custom Witness | B: Group + Closure | C: Protocol | D: Stored Witness | E: Fully Witnessed |
|-----------|------------------|-------------------|-------------|-------------------|-------------------|
| Ecosystem consistency | High | Medium | Low | Low | **Highest** |
| Call-site ergonomics | Good (with convenience) | Poor (two params) | **Best** | Good | Good (with convenience) |
| Composability | High | Medium | Low (one conformance) | Low | **Highest** |
| New abstractions | 1 witness type | 0 (but messy) | 1 protocol | 0 | 1 witness type |
| Ordering integration | Not addressed | Not addressed | Not addressed | Stored | **Addressed** |
| Type simplicity | Simple | Simple | **Simplest** | Complex | Simple |
| Consistency with Ordering pattern | Partial | No | No | No | **Yes** |

---

## Outcome

**Status**: RECOMMENDATION

### Recommended: Option E — Fully Witnessed

Option E is the most ecosystem-consistent design. It follows the same dual-overload pattern that `Collection.min/max` uses for ordering, applied to both the ordering and arithmetic dimensions of `Sample<T>`.

**The two witness axes:**

| Axis | Witness Type | Provided at | Convenience for |
|------|-------------|-------------|-----------------|
| Ordering (sort, percentile) | `Ordering.Comparator<Element>` | `init` (resolved into sorted array) | `Comparison.Protocol` types |
| Arithmetic (mean, sum) | `Sample.Averaging<Element>` | Call site | `Duration`, `Double`, `Int`, `UInt64` |

**Why ordering at init but arithmetic at call site:**
- Ordering is needed by ALL percentile operations — resolving it once at init amortizes the O(n log n) sort
- Arithmetic is needed only by mean/sum — not all consumers need it, so don't require it at construction
- This matches the constraint tiers from first-principles: Tier 0 (Comparable → ordering) is foundational, Tier 1 (Averageable → arithmetic) is opt-in

**The `Accumulator` is simpler:**
Accumulator is concrete on `UInt64` with a fixed commutative monoid structure. It provides `Algebra.Monoid.Commutative<Accumulator>` as a static witness value, following the Cardinal pattern. No witness threading needed — operations are direct.

### Revised primitives dependency triage

| Package | Verdict | Why |
|---------|---------|-----|
| **swift-comparison-primitives** | **USE** | `Comparison.Protocol` for convenience overloads on init |
| **swift-ordering-primitives** | **USE** | `Ordering.Comparator<T>` for sort witness at init |
| **swift-algebra-monoid-primitives** | **USE** | `Algebra.Monoid.Commutative` witness for Accumulator |
| **swift-witness-primitives** | **USE** (transitive) | `Witness.Protocol` marker for `Sample.Averaging` |
| All others | SKIP | Not needed for v1 |

### Call site examples

```swift
// Construction — Comparison.Protocol types (convenience)
let sample = Sample([3.2, 1.5, 4.7, 2.1])  // Element: Double, infers .ascending

// Construction — custom ordering
let sample = Sample(observations, sortedBy: .descending)

// Percentile — no witness needed (already sorted)
sample.p99          // Double?
sample.median       // Double?

// Mean — witness parameter
sample.mean(using: .real)  // Double

// Mean — convenience for known types
sample.mean         // Double (via extension where Element == Double)

// Accumulator — direct operations, static monoid witness
var acc = Sample.Accumulator.empty
acc.record(42)
acc.record(17)
let merged = acc.merged(with: otherAcc)
// Static witness: Sample.Accumulator.monoid — Algebra.Monoid.Commutative<Accumulator>
```

---

## References

- Comparison.Protocol: `swift-comparison-primitives/Sources/Comparison Primitives Core/Comparison.Protocol.swift`
- Ordering.Comparator: `swift-ordering-primitives/Sources/Ordering Primitives/Ordering.Comparator.swift`
- Cardinal.monoid static witness: `swift-algebra-cardinal-primitives/Sources/Algebra Cardinal Primitives/Cardinal+Monoid.swift`
- Collection.min dual overload: `swift-collection-primitives/Sources/Collection Primitives/Collection.Min+Property.View.swift`
- Algebra.Module: `swift-algebra-module-primitives/Sources/Algebra Module Primitives/Algebra.Module.swift`
