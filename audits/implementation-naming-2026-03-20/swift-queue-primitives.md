# swift-queue-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Skills**: implementation, naming
**Scope**: All 29 `.swift` files under `Sources/`
**Status**: READ-ONLY audit

---

## Summary Table

| ID | Severity | Rule | File | Line(s) | Description |
|----|----------|------|------|---------|-------------|
| [Q-001] | HIGH | [IMPL-002], [PATTERN-017] | Queue+Conveniences.swift | 51 | `.rawValue.rawValue` chain in `distance(from:to:)` |
| [Q-002] | HIGH | [IMPL-002], [PATTERN-017] | Queue+Conveniences.swift | 57 | `.rawValue.rawValue` chain in `index(_:offsetBy:)` |
| [Q-003] | HIGH | [IMPL-002], [PATTERN-017] | Queue+Conveniences.swift | 64-65 | `.rawValue.rawValue` chain (x2) in `index(_:offsetBy:limitedBy:)` |
| [Q-004] | HIGH | [IMPL-010], [PATTERN-018] | Queue+Conveniences.swift | 51, 57-58, 64-65, 71 | `Int(bitPattern:)` at call sites in RandomAccessCollection conformance |
| [Q-005] | HIGH | [PATTERN-021] | Queue+Conveniences.swift | 58, 71 | `__unchecked` construction at call sites |
| [Q-006] | MEDIUM | [IMPL-010] | Queue.Linked ~Copyable.swift | 37 | `Int(bitPattern:)` at call site in `_ensureCapacityForOneMore()` |
| [Q-007] | LOW | [IMPL-010] | 10 files | various | `Int(bitPattern: count)` in `underestimatedCount` (stdlib boundary) |
| [Q-008] | HIGH | [API-IMPL-005] | Queue.swift | 83-433 | 9 type declarations in single file |
| [Q-009] | HIGH | [API-IMPL-005] | Queue.Error.swift | 29-173 | 11 error enums + 3 typealiases in single file |
| [Q-010] | MEDIUM | [API-IMPL-005] | Queue.Linked.Inline+Small.swift | all | Two types' extensions in single file |
| [Q-011] | MEDIUM | [API-IMPL-005] | Queue.DoubleEnded Copyable.swift | all | Extensions for 4 types (DoubleEnded, Fixed, Static, Small) in single file |
| [Q-012] | MEDIUM | [API-IMPL-005] | Queue.DoubleEnded.swift | all | Extensions for 5 types in single file |
| [Q-013] | MEDIUM | [API-IMPL-005] | Queue.DoubleEnded.Accessor.swift | 20-37 | Front, Back, PeekAccessor declarations in single file |
| [Q-014] | LOW | [API-NAME-002] | Queue.Dynamic ~Copyable.swift | 118-119 | `reserveCapacity` (delegated to buffer; method name is compound) |
| [Q-015] | LOW | [API-NAME-002] | Queue.DoubleEnded.swift | 73 | `reserveCapacity` in buffer delegation |
| [Q-016] | INFO | [IMPL-033] | Queue+Input.Protocol.swift | 88-92 | Manual `while` loop for `advance(by:)` |
| [Q-017] | INFO | [IMPL-033] | Queue.Bounded+Input.Protocol.swift | 85-89 | Manual `while` loop for `advance(by:)` |
| [Q-018] | INFO | [IMPL-033] | Queue.Static+Input.Protocol.swift | 87-91 | Manual `while` loop for `advance(by:)` |
| [Q-019] | INFO | [IMPL-033] | Queue.Small+Input.Protocol.swift | 89-93 | Manual `while` loop for `advance(by:)` |
| [Q-020] | INFO | [IMPL-033] | Queue.DoubleEnded.swift | 586-594 | Manual `while` loop for Equatable |
| [Q-021] | INFO | [IMPL-033] | Queue.DoubleEnded.swift | 601-608 | Manual `while` loop for Hashable |
| [Q-022] | LOW | [IMPL-021] | Queue.DoubleEnded.Accessor.swift | 37-63 | Hand-rolled `PeekAccessor` struct instead of Property.View |
| [Q-023] | LOW | [API-NAME-001] | Queue.Error.swift | 29-133 | Hoisted error types use `__QueueDoubleEndedError` compound names at module scope |
| [Q-024] | INFO | n/a | Queue.swift, Queue.Error.swift | various | Comment references to `Queue.Bounded` do not match actual type name `Queue.Fixed` |

---

## Findings

### [Q-001] `.rawValue.rawValue` chain in `distance(from:to:)` -- HIGH

**File**: `Sources/Queue Dynamic Primitives/Queue+Conveniences.swift:51`
**Rules**: [IMPL-002], [PATTERN-017]

```swift
Int(bitPattern: end.rawValue.rawValue) - Int(bitPattern: start.rawValue.rawValue)
```

Double raw-value extraction chains expose mechanism. Per [IMPL-002]: "If you find yourself chaining `.rawValue.rawValue`, that's a missing operator. Add it." The stdlib `RandomAccessCollection` conformance requires `Int`, but this conversion should be encapsulated in a boundary overload or typed operation (e.g., `end.distance(to: start)` returning `Int`, or `Index.offset(from:to:)` as a static).

---

### [Q-002] `.rawValue.rawValue` chain in `index(_:offsetBy:)` -- HIGH

**File**: `Sources/Queue Dynamic Primitives/Queue+Conveniences.swift:57`
**Rules**: [IMPL-002], [PATTERN-017]

```swift
let raw = Int(bitPattern: i.rawValue.rawValue) + distance
```

Same pattern as [Q-001]. The `rawValue.rawValue` chain + `Int(bitPattern:)` at the call site is pure mechanism. Per [IMPL-010], this should be pushed into a boundary overload on `Index` (e.g., `Index.advanced(by: Int) -> Index`).

---

### [Q-003] `.rawValue.rawValue` chains (x2) in `index(_:offsetBy:limitedBy:)` -- HIGH

**File**: `Sources/Queue Dynamic Primitives/Queue+Conveniences.swift:64-65`
**Rules**: [IMPL-002], [PATTERN-017]

```swift
let raw = Int(bitPattern: i.rawValue.rawValue) + distance
let limitRaw = Int(bitPattern: limit.rawValue.rawValue)
```

Two `.rawValue.rawValue` chains in the same method body. Same infrastructure gap as [Q-001] and [Q-002].

---

### [Q-004] `Int(bitPattern:)` at call sites in RandomAccessCollection -- HIGH

**File**: `Sources/Queue Dynamic Primitives/Queue+Conveniences.swift:51, 57-58, 64-65, 71`
**Rules**: [IMPL-010], [PATTERN-018]

Six instances of `Int(bitPattern:)` in three methods (`distance(from:to:)`, `index(_:offsetBy:)`, `index(_:offsetBy:limitedBy:)`). Per [IMPL-010]: "`Int(bitPattern:)` conversions MUST live inside boundary overloads, never at call sites."

The fix is to add boundary methods on `Index<Element>` that encapsulate the `Int` conversion for `RandomAccessCollection` conformance. All these methods implement stdlib `RandomAccessCollection` requirements, so this is a legitimate stdlib boundary -- but the conversion should be in one place (e.g., an `Index` extension), not repeated 6 times.

---

### [Q-005] `__unchecked` construction at call sites -- HIGH

**File**: `Sources/Queue Dynamic Primitives/Queue+Conveniences.swift:58, 71`
**Rules**: [PATTERN-021]

```swift
return Index(__unchecked: (), Ordinal(UInt(bitPattern: raw)))
```

Per [PATTERN-021]: "When a typed arithmetic operator exists for a conversion, it MUST be preferred over `__unchecked` with rawValue extraction." The `Index` is reconstructed from a raw `Int` via `__unchecked` at the call site. This should be encapsulated in a functor operation or boundary overload.

---

### [Q-006] `Int(bitPattern:)` at call site in `_ensureCapacityForOneMore()` -- MEDIUM

**File**: `Sources/Queue Linked Primitives/Queue.Linked ~Copyable.swift:37`
**Rules**: [IMPL-010]

```swift
try! _buffer.ensureCapacity(Int(bitPattern: _buffer.count) + 1)
```

`Int(bitPattern:)` conversion at the call site. The `ensureCapacity` API accepts `Int`, but the queue's count is typed. This should be pushed into a boundary overload on the buffer (e.g., `ensureCapacity(_: Index<Element>.Count)`) or use `count + .one` in typed arithmetic with a typed `ensureCapacity` overload.

---

### [Q-007] `Int(bitPattern: count)` in `underestimatedCount` -- LOW

**Files**: 10 files across Queue Dynamic, Fixed, Static, Small, Linked, DoubleEnded Primitives
**Rules**: [IMPL-010]

```swift
public var underestimatedCount: Int { Int(bitPattern: count) }
```

This is a stdlib boundary (`Sequence.underestimatedCount` requires `Int`). The conversion is localized and each occurrence is a boundary overload implementation. This is the correct location for `Int(bitPattern:)` per [IMPL-010], but the pattern repeats 10 times. A protocol default providing `underestimatedCount` for any type with a typed `count` would eliminate duplication. LOW because each instance individually follows the rule; the issue is repetition.

---

### [Q-008] 9 type declarations in `Queue.swift` -- HIGH

**File**: `Sources/Queue Primitives Core/Queue.swift:83-433`
**Rules**: [API-IMPL-005]

This file declares:
1. `Queue` (line 83)
2. `Queue.Fixed` (line 115)
3. `Queue.Linked` (line 172)
4. `Queue.Linked.Fixed` (line 212)
5. `Queue.DoubleEnded` (line 244)
6. `Queue.DoubleEnded.Position` (line 250)
7. `Queue.DoubleEnded.Fixed` (line 271)
8. `Queue.Linked.Inline` (line 384)
9. `Queue.Linked.Small` (line 421)

Per [API-IMPL-005]: "Each `.swift` file MUST contain exactly one type declaration." The comment at the top of each nested type notes this is due to [MEM-COPY-006] (Swift compiler bug with ~Copyable constraint propagation). Per [PATTERN-022], this is now fixed in Swift 6.2.4+ -- nested types can be in separate files via `extension Parent where Element: ~Copyable { }`. Splitting would bring this into compliance.

---

### [Q-009] 11 error enums in `Queue.Error.swift` -- HIGH

**File**: `Sources/Queue Primitives Core/Queue.Error.swift:29-173`
**Rules**: [API-IMPL-005]

Eleven hoisted error enums (`__QueueError`, `__QueueBoundedError`, `__QueueStaticError`, `__QueueLinkedError`, `__QueueLinkedBoundedError`, `__QueueLinkedInlineError`, `__QueueLinkedSmallError`, `__QueueDoubleEndedError`, `__QueueDoubleEndedFixedError`, `__QueueDoubleEndedStaticError`, `__QueueDoubleEndedSmallError`) plus three typealiases in one file. The file acknowledges this is due to Swift limitations with generic nested types (documented exception per [API-EXC-001]), but each should ideally be in its own file.

---

### [Q-010] Two types' extensions in `Queue.Linked.Inline+Small.swift` -- MEDIUM

**File**: `Sources/Queue Linked Primitives/Queue.Linked.Inline+Small.swift`
**Rules**: [API-IMPL-005]

This file contains extensions for both `Queue.Linked.Inline` and `Queue.Linked.Small`. Per [API-IMPL-005], these should be in separate files (e.g., `Queue.Linked.Inline.swift` and `Queue.Linked.Small.swift`).

---

### [Q-011] 4 types' extensions in `Queue.DoubleEnded Copyable.swift` -- MEDIUM

**File**: `Sources/Queue DoubleEnded Primitives/Queue.DoubleEnded Copyable.swift`
**Rules**: [API-IMPL-005]

Copyable extensions for `Queue.DoubleEnded`, `Queue.DoubleEnded.Fixed`, `Queue.DoubleEnded.Static`, and `Queue.DoubleEnded.Small` -- all in one file. Each type's Copyable extensions should be in separate files.

---

### [Q-012] 5 types' extensions in `Queue.DoubleEnded.swift` -- MEDIUM

**File**: `Sources/Queue DoubleEnded Primitives/Queue.DoubleEnded.swift`
**Rules**: [API-IMPL-005]

Extensions for `Queue.DoubleEnded` (~Copyable ops, Copyable ops, Sequence, Equatable, Hashable, ExpressibleByArrayLiteral, CustomStringConvertible), `Queue.DoubleEnded.Fixed` (~Copyable ops, Copyable ops, drain), `Queue.DoubleEnded.Static` (properties, operations), and `Queue.DoubleEnded.Small` (properties, operations) -- all in one file. These should be split per type per [API-IMPL-005].

---

### [Q-013] Multiple type declarations in `Queue.DoubleEnded.Accessor.swift` -- MEDIUM

**File**: `Sources/Queue DoubleEnded Primitives/Queue.DoubleEnded.Accessor.swift:20-37`
**Rules**: [API-IMPL-005]

Three type declarations: `Queue.DoubleEnded.Front` (enum), `Queue.DoubleEnded.Back` (enum), and `Queue.DoubleEnded.PeekAccessor` (struct). Per [API-IMPL-005], each should be in its own file. The Front and Back enums are namespace tags and may be acceptable as lightweight declarations alongside the Property.View extensions they enable, but PeekAccessor is a standalone public type.

---

### [Q-014] `reserveCapacity` compound name delegation -- LOW

**File**: `Sources/Queue Dynamic Primitives/Queue.Dynamic ~Copyable.swift:118-119`
**Rules**: [API-NAME-002]

```swift
public mutating func reserve(_ minimumCapacity: Index_Primitives.Index<Element>.Count) {
    _buffer.reserveCapacity(minimumCapacity)
}
```

The public API correctly uses `reserve` (non-compound), but internally delegates to `_buffer.reserveCapacity` (compound). The compound name is on the buffer layer, not on the queue layer, so this is a buffer-primitives concern, not a queue-primitives concern. Noting for completeness.

---

### [Q-015] `reserveCapacity` compound name in buffer delegation -- LOW

**File**: `Sources/Queue DoubleEnded Primitives/Queue.DoubleEnded.swift:73`
**Rules**: [API-NAME-002]

Same pattern as [Q-014]. The DoubleEnded `reserve` method delegates to `_buffer.reserveCapacity`. The compound name is on the buffer layer.

---

### [Q-016] through [Q-019] Manual `while` loops for `advance(by:)` -- INFO

**Files**: `Queue+Input.Protocol.swift:88-92`, `Queue.Bounded+Input.Protocol.swift:85-89`, `Queue.Static+Input.Protocol.swift:87-91`, `Queue.Small+Input.Protocol.swift:89-93`
**Rules**: [IMPL-033]

```swift
var i: Index_Primitives.Index<Element>.Count = .zero
while i < n {
    _ = dequeue()
    i += .one
}
```

Manual `while` loop repeated in 4 files. The loop uses typed arithmetic (`.zero`, `+= .one`), which is good, but per [IMPL-033] this could be expressed as a higher-level iteration if `Index.Count` supported a `repeat(count:)` or similar operation. INFO because the typed `while` loop is at Level 3 of the iteration hierarchy and the operation is destructive (consuming via `dequeue()`), which makes standard iteration infrastructure a poor fit.

---

### [Q-020] Manual `while` loop for Equatable -- INFO

**File**: `Sources/Queue DoubleEnded Primitives/Queue.DoubleEnded.swift:586-594`
**Rules**: [IMPL-033]

```swift
var i: Index_Primitives.Index<Element>.Count = .zero
while i < lhs.count {
    if lhs._readElement(at: i) != rhs._readElement(at: i) {
        return false
    }
    i += .one
}
```

Manual `while` loop with typed counter. Could potentially use `forEach` or a zip-like operation, but the early-exit semantics make this pattern acceptable.

---

### [Q-021] Manual `while` loop for Hashable -- INFO

**File**: `Sources/Queue DoubleEnded Primitives/Queue.DoubleEnded.swift:601-608`
**Rules**: [IMPL-033]

Same pattern as [Q-020]. Manual `while` loop for hashing. Typed arithmetic is correct; the mechanism is the loop structure itself.

---

### [Q-022] Hand-rolled `PeekAccessor` struct -- LOW

**File**: `Sources/Queue DoubleEnded Primitives/Queue.DoubleEnded.Accessor.swift:37-63`
**Rules**: [IMPL-021]

```swift
public struct PeekAccessor {
    @usableFromInline
    internal let _buffer: Buffer<Element>.Ring
    ...
}
```

Per [IMPL-021]: "MUST NOT hand-roll accessor structs." The `PeekAccessor` stores a buffer copy rather than using `Property<Tag, Base>.View`. Since this is a non-mutating accessor on a Copyable base, `Property<Peek, Queue.DoubleEnded>` would be the correct pattern. The custom struct duplicates what `Property` provides generically.

Note: The `Front.View` and `Back.View` correctly use `Property.View.Typed`, demonstrating the pattern is known and used elsewhere in this file.

---

### [Q-023] Hoisted error enum compound names -- LOW

**File**: `Sources/Queue Primitives Core/Queue.Error.swift:29-133`
**Rules**: [API-NAME-001]

Module-level error types like `__QueueDoubleEndedError`, `__QueueBoundedError`, `__QueueLinkedBoundedError` use compound names. These are explicitly documented as hoisted implementations due to Swift language limitations with generic nested types, and they are hidden behind typealiases (`Queue.DoubleEnded.Error`, `Queue.Fixed.Error`, etc.) that follow Nest.Name. The compound names are implementation-internal and not part of the public API. LOW because the typealiases provide the correct public naming.

---

### [Q-024] Comment/doc references to `Queue.Bounded` instead of `Queue.Fixed` -- INFO

**Files**: `Queue.swift:37, 98-99`, `Queue.Error.swift:158-159`, `Queue.Bounded.swift:41` (doc comment)

Several doc comments reference `Queue.Bounded` (e.g., `Queue/Bounded/Error/overflow`) while the actual type is named `Queue.Fixed`. The struct declaration says `public struct Fixed` but comments say `Queue<Int>.Bounded`. This suggests a rename occurred without updating all documentation. Not a code issue, but causes confusion.

---

## Statistics

| Severity | Count |
|----------|-------|
| HIGH | 6 |
| MEDIUM | 6 |
| LOW | 6 |
| INFO | 6 |
| **Total** | **24** |

## Priority Remediation

### Immediate (HIGH findings)

1. **[Q-001] through [Q-005]**: The `RandomAccessCollection` conformance in `Queue+Conveniences.swift` concentrates all `.rawValue.rawValue` chains, `Int(bitPattern:)` call-site usage, and `__unchecked` construction. The fix is to add boundary overloads on `Index<Element>` that encapsulate the stdlib Int conversion:
   - `Index.distance(to:) -> Int`
   - `Index.advanced(by: Int) -> Index`
   - `Index.advanced(by: Int, limitedBy: Index) -> Index?`

   These three methods push all `Int(bitPattern:)` and `__unchecked` into the index-primitives boundary layer, leaving the `RandomAccessCollection` conformance reading as pure intent.

2. **[Q-008]**: Split `Queue.swift` into per-type files using `extension Queue where Element: ~Copyable { }` pattern (now supported per [PATTERN-022] in Swift 6.2.4+).

### Short-term (MEDIUM findings)

3. **[Q-006]**: Add typed `ensureCapacity` overload on the linked buffer.
4. **[Q-009] through [Q-013]**: Split multi-type files per [API-IMPL-005].

### Backlog (LOW, INFO)

5. **[Q-007]**: Consider protocol default for `underestimatedCount`.
6. **[Q-022]**: Replace `PeekAccessor` with `Property<Peek, ...>`.
7. **[Q-016] through [Q-021]**: Manual loops are acceptable at current iteration hierarchy level.
8. **[Q-024]**: Update stale `Queue.Bounded` references in doc comments.
