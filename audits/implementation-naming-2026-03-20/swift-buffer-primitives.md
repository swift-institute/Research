# swift-buffer-primitives: Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (Opus 4.6)
**Skills**: naming [API-NAME-*], implementation [IMPL-*]
**Scope**: All 123 `.swift` files in `Sources/`

## Summary

| Severity | Count | Categories |
|----------|-------|------------|
| CRITICAL | 0 | — |
| HIGH | 5 | .rawValue chains, __unchecked boundary, for-loop mechanism |
| MEDIUM | 15 | Int(bitPattern:) at non-boundary call sites, while-loop mechanism |
| LOW | 7 | Minor naming, duplication |

Overall assessment: **Good**. The codebase is well-structured with excellent use of Nest.Name patterns, Property.View for verb-as-property, and core logic in static methods. The primary concerns are .rawValue.rawValue chains (violating [PATTERN-017]), Int(bitPattern:) used outside true C/stdlib boundaries (violating [IMPL-010]), and some while-loop iteration where forEach/reduce would express intent more clearly (violating [IMPL-033]).

---

## HIGH Findings

### Finding [BUF-001]: .rawValue.rawValue chain in Arena allocate
- **Severity**: HIGH
- **Requirement**: [PATTERN-017] .rawValue confined to boundary code
- **Location**: `Sources/Buffer Arena Primitives/Buffer.Arena+Heap ~Copyable.swift:50`
- **Current**: `slot = UInt32(header.highWater.rawValue.rawValue)`
- **Proposed**: Add a boundary overload or typed conversion: `slot = UInt32(header.highWater)` via a `UInt32.init(_ count: Index<Element>.Count)` extension, or use `.map` to extract the ordinal at the type level.
- **Rationale**: Double `.rawValue` extraction violates [PATTERN-017] which requires rawValue access only in boundary code. This is core arena logic, not a C/stdlib boundary. The same pattern appears at line 143: `guard rawSlot < UInt32(header.highWater.rawValue.rawValue)`.

### Finding [BUF-002]: .rawValue.rawValue chain in Arena isValid
- **Severity**: HIGH
- **Requirement**: [PATTERN-017] .rawValue confined to boundary code
- **Location**: `Sources/Buffer Arena Primitives/Buffer.Arena+Heap ~Copyable.swift:143`
- **Current**: `guard rawSlot < UInt32(header.highWater.rawValue.rawValue) else { return false }`
- **Proposed**: Same as BUF-001 — use a typed conversion or boundary overload.
- **Rationale**: This is validation logic in the arena's core path, not a boundary. The double extraction defeats the purpose of typed wrappers.

### Finding [BUF-003]: .rawValue in Unbounded.reallocate
- **Severity**: HIGH
- **Requirement**: [PATTERN-017] .rawValue confined to boundary code
- **Location**: `Sources/Buffer Primitives Core/Buffer.Unbounded.swift:61,183,186`
- **Current**:
  - Line 61: `self._storage = try Aligned(byteCount: minimumCapacity.rawValue, alignment: alignment)`
  - Line 183: `var newStorage = try Buffer.Aligned(byteCount: newCapacity.rawValue, alignment: alignment)`
  - Line 186: `let bytesToCopy = Int(bitPattern: Index<Element>.Count.min(count, newCapacity).rawValue)`
- **Proposed**: `Buffer.Aligned.init` should accept `Index<Element>.Count` directly (or `Cardinal`) and do the extraction internally as a boundary overload. Line 186 should use typed arithmetic.
- **Rationale**: These are the internal guts of Unbounded, not C/stdlib API boundaries. The `.rawValue` extraction should be pushed to the `Aligned.init` boundary, which IS a true allocation boundary.

### Finding [BUF-004]: __unchecked in non-boundary internal code
- **Severity**: HIGH
- **Requirement**: [PATTERN-021] Prefer typed arithmetic over __unchecked
- **Location**: `Sources/Buffer Primitives Core/Buffer.Unbounded.swift:101,107`
- **Current**:
  ```swift
  Index<Element>.Count(__unchecked: (), _storage.count)
  ```
- **Proposed**: Use a typed conversion from `Cardinal` since `_storage.count` is `Cardinal`:
  ```swift
  Index<Element>.Count(_storage.count)
  ```
  If no such initializer exists, this is a gap in index-primitives. The `__unchecked` marker should only appear at boundaries where type safety has been verified externally.
- **Rationale**: The Unbounded type's `count` and `capacity` computed properties both use `__unchecked` to construct `Index<Element>.Count` from a `Cardinal`. This is an internal property, not a boundary. A safe conversion path should exist.

### Finding [BUF-005]: for-in over raw Int range in Arena deinit/iteration
- **Severity**: HIGH
- **Requirement**: [IMPL-033] Iteration: intent over mechanism
- **Location**: `Sources/Buffer Arena Primitives/Buffer.Arena+Heap ~Copyable.swift:191-195,210-216`; `Sources/Buffer Primitives Core/Buffer.swift:996`; `Sources/Buffer Arena Inline Primitives/Buffer.Arena.Inline.swift:147-151`
- **Current**:
  ```swift
  let hw = Int(bitPattern: header.highWater)
  for i in 0..<hw {
      if meta[i].isOccupied {
          body(Index<Element>(Ordinal(UInt(i))))
      }
  }
  ```
- **Proposed**: Iterate using typed indices:
  ```swift
  var slot: Index<Element> = .zero
  let end = header.highWater.map(Ordinal.init)
  while slot < end {
      if meta[slot].isOccupied { body(slot) }
      slot += .one
  }
  ```
  Or, better: provide a `Meta` helper that yields occupied indices directly, matching the pattern used elsewhere (e.g., `bitmap.ones.forEach`).
- **Rationale**: The arena discipline uses raw `Int` iteration with manual `Index<Element>(Ordinal(UInt(i)))` reconstruction inside the loop body. This is mechanism, not intent. The Buffer.swift deinit (line 994-1006) does the same with `Int(bitPattern: header.highWater)` and manual stride arithmetic. Note: the deinit in Buffer.swift has a WORKAROUND comment explaining this is due to a compiler crash with closures capturing ~Copyable fields — the `for i in` loop is intentional there. The static methods in `Buffer.Arena+Heap ~Copyable.swift` have no such constraint and should use typed iteration.

---

## MEDIUM Findings

### Finding [BUF-006]: Int(bitPattern:) in Iterator pointer arithmetic
- **Severity**: MEDIUM
- **Requirement**: [IMPL-010] Int(bitPattern:) in boundary overloads only
- **Location**: `Sources/Buffer Ring Primitives/Buffer.Ring+Span.swift:39,45,47,86,99,152,158,160,195,208`; `Sources/Buffer Linear Primitives/Buffer.Linear+Span.swift:41,95`; `Sources/Buffer Linear Inline Primitives/Buffer.Linear.Inline Copyable.swift:74`; `Sources/Buffer Ring Inline Primitives/Buffer.Ring.Small+Span.swift:39,45,47,86,99`; `Sources/Buffer Linear Small Primitives/Buffer.Linear.Small+Span.swift:116`
- **Current**: `unsafe self.base = storageBase + Int(bitPattern: range.lowerBound)` and `unsafe base = base + Int(bitPattern: take)`
- **Proposed**: These are pointer arithmetic at the UnsafePointer level — the `+` operator on `UnsafePointer` requires `Int`. This IS a boundary (Swift stdlib's UnsafePointer API). However, there should ideally be a typed overload: `UnsafePointer + Index<Element>` or `UnsafePointer + Index<Element>.Count` defined in a boundary extension.
- **Rationale**: Per [IMPL-010], `Int(bitPattern:)` should appear in boundary overloads, not sprinkled through iterator implementations. A single boundary extension on `UnsafePointer` that accepts typed counts would eliminate ~25 usages. This is MEDIUM because the conversion is at the UnsafePointer API boundary, which is legitimate — but the volume suggests a missing boundary overload.

### Finding [BUF-007]: Int(bitPattern:) in preconditions
- **Severity**: MEDIUM
- **Requirement**: [IMPL-010] Int(bitPattern:) in boundary overloads only
- **Location**: `Sources/Buffer Primitives Core/Buffer.Aligned+Convenience.swift:27,31,53,75,102,117`
- **Current**:
  ```swift
  precondition(index >= 0 && index < Int(bitPattern: count), "index out of bounds")
  ```
- **Proposed**: The `Buffer.Aligned` subscript takes raw `Int` indices. The precondition converts `count` (Cardinal) to `Int` for comparison. This is a raw-Int API surface — consider providing a typed subscript accepting `Index<UInt8>` and keep the Int subscript as a boundary overload.
- **Rationale**: `Buffer.Aligned` is the UInt8-specific aligned buffer. Its subscript uses raw `Int` throughout, requiring `Int(bitPattern: count)` in 6 places. This is semi-legitimate as a boundary API, but the volume suggests the type should accept typed indices.

### Finding [BUF-008]: Int(bitPattern:) in underestimatedCount
- **Severity**: MEDIUM
- **Requirement**: [IMPL-010] Int(bitPattern:) in boundary overloads only
- **Location**: `Sources/Buffer Ring Primitives/Buffer.Ring+Span.swift:119,228`; `Sources/Buffer Linear Primitives/Buffer.Linear+Span.swift:58,112`; `Sources/Buffer Linked Primitives/Buffer.Linked Copyable.swift:256`
- **Current**: `public var underestimatedCount: Int { Int(bitPattern: header.count) }`
- **Proposed**: This IS a boundary overload — `Swift.Sequence.underestimatedCount` requires `Int`. This is correct usage per [IMPL-010]. No change needed.
- **Rationale**: Downgraded on analysis. These are protocol-mandated `Int` conversions. Keeping as MEDIUM only because the same pattern could be centralized via a default implementation.

### Finding [BUF-009]: Int(bitPattern:) in Hasher
- **Severity**: MEDIUM
- **Requirement**: [IMPL-010] Int(bitPattern:) in boundary overloads only
- **Location**: `Sources/Buffer Linked Primitives/Buffer.Linked Copyable.swift:307`
- **Current**: `hasher.combine(Int(bitPattern: header.count))`
- **Proposed**: This is a boundary — `Hasher.combine` requires a `Hashable` type. `Int` is the natural choice. Acceptable per [IMPL-010].
- **Rationale**: Correct boundary usage. Keeping as MEDIUM for tracking only.

### Finding [BUF-010]: while-loop iteration in forEach implementations
- **Severity**: MEDIUM
- **Requirement**: [IMPL-033] Iteration: intent over mechanism
- **Location**: `Sources/Buffer Ring Primitives/Buffer.Ring+forEach.swift:8-12,24-28,41-47`; `Sources/Buffer Linear Primitives/Buffer.Linear+forEach.swift:7-12,21-27,37-42`
- **Current**:
  ```swift
  var slot: Index<Element> = .zero
  let end = header.count.map(Ordinal.init)
  while slot < end {
      try body(unsafe storage.pointer(at: slot).pointee)
      slot += .one
  }
  ```
- **Proposed**: The `while slot < end { ... slot += .one }` pattern is used consistently across Ring, Linear, Bounded, and Inline forEach implementations. This IS the ~Copyable forEach pattern — closures over `borrowing Element` require manual iteration because stdlib's `Sequence.forEach` requires Copyable. This is an intentional mechanism choice forced by the ~Copyable constraint.
- **Rationale**: Downgraded on analysis. The while-loop is the only viable pattern for ~Copyable forEach. Keeping as MEDIUM for awareness — when Swift gains Copyable-relaxed sequence iteration, these should migrate.

### Finding [BUF-011]: Slab.Inline deinit uses while-loop with manual Bit.Index
- **Severity**: MEDIUM
- **Requirement**: [IMPL-033] Iteration: intent over mechanism
- **Location**: `Sources/Buffer Primitives Core/Buffer.swift:507-516`
- **Current**:
  ```swift
  var slot: Bit.Index = .zero
  let end = Bit.Index.Count(UInt(wordCount)).map(Ordinal.init)
  while slot < end {
      if header.bitmap[slot] {
          let elementSlot = Index<Element>.Bounded<wordCount>(slot.retag(Element.self))!
          unsafe storage.pointer(at: elementSlot).deinitialize(count: 1)
      }
      slot += .one
  }
  ```
- **Proposed**: Use `header.bitmap.ones.forEach { ... }` like the Slab heap deinit does:
  ```swift
  header.bitmap.ones.forEach { slot in
      let elementSlot = Index<Element>.Bounded<wordCount>(slot.retag(Element.self))!
      unsafe storage.pointer(at: elementSlot).deinitialize(count: 1)
  }
  ```
- **Rationale**: The heap-backed Slab uses bitmap iteration (`ones.forEach`), but the inline deinit uses a manual while-loop over all slots. The Wegner/Kernighan iteration is both more intent-expressive and more efficient (O(count) vs O(capacity)). Note: deinit closures may have the same compiler crash issue as Arena.Inline — if so, this is blocked by the same compiler bug and should be noted as such.

### Finding [BUF-012]: Arena.Inline uses raw Int subscript into _meta
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002] Typed arithmetic — no .rawValue at call sites
- **Location**: `Sources/Buffer Arena Inline Primitives/Buffer.Arena.Inline.swift:172,180`; `Sources/Buffer Arena Primitives/Buffer.Arena+Heap ~Copyable.swift:21-24,46,53-56`
- **Current**:
  ```swift
  _meta[Int(bitPattern: slot)].isOccupied
  _meta[Int(bitPattern: slot)].token
  ```
  And in static methods:
  ```swift
  meta[slot].token  // meta is UnsafeMutablePointer<Meta>, subscripted by Index<Element>
  ```
- **Proposed**: The `InlineArray` subscript requires `Int`. `_meta[Int(bitPattern: slot)]` is the boundary. The `UnsafeMutablePointer` subscript path (`meta[slot]`) already accepts typed indices (via boundary overload). No change needed for the pointer path. For InlineArray, a boundary extension `InlineArray.subscript(_ index: Index<Element>)` would eliminate the `Int(bitPattern:)` calls.
- **Rationale**: The pointer-based code correctly uses typed subscripts. The InlineArray code requires explicit Int conversion — a boundary extension on InlineArray would be the proper fix.

### Finding [BUF-013]: Arena.Position.slot reconstructs Index from UInt32
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002] Typed arithmetic
- **Location**: `Sources/Buffer Primitives Core/Buffer.swift:1107-1108`
- **Current**: `Index<Element>(Ordinal(UInt(index)))`
- **Proposed**: This is a legitimate typed construction — `UInt32 -> UInt -> Ordinal -> Index<Element>`. The chain is verbose but correct. A convenience `Index<Element>(UInt32)` boundary overload would clean this up.
- **Rationale**: Three constructor wrappers to go from UInt32 to Index is verbose. A single boundary overload would express the same intent more clearly.

### Finding [BUF-014]: Arena Header.maximumCapacity constructs Count from UInt32.max
- **Severity**: MEDIUM
- **Requirement**: [IMPL-002] Typed arithmetic
- **Location**: `Sources/Buffer Primitives Core/Buffer.swift:1156`
- **Current**: `Index<Element>.Count(Cardinal(UInt(UInt32.max)))`
- **Proposed**: A static constant or boundary overload `Index<Element>.Count(UInt32)` would be cleaner.
- **Rationale**: Four constructor wrappers. Same pattern as BUF-013.

### Finding [BUF-015]: Arena forEach reconstructs Index inside loop
- **Severity**: MEDIUM
- **Requirement**: [IMPL-033] Iteration: intent over mechanism
- **Location**: `Sources/Buffer Arena Primitives/Buffer.Arena+Heap ~Copyable.swift:193`
- **Current**: `body(Index<Element>(Ordinal(UInt(i))))`
- **Proposed**: Iterate with typed indices (see BUF-005 proposed fix).
- **Rationale**: Reconstructing a typed index from a raw Int loop variable inside the loop body is mechanism. This is part of the same issue as BUF-005.

### Finding [BUF-016]: Arena deinit reconstructs Index inside loop
- **Severity**: MEDIUM
- **Requirement**: [IMPL-033] Iteration: intent over mechanism
- **Location**: `Sources/Buffer Arena Primitives/Buffer.Arena+Heap ~Copyable.swift:213`
- **Current**: `arenaStorage.deinitialize(at: Index<Element>(Ordinal(UInt(i))))`
- **Proposed**: Same as BUF-005/BUF-015.
- **Rationale**: Same issue.

### Finding [BUF-017]: Int(bitPattern:) in Arena grow
- **Severity**: MEDIUM
- **Requirement**: [IMPL-010] Int(bitPattern:) in boundary overloads only
- **Location**: `Sources/Buffer Arena Primitives/Buffer.Arena.swift:181`
- **Current**: `let oldCap = Int(bitPattern: header.capacity)`
- **Proposed**: This feeds `UnsafeMutablePointer.update(from:count:)` which requires `Int`. This IS a boundary — UnsafePointer API. Acceptable.
- **Rationale**: Correct boundary usage for UnsafePointer bulk operations.

### Finding [BUF-018]: Int(bitPattern:) in Arena.Inline._elementPointer
- **Severity**: MEDIUM
- **Requirement**: [IMPL-010] Int(bitPattern:) in boundary overloads only
- **Location**: `Sources/Buffer Arena Inline Primitives/Buffer.Arena.Inline.swift:28`
- **Current**: `let offset = Int(bitPattern: slot) * MemoryLayout<Element>.stride`
- **Proposed**: This is raw pointer arithmetic — a true boundary. Acceptable per [IMPL-010].
- **Rationale**: Manual pointer offset calculation is inherently a boundary operation.

### Finding [BUF-019]: Arena.Small._spillToHeap uses raw Int iteration
- **Severity**: MEDIUM
- **Requirement**: [IMPL-033] Iteration: intent over mechanism
- **Location**: `Sources/Buffer Arena Inline Primitives/Buffer.Arena.Small.swift:274`
- **Current**: `let hw = Int(bitPattern: inlineBuf.header.highWater)` followed by `for i in 0..<hw`
- **Proposed**: Same typed iteration pattern as BUF-005.
- **Rationale**: Same arena raw-Int iteration pattern.

### Finding [BUF-020]: Duplicate Iterator types (Ring, Ring.Bounded, Linear, Linear.Bounded)
- **Severity**: MEDIUM
- **Requirement**: [API-IMPL-005] One type per file (tangential: DRY)
- **Location**: `Sources/Buffer Ring Primitives/Buffer.Ring+Span.swift` (two Iterator types), `Sources/Buffer Linear Primitives/Buffer.Linear+Span.swift` (two Iterator types)
- **Current**: `Buffer.Ring.Iterator` and `Buffer.Ring.Bounded.Iterator` are nearly identical (same fields, same logic). Same for `Buffer.Linear.Iterator` and `Buffer.Linear.Bounded.Iterator`.
- **Proposed**: Factor out a shared iterator implementation parameterized by storage access, or use a typealias where the types are identical.
- **Rationale**: 4 iterator types with near-identical implementations (~60 lines each). This creates maintenance burden and increases the chance of drift. [API-IMPL-005] is about one type per file, but the duplication issue is the deeper concern.

---

## LOW Findings

### Finding [BUF-021]: Commented-out underestimatedCount with .rawValue.rawValue
- **Severity**: LOW
- **Requirement**: [PATTERN-017] .rawValue confined to boundary code
- **Location**: `Sources/Buffer Linear Inline Primitives/Buffer.Linear.Inline Copyable.swift:107`; `Sources/Buffer Ring Inline Primitives/Buffer.Ring.Inline Copyable.swift:136`; `Sources/Buffer Slab Inline Primitives/Buffer.Slab.Inline Copyable.swift:126`
- **Current**: `//     public var underestimatedCount: Int { Int(bitPattern: header.count.rawValue.rawValue) }`
- **Proposed**: Remove commented-out code. If re-enabled, use `Int(bitPattern: header.count)` — the double `.rawValue` should never appear.
- **Rationale**: Dead code with a double `.rawValue` chain. Should be removed or fixed before uncommenting.

### Finding [BUF-022]: Buffer.Ring.Header.Cyclic init uses __unchecked
- **Severity**: LOW
- **Requirement**: [PATTERN-021] Prefer typed arithmetic over __unchecked
- **Location**: `Sources/Buffer Primitives Core/Buffer.swift:221`
- **Current**: `self.head = Index<Element>.Cyclic<capacity>(__unchecked: Ordinal(0))`
- **Proposed**: If `Index<Element>.Cyclic<capacity>.zero` exists, use it. If not, this is a legitimate initialization boundary.
- **Rationale**: The `__unchecked` is used to construct a zero-valued cyclic index. This is initialization code with a known-valid value. LOW because `.zero` would be more idiomatic if available.

### Finding [BUF-023]: Buffer.Aligned subscript uses raw Int
- **Severity**: LOW
- **Requirement**: [IMPL-002] Typed arithmetic
- **Location**: `Sources/Buffer Primitives Core/Buffer.Aligned+Convenience.swift:25-34`
- **Current**: `public subscript(index: Int) -> UInt8`
- **Proposed**: The doc comment says this is for "debugging and infrequent access." A typed overload accepting `Index<UInt8>` would be preferable for consistent API, keeping the `Int` version as a boundary convenience.
- **Rationale**: Low severity because the type explicitly notes this is for debugging. The typed APIs (`bytes`, `mutableBytes`, `span`) are the primary access path.

### Finding [BUF-024]: Buffer.Aligned.zero(range:) and zero(from:) use raw Int
- **Severity**: LOW
- **Requirement**: [IMPL-002] Typed arithmetic
- **Location**: `Sources/Buffer Primitives Core/Buffer.Aligned+Convenience.swift:101,116`
- **Current**: `public mutating func zero(range: Swift.Range<Int>)` and `func zero(from offset: Int)`
- **Proposed**: These are convenience methods on a UInt8-specific type. Typed overloads accepting `Index<UInt8>` ranges would be more consistent, keeping `Int` versions as boundary overloads.
- **Rationale**: Same rationale as BUF-023. Low priority because Buffer.Aligned is a boundary type that interfaces with raw memory APIs.

### Finding [BUF-025]: Multiple types in Buffer.swift
- **Severity**: LOW
- **Requirement**: [API-IMPL-005] One type per file
- **Location**: `Sources/Buffer Primitives Core/Buffer.swift` (1280 lines, ~30 type declarations)
- **Current**: All Buffer discipline types (Ring, Linear, Slab, Linked, Slots, Arena) and their nested types (Header, Bounded, Inline, Small, Checkpoint, Node, Position, Error, Meta) are declared in a single file.
- **Proposed**: This is the namespace declaration file — all types are nested inside `Buffer<Element>`. Splitting would require separate files for each nested type declaration. This is an intentional design choice: the type declarations are tightly coupled and interdependent (conditional conformances at the bottom reference all of them). The alternative would be 30+ stub files with empty type bodies, which is worse.
- **Rationale**: LOW because this is a defensible exception to [API-IMPL-005]. The file is a type catalog with conditional conformances. The real implementations live in separate module files. Still, the file at 1280 lines is large and could benefit from splitting at least the conditional conformance blocks.

### Finding [BUF-026]: Naming compliance — all types follow Nest.Name pattern
- **Severity**: LOW (POSITIVE)
- **Requirement**: [API-NAME-001], [API-NAME-002]
- **Location**: Entire codebase
- **Current**: All types use proper Nest.Name: `Buffer.Ring`, `Buffer.Linear`, `Buffer.Slab.Bounded.Indexed`, `Buffer.Arena.Position`, etc. All methods use non-compound names with Property.View accessors: `buffer.push.back()`, `buffer.pop.front()`, `buffer.remove.all()`, `buffer.insert.front()`, `buffer.peek.front`.
- **Proposed**: No changes needed.
- **Rationale**: The codebase is exemplary in naming compliance. No compound type names (`BufferRing`, `RingBuffer`) or compound methods (`pushBack`, `popFront`) were found anywhere.

### Finding [BUF-027]: Core logic in static methods — excellent compliance
- **Severity**: LOW (POSITIVE)
- **Requirement**: [IMPL-023] Core logic in static methods
- **Location**: All discipline modules
- **Current**: All element manipulation logic lives in static methods: `Buffer.Ring.pushBack(...)`, `Buffer.Linear.append(...)`, `Buffer.Slab.insert(...)`, `Buffer.Arena.allocate(...)`, etc. Instance methods delegate to static methods.
- **Proposed**: No changes needed.
- **Rationale**: Perfect compliance with [IMPL-023]. The three-layer architecture (Header / Static Operations / Composed Types) is consistently applied across all six buffer disciplines.

---

## Findings by Module

| Module | Findings |
|--------|----------|
| Buffer Primitives Core | BUF-003, BUF-004, BUF-005 (deinit), BUF-011, BUF-013, BUF-014, BUF-022, BUF-023, BUF-024, BUF-025 |
| Buffer Ring Primitives | BUF-006, BUF-008, BUF-010, BUF-020 |
| Buffer Linear Primitives | BUF-006, BUF-008, BUF-010, BUF-020 |
| Buffer Arena Primitives | BUF-001, BUF-002, BUF-005, BUF-015, BUF-016, BUF-017 |
| Buffer Arena Inline Primitives | BUF-005 (variant), BUF-012, BUF-018, BUF-019 |
| Buffer Slab Primitives | (clean) |
| Buffer Linked Primitives | BUF-008, BUF-009 |
| Buffer Slots Primitives | (clean) |
| Buffer Ring Inline Primitives | BUF-006, BUF-021 |
| Buffer Linear Inline Primitives | BUF-006, BUF-021 |
| Buffer Linear Small Primitives | BUF-006 |
| Buffer Slab Inline Primitives | BUF-021 |
| Buffer Linked Inline Primitives | (clean) |

## Systemic Patterns

### 1. Arena discipline uses raw Int iteration (HIGH)
The Arena discipline consistently uses `for i in 0..<Int(bitPattern: highWater)` with manual `Index<Element>(Ordinal(UInt(i)))` reconstruction. This appears in 5 locations across Arena Primitives and Arena Inline. A typed iteration helper (`Arena.forEachSlot(upTo:body:)`) or converting to while-loop typed iteration would fix all occurrences.

### 2. Missing UnsafePointer boundary overloads (MEDIUM)
~25 `Int(bitPattern:)` usages in Iterator types are for `UnsafePointer + offset` arithmetic. A single boundary extension:
```swift
extension UnsafePointer {
    static func + (lhs: Self, rhs: Index<Pointee>.Count) -> Self { lhs + Int(bitPattern: rhs) }
}
```
would eliminate most of these.

### 3. Buffer.Aligned uses raw Int throughout (LOW)
Buffer.Aligned is a UInt8-specific boundary type interfacing with raw memory APIs. Its use of raw `Int` subscripts, `Range<Int>`, and `Int` offsets is defensible but could benefit from typed overloads for consistency.

### 4. Property.View pattern — exemplary (POSITIVE)
The codebase is a model implementation of [IMPL-020]. All verb operations use Property.View:
- `buffer.push.back(element)` / `buffer.push.front(element)`
- `buffer.pop.front()` / `buffer.pop.back()`
- `buffer.peek.front` / `buffer.peek.back`
- `buffer.remove.all()` / `buffer.remove.first()` / `buffer.remove.last()`
- `buffer.insert.front(element)` / `buffer.insert.back(element)`
- `buffer.drain { ... }`
- `buffer.forEach.occupied { ... }`

### 5. Typed throws — exemplary (POSITIVE)
All throwing functions use typed throws per [API-ERR-001]:
- `throws(Error)` for bounded buffer operations
- `throws(Buffer.Aligned.Error)` for allocation
- `throws(Storage<Node>.Pool.Error)` for pool operations
- `throws(Buffer<Element>.Arena.Error)` for arena validation
