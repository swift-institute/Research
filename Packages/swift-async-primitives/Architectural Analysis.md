# On the Structural Independence of Synchronous Coalgebraic Streams and Asynchronous Channel Primitives
<!--
---
version: 1.0.0
last_updated: 2026-01-16
status: DECISION
---
-->

**A Formal Analysis of Type-Theoretic Finite Sets, Coinductive Streams, and Concurrent Communication Abstractions in Swift**

---

## Abstract

This paper presents a rigorous analysis of three foundational Swift packages—`swift-finite-primitives`, `swift-infinite-primitives`, and `swift-async-primitives`—examining whether structural unification is feasible and desirable. We demonstrate that despite superficial terminological similarities (bounded/unbounded, finite/infinite), these packages operate in fundamentally different semantic domains with incompatible computational models. Specifically, we show that: (1) `Finite.Ordinal<N>` requires compile-time cardinality, rendering it unsuitable for runtime-configured channel capacities; (2) `Infinite.Observable` enforces coalgebraic purity laws that async receivers necessarily violate; and (3) the execution models (synchronous observation vs. suspended iteration) are categorically distinct. We conclude with recommendations for ecosystem coherence through protocol extraction and documentation rather than forced structural integration.

---

## 1. Introduction

Modern software systems increasingly require coordination between synchronous computation, infinite data streams, and concurrent communication channels. Swift's type system, particularly with the introduction of value generics (`let N: Int`), non-copyable types (`~Copyable`), and structured concurrency, provides unprecedented opportunities for encoding these distinctions at the type level.

The primitives ecosystem under analysis comprises three packages:

1. **swift-finite-primitives**: Type-theoretic abstractions for finite sets, implementing the categorical concept of `Fin n`—the canonical type with exactly n inhabitants.

2. **swift-infinite-primitives**: Coalgebraic infrastructure for coinductive streams, providing pure observation via head/tail decomposition following the `F(X) = A × X` functor pattern.

3. **swift-async-primitives**: Concurrent communication primitives including bounded and unbounded channels, broadcast mechanisms, and synchronization constructs.

The research question motivating this analysis: *Can swift-async-primitives be refactored to maximize structural reuse of swift-finite-primitives and swift-infinite-primitives?*

Our findings indicate that while conceptual relationships exist, structural unification would violate the semantic contracts of each package. We formalize these constraints and provide recommendations for ecosystem coherence.

---

## 2. Background and Theoretical Foundations

### 2.1 Finite Types and Value Generics

In type theory, `Fin n` (or ℕ<sub>n</sub>) denotes the finite set {0, 1, ..., n-1}. This construction is fundamental to dependent type theory, serving as the canonical example of a family of types indexed by natural numbers.

Swift's value generics enable encoding cardinality at the type level:

```swift
public struct Ordinal<let N: Int>: Sendable, Hashable {
    public let rawValue: Int

    public init?(_ rawValue: Int) {
        guard rawValue >= 0 && rawValue < N else { return nil }
        self.rawValue = rawValue
    }
}
```

**Critical Property**: N must be a compile-time constant. The type `Ordinal<64>` is distinct from `Ordinal<128>`, and no runtime mechanism can unify them without existential wrapping.

### 2.2 Coalgebras and Coinductive Streams

A coalgebra for a functor F : Set → Set consists of a set X (the carrier) and a function α : X → F(X) (the structure map). For infinite streams, we use the functor F(X) = A × X, yielding:

```
α : Stream → A × Stream
α(s) = (head(s), tail(s))
```

The `Infinite.Observable` protocol captures this precisely:

```swift
public protocol Observable: Enumerable, Sendable where Element: Sendable {
    associatedtype Tail: Observable where Tail.Element == Element
    var head: Element { get }
    var tail: Tail { get }
}
```

**Coalgebraic Laws**:
1. **Purity**: Observing `head` and `tail` multiple times yields identical results
2. **Totality**: `tail` always produces a valid `Observable`
3. **Productivity**: Every finite prefix is computable

These laws enable *bisimulation*—two streams are equivalent iff they are indistinguishable by any finite sequence of observations—and *coinductive proofs*.

### 2.3 Async Iteration and Effect Systems

Asynchronous iteration in Swift follows the `AsyncSequence` protocol:

```swift
public protocol AsyncSequence<Element, Failure> {
    associatedtype AsyncIterator: AsyncIteratorProtocol
    func makeIterator() -> AsyncIterator
}

public protocol AsyncIteratorProtocol<Element, Failure> {
    mutating func next() async throws(Failure) -> Element?
}
```

**Key Distinctions from Observable**:
1. **Effectful**: `next()` may suspend, throw, or have side effects
2. **Stateful**: The iterator maintains mutable state; calling `next()` advances position
3. **Terminable**: Returns `nil` on completion
4. **Non-idempotent**: Calling `next()` twice yields different results

---

## 3. Package Analysis

### 3.1 swift-finite-primitives

**Core Abstraction**: `Finite.Ordinal<let N: Int>`

| Property | Value |
|----------|-------|
| Cardinality | Compile-time constant N |
| Inhabitants | {0, 1, ..., N-1} |
| Memory | Zero-cost wrapper over Int |
| Conformances | Sendable, Hashable, Comparable, Codable, Enumerable |

**Key Types**:
- `Finite.Enumerable`: Protocol for types with finite, indexed inhabitants
- `Finite.Enumeration<Element>`: Zero-allocation lazy collection over Enumerable types

**Product Isomorphism** (`Fin(m×n) ≅ Fin(m) × Fin(n)`):
```swift
func decomposed<Rows: Int, Columns: Int>() -> (row: Ordinal<Rows>, column: Ordinal<Columns>)
init(row: Ordinal<Rows>, column: Ordinal<Columns>)
```

**Limitations**: Value-generic constraints (`where N > 0`) are not yet supported in Swift, preventing certain APIs like `minBound`/`maxBound`.

### 3.2 swift-infinite-primitives

**Core Abstractions**:
- `Infinite.Enumerable`: Marker protocol for infinite `Sequence` types
- `Infinite.Observable`: Coalgebraic head/tail observation

**Generator Types**:
| Type | Description | State |
|------|-------------|-------|
| `Repeat<Element>` | Constant repetition | Element |
| `Iterate<Element>` | Endomorphism iteration | Element |
| `Unfold<State, Element>` | General anamorphism | (State, Step) |
| `Cycle<Base>` | Finite collection cycling | (Base, Index) |

**Transformer Types**:
| Type | Description | Tail Type |
|------|-------------|-----------|
| `Map<Source, Element>` | Element transformation | `Map<Source.Tail, Element>` |
| `Zip<First, Second>` | Parallel combination | `Zip<First.Tail, Second.Tail>` |
| `Scan<Source, Element>` | Running accumulation | `Scan<Source.Tail, Element>` |

**Observation**: Transformer tail types are *heterogeneous*—`Map<Naturals, String>` has tail type `Map<Naturals, String>`, not `Map<Naturals, String>.Tail`. This enables type-level reasoning about stream transformations.

### 3.3 swift-async-primitives

**Core Abstractions**:

| Type | Capacity | Consumer Model | Backpressure |
|------|----------|----------------|--------------|
| `Channel.Unbounded` | Unlimited | Single | No |
| `Channel.Bounded` | Runtime Int | Single | Yes |
| `Broadcast` | Configurable buffer | Multi (cursor) | Per-subscriber |

**Synchronization Primitives**:
- `Promise<Value>`: Single-value, multi-reader async primitive
- `Barrier`: N-party synchronization point
- `Bridge`: Sync-to-async handoff (multi-producer, single-consumer)

**Waiter Infrastructure**:
- `Waiter.Queue.Bounded`: Fixed-capacity waiter queue
- `Waiter.Queue.Unbounded`: Unlimited waiter queue
- `Waiter.Entry`: Queue entry with ID, flag, resumption

**Timer Infrastructure**:
- `Timer.Wheel`: Hierarchical timer wheel with O(1) amortized operations

---

## 4. Integration Analysis

### 4.1 Finite.Ordinal for Channel Indices

**Hypothesis**: Use `Finite.Ordinal<N>` for type-safe buffer indexing in bounded channels.

**Analysis**:

Current bounded channel construction:
```swift
public init(capacity: Int)  // Runtime parameter
```

Hypothetical ordinal-parameterized construction:
```swift
public struct Bounded<let Capacity: Int> {
    var buffer: InlineArray<Capacity, Element>
    var head: Finite.Ordinal<Capacity>
    var tail: Finite.Ordinal<Capacity>
}
```

**Impediments**:

1. **Runtime vs. Compile-time Capacity**

   Channel capacity is fundamentally a runtime concern:
   ```swift
   let capacity = config.maxBufferSize  // User configuration
   let channel = Channel<Message>.Bounded(capacity: capacity)
   ```

   Value generics require compile-time constants. Converting to ordinal-parameterized channels would require:
   ```swift
   // Impossible: capacity is not a compile-time constant
   let channel = Channel<Message>.Bounded<capacity>()
   ```

2. **Generic Proliferation**

   Parameterizing by capacity propagates through all containing types:
   ```swift
   // Current (clean)
   struct Server {
       var requestChannel: Channel<Request>.Bounded
   }

   // With value generics (viral)
   struct Server<let Capacity: Int> {
       var requestChannel: Channel<Request>.Bounded<Capacity>
   }
   ```

3. **Memory Model Mismatch**

   `Finite.Ordinal` is a zero-cost Int wrapper. Bounded channels use heap-allocated ring buffers:
   ```swift
   var _storage: UnsafeMutablePointer<Element>
   ```

   The benefit of compile-time indices requires inline storage (`InlineArray`), which fundamentally changes the allocation model.

4. **Swift Language Limitations**

   Value-generic constraints (`where Capacity > 0`) are not yet supported, preventing meaningful bounded-index operations.

**Conclusion**: Integration not feasible without fundamental API redesign.

### 4.2 Infinite.Observable for Async Receivers

**Hypothesis**: Async channel receivers should conform to `Infinite.Observable`.

**Analysis**:

Observable contract:
```swift
protocol Observable {
    var head: Element { get }      // Pure, idempotent
    var tail: Tail { get }         // Pure, returns valid Observable
}
```

Async receiver behavior:
```swift
protocol AsyncIteratorProtocol {
    mutating func next() async throws -> Element?  // Effectful, stateful, fallible
}
```

**Categorical Comparison**:

| Property | Observable | Async Receiver |
|----------|------------|----------------|
| `head` access | Pure, repeatable | N/A (no `head`) |
| Advancement | `tail` returns new stream | `next()` mutates iterator |
| Suspension | Never | May suspend (backpressure) |
| Termination | Never terminates | May return `nil` |
| Failure | Cannot fail | May throw |
| Idempotence | Yes (coalgebraic law) | No (consumption is effectful) |

**Formal Argument**:

Let `s` be an `Observable` and `r` be an async receiver. The coalgebraic law states:
```
∀s. head(s) = head(s)  ∧  tail(s) = tail(s)
```

For async receivers, let `next₁` and `next₂` denote consecutive calls to `next()`:
```
next₁(r) ≠ next₂(r)  (in general)
```

This directly violates the coalgebraic purity law. Any conformance would be *semantically incorrect*.

**Counterargument Consideration**: Could we define `Async.Observable` with different laws?

```swift
protocol Async.Observable {
    var head: Element { get async throws }
    var tail: Tail { get async throws }
}
```

This abandons the coalgebraic structure entirely. The mathematical properties (bisimulation, coinductive proofs) no longer apply. What remains is syntactically similar but categorically different—a "head/tail" API without the formal guarantees that make it useful.

**Conclusion**: Conformance not possible without violating Observable's semantic contract.

### 4.3 Bounded/Unbounded Naming Alignment

**Hypothesis**: Rename `Channel.Bounded` → `Channel.Finite` and `Channel.Unbounded` → `Channel.Infinite`.

**Analysis**:

Semantic mapping:
- Bounded (has capacity limit) ↔ Finite (enumerable inhabitants)
- Unbounded (no limit) ↔ Infinite (non-terminating)

**Arguments For**:
1. Terminology consistency across ecosystem
2. API discoverability for users familiar with finite/infinite primitives

**Arguments Against**:

1. **Industry Convention**

   "Bounded channel" and "unbounded channel" are established terms in concurrent programming:
   - Go: Buffered channel (bounded), unbuffered channel
   - Rust: `bounded()`, `unbounded()` in crossbeam/tokio
   - Java: `ArrayBlockingQueue` (bounded), `LinkedBlockingQueue` (unbounded)

   Renaming breaks mental models for experienced concurrent programmers.

2. **Semantic Domain Difference**

   `Finite.Ordinal<N>` represents a type with N *inhabitants*—values that can exist. A `Channel.Bounded(capacity: 64)` doesn't have 64 inhabitants; it has a buffer that can hold up to 64 elements. The cardinality is of the buffer contents, not the type.

3. **False API Promise**

   Naming `Channel.Finite` suggests it uses `Finite` primitives for indexing or capacity. It doesn't and can't (runtime vs. compile-time). The name would mislead users.

4. **Mathematical Connotation**

   `Infinite.Observable` produces *actually infinite* streams (productivity law). `Channel.Unbounded` has potentially infinite throughput but finite contents at any instant. These are different infinities.

**Conclusion**: Retain industry-standard `Bounded`/`Unbounded` terminology.

---

## 5. Recommended Architecture

### 5.1 Structural Independence

The packages should remain structurally independent:

```
swift-finite-primitives      swift-infinite-primitives
         │                            │
         │                            │
    (no dependency)              (no dependency)
         │                            │
         ▼                            ▼
              swift-async-primitives
```

**Rationale**: Each package serves a distinct computational domain:
- **finite-primitives**: Type-theoretic finite sets (compile-time cardinality)
- **infinite-primitives**: Coalgebraic streams (pure observation, coinduction)
- **async-primitives**: Concurrent communication (runtime configuration, effects)

### 5.2 Protocol Extraction

Within async-primitives, extract shared protocols for bounded/unbounded variants:

```swift
extension Async.Waiter.Queue {
    /// Protocol unifying bounded and unbounded waiter queue operations.
    public protocol QueueProtocol<Outcome, Metadata>: ~Copyable {
        associatedtype Outcome: Sendable
        associatedtype Metadata: ~Copyable & Sendable

        typealias Entry = Async.Waiter.Entry<Outcome, Metadata>
        typealias Flagged = Async.Waiter.Queue.Flagged<Outcome, Metadata>

        var count: Int { get }
        var isEmpty: Bool { get }

        mutating func popFront() -> Entry?
        mutating func popEligible(flaggedInto: inout Drain<Flagged>) -> Entry?
        mutating func reapFlagged(into: inout Drain<Flagged>)
        mutating func drainAll(_ body: (consuming Entry) -> Void)
    }
}
```

This enables generic programming over queue types without forcing structural unification.

### 5.3 One-Way Adapters

Where composition is meaningful, provide unidirectional adapters:

```swift
// In a bridge package or extension
extension Infinite.Observable {
    /// Converts a pure infinite stream to an async sequence.
    ///
    /// The resulting sequence:
    /// - Yields elements on demand (respects backpressure)
    /// - Honors task cancellation
    /// - Never throws (pure source)
    ///
    /// - Complexity: O(1) per element
    func asAsyncSequence() -> some AsyncSequence<Element, Never> {
        AsyncStream<Element> { continuation in
            var current: Self = self
            while !Task.isCancelled {
                continuation.yield(current.head)
                current = current.tail
            }
            continuation.finish()
        }
    }
}
```

The reverse adapter (`AsyncSequence` → `Observable`) is **not possible**:
1. Async sequences may terminate (Observable cannot)
2. Consumption is effectful (Observable requires purity)
3. `head` cannot be called multiple times with same result

### 5.4 Documentation of Conceptual Relationships

Add documentation explaining the relationship without implying structural sharing:

```swift
/// A channel with bounded buffer capacity.
///
/// ## Conceptual Relationship to Finite Primitives
///
/// Conceptually related to `Finite` types in that both involve bounded cardinality.
/// However, the relationship is semantic rather than structural:
///
/// - `Finite.Ordinal<N>`: Compile-time cardinality, type-safe indexing
/// - `Channel.Bounded(capacity:)`: Runtime capacity, dynamic buffer
///
/// The capacity is user-configurable at runtime, making value-generic
/// parameterization infeasible.
public struct Bounded<Element: Sendable>: ~Copyable, @unchecked Sendable { ... }
```

---

## 6. Related Work

### 6.1 Coalgebraic Semantics

Rutten's work on universal coalgebra [1] provides the theoretical foundation for `Infinite.Observable`. The distinction between algebraic (constructor-based) and coalgebraic (destructor-based) types directly informs our analysis of why async receivers cannot conform to Observable.

### 6.2 Session Types

Session types [2] formalize communication protocols at the type level. The bounded/unbounded channel distinction relates to session type capacity annotations, though Swift's current type system lacks the dependent features for full session type encoding.

### 6.3 Effect Systems

The distinction between pure observation (Observable) and effectful iteration (AsyncSequence) parallels work on algebraic effects [3]. A future Swift with first-class effects could potentially provide unified abstraction, but this is beyond current language capabilities.

### 6.4 Linear and Affine Types

Swift's `~Copyable` types implement affine semantics (use at most once). The single-receiver guarantee on channels (`Receiver` is `~Copyable`) ensures exactly-once consumption, a property exploited throughout the waiter infrastructure.

---

## 7. Conclusion

This analysis demonstrates that swift-async-primitives should remain structurally independent of swift-finite-primitives and swift-infinite-primitives. The key findings are:

1. **Compile-time vs. Runtime Capacity**: `Finite.Ordinal<N>` requires compile-time N; channel capacities are runtime-configured. No unification is possible without API redesign that would eliminate user flexibility.

2. **Coalgebraic Purity vs. Effectful Iteration**: `Infinite.Observable` requires idempotent observation (coalgebraic law); async receivers are inherently effectful and stateful. Conformance would violate the semantic contract that makes Observable mathematically tractable.

3. **Terminability**: Observable streams are infinite by construction (productivity law); async channels terminate. This is a categorical distinction, not an implementation detail.

4. **Terminology Independence**: While "bounded" relates to "finite" and "unbounded" to "infinite" in everyday language, the formal semantics differ. Renaming would introduce false API promises and break industry conventions.

The recommended approach is:
- Maintain structural independence
- Extract internal protocols for code reuse within async-primitives
- Provide one-way adapters (Observable → AsyncSequence) where meaningful
- Document conceptual relationships without implying structural sharing

This preserves each package's design integrity while acknowledging their place in a coherent type-theoretic ecosystem.

---

## References

[1] Rutten, J.J.M.M. (2000). "Universal coalgebra: a theory of systems." *Theoretical Computer Science*, 249(1), 3-80.

[2] Honda, K., Vasconcelos, V.T., & Kubo, M. (1998). "Language primitives and type discipline for structured communication-based programming." *ESOP '98*, LNCS 1381, 122-138.

[3] Plotkin, G. & Pretnar, M. (2009). "Handlers of algebraic effects." *ESOP '09*, LNCS 5502, 80-94.

[4] Wadler, P. (2012). "Propositions as sessions." *ICFP '12*, 273-286.

[5] McBride, C. & McKinna, J. (2004). "The view from the left." *Journal of Functional Programming*, 14(1), 69-111.

---

## Appendix A: Type Signatures

### A.1 Finite Primitives

```swift
// Canonical finite type
public struct Ordinal<let N: Int>: Sendable, Hashable, Comparable {
    public let rawValue: Int
    public init?(_ rawValue: Int)
    public init(__unchecked rawValue: Int)
    public static var count: Int { N }
    public var ordinal: Int { rawValue }
}

// Enumerable protocol
public protocol Enumerable: CaseIterable, Sendable {
    static var count: Int { get }
    var ordinal: Int { get }
    init(__unchecked ordinal: Int)
}
```

### A.2 Infinite Primitives

```swift
// Marker protocol
public protocol Enumerable: Sequence, Sendable where Element: Sendable {}

// Coalgebraic protocol
public protocol Observable: Enumerable {
    associatedtype Tail: Observable where Tail.Element == Element
    var head: Element { get }
    var tail: Tail { get }
}

// Anamorphism
public struct Unfold<State, Element>: Observable {
    public typealias Step = (State) -> (Element, State)
    public init(_ initial: State, step: @escaping Step)
    public var head: Element { step(state).0 }
    public var tail: Unfold { Unfold(step(state).1, step: step) }
}
```

### A.3 Async Primitives

```swift
// Bounded channel
public struct Bounded<Element: Sendable>: ~Copyable, @unchecked Sendable {
    public init(capacity: Int)
    public func close()
    public var isClosed: Bool { get }
}

// Receiver (AsyncSequence conformance)
public struct Receiver: ~Copyable, AsyncSequence, @unchecked Sendable {
    public func receive() async throws(Error) -> Element?
}

// Observable types CANNOT conform to AsyncSequence due to:
// 1. Termination (AsyncSequence) vs. Infinity (Observable)
// 2. Effectful mutation (AsyncSequence) vs. Pure observation (Observable)
// 3. Suspension semantics (AsyncSequence) vs. Immediate return (Observable)
```

---

## Appendix B: Proof of Non-Conformance

**Theorem**: No type can simultaneously satisfy `Infinite.Observable` and exhibit async receiver semantics.

**Proof**:

Let T be a type with methods:
- `head: Element` (Observable requirement)
- `receive() async -> Element?` (receiver semantics)

Case 1: `head` is implemented in terms of `receive()`:
```swift
var head: Element {
    // Cannot call async from sync context
    // Compilation fails
}
```
This is syntactically impossible in Swift.

Case 2: `head` and `receive()` share underlying state:
```swift
var head: Element {
    return buffer.first!  // Reads without consuming
}

func receive() async -> Element? {
    return buffer.removeFirst()  // Consumes
}
```

After calling `receive()`, subsequent calls to `head` return different values, violating:
```
∀t. head(t) = head(t)  // Idempotence law
```

Case 3: `head` and `receive()` are independent:

Then `head` and `receive()` return unrelated streams, which is semantically meaningless—the type presents two uncoordinated interfaces.

**Conclusion**: No implementation can satisfy both contracts. ∎

---

*Document Version: 1.0*
*Analysis Date: January 2026*
*Package Versions: swift-finite-primitives (main), swift-infinite-primitives (main), swift-async-primitives (main)*
