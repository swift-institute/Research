# Span View Integration Strategy

<!--
---
version: 1.0.0
last_updated: 2026-03-19
status: IN_PROGRESS
tier: 3
---
-->

## Context

After replacing `with*` closure patterns with direct `~Escapable` properties across the ecosystem, a second wave of closure patterns remains: `span.withUnsafeBufferPointer { }`. These exist because Span is a safe view that currently lacks protocol-level integration with the sequence/collection ecosystem. Converting Span to owning types (Array, String) requires escaping to unsafe code through closures.

**Trigger**: `entry.name.withUnsafeBufferPointer { buffer in String(decoding: buffer, as: UTF8.self) }` — we have a Span and immediately wrap it in a closure to escape to UnsafeBufferPointer. The Span IS the safe view; the closure defeats its purpose.

## Question

How should Span integrate with the Swift Institute sequence ecosystem to enable closure-free consumption, and what is the correct path for Span → String and Span → Array conversion?

## Prior Art Survey

### Swift Evolution

| Proposal | Topic | Key Finding |
|----------|-------|-------------|
| SE-0456 | Span: Safe Access to Contiguous Storage | Span is a non-owning, non-escaping view. Deliberately does NOT conform to Sequence/Collection. |
| SE-0467 | MutableSpan, MutableRawSpan | Mutable variants follow same ~Escapable pattern. |
| SE-0474 | Coroutine accessors (`read`/`modify` in protocols) | Enables protocol-level yielding of ~Escapable values. |

### stdlib `_BorrowingSequence` (Swift 6.3, experimental)

**File**: `swiftlang/swift/stdlib/public/core/BorrowingSequence.swift`

The stdlib has an **experimental, underscore-prefixed** protocol:

```swift
@available(SwiftStdlib 6.3, *)
public protocol _BorrowingSequence<_Element>: ~Copyable, ~Escapable {
    associatedtype _Element: ~Copyable
    associatedtype _BorrowingIterator: _BorrowingIteratorProtocol<_Element>

    @_lifetime(borrow self)
    func _makeBorrowingIterator() -> _BorrowingIterator
}
```

**Span already conforms** (6.3+):
```swift
extension Span: _BorrowingSequence, _BorrowingIteratorProtocol
where Element: ~Copyable {
    @_lifetime(borrow self)
    public func _makeBorrowingIterator() -> Self { self }

    @_lifetime(&self)
    @_lifetime(self: copy self)
    public mutating func _nextSpan(maximumCount: Int) -> Span<Element> {
        let result = extracting(first: maximumCount)
        self = extracting(droppingFirst: maximumCount)
        return result
    }
}
```

**Critical insight**: Span is **self-iterating** — it serves as both sequence and iterator, yielding sub-spans via `extracting()`.

### Our `Sequence.Borrowing.Protocol` (swift-sequence-primitives)

**File**: `swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Borrowing.Protocol.swift`

Our protocol parallels the stdlib design independently:

```swift
public protocol `Protocol`: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: Sequence.Iterator.`Protocol`

    @_lifetime(borrow self)
    borrowing func makeIterator() -> Iterator
}
```

**Already conforms**: Buffer.Linear, Buffer.Linear.Bounded, Buffer.Linear.Small, Buffer.Ring (multiple variants).

**Our `Span.Iterator`** already conforms to `Sequence.Iterator.Protocol` with `nextSpan(maximumCount: Cardinal)`.

### Convergence

The stdlib and our ecosystem **independently converged** on the same design:
- Iteration primitive is `nextSpan(maximumCount:)`, not `next()`
- Self-iterating pattern (sequence = iterator)
- `~Escapable` iterator tied to sequence lifetime
- Sub-span yielding for zero-copy batch access

The difference: stdlib uses `Int` for maximumCount, ours uses `Cardinal` (typed integer). And stdlib's is underscore-prefixed (unstable).

## Analysis

### Option A: Add `Span: Sequence.Borrowing.Protocol` conformance

Add a retroactive conformance in `Sequence Primitives Standard Library Integration/`:

```swift
extension Swift.Span: Sequence.Borrowing.`Protocol` where Element: Copyable {
    @_lifetime(borrow self)
    public borrowing func makeIterator() -> Swift.Span<Element>.Iterator {
        .init(span: self)
    }
}
```

Add `.collect()` to `Sequence.Borrowing.Protocol`:

```swift
extension Sequence.Borrowing.`Protocol` where Element: Copyable {
    public borrowing func collect() -> [Element] {
        var iterator = makeIterator()
        var result: [Element] = []
        while let element = iterator.next() {
            result.append(element)
        }
        return result
    }
}
```

**Call site**: `let bytes: [UInt8] = span.collect()`

**Pros**:
- Principled — Span participates in the protocol hierarchy
- All `Sequence.Borrowing.Protocol` conformers gain `.collect()`
- Aligns with stdlib's `_BorrowingSequence` direction
- Zero new types or abstractions

**Cons**:
- Retroactive conformance on stdlib type (compiler warning: `@retroactive`)
- `.collect()` naming — terminal operation on borrowing protocol

### Option B: Standalone extensions without protocol conformance

Add direct methods on Span:

```swift
extension Swift.Span where Element: Copyable {
    public func toArray() -> [Element] { ... }
}
```

**Pros**: Simple, no protocol machinery.
**Cons**: Unprincipled, doesn't compose with lazy pipelines.

### Comparison

| Criterion | Option A (conformance) | Option B (standalone) |
|-----------|----------------------|---------------------|
| Language-level integration | Full protocol hierarchy | Ad-hoc |
| Composability | `.map { }.filter { }.collect()` | None |
| Alignment with stdlib direction | `_BorrowingSequence` convergence | Divergence |
| Retroactive conformance warning | `@retroactive` needed | None |
| Implementation complexity | ~10 lines | ~5 lines |

**Recommendation**: Option A. The retroactive conformance warning is acceptable — it's the same pattern used throughout the ecosystem for stdlib extensions.

### Span → String

The stdlib provides a **two-step designed API path**:

```
Span<UInt8> → UTF8Span (validates/assumes) → String (copies)
```

1. `UTF8Span(validating: span)` — validates UTF-8, `throws(UTF8.ValidationError)`
2. `UTF8Span(unchecked: span)` — `@unsafe`, skips validation
3. `String(copying: utf8Span)` — copies validated bytes into owned String

**This IS the canonical stdlib path.** `UTF8Span` is `Swift.UTF8Span` (stdlib), not a custom type. The two-step makes validation explicit — this is intentional API design:

- The validation step prevents creating Strings from invalid UTF-8
- The `copying:` label makes the allocation explicit
- The unsafe variant is available for known-valid data

**For our ecosystem**:

| Context | Syntax |
|---------|--------|
| Known-valid UTF-8 (env vars, POSIX paths) | `String(copying: unsafe UTF8Span(unchecked: span))` |
| Untrusted input | `String(copying: try UTF8Span(validating: span))` |

No custom wrapper needed. The stdlib chain is the answer.

### Span → Array via `.collect()`

With Option A, the call sites become:

```swift
// Before:
let bytes: [UInt8] = span.withUnsafeBufferPointer { Array($0) }

// After:
let bytes: [UInt8] = span.collect()

// Or with pipeline:
let processed = span.map { $0 + 1 }.filter { $0 > 5 }.collect()
```

### Syscall boundary patterns (keep as-is)

`span.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }` — these are legitimate. The OS syscall needs a raw pointer. The closure boundary is the correct design at the syscall edge. These should NOT be changed.

## Outcome

**Status**: IN_PROGRESS

### Recommended Actions

1. **Add `Span: Sequence.Borrowing.Protocol`** conformance in swift-sequence-primitives
2. **Add `.collect()` to `Sequence.Borrowing.Protocol`** (borrowing variant for Copyable elements)
3. **Use `String(copying: UTF8Span(...))` for Span → String** — stdlib designed path, no wrapper
4. **Keep `withUnsafeBytes` at syscall boundaries** — correct design for raw pointer handoff
5. **Fix Category 1 sites** using `.collect()` for Array and `UTF8Span` chain for String
6. **Fix Category 3** (1 missed `withUnsafePointer` site)

### Open Questions

- Should `Sequence.Borrowing.Protocol` also gain `.reduce`, `.forEach`, `.contains` terminals?
- Should the `@retroactive` conformance be documented as a known pattern?
- When stdlib stabilizes `BorrowingSequence` (6.3+), should we migrate from our protocol?

## References

- `swiftlang/swift/stdlib/public/core/Span/Span.swift` — Span type definition
- `swiftlang/swift/stdlib/public/core/BorrowingSequence.swift` — `_BorrowingSequence` protocol
- `swiftlang/swift/stdlib/public/core/UTF8Span.swift` — UTF8Span + String(copying:)
- `swift-sequence-primitives/.../Sequence.Borrowing.Protocol.swift` — Our parallel protocol
- `swift-sequence-primitives/.../Swift.Span.Iterator.swift` — Span.Iterator implementation
- `swift-primitives/Research/view-vs-span-borrowed-access-types.md` — View vs Span distinction
- `swift-primitives/Research/iterator-span-buffer-elimination.md` — Zero-allocation iteration
