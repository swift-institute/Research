# Defunctionalized Work Queue Extraction

<!--
---
version: 1.0.0
last_updated: 2026-03-18
status: IN_PROGRESS
tier: 2
---
-->

## Context

Two primitives packages independently implement the same structural pattern: **replacing recursive tree traversal with an iterative loop over a heap-allocated work stack**. Both use type-erased raw pointers with witness closures for dispatch and destruction.

| Consumer | Package | Pattern Instance |
|----------|---------|-----------------|
| Parser execution | swift-machine-primitives (tier 19) | `Machine.Value` + `Machine.Frame` + `Stack<Frame>` + `Machine.Value.Arena` |
| View rendering | swift-rendering-primitives | `Rendering.Thunk` + `Rendering.Work` + `[Work]` stack |

This research investigates whether the shared shape should be extracted into a reusable primitive, and if so, what it should look like.

## Question

Should the "type-erased heap allocation + witness dispatch + iterative work stack" pattern be extracted into a shared primitive that both machine-primitives and rendering-primitives consume?

## Prior Art

### Internal

- `Machine.Value<Mode>` — type-erased value with ARC `_Storage` class, `ObjectIdentifier` for type-safe extraction, `_Table` for destruction. Production since 2026-01.
- `Rendering.Thunk` — witness struct storing `dispatch` + `destroy` closures, paired with `UnsafeMutableRawPointer`. Implemented 2026-03-18.
- Both derive from the same insight: recursive traversal overflows the 544 KB cooperative thread pool stack; defunctionalize continuations onto the heap.

### External

- **Trampoline pattern** (functional programming) — convert recursive calls to heap-allocated thunks processed in a loop. Standard technique in Haskell, Scala, and continuation-passing style transforms.
- **Defunctionalization** (Reynolds 1972) — replace higher-order functions with first-order data + dispatch. Machine.Frame is a textbook defunctionalized continuation.
- **Work-stealing queues** (Cilk, Swift concurrency) — related but different: concurrent work distribution vs. single-threaded traversal.

## Analysis

### Instance Comparison

#### Shared Shape

Both consumers implement these four components:

| Component | Description |
|-----------|-------------|
| **Type-erased heap value** | Allocate `T` on heap via `UnsafeMutablePointer<T>`, carry `UnsafeMutableRawPointer` |
| **Witness closures** | Closures specialized at creation time capturing `T.self` for type-specific operations |
| **Work stack** | LIFO collection of work items; dispatch may push new items |
| **Iterative loop** | `while let item = stack.pop() { dispatch(item) }` replacing recursion |

#### Concrete Divergences

| Aspect | Machine (parser) | Rendering |
|--------|-------------------|-----------|
| **Value lifetime** | ARC (`_Storage` class) — values may be referenced from multiple frames via handles | Manual alloc/dealloc — each value consumed exactly once |
| **Type extraction** | Yes — `ObjectIdentifier` + `read<T>/take<T>` to recover typed value | No — dispatch closure is fully type-erased, never extracts |
| **Witness shape** | `_Table` (destroy only) + separate `Transform.Erased` (dispatch via capture system) | `Thunk` (dispatch + destroy bundled) |
| **Work item type** | `Machine.Frame` — 9+ domain-specific continuation cases (map, flatMap, oneOf, many, fold, optional, sequence, recursiveExit, extra) | `Rendering.Work` — 2 cases (render, action) |
| **Stack type** | `Stack<Frame>` from stack-primitives (typed, ~Copyable) | `[Work]` plain Array |
| **Arena** | `Machine.Value.Arena` — slot-based random access with handle indirection + generation counter (ABA prevention) | None — sequential LIFO only |
| **Error recovery** | Backtracking: unwind frame stack on failure, try alternatives | None |
| **~Copyable support** | No — `Machine.Value` stores Copyable values only | Yes — `Rendering.Thunk` borrows through raw pointer for ~Copyable views |

### Option A: No Extraction (Status Quo)

Each consumer maintains its own implementation of the pattern.

**Rendering implementation size**: ~60 lines total (Thunk: 39, Work: 7, Context extensions: ~60).

**Machine implementation size**: ~360 lines (Value: 248, Value.Arena: 114, _Table inline).

**Advantages**:
- Zero coupling between consumers
- Each implementation is exactly right for its domain
- No dependency overhead
- Domain-specific optimizations (ARC for multi-reference in machine, manual for single-consume in rendering)

**Disadvantages**:
- Pattern repeated when future consumers appear (serialization, layout, AST transforms)
- Unsafe boilerplate duplicated (alloc/init/deinit/dealloc pattern)

### Option B: Extract a Shared `Thunk` Type

Extract the "type-erased heap value with destruction witness" into a low-tier primitive.

```swift
/// A type-erased heap-allocated value with automatic destruction.
public struct Erased: ~Copyable {
    @usableFromInline let pointer: UnsafeMutableRawPointer
    @usableFromInline let _destroy: (UnsafeMutableRawPointer) -> Void

    @inlinable
    public init<T>(allocating value: consuming T) {
        let p = UnsafeMutablePointer<T>.allocate(capacity: 1)
        p.initialize(to: value)
        self.pointer = .init(p)
        self._destroy = { raw in
            raw.assumingMemoryBound(to: T.self).deinitialize(count: 1)
            raw.deallocate()
        }
    }

    deinit { _destroy(pointer) }
}
```

**Advantages**:
- Centralizes the unsafe alloc/init/deinit/dealloc pattern
- ~Copyable with `deinit` — automatic cleanup, no manual destroy calls
- Rendering's `_cleanupStack()` becomes unnecessary (deinit handles it)
- Future consumers get safe heap allocation for free

**Disadvantages**:
- Machine can't use it — Machine.Value needs ARC (multi-reference via handles), ObjectIdentifier (type extraction), and Sendable mode parameterization. This type is strictly less capable.
- Rendering still needs a dispatch closure alongside this type (dispatch is domain-specific)
- Very thin abstraction: 15 lines, wrapping 4 lines of unsafe code. Marginal value.
- Consumers still need the `pointer` for dispatch, so the unsafe access moves rather than disappears

### Option C: Use `Machine.Value<Mode.Unchecked>` Directly in Rendering

Rendering depends on machine-primitives and uses `Machine.Value` for type-erased storage.

```swift
// Rendering.Work would become:
enum Work {
    case render(
        value: Machine.Value<Machine.Capture.Mode.Unchecked>,
        dispatch: (Machine.Value<Machine.Capture.Mode.Unchecked>, inout Context) -> Void
    )
    case action(Action)
}
```

**Advantages**:
- Reuses production-proven type-erased storage
- ARC handles cleanup automatically — no `_cleanupStack()`, no manual destroy
- No raw pointer operations in rendering code

**Disadvantages**:
- **~Copyable blocker**: `Machine.Value.read<T>()` returns `T` (a copy). Rendering needs to *borrow through* the pointer for `borrowing Self` on `_render`. Machine.Value doesn't expose its raw pointer publicly. ~Copyable views cannot be extracted via `read`. **This is a fundamental mismatch.**
- ARC overhead: each work item allocates a `_Storage` class instance. For a 1000-view tree, that's 1000 extra class allocations + retain/release. The current manual approach has zero ARC traffic.
- `ObjectIdentifier` stored but never checked — dead weight per work item
- Dependency on machine-primitives pulls in handle-primitives (tier 10) and graph-primitives (tier 18) at the package level, even though only Machine Value Primitives (effective tier 0) is consumed

### Option D: Extract a Generalized `Trampoline` (Loop + Stack)

Extract the iterative loop pattern itself into a primitive.

```swift
public struct Trampoline<Item>: ~Copyable {
    var items: [Item]

    public mutating func push(_ item: Item) { items.append(item) }

    public mutating func run(_ dispatch: (Item, inout Self) -> Void) {
        while let item = items.popLast() {
            dispatch(item, &self)
        }
    }
}
```

**Advantages**:
- Captures the abstract loop pattern

**Disadvantages**:
- Trivially thin: wraps `[Item]` + `while popLast`. Three lines of infrastructure.
- Consumers need domain-specific `Item` types anyway (Frame, Work)
- The loop body is 1-5 lines in both consumers — the abstraction saves nothing
- Rendering needs `_reverseAbove(marker)` for LIFO ordering correction; machine doesn't. Domain-specific stack operations don't generalize.

### Option E: Extend Machine.Value with Borrowing Access

Add a `withUnsafePointer` method to `Machine.Value` that enables borrowing access without extraction, then use Machine.Value in rendering.

```swift
extension Machine.Value {
    @inlinable
    public func withUnsafePointer<R>(
        as type: T.Type,
        _ body: (UnsafePointer<T>) -> R
    ) -> R {
        precondition(self.type == ObjectIdentifier(T.self))
        return body(_project(type))
    }
}
```

**Advantages**:
- Fixes the ~Copyable blocker from Option C
- Rendering dispatch becomes: `value.withUnsafePointer(as: V.self) { V._render($0.pointee, context: &ctx) }`
- ARC cleanup still works
- Machine.Value becomes more generally useful

**Disadvantages**:
- Still carries ARC overhead (class allocation per work item)
- Still carries ObjectIdentifier overhead
- Rendering dispatch closure still needs to be stored alongside the value (Machine.Value has no concept of "dispatch witness")
- Requires machine-primitives API change for rendering's benefit — pollutes a focused API

## Comparison

| Criterion | A: Status Quo | B: Shared Thunk | C: Machine.Value | D: Trampoline | E: Machine.Value + Borrow |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Code reuse | None | Partial | Full storage | Loop only | Full storage |
| ~Copyable support | ✓ | ✓ | ✗ **blocker** | N/A | ✓ (with API change) |
| ARC overhead | None | None | Per work item | None | Per work item |
| Abstraction value | — | Marginal (15 lines) | Moderate | Trivial (3 lines) | Moderate |
| Coupling | None | Low (new primitive) | High (machine dep) | Low (new primitive) | High (machine dep + API change) |
| Future consumers | Copy pattern | Import primitive | Import machine | Import trampoline | Import machine |
| Unsafe containment | No (in each consumer) | Yes (centralized) | Yes (in Machine.Value) | No | Yes (in Machine.Value) |
| Machine can use it? | N/A | No (needs ARC + extraction) | N/A (is machine) | No (too thin) | N/A |

### Key Tensions

1. **Machine.Value is ARC-based; rendering needs manual single-owner lifetime.** Machine values may be referenced from multiple frames (via arena handles). Rendering values are produced once, consumed once. ARC is structural overhead for this use case.

2. **Machine.Value returns copies; rendering needs borrows.** The `read<T>` / `take<T>` API copies the value out. Rendering's `borrowing Self` on `_render` requires pointer-level access. This is fixable (Option E) but changes Machine.Value's API surface.

3. **The witness table shapes are different.** Machine separates destruction (`_Table`) from dispatch (`Transform.Erased` via capture system). Rendering bundles them (`Thunk`). No shared witness shape exists.

4. **The work item types are fully domain-specific.** Machine.Frame has 9+ parser-continuation cases. Rendering.Work has 2 cases. No useful shared `Work` type exists.

## Outcome

**Status**: IN_PROGRESS — awaiting discussion.

### Preliminary Assessment

The overlap between machine-primitives and rendering-primitives is at the **design pattern level**, not the **reusable type level**. The four concrete components (value storage, witness shape, work item type, loop structure) all diverge in their specifics:

- Storage: ARC multi-reference vs. manual single-owner
- Witness: separate destroy + dispatch-via-captures vs. bundled thunk
- Work items: 9-case parser continuation vs. 2-case render-or-action
- Loop: two-phase node-execution + frame-processing vs. simple pop-dispatch

**Options C and E** (use Machine.Value directly) face a structural mismatch: ARC overhead for a single-owner pattern, and borrowing access for ~Copyable types requires API changes to Machine.Value.

**Options B and D** (new shared primitives) are too thin to justify — they wrap 3-15 lines of code that each consumer writes once.

**Option A** (status quo) appears strongest for the current two-consumer situation. The rendering implementation is 60 lines, domain-specific, and correct. The pattern knowledge is documented (this research + cooperative-pool-stack-overflow.md) for future consumers.

### Open Question

If a third consumer appears (serialization, layout, AST transform), would the balance shift? The answer depends on whether that consumer's requirements match machine's shape (ARC, multi-reference, type extraction) or rendering's shape (single-owner, borrow-dispatch, no extraction). If the latter, a minimal `Erased` type (Option B) might cross the threshold. But [PRIM-FOUND-001] — existence is determined by domain scope, not adoption count — cuts both ways: a "type-erased heap allocation" IS a domain concept, but it might be too thin to be a useful primitive.

## References

- Reynolds, J.C. (1972). *Definitional interpreters for higher-order programming languages*. (Defunctionalization)
- `swift-rendering-primitives/Research/cooperative-pool-stack-overflow.md` (v6) — root cause analysis and option evaluation
- `swift-machine-primitives/Research/machine-value-api-surface.md` — Machine.Value extraction patterns
- `swift-institute/Research/Reflections/2026-03-18-iterative-render-machine-stack-overflow-fix.md`
