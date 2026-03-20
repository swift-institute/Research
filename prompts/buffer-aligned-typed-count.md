# Buffer.Aligned: Type `count` as `Index<UInt8>.Count`

## Goal

Change `Buffer.Aligned.count` from bare `Cardinal` to `Index<UInt8>.Count` (= `Tagged<UInt8, Cardinal>`). This enables consumers to use `.retag(Element.self)` instead of constructing from scratch, keeping arithmetic in the typed domain.

## Current state

`Buffer.Aligned` is defined in:
```
swift-buffer-primitives/Sources/Buffer Primitives Core/Buffer.Aligned.swift
```

```swift
public struct Aligned: ~Copyable, @unchecked Sendable {
    var bytePointer: UnsafeMutablePointer<UInt8>
    public let count: Cardinal              // ← bare Cardinal
    public let alignment: Memory.Alignment
}
```

`Buffer.Aligned` is always `Element == UInt8` (its storage is byte-oriented). So `count` semantically IS a byte count — an `Index<UInt8>.Count`.

## What to change

### 1. Change the stored property type

```swift
// Before:
public let count: Cardinal

// After:
public let count: Index<UInt8>.Count
```

This requires `import Index_Primitives` (already available — `Buffer Primitives Core` depends on `Index Primitives`).

### 2. Update the init (Buffer.Aligned.swift:89)

```swift
// Before:
public init(byteCount: Cardinal, ...) {
    self.count = .zero       // line 98
    self.count = byteCount   // line 112
}

// After:
public init(byteCount: Cardinal, ...) {
    self.count = .zero                       // .zero works on Tagged<UInt8, Cardinal>
    self.count = Index<UInt8>.Count(byteCount)  // wrap bare Cardinal
}
```

Or accept `Index<UInt8>.Count` as the parameter type directly and update callers.

### 3. Update internal consumers (Buffer.Aligned.swift)

All internal uses of `count` are stdlib boundary conversions (`Int(bitPattern: count)`). These continue to work because `Int(bitPattern: Tagged<Tag, Cardinal>)` exists in cardinal-primitives.

Verify these still compile (lines 147, 162, 228, 240, 287, 298):
```swift
// Before (works with Cardinal):
Int(bitPattern: count)

// After (works with Tagged<UInt8, Cardinal> via Int(bitPattern: Tagged<Tag, Cardinal>)):
Int(bitPattern: count)  // same call, different overload resolves — verify
```

### 4. Update Buffer.Unbounded (Buffer.Unbounded.swift:101, 107)

```swift
// Before (current, after Pass 3 cleanup):
public var count: Index<Element>.Count {
    Index<Element>.Count(_storage.count)    // Cardinal → Tagged<Element, Cardinal>
}

// After:
public var count: Index<Element>.Count {
    _storage.count.retag(Element.self)       // Tagged<UInt8, Cardinal> → Tagged<Element, Cardinal>
}
```

This is the payoff: `.retag(Element.self)` is zero-cost and keeps the full chain typed.

### 5. Check cross-package consumers

`Buffer.Aligned` is `public`. Grep `swift-primitives` for all access to `.count` on `Aligned` instances:

```bash
grep -rn 'aligned\.count\|\.count' swift-buffer-primitives/Sources/Buffer\ Primitives\ Core/
```

Also check `swift-standards` and `swift-foundations` for any cross-repo usage:
```bash
grep -rn 'Buffer\.Aligned' /Users/coen/Developer/swift-standards/
grep -rn 'Buffer\.Aligned' /Users/coen/Developer/swift-foundations/
```

## Build & test

```bash
cd /Users/coen/Developer/swift-primitives/swift-buffer-primitives
swift build && swift test
```

Buffer-primitives has 391 tests across 71 suites — comprehensive coverage.

## Constraints

- `Buffer.Aligned` is always `Element == UInt8` — the tag is always `UInt8`
- The `byteCount` init parameter could stay `Cardinal` (converting at the boundary) or become `Index<UInt8>.Count` (pushing the typed boundary outward) — use your judgement
- `Int(bitPattern:)` calls at stdlib boundaries are justified per [CONV-001]
- No Foundation imports

## Commit format

```
[audit] Type Buffer.Aligned.count as Index<UInt8>.Count — swift-buffer-primitives
```
