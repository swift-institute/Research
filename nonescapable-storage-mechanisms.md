# ~Escapable Storage Mechanisms

<!--
---
version: 1.2.0
last_updated: 2026-03-02
status: SUPERSEDED
superseded_by: nonescapable-ecosystem-state.md
---
-->

> **SUPERSEDED** (2026-04-02) by [nonescapable-ecosystem-state.md](nonescapable-ecosystem-state.md) (swift-institute).
> All findings consolidated into the topic-based document. This file retained as historical rationale.

## Context

The Swift Institute ecosystem is adopting `~Escapable` types (SE-0446) for lifetime-safe resource access. Track 2 of the adoption plan requires multi-element containers with conditional Escapable conformance — containers that are Escapable when `Element: Escapable`, and ~Escapable when `Element: ~Escapable`.

The initial experiment (`conditional-escapable-container`) reported that heap-backed containers are blocked because `UnsafeMutablePointer<T>` requires `T: Escapable`. This research investigates whether the blocker is absolute or if workarounds exist.

**Trigger**: User requested verification of the blocker against the Swift compiler source at `/Users/coen/Developer/swiftlang/swift/`.

## Question

Can multi-element containers store `~Escapable` elements today (Swift 6.2.4), and if so, through what mechanism?

## Analysis

### Root Cause: Implicit Escapable on Pointer Type Parameters

The Swift stdlib declares pointer types with `~Copyable` but NOT `~Escapable` on their type parameters:

```swift
// stdlib/public/core/UnsafePointer.swift
public struct UnsafeMutablePointer<Pointee: ~Copyable>: Copyable { ... }
```

Since `~Escapable` is not suppressed, `Pointee` implicitly requires `Escapable`. This was confirmed by:

1. **Compiler diagnostic**: `'where Pointee: Escapable' is implicit here`
2. **FIXME in compiler source** (`lib/ClangImporter/ImportType.cpp:507`): "FIXME: remove workaround once Unsafe*Pointer supports nonescapable pointees"
3. **SE-0465 explicit deferral**: "To usefully allow pointers to nonescapable types, we'll need to assign precise lifetime semantics to their pointee... that work is postponed to a future proposal"

The same implicit Escapable affects:
- `UnsafeMutableRawPointer.initializeMemory(as: T.self, to:)` — `T` implicitly Escapable
- `UnsafeMutableRawPointer.assumingMemoryBound(to: T.self)` — `T` implicitly Escapable
- `InlineArray<let count: Int, Element: ~Copyable>` — `Element` implicitly Escapable
- `withUnsafePointer(to:)`, `withUnsafeMutablePointer(to:)` — `T` implicitly Escapable

### Blocked Paths (Exhaustively Tested)

| Path | Error | Root Cause |
|------|-------|------------|
| `UnsafeMutablePointer<Element>` | `type 'Element' does not conform to protocol 'Escapable'` | Implicit Escapable on `Pointee` |
| `UnsafeMutableRawPointer.initializeMemory(as:to:)` | Same | Implicit Escapable on `T` |
| `UnsafeMutableRawPointer.assumingMemoryBound(to:)` | Same | Implicit Escapable on `T` |
| `InlineArray<N, Element>` | Same | Implicit Escapable on `Element` |
| `withUnsafePointer(to:)` | Same | Implicit Escapable on `T` |
| `Optional<Element>` as stored property | `lifetime-dependent variable 'self' escapes its scope` | Lifetime checker rejects Optional wrapping in ~Escapable containers |
| Partial reinit of `self.property` | `cannot partially reinitialize 'self' after it has been consumed` | ~Copyable ownership rule |
| `@_rawLayout` element access | Same as pointer types | Layout compiles, but typed access requires pointer types with implicit Escapable |

### Working Paths

| Path | Mechanism | Capacity |
|------|-----------|----------|
| Non-Optional struct fields | Inline storage (like enum) | Fixed at compile time |
| Enum associated values | Compiler enum layout engine | Variable (one case per occupancy level) |
| consuming take() | Move semantics | N/A (extraction) |
| Nested containers | Composition | Depth, not breadth |
| MemoryLayout<~Escapable> | Type metadata | N/A (size/alignment query) |
| `@_rawLayout` declaration | Attribute does not constrain Escapable | N/A (layout only, no access) |

### Key Discovery: Enum-Based Variable-Occupancy Storage

The stdlib's `Optional<Wrapped: ~Copyable & ~Escapable>` and `Result<Success: ~Copyable & ~Escapable>` prove that enum associated values support ~Escapable elements. The problem with Optional is using it as a **stored property** inside another ~Escapable type.

The workaround: make the enum itself the container, with each case representing a different occupancy level:

```swift
enum EnumStack4<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    case zero
    case one(Element)
    case two(Element, Element)
    case three(Element, Element, Element)
    case four(Element, Element, Element, Element)

    @_lifetime(self: copy self, copy element)
    mutating func push(_ element: consuming Element) {
        switch consume self {       // Full consumption of self
        case .zero:
            self = .one(element)    // Full reinit (not partial)
        case .one(let a):
            self = .two(a, element)
        // ...
        }
    }
}

extension EnumStack4: Copyable where Element: Copyable & ~Escapable {}
extension EnumStack4: Escapable where Element: Escapable & ~Copyable {}
```

This works because:
1. `consume self` on the enum is **full** consumption (the entire value)
2. `self = .case(...)` is **full** reinitialization (not partial)
3. Enum layout handles the occupancy discrimination without Optional
4. Conditional Escapable conformance composes correctly

**Validated by experiment**: `pointer-nonescapable-storage` V14 (2 slots) and V15 (4 slots), both CONFIRMED on Swift 6.2.4.

### Scalability Assessment

| Capacity | Enum Cases | Associated Values | Practical? |
|----------|-----------|-------------------|------------|
| 2 | 3 (empty, one, two) | 3 | Yes |
| 4 | 5 | 10 | Yes |
| 8 | 9 | 36 | Marginal |
| 16 | 17 | 136 | Impractical |
| 64 | 65 | 2080 | No |

The enum pattern is practical for small fixed capacities (2-8). For larger capacities, it becomes unwieldy. Production waiter queues (Async.Waiter.Queue.Bounded) use capacities of 64+, which rules out enum-based storage.

### @_rawLayout: Layout Compiles, Access Blocked

Value-generic parameterized structs using `@_rawLayout` were investigated as a general alternative to hand-coded enum variants:

```swift
@_rawLayout(likeArrayOf: Element, count: capacity)
struct RawLayoutStorage<Element: ~Copyable & ~Escapable, let capacity: Int>: ~Copyable, ~Escapable {
    @_lifetime(immortal) init() {}
}
```

**Layout declaration**: COMPILES. `@_rawLayout(likeArrayOf: Element, count: capacity)` does not add an implicit Escapable constraint on Element. `MemoryLayout` correctly reports `size = capacity × stride(Element)`.

**Element access**: BLOCKED. Every path from raw storage to a typed element requires a pointer type with implicit Escapable:

| Access Method | Blocker |
|---------------|---------|
| `UnsafeMutablePointer<Element>(rawPtr)` | `Pointee` implicitly Escapable |
| `rawPtr.assumingMemoryBound(to: Element.self)` | `T` implicitly Escapable |
| `rawPtr.initializeMemory(as: Element.self, to:)` | `T` implicitly Escapable |
| `unsafeAddress` / `unsafeMutableAddress` subscripts | Return `UnsafePointer<Element>` — same |
| `withUnsafeMutablePointer(to:)` | `T` implicitly Escapable |

**Why enums bypass this**: Enum associated values are accessed through pattern matching. The compiler manages storage offsets at compile time — no pointer construction needed. `@_rawLayout` requires runtime offset computation via pointer arithmetic, which hits the typed pointer constraint.

**Conclusion**: `@_rawLayout` is the correct **future** solution. When stdlib adds `~Escapable` to pointer type parameters (per SE-0465 deferral), `@_rawLayout` containers will immediately work. Today, it suffers the same access blocker as all pointer-backed storage.

**Validated by experiment**: `pointer-nonescapable-storage` V16 (declaration PASS), V17/V17b (access BLOCKED) on Swift 6.2.4.

### Stdlib Patterns (for reference)

Types that ARE ~Escapable in stdlib store their backing data as `UnsafeRawPointer?` (type-erased), not through typed pointers:
- `Span<Element: ~Copyable>` → stores `UnsafeRawPointer?`
- `MutableSpan<Element: ~Copyable>` → stores `UnsafeMutableRawPointer`

These are **views** (non-owning), not containers. The raw pointer stores a pointer-to-existing-memory, not a pointer-to-owned-allocation.

## Outcome

**Status**: DECISION

### Confirmed Blockers

1. **Heap-backed containers** (`UnsafeMutablePointer`, `UnsafeMutableRawPointer`) cannot store ~Escapable elements. This requires stdlib changes (adding `~Escapable` to Pointee/T type parameters) which are deferred to a future Swift Evolution proposal.

2. **`Optional<Element>` stored properties** in ~Escapable containers are blocked by the lifetime checker. This affects any pattern that needs "empty slot" semantics.

3. **`InlineArray<N, Element>`** does not support ~Escapable elements (same implicit Escapable constraint).

4. **`@_rawLayout` element access** is blocked by the same pointer constraint. The layout declaration compiles with `Element: ~Escapable`, but all element access methods require pointer types with implicit Escapable. This is the **layout-vs-access gap** — `@_rawLayout` is the correct future solution when pointer types gain `~Escapable` support.

### Available Workarounds

1. **Single-element containers** (Box/wrapper): Fully supported via non-Optional struct fields with `@_lifetime(copy element)` on init.

2. **Fixed-element containers** (Pair, Triple): Supported for compile-time-fixed element counts via non-Optional struct fields.

3. **Enum-based variable-occupancy** (NEW): Supports 2-8 element containers with push/access semantics. Uses `consume self` + full reinit to avoid partial reinit errors.

### Production Applicability

| Container | Current Storage | ~Escapable Viable? | Mechanism |
|-----------|----------------|---------------------|-----------|
| Resumption | N/A (closure) | **REVERTED** | ~Escapable deployment reverted — cache/pool need `[Resumption]` (dynamic array, heap-backed) |
| Entry | Struct fields | Possible (immortal) | All fields are Escapable types |
| Queue.Bounded (capacity 64) | UnsafeMutablePointer | **NO** | Blocked by pointer Escapable constraint |
| Queue.Unbounded (linked list) | UnsafeMutablePointer | **NO** | Same |
| Stream.Iterator | Closure | Possible (immortal) | @_lifetime(immortal) workaround |

### Recommendation

1. **Resumption ~Copyable + ~Escapable**: Attempted and **reverted**. Pattern works in isolation (experiment V1-V7 PASS) but downstream consumers (cache/pool) require `[Resumption]` — dynamic arrays cannot hold ~Escapable elements. This demonstrates that the heap-backed container blocker cascades beyond container types to any type that must be stored in collections.

2. **Entry ~Escapable**: Experiment should test `@_lifetime(immortal)` on Entry. All stored fields (continuation, flag, metadata) are Escapable types, so no storage blocker exists. The question is whether Entry can be ~Escapable without cascading to Queue.

3. **Queue ~Escapable**: BLOCKED. No workaround available at current capacities. Track the Swift Evolution proposal for `UnsafePointer<Pointee: ~Copyable & ~Escapable>`.

4. **Enum-based containers**: Viable for new small-capacity container types (inline stacks, pairs, triples) but not for existing production Queue types.

## References

- SE-0446: Nonescapable Types
- SE-0465: Nonescapable Standard Library Primitives (explicit pointer deferral)
- SE-0437: Noncopyable Standard Library Primitives (pointer ~Copyable support)
- Experiment: `swift-institute/Experiments/pointer-nonescapable-storage/`
- Experiment: `swift-institute/Experiments/conditional-escapable-container/`
- FIXME: `swiftlang/swift/lib/ClangImporter/ImportType.cpp:507`
