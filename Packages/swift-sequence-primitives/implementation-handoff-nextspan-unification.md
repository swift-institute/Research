# Handoff: Unify Iterator Protocols via nextSpan
<!--
---
version: 1.0.0
last_updated: 2026-03-16
status: RECOMMENDATION
---
-->

## Goal

Merge `Sequence.Iterator.Borrowing.Protocol` into `Sequence.Iterator.Protocol`, making `nextSpan(maximumCount:) -> Span<Element>` the sole protocol requirement. `next()` and `skip(by:)` become derived default extensions. This is steps 3–10 of the implementation path in `Research/sequence-iterator-protocol-architecture.md` §6.3.

## Why

We have two parallel iterator protocols today — one returning `Element?` via `next()`, one returning `Span<Element>` via `nextSpan()`. Research and experiments proved that `nextSpan` is a universal primitive that works for ALL storage types (contiguous, scattered, linked, slab, ring, computed, tree). The two protocols can be unified into one with `nextSpan` as the single requirement and `next()` derived from it. This eliminates protocol duplication while preserving all existing functionality.

## Context You Need

Read these files in order of importance:

1. `Research/sequence-iterator-protocol-architecture.md` — §6.3 "nextSpan as Universal Primitive" has the full rationale, performance findings, and implementation path
2. `Experiments/nextspan-universal-primitive/Sources/main.swift` — the validated protocol shape (lines 28-41 are the target design)
3. `Experiments/nextspan-performance-overhead/Sources/main.swift` — performance findings (Span init has 2.5-3.5x overhead in derived `next()`, mitigated by conformer overrides)

## What Exists Today

### Two Iterator Protocols

**`Sequence.Iterator.Protocol`** (`Sources/Sequence Primitives Core/Sequence.Iterator.Protocol.swift`):
```swift
extension Sequence.Iterator {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        @_lifetime(self: immortal)
        mutating func next() -> Element?
    }
}
```

**`Sequence.Iterator.Borrowing.Protocol`** (`Sources/Sequence Primitives Core/Sequence.Iterator.Borrowing.Protocol.swift`):
```swift
extension Sequence.Iterator.Borrowing {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        @_lifetime(&self)
        mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element>
        @_lifetime(self: immortal)
        mutating func skip(by maximumCount: Cardinal) -> Cardinal
    }
}
// + default skip(by:) implementation
```

### Two Sequence Protocols

**`Sequence.Protocol`** (`Sources/Sequence Primitives Core/Sequence.Protocol.swift`):
```swift
extension Sequence {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype Iterator: Sequence.Iterator.`Protocol` & ~Copyable & ~Escapable
            where Iterator.Element == Element
        @_lifetime(copy self)
        consuming func makeIterator() -> Iterator
    }
}
```

**`Sequence.Borrowing.Protocol`** (`Sources/Sequence Primitives Core/Sequence.Borrowing.Protocol.swift`):
```swift
extension Sequence.Borrowing {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype Iterator: Sequence.Iterator.Borrowing.`Protocol`
            where Iterator.Element == Element
        @_lifetime(borrow self)
        borrowing func makeIterator() -> Iterator
    }
}
```

### Namespace Enums

- `Sequence.Iterator` — enum in `Sources/Sequence Primitives Core/Sequence.Iterator.swift`
- `Sequence.Iterator.Borrowing` — enum in `Sources/Sequence Primitives Core/Sequence.Iterator.Borrowing.swift`

## Target Design

After unification, `Sequence.Iterator.Protocol` becomes:

```swift
extension Sequence.Iterator {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable

        /// The sole protocol requirement. Returns up to maximumCount elements as a Span.
        /// Returns empty span when exhausted.
        @_lifetime(&self)
        mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element>
    }
}
```

With default extensions:

```swift
// Derived next() for Copyable elements
extension Sequence.Iterator.`Protocol` where Self: ~Copyable & ~Escapable, Element: Copyable {
    @inlinable
    @_lifetime(self: immortal)
    public mutating func next() -> Element? {
        let span = nextSpan(maximumCount: Cardinal(1))
        return span.isEmpty ? nil : span[0]
    }
}

// Derived skip(by:)
extension Sequence.Iterator.`Protocol` where Self: ~Copyable & ~Escapable {
    @inlinable
    @_lifetime(self: immortal)
    public mutating func skip(by maximumCount: Cardinal) -> Cardinal {
        var remaining = maximumCount
        while remaining > .zero {
            let span = nextSpan(maximumCount: remaining)
            if span.isEmpty { break }
            remaining = remaining.subtract.saturating(Cardinal(UInt(span.count)))
        }
        return maximumCount.subtract.saturating(remaining)
    }
}
```

**`Sequence.Borrowing.Protocol`** updates its associated type constraint:

```swift
// Iterator constraint changes from:
associatedtype Iterator: Sequence.Iterator.Borrowing.`Protocol`
// to:
associatedtype Iterator: Sequence.Iterator.`Protocol` & ~Copyable & ~Escapable
```

**`Sequence.Protocol`** — no change needed (already references `Sequence.Iterator.Protocol`).

## Critical Performance Constraint

The derived `next()` (via `nextSpan(maximumCount: 1)`) has 2.5-3.5x overhead due to Span's `_unsafeStart` initializer chain (alignment checks, mark_dependence, COW tracking). **This is a Span-specific issue, NOT a ~Escapable issue** — custom ~Escapable structs reach parity.

**Mitigation**: All downstream buffer conformers (Buffer.Linear, Buffer.Ring, etc.) already have direct `next()` implementations. These MUST be preserved as overrides of the default. They are NOT protocol requirements — they are extensions that shadow the default. When the Span initializer improves upstream, these overrides can be deleted without API change.

## Step-by-Step Changes

### Step 3: Merge Borrowing.Protocol requirements into Iterator.Protocol

**File**: `Sources/Sequence Primitives Core/Sequence.Iterator.Protocol.swift`

- Replace `next()` requirement with `nextSpan(maximumCount:)` requirement
- Change `@_lifetime(self: immortal)` to `@_lifetime(&self)` on the requirement
- Update the doc comments to reflect the new design

### Step 4: Add `next()` default extension

**File**: `Sources/Sequence Primitives Core/Sequence.Iterator.Protocol.swift` (same file, below the protocol)

- Add default `next()` for `Element: Copyable` (see Target Design above)
- This uses `Cardinal(1)` not bare `1` — the parameter type is `Cardinal` from Index_Primitives

### Step 5: Add `skip(by:)` default extension

**File**: `Sources/Sequence Primitives Core/Sequence.Iterator.Protocol.swift` (same file)

- Move the default `skip(by:)` from `Sequence.Iterator.Borrowing.Protocol.swift` to here
- Adapt the constraint from `Sequence.Iterator.Borrowing.Protocol` to `Sequence.Iterator.Protocol`

### Step 6: Update both sequence protocols

**File**: `Sources/Sequence Primitives Core/Sequence.Borrowing.Protocol.swift`
- Change `Iterator: Sequence.Iterator.Borrowing.Protocol` to `Iterator: Sequence.Iterator.Protocol & ~Copyable & ~Escapable`

**File**: `Sources/Sequence Primitives Core/Sequence.Protocol.swift`
- No change needed (already references `Sequence.Iterator.Protocol`)

### Step 7: Update all downstream iterator conformers

These types conform to `Sequence.Iterator.Protocol` via `next()` today. After the protocol change, their `next()` will no longer satisfy the protocol requirement — they need `nextSpan()`.

**Lazy operator iterators** (in `Sources/Sequence Primitives Core/`):
These wrap a base iterator and call `_base.next()`. They are element-transforming pipelines and do NOT have direct pointer access. They CANNOT efficiently implement `nextSpan` natively — they would need a heap-allocated buffer (computed element pattern from the experiment).

**THIS IS THE KEY ARCHITECTURAL DECISION**: These lazy iterator types should get `nextSpan` via a default extension that uses `next()`, which is the INVERSE of the default for contiguous types. The pattern:

```swift
// For lazy/computed iterators: nextSpan derived from next()
// (stored element buffer + next() as the native primitive)
```

BUT WAIT — the protocol requires `nextSpan` as the sole requirement. Lazy iterators don't have stored pointers to back a Span. This is the "computed elements with heap buffer" pattern from the experiment (Variant 6). Each lazy iterator would need a heap-allocated buffer to write the computed element into, then return a Span pointing to that buffer. This is the `ComputedIterator` pattern.

**HOWEVER** — this adds heap allocation to every lazy iterator. That's a significant cost for `map`, `filter`, `compactMap`, `drop`, `prefix` pipelines. The research document notes this as a known concern.

**Recommended approach**: The lazy iterators should continue to provide `next()` directly (as they do today) and gain a `nextSpan` that uses a one-element heap buffer. But since `next()` is no longer a protocol requirement, it's just a method. The Property.View algorithms will continue to call `next()` on these iterators because the `Sequence.Protocol` algorithms use `makeIterator()` + `next()`.

**ACTUALLY — re-read the architecture carefully**: `Sequence.Protocol` conformers (the consuming path) work via `makeIterator() -> Iterator` then `iterator.next()`. The `next()` default extension calls `nextSpan(1)` then extracts. For lazy iterators, we need `nextSpan` to work, but the FAST path is `next()`. So: lazy iterators implement BOTH `nextSpan` (required) AND `next()` (override of default). The `next()` override is their efficient native implementation. The `nextSpan` is the slow path that allocates a buffer.

Wait — that means every lazy iterator needs a heap buffer field. That's invasive. Let me reconsider.

**ALTERNATIVE**: Maybe `next()` should remain alongside `nextSpan` as a protocol requirement with a two-way default relationship:
- Default `next()` from `nextSpan` (for contiguous types)
- Default `nextSpan` from `next()` (for computed types)
- Conformers must implement at least one

This is the "two customization points" pattern. But Swift protocols don't enforce "implement at least one" — you'd get infinite recursion if neither is overridden. The experiment only validated the one-requirement design.

**PRAGMATIC RECOMMENDATION**: Given the performance findings, the safest path is:

1. Make `nextSpan` the sole protocol requirement
2. Provide a default `next()` that calls `nextSpan(1)`
3. **Contiguous iterators** (Buffer.Linear, Buffer.Ring, Span.Iterator.Batch): already have `nextSpan`, keep `next()` as performance override
4. **Lazy iterators** (Map, Filter, CompactMap, Drop.First, Drop.While, Prefix.First, Prefix.While): need a stored `UnsafeMutablePointer<Element>` buffer field + `nextSpan` that writes into it. Keep existing `next()` as override.
5. **Span.Iterator**: element-at-a-time only, needs buffer or conversion

This is the most technically correct approach but IS invasive for the lazy types. The alternative is to keep `next()` as a protocol requirement too (both `next` and `nextSpan`), which is what the buffer conformers already satisfy.

**I recommend you DISCUSS this decision with the user before implementing.** The research document's step 3 says "merge", but the lazy iterator heap-buffer cost was not fully analyzed. Present both options:
- **Option A**: `nextSpan` sole requirement + heap buffer in lazy iterators (pure design, extra allocation)
- **Option B**: Both `next()` and `nextSpan()` as requirements with two-way defaults (pragmatic, risk of infinite recursion)
- **Option C**: `nextSpan` sole requirement, but lazy iterators DON'T conform and remain on a separate protocol (breaks the unification goal)

---

Here are the specific conformers grouped by category:

**Category 1: Contiguous buffer iterators** (already have both `next()` and `nextSpan()`):

| Type | File (in swift-buffer-primitives) |
|------|------|
| `Buffer.Linear.Iterator` | `Sources/Buffer Linear Primitives/Buffer.Linear+Span.swift` |
| `Buffer.Linear.Bounded.Iterator` | same file |
| `Buffer.Linear.Small.Iterator` | `Sources/Buffer Linear Small Primitives/Buffer.Linear.Small+Span.swift` |
| `Buffer.Ring.Iterator` | `Sources/Buffer Ring Primitives/Buffer.Ring+Span.swift` |
| `Buffer.Ring.Bounded.Iterator` | same file |
| `Buffer.Ring.Small.Iterator` | `Sources/Buffer Ring Inline Primitives/Buffer.Ring.Small+Span.swift` |

These currently declare: `Sequence.Iterator.Protocol, Sequence.Iterator.Borrowing.Protocol, IteratorProtocol`
After: change `Sequence.Iterator.Borrowing.Protocol` → removed (requirements absorbed into `Sequence.Iterator.Protocol`), keep `IteratorProtocol`.

**Category 2: Span iterators** (in swift-sequence-primitives):

| Type | File |
|------|------|
| `Swift.Span.Iterator` | `Sources/Sequence Primitives Standard Library Integration/Swift.Span.Iterator.swift` |
| `Swift.Span.Iterator.Batch` | `Sources/Sequence Primitives Standard Library Integration/Swift.Span.Iterator.Batch.swift` |

`Span.Iterator` currently has `next()` only — no protocol conformance, no `nextSpan`. It would need `nextSpan` added.
`Span.Iterator.Batch` currently conforms to `Sequence.Iterator.Borrowing.Protocol` only. After unification it conforms to `Sequence.Iterator.Protocol`.

**Category 3: Lazy operator iterators** (in swift-sequence-primitives `Sources/Sequence Primitives Core/`):

| Type | File |
|------|------|
| `Sequence.Map.Iterator` | `Sequence.Map.Iterator.swift` |
| `Sequence.Filter.Iterator` | `Sequence.Filter.Iterator.swift` |
| `Sequence.CompactMap.Iterator` | `Sequence.CompactMap.Iterator.swift` |
| `Sequence.Drop.First.Iterator` | `Sequence.Drop.First.Iterator.swift` |
| `Sequence.Drop.While.Iterator` | `Sequence.Drop.While.Iterator.swift` |
| `Sequence.Prefix.First.Iterator` | `Sequence.Prefix.First.Iterator.swift` |
| `Sequence.Prefix.While.Iterator` | `Sequence.Prefix.While.Iterator.swift` |

These have `next()` only. Need `nextSpan` added (computed element pattern with buffer).

### Step 8: Update Property.View algorithms to use nextSpan

The Property.View algorithm files iterate via `makeIterator()` + `next()`. They continue to work because `next()` is provided via default extension (or override). No change strictly needed — but if you want them to use `nextSpan` for batch efficiency on contiguous types, that's a separate enhancement.

**Files** (in `Sources/Sequence Primitives Core/`):
- `Sequence.ForEach+Property.View.swift`
- `Sequence.Contains+Property.View.swift`
- `Sequence.First+Property.View.swift`
- `Sequence.Reduce+Property.View.swift`
- `Sequence.Satisfies+Property.View.swift`
- `Sequence.Count+Property.View.swift`
- `Sequence.Drain+Property.View.swift`
- `Sequence.Span+Property.View.swift` — already uses `nextSpan`, constraint changes from `Sequence.Borrowing.Protocol` to `Sequence.Protocol` (or stays as-is if `Sequence.Borrowing.Protocol` is kept)

### Step 9: Delete Sequence.Iterator.Borrowing.Protocol.swift

After all references are updated. The namespace enum `Sequence.Iterator.Borrowing` in `Sequence.Iterator.Borrowing.swift` can also be deleted (or kept if referenced elsewhere).

### Step 10: Update documentation

- Update doc comments in all modified files
- Update `Sequence.swift` namespace doc
- Update `Sequence.Iterator.swift` namespace doc
- Update `Sequence.Borrowing.swift` namespace doc
- Update research document §6.3 implementation path (mark steps DONE)

## Package Structure

```
swift-sequence-primitives/
├── Package.swift                    (Swift 6.2, platforms v26)
├── Sources/
│   ├── Sequence Primitives Core/    (main module — all protocols, algorithms, lazy types)
│   ├── Sequence Primitives Standard Library Integration/  (Span iterator, stdlib bridging)
│   └── Sequence Primitives/         (umbrella re-export)
├── Tests/
├── Research/
└── Experiments/
```

Dependencies: `swift-property-primitives` (Property.View), `swift-index-primitives` (Cardinal, Ordinal, Index<T>)

The `Cardinal` type from `Index_Primitives` is used for `nextSpan(maximumCount:)` parameter and `skip(by:)`. It wraps `UInt` with saturating arithmetic (`.subtract.saturating()`, `.advance.saturating(by:)`).

## Build and Test

```bash
cd /Users/coen/Developer/swift-primitives/swift-sequence-primitives
swift build
swift test
```

For buffer-primitives (downstream, after sequence-primitives compiles):
```bash
cd /Users/coen/Developer/swift-primitives/swift-buffer-primitives
swift build
swift test
```

## Key Constraints

- No Foundation imports
- `Nest.Name` naming (no compound identifiers)
- One type per file
- All `@inlinable` on public API
- `unsafe` keyword on all unsafe operations (strict memory safety)
- `@_lifetime(&self)` on `nextSpan` — the returned Span borrows from the iterator
- `@_lifetime(self: immortal)` on `next()` and `skip(by:)` — they return owned/scalar values
- Feature flags already enabled: `Lifetimes`, `SuppressedAssociatedTypes`, `SuppressedAssociatedTypesWithDefaults`, `BuiltinModule`, `strictMemorySafety()`
