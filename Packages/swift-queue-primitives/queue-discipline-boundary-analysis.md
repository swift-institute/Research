# Queue Discipline Boundary Analysis

<!--
---
version: 1.0.0
last_updated: 2026-02-14
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute primitives architecture establishes a strict four-layer dependency chain:

```
Memory (Tier 13) -> Storage (Tier 14) -> Buffer (Tier 15) -> Data Structure (Tier 16+)
```

`queue-primitives` sits at the top of this chain, wrapping `Buffer.Ring` (and its variants: `Buffer.Ring.Bounded`, `Buffer.Ring.Inline`, `Buffer.Ring.Small`, `Buffer.Linked`) to present a consumer-facing queue abstraction. The question: does `queue-primitives` contain ONLY queue-discipline semantics, or has buffer-level concern leaked upward?

**Trigger**: [RES-012] Discovery -- proactive design audit to verify layering discipline.

**Scope**: Package-specific (swift-queue-primitives).

## Question

What semantics belong SOLELY to the queue abstraction layer, and does `queue-primitives` currently contain anything that properly belongs to the buffer layer?

---

## Prior Art Survey

### Source 1: Formal ADT Theory (Liskov & Guttag, Software Foundations)

The formal algebraic specification for a FIFO Queue:

```
Sorts: Queue, Element, Boolean

Operations:
  empty    : -> Queue
  enqueue  : Queue x Element -> Queue
  dequeue  : Queue -> Queue x Element
  peek     : Queue -> Element
  is_empty : Queue -> Boolean

Axioms:
  is_empty(empty)               = true
  is_empty(enqueue(q, e))       = false
  dequeue(enqueue(empty, e))    = (empty, e)
  dequeue(enqueue(q, e))        = let (q', e') = dequeue(q) in (enqueue(q', e), e')
                                  where !is_empty(q)
  peek(enqueue(empty, e))       = e
  peek(enqueue(q, e))           = peek(q)  where !is_empty(q)
```

The critical axiom is the **FIFO ordering law**: `dequeue` always returns the *oldest* enqueued element. The ADT mentions NO implementation concerns: no ring buffer, no capacity, no head/tail pointers, no contiguous memory. The queue is purely the **FIFO access discipline with ordering preservation laws**.

A double-ended queue (deque) extends this with symmetric access:

```
Operations: push_front, push_back, pop_front, pop_back, peek_front, peek_back

Axioms:
  pop_front(push_back(empty, e))   = (empty, e)
  pop_back(push_front(empty, e))   = (empty, e)
  pop_front(push_front(q, e))      = (q, e)         (stack-like at front)
  pop_back(push_back(q, e))        = (q, e)          (stack-like at back)
```

The deque's distinguishing axiom: **both ends** support insertion and removal, with FIFO at front-to-back and LIFO at each individual end.

### Source 2: Rust `VecDeque` (std::collections)

Rust's `VecDeque` is a double-ended queue implemented with a growable ring buffer. It provides:

- `push_back` / `push_front` -- the queue discipline operations
- `pop_back` / `pop_front` -- symmetric removal
- `front()` / `back()` -- peek without removal
- `make_contiguous()` -- exposes that the ring may wrap (implementation detail leaking into API)
- `as_slices()` -- returns the two contiguous halves (implementation detail)
- `len()`, `is_empty()`, `capacity()` -- state queries
- Full `Index` trait (random access by position) -- contested: this is array-like, not queue-like
- `Iterator`, `IntoIterator`, `FromIterator` -- sequence integration
- `Eq`, `Hash`, `Ord`, `Clone`, `Debug` -- algebraic/trait conformances
- `drain()`, `retain()`, `resize()` -- bulk operations

**Key observation**: Rust does NOT have a separate `Queue` type. `VecDeque` serves as both queue and deque, conflating the FIFO restriction with general double-ended access. There is no `RawRingBuf` / `VecDeque` split analogous to `RawVec` / `Vec`. The buffer and queue concerns live in the same type.

**Contrast with our architecture**: We have `Buffer.Ring` owning the ring mechanics, and `Queue` / `Queue.DoubleEnded` owning the access discipline. This is a *stricter* separation than Rust provides.

### Source 3: C++ STL Queue / Deque Adapters (Stepanov)

The C++ STL makes the queue/buffer separation **explicit through the adapter pattern**:

- `std::deque<T>` is the underlying container (our `Buffer.Ring` equivalent). It owns memory layout, growth, contiguous-segment management, and random access.
- `std::queue<T>` is a **container adapter** that wraps `std::deque` (or `std::list`) and restricts the interface to FIFO operations only: `push()`, `pop()`, `front()`, `back()`, `empty()`, `size()`.
- `std::priority_queue<T>` is another adapter adding priority ordering.

The STL's design philosophy: the queue adds **no storage capability** -- it is purely an access restriction. Multiple reasons exist for this wrapper: (1) providing semantic meaning, (2) restricting accidental misuse of unintended functions, (3) presenting a specific interface.

**This is the closest prior art to our architecture**. Our `Queue` wraps `Buffer.Ring` exactly as `std::queue` wraps `std::deque`. The key difference: our Queue also provides protocol conformances and type-system integration that C++ adapters cannot.

### Source 4: Haskell / Okasaki's Functional Queues

Okasaki's purely functional queues (1996, CMU-CS-96-177) decompose the queue into:

- **Two lists**: a front list (for dequeue) and a reversed rear list (for enqueue)
- **Invariant**: the front list is non-empty whenever the queue is non-empty
- **Rotation**: when front empties, reverse rear onto front (O(n) amortized to O(1))
- **Lazy scheduling**: spread the reversal cost across subsequent operations

The algebraic structure:

- **Functor**: `fmap` over queue preserves FIFO order
- **Foldable**: collapse in FIFO order
- **Monoid**: concatenation with empty queue as identity
- **No random access**: the queue abstraction deliberately forbids positional indexing in the algebraic treatment

Okasaki demonstrated that the queue discipline itself (not the buffer) determines the amortized complexity bounds. The two-list representation is queue-specific; a buffer would never choose this structure.

### Source 5: What Makes a Queue a Queue (vs. a Buffer)

From the literature survey, the fundamental distinction:

| Property | Buffer | Queue |
|----------|--------|-------|
| **Access pattern** | Random / positional | Restricted (front/back only) |
| **Ordering guarantee** | Elements at positions | FIFO ordering between enqueue/dequeue |
| **Identity** | Memory region with capacity | Logical sequence with discipline |
| **Growth** | Capacity management concern | Transparent to consumer |
| **Element lifecycle** | init/move/deinit mechanics | Invisible -- consumer sees values |
| **Core invariant** | `count <= capacity` | `dequeue returns oldest enqueued` |

The queue's **sole addition** over a buffer is the access discipline: you may only add at the back and remove at the front (or symmetrically for deque). Everything else -- allocation, capacity, CoW, element lifecycle, ring wrapping -- belongs to the buffer.

---

## Analysis

### What is SOLELY Queue Discipline

#### A. Access Discipline (The Defining Property)

The queue's primary contribution: **restricting** the buffer's general-purpose interface to FIFO (or double-ended) access patterns. The buffer provides `pushBack`, `pushFront`, `popBack`, `popFront` as raw ring operations; the queue decides *which* of these to expose and *how*.

| API | What it provides | Why not in Buffer |
|-----|-----------------|-------------------|
| `enqueue(_:)` | FIFO insertion -- back only | Buffer exposes both `pushFront` and `pushBack`; queue restricts to back |
| `dequeue()` | FIFO removal -- front only | Buffer exposes both `popFront` and `popBack`; queue restricts to front |
| `peek()` / `peek(_:)` | Non-destructive front inspection | Buffer provides `peekFront`, `peekBack`, and subscript; queue restricts to front |
| `push(_:to:)` on DoubleEnded | Position-parameterized insertion | Buffer has separate methods; deque adds the `Position` enum to unify them |
| `pop(from:)` on DoubleEnded | Position-parameterized removal | Same -- the `Position` type is queue discipline |
| `front` / `back` accessors on DoubleEnded | Property.View-based positional access | The accessor pattern with `push`/`pop`/`take`/`peek` per position is purely queue ergonomics |
| `drain(_:)` | Consuming traversal in FIFO order | The ordering guarantee (front-to-back) is queue discipline |

#### B. Protocol/Interface Conformance

The queue makes the ring buffer a **citizen of the type system's protocol hierarchy**. The buffer provides mechanisms; the queue provides contracts.

| Conformance | What it provides | Why not in Buffer |
|-------------|-----------------|-------------------|
| `Sequence.Protocol` | Multi-pass traversal contract (FIFO order) | Buffer Ring's traversal is an implementation detail; Queue commits to FIFO iteration |
| `Swift.Sequence` | `for-in` loops, `map`, `filter` | Buffer should not carry stdlib coupling |
| `Swift.Collection` | Indexed traversal contract | Queue.DoubleEnded commits to Collection; plain Queue provides it too |
| `Swift.BidirectionalCollection` | Reverse traversal | Queue.DoubleEnded provides this; buffer does not commit to it |
| `Swift.RandomAccessCollection` | O(1) distance as semantic *guarantee* | Buffer provides O(1) as implementation *fact*; Queue elevates it to obligation |
| `Collection.Indexed` | `startIndex`/`endIndex`/`index(after:)` | The index *navigation* contract is Queue's |
| `Collection.Bidirectional` | `index(before:)` | Same |
| `Collection.Protocol` | Full collection contract | Same |
| `Collection.Access.Random` | Random-access guarantee | Same |
| `Input.Streaming` | `first` + `advance()` cursor protocol | Queue-as-input-stream is a queue-level semantic commitment |
| `Input.Protocol` | Checkpoint/restore for backtracking | The "stream of values" interpretation is queue discipline |
| `Sequence.Drain.Protocol` | Consuming iteration contract | Drain ordering (FIFO) is queue discipline |
| `Sequence.Clearable` | `removeAll()` contract | Enables Property.View consuming patterns |
| `Sequence.Iterator.Protocol` | Iterator type contract | Same |
| `ExpressibleByArrayLiteral` | `[1, 2, 3]` syntax | Consumer ergonomics |

#### C. Semantic Contracts

| Contract | Explanation |
|----------|-------------|
| **FIFO ordering** | `dequeue()` always returns the oldest enqueued element. This is THE queue axiom. The buffer has no ordering opinion. |
| **Position semantics** | Position 0 is the front (next to dequeue); position `count-1` is the back (most recently enqueued). Buffer positions are physical. |
| **Value semantics commitment** | Buffer provides CoW *mechanism*; Queue commits to `var b = a; b.enqueue(x)` not affecting `a`. |
| **Capacity-independent identity** | Two queues with the same elements in the same FIFO order are equal regardless of capacity. The buffer has no equality concept. |
| **Overflow as semantic error** | `Queue.Fixed.Error.overflow`, `Queue.Static.Error.overflow` -- "you tried to enqueue into a full queue" is a queue-level semantic. The buffer just has a full flag. |
| **Empty as semantic error** | `Queue.Linked.Error.empty` -- "you tried to dequeue from an empty queue" is a queue-level concern. |
| **Safe peek alternatives** | `peek()` returning Optional for Copyable; `peek(_:)` with closure for ~Copyable. The borrow-vs-copy distinction at the consumer API level is queue discipline. |

#### D. Type-Level Invariants

| Invariant | What it adds |
|-----------|-------------|
| `Queue.Fixed` -- bounded FIFO | Compile-time commitment: "this queue will never grow beyond N." Buffer.Ring.Bounded provides the mechanism; Queue adds the semantic contract and typed error. |
| `Queue.Static<capacity>` -- inline FIFO | Promise to the user: "this never heap-allocates." |
| `Queue.Small<inlineCapacity>` -- hybrid FIFO | SmallVec-pattern applied to queue discipline. |
| `Queue.Linked` -- arena-backed FIFO | O(1) worst-case operations via linked storage. The queue decides to use linked backing. |
| `Queue.DoubleEnded` -- symmetric access | The type itself IS the discipline: "both ends are accessible." |
| `Queue.DoubleEnded.Position` enum | `.front` / `.back` as first-class position type. This is purely queue vocabulary. |
| Conditional `Copyable` | `Copyable where Element: Copyable` as user-facing guarantee. |
| Conditional `Sendable` | `@unchecked Sendable where Element: Sendable`. |
| `Deque<Element>` typealias | Consumer-facing name for `Queue<Element>.DoubleEnded`. |

#### E. Algebraic Structure

| Property | Queue owns it |
|----------|---------------|
| `Equatable` (`==`) | Element-wise, capacity-independent, FIFO-order comparison |
| `Hashable` | Element-wise hashing in FIFO order |
| `CustomStringConvertible` | Human-readable FIFO-order representation |
| `ExpressibleByArrayLiteral` | Literal syntax for queue construction |

#### F. Consumer-Facing Ergonomics

| Feature | What it adds |
|---------|-------------|
| Variant taxonomy | Coherent `Queue`/`Fixed`/`Static`/`Small`/`Linked`/`DoubleEnded` family |
| Iterator types | `Queue.Iterator`, `Queue.Fixed.Iterator`, `Queue.Static.Iterator`, `Queue.Small.Iterator`, `Queue.Linked.Iterator`, `Queue.DoubleEnded.Iterator`, etc. |
| Error type taxonomy | `Queue.Error`, `Queue.Fixed.Error`, `Queue.Static.Error`, `Queue.Linked.Error`, `Queue.Linked.Fixed.Error`, etc. |
| Property.View patterns | `.drain { }`, `.forEach { }`, `.front.push()`, `.front.pop()`, `.back.push()`, `.back.pop()` |
| PeekAccessor (DoubleEnded) | `deque.peek.front`, `deque.peek.back` -- non-mutating peek namespace |
| Sequence Tag enums | `Queue.Static.Drain.View`, `Queue.Static.ForEach.View`, etc. for Property.View typed access |
| `clear(keepingCapacity:)` | Consumer-facing boolean flag for capacity policy |
| `compact()` | "Release unused memory" as consumer operation |
| `reserve(_:)` | "Pre-allocate for known workload" as consumer operation |
| `init(reservingCapacity:)` | Pre-allocation at construction time |
| `init(_ elements:)` (DoubleEnded) | Sequence-based construction |

### What Buffer.Ring Owns (Queue Merely Delegates)

| Concern | Owned by Buffer.Ring |
|---------|---------------------|
| Memory allocation/deallocation | Creates/destroys `Storage.Heap` |
| Capacity tracking | `Header.capacity` |
| Count tracking | `Header.count` |
| Growth policy | Doubling strategy, minimum capacity |
| CoW mechanism | `ensureUnique()` |
| Element init/move/deinit lifecycle | Via `Storage` |
| Ring wrapping (head/tail modular arithmetic) | Physical index calculation |
| Raw `pushFront`/`pushBack`/`popFront`/`popBack` | Ring buffer operations |
| `peekFront`/`peekBack` | Raw element access |
| `withFront(_:)`/`withBack(_:)` | Borrowing access |
| Contiguous memory management | `make_contiguous`-equivalent |
| `forEach` traversal implementation | Walking the ring in physical order |
| Inline storage management (Static/Small) | `Buffer.Ring.Inline`, `Buffer.Ring.Small` |
| Checkpoint mechanism | `Buffer.Ring.Checkpoint` / `restore(to:)` |
| Linked-list arena allocation | `Buffer.Linked` node management |
| `isFull`/`isEmpty` state flags | Header state machine |
| Subscript by logical index | Direct ring buffer access |

---

## Audit: Current queue-primitives

### Audit Methodology

For each public API member across all source files in `queue-primitives`, classify as:
- **QUEUE**: Solely queue discipline (access restriction, protocol conformance, semantic contract, type invariant, ergonomics)
- **DELEGATE**: Pure delegation to buffer (thin wrapper calling `_buffer.foo`)
- **CONTESTED**: Could belong to either layer

### Findings

#### Pure Queue Discipline (correctly placed)

| Item | Category | Variants |
|------|----------|----------|
| `enqueue(_:)` | Access discipline | Queue, Fixed, Static, Small, Linked, Linked.Fixed, Linked.Inline, Linked.Small |
| `dequeue()` | Access discipline | All variants |
| `peek()` / `peek(_:)` | Access discipline | All variants |
| `push(_:to:)` | Access discipline | DoubleEnded, DoubleEnded.Fixed, DoubleEnded.Static, DoubleEnded.Small |
| `pop(from:)` | Access discipline | All DoubleEnded variants |
| `take(from:)` | Access discipline | All DoubleEnded variants |
| `clear(keepingCapacity:)` / `clear()` | Consumer ergonomics | All variants |
| `Queue.DoubleEnded.Position` enum | Type-level vocabulary | DoubleEnded |
| `Deque<Element>` typealias | Consumer naming | Module-level |
| `Swift.Sequence` conformance | Protocol | Queue, Fixed, Linked, Linked.Fixed, DoubleEnded, DoubleEnded.Fixed |
| `Sequence.Protocol` conformance | Protocol | Queue, Fixed, Static, Small, DoubleEnded, DoubleEnded.Fixed, DoubleEnded.Static, DoubleEnded.Small |
| `Swift.Collection` / `BidirectionalCollection` / `RandomAccessCollection` | Protocol | Queue, DoubleEnded, DoubleEnded.Fixed |
| `Collection.Indexed` / `Collection.Bidirectional` | Protocol | Queue, DoubleEnded, DoubleEnded.Fixed |
| `Collection.Protocol` / `Collection.Access.Random` | Protocol | DoubleEnded, DoubleEnded.Fixed |
| `Input.Streaming` conformance | Protocol | Queue, Fixed, Static, Small |
| `Input.Protocol` conformance (checkpoint/restore) | Protocol | Queue, Fixed, Static, Small |
| `Sequence.Drain.Protocol` conformance | Protocol | Queue, Fixed, Static, Small, Linked, DoubleEnded, DoubleEnded.Fixed, DoubleEnded.Static, DoubleEnded.Small |
| `Sequence.Clearable` conformance | Protocol | Queue, Fixed, Static, Small, Linked, DoubleEnded, DoubleEnded.Fixed, DoubleEnded.Static, DoubleEnded.Small |
| `Equatable` / `Hashable` | Algebraic | Queue, Linked, Linked.Fixed, DoubleEnded |
| `ExpressibleByArrayLiteral` | Syntax sugar | Queue, DoubleEnded |
| `CustomStringConvertible` | Ergonomics | Queue, DoubleEnded |
| Iterator types (`Queue.Iterator`, etc.) | Type identity | All Copyable variants |
| Error type taxonomy (`Queue.Error`, etc.) | Semantic errors | All variants |
| Conditional `Copyable` / `Sendable` | Type invariant | All variants |
| Property.View patterns (`.drain`, `.forEach`, `.front`, `.back`, `.peek`) | Ergonomics | Various variants |
| Sequence Tag enums (`Drain.View`, `ForEach.View`, etc.) | Property.View support | Static, Small, DoubleEnded.Static, DoubleEnded.Small |
| PeekAccessor struct (DoubleEnded) | Ergonomics | DoubleEnded |
| Front/Back namespaces and Property.View.Typed extensions | Ergonomics | DoubleEnded |
| `forEach(_:)` (borrowing, FIFO-order guarantee) | Access discipline + ordering | All variants |
| Bounds-checked subscript with precondition | Safety contract | Queue, DoubleEnded, DoubleEnded.Fixed |
| `element(at:)` safe access | Safety contract | Queue |
| `init(reservingCapacity:)` | Consumer ergonomics | Queue, Linked, DoubleEnded |
| `init(_ elements:)` (Sequence) | Consumer ergonomics | DoubleEnded |
| Variant taxonomy and namespace | Architecture | `Queue.swift` |

#### Pure Delegation (correctly placed -- thin wrappers are the point)

| Item | Delegates to | Verdict |
|------|-------------|---------|
| `var count` -> `_buffer.count` | Buffer.Ring.Header | **OK** -- Queue surface for buffer state |
| `var isEmpty` -> `_buffer.isEmpty` | Buffer.Ring.Header | **OK** |
| `var capacity` -> `_buffer.capacity` | Buffer.Ring.Header | **OK** |
| `var isFull` -> `count >= capacity` or `_buffer.isFull` | Buffer.Ring.Header | **OK** |
| `reserve(_:)` -> `_buffer.reserveCapacity(_:)` | Buffer.Ring | **OK** |
| `compact()` -> `_buffer.compact()` | Buffer.Ring | **OK** |
| subscript `_read`/`_modify` -> `_buffer[index]` | Buffer.Ring | **OK** -- Queue adds the index type and preconditions |
| `makeUnique()` -> `_buffer.ensureUnique()` | Buffer.Ring | **OK** -- internal CoW delegation |
| `forEach(_:)` -> `_buffer.forEach(_:)` | Buffer.Ring | **OK** -- Queue adds the FIFO ordering guarantee |

#### Contested / Observations

| Item | Issue | Assessment |
|------|-------|------------|
| `isSpilled` on `Queue.Small` and `Queue.DoubleEnded.Small` | Exposes buffer implementation detail (inline vs heap). | **CONTESTED** -- a user reasonably wants to know if they've spilled. The SmallVec pattern's value proposition depends on knowing when you've spilled. This is a valid consumer-facing diagnostic property. Keep it. |
| `isSpilled` on `Queue.Linked.Small` | Same as above. | **CONTESTED** -- same rationale. Keep it. |
| `compact()` on `Queue` | Triggers ring buffer linearization -- buffer-level concern. | **OK** -- the user intent ("release unused memory") is queue-level. The linearization is an implementation consequence, not exposed. |
| `reserve(_:)` on `Queue` and `Queue.Linked` | Capacity reservation is a buffer concern. | **OK** -- consumer ergonomics. The user wants to "pre-allocate for my workload." The how (buffer growth) is hidden. |
| `Checkpoint` typealias exposing `Buffer<Storage<Element>.Heap>.Ring.Checkpoint` | The `Input.Protocol` conformance exposes the buffer's checkpoint type directly. | **MINOR LEAK** -- `Checkpoint` is a public typealias to `Buffer<Storage<Element>.Heap>.Ring.Checkpoint`. The buffer type name is visible to consumers. Consider wrapping in a `Queue.Checkpoint` for abstraction, though this is cosmetic since the checkpoint is opaque to users anyway. |
| `Queue.Static.Iterator` copies to `Buffer.Linear` snapshot | Iterator creates a `Buffer<Element>.Linear` internally for safe iteration. | **OK** -- this is an implementation detail hidden behind the `Iterator` type. The user sees `Queue.Static.Iterator`, not the buffer copy. |
| `Queue.Linked.Iterator` wraps `Buffer<Element>.Linked<1>.Iterator` | Thin wrapper providing queue-level type identity. | **OK** -- correctly wraps the buffer iterator. |
| `_deinitWorkaround: AnyObject?` on `Queue.Static` and `Queue.DoubleEnded.Static` | Compiler bug workaround. | **OK** -- not part of public API. Documented with issue link. |
| `_identity` on `Queue.DoubleEnded` | Exposes `ObjectIdentifier` of buffer storage for CoW testing. | **OK** -- `@usableFromInline internal`, not public. Testing infrastructure. |
| Collection conformances on plain `Queue` | Plain FIFO queue providing `RandomAccessCollection` with subscript. | **CONTESTED** -- a pure FIFO queue in ADT theory forbids random access. However, `Queue` wraps a ring buffer where O(1) random access is efficient, and Swift's protocol hierarchy makes Collection conformance extremely valuable. This is a pragmatic decision: the FIFO discipline is expressed through `enqueue`/`dequeue` naming; Collection conformance is an *additional* capability that doesn't violate FIFO semantics. This matches `VecDeque` in Rust which also provides `Index`. |

### What's MISSING from Queue (things that are solely queue discipline but not yet present)

| Missing | Category | Priority |
|---------|----------|----------|
| `Equatable` on `Queue.Fixed` | Algebraic | Medium -- capacity-independent equality is core queue semantics |
| `Hashable` on `Queue.Fixed` | Algebraic | Medium -- follows from Equatable |
| `Equatable`/`Hashable` on `Queue.Static`, `Queue.Small` | Algebraic | Medium -- same rationale |
| `Equatable`/`Hashable` on DoubleEnded variants (Fixed, Static, Small) | Algebraic | Medium |
| `CustomStringConvertible` on all non-Dynamic variants | Ergonomics | Low |
| `ExpressibleByArrayLiteral` on `Queue.Fixed`, `Queue.Linked` | Syntax sugar | Low |
| `Collection` conformances on `Queue.Fixed` | Protocol | Low -- Fixed queue is less commonly iterated by index |
| `init<S: Swift.Sequence>(_:)` on `Queue` (dynamic) | Consumer ergonomics | Low |

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: queue-primitives is well-layered

The current `queue-primitives` package is **overwhelmingly correct** in its separation of concerns. Every public API member falls cleanly into one of:

1. **Access discipline** -- `enqueue`/`dequeue`/`peek`/`push`/`pop` restricting buffer operations to FIFO or double-ended patterns
2. **Protocol conformance** -- making the queue a citizen of the type system's protocol hierarchy
3. **Semantic contract** -- typed errors, FIFO ordering guarantees, value semantics commitment
4. **Pure delegation** -- thin wrappers with queue-level naming and preconditions
5. **Consumer ergonomics** -- variant taxonomy, Property.View patterns, iterator types

### Specific Recommendations

#### 1. Wrap `Queue.Checkpoint` (Minor)

The `Input.Protocol` conformance on Queue, Queue.Fixed, Queue.Static, and Queue.Small all expose `Buffer<Storage<Element>.Heap>.Ring.Checkpoint` (or `Buffer<Storage<Element>.Heap>.Ring.Small<N>.Checkpoint`) as a public typealias. For abstraction purity, consider wrapping in `Queue.Checkpoint`. This is cosmetic -- the type is opaque to consumers regardless.

#### 2. Add `Equatable` / `Hashable` to More Variants (Medium Priority)

Queue (dynamic) and Queue.Linked already have `Equatable`/`Hashable`. These are core queue-discipline semantics (capacity-independent, FIFO-order element-wise comparison). Currently absent from Queue.Fixed, Queue.Static, Queue.Small, and most DoubleEnded sub-variants.

#### 3. `isSpilled` is acceptable

`Queue.Small.isSpilled` and `Queue.DoubleEnded.Small.isSpilled` expose buffer implementation details, but they are *diagnostic* properties that users legitimately need. The SmallVec pattern's value proposition depends on knowing when spill occurred. Keep them.

#### 4. Collection on plain Queue is a pragmatic correct decision

Pure ADT theory forbids random access on queues. However, Swift's protocol hierarchy makes Collection conformance immensely valuable (stdlib algorithm interop, subscripting, slicing). The FIFO discipline is expressed through the `enqueue`/`dequeue` naming convention; Collection is an additive capability. This matches Rust's `VecDeque` (provides `Index` trait) and is consistent with how `array-primitives` provides Collection over Buffer.Linear.

#### 5. No buffer concerns have leaked upward

The audit found **zero instances** of queue-primitives doing work that properly belongs to the buffer layer. All storage management, growth, CoW mechanics, element lifecycle, ring wrapping, head/tail pointer arithmetic, and linked-list arena management are handled by `Buffer.Ring` / `Buffer.Linked` and their variants. Queue's `_buffer` stored property is the only coupling, and it is correctly `package`-scoped.

### Summary Table

| Layer | Concern Count | Assessment |
|-------|:---:|---|
| Pure queue discipline | 60+ distinct APIs across 13 type variants | Correctly placed |
| Pure delegation | ~10 passthrough properties/methods per variant | Correctly placed -- thin wrapping is the design intent |
| Buffer concern leaked into queue | **0** | Clean separation |
| Queue concern missing | 8-10 items | Future work, not a layering violation |
| Contested items | 3 (isSpilled x3, Checkpoint typealias, Collection on FIFO) | All acceptable with rationale |

---

## References

- Liskov & Guttag, "Abstraction and Specification in Program Development": ADT axioms for queues
- [Software Foundations (UPenn), "ADT: Abstract Data Types"](https://softwarefoundations.cis.upenn.edu/vfa-current/ADT.html)
- [Queue (abstract data type) -- Wikipedia](https://en.wikipedia.org/wiki/Queue_(abstract_data_type))
- Okasaki, "Purely Functional Data Structures" (1996, CMU-CS-96-177): amortized functional queues
- [Okasaki (1996) -- Simple and efficient purely functional queues and deques](https://www.cambridge.org/core/journals/journal-of-functional-programming/article/simple-and-efficient-purely-functional-queues-and-deques/7B3036772616B39E87BF7FBD119015AB)
- [Rust `VecDeque` documentation](https://doc.rust-lang.org/std/collections/struct.VecDeque.html)
- [Rust `VecDeque` improvement proposal (Issue #99805)](https://github.com/rust-lang/rust/issues/99805)
- [C++ `std::queue` -- cppreference.com](https://en.cppreference.com/w/cpp/container/queue.html)
- [C++ `std::queue` -- cplusplus.com](https://cplusplus.com/reference/queue/queue/)
- Stepanov & McJones, "Elements of Programming" (2009): coordinate structures and container concepts
- [Circular buffer -- Wikipedia](https://en.wikipedia.org/wiki/Circular_buffer)
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-discipline-boundary-analysis.md`
