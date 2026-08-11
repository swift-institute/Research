# Sequence-Primitives × Storage-Primitives Integration Analysis

<!--
---
version: 2.0.0
last_updated: 2026-02-06
status: DECISION
research_tier: 2
applies_to: [swift-sequence-primitives, swift-storage-primitives, swift-bit-vector-primitives, swift-collection-primitives, swift-buffer-primitives]
normative: false
---
-->

<!--
## Changelog

### 2.0.0 (2026-02-06)
- Status: RECOMMENDATION → DECISION
- bit-vector-primitives adopted sequence-primitives dependency (Tier 9 → Tier 7)
- Ones.View and Ones.Static conform to Sequence.Protocol + Swift.Sequence
- Bare forEach methods removed; Swift.Sequence.forEach replaces them
- Documented underestimatedCount disambiguation finding (Swift.Sequence + Sequence.Protocol dual conformance)
- Added Part IX: Implementation Record
- Updated FP-1 assessment (partially addressed)
- Updated REC-SEQ-STOR-004 (refined: no direct dependency between sequence and storage, but intermediary packages like bit-vector DO adopt sequence)
-->

@Metadata {
    @TitleHeading("Swift Primitives Research")
}

A systematic investigation into the integration surface between `swift-sequence-primitives` (Tier 7) and `swift-storage-primitives` (Tier 14), analyzing how these two foundational packages interact through the tier stack and identifying opportunities for improved coordination.

## Abstract

Sequence-primitives (Tier 7) defines *how elements are traversed*. Storage-primitives (Tier 14) defines *how elements exist in memory*. These packages are separated by seven tiers and have zero direct code dependencies. Yet they are deeply coupled at the semantic level: every storage-backed collection must implement sequence protocols to be useful, and every sequence operation over a storage-backed collection must interact with storage's initialization tracking, ownership semantics, and span access.

This document maps the integration surface, identifies the intermediary packages that bridge these tiers, evaluates whether the current layering is sound, and recommends coordination patterns for downstream consumers that must implement both.

**Principal Findings**:

1. **No direct dependency between sequence-primitives and storage-primitives is needed or desirable.** The tier separation (7 vs 14) is architecturally correct. Sequence defines abstract traversal contracts; storage provides concrete memory management. Coupling them would conflate abstraction layers.

2. **Intermediary packages SHOULD adopt sequence-primitives where iteration is a primary concern.** Bit-vector-primitives (Tier 9) now depends on sequence-primitives (Tier 7). `Bit.Vector.Ones.View` and `Bit.Vector.Ones.Static` conform to `Sequence.Protocol` + `Swift.Sequence`, eliminating bare `forEach` reimplementations. This transitive upgrade flows to storage-primitives and buffer-primitives call sites with zero source changes.

3. **Integration occurs at three intermediary tiers**: Collection (Tier 8), Buffer (Tier 15), and ADT packages (Tier 10–16). These tiers compose sequence protocols over storage-backed data, each adding a specific concern.

4. **Five integration patterns** emerge from the existing codebase: iterator-over-storage, span-bridged borrowing iteration, drain-as-move-sequence, consume-as-ownership-transfer, and conditional Swift.Sequence conformance.

5. **The Sequence.Consume protocol's documentation already encodes storage interaction patterns** — its example code references `storage.deinitRemaining()` and `storage.moveElement(at:)`, demonstrating the expected integration shape.

6. **`underestimatedCount` disambiguation is required** when conforming to both `Sequence.Protocol` and `Swift.Sequence`. The `Sequence.Protocol+Swift.Sequence.swift` extension provides a default `underestimatedCount`, and `Swift.Sequence` provides its own. The compiler sees two matching candidates and errors. Each conforming type must provide an explicit `var underestimatedCount: Int { 0 }` override.

---

## Part I: Context

### 1.1 Research Trigger

Per [RES-012], this is a **Discovery** research document. The trigger is a proactive analysis: both packages are mature and heavily documented, but no research document explicitly maps their integration surface. Given that every collection primitive must bridge these two packages, documenting the integration patterns prevents inconsistency across the 20+ ADT packages that consume both.

### 1.2 Scope

Per [RES-002a], this research is **primitives-wide** — it affects packages across tiers 7–16.

| Criterion | Assessment |
|-----------|------------|
| Packages directly analyzed | swift-sequence-primitives (Tier 7), swift-storage-primitives (Tier 14) |
| Packages indirectly affected | swift-collection-primitives (8), swift-buffer-primitives (15), all ADT packages (10–16) |
| Tiers spanned | 7–16 (nine tiers) |
| Precedent-setting | No — documents existing patterns |
| Research tier | Tier 2 — cross-package, reversible recommendations |

### 1.3 The Two Packages

| Aspect | sequence-primitives | storage-primitives |
|--------|--------------------|--------------------|
| **Tier** | 7 | 14 |
| **Question answered** | How are elements *traversed*? | How do elements *exist in memory*? |
| **Core abstractions** | `Sequence.Protocol`, `Sequence.Iterator.Protocol`, `Sequence.Borrowing.Protocol`, `Sequence.Drain.Protocol`, `Sequence.Consume.Protocol` | `Storage.Heap`, `Storage.Inline<N>`, `Storage.Initialization`, tracked accessors |
| **Dependencies** | Property Primitives (0), Index Primitives (6) | Index Primitives (6), Memory Primitives (13), Property Primitives (0), Range Primitives (9), Bit Vector Primitives (9) |
| **Shared dependencies** | Property Primitives, Index Primitives | Property Primitives, Index Primitives |
| **~Copyable support** | Container and iterator; Element limited by SE-0427 | Container and elements; full per-slot tracking |
| **Property.View pattern** | All operations (forEach, map, filter, etc.) | All operations (initialize, move, copy, deinitialize) |
| **Element ownership** | Borrowing, consuming, draining (protocol-level) | Initialize, move, copy, deinitialize (physical-level) |

### 1.4 Tier Separation

```
Tier  7: sequence          ← Abstract traversal contracts
Tier  8: collection        ← Indexed multi-pass traversal
Tier  9: range, bit        ← Bounded intervals
Tier 10: deque, heap, list ← ADT packages (use both)
Tier 14: storage           ← Concrete memory management
Tier 15: buffer            ← Access discipline over storage
Tier 16: queue, dictionary ← More ADTs
```

The seven-tier gap is the widest bridging distance in the primitives architecture. This is not accidental — it reflects a fundamental abstraction boundary between *what you can do with elements* (sequence) and *where elements live* (storage).

---

## Part II: Why No Direct Dependency

### 2.1 Tier Constraint

Per Primitives Tiers.md: "A package at tier N MUST NOT depend on any package at tier N or higher."

- Sequence (7) cannot depend on Storage (14): upward dependency, forbidden.
- Storage (14) could theoretically depend on Sequence (7): downward dependency, permitted.

But Storage does not depend on Sequence, and should not:

### 2.2 Separation of Concerns

| Layer | Concern | Storage's Role | Sequence's Role |
|-------|---------|---------------|-----------------|
| Physical | Where bytes live | **Primary** — placement, allocation, deallocation | None |
| Lifecycle | When elements exist | **Primary** — initialize, deinitialize, tracking | None |
| Traversal | Order of access | None | **Primary** — iteration protocols |
| Ownership transfer | Who owns elements | **Provides** — move, copy operations | **Defines** — consuming, borrowing, draining contracts |
| API surface | User-facing operations | Internal (used by buffers/ADTs) | External (implemented by ADTs) |

Storage has no concept of "iteration order" — it provides `pointer(at:)` for random access. Sequence has no concept of "where elements live" — it defines `makeIterator()` and `next()`. The integration is correctly left to the ADT layer, which knows both the storage layout and the desired traversal order.

### 2.3 The Abstraction Layer Model

From `storage-ownership-reference-synthesis.md` §1.2:

```
Layer         | Question Answered
──────────────|────────────────────────────────
Storage       | How does memory EXIST?
Buffer        | How is data TRANSFERRED?
ADT/Container | What OPERATIONS are available?
```

Sequence protocols are *operation contracts* — they belong at the ADT/Container layer. Storage is the *existence substrate*. The intermediary Buffer layer provides *access discipline* (linear, ring, slab). This three-layer model correctly keeps sequence and storage apart.

---

## Part III: Integration Patterns

Five patterns emerge from analyzing how existing ADTs bridge sequence protocols with storage management.

### Pattern 1: Iterator-over-Storage

The most common pattern. An ADT implements `Sequence.Protocol` by creating an iterator that walks storage slots.

```swift
// Conceptual pattern (not real code — actual ADTs vary)
extension Stack: Sequence.`Protocol` where Element: Copyable {
    struct Iterator: Sequence.Iterator.`Protocol` {
        var storage: Storage.Heap
        var index: Index<Element>
        let end: Index<Element>

        mutating func next() -> Element? {
            guard index < end else { return nil }
            defer { index = index.advanced(by: 1) }
            return storage.pointer(at: index).pointee
        }
    }

    borrowing func makeIterator() -> Iterator {
        Iterator(storage: _storage, index: .zero, end: count)
    }
}
```

**Integration points**:
- `Index<Element>` — shared dependency (index-primitives, Tier 6)
- `storage.pointer(at:)` — Storage provides positional access
- `Element: Copyable` — required because `next()` returns `Element?` (SE-0427 constraint)
- Iterator copies from storage without affecting initialization state

**Constraint**: This pattern requires `Element: Copyable` because `Sequence.Iterator.Protocol.next()` returns `Element?`, and `Optional` requires `Copyable`. For `~Copyable` elements, see Pattern 3 and 4.

### Pattern 2: Span-Bridged Borrowing Iteration

ADTs with contiguous storage implement `Sequence.Borrowing.Protocol` by exposing `Span<Element>` from `Memory.Contiguous.Protocol`.

```swift
// Conceptual pattern
extension Array: Sequence.Borrowing.`Protocol` where Element: Copyable {
    @_lifetime(borrow self)
    borrowing func makeIterator() -> Swift.Span.Iterator.Batch<Element> {
        Swift.Span.Iterator.Batch(span: _storage.span)
    }
}
```

**Integration points**:
- `Storage.Heap` and `Storage.Inline` both conform to `Memory.Contiguous.Protocol`
- `Memory.Contiguous.Protocol` provides `var span: Span<Element>` (borrowing)
- `Swift.Span.Iterator.Batch` (from sequence-primitives stdlib integration) wraps a `Span` as a borrowing iterator
- `nextSpan(maximumCount:)` returns sub-spans without copying

**This is the tightest integration point**: sequence-primitives already provides `Swift.Span.Iterator.Batch`, and storage-primitives already provides `span` via `Memory.Contiguous.Protocol`. The bridge is `Span<Element>` — a stdlib type that both packages understand.

### Pattern 3: Drain-as-Move-Sequence

For `~Copyable` elements, ADTs implement `Sequence.Drain.Protocol` by moving elements out of storage.

```swift
// Conceptual pattern
extension Stack: Sequence.Drain.`Protocol` {
    mutating func drain(_ body: (consuming Element) -> Void) {
        while !isEmpty {
            let element = _storage.move.last()   // Storage.Move accessor
            body(element)
        }
        _storage.deinitialize.all()              // Storage.Deinitialize accessor
    }
}
```

**Integration points**:
- `storage.move(at:)` transfers element ownership from storage to closure parameter
- `storage.deinitialize.all()` cleans up tracking state
- Container survives but is empty (mutating, not consuming)
- Works for both `Copyable` and `~Copyable` elements

**Storage operations used**: `move.last()`, `move(at:)`, `deinitialize.all()` — all tracked accessors that automatically update `Storage.Initialization` state.

### Pattern 4: Consume-as-Ownership-Transfer

ADTs implement `Sequence.Consume.Protocol` for destructive iteration where the container itself is consumed.

From `Sequence.Consume.swift` documentation (lines 60–83):

```swift
extension MyContainer.Consume {
    struct State: ~Copyable {
        var storage: Storage          // Storage ownership transferred
        var index: Int
        let count: Int

        deinit {
            storage.deinitRemaining(from: index, count: count - index)
        }
    }
}

extension MyContainer: Sequence.Consume.`Protocol` {
    consuming func consume() -> Sequence.Consume.View<Element, Consume.State> {
        Sequence.Consume.View(
            state: Consume.State(storage: storage, index: 0, count: count),
            next: { state in
                guard state.index < state.count else { return nil }
                defer { state.index += 1 }
                return state.storage.moveElement(at: state.index)
            }
        )
    }
}
```

**Integration points**:
- `consuming func consume()` transfers storage ownership into the `View.State`
- `State.deinit` handles cleanup of unvisited elements — maps to `storage.deinitialize(range:)`
- `storage.moveElement(at:)` corresponds to `storage.move(at:)` accessor
- The `State` type owns storage; no separate ARC or reference counting needed

**This pattern directly encodes storage semantics in the sequence protocol**. The Consume.Protocol's design was informed by how storage-backed containers need to transfer ownership during iteration.

### Pattern 5: Conditional Swift.Sequence Conformance

From `Collection Primitives Architecture.md` §2.3:

```swift
extension Queue: Swift.Sequence where Element: Copyable { ... }
```

**Integration points**:
- `Copyable` constraint gates stdlib `Sequence` conformance
- CoW semantics via `makeUnique()` before mutation
- Method shadowing provides both `~Copyable` (closure-based) and `Copyable` (direct-return) APIs
- stdlib `for-in` syntax available only for `Copyable` elements

---

## Part IV: Shared Dependencies as Integration Medium

Sequence and Storage share two dependencies that serve as the integration medium:

### 4.1 Property Primitives (Tier 0)

Both packages use the `Property<Tag, Base>.View` pattern for all operations:

| Package | Tag Types | Pattern |
|---------|-----------|---------|
| Sequence | `ForEach`, `Map`, `Filter`, `Reduce`, `Contains`, `Satisfies`, `Count`, `Prefix`, `Drop`, `Drain`, `Consume`, `Span`, `First` | `instance.forEach { }`, `instance.map { }` |
| Storage | `Initialize`, `Move`, `Copy`, `Deinitialize` | `storage.initialize.next(to:)`, `storage.move(at:)` |

**Implication**: ADTs that bridge both packages use two distinct sets of `Property.View` accessors — one set for user-facing sequence operations, another for internal storage management. The Property.View pattern ensures API consistency across both domains without requiring cross-package coupling.

### 4.2 Index Primitives (Tier 6)

Both packages use `Index<Element>` for typed positional access:

| Package | Usage |
|---------|-------|
| Sequence | `Cardinal` in `Sequence.Iterator.Borrowing.Protocol.nextSpan(maximumCount:)` and `.skip(by:)` |
| Storage | `Index<Element>` for slot addressing, `Index<Element>.Count` for capacity, `Index<Element>.Offset` for arithmetic |

**Implication**: When an ADT implements a sequence iterator over storage, `Index<Element>` is the shared coordinate type. No conversion is needed — both packages agree on what an index means. This is the strongest actual integration point, facilitated by the shared Tier 6 dependency.

---

## Part V: The Intermediary Tiers

### 5.1 Collection Primitives (Tier 8)

Collection-primitives imports sequence-primitives but not storage-primitives. It defines:
- `Collection.Protocol` (extends `Sequence.Protocol` with indexed multi-pass access)
- `Collection.Indexed` (for `~Copyable` element collections)

Collection sits one tier above Sequence and six tiers below Storage. It adds the *indexing* concern without introducing storage concerns. Actual storage integration happens at the ADT tier (10+) where concrete collections know their storage layout.

### 5.2 Buffer Primitives (Tier 15)

Buffer-primitives imports storage-primitives. It provides access disciplines:
- `Buffer.Linear` — sequential access over `Storage.Heap` or `Storage.Inline`
- `Buffer.Ring` — circular access discipline
- `Buffer.Slab` — indexed slot access with occupancy

Buffer does NOT import sequence-primitives. It handles *how data is transferred between storage and consumers* — growth policies, inline-to-heap transitions, and access patterns. The sequence protocol conformances live at the ADT level above Buffer.

### 5.3 ADT Packages (Tiers 10–16)

These packages compose the full stack: storage + buffer + sequence conformances.

```
Stack (Tier 15)
├── implements: Sequence.Protocol, Sequence.Drain.Protocol, Sequence.Consume.Protocol
├── uses: Buffer.Linear → Storage.Heap (base variant)
└── uses: Storage.Inline (bounded variant)

Queue (Tier 16)
├── implements: Sequence.Protocol (where Element: Copyable)
├── uses: Buffer.Ring → Storage.Heap
└── Drain/Consume: closure-based for ~Copyable

Deque (Tier 10)
├── implements: Sequence.Protocol (where Element: Copyable)
├── uses: Storage.Heap (ring buffer semantics)
└── inline variant: Storage.Inline-backed
```

**Key insight**: The ADT is the *integration site* — it is the only layer that knows both the traversal contract (from sequence-primitives) and the physical layout (from storage-primitives). This is correct by construction: integration at any lower tier would conflate abstraction levels.

---

## Part VI: Analysis of Current State

### 6.1 What Works

| Aspect | Assessment |
|--------|------------|
| **Tier separation** | Sound. Seven-tier gap correctly reflects abstraction distance. |
| **No direct dependency** | Correct. Neither package needs the other's types. |
| **Shared Index<Element>** | Excellent. Provides typed coordination without coupling. |
| **Property.View pattern** | Consistent. Both packages use the same accessor pattern. |
| **Span as bridge** | Effective. `Memory.Contiguous.Protocol.span` + `Swift.Span.Iterator.Batch` provides zero-copy iteration. |
| **Consume.Protocol design** | Storage-aware. Documentation encodes storage interaction patterns. |
| **Conditional Copyable** | Pragmatic. `Swift.Sequence` conformance gated on `Element: Copyable`. |

### 6.2 Friction Points

| Issue | Description | Severity |
|-------|-------------|----------|
| **FP-1: "Iterate initialized slots" vocabulary** *(partially addressed)* | `Bit.Vector.Ones.View` now conforms to `Swift.Sequence`, so ADTs iterate initialized slots via `_slots.ones.forEach { }` or `for index in _slots.ones { }` using stdlib sequence semantics instead of a bare reimplemented `forEach`. The underlying iteration pattern (Wegner/Kernighan across words) is now provided by `Ones.View.Iterator`, not reimplemented per ADT. | Resolved (iteration); Low (linearization helper for ring buffers remains) |
| **FP-2: Consume.Protocol's storage examples are informal** | The `Sequence.Consume.swift` documentation shows `storage.deinitRemaining()` and `storage.moveElement(at:)` — method names that don't match actual Storage API (`storage.deinitialize(range:)`, `storage.move(at:)`). | Low |
| **FP-3: SE-0427 creates a bifurcated world** | `Sequence.Protocol` requires `Element: Copyable` (implicit). `Storage` supports `~Copyable` elements. The two capabilities don't align — storage can store what sequences can't iterate. Workarounds exist (Drain, Consume, closure-based APIs) but the gap is fundamental. | Medium (language limitation) |
| **FP-4: No pattern for ring-buffer iteration** | `Storage.Initialization` has `.two(first:, second:)` for ring buffers. Implementing `Sequence.Iterator.Protocol` over two disjoint ranges requires the ADT to handle linearization. No helper exists. | Low |

### 6.3 Gap Severity Assessment

FP-1 is now **resolved** for initialized-slot iteration (bit-vector-primitives provides `Ones.View.Iterator` via `Sequence.Protocol`). FP-3 remains a Swift language limitation (SE-0427). FP-2 and FP-4 are documentation and convenience issues.

**Assessment**: The integration surface is well-designed. FP-1 was the most frequently encountered friction point and is now addressed.

---

## Part VII: Recommendations

### REC-SEQ-STOR-001: Document Integration Patterns in ADT Guidelines

**Priority**: MEDIUM

Create a section in the Collection Primitives Architecture research document (or a new companion document) that formalizes the five integration patterns identified in Part III. This provides a replicable template for new ADT packages.

**Content outline**:
1. Pattern catalog (iterator-over-storage, span-bridged, drain-as-move, consume-as-ownership, conditional-Sequence)
2. Which Storage accessors correspond to which Sequence protocol requirements
3. When to use each pattern (decision tree based on Element: Copyable and storage variant)

| Storage Variant | Element Constraint | Sequence Conformance | Pattern |
|----------------|--------------------|-----------------------|---------|
| Storage.Heap | Copyable | Sequence.Protocol + Swift.Sequence | Pattern 1 + 5 |
| Storage.Heap | ~Copyable | Sequence.Drain.Protocol + Sequence.Consume.Protocol | Pattern 3 + 4 |
| Storage.Inline | Copyable | Sequence.Borrowing.Protocol (via span) | Pattern 2 |
| Storage.Inline | ~Copyable | Sequence.Drain.Protocol | Pattern 3 |
| Contiguous (either) | Copyable | Sequence.Borrowing.Protocol | Pattern 2 |

### REC-SEQ-STOR-002: Align Consume.Protocol Documentation with Storage API

**Priority**: LOW

Update the `Sequence.Consume.swift` documentation examples to use names that match the actual Storage API:

| Current (documentation) | Actual (Storage API) |
|-------------------------|---------------------|
| `storage.deinitRemaining(from:count:)` | `storage.deinitialize(range:)` or `storage.deinitialize.all()` |
| `storage.moveElement(at:)` | `storage.move(at:)` |

This is a documentation-only change with zero code impact.

### REC-SEQ-STOR-003: Consider Ring-Buffer Iteration Helper

**Priority**: LOW

When ADTs implement `Sequence.Iterator.Protocol` over ring-buffer storage (`Storage.Initialization.two(first:, second:)`), they must handle two-range iteration:

```swift
// Current: each ADT reimplements this
mutating func next() -> Element? {
    if currentIndex < firstRange.upperBound {
        defer { currentIndex = currentIndex.advanced(by: 1) }
        return storage.pointer(at: currentIndex).pointee
    }
    if !secondRangeStarted {
        currentIndex = secondRange.lowerBound
        secondRangeStarted = true
    }
    guard currentIndex < secondRange.upperBound else { return nil }
    defer { currentIndex = currentIndex.advanced(by: 1) }
    return storage.pointer(at: currentIndex).pointee
}
```

A helper in `Storage.Initialization` that linearizes the two-range case (yielding indices in logical order) could reduce this boilerplate. However, this is a convenience optimization — each ADT's ring-buffer iteration is slightly different (Deque iterates front-to-back, Queue FIFO). The ADT-specific variation may make a generic helper impractical.

**Recommendation**: Monitor whether ADT implementations converge on a common pattern. If three or more ADTs implement identical two-range iteration logic, extract per [RES-017] (Pattern Extraction).

### REC-SEQ-STOR-004: No Direct Dependency Between Sequence and Storage — But Intermediaries Adopt Sequence

**Priority**: HIGH

**Status**: IMPLEMENTED

The architecture maintains no direct dependency between sequence-primitives (Tier 7) and storage-primitives (Tier 14). However, intermediary packages that provide iteration as a primary concern SHOULD adopt sequence-primitives:

1. **Tier constraint is sound**: The seven-tier gap between sequence and storage reflects genuine abstraction distance.
2. **Intermediary adoption is correct**: Bit-vector-primitives (Tier 9) now depends on sequence-primitives (Tier 7). This is a downward dependency, architecturally permitted and semantically justified — bit-vector iteration IS a sequence concern.
3. **Transitive upgrade**: Storage-primitives and buffer-primitives call `_slots.ones.forEach { }`. This call site is syntactically unchanged but now dispatches to `Swift.Sequence.forEach` instead of a bare reimplementation. Zero source changes downstream.
4. **Shared dependencies sufficient**: `Index<Element>` and `Property.View` provide all necessary coordination between sequence and storage directly.
5. **Span bridge works**: `Memory.Contiguous.Protocol.span` + `Swift.Span.Iterator.Batch` gives zero-copy iteration without coupling.
6. **Each package evolves independently**: Storage can add Arena/Pool variants; Sequence can add new operations — neither change forces updates to the other.

**Principle applied**: Dependency maximum utilization — use what lower tiers provide rather than reimplementing. Bare `forEach` on `Ones.View` was a reimplementation of `Swift.Sequence.forEach`; adopting the dependency eliminates it.

---

## Part VIII: Outcome

### 8.1 Status

**Status**: DECISION

### 8.2 Summary

The integration between sequence-primitives and storage-primitives is **well-designed and architecturally sound**. The seven-tier separation is correct — no direct dependency between the two exists or should exist. However, intermediary packages like bit-vector-primitives (Tier 9) correctly adopt sequence-primitives (Tier 7) where iteration is a primary concern.

Integration occurs through:

1. **Shared dependencies** — `Index<Element>` (Tier 6) and `Property.View` (Tier 0)
2. **Stdlib bridge types** — `Span<Element>`, `UnsafeMutablePointer<Element>`
3. **ADT-layer composition** — each collection knows both its storage layout and its sequence contract
4. **Intermediary adoption** — bit-vector-primitives conforms `Ones.View` and `Ones.Static` to `Sequence.Protocol` + `Swift.Sequence`, eliminating bare `forEach` reimplementations across the stack

Five integration patterns cover all combinations of storage variant × element copyability × iteration semantics.

### 8.3 Implications for Future Development

| Future Change | Impact on Integration |
|---------------|-----------------------|
| **Storage.Arena / Storage.Pool** (from storage-primitives comparative analysis REC-001/002) | New storage variants will need matching sequence integration patterns. Arena's batch-deallocation semantics interact with Drain and Consume differently (all elements must be deinitialized before arena reset). Document new patterns as part of Arena/Pool implementation. |
| **SE-0427 relaxation** (if Swift allows `~Copyable` associated types) | Would unify the bifurcated world: `Sequence.Protocol` could directly support `~Copyable` elements. Drain and Consume protocols would remain useful for ownership-transfer semantics but would no longer be the *only* way to iterate `~Copyable` elements. |
| **New sequence operations** (Zip, Chain, Window, etc.) | No impact on integration. New operations compose over existing iterator protocols, which already bridge to storage via the five patterns. |
| **Storage.Protocol** (rejected in storage-primitives comparative analysis §8.3) | Would not affect sequence integration — sequence protocols are implemented by ADTs, not by storage types directly. |

---

## Part IX: Implementation Record

### 9.1 What Was Implemented

**Package**: `swift-bit-vector-primitives` (Tier 9)

**Dependency added**: `swift-sequence-primitives` (Tier 7) — downward dependency, architecturally correct.

| File | Action |
|------|--------|
| `Package.swift` | Added `swift-sequence-primitives` dependency |
| `Bit.Vector.Ones.View.Iterator.swift` | **New** — Wegner/Kernighan iterator across `UInt` words, conforms to `IteratorProtocol` with `Element == Bit.Index` |
| `Bit.Vector.Ones.View+Sequence.Protocol.swift` | **New** — `Sequence.Protocol` + `Swift.Sequence` conformance with `underestimatedCount` disambiguation |
| `Bit.Vector.Ones.Static.swift` | **New** — `Copyable` sequence type with `InlineArray` copy for `Bit.Vector.Static` |
| `Bit.Vector.Ones.Static.Iterator.swift` | **New** — Wegner/Kernighan iterator for `InlineArray` storage |
| `Bit.Vector+ones.swift` | Removed bare `forEach` on `Ones.View` |
| `Bit.Vector.Static+ones.swift` | Changed return type from `Property<Bit.Vector.Ones, Self>` to `Bit.Vector.Ones.Static<wordCount>`, removed `Property`-based `forEach` |
| `exports.swift` | Added `@_exported import Sequence_Primitives` |

### 9.2 Design Decisions

**Why `Swift.Sequence` over `Property.View` pattern**: The `Property<Sequence.ForEach, Base>.View` pattern requires `mutating _read`/`_modify` access, which does not work on temporaries. Call sites like `bitmap.ones.forEach { }` create a temporary `Ones.View` — the `Property.View` accessor would fail. `Swift.Sequence.forEach` is non-mutating and works on temporaries, preserving the existing call-site syntax.

**Why separate `Ones.Static<wordCount>`**: `Bit.Vector.Static` stores an `InlineArray` on the stack. A pointer-based view into stack storage would dangle on temporaries. `Ones.Static` copies the `InlineArray` (cheap — typically 1–4 words) so iteration is safe on temporaries.

**What stays as-is**:
- `Bit.Set.forEach` — innermost single-word bit extraction loop (Wegner/Kernighan on one `UInt`). Called BY the iterators, not replaced by them.
- `Storage.Initialization.forEach` — 3-case switch over 0–2 ranges. Not a sequence reimplementation.

### 9.3 Finding: `underestimatedCount` Disambiguation

**Problem**: When a type conforms to both `Sequence.Protocol` and `Swift.Sequence`, the compiler reports an ambiguity error for `underestimatedCount`:

```
error: type 'X' does not conform to protocol 'Sequence'
note: multiple matching properties named 'underestimatedCount' with type 'Int'
```

**Root cause**: `Sequence.Protocol+Swift.Sequence.swift` provides a default `underestimatedCount` on all `Sequence.Protocol where Self: Copyable` types. `Swift.Sequence` provides its own default. The compiler sees two matching candidates and cannot pick.

**Fix**: Every type conforming to both protocols must include an explicit override:

```swift
extension MyType: Swift.Sequence {
    var underestimatedCount: Int { 0 }
}
```

**Scope**: Affects all types that conform to both `Sequence.Protocol` and `Swift.Sequence` — not just bit-vector types. This finding applies ecosystem-wide and should be documented in sequence-primitives itself.

**Validated by**: `swift-bit-vector-primitives/Experiments/sequence-protocol-conformance/` — all 7 variants confirmed.

### 9.4 Downstream Impact

| Package | Impact | Source Changes |
|---------|--------|----------------|
| storage-primitives (Tier 14) | `_slots.ones.forEach { }` now dispatches to `Swift.Sequence.forEach` | Zero |
| buffer-primitives (Tier 15) | 10 call sites upgraded transitively | Zero |
| All future ADTs using `Ones.View` | Get `for-in`, `map`, `filter`, `reduce` for free | Zero |

### 9.5 Verification

| Check | Result |
|-------|--------|
| `swift build` (bit-vector-primitives) | Pass |
| `swift test` (bit-vector-primitives) | 16/16 tests pass |
| `swift build` (storage-primitives) | Pass |
| `swift build` (buffer-primitives) | Pre-existing compiler crash in `Buffer.Slab.deinit` MoveOnlyChecker — unrelated |
| Experiment (7 variants) | All CONFIRMED |

---

## References

### Internal Research

- `/Users/coen/Developer/swift-primitives/Research/range-sequence-collection-semantic-analysis.md` — RES-014, Sequence/Collection/Range semantic relationships
- `/Users/coen/Developer/swift-primitives/Research/storage-primitives-comparative-analysis.md` — State of the art analysis for storage-primitives
- `/Users/coen/Developer/swift-primitives/Research/integration-maximization-comparative-analysis.md` — Integration methodology and metrics
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Research/storage-ownership-reference-synthesis.md` — Three-layer model (Storage → Buffer → ADT)
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Research/Collection Primitives Architecture.md` — ADT storage patterns, variant system

### Package Sources

- `/Users/coen/Developer/swift-primitives/swift-sequence-primitives/` — Sequence protocols and Property.View operations
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/` — Storage.Heap, Storage.Inline, tracked accessors
- `/Users/coen/Developer/swift-primitives/swift-bit-vector-primitives/` — Bit.Vector, Ones.View, Ones.Static (implements Sequence.Protocol)
- `/Users/coen/Developer/swift-primitives/swift-collection-primitives/` — Collection.Protocol bridging

### Experiments

- `/Users/coen/Developer/swift-primitives/swift-bit-vector-primitives/Experiments/sequence-protocol-conformance/` — Validates Sequence.Protocol + Swift.Sequence conformance, underestimatedCount disambiguation, and forEach-on-temporary behavior

### Swift Evolution

- SE-0390: Noncopyable structs and enums
- SE-0427: Noncopyable generics (source of Element: Copyable implicit constraint)
- SE-0456: Span properties

### Architectural Documents

- `/Users/coen/Developer/swift-primitives/Documentation.docc/Primitives Tiers.md` — Tier constraint and current assignments
- `/Users/coen/Developer/swift-institute/Documentation.docc/Five Layer Architecture.md` — Layer model
