# Non-Closure Peek for ~Copyable Elements via ~Escapable

<!--
---
version: 1.0.0
last_updated: 2026-03-31
status: SUPERSEDED
superseded_by: nonescapable-ecosystem-state.md
---
-->

> **SUPERSEDED** (2026-04-02) by [nonescapable-ecosystem-state.md](nonescapable-ecosystem-state.md) (swift-institute).
> All findings consolidated into the topic-based document. This file retained as historical rationale.

## Context

`Queue.DoubleEnded.front.peek` uses a closure for ~Copyable elements:

```swift
func peek<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R?
```

The Copyable path has `var peek: Element?` which copies. The closure pattern works but is less ergonomic than property access. This research investigates whether `~Escapable` or other Swift ownership features can enable a property-based peek for ~Copyable elements.

**Trigger**: Design question during ~Copyable ownership improvements for `Async.Bridge` and Deque accessor API. The closure-based peek was the pragmatic Swift 6.2 solution. Filed as handoff from queue-primitives session.

**Prior assumption**: `Optional<~Escapable>` was expected to be blocked by nil-construction lifetime requirements, based on the `flatmap-inner-iterator-state-machine` experiment (V3, REFUTED in Swift 6.2.3) which found `var x: T? = nil` fails for `~Escapable` T as a stored property.

## Question

Can `~Escapable` types enable a non-closure `var peek: Borrowed<Element>?` property for ~Copyable deque elements?

## Analysis

### Three Avenues Investigated

#### Avenue 1: ~Escapable Wrapper (`Borrowed<T>`)

A `Borrowed<T: ~Copyable>: ~Escapable` type wrapping `UnsafePointer<T>` with `@_lifetime(borrow pointer)`. The wrapper is Copyable (pointer is trivially copyable) but ~Escapable (lifetime tied to the container's borrow scope). Per [IMPL-065], this is a "pointer-based view into a container."

**Key type properties:**
- Copyable: yes (UnsafePointer is Copyable)
- ~Escapable: yes (lifetime-scoped via @_lifetime)
- Can wrap in Optional: yes (Copyable allows `.some()` wrapping without consumption)

This is the critical distinction from the prior `read-accessor-noncopyable-optional` experiment, which tested `Optional<NC>` where NC is ~Copyable. Wrapping a ~Copyable value in `.some()` consumes it. Wrapping a Copyable ~Escapable value in `.some()` copies it — no consumption.

#### Avenue 2: `_read` Coroutine Accessor

The `_read` accessor yields a borrow within a coroutine frame. Already used in production for `Queue.DoubleEnded.front` (yields `Front.View`). The question was whether `_read` can yield `Optional<~Escapable>`.

**Status**: `_read`/`_modify` remain underscored. SE-0474 (Yielding Accessors) provides official replacements (`yielding borrow`/`yielding mutate`), accepted but not yet shipping. SE-0507 (Borrow and Mutate Accessors) provides non-coroutine alternatives for stored values.

#### Avenue 3: Future `ref`/`borrow` Return Types

The Ownership Manifesto deferred `ref` returns. Current state:

| Feature | Available |
|---------|-----------|
| `_read`/`_modify` (unsupported) | Swift 5.0+ |
| `~Escapable` + `@_lifetime` (experimental) | Swift 6.2+ |
| SE-0474 `yielding borrow`/`yielding mutate` | Swift 6.4 |
| SE-0507 `borrow`/`mutate` accessors | Swift 6.4 |
| SE-0519 `Borrow<T>`/`Inout<T>` types | Review complete, decision pending |
| `@lifetime` (official, non-experimental) | Pitch #3 stage |

SE-0519 is the most relevant: `Borrow<T>` and `Inout<T>` are stdlib `~Escapable` types for first-class borrowed/mutable references. Structurally identical to the `Borrowed<T>` wrapper in our experiment.

### Experimental Verification

**Experiment**: `swift-primitives/Experiments/noncopyable-peek-escapable/`
**Toolchain**: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
**Modes tested**: Debug and release

| Variant | Pattern | Result |
|---------|---------|--------|
| V1 | `Borrowed<T: ~Copyable>: ~Escapable` type definition | CONFIRMED |
| V2 | Non-optional `_read` yield of `Borrowed<Resource>` from ~Copyable container | CONFIRMED |
| V3 | Function returning `Optional<Span<Int>>` with nil fallback | CONFIRMED |
| V4 | Computed property returning `Optional<Span<Int>>` with `@_lifetime(borrow self)` | CONFIRMED |
| V5 | `_read` yielding `Optional<Borrowed<Resource>>` with nil fallback | CONFIRMED |
| V6 | Two-step `isEmpty` + non-optional `Borrowed` accessor | CONFIRMED |
| V7 | Closure-based `func peek<R>(_ body: (borrowing Element) -> R) -> R?` (status quo) | CONFIRMED |

**All 7 variants pass in both debug and release mode.** The original hypothesis — that `Optional<~Escapable>` is blocked — is refuted for Swift 6.3.

### Key Insight

The blocker documented in prior experiments is **~Copyable + Optional**, not **~Escapable + Optional**:

| Combination | Works? | Why |
|-------------|--------|-----|
| `Optional<~Copyable>` from `_read` | No | `.some()` wrapping consumes the ~Copyable value |
| `Optional<Copyable & ~Escapable>` from `_read` | **Yes** | `.some()` copies the Copyable wrapper; ~Escapable nil has valid lifetime in coroutine/function scope |
| `var x: ~Escapable? = nil` (stored property) | No | Stored property nil has no lifetime source |
| `return nil` in `@_lifetime(borrow)` function | **Yes** | Function's lifetime annotation covers the nil case |

The `Borrowed<T>` wrapper is Copyable because it holds only `UnsafePointer<T>`. The element `T` is ~Copyable, but the wrapper itself is not. This is the same design as `Span<Element>` — Span is Copyable regardless of Element's copyability.

### Proposed Design for Queue.DoubleEnded

```swift
/// Borrowed view into a ~Copyable element. Copyable, ~Escapable.
struct Borrowed<T: ~Copyable>: ~Escapable {
    let _pointer: UnsafePointer<T>

    @_lifetime(borrow pointer)
    init(_ pointer: UnsafePointer<T>) {
        unsafe _pointer = pointer
    }

    var pointee: T {
        _read { yield unsafe _pointer.pointee }
    }
}

// On Front.View / Back.View:
var peek: Borrowed<Element>? {
    _read {
        guard !(unsafe base.pointee.isEmpty) else { yield nil; return }
        yield unsafe Borrowed(base.pointee._buffer.frontPointer)
    }
}
```

**Call site** (replaces closure):
```swift
// Before (closure):
deque.front.peek { $0.value }

// After (property):
deque.front.peek?.pointee.value
```

### Comparison of Patterns

| Criterion | Closure (V7) | Borrowed property (V5) | Two-step (V6) |
|-----------|-------------|----------------------|----------------|
| Optional return | Yes | Yes | No (preconditions) |
| No closure overhead | No | Yes | Yes |
| Single expression | Yes | Yes | No (guard + access) |
| Works with `if let` | Yes (on R) | Yes (on Borrowed) | N/A |
| Stable Swift | Yes | Experimental (`@_lifetime`) | Experimental (`@_lifetime`) |
| Lifetime-safe | N/A (closure scoped) | Yes (compiler-enforced) | Yes (compiler-enforced) |

### Constraints

1. **`@_lifetime` is experimental**: Supported since Swift 6.2, used by stdlib (Span), but not yet an official language feature. Pitch #3 is in progress.
2. **`_read` is underscored**: SE-0474 (`yielding borrow`) provides the official replacement but isn't shipping yet. The underscored `_read` is already used throughout swift-primitives production code.
3. **Buffer must expose element pointer**: `Buffer.Ring` needs a `frontPointer`/`backPointer` method returning `UnsafePointer<Element>`. This is a minor infrastructure addition.
4. **SE-0519 convergence**: If `Borrow<T>` is accepted, it would be the stdlib equivalent of our `Borrowed<T>`. The ecosystem should adopt the stdlib type when available.

### Prior Art Reconciliation

| Prior experiment | Finding | Reconciliation |
|-----------------|---------|----------------|
| `read-accessor-noncopyable-optional` (2026-02-13) | `_read` cannot yield ~Copyable into Optional | Still correct. Our `Borrowed<T>` is Copyable, not ~Copyable. |
| `flatmap-inner-iterator-state-machine` V3 (REFUTED) | `var x: T? = nil` fails for ~Escapable T as stored property | Still correct for stored properties. Our experiment uses computed properties and coroutines. |
| `mutex-escapable-accessor` (2026-03-31) | ~Escapable views from _read work | Confirmed and extended: Optional<~Escapable> also works. |
| `nonescapable-edge-cases` (2026-02-28) | ~Escapable claims verified | Compatible. Our experiment adds Optional<~Escapable> as a new confirmed capability. |

## Outcome

**Status**: RECOMMENDATION

### Decision

A `Borrowed<T: ~Copyable>: ~Escapable` wrapper type CAN enable property-based `var peek: Borrowed<Element>?` for ~Copyable deque elements. All three avenues converge on feasibility:

1. **~Escapable wrapper**: FEASIBLE NOW (Swift 6.3, experimental `@_lifetime`)
2. **`_read` coroutine**: FEASIBLE NOW (underscored, production-proven)
3. **Future stabilization**: SE-0474 (`yielding borrow`), SE-0507 (`borrow` accessor), SE-0519 (`Borrow<T>`) all reinforce this direction

### Recommendation

1. **Implement `Borrowed<T>` in `swift-property-primitives`** (or a new `swift-borrow-primitives`) as the ecosystem's borrowed-view type. Design it as a precursor to SE-0519's `Borrow<T>` — same shape, easy migration path.

2. **Add `var peek: Borrowed<Element>?` to `Front.View` and `Back.View`** alongside the existing closure-based `func peek`. The property is more ergonomic; the closure remains for backward compatibility and for patterns that need to transform within the borrow scope.

3. **When SE-0519 ships**: Replace `Borrowed<T>` with `Borrow<T>` from the stdlib. The API shape is identical — `peek?.pointee` becomes the permanent pattern.

4. **Infrastructure prerequisite**: `Buffer.Ring` needs `frontPointer` / `backPointer` methods returning `UnsafePointer<Element>` to the front/back elements.

### Deferred

- **Stored property `Optional<~Escapable>`**: Still blocked (no lifetime source for nil default). Not needed for the computed property pattern.
- **`Optional<~Copyable>` from `_read`**: Still blocked (`.some()` consumes). The `Borrowed<T>` wrapper sidesteps this entirely because it is Copyable.

## References

- SE-0446: Nonescapable Types
- SE-0456: Stdlib Span Properties
- SE-0465: Nonescapable stdlib primitives
- SE-0474: Yielding Accessors
- SE-0507: Borrow and Mutate Accessors
- SE-0519: Borrow and Inout Types (review complete, decision pending)
- Pitch #3: Compile-time Lifetime Dependency Annotations
- Andrew Trick: Property Lifetimes gist
- Experiment: `swift-primitives/Experiments/noncopyable-peek-escapable/`
- Prior: `swift-input-primitives/Experiments/read-accessor-noncopyable-optional/`
- Prior: `swift-sequence-primitives/Experiments/flatmap-inner-iterator-state-machine/`
- Prior: `swift-primitives/Experiments/mutex-escapable-accessor/`
- Memory: `copypropagation-nonescapable-fix.md` (CopyPropagation Bug 2 — FIXED in Swift 6.3)
