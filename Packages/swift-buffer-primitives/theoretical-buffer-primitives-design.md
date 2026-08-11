# Theoretical Buffer-Primitives Built on Storage-Primitives and Bit-Vector-Primitives

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
tier: 3
---
-->

## Context

The Swift Institute primitives architecture establishes a logical dependency chain:

```
Storage (Tier 12) → Buffer (Tier 13) → Data Structures (Tier 14+)
```

We have invested significant design effort in `storage-primitives` (providing `Storage<Element>.Heap` and `Storage<Element>.Inline<capacity>` with `Storage.Initialization` tracking) and `bit-vector-primitives` (providing `Bit.Vector` and `Bit.Vector.Static<wordCount>` for packed occupancy bitmaps). These two packages represent a mature, well-tested foundation.

The existing `buffer-primitives` package was written before `storage-primitives` and `bit-vector-primitives` reached their current form. Attempting to incrementally refactor the existing buffer layer to use the new foundation has not produced satisfactory results — the legacy structure resists the new abstractions.

This research asks: **What does a theoretically ideal buffer-primitives look like when designed from first principles on top of storage-primitives and bit-vector-primitives, unconstrained by the existing implementation?**

**Trigger**: [RES-011] Research-first design — blocked by impedance mismatch between current buffer-primitives and the storage/bit-vector foundation.

**Precedent risk**: VERY HIGH — Buffer primitives sit at the critical junction between raw storage and all higher-level data structures (deque, queue, stack, array). Every ADT in the system depends on this layer. The design constrains what is expressible at all higher layers.

**Constraints**:
- MUST build exclusively on `Storage_Primitives` and `Bit_Vector_Primitives` (and their transitive deps)
- MUST support `~Copyable` element types throughout
- MUST support both `Storage.Heap` and `Storage.Inline` backing
- MUST NOT import Foundation ([PRIM-FOUND-001])
- MUST follow [API-NAME-001] Nest.Name pattern
- MUST follow [API-IMPL-005] one type per file
- MUST remain at Tier 13 (depend only on Tiers 0–12)
- MUST NOT examine or be constrained by current buffer-primitives implementation

---

## Question

What is the complete type hierarchy, operational semantics, and API surface of a theoretical buffer-primitives package that:

1. Maximally leverages `Storage.Heap`, `Storage.Inline`, `Storage.Initialization`, and `Bit.Vector`/`Bit.Vector.Static` as its foundation?
2. Supports the canonical buffer disciplines (linear, ring, slab)?
3. Supports both heap-backed and inline-backed variants of each discipline?
4. Maintains ~Copyable safety and conditional Copyable conformance?

**Sub-questions**:
- SQ1: What is the minimal set of buffer disciplines that belong at the primitives layer?
- SQ2: How does `Storage.Initialization` (`.empty`, `.one`, `.two`) map to each discipline's state?
- SQ3: How does `Bit.Vector` integrate for occupancy tracking (slab discipline)?
- SQ4: What is the relationship between buffer Header types and Storage metadata?
- SQ5: How should growth policy interact with storage replacement?

---

## Systematic Literature Review

### Protocol

**Research questions**:
- RQ1: What buffer disciplines are considered canonical in systems programming?
- RQ2: How do existing systems separate storage strategy from buffer discipline?
- RQ3: What formal properties must each discipline preserve?

**Search strategy**:
- Databases: ACM DL, arXiv, Swift Evolution, Rust docs/RFCs, Boost docs
- Keywords: "buffer discipline", "ring buffer formal", "circular buffer verification", "linear buffer", "slab allocation", "buffer abstraction"
- Date range: 1990–2026

**Inclusion criteria**: Systems-level buffer abstractions with formal or semi-formal treatment; production libraries with documented design rationale.

**Exclusion criteria**: Application-level buffering (I/O streams), numerical buffers, GPU buffers.

### Search Results

| # | Source | Title/Description | RQ | Key Finding |
|---|--------|------|-----|-------------|
| 1 | Bonwick (USENIX 1994) | The Slab Allocator | RQ1 | Slab = fixed-size slots with bitmap occupancy; canonical discipline |
| 2 | Snellman (2016) | "Writing Ring Buffers Wrong" | RQ3 | Virtual-memory mirroring; head/tail invariants |
| 3 | Giesen (2010) | "Ring Buffers and Queues" | RQ1, RQ3 | Power-of-2 masking; three ring buffer variants |
| 4 | Rust `bytes` crate | Buf/BufMut traits | RQ2 | Trait-based discipline separation from backing storage |
| 5 | Rust `VecDeque` | Standard library deque | RQ1 | Ring buffer with contiguous backing, `make_contiguous()` |
| 6 | Rust `ringbuffer` crate | Trait + impls | RQ2 | `RingBuffer` trait with Alloc/ConstGeneric/Growable impls |
| 7 | Rust `smallvec`/`tinyvec` | Small buffer optimization | RQ2 | Inline-then-heap via enum discriminator |
| 8 | folly `IOBuf` | Chained buffer descriptors | RQ2 | Descriptor (head/tail/length) separated from backing memory |
| 9 | Boost.CircularBuffer | Fixed ring buffer | RQ1 | Overwrite-on-full policy |
| 10 | Wadler (1990) | Linear Types | RQ3 | Exactly-once usage; formal basis for ~Copyable |
| 11 | Tov & Pucella (2011) | Practical Affine Types | RQ3 | At-most-once; formal basis for ownership transfer in push/pop |
| 12 | Jung et al. (POPL 2018) | RustBelt | RQ3 | Semantic verification of unsafe ring buffer code |
| 13 | seL4 verified kernel | IPC ring buffers | RQ3 | Mechanized proof of ring buffer FIFO ordering |
| 14 | Bernardy et al. (2017) | Retrofitting Linear Types | RQ3 | Linear types enable safe in-place buffer mutation |
| 15 | OCaml Cstruct_cap | Capability-based buffers | RQ2 | Phantom types for read/write capability |
| 16 | Haskell linear-base | Linear arrays | RQ3 | Unique ownership ⟹ safe in-place mutation |
| 17 | SE-0390 | Noncopyable structs/enums | RQ3 | Swift ~Copyable = affine types |
| 18 | SE-0437 | Noncopyable stdlib primitives | RQ2 | ManagedBuffer<Header, Element: ~Copyable> |
| 19 | Xi (2012) | ATS Linear Types for Multicore | RQ3 | Provably safe buffer manipulation across cores |

### Synthesis

**RQ1 — Canonical Buffer Disciplines**:

The literature converges on three fundamental buffer disciplines at the systems level, plus two composite disciplines built from them:

| Discipline | Invariant | Operations | Storage Pattern |
|------------|-----------|------------|-----------------|
| **Linear** | Elements occupy `[0, count)` contiguously from start | append, consume-front, shift | `Storage.Initialization.one` |
| **Ring** | Elements wrap around fixed capacity; head + count define window | push-back, pop-front, push-front, pop-back | `Storage.Initialization.one` OR `.two` |
| **Slab** | Fixed slots; any slot may be occupied or vacant independently | insert-at, remove-at, iterate-occupied | `Bit.Vector` occupancy bitmap |
| **Stack** (composite) | Linear discipline restricted to LIFO access | push, pop, peek | `Storage.Initialization.one` |
| **Deque** (composite) | Ring discipline with both-end access | push-front, push-back, pop-front, pop-back | `Storage.Initialization.one` OR `.two` |

Stack and deque are not separate disciplines — they are access-policy restrictions on linear and ring buffers respectively. They belong at a higher layer (Tier 14+).

**The three fundamental disciplines are: Linear, Ring, and Slab.**

**RQ2 — Storage Strategy Separation**:

Every surveyed production system separates storage from discipline:

| System | Storage Abstraction | Discipline Abstraction | Coupling |
|--------|--------------------|-----------------------|----------|
| Rust `bytes` | `Vec<u8>`, `Arc<[u8]>` | `Buf`/`BufMut` traits | Loose (trait-based) |
| Rust `ringbuffer` | `Vec`, const-generic array | `RingBuffer` trait | Loose (trait-based) |
| Rust `smallvec` | `union { inline, heap }` | Linear (Vec-like) | Tight (enum) |
| folly IOBuf | Custom allocator, mmap, shared | IOBuf descriptor chain | Explicit separation |
| Boost.CircularBuffer | Dynamic array | Ring with overwrite | Tight |
| Swift Institute | `Storage.Heap`, `Storage.Inline` | Buffer.Linear, Buffer.Ring | **To be designed** |

The Swift Institute approach is unique in having explicit, well-typed storage primitives. The key design opportunity is to make discipline implementations **parametric** over storage, rather than having separate Heap and Inline copies of each discipline.

**RQ3 — Formal Properties**:

Each discipline has invariants that must be preserved:

**Linear Buffer Invariants**:
- L1: `0 ≤ count ≤ capacity`
- L2: Slots `[0, count)` are initialized; slots `[count, capacity)` are uninitialized
- L3: `Storage.Initialization == .linear(count: count)` equivalently `.one(0..<count)`
- L4: Append increments count; consume-front shifts elements left

**Ring Buffer Invariants**:
- R1: `0 ≤ count ≤ capacity`
- R2: `head` is a valid slot index `[0, capacity)`
- R3: Elements occupy slots `[head, head+count) mod capacity`
- R4: When non-wrapping: `Storage.Initialization == .one(head..<head+count)`
- R5: When wrapping: `Storage.Initialization == .two(first: head..<capacity, second: 0..<(head+count-capacity))`
- R6: Push-back writes at slot `(head + count) mod capacity`; pop-front reads at `head`
- R7: FIFO ordering: pop returns elements in push order

**Slab Buffer Invariants**:
- S1: `0 ≤ occupancy ≤ capacity`
- S2: Slot `i` is initialized ⟺ `bitmap[i] == true`
- S3: `bitmap.popcount == occupancy`
- S4: Insert at slot `i` requires `bitmap[i] == false`; sets `bitmap[i] = true`
- S5: Remove at slot `i` requires `bitmap[i] == true`; sets `bitmap[i] = false`

---

## Formal Semantics

### Type Definitions

We define the buffer state space formally. Let `S` denote a storage instance (either `Storage.Heap<E>` or `Storage.Inline<E, cap>`), and let `n = capacity(S)`.

**Linear Buffer State**:
```
σ_linear = (S, count : Fin(n+1))
where initialized(S) = [0, count)
```

**Ring Buffer State**:
```
σ_ring = (S, head : Fin(n), count : Fin(n+1))
where initialized(S) = { (head + i) mod n | 0 ≤ i < count }
```

**Slab Buffer State**:
```
σ_slab = (S, bitmap : BitVector(n))
where initialized(S) = { i | bitmap[i] = 1 }
```

### Typing Rules

We use the notation `Γ ⊢ e : τ` and `Γ; σ ⊢ e ⇒ σ'; v : τ` for state-transforming operations.

**Linear Buffer — Append**:
```
Γ ⊢ buf : Buffer.Linear<E>    Γ ⊢ elem : E    buf.count < buf.capacity
─────────────────────────────────────────────────────────────────────────── (T-LinAppend)
Γ; (S, count) ⊢ buf.append(consuming elem) ⇒ (S', count+1); () : Void
where S' = S[count ↦ elem]
```

**Linear Buffer — Consume Front**:
```
Γ ⊢ buf : Buffer.Linear<E>    buf.count > 0
───────────────────────────────────────────────────────────────────── (T-LinConsume)
Γ; (S, count) ⊢ buf.consumeFront() ⇒ (S', count-1); v : E
where v = S[0], S' = shift(S, [1, count) → [0, count-1))
```

**Ring Buffer — Push Back**:
```
Γ ⊢ buf : Buffer.Ring<E>    Γ ⊢ elem : E    buf.count < buf.capacity
───────────────────────────────────────────────────────────────────────── (T-RingPush)
Γ; (S, head, count) ⊢ buf.pushBack(consuming elem) ⇒ (S', head, count+1); () : Void
where tail = (head + count) mod capacity, S' = S[tail ↦ elem]
```

**Ring Buffer — Pop Front**:
```
Γ ⊢ buf : Buffer.Ring<E>    buf.count > 0
───────────────────────────────────────────────────────────────────── (T-RingPop)
Γ; (S, head, count) ⊢ buf.popFront() ⇒ (S', head', count-1); v : E
where v = S[head], head' = (head + 1) mod capacity, S' = S with slot head deinitialized
```

**Slab Buffer — Insert**:
```
Γ ⊢ buf : Buffer.Slab<E>    Γ ⊢ elem : E    Γ ⊢ slot : Index<Element>    bitmap[slot] = 0
─────────────────────────────────────────────────────────────────────────────────────── (T-SlabInsert)
Γ; (S, bitmap) ⊢ buf.insert(consuming elem, at: slot) ⇒ (S', bitmap'); () : Void
where S' = S[slot ↦ elem], bitmap' = bitmap with bit slot set
```

**Slab Buffer — Remove**:
```
Γ ⊢ buf : Buffer.Slab<E>    Γ ⊢ slot : Index<Element>    bitmap[slot] = 1
────────────────────────────────────────────────────────────────────────────── (T-SlabRemove)
Γ; (S, bitmap) ⊢ buf.remove(at: slot) ⇒ (S', bitmap'); v : E
where v = S[slot], S' = S with slot deinitialized, bitmap' = bitmap with bit slot cleared
```

### Operational Semantics

**Ownership Transfer** (consuming push):
```
⟨push(v, buf), σ⟩ → ⟨(), σ[slot ↦ v]⟩
where v is consumed (moved) — no copy exists after push
```

**Ownership Return** (producing pop):
```
⟨pop(buf), σ⟩ → ⟨v, σ[slot ↦ ⊥]⟩
where v is the previously stored value, slot is deinitialized
```

The `consuming`/producing semantics are enforced by Swift's `~Copyable` type system: the `consuming` parameter annotation ensures the caller relinquishes ownership, and the return value transfers ownership to the caller.

### Soundness Argument

**Claim**: For each buffer discipline, the operations preserve the discipline invariants and storage initialization tracking is always consistent.

**Proof sketch for Ring Buffer**:

1. **Initialization consistency**: The ring buffer maintains `Storage.Initialization` matching its head/count state.
   - When `count == 0`: `.empty`
   - When non-wrapping (`head + count ≤ capacity`): `.one(head..<head+count)`
   - When wrapping (`head + count > capacity`): `.two(first: head..<capacity, second: 0..<(head+count-capacity))`

2. **Push preserves R1–R7**: Given `count < capacity`:
   - `tail = (head + count) mod capacity` is a valid uninitialized slot (by R3 and count < capacity)
   - Writing at `tail` and incrementing `count` maintains the contiguous-modular window invariant
   - FIFO ordering is preserved because `tail` is always the position after the last element

3. **Pop preserves R1–R7**: Given `count > 0`:
   - `head` is an initialized slot (by R2, R3)
   - Reading and deinitializing `head`, advancing `head = (head + 1) mod capacity`, decrementing `count` maintains the window
   - FIFO: the element at `head` was the earliest pushed ∎

**Proof sketch for Slab Buffer**:

1. **Bitmap consistency**: `bitmap[i] == true ⟺ slot i is initialized`
2. **Insert at vacant slot**: Precondition `bitmap[slot] == false` ensures we don't overwrite an initialized slot. Setting the bit and initializing the slot maintains S2.
3. **Remove at occupied slot**: Precondition `bitmap[slot] == true` ensures we read a valid value. Clearing the bit and deinitializing maintains S2.
4. **Deinit safety**: On destruction, iterate `bitmap.ones.forEach` and deinitialize each occupied slot. By S2, this deinitializes exactly the initialized slots. ∎

---

## Theoretical Foundation

### Substructural Type Theory and Buffer Disciplines

Swift's `~Copyable` types implement **affine typing** — values can be used at most once. This is the substructural foundation that makes buffer ownership safe:

| Substructural Property | Swift Mechanism | Buffer Application |
|----------------------|-----------------|-------------------|
| No implicit copy (affine) | `~Copyable` | Elements cannot be accidentally duplicated in storage |
| Consuming transfer | `consuming` parameter | Push consumes the element into the buffer |
| Producing return | Return value | Pop produces the element out of the buffer |
| Conditional copy | `where Element: Copyable` | Copy-on-write for copyable elements only |

### Category-Theoretic View

**Buffers as indexed state monads**: Each buffer discipline can be modeled as a state monad indexed by the discipline's state type:

```
Buffer.Linear : State(σ_linear) → State(σ_linear)
Buffer.Ring   : State(σ_ring)   → State(σ_ring)
Buffer.Slab   : State(σ_slab)   → State(σ_slab)
```

The storage type is a parameter of the state, not a parameter of the monad. This is the formal justification for making discipline operations **parametric over storage**: the discipline defines the state transitions, while storage provides the physical substrate.

**Storage as a functor**: `Storage.Heap` and `Storage.Inline` are both instances of a conceptual "storage functor" that maps element types to storage containers:

```
Storage.Heap   : Type → StorageContainer
Storage.Inline : Type × Nat → StorageContainer
```

The buffer discipline doesn't care which functor produced the storage — it operates on the abstract interface of slot access (initialize, move, deinitialize, pointer-at).

### The Discipline–Storage Product

The theoretical design space is a **product** of disciplines and storage strategies:

```
BufferType = Discipline × StorageStrategy

Discipline     = { Linear, Ring, Slab }
StorageStrategy = { Heap, Inline }
```

This gives 6 combinations:

| | Heap | Inline |
|---|------|--------|
| **Linear** | Growable linear buffer | Fixed-capacity linear buffer |
| **Ring** | Growable ring buffer | Fixed-capacity ring buffer |
| **Slab** | Growable slab | Fixed-capacity slab |

In practice, Heap variants support growth (reallocation to larger storage), while Inline variants are fixed at compile time.

---

## Analysis: Type Hierarchy Design

### Design Principle: Discipline as Namespace, Storage as Parameter

Rather than creating 6 separate types (one per cell in the product), we define **3 discipline namespaces** with storage-parametric operations. The discipline namespace owns the Header type (cursor state); the storage type is passed to operations.

This follows the pattern established in `storage-primitives` where operations are defined on `Storage.Heap` and `Storage.Inline` separately but share the coordinate system `Index<Element>`.

### Option A: Discipline Owns Both Header and Storage (Monolithic)

```swift
// Each buffer type bundles header + storage
public struct Buffer.Ring<Element: ~Copyable>: ~Copyable {
    var header: Header
    var storage: Storage<Element>.Heap
}

public struct Buffer.Ring.Static<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var header: Header.Cyclic<capacity>
    var storage: Storage<Element>.Inline<capacity>
}
```

**Pros**: Simple ownership — buffer owns everything. Clear API: `ring.pushBack(elem)`.
**Cons**: Duplicated discipline logic between Heap and Inline variants. Growth requires `Storage.Heap`-specific code mixed into discipline logic. The monolithic approach tightly couples what should be orthogonal concerns.

### Option B: Header-Only Disciplines with Separate Storage (Decoupled)

```swift
// Discipline defines only the cursor/state header
public struct Buffer.Ring.Header: Sendable {
    public var head: Index<Element>
    public var count: Index<Element>.Count
    public let capacity: Index<Element>.Count
}

// Operations are methods on Header that take storage as inout parameter
extension Buffer.Ring.Header {
    public mutating func pushBack(
        _ element: consuming Element,
        into storage: Storage<Element>.Heap
    )

    public mutating func pushBack(
        _ element: consuming Element,
        into storage: inout Storage<Element>.Inline<capacity>
    )
}
```

**Pros**: Clean separation. Header is Sendable/Copyable (just indices). Discipline logic written once, storage-specific pointer access is minimal. Matches the existing `Storage.Initialization` pattern where the tracking is metadata alongside the storage.
**Cons**: Verbose call sites — caller must pass storage explicitly. Risk of header/storage mismatch (using a header with the wrong storage instance).

### Option C: Discipline Types with Generic Storage Protocol (Abstract)

```swift
protocol BufferStorage<Element> {
    associatedtype Element: ~Copyable
    var slotCapacity: Index<Element>.Count { get }
    func initialize(to element: consuming Element, at slot: Index<Element>)
    func move(at slot: Index<Element>) -> Element
    func deinitialize(at slot: Index<Element>)
}

extension Storage.Heap: BufferStorage {}
extension Storage.Inline: BufferStorage {}

public struct Buffer.Ring<S: BufferStorage>: ~Copyable {
    var header: Header
    var storage: S
}
```

**Pros**: Write discipline logic once, works with any conforming storage. Extensible.
**Cons**: `~Copyable` types cannot conform to protocols in current Swift (fundamental language limitation). Protocol associated types and generics create complex constraints. This is not viable at the primitives layer — protocols belong at Layer 3 (Foundations).

### Option D: Discipline Namespaces with Static Methods (Functional)

```swift
// Discipline as pure namespace with static operations
public enum Buffer<Element: ~Copyable>: Copyable {
    public enum Linear {}
    public enum Ring {}
    public enum Slab {}
}

// Ring discipline: static methods operating on (header, storage) pairs
extension Buffer.Ring {
    @inlinable
    public static func pushBack(
        _ element: consuming Element,
        header: inout Buffer.Ring.Header,
        storage: Storage<Element>.Heap
    ) { ... }
}
```

**Pros**: No ownership complications — namespaces are stateless. Clean separation of concerns. Easy to compose. No need for generic storage protocol.
**Cons**: Free-function style may feel non-idiomatic. Caller manages header/storage pair manually.

### Recommended Design: Hybrid of A and D

After analyzing the trade-offs, the recommended design uses **discipline-specific value types that own a header, with storage passed to operations**. This is a refinement of Option B that avoids Option A's duplication while maintaining type safety:

**Core insight**: The Header IS the discipline's state. The storage is the discipline's substrate. The Header is lightweight (a few integers) and always Copyable/Sendable. The storage is heavy and potentially ~Copyable. They should live at different ownership levels.

However, for ergonomic use, we also provide **composed types** that bundle header + storage for common cases.

---

## Proposed Type Hierarchy

### Layer 1: Discipline Headers (Pure State)

Headers capture the discipline's cursor/window state without owning any storage. They are always `Copyable` and `Sendable`.

```swift
public enum Buffer<Element: ~Copyable>: Copyable {
    public enum Linear {}
    public enum Ring {}
    public enum Slab {}
}
```

#### Buffer.Linear.Header

```swift
extension Buffer.Linear {
    public struct Header: Copyable, Sendable, Hashable {
        /// Number of initialized elements at [0, count).
        public var count: Index<Element>.Count

        /// Total slot capacity.
        public let capacity: Index<Element>.Count

        public init(capacity: Index<Element>.Count)
    }
}
```

**Initialization mapping**: `Storage.Initialization.linear(count: header.count)`

#### Buffer.Ring.Header

```swift
extension Buffer.Ring {
    public struct Header: Copyable, Sendable, Hashable {
        /// Slot index of the first element.
        public var head: Index<Element>

        /// Number of initialized elements.
        public var count: Index<Element>.Count

        /// Total slot capacity.
        public let capacity: Index<Element>.Count

        public init(capacity: Index<Element>.Count)
    }
}
```

**Initialization mapping**:
- Empty: `count == 0` → `.empty`
- Non-wrapping: `head + count ≤ capacity` → `.one(head..<head+count)`
- Wrapping: `head + count > capacity` → `.two(first: head..<capacity, second: 0..<(head+count-capacity))`

The Header provides a computed property:
```swift
extension Buffer.Ring.Header {
    public var initialization: Storage.Initialization { get }
}
```

#### Buffer.Ring.Header.Cyclic\<let capacity: Int\>

For fixed-capacity ring buffers, a specialized header uses compile-time modular arithmetic:

```swift
extension Buffer.Ring.Header {
    public struct Cyclic<let capacity: Int>: Copyable, Sendable, Hashable {
        public var head: Index<Element>
        public var count: Index<Element>.Count

        public static var capacity: Index<Element>.Count { ... }

        public init()
    }
}
```

The `Cyclic` variant computes `(head + offset) mod capacity` at compile-known modulus, enabling optimizer strength reduction.

#### Buffer.Slab.Header

```swift
extension Buffer.Slab {
    public struct Header: ~Copyable, Sendable {
        /// Occupancy bitmap — bit i set ⟺ slot i is initialized.
        public var bitmap: Bit.Vector

        /// Total slot capacity.
        public var capacity: Bit.Index.Count { bitmap.capacity }

        /// Number of occupied slots.
        public var occupancy: Bit.Index.Count { bitmap.popcount }

        public init(capacity: Bit.Index.Count)
    }
}
```

**Note**: `Buffer.Slab.Header` is `~Copyable` because `Bit.Vector` is `~Copyable` (heap-allocated). This is a key difference from Linear and Ring headers.

#### Buffer.Slab.Header.Static\<let wordCount: Int\>

```swift
extension Buffer.Slab.Header {
    public struct Static<let wordCount: Int>: Copyable, Sendable {
        public var bitmap: Bit.Vector.Static<wordCount>

        public static var capacity: Bit.Index.Count { ... }
        public var occupancy: Bit.Index.Count { bitmap.popcount }

        public init()
    }
}
```

The static variant uses `Bit.Vector.Static` which is `Copyable`, making the header `Copyable` too.

### Layer 2: Discipline Operations (Static Methods on Namespaces)

Operations are defined as static methods on the discipline namespace. They take a header and storage, performing the discipline's logic.

This is the core of the design: **each discipline's operations are pure functions of (header, storage) → (header', storage', result)**.

#### Buffer.Linear Operations

```swift
extension Buffer.Linear {
    // === Append (write at tail) ===

    /// Appends an element at position `count`, incrementing count.
    @inlinable
    public static func append(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage<Element>.Heap
    )
    // Precondition: header.count < header.capacity
    // Effect: storage.initialize(to: element, at: Index(header.count))
    //         header.count += 1
    //         storage.initialization = .linear(count: header.count)

    /// Append variant for inline storage.
    @inlinable
    public static func append(
        _ element: consuming Element,
        header: inout Header,
        storage: inout Storage<Element>.Inline<capacity>
    )

    // === Consume Front (read + shift) ===

    /// Removes and returns the first element, shifting remaining elements left.
    @inlinable
    public static func consumeFront(
        header: inout Header,
        storage: Storage<Element>.Heap
    ) -> Element
    // Precondition: header.count > 0
    // Effect: v = storage.move(at: .zero)
    //         shift elements [1, count) → [0, count-1)
    //         header.count -= 1
    //         return v

    // === Deinitialize All ===

    /// Deinitializes all elements in [0, count).
    @inlinable
    public static func deinitializeAll(
        header: inout Header,
        storage: Storage<Element>.Heap
    )

    // === Span Access (Copyable elements, Heap storage) ===

    /// Provides read-only Span access to initialized elements.
    @inlinable
    public static func withSpan<R, E: Swift.Error>(
        header: Header,
        storage: Storage<Element>.Heap,
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R where Element: Copyable
}
```

#### Buffer.Ring Operations

```swift
extension Buffer.Ring {
    // === Push Back ===

    /// Writes element at the tail position (head + count) mod capacity.
    @inlinable
    public static func pushBack(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage<Element>.Heap
    )
    // Precondition: header.count < header.capacity
    // Effect: tail = (head + count) mod capacity
    //         storage.initialize(to: element, at: tail)
    //         header.count += 1
    //         storage.initialization = header.initialization

    // === Pop Front ===

    /// Removes and returns the element at head.
    @inlinable
    public static func popFront(
        header: inout Header,
        storage: Storage<Element>.Heap
    ) -> Element
    // Precondition: header.count > 0
    // Effect: v = storage.move(at: head)
    //         head = (head + 1) mod capacity
    //         count -= 1
    //         return v

    // === Push Front ===

    /// Writes element at (head - 1) mod capacity.
    @inlinable
    public static func pushFront(
        _ element: consuming Element,
        header: inout Header,
        storage: Storage<Element>.Heap
    )
    // Precondition: header.count < header.capacity
    // Effect: head = (head - 1) mod capacity
    //         storage.initialize(to: element, at: head)
    //         count += 1

    // === Pop Back ===

    /// Removes and returns the element at (head + count - 1) mod capacity.
    @inlinable
    public static func popBack(
        header: inout Header,
        storage: Storage<Element>.Heap
    ) -> Element

    // === Indexed Access ===

    /// Returns the storage slot for logical index i (0-based from front).
    @inlinable
    public static func slot(
        forLogicalIndex i: Index<Element>.Offset,
        header: Header
    ) -> Index<Element>
    // Returns (head + i) mod capacity

    // === Linearize ===

    /// Moves elements so they occupy [0, count) contiguously (unwraps ring).
    @inlinable
    public static func linearize(
        header: inout Header,
        storage: Storage<Element>.Heap
    )
    // Effect: if wrapping, rotate elements so head = 0

    // === Deinitialize All ===

    @inlinable
    public static func deinitializeAll(
        header: inout Header,
        storage: Storage<Element>.Heap
    )

    // All operations also have Storage.Inline overloads.
}
```

#### Buffer.Slab Operations

```swift
extension Buffer.Slab {
    // === Insert ===

    /// Initializes element at the given slot, marking it occupied.
    @inlinable
    public static func insert(
        _ element: consuming Element,
        at slot: Index<Element>,
        header: inout Header,
        storage: Storage<Element>.Heap
    )
    // Precondition: header.bitmap[slot.asBitIndex] == false
    // Effect: storage.initialize(to: element, at: slot)
    //         header.bitmap[slot.asBitIndex] = true

    // === Remove ===

    /// Deinitializes and returns the element at the given slot.
    @inlinable
    public static func remove(
        at slot: Index<Element>,
        header: inout Header,
        storage: Storage<Element>.Heap
    ) -> Element
    // Precondition: header.bitmap[slot.asBitIndex] == true
    // Effect: v = storage.move(at: slot)
    //         header.bitmap[slot.asBitIndex] = false
    //         return v

    // === Iterate Occupied ===

    /// Calls body for each occupied slot's index.
    @inlinable
    public static func forEachOccupied(
        header: borrowing Header,
        _ body: (Index<Element>) -> Void
    )
    // Effect: header.bitmap.ones.forEach { bitIndex in body(bitIndex.asStorageIndex) }

    // === First Vacant ===

    /// Returns the first vacant slot index, or nil if full.
    @inlinable
    public static func firstVacant(
        header: borrowing Header
    ) -> Index<Element>?

    // === Deinitialize All ===

    @inlinable
    public static func deinitializeAll(
        header: inout Header,
        storage: Storage<Element>.Heap
    )
    // Effect: header.bitmap.ones.forEach { slot in storage.deinitialize(at: slot) }
    //         header.bitmap.clear.all()
}
```

### Layer 3: Composed Buffer Types (Ergonomic Wrappers)

For common use cases, composed types bundle header + storage for ergonomic one-object usage.

#### Buffer.Ring — Heap-Backed (Growable)

```swift
extension Buffer.Ring {
    /// A growable ring buffer backed by heap storage.
    public struct Growable<Element: ~Copyable>: ~Copyable {
        public var header: Header
        public var storage: Storage<Element>.Heap

        public init(minimumCapacity: Index<Element>.Count)

        public mutating func pushBack(_ element: consuming Element)
        public mutating func popFront() -> Element
        public mutating func pushFront(_ element: consuming Element)
        public mutating func popBack() -> Element

        public var count: Index<Element>.Count { header.count }
        public var isEmpty: Bool { header.count == .zero }
        public var capacity: Index<Element>.Count { header.capacity }

        deinit // calls Buffer.Ring.deinitializeAll
    }
}

extension Buffer.Ring.Growable: Copyable where Element: Copyable {}
extension Buffer.Ring.Growable: Sendable where Element: Sendable {}
```

Growth is handled by `Buffer.Ring.Growable` internally:
1. Allocate new `Storage.Heap` with grown capacity (via `Buffer.Growth.Policy`)
2. Linearize ring into new storage (move all elements to [0, count))
3. Replace storage, reset head to 0

#### Buffer.Ring — Inline-Backed (Fixed Capacity)

```swift
extension Buffer.Ring {
    /// A fixed-capacity ring buffer backed by inline storage.
    public struct Bounded<Element: ~Copyable, let capacity: Int>: ~Copyable {
        public var header: Header.Cyclic<capacity>
        public var storage: Storage<Element>.Inline<capacity>

        public init() throws(Storage<Element>.Inline<capacity>.Error)

        public mutating func pushBack(_ element: consuming Element)
        public mutating func popFront() -> Element
        // ... same API as Growable, without growth
    }
}

extension Buffer.Ring.Bounded: Copyable where Element: Copyable {}
extension Buffer.Ring.Bounded: Sendable where Element: Sendable {}
```

#### Buffer.Linear — Heap-Backed (Growable)

```swift
extension Buffer.Linear {
    public struct Growable<Element: ~Copyable>: ~Copyable {
        public var header: Header
        public var storage: Storage<Element>.Heap

        public init(minimumCapacity: Index<Element>.Count)

        public mutating func append(_ element: consuming Element)
        public mutating func removeLast() -> Element
        public var count: Index<Element>.Count { header.count }

        deinit
    }
}
```

#### Buffer.Linear — Inline-Backed (Fixed Capacity)

```swift
extension Buffer.Linear {
    public struct Bounded<Element: ~Copyable, let capacity: Int>: ~Copyable {
        public var header: Header
        public var storage: Storage<Element>.Inline<capacity>

        public init() throws(Storage<Element>.Inline<capacity>.Error)

        public mutating func append(_ element: consuming Element)
        public mutating func removeLast() -> Element

        deinit
    }
}
```

#### Buffer.Slab — Heap-Backed

```swift
extension Buffer.Slab {
    public struct Growable<Element: ~Copyable>: ~Copyable {
        public var header: Header
        public var storage: Storage<Element>.Heap

        public init(capacity: Index<Element>.Count)

        public mutating func insert(_ element: consuming Element, at slot: Index<Element>)
        public mutating func remove(at slot: Index<Element>) -> Element

        deinit
    }
}
```

#### Buffer.Slab — Inline-Backed (Fixed Capacity)

```swift
extension Buffer.Slab {
    public struct Bounded<Element: ~Copyable, let capacity: Int, let wordCount: Int>: ~Copyable {
        public var header: Header.Static<wordCount>
        public var storage: Storage<Element>.Inline<capacity>

        public init() throws(Storage<Element>.Inline<capacity>.Error)

        deinit
    }
}
```

### Layer 4: Growth Policy

```swift
extension Buffer {
    public enum Growth {
        public struct Policy: Copyable, Sendable {
            public let grow: @Sendable (Index<Element>.Count) -> Index<Element>.Count

            public static var doubling: Self
            public static func factor(_ multiplier: Double) -> Self
            public static func exact(_ capacity: Index<Element>.Count) -> Self
            public static func pageAligned(pageSize: Int = 4096) -> Self
        }
    }
}
```

Growth policy is only relevant for `Growable` variants. When a push exceeds capacity:

1. Compute new capacity via policy: `newCapacity = policy.grow(currentCapacity)`
2. Allocate new `Storage<Element>.Heap` with `newCapacity`
3. Move all elements from old to new storage (linearizing ring if needed)
4. Replace header capacity
5. Old storage deallocated via ARC (Heap) or scope (Inline — but Inline doesn't grow)

### Index Bridge: Bit.Index ↔ Index\<Storage\>

The slab discipline requires converting between `Bit.Index` (used by `Bit.Vector`) and `Index<Element>` (used by storage). This bridge must be explicit:

```swift
extension Buffer.Slab {
    /// Converts a storage slot index to a bit index for bitmap access.
    @inlinable
    public static func bitIndex(for slot: Index<Element>) -> Bit.Index

    /// Converts a bit index from bitmap to a storage slot index.
    @inlinable
    public static func storageIndex(for bit: Bit.Index) -> Index<Element>
}
```

These are O(1) conversions — both are fundamentally unsigned integer offsets from zero — but the typed wrapper prevents accidental cross-domain use.

---

## Storage.Initialization Integration Map

A key insight: `Storage.Initialization` was designed precisely to track what buffer disciplines need. Here is the exact mapping:

| Discipline | State | `Storage.Initialization` |
|------------|-------|--------------------------|
| Linear | empty | `.empty` |
| Linear | `count` elements | `.one(0..<count)` equivalently `.linear(count: count)` |
| Ring | empty | `.empty` |
| Ring | non-wrapping | `.one(head..<head+count)` |
| Ring | wrapping | `.two(first: head..<capacity, second: 0..<overflow)` |
| Slab | empty | `.empty` |
| Slab | occupied | **Not directly representable** — slab has arbitrary sparse occupancy |

**Critical finding**: `Storage.Initialization` covers Linear and Ring perfectly but cannot represent Slab's sparse occupancy. This is by design:

- **Linear and Ring**: `Storage.Initialization` IS the definitive tracking. The header's `count`/`head` derive the initialization state, and storage's `deinit` uses it for cleanup.
- **Slab**: `Bit.Vector` IS the definitive tracking. The slab buffer overrides storage's deinit behavior to iterate `bitmap.ones` instead of using `Storage.Initialization`.

This means Slab buffers must take ownership of cleanup rather than relying on `Storage.Heap`'s automatic deinit. Two approaches:

1. **Set `storage.initialization = .empty` and handle cleanup manually**: The slab buffer's `deinit` iterates the bitmap and deinitializes each occupied slot, then deallocates storage with `.empty` initialization (so storage's deinit does nothing).

2. **Use a raw `Storage.Heap` with initialization always `.empty`**: Slab never updates storage initialization. Slab's deinit is solely responsible for cleanup.

Approach 1 is safer (storage initialization is at least consistent even if incomplete). The bitmap is the single source of truth for occupied slots.

---

## Module Organization

Following [API-IMPL-005] one type per file and the established module pattern:

```
swift-buffer-primitives/Sources/
  Buffer Primitives Core/
    Buffer.swift                              → enum Buffer<Element>
    Buffer.Linear.swift                       → enum Buffer.Linear
    Buffer.Ring.swift                         → enum Buffer.Ring
    Buffer.Slab.swift                         → enum Buffer.Slab
    Buffer.Growth.swift                       → enum Buffer.Growth
    Buffer.Growth.Policy.swift                → struct Buffer.Growth.Policy
    Buffer.Linear.Header.swift                → struct Buffer.Linear.Header
    Buffer.Ring.Header.swift                  → struct Buffer.Ring.Header
    Buffer.Ring.Header.Cyclic.swift           → struct Buffer.Ring.Header.Cyclic
    Buffer.Slab.Header.swift                  → struct Buffer.Slab.Header
    Buffer.Slab.Header.Static.swift           → struct Buffer.Slab.Header.Static
    exports.swift                             → re-exports of dependencies

  Buffer Linear Primitives/
    Buffer.Linear ~Copyable.swift             → Linear static ops for ~Copyable elements (Heap)
    Buffer.Linear Copyable.swift              → Linear copy ops for Copyable elements (Heap)
    Buffer.Linear.Inline ~Copyable.swift      → Linear static ops (Inline storage)
    Buffer.Linear.Inline Copyable.swift       → Linear copy ops (Inline storage)
    Buffer.Linear.Growable.swift              → struct Buffer.Linear.Growable
    Buffer.Linear.Bounded.swift               → struct Buffer.Linear.Bounded

  Buffer Ring Primitives/
    Buffer.Ring ~Copyable.swift               → Ring static ops (Heap)
    Buffer.Ring Copyable.swift                → Ring copy ops (Heap)
    Buffer.Ring.Inline ~Copyable.swift        → Ring static ops (Inline)
    Buffer.Ring.Inline Copyable.swift         → Ring copy ops (Inline)
    Buffer.Ring.Growable.swift                → struct Buffer.Ring.Growable
    Buffer.Ring.Bounded.swift                 → struct Buffer.Ring.Bounded

  Buffer Slab Primitives/
    Buffer.Slab ~Copyable.swift               → Slab static ops (Heap)
    Buffer.Slab.Inline ~Copyable.swift        → Slab static ops (Inline)
    Buffer.Slab.Growable.swift                → struct Buffer.Slab.Growable
    Buffer.Slab.Bounded.swift                 → struct Buffer.Slab.Bounded

  Buffer Primitives/
    exports.swift                             → public re-export of all modules

  Buffer Primitives Test Support/
    ...test helpers...
```

### Package.swift Dependencies

```swift
dependencies: [
    .package(path: "../swift-storage-primitives"),     // Tier 12
    .package(path: "../swift-bit-vector-primitives"),  // Tier 13 (lateral — documented exception)
    .package(path: "../swift-index-primitives"),       // Tier 6
    .package(path: "../swift-memory-primitives"),      // Tier 10
]
```

**Note on lateral dependency**: `bit-vector-primitives` is Tier 13, same as `buffer-primitives`. This is a documented exception in the tier system — both are in the "Buffers" semantic domain. The dependency is justified because slab buffers fundamentally require bitmap occupancy tracking, and `Bit.Vector` is the canonical implementation.

---

## Empirical Validation (Cognitive Dimensions)

| Dimension | Assessment | Rationale |
|-----------|------------|-----------|
| **Visibility** | HIGH | Three discipline namespaces (`Linear`, `Ring`, `Slab`) are immediately discoverable via `Buffer.` autocomplete. Each has a clear Header, Growable, and Bounded type. |
| **Consistency** | HIGH | Every discipline follows the same pattern: Header (state) + static ops (transitions) + Growable/Bounded (composed). Naming is parallel across disciplines. |
| **Viscosity** | LOW | Adding a new discipline means adding a new namespace + header + ops. No changes to existing disciplines required. Storage strategy changes are localized. |
| **Role-expressiveness** | HIGH | `Buffer.Ring.Header` clearly says "ring buffer cursor state." `Buffer.Ring.Growable` clearly says "growable ring buffer." `Buffer.Slab.Header.Static<4>` clearly says "fixed 256-bit slab bitmap." |
| **Error-proneness** | MEDIUM | Header/storage separation means the caller could theoretically mismatch them. The Growable/Bounded composed types eliminate this risk for common cases. Static method API requires discipline but is explicit. |
| **Abstraction** | APPROPRIATE | Three layers (headers, static ops, composed types) let users choose their abstraction level. ADT authors use static ops for maximum control. Application code uses Growable/Bounded for convenience. |

---

## Comparison with Prior Art

| Aspect | This Design | Rust `bytes` | Rust `ringbuffer` | folly IOBuf |
|--------|------------|--------------|-------------------|-------------|
| Discipline-storage separation | Header vs Storage | Trait vs impl | Trait vs impl | Descriptor vs memory |
| ~Copyable support | First-class | N/A (Rust ownership) | N/A | N/A |
| Inline storage | `Storage.Inline` | `tinyvec` (separate) | `ConstGenericRingBuffer` | No |
| Bitmap occupancy (slab) | `Bit.Vector` | Not in `bytes` | Not applicable | Not applicable |
| Growth policy | Pluggable | `BufMut::remaining_mut` | Trait method | Manual |
| Formal backing | Typed state machine | Informal | Informal | Informal |

---

## Outcome

**Status**: RECOMMENDATION (Converged via Claude–ChatGPT collaborative discussion, 2026-02-03)

**Decision**: Implement the three-layer design with sequence-primitives integration.

### Architecture

1. **Discipline Headers** (pure cursor state, always Copyable except Slab dynamic)
2. **Static discipline operations** (expert-only, on namespace enums, taking header + storage)
3. **Composed buffer types** (`Growable<Element>` and `Bounded<Element, capacity>` per discipline, with sequence protocol conformances)

### Discipline Classification

- **Ordering disciplines**: Linear, Ring (elements have logical sequence)
- **Addressability discipline**: Slab (slots individually addressable, no ordering)

Stack and Deque are access-policy restrictions belonging at Tier 14+.

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Number of disciplines | 3 (Linear, Ring, Slab) | Minimal complete set; Stack/Deque are higher-layer restrictions |
| Discipline classification | Ordering (Linear, Ring) vs Addressability (Slab) | Different axes; prevents Slab from acquiring ordering semantics |
| Header ownership | Headers are separate from storage | Clean separation of state from substrate |
| Namespace generic | `enum Buffer {}` non-generic | Matches `Storage` precedent; Element on composed types |
| Slab tracking | `Bit.Vector` (not `Storage.Initialization`) | Sparse occupancy requires bitmap, not range tracking |
| Slab element iteration | Single `forEachOccupied(header:storage:body:)` | Unordered, borrowing, index+element; no further iteration at Tier 13 |
| Slab.firstVacant | Included as minimal primitive | Word-level bit scan; no search ranges or heuristics |
| Slab.Growable | Architecturally valid, secondary priority | Uncommon; static-op layer supports it, composed type lower priority |
| Inline support | Via storage parameter overloads | Same discipline logic, different storage type |
| Span access | Heap-only | Physical necessity — Storage.Inline 64-byte slots prevent contiguous Span |
| Growth | Owned by Growable via stored `Buffer.Growth.Policy` | Growth is identity, not incidental parameter |
| Composed type naming | `Growable` / `Bounded` | Describes observable semantics (not storage location) |
| Cyclic arithmetic | Via `Cyclic_Primitives` dependency | Maximum dependency reuse principle |
| Bit.Vector lateral dep | Kept at Tier 13 (documented exception) | Not "storage"; premature to move to Tier 12 |
| Sequence integration | Explicit dependency on `sequence-primitives` (Tier 7) | Maximum reuse; composed types become first-class iteration participants |

### Sequence Protocol Conformances

| Composed Type | Sequence.Protocol | Borrowing.Protocol | Consume.Protocol | Clearable |
|---|---|---|---|---|
| Linear.Growable | where Element: Copyable | Yes (contiguous) | Yes | Yes |
| Linear.Bounded | where Element: Copyable | No (Inline, non-contiguous) | Yes | Yes |
| Ring.Growable | where Element: Copyable | Yes (per-segment) | Yes | Yes |
| Ring.Bounded | where Element: Copyable | No (Inline, non-contiguous) | Yes | Yes |
| Slab.Bounded | No (unordered) | No (sparse) | Yes (unordered drain) | Yes |
| Slab.Growable | No (unordered) | No (sparse) | Yes (unordered drain) | Yes |

### Dependencies

```
swift-buffer-primitives (Tier 13)
  ├─ swift-storage-primitives (Tier 12)
  ├─ swift-bit-vector-primitives (Tier 13, lateral exception)
  ├─ swift-sequence-primitives (Tier 7, explicit)
  ├─ swift-cyclic-index-primitives (Tier 9)
  │   └─ swift-cyclic-primitives (Tier 8)
  ├─ swift-index-primitives (Tier 6)
  └─ swift-memory-primitives (Tier 10)
```

### Implementation Priority

1. Ring.Growable + Ring.Bounded (most complex, highest reuse)
2. Linear.Growable + Linear.Bounded
3. Slab.Bounded
4. Slab.Growable (secondary)

### Verification Plan

- Experiment: Implement `Buffer.Ring.Header` + static ops + `Buffer.Ring.Growable` on current storage-primitives
- Experiment: Verify `Storage.Initialization` consistency across push/pop sequences
- Experiment: Verify slab bitmap/storage consistency through insert/remove/deinit cycles
- Experiment: Benchmark composed types vs direct static method usage
- Audit: Dependency reuse sweep — identify any local logic that should delegate to existing primitives

### Resolved Open Questions

| Question | Resolution | Round |
|----------|-----------|-------|
| Growth.Policy storage | Owned by Growable types (part of identity) | Round 1 |
| Bit.Vector tier placement | Keep lateral at Tier 13 (not premature to move) | Round 1 |
| Slab firstVacant | Include as minimal word-scan primitive | Round 1 |
| Cyclic header dependency | Use Cyclic_Primitives (max reuse principle) | Round 2 |

### Collaborative Discussion Record

Converged in 3 rounds between Claude (Anthropic) and ChatGPT (OpenAI). Full transcript at `/tmp/buffer-primitives-design-transcript.md`. Converged plan at `/tmp/buffer-primitives-design-converged.md`.

---

## References

### Foundational
- Wadler, P. (1990). "Linear Types Can Change the World." *IFIP TC 2 Working Conference*.
- Tov, J. A. & Pucella, R. (2011). "Practical Affine Types." *POPL '11*. https://dl.acm.org/doi/10.1145/1925844.1926436
- Bernardy, J.-P. et al. (2017). "Retrofitting Linear Types." Microsoft Research.
- Jung, R. et al. (2018). "RustBelt: Securing the Foundations of the Rust Programming Language." *POPL '18*.
- Xi, H. (2012). "A Linear Type System for Multicore Programming in ATS." *Science of Computer Programming*.

### Buffer Discipline Theory
- Bonwick, J. (1994). "The Slab Allocator: An Object-Caching Kernel Memory Allocator." *USENIX Summer Technical Conference*.
- Snellman, J. (2016). "I've been writing ring buffers wrong all these years." https://www.snellman.net/blog/archive/2016-12-13-ring-buffers/
- Giesen, F. (2010). "Ring Buffers and Queues." https://fgiesen.wordpress.com/2010/12/14/ring-buffers-and-queues/
- Frigo, M. et al. (1999). "Cache-Oblivious Algorithms." *FOCS*.

### Language Implementations
- Rust `bytes` crate. https://docs.rs/bytes/latest/bytes/
- Rust `ringbuffer` crate. https://docs.rs/ringbuffer
- Rust `smallvec` crate. https://github.com/servo/rust-smallvec
- Rust `tinyvec` crate. https://docs.rs/tinyvec/latest/tinyvec/
- Facebook folly `IOBuf`. https://github.com/facebook/folly/blob/main/folly/io/IOBuf.h
- Boost.CircularBuffer. https://www.boost.org/doc/libs/release/libs/circular_buffer/
- OCaml `Cstruct_cap`. https://ocaml.org/p/cstruct/6.1.0/doc/Cstruct_cap/
- Haskell `linear-base`. https://github.com/tweag/linear-base

### Swift Evolution
- SE-0390: Noncopyable Structs and Enums.
- SE-0437: Noncopyable Standard Library Primitives.
- SE-0447: Span — Safe Access to Contiguous Storage.

### Verification
- seL4 Verified Microkernel — ring buffer IPC verification. https://sel4.systems
- Iris Project (Separation Logic in Coq). https://iris-project.org
- Krishna, S. "Compositional Abstractions for Verifying Concurrent Data Structures." NYU.
- Nanevski, A. et al. (2021). "On Algebraic Abstractions for Concurrent Separation Logics." *POPL '21*.

### Internal
- `buffer-algebraic-structure` research (IN_PROGRESS) — confirms buffers are ad-hoc structs, not algebraic intervals.
- `storage-primitives-first-principles` research (IN_PROGRESS) — storage taxonomy.
- `ring-buffer-index-arithmetic` research (DECISION) — cyclic group for bounded, % for dynamic.
- `inline-storage-span-access` research (DECISION) — 64-byte slots prevent dense Span.

### Deferral

**Date**: 2026-03-15

**Reason**: The document reached RECOMMENDATION status (converged via Claude-ChatGPT collaborative discussion) with a complete three-layer design (discipline headers, static operations, composed types) and sequence-primitives integration. Implementation was overtaken by the buffer-primitives inline module split in February 2026, which reorganized the existing buffer code into 5 separate modules (Ring, Linear, Slab, Linked, Arena). The theoretical redesign from first principles has not been reconciled with the post-split module structure.

**Resume when**: The inline module split is stable and a decision is made on whether to proceed with the theoretical redesign or evolve the current split structure incrementally.
