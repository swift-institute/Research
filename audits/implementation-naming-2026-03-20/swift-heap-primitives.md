# swift-heap-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (Opus 4.6)
**Skills**: /implementation, /naming
**Package**: `/Users/coen/Developer/swift-primitives/swift-heap-primitives/`
**Scope**: All 42 `.swift` files across 9 modules

## Summary Table

| ID | Severity | Rule | Location | Description |
|----|----------|------|----------|-------------|
| HEAP-001 | MEDIUM | [API-IMPL-005] | `Heap.swift` | Multiple types in one file (Heap, Order, Error, Fixed, Push, MinMax, Binary) |
| HEAP-002 | MEDIUM | [API-NAME-002] | `Heap ~Copyable.swift:48` | `appendWithoutHeapify` is a compound method name |
| HEAP-003 | MEDIUM | [API-NAME-002] | `Heap ~Copyable.swift:62` | `removePriority` is a compound method name |
| HEAP-004 | MEDIUM | [API-NAME-002] | `Heap ~Copyable.swift:86` | `bubbleUp` is a compound method name |
| HEAP-005 | MEDIUM | [API-NAME-002] | `Heap ~Copyable.swift:121` | `trickleDown` is a compound method name |
| HEAP-006 | MEDIUM | [API-NAME-002] | `Heap Copyable.swift:75` | `replacePriority` is a compound method name |
| HEAP-007 | LOW | [API-NAME-002] | `Heap.MinMax ~Copyable.swift:90,105` | `removeMin`/`removeMax` are compound method names |
| HEAP-008 | LOW | [API-NAME-002] | `Heap.MinMax ~Copyable.swift:179,236` | `trickleDownMin`/`trickleDownMax` are compound method names |
| HEAP-009 | LOW | [API-NAME-002] | `Heap.MinMax ~Copyable.swift:60` | `isMinLevel` is a compound method name |
| HEAP-010 | LOW | [API-NAME-002] | `Heap.Fixed ~Copyable.swift:307` | `makeUnique` is a compound method name |
| HEAP-011 | LOW | [API-NAME-002] | `Heap.Navigate.swift:86` | `lastNonLeaf` is a compound property name |
| HEAP-012 | LOW | [API-NAME-002] | `Heap.Navigate.swift:94,100` | `leftChildOfRoot`/`rightChildOfRoot` are compound property names |
| HEAP-013 | LOW | [API-NAME-002] | `Heap.Navigate.swift:109` | `isValid` is a compound method name |
| HEAP-014 | INFO | [IMPL-010] | `Heap.Navigate.swift:59,71` | `.rawValue` access in Navigate boundary code -- correctly confined |
| HEAP-015 | INFO | [IMPL-010] | `Heap.Navigate.swift:87` | Double `.rawValue.rawValue` in `lastNonLeaf` -- correctly confined |
| HEAP-016 | OK | [PATTERN-017] | Various | `.rawValue` usage confined to Navigate (3 occurrences) -- compliant |
| HEAP-017 | OK | [IMPL-010] | Various | `Int(bitPattern:)` in `underestimatedCount` (5x) -- boundary overload for Swift.Sequence |
| HEAP-018 | MEDIUM | [IMPL-010] | `Heap.MinMax ~Copyable.swift:61` | `Int(bitPattern: index)` in `isMinLevel` -- algorithmic, not boundary |
| HEAP-019 | MEDIUM | [IMPL-010] | `Heap.MinMax ~Copyable.swift:298` | `Int(bitPattern: _buffer.count)` in `heapify` -- algorithmic, not boundary |
| HEAP-020 | LOW | [PATTERN-021] | `Heap.Navigate.swift:60,74-75,89` | `__unchecked` Index construction in Navigate (6x) -- boundary code, acceptable |
| HEAP-021 | LOW | [PATTERN-021] | `Heap.swift:134`, `Heap.MinMax.Fixed ~Copyable.swift:30` | `__unchecked` Count construction in init -- boundary code, acceptable |
| HEAP-022 | LOW | [PATTERN-021] | `Heap.MinMax ~Copyable.swift:311` | `__unchecked` Index in heapify loop -- algorithmic context |
| HEAP-023 | MEDIUM | [API-IMPL-005] | `Heap.MinMax ~Copyable.swift:66-72` | `Int._binaryLogarithm()` extension defined in MinMax file |
| HEAP-024 | MEDIUM | [IMPL-INTENT] | `Heap.MinMax ~Copyable.swift:296-321` | MinMax `heapify()` uses raw Int arithmetic extensively |
| HEAP-025 | LOW | [IMPL-033] | `Heap.MinMax ~Copyable.swift:202,259` | `for _ in 0..<4` magic number loop for grandchildren iteration |
| HEAP-026 | LOW | [API-NAME-002] | Various Copyable files | `withPriority`, `withMin`, `withMax` are compound method names |
| HEAP-027 | OK | [API-NAME-001] | All types | Nest.Name pattern correctly used throughout (Heap.Static, Heap.Fixed, etc.) |
| HEAP-028 | OK | [IMPL-020] | Various | Property.View pattern correctly used for `remove`, `min`, `max`, `peek`, `forEach`, etc. |
| HEAP-029 | INFO | [API-NAME-002] | Various | `removeAll`, `makeIterator`, `underestimatedCount`, `nextSpan` -- protocol-mandated names, exempt |
| HEAP-030 | LOW | [API-IMPL-005] | `Heap.MinMax.swift` | Multiple nested type aliases and tag enums in one file (Position, Error, Property, Remove) |
| HEAP-031 | INFO | [IMPL-INTENT] | `Heap.MinMax ~Copyable.swift:112` | `_buffer.count == .one + .one` -- readable count==2 check using typed arithmetic |
| HEAP-032 | OK | [API-ERR-001] | All throwing functions | All uses typed throws consistently |

## Detailed Findings

### HEAP-001: Multiple types in Heap.swift [API-IMPL-005] -- MEDIUM

**File**: `/Users/coen/Developer/swift-primitives/swift-heap-primitives/Sources/Heap Primitives Core/Heap.swift`

`Heap.swift` declares the primary `Heap` struct but also embeds full type declarations for:
- `Heap.Order` (enum, lines 67-72)
- `Heap.Error` (enum, lines 77-80)
- `Heap.Fixed` (struct, lines 103-138, including its own `Error` enum)
- `Heap.Push` + `Heap.Push.Outcome` (enum, lines 143-151)
- `Heap.MinMax` (struct, lines 162-171)
- `Heap.Ordering` (typealias, line 179)
- `Heap.Binary` (typealias, line 187)

Per [API-IMPL-005], each type should have its own file. The `Fixed` struct with its full `Error` enum and init is especially heavy. However, `MinMax` is declared here due to a documented `~Copyable` constraint propagation requirement, so that specific case has a compiler-mandated justification.

**Recommendation**: Extract `Heap.Order`, `Heap.Error`, `Heap.Push`/`Heap.Push.Outcome`, and `Heap.Fixed` (struct body only -- init and stored properties needed for cross-module constraint propagation) into separate files. Keep `Heap.MinMax` declaration in `Heap.swift` per the documented compiler constraint.

---

### HEAP-002 through HEAP-006: Compound package-internal method names [API-NAME-002] -- MEDIUM

These are `package` visibility (internal to the superrepo), so they don't pollute the public API surface. However, [API-NAME-002] applies to all identifiers.

| Finding | Method | File:Line |
|---------|--------|-----------|
| HEAP-002 | `appendWithoutHeapify` | `Heap ~Copyable.swift:48` |
| HEAP-003 | `removePriority` | `Heap ~Copyable.swift:62` (also Static:61, Fixed:66, Small:103) |
| HEAP-004 | `bubbleUp` | `Heap ~Copyable.swift:86` (also Static:85, Fixed:91, Small:131, MinMax:138) |
| HEAP-005 | `trickleDown` | `Heap ~Copyable.swift:121` (also Static:117, Fixed:123, Small:166) |
| HEAP-006 | `replacePriority` | `Heap Copyable.swift:75` |

These are duplicated across 4-5 variant types due to the lack of a shared buffer protocol (documented in comments). The compound names are algorithmically conventional (heap terminology), but they violate [API-NAME-002].

**Possible nested accessor alternatives**:
- `appendWithoutHeapify` -> internal detail, could be `_append(skippingHeapify:)` or kept as-is since it's package-internal
- `removePriority` -> already surfaced publicly as `take` and `pop`, so the package method is just an implementation detail
- `bubbleUp`/`trickleDown` -> these are standard heap algorithm names; renaming could reduce readability. A `sift.up`/`sift.down` accessor pattern would be the Nest.Name alternative.

**Recommendation**: These are package-internal and use standard algorithm terminology. LOW priority to refactor unless a shared buffer protocol emerges.

---

### HEAP-007 through HEAP-009: MinMax compound internal names [API-NAME-002] -- LOW

| Finding | Method | File:Line |
|---------|--------|-----------|
| HEAP-007 | `removeMin`/`removeMax` | `Heap.MinMax ~Copyable.swift:90,105` |
| HEAP-008 | `trickleDownMin`/`trickleDownMax` | `Heap.MinMax ~Copyable.swift:179,236` |
| HEAP-009 | `isMinLevel` | `Heap.MinMax ~Copyable.swift:60` |

All package-internal. The public API correctly uses `heap.min.pop()` / `heap.max.pop()` via Property.View, which is the correct nested accessor pattern.

---

### HEAP-010 through HEAP-013: Navigate compound names [API-NAME-002] -- LOW

| Finding | Identifier | File:Line |
|---------|-----------|-----------|
| HEAP-010 | `makeUnique()` | `Heap.Fixed ~Copyable.swift:307`, `Heap.MinMax Copyable.swift:131` |
| HEAP-011 | `lastNonLeaf` | `Heap.Navigate.swift:86` |
| HEAP-012 | `leftChildOfRoot`/`rightChildOfRoot` | `Heap.Navigate.swift:94,100` |
| HEAP-013 | `isValid(_:)` | `Heap.Navigate.swift:109` |

All package-internal except `isValid` which is public. `makeUnique` mirrors stdlib's `isKnownUniquelyReferenced` pattern. `isValid` is a simple predicate.

**Recommendation**: `isValid` could become `navigate.contains(index)` or stay as-is (simple predicate). Low priority.

---

### HEAP-018 & HEAP-019: Int(bitPattern:) in algorithmic code [IMPL-010] -- MEDIUM

**File**: `/Users/coen/Developer/swift-primitives/swift-heap-primitives/Sources/Heap MinMax Primitives/Heap.MinMax ~Copyable.swift`

Line 61:
```swift
let raw = Int(bitPattern: index)
return (raw &+ 1)._binaryLogarithm() & 0b1 == 0
```

Line 298:
```swift
let rawCount = Int(bitPattern: _buffer.count)
```

[IMPL-010] restricts `Int(bitPattern:)` to boundary overloads. The `underestimatedCount` usages (HEAP-017) are correct boundary overloads for the `Swift.Sequence` protocol requirement. But these two are mid-algorithm escapes from the typed index/count system.

The `isMinLevel` method has a comment citing `[IMPL-001]` (binary logarithm requires raw arithmetic), and the `heapify` method cites it too. This is defensible -- floor-log2 and power-of-2 tree math genuinely require raw integers. However, the current code escapes to raw `Int` and stays there for the entire heapify loop body, which is broader than necessary.

**Recommendation**: Document these as principled boundary escapes with a `// BOUNDARY:` comment (like the existing `[IMPL-001]` citation). Consider whether a `Heap.Index.level` computed property could encapsulate the log2 escape for `isMinLevel`.

---

### HEAP-023: Int._binaryLogarithm() in wrong file [API-IMPL-005] -- MEDIUM

**File**: `/Users/coen/Developer/swift-primitives/swift-heap-primitives/Sources/Heap MinMax Primitives/Heap.MinMax ~Copyable.swift:66-72`

```swift
extension Int {
    @usableFromInline
    package func _binaryLogarithm() -> Int {
        precondition(self > 0)
        return Int.bitWidth - 1 - self.leadingZeroBitCount
    }
}
```

An `Int` extension is defined inside the `Heap.MinMax ~Copyable.swift` file. Per [API-IMPL-005], this should either:
1. Be in its own file (e.g., `Int+BinaryLogarithm.swift`)
2. Be a static method on `Heap.Navigate` or `Heap.MinMax` instead of extending `Int`

**Recommendation**: Move to a dedicated file or make it a private helper on the MinMax type.

---

### HEAP-024: MinMax heapify uses extensive raw Int arithmetic [IMPL-INTENT] -- MEDIUM

**File**: `/Users/coen/Developer/swift-primitives/swift-heap-primitives/Sources/Heap MinMax Primitives/Heap.MinMax ~Copyable.swift:296-321`

```swift
let rawCount = Int(bitPattern: _buffer.count)
guard rawCount > 1 else { return }
let limit = rawCount / 2
var level = limit._binaryLogarithm()
while level >= 0 {
    let isMin = level & 0b1 == 0
    let firstPos = UInt((1 << level) &- 1)
    let lastPos = UInt(Swift.min((1 << (level &+ 1)) &- 2, limit - 1))
    var pos = firstPos
    while pos <= lastPos {
        let index = Heap.Index(__unchecked: (), Ordinal(pos))
        ...
        pos &+= 1
    }
    level -= 1
}
```

This is 15+ lines of raw `Int`/`UInt` arithmetic (bit shifts, overflow operators, division). While the `[IMPL-001]` comment justifies the escape, the code reads as mechanism-heavy. The single-ended `heapify` (Floyd's algorithm) in `Heap ~Copyable.swift:172-179` is much more intent-driven by contrast, using typed indices and `idx.predecessor.exact()`.

**Recommendation**: Consider extracting a `Navigate.levelRange(level:count:)` helper that encapsulates the bit-shift arithmetic and returns typed indices, keeping the heapify loop at the intent level.

---

### HEAP-025: Magic number 4 in grandchildren iteration [IMPL-033] -- LOW

**File**: `/Users/coen/Developer/swift-primitives/swift-heap-primitives/Sources/Heap MinMax Primitives/Heap.MinMax ~Copyable.swift:202,259`

```swift
for _ in 0..<4 {
    guard nav.isValid(gcIndex) else { break }
    ...
    gcIndex += .one
}
```

The number 4 (maximum grandchildren in a binary heap) is a magic constant. A named constant like `Navigate.maxGrandchildren` would make the intent clearer.

---

### HEAP-026: withPriority/withMin/withMax compound public names [API-NAME-002] -- LOW

These are borrowing access methods for `~Copyable` elements:

| Method | Files |
|--------|-------|
| `withPriority(_:)` | Heap, Static, Fixed, Small `~Copyable.swift` |
| `withMin(_:)` | MinMax `~Copyable.swift:339` |
| `withMax(_:)` | MinMax `~Copyable.swift:346` |

These follow the `with...` closure pattern common in Swift (like `withUnsafePointer`). They're compound names but match an established Swift idiom. The Copyable variants correctly use the Property.View pattern (`heap.min.peek`, `heap.max.peek`), and these `with...` methods exist only for the `~Copyable` path where copies are impossible.

**Recommendation**: Accept as idiomatic Swift for the `~Copyable` borrowing pattern.

---

### HEAP-030: Multiple namespace enums in Heap.MinMax.swift [API-IMPL-005] -- LOW

**File**: `/Users/coen/Developer/swift-primitives/swift-heap-primitives/Sources/Heap MinMax Primitives/Heap.MinMax.swift`

This file contains the `Position` enum, `Error` typealias, `Fixed.Error` typealias, `Property` typealias, and the `Remove` accessor with its `Property.View.Typed` extension. These are lightweight namespace declarations, not full types, so the violation is minor.

---

## Compliant Patterns (Notable)

1. **[API-NAME-001]**: All types use correct Nest.Name pattern: `Heap.Static`, `Heap.Fixed`, `Heap.Small`, `Heap.MinMax`, `Heap.MinMax.Static`, `Heap.MinMax.Small`, `Heap.MinMax.Fixed`, `Heap.Navigate`, `Heap.Push.Outcome`. No compound type names found.

2. **[IMPL-020]**: Property.View pattern is correctly and consistently used for public API:
   - `heap.remove.all()` -- Heap, Static, Fixed, Small
   - `heap.min.peek`, `heap.min.pop()`, `heap.min.take` -- MinMax
   - `heap.max.peek`, `heap.max.pop()`, `heap.max.take` -- MinMax
   - `heap.peek.min`, `heap.peek.max` -- MinMax (non-mutating via Property.Typed)
   - `heap.drain { }`, `heap.forEach { }`, etc. -- Sequence accessors

3. **[API-ERR-001]**: All throwing functions use typed throws: `throws(Heap.Error)`, `throws(Heap.Fixed.Error)`, `throws(Heap.Static<capacity>.Error)`, `throws(Heap.Small<inlineCapacity>.Error)`, `throws(Heap<Element>.MinMax.Error)`.

4. **[PATTERN-017]**: `.rawValue` access is correctly confined to `Heap.Navigate` (3 occurrences, all in index arithmetic boundary code).

5. **[IMPL-002]**: Typed arithmetic used consistently: `.one`, `.zero`, `count.map(Ordinal.init)`, `count.subtract.saturating(.one)`, `idx.predecessor.exact()`, `idx += .one`.

## Statistics

| Metric | Count |
|--------|-------|
| Total files | 42 |
| `Int(bitPattern:)` | 8 (5 boundary/OK, 2 algorithmic/MEDIUM, 1 commented-out) |
| `__unchecked` | 8 (6 Navigate boundary, 2 init boundary) |
| `.rawValue` | 3 (all in Navigate boundary) |
| Compound public method names | 6 (withPriority, withMin, withMax, isValid, removeAll, makeIterator -- last 2 protocol-mandated) |
| Compound package method names | ~15 (bubbleUp, trickleDown, removePriority, etc. across 5 variants) |
| Property.View accessors | 14+ (remove, min, max, peek, drain, forEach, satisfies, first, reduce, contains, drop, prefix) |

## Verdict

The package is well-architected with strong adherence to [API-NAME-001] (Nest.Name types), [IMPL-020] (Property.View pattern), [API-ERR-001] (typed throws), and [PATTERN-017] (.rawValue confinement). The primary areas for improvement are:

1. **HEAP-001** (MEDIUM): `Heap.swift` contains too many types -- extract `Order`, `Error`, `Push`, `Fixed` to separate files.
2. **HEAP-018/019** (MEDIUM): Two algorithmic `Int(bitPattern:)` usages in MinMax could benefit from typed encapsulation.
3. **HEAP-023** (MEDIUM): `Int._binaryLogarithm()` extension belongs in its own file.
4. **HEAP-024** (MEDIUM): MinMax `heapify()` is mechanism-heavy -- consider extracting level-range helpers.
5. **Compound internal names** (LOW): Package-internal algorithm methods use compound names (bubbleUp, trickleDown, etc.), but these are standard heap terminology and refactoring priority is low.
