# Stack Discipline Boundary Analysis

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
Memory (Tier 13) → Storage (Tier 14) → Buffer (Tier 15) → Data Structure (Tier 16+)
```

`stack-primitives` sits at the top of this chain, wrapping `Buffer.Linear` (and its variants) to present a consumer-facing stack abstraction. The question: does `stack-primitives` contain ONLY stack-discipline semantics, or has buffer-level concern leaked upward?

**Trigger**: [RES-012] Discovery — proactive design audit to verify layering discipline.

**Scope**: Package-specific (swift-stack-primitives).

## Question

What semantics belong SOLELY to the stack abstraction layer, and does `stack-primitives` currently contain anything that properly belongs to the buffer layer?

---

## Prior Art Survey

### Source 1: Formal ADT Axioms (Liskov & Guttag / UNC COMP 410)

The stack is one of the original ADTs formalized axiomatically. The formal specification:

```
Sorts: STACK, E, nat, boolean

Canonical constructors: new, push
Non-canonical constructors: pop
Examiners: size, empty, top

Operations:
  new:              → STACK
  push: STACK × E   → STACK
  pop:  STACK        → STACK
  top:  STACK        → E
  size: STACK        → nat
  empty: STACK       → boolean

Axioms:
  size(new)          = 0
  size(push(S,e))    = size(S) + 1
  empty(new)         = true
  empty(push(S,e))   = false
  top(new)           = error
  top(push(S,e))     = e
  pop(new)           = new
  pop(push(S,e))     = S
```

**Key**: The axioms define a stack purely in terms of its LIFO discipline. There is no mention of indices, capacity, contiguous memory, or iteration. The stack is entirely defined by two facts: (1) `top(push(S,e)) = e` — you get back what you last pushed, and (2) `pop(push(S,e)) = S` — popping restores the prior state. Everything else is derivable from these two axioms plus the constructors.

### Source 2: C++ STL `std::stack` (Container Adapter)

C++ provides the purest industrial separation. `std::stack` is a *container adapter* — it wraps a `SequenceContainer` (defaulting to `std::deque`) and **restricts its interface** to enforce LIFO discipline:

**Exposed (stack discipline)**:
- `top()` — access top element (reference to `back()`)
- `push()` / `emplace()` — add to top
- `pop()` — remove from top
- `empty()` / `size()` — capacity queries
- `swap()` — exchange contents
- Comparison operators (`==`, `<=>`)

**Hidden (underlying container operations)**:
- Random access (`operator[]`, `at()`)
- Front access (`front()`)
- **Iteration** — no iterators whatsoever
- Position-based insert/erase
- Direct container manipulation

**Key**: `std::stack` deliberately hides iteration, subscripting, and all position-based access. The entire value proposition is *restriction*: a stack is a container that refuses to let you do anything except interact with the top. This is the single strongest design signal in the prior art.

### Source 3: Rust `Vec<T>` as Stack

Rust has no dedicated `Stack` type. Instead, `Vec<T>` provides `push()` and `pop()` methods directly, and programmers use `Vec` when they want stack semantics. This is the "stack is just a restricted vector" school of thought.

However, Rust's `heapless` crate provides `Vec<T, N>` — a fixed-capacity, inline-storage vector — which is structurally equivalent to `Stack.Static` in our architecture. The crate enforces the same pattern: the data structure wraps a buffer primitive and adds consumer-facing semantics.

**Key**: Rust's approach suggests that a stack is a *usage discipline* on a buffer, not a separate data structure. The stack adds no storage mechanism — it adds a vocabulary (`push`/`pop`/`peek` instead of `append`/`removeLast`/`last`) and, critically, the *absence* of certain operations (no `insert(at:)`, no `remove(at:)`).

### Source 4: Haskell `Data.Stack` (Algebraic)

Haskell's `Data.Stack` package provides a minimal stack:

```haskell
stackNew    :: Stack a
stackPush   :: a -> Stack a -> Stack a
stackPop    :: Stack a -> (Maybe a, Stack a)
stackPeek   :: Stack a -> Maybe a
stackIsEmpty :: Stack a -> Bool
stackSize   :: Stack a -> Int
```

Typeclass instances: `Read`, `Show`, `Semigroup`, `Monoid`, `NFData`.

**Key**: The Haskell stack is algebraically minimal. It provides no iteration, no indexing, no mapping. The `Semigroup`/`Monoid` instance (stack concatenation with empty stack as identity) is the only algebraic structure. This is even more restrictive than `std::stack`.

### Source 5: Stack vs Array — The Definitional Difference

Comparing with the companion analysis (`array-discipline-boundary-analysis.md`):

| Property | Array | Stack |
|----------|-------|-------|
| Access discipline | Indexed random access | Top-only access |
| Core axiom | `get(set(a,i,v), i) = v` | `top(push(S,e)) = e` |
| Iteration | Core semantic (Collection) | **Anti-pattern** (violates LIFO) |
| Subscript | Core semantic (O(1) indexed) | **Anti-pattern** (bypasses top) |
| Protocol conformance | Collection hierarchy | Sequence at most |
| Density invariant | Yes (every index mapped) | N/A (no index concept) |

An array's identity is *indexed access*. A stack's identity is *restriction* — what it refuses to expose. The array adds capabilities atop the buffer; the stack *removes* capabilities. This is the fundamental tension in our architecture: the stack's value is in what it *hides*, but our implementation currently *exposes* indexed access, iteration, and subscript.

---

## Analysis

### What is SOLELY Stack Discipline

#### A. Protocol/Interface Conformance

Unlike the array (which contributes the entire Collection protocol hierarchy), the stack's protocol conformances are minimal and focused on sequential traversal rather than indexed access.

| Conformance | What it provides | Why not in Buffer |
|-------------|-----------------|-------------------|
| `Sequence.Protocol` | Forward traversal (bottom-to-top) | Buffer is a mechanism; stack commits to the traversal contract |
| `Swift.Sequence` | Interop with stdlib `for-in`, `map`, `filter` | Buffer should not carry stdlib coupling |
| `Sequence.Iterator.Protocol` | `makeIterator()` / `next()` contract | Same |
| `Sequence.Clearable` | `removeAll()` enabling `.forEach.consuming {}` | Pattern integration is consumer-facing |
| `Sequence.Drain.Protocol` | `drain(_:)` ownership-transferring iteration | Same |

**Notable absence**: Stack does NOT conform to `Collection`, `BidirectionalCollection`, `RandomAccessCollection`, `Collection.Protocol`, `Collection.Access.Random`, `Collection.Indexed`, or `Collection.Bidirectional`. This is **correct** — a stack's identity is the restriction of access to the top. Collection conformance would undermine the LIFO discipline.

#### B. Semantic Contracts

| Contract | Explanation |
|----------|-------------|
| **LIFO discipline** | `push` adds to top, `pop` removes from top. This is the *raison d'etre*. The buffer's `append`/`removeLast` happen to be LIFO, but the stack *names* and *commits to* this contract. |
| **Vocabulary renaming** | `push`/`pop`/`peek` instead of `append`/`removeLast`/`last`. This is not cosmetic — it establishes the user's mental model as a stack, not a buffer. |
| **Overflow as typed error** | `Stack.Bounded.push()` and `Stack.Static.push()` throw `throws(__StackBoundedError)` / `throws(__StackStaticError)` with `.overflow`. The buffer's `append` returns an optional rejected element. The stack reinterprets this as a semantic error: "the stack is full." |
| **Peek without removal** | `peek()` / `peek(_:)` — observe the top without consuming it. The buffer has no equivalent named operation; the stack defines this as a first-class semantic. |
| **Value semantics commitment** | Buffer provides CoW *mechanism*; stack commits to `var b = a; b.push(x)` not affecting `a`. |
| **Capacity independence of identity** | Two stacks with the same elements are equal regardless of capacity. The buffer has no equality concept. |
| **Safe pop** | `pop() -> Element?` returns Optional instead of trapping on empty. This is a stack-discipline safety contract — the empty stack is a normal state, not an error. |

#### C. Type-Level Invariants

| Invariant | What it adds |
|-----------|-------------|
| `Stack.Static<capacity>` | Compile-time capacity bound. Promise: "this never heap-allocates." |
| `Stack.Bounded` | Runtime capacity with overflow as typed error. |
| `Stack.Small<inlineCapacity>` | SmallVec-style inline-then-spill. |
| Conditional Copyable | `Copyable where Element: Copyable` as user-facing guarantee. |
| Conditional Sendable | `@unchecked Sendable where Element: Sendable`. |

#### D. Algebraic Structure (not yet implemented but canonically Stack's)

| Property | Stack owns it |
|----------|---------------|
| Monoid under concatenation | Stack ++ Stack with empty as identity (per Haskell `Monoid` instance) |
| Equatable | Element-wise, capacity-independent |
| Hashable | Follows from Equatable |

#### E. Consumer-Facing Ergonomics

| Feature | What it adds |
|---------|-------------|
| Variant taxonomy | Coherent `Stack`/`Bounded`/`Static`/`Small` family |
| Iterator types | `Stack.Iterator`, `Stack.Bounded.Iterator`, `Stack.Static.Iterator`, `Stack.Small.Iterator` |
| Typed errors | `Stack.Error`, `Stack.Bounded.Error`, `Stack.Static.Error`, `Stack.Small.Error` with `.overflow` and `.bounds` |
| Error descriptions | `CustomStringConvertible` for all error types |
| `clear(keepingCapacity:)` | Boolean flag as user convenience (Dynamic only) |
| `compact()` | Reduce capacity to match count (Dynamic only) |
| Property.View patterns | `.drain {}`, `.forEach {}`, `.satisfies {}`, `.first {}`, `.reduce {}`, `.contains {}`, `.drop {}`, `.prefix {}` (Static, Small) |
| `isSpilled` | Diagnostic for `Stack.Small` users |
| `requestedCapacity` | User-facing capacity for `Stack.Bounded` |

### What Buffer.Linear Owns (Stack Merely Delegates)

| Concern | Owned by Buffer.Linear |
|---------|----------------------|
| Memory allocation/deallocation | Creates/destroys `Storage.Heap` |
| Capacity tracking | `Header.capacity` |
| Count tracking | `Header.count` |
| Growth policy | `Buffer.Growth.Policy` |
| CoW mechanism | `ensureUnique()` |
| Element init/move/deinit lifecycle | Via `Storage` |
| Initialization state tracking | `Storage.Initialization` |
| Raw pointer access | `pointer(at:)` |
| Contiguous memory guarantee | `Span.Protocol` |
| Header state machine | `isEmpty`, `isFull` |
| Unchecked subscript | Direct pointer arithmetic |
| Inline storage management | `Buffer.Linear.Inline`, `Buffer.Linear.Small` |
| Spill detection | `Buffer.Linear.Small.isSpilled` |

---

## Audit: Current stack-primitives

### Audit Methodology

For each file in `stack-primitives`, classify every public API member as:
- **STACK**: Solely stack discipline (LIFO vocabulary, semantic contract, type invariant, ergonomics)
- **DELEGATE**: Pure delegation to buffer (thin wrapper calling `_buffer.foo`)
- **CONTESTED**: Could belong to either layer, or violates stack discipline

### Findings

#### Pure Stack Discipline (correctly placed)

| Item | Category | Variants |
|------|----------|----------|
| `push(_:)` | Vocabulary — LIFO naming for `append` | All 4 variants |
| `pop() -> Element?` | Vocabulary + Safety — LIFO naming for `removeLast` with Optional return | All 4 variants |
| `peek(_:) -> R?` (~Copyable closure) | Semantic — observe top without removal | All 4 variants |
| `peek() -> Element?` (Copyable) | Semantic — observe top without removal | All 4 variants |
| `clear(keepingCapacity:)` | Ergonomics — user-facing parameter | Stack (Dynamic) |
| `clear()` | Ergonomics — named for stack context | Static, Small, Bounded |
| `compact()` | Ergonomics — reduce capacity to count | Stack (Dynamic) |
| `Stack.Error` / `.bounds` | Typed error — stack-discipline bounds violation | Stack (Dynamic) |
| `Stack.Bounded.Error` / `.overflow`, `.bounds` | Typed error — capacity overflow as semantic error | Bounded |
| `Stack.Static.Error` / `.overflow`, `.bounds` | Typed error — capacity overflow as semantic error | Static |
| `Stack.Small.Error` / `.bounds` | Typed error — bounds violation | Small |
| `CustomStringConvertible` on all error types | Ergonomics — human-readable error messages | All error types |
| `Stack.Iterator` | Iterator type wrapping buffer internals | Dynamic |
| `Stack.Bounded.Iterator` | Iterator type wrapping buffer internals | Bounded |
| `Stack.Static.Iterator` | Iterator type wrapping buffer internals | Static |
| `Stack.Small.Iterator` | Iterator type wrapping buffer internals | Small |
| `Sequence.Protocol` conformance | Protocol — sequential traversal contract | All 4 variants (where Copyable) |
| `Swift.Sequence` conformance | Protocol — stdlib interop | Dynamic, Bounded |
| `Sequence.Clearable` conformance | Protocol — enabling `.forEach.consuming {}` | All 4 variants (where Copyable) |
| `Sequence.Drain.Protocol` conformance | Protocol — ownership-transferring iteration | All 4 variants (where Copyable) |
| `makeIterator()` | Protocol requirement | All 4 variants (where Copyable) |
| `underestimatedCount` | Protocol disambiguation | All 4 variants (where Copyable) |
| `removeAll()` | Protocol requirement (Clearable) | All 4 variants (where Copyable) |
| `drain(_:)` | Protocol method | All 4 variants (where Copyable) |
| `drain` property accessor | Property.View pattern | Dynamic, Bounded |
| Property.View tag enums (`Drain`, `ForEach`, `Satisfies`, `First`, `Reduce`, `Contains`, `Drop`, `Prefix`) | Ergonomics — Property.View type plumbing | Static, Small |
| Property accessor computed properties (`drain`, `forEach`, `satisfies`, `first`, `reduce`, `contains`, `drop`, `prefix`) | Ergonomics — Property.View access pattern | Static, Small |
| Conditional `Copyable` conformance | Type invariant | Dynamic, Bounded |
| Conditional `Sendable` conformance | Type invariant | All 4 variants |
| `Stack.Index` typealias | Typed indexing namespace | Core |
| `init()` | Construction | All 4 variants |
| `init(reservingCapacity:)` | Construction | Dynamic |
| `init(capacity:)` | Construction | Bounded |
| `requestedCapacity` stored property | Capacity contract for bounded semantics | Bounded |
| Variant taxonomy (`Stack`, `Static`, `Small`, `Bounded`) | Architecture — coherent type family | Core |
| `element(at:) -> Element?` (Optional) | Safe access | Dynamic, Bounded |
| `element(at:) throws` (Typed error) | Safe access with typed throw | Dynamic, Bounded |
| `withElement(at:_:) throws` | ~Copyable safe access | Static, Small |
| `Iterator.next()` | Protocol requirement | All 4 iterators |

#### Pure Delegation (correctly placed — thin wrappers are the point)

| Item | Delegates to | Verdict |
|------|-------------|---------|
| `var count` → `_buffer.count` | Buffer.Linear.Header | **OK** — Stack surface for buffer state |
| `var isEmpty` → `_buffer.isEmpty` | Buffer.Linear.Header | **OK** |
| `var capacity` → `_buffer.capacity` | Buffer.Linear.Header | **OK** (Dynamic, Small) |
| `var capacity` → `requestedCapacity` | Stack.Bounded stored property | **OK** (Bounded — not even buffer delegation) |
| `var isFull` → `_buffer.isFull` / `count >= requestedCapacity` | Buffer.Linear.Header / Stack logic | **OK** |
| `reserve(_:)` → `_buffer.reserveCapacity(_:)` | Buffer.Linear | **OK** |
| `var span` → `_buffer.span` | Buffer.Linear | **OK** |
| `var mutableSpan` → `_buffer.mutableSpan` | Buffer.Linear | **OK** |
| `forEach(_:)` (~Copyable) → `_buffer.forEach(_:)` | Buffer.Linear | **OK** |
| `truncate(to:)` → `_buffer.truncate(to:)` | Buffer.Linear | **OK** |

#### Contested / Observations

| Item | Issue | Assessment |
|------|-------|------------|
| **`subscript(index:)` — bounds-checked indexed access** | Provides O(1) random access by index on all variants. The formal stack ADT has NO index concept. C++ `std::stack` deliberately hides `operator[]`. Haskell `Data.Stack` has no indexing. This is an **array-like** operation on a stack. | **CONTESTED** — This violates the pure LIFO discipline. A consumer who subscripts a stack by index is not using it as a stack; they are using it as an array. However, pragmatically, debugging and inspection of stack contents is a legitimate need. The subscript is guarded by `precondition`, not exposed via Collection conformance, so it does not confer full random-access citizenship. **Recommendation**: Consider whether this should be gated behind a `.debug` or `.unsafe` accessor to signal that indexed access is outside the stack contract. Alternatively, accept it as a pragmatic escape hatch and document that it exists for inspection, not as part of the stack discipline. |
| **`subscript(index: Index.Bounded<capacity>)` — capacity-bounded subscript** | Stack.Static exposes a subscript accepting a compile-time-bounded index. This is even more "array-like" — it provides type-level bounds checking for indexed access on a stack. | **CONTESTED** — Same concern as above, amplified. A bounded subscript is infrastructure for arrays and fixed-size containers. On a stack, it undermines the LIFO guarantee by enabling arbitrary position access. |
| **`element(at:) -> Element?`** | Safe indexed access returning Optional. Present on Dynamic and Bounded variants. | **CONTESTED** — Same concern. Indexed access is not stack discipline. However, the `at:` label and Optional return signal "this might fail," which is more cautious than a bare subscript. |
| **`element(at:) throws`** | Throwing indexed access. Present on Dynamic and Bounded variants. | **CONTESTED** — Same concern. The typed throw does make misuse visible at the call site. |
| **`withElement(at:_:)`** | Closure-based indexed access for ~Copyable elements. Present on Static and Small variants. | **CONTESTED** — Same concern. This is the ~Copyable counterpart of `element(at:)`. |
| **`forEach(_:)` as bottom-to-top iteration** | Buffer's `forEach` iterates in insertion order (bottom to top). The stack surfaces this directly. From a pure stack perspective, iteration should be top-to-bottom (most recent first) or should not exist at all. | **MINOR** — Bottom-to-top is the natural storage order and matches the Sequence.Protocol iteration direction. Top-to-bottom would require reversal. This is a pragmatic choice, not a layering violation. However, `std::stack` deliberately provides no iteration at all. |
| **`isSpilled` on Stack.Small** | Exposes buffer implementation detail (inline vs heap). | **ACCEPTABLE** — A user reasonably wants to know if they have spilled. This is a valid consumer-facing diagnostic property. The SmallVec pattern's value proposition depends on knowing when you have spilled. Keep it. |
| **`span` / `mutableSpan`** | Exposes contiguous memory view of the stack's elements. This is direct buffer-level access — Span gives arbitrary random access to all elements by position. | **CONTESTED** — Span access completely bypasses the LIFO discipline. Any consumer who obtains a `Span<Element>` can read any element at any index, making the stack indistinguishable from an array. However, Span is the Swift standard mechanism for safe contiguous memory access and is necessary for FFI, serialization, and performance-critical bulk operations. **Recommendation**: Keep it, but document that it is an escape hatch for bulk/FFI operations, not part of the stack contract. |
| **`mutableSpan`** | Same as `span`, but mutable. | **CONTESTED** — Stronger concern than `span`: mutable random access to stack elements completely breaks the LIFO contract. A consumer can modify any element at any position. **Recommendation**: Same as `span`. Needed for performance/FFI but should be documented as escaping the stack discipline. |
| **`truncate(to:)`** | Removes elements from the top until count matches. Semantically this is "pop n times." | **BORDERLINE OK** — This is a bulk `pop()`. It respects the LIFO discipline (elements are removed from the top). The name `truncate` is buffer-vocabulary, but the semantic is valid. Could be named `pop(count:)` for stack consistency. |
| **`compact()`** | Reduces capacity to match count (Dynamic only). | **BORDERLINE OK** — This is capacity management, which is buffer territory conceptually. But the user needs a way to say "I'm done pushing, reclaim memory." Acceptable as consumer ergonomics. |
| **`reserve(_:)`** | Reserves capacity (Dynamic only). | **BORDERLINE OK** — Same reasoning as `compact()`. The user says "I'm about to push N elements, pre-allocate." This is consumer ergonomics over buffer mechanism. |

### What's MISSING from Stack (things that are solely stack discipline but not yet present)

| Missing | Category | Priority |
|---------|----------|----------|
| `Equatable where Element: Equatable` | Algebraic | High — capacity-independent equality is core data structure semantics |
| `Hashable where Element: Hashable` | Algebraic | High — follows from Equatable |
| `swap(_:)` / `swap(with:)` | Stack operation | Low — `std::stack` has it; Swift typically uses `swap(&a, &b)` at call site |
| `CustomStringConvertible` / `CustomDebugStringConvertible` on Stack types | Ergonomics | Low |
| `Codable where Element: Codable` | Serialization | Low for primitives |
| `depth` as alias for `count` | Vocabulary | Very Low — "depth" is canonical stack terminology but `count` is universal |
| Top-to-bottom iteration option | Semantic | Low — would require a reversed iterator, `forEach` currently goes bottom-to-top |

---

## Outcome

**Status**: RECOMMENDATION

### Verdict: stack-primitives has correct LIFO core with significant indexed-access surface area that warrants scrutiny

The `stack-primitives` package gets the core stack discipline right: `push`/`pop`/`peek` vocabulary, typed overflow errors, safe Optional returns, and a coherent variant taxonomy. No buffer-level storage management, growth, CoW, or element lifecycle has leaked upward.

However, the package exposes a substantial indexed-access surface (`subscript`, `element(at:)`, `withElement(at:)`, `span`, `mutableSpan`) that the formal stack ADT and the strongest prior art (`std::stack`, Haskell `Data.Stack`) deliberately exclude. This is the central tension:

- **Purist position**: A stack that lets you subscript by index is not a stack — it is an array with a `push`/`pop` vocabulary overlay. C++ specifically designed `std::stack` as a *restriction adapter* that hides `operator[]`.
- **Pragmatist position**: Inspection, debugging, serialization, and FFI require access to the stack's contents. The subscript is guarded by preconditions and is not exposed via Collection conformance, so it does not confer full random-access citizenship.

This analysis does not declare the indexed access wrong, but it identifies the tension and recommends explicit documentation.

### Specific Recommendations

#### 1. Document Indexed Access as Escape Hatch (Medium Priority)

The `subscript(index:)`, `element(at:)`, `withElement(at:)`, `span`, and `mutableSpan` APIs should have documentation explicitly stating they are escape hatches for inspection/debugging/FFI, not part of the LIFO contract. Example:

```swift
/// Accesses the element at the given typed index.
///
/// - Note: Indexed access is an escape hatch for inspection and debugging.
///   Prefer `push(_:)`, `pop()`, and `peek()` for normal stack operations.
///   Using indexed access extensively may indicate that `Array` is a better
///   fit than `Stack` for your use case.
```

#### 2. Add `Equatable` / `Hashable` (Medium Priority)

These are core data-structure semantics (capacity-independent element-wise comparison). Currently absent from all variants. Both `std::stack` and Haskell `Data.Stack` provide equality.

#### 3. Consider `pop(count:)` as Alternative to `truncate(to:)` (Low Priority)

`truncate(to:)` uses buffer vocabulary. A stack-discipline alternative would be `pop(count:)` or `pop(_: Int)` that removes N elements from the top. This is semantically clearer for stack consumers. Both could coexist.

#### 4. `isSpilled` is Acceptable (No Action)

`Stack.Small.isSpilled` exposes a buffer detail, but it is a diagnostic property that users legitimately need. The SmallVec pattern's value proposition depends on knowing when you have spilled. Keep it.

#### 5. No Buffer Concerns Have Leaked Upward (Positive Finding)

The audit found **zero instances** of stack-primitives performing work that properly belongs to the buffer layer. All storage management, growth, CoW, element lifecycle, and contiguous-memory operations are handled by `Buffer.Linear` and its variants. Stack's `_buffer` stored property is the only coupling, and it is correctly `package`-scoped.

#### 6. `forEach` Direction is Pragmatically Correct (No Action)

Bottom-to-top iteration order matches storage order and `Sequence.Protocol` expectations. While top-to-bottom would be more "stack-like," the current direction is consistent with how the Swift ecosystem uses sequences. No change needed.

### Summary Table

| Layer | Concern Count | Assessment |
|-------|:---:|---|
| Pure stack discipline | 35+ distinct APIs | Correctly placed — LIFO vocabulary, typed errors, iterators, protocol conformances, variant taxonomy |
| Pure delegation | 10 passthrough properties/methods | Correctly placed — thin wrapping is the design intent |
| Contested (indexed access surface) | 8 APIs across variants | Not a layering violation, but violates pure LIFO discipline. Recommend documenting as escape hatches. |
| Buffer concern leaked into stack | **0** | Clean separation |
| Stack concern missing | 2-3 items | Future work (Equatable, Hashable), not a layering violation |

---

## References

- UNC COMP 410 ADT Axiomatic Semantics: formal stack axioms (https://www.cs.unc.edu/~stotts/COMP410/adt/)
- Liskov & Guttag, "Abstraction and Specification in Program Development": ADT axioms
- cppreference, `std::stack` container adapter (https://en.cppreference.com/w/cpp/container/stack.html)
- Haskell `Data.Stack` 0.4.0: minimal algebraic stack (https://hackage.haskell.org/package/Stack-0.4.0/docs/Data-Stack.html)
- Rust `Vec<T>` as stack: `push`/`pop` on vector (https://doc.rust-lang.org/std/vec/struct.Vec.html)
- Rust `heapless` crate: fixed-capacity vector for embedded (https://docs.rs/heapless)
- Wikipedia, "Stack (abstract data type)" (https://en.wikipedia.org/wiki/Stack_(abstract_data_type))
- Stepanov & McJones, "Elements of Programming" (2009): container adapter patterns
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-discipline-boundary-analysis.md`
- `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/Research/theoretical-buffer-primitives-design.md`
