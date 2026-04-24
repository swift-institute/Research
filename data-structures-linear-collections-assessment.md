# Linear Collections — Post-Refactor Comprehensive Assessment

<!--
---
version: 2.0.0
last_updated: 2026-02-12
status: DECISION
---
-->

## Context

The three foundational packages (buffer-primitives, storage-primitives, memory-primitives) have been refactored and now compile and pass tests. This assessment audits the five Linear Collections data structure packages that build on top of them:

1. **swift-array-primitives** at `/Users/coen/Developer/swift-primitives/swift-array-primitives/`
2. **swift-list-primitives** at `/Users/coen/Developer/swift-primitives/swift-list-primitives/`
3. **swift-stack-primitives** at `/Users/coen/Developer/swift-primitives/swift-stack-primitives/`
4. **swift-queue-primitives** at `/Users/coen/Developer/swift-primitives/swift-queue-primitives/`
5. **swift-cyclic-primitives** at `/Users/coen/Developer/swift-primitives/swift-cyclic-primitives/`

## Question

What is the current state of each package across eight audit dimensions: buffer/storage/memory integration, ~Copyable support, naming compliance, unsafe pointer usage, raw Int usage, error handling, one-type-per-file compliance, and Foundation imports?

---

## Analysis

### 1. Buffer / Storage / Memory Integration

All five packages have been fully migrated to the refactored buffer primitives. No package uses raw `UnsafeMutableBufferPointer`-based storage directly for its primary data store.

#### Array Primitives

| Variant | Buffer Type | File:Line |
|---------|------------|-----------|
| `Array` | `Buffer<Element>.Linear` | `Array Primitives Core/Array.swift:58` |
| `Array.Fixed` | `Buffer<Element>.Linear.Bounded` | `Array Primitives Core/Array.swift:104` |
| `Array.Static` | `Buffer<Element>.Linear.Inline<capacity>` | `Array Primitives Core/Array.swift:134` |
| `Array.Small` | `Buffer<Element>.Linear.Small<inlineCapacity>` | `Array Primitives Core/Array.Small.swift:34` |
| `Array.Bounded` | `Buffer<Element>.Linear.Bounded` | `Array Primitives Core/Array.swift:178` |
| `Array.Inline` | Typealias to `Swift.InlineArray` | `Array Primitives Core/Array.swift:201` |

#### List Primitives

| Variant | Buffer Type | File:Line |
|---------|------------|-----------|
| `List.Linked<N>` | `Buffer<Element>.Linked<N>` | `List Primitives Core/List.Linked.swift:72` |
| `List.Linked.Bounded` | `Buffer<Element>.Linked<N>` | `List Primitives Core/List.Linked.swift:97` |
| `List.Linked.Inline` | `Buffer<Element>.Linked<N>.Inline<capacity>` | `List Primitives Core/List.Linked.swift:147` |
| `List.Linked.Small` | `Buffer<Element>.Linked<N>.Small<inlineCapacity>` | `List Primitives Core/List.Linked.swift:187` |

#### Stack Primitives

| Variant | Buffer Type | File:Line |
|---------|------------|-----------|
| `Stack` | `Buffer<Element>.Linear` | `Stack Primitives Core/Stack.swift:76` |
| `Stack.Static` | `Buffer<Element>.Linear.Inline<capacity>` | `Stack Primitives Core/Stack.swift:91` |
| `Stack.Small` | `Buffer<Element>.Linear.Small<inlineCapacity>` | `Stack Primitives Core/Stack.swift:143` |
| `Stack.Bounded` | `Buffer<Element>.Linear.Bounded` | `Stack Primitives Core/Stack.swift:212` |

#### Queue Primitives

| Variant | Buffer Type | File:Line |
|---------|------------|-----------|
| `Queue` | `Buffer<Element>.Ring` | `Queue Primitives Core/Queue.swift:86` |
| `Queue.Static` | `Buffer<Element>.Ring.Inline<capacity>` | `Queue Primitives Core/Queue.swift:101` |
| `Queue.Small` | `Buffer<Element>.Ring.Small<inlineCapacity>` | `Queue Primitives Core/Queue.swift:150` |
| `Queue.Fixed` | `Buffer<Element>.Ring.Bounded` | `Queue Primitives Core/Queue.swift:194` |
| `Queue.Linked` | `Buffer<Element>.Linked<1>` | `Queue Primitives Core/Queue.swift:252` |
| `Queue.Linked.Fixed` | `Buffer<Element>.Linked<1>` | `Queue Primitives Core/Queue.swift:291` |
| `Queue.Linked.Inline` | `List<Element>.Linked<1>.Inline<capacity>` (via List) | `Queue Primitives Core/Queue.swift:517` |
| `Queue.Linked.Small` | `List<Element>.Linked<1>.Small<inlineCapacity>` (via List) | `Queue Primitives Core/Queue.swift:554` |
| `Queue.DoubleEnded` | `Buffer<Element>.Ring` | `Queue Primitives Core/Queue.swift:324` |
| `Queue.DoubleEnded.Fixed` | `Buffer<Element>.Ring.Bounded` | `Queue Primitives Core/Queue.swift:350` |
| `Queue.DoubleEnded.Static` | `Buffer<Element>.Ring.Inline<capacity>` | `Queue Primitives Core/Queue.swift:373` |
| `Queue.DoubleEnded.Small` | `Buffer<Element>.Ring.Small<inlineCapacity>` | `Queue Primitives Core/Queue.swift:401` |

#### Cyclic Primitives

Cyclic primitives do not depend on buffer/storage/memory at all. They use Ordinal/Cardinal typed arithmetic from `swift-ordinal-primitives` and `swift-cardinal-primitives`. This is correct -- cyclic groups are algebraic structures, not storage-backed collections.

**Verdict: PASS.** All storage-backed types delegate to refactored Buffer primitives. No raw pointer storage management remains.

---

### 2. ~Copyable Support

All five packages implement comprehensive ~Copyable support using the established dual-extension pattern: base operations in `where Element: ~Copyable` extensions, CoW-aware overloads in `where Element: Copyable` extensions.

#### Constraint Separation Pattern

Every package correctly separates Copyable and ~Copyable concerns:

- **Array**: `Array.Fixed ~Copyable.swift` / `Array.Fixed Copyable.swift` per variant module
- **List**: `List.Linked ~Copyable.swift` / `List.Linked Copyable.swift`
- **Stack**: `Stack ~Copyable.swift` / `Stack Copyable.swift`
- **Queue**: `Queue.Dynamic ~Copyable.swift` / `Queue.Dynamic Copyable.swift`, `Queue.Linked ~Copyable.swift` / `Queue.Linked Copyable.swift`
- **Cyclic**: Not applicable (mathematical types, always Copyable)

#### Conditional Copyable Conformances

All heap-backed types correctly use `extension T: Copyable where Element: Copyable {}`:
- `Array Primitives Core/Array.swift:211-219`
- `Stack Primitives Core/Stack.swift:258-264`
- `Queue Primitives Core/Queue.swift:445-479`
- `List Primitives Core/List.Linked.swift:230-233`

Inline/Small variants are correctly unconditionally ~Copyable (due to deinit requirements).

#### Compiler Bug Workarounds

Types with value generic parameters (`Static<let capacity: Int>`, `Small<let inlineCapacity: Int>`) are correctly declared inside the parent struct body rather than in extensions, with explanatory comments citing the Swift compiler bug:
- `Stack Primitives Core/Stack.swift:78-98` (Stack.Static)
- `Stack Primitives Core/Stack.swift:100-154` (Stack.Small)
- `Queue Primitives Core/Queue.swift:88-117` (Queue.Static)
- `Queue Primitives Core/Queue.swift:119-163` (Queue.Small)
- `Array Primitives Core/Array.swift:131-144` (Array.Static)
- `Array Primitives Core/Array.swift:175-185` (Array.Bounded)

**Verdict: PASS.** ~Copyable support is comprehensive and correctly structured.

---

### 3. Naming Compliance ([API-NAME-001] Nest.Name Pattern)

#### Compliant Names

All primary types follow the Nest.Name pattern:
- `Array`, `Array.Fixed`, `Array.Static`, `Array.Small`, `Array.Bounded`, `Array.Inline`
- `List.Linked<N>`, `List.Linked.Bounded`, `List.Linked.Inline`, `List.Linked.Small`
- `Stack`, `Stack.Bounded`, `Stack.Static`, `Stack.Small`
- `Queue`, `Queue.Fixed`, `Queue.Static`, `Queue.Small`, `Queue.Linked`, `Queue.Linked.Fixed`, `Queue.Linked.Inline`, `Queue.Linked.Small`, `Queue.DoubleEnded`, `Queue.DoubleEnded.Fixed`, `Queue.DoubleEnded.Static`, `Queue.DoubleEnded.Small`
- `Cyclic.Group.Static`, `Cyclic.Group.Static.Element`

#### Naming Inconsistency: `Fixed` vs `Bounded`

There is a naming inconsistency between packages for the fixed-capacity variant concept:

| Package | Fixed-capacity type name | File:Line |
|---------|------------------------|-----------|
| Array | `Array.Fixed` | `Array Primitives Core/Array.swift:101` |
| Stack | `Stack.Bounded` | `Stack Primitives Core/Stack.swift:210` |
| Queue (ring) | `Queue.Fixed` | `Queue Primitives Core/Queue.swift:192` |
| Queue (linked) | `Queue.Linked.Fixed` | `Queue Primitives Core/Queue.swift:289` |
| Queue (deque) | `Queue.DoubleEnded.Fixed` | `Queue Primitives Core/Queue.swift:348` |
| List | `List.Linked.Bounded` | `List Primitives Core/List.Linked.swift:95` |

Stack uses `Bounded` while Array/Queue use `Fixed` for the same concept (a container with a runtime-specified maximum capacity). This should be reconciled.

**Severity: MEDIUM** -- Cross-package inconsistency. Not a Nest.Name violation, but a terminology divergence that will confuse users.

#### Hoisted Error Type Naming

All hoisted error types correctly use the `__` prefix convention and expose Nest.Name typealiases:
- `__StackError<Element>` -> `Stack.Error` at `Stack Primitives Core/Stack.Error.swift:32,163`
- `__QueueError` -> `Queue.Error` at `Queue Primitives Core/Queue.Error.swift:29,147`
- `__ListLinkedError` -> `List.Linked.Error` at `List Primitives Core/List.Linked.Error.swift:30,84`

**Verdict: PASS** on Nest.Name structure. **MEDIUM** on Fixed/Bounded terminology divergence.

---

### 4. Unsafe Pointer Usage

#### Array Iterators (Sanctioned)

Array iterators store `UnsafePointer<Element>` for zero-copy iteration. This matches stdlib `Array.Iterator` semantics and is marked `@safe` at the struct level with `@unsafe` on the init:

- `Array Dynamic Primitives/Array.Dynamic.swift:58` -- `let base: UnsafePointer<Element>`
- `Array Dynamic Primitives/Array.Dynamic.swift:66-68` -- `@unsafe init(base:count:)`
- `Array Fixed Primitives/Array.Fixed ~Copyable.swift:71` -- `let base: UnsafePointer<Element>`
- `Array Fixed Primitives/Array.Fixed ~Copyable.swift:79-81` -- `@unsafe init(base:count:)`

#### Sentinel Pointer for Empty Iterator

Both Array and Array.Fixed use `UnsafePointer<Element>(bitPattern: 1)!` as a sentinel for empty iterators:

- `Array Dynamic Primitives/Array.Dynamic.swift:93` -- `return unsafe Iterator(base: UnsafePointer<Element>(bitPattern: 1)!, count: .zero)`
- `Array Fixed Primitives/Array.Fixed ~Copyable.swift:106` -- `return unsafe Iterator(base: UnsafePointer<Element>(bitPattern: 1)!, count: .zero)`

This is a well-known pattern (null-page sentinel) but should be documented as an explicit design choice.

**Severity: LOW** -- Functional and safe (never dereferenced when count is zero), but could benefit from a named constant.

#### `@_spi(Unsafe)` Escape Hatches

Array.Fixed correctly gates unsafe buffer access behind `@_spi(Unsafe)`:

- `Array Fixed Primitives/Array.Fixed ~Copyable.swift:211-230` -- `withUnsafeBufferPointer` and `withUnsafeMutableBufferPointer` both annotated `@unsafe @_spi(Unsafe)`

#### Queue.DoubleEnded.Accessor `unsafe` Usage

The Property.View.Typed extensions for Queue.DoubleEnded use `unsafe base.pointee` to access the underlying buffer through the property view's raw pointer:

- `Queue DoubleEnded Primitives/Queue.DoubleEnded.Accessor.swift:113-147` (Front accessor)
- `Queue DoubleEnded Primitives/Queue.DoubleEnded.Accessor.swift:185-220` (Back accessor)

This is inherent to the Property.View pattern (pointer-based accessor) and is correctly marked with `unsafe`.

#### Stack/List/Queue Property.View Usage

Similarly, List.Linked uses `unsafe base.pointee` in Property.View.Read.Typed.Valued extensions for peek and reversed access:

- `List Linked Primitives/List.Linked ~Copyable.swift:156-158,179,193,228,247`
- `List Linked Primitives/List.Linked.Bounded.swift:173-174,190,198,233-234,250`

All correctly marked with `unsafe` keyword.

**Verdict: PASS.** No escaped unsafe pointers. Iterator UnsafePointer usage matches stdlib convention. All unsafe access is annotated.

---

### 5. Raw Int Usage (vs Typed Index/Count/Offset)

This is the most significant finding across all packages. Several locations use raw `Int` where typed `Index<Element>.Count` or `Index<Element>` should be used.

#### CRITICAL: List.Linked count/capacity Return Raw Int

```
List Linked Primitives/List.Linked ~Copyable.swift:20
    public var count: Int { Int(bitPattern: _buffer.count) }

List Linked Primitives/List.Linked ~Copyable.swift:28
    public var capacity: Int { Int(bitPattern: _buffer.capacity) }
```

The `_buffer.count` and `_buffer.capacity` return typed `Index<Element>.Count`, but the properties strip the type information via `Int(bitPattern:)`. Compare with Stack Dynamic, where `count` and `capacity` correctly return `Index.Count`:

```
Stack Dynamic Primitives/Stack ~Copyable.swift:20
    public var count: Index.Count { _buffer.count }

Stack Dynamic Primitives/Stack ~Copyable.swift:28
    public var capacity: Index.Count { _buffer.capacity }
```

**Affected locations:**
- `List Linked Primitives/List.Linked ~Copyable.swift:20` -- `count: Int`
- `List Linked Primitives/List.Linked ~Copyable.swift:28` -- `capacity: Int`
- `List Linked Primitives/List.Linked.Bounded.swift:20` -- `count: Int`
- `List Linked Primitives/List.Linked.Small.swift:29` -- `count: Int`

**Severity: HIGH** -- Typed index information is available from the buffer but deliberately erased at the API boundary.

#### CRITICAL: Queue.Linked count/capacity Return Raw Int

Same issue as List.Linked:

- `Queue Linked Primitives/Queue.Linked ~Copyable.swift:20` -- `public var count: Int { Int(bitPattern: _buffer.count) }`
- `Queue Linked Primitives/Queue.Linked ~Copyable.swift:28` -- `public var capacity: Int { Int(bitPattern: _buffer.capacity) }`
- `Queue Linked Primitives/Queue.Linked.Bounded.swift:20` -- `public var count: Int { Int(bitPattern: _buffer.count) }`

**Severity: HIGH** -- Same as List.Linked.

#### CRITICAL: Queue.Linked.Fixed `capacity` Stored as Raw Int

```
Queue Primitives Core/Queue.swift:294
    public let capacity: Int
```

Compare with `Queue.Fixed` which correctly uses typed capacity:

```
Queue Primitives Core/Queue.swift:197
    public let capacity: Index.Count
```

**Severity: HIGH** -- The stored property itself is raw Int, not just the getter.

#### CRITICAL: List.Linked.Bounded `capacity` Stored as Raw Int

```
List Primitives Core/List.Linked.swift:104
    public let capacity: Int
```

**Severity: HIGH** -- Same as Queue.Linked.Fixed.

#### MEDIUM: Queue.Linked init Parameters Use Raw Int

```
Queue Primitives Core/Queue.swift:265
    public init(reservingCapacity capacity: Int) throws(__QueueLinkedError) {

Queue Primitives Core/Queue.swift:301
    public init(capacity: Int) throws(__QueueLinkedBoundedError) {
```

**Severity: MEDIUM** -- init parameters cascade from the stored property type.

#### MEDIUM: List.Linked init Parameter Uses Raw Int

```
List Primitives Core/List.Linked.swift:217
    public init(reservingCapacity capacity: Int) throws(List<Element>.Linked<N>.Error) {

List Primitives Core/List.Linked.swift:111
    public init(capacity: Int) throws(__ListLinkedBoundedError) {
```

**Severity: MEDIUM** -- Same cascade.

#### MEDIUM: Queue.Linked reserve/ensureCapacity Use Raw Int

```
Queue Linked Primitives/Queue.Linked ~Copyable.swift:36
    mutating func _ensureCapacity(_ minimumCapacity: Int) {

Queue Linked Primitives/Queue.Linked ~Copyable.swift:47
    public mutating func reserve(_ minimumCapacity: Int) {
```

**Severity: MEDIUM** -- Internal API propagates raw Int.

#### MEDIUM: List.Linked reserve/ensureCapacity Use Raw Int

```
List Linked Primitives/List.Linked ~Copyable.swift:36
    package mutating func ensureCapacity(_ minimumCapacity: Int) {

List Linked Primitives/List.Linked ~Copyable.swift:47
    public mutating func reserve(_ minimumCapacity: Int) {
```

**Severity: MEDIUM** -- Same as Queue.Linked.

#### MEDIUM: Stack.Static/Small `withElement(at: Int)` Uses Raw Int

```
Stack Static Primitives/Stack.Static ~Copyable.swift:190
    public func withElement<R>(at index: Int, _ body: ...) -> R {

Stack Static Primitives/Stack.Static ~Copyable.swift:224
    public mutating func withMutableElement<R>(at index: Int, _ body: ...) -> R {
```

Note: The same file also has a typed overload `withElement(at index: Stack<Element>.Index, ...)` at line 206. The raw-Int overload is a convenience that performs its own bounds check and creates a typed index internally. This is acceptable as an untyped convenience alongside the typed primary API.

**Severity: LOW** -- Convenience overload alongside typed primary API.

#### LOW: __ArrayStaticError Uses Raw Int in Error Payload

```
Array Primitives Core/Array.Static.Error.swift:24
    case indexOutOfBounds(index: Int, count: Int)
```

Compare with Stack's error types which use typed payloads:

```
Stack Primitives Core/Stack.Error.swift:38-39
    public let index: Index_Primitives.Index<Element>
    public let count: Index_Primitives.Index<Element>.Count
```

**Severity: MEDIUM** -- Error payload should carry typed index information for consistency with Stack.

#### Mixed: List.Linked.Small `capacity` Returns Typed But `count` Returns Raw

```
List Linked Primitives/List.Linked.Small.swift:29
    public var count: Int { Int(bitPattern: _buffer.count) }

List Linked Primitives/List.Linked.Small.swift:37
    public var capacity: Index<Element>.Count { _buffer.capacity }
```

The capacity is typed but count is raw Int -- inconsistent within the same type.

**Severity: HIGH** -- Internal inconsistency within a single type's API.

**Verdict: FAIL.** Linked variants (List.Linked, Queue.Linked) systematically erase typed index information. This is the primary remediation target.

---

### 6. Error Handling (Typed Throws)

All packages use typed throws throughout. Every throwing function specifies an explicit error type.

#### Correct Typed Throws Examples

- `Stack Static Primitives/Stack.Static ~Copyable.swift:45` -- `throws(__StackStaticError<Element>)`
- `Queue Primitives Core/Queue.swift:265` -- `throws(__QueueLinkedError)`
- `List Linked Primitives/List.Linked.Bounded.swift:41` -- `throws(__ListLinkedBoundedError)`
- `List Linked Primitives/List.Linked ~Copyable.swift:102` -- `throws(List<Element>.Linked<N>.Error)`

#### BUG: Queue.DoubleEnded `pop()` Throws Wrong Error Case

The `pop()` methods on Queue.DoubleEnded front/back accessors throw `.invalidCapacity` when they mean "empty":

```
Queue DoubleEnded Primitives/Queue.DoubleEnded.Accessor.swift:132-135
    public func pop() throws(__QueueDoubleEndedError) -> Element {
        guard !(unsafe base.pointee.isEmpty) else {
            throw .invalidCapacity // Using existing error case for empty
        }

Queue DoubleEnded Primitives/Queue.DoubleEnded.Accessor.swift:205-208
    public func pop() throws(__QueueDoubleEndedError) -> Element {
        guard !(unsafe base.pointee.isEmpty) else {
            throw .invalidCapacity // Using existing error case for empty
        }
```

The `__QueueDoubleEndedError` type only has `.invalidCapacity` (no `.empty` case):

```
Queue Primitives Core/Queue.Error.swift:100-103
    public enum __QueueDoubleEndedError: Swift.Error, Sendable, Equatable {
        case invalidCapacity
    }
```

This is a semantic error. The error communicates "invalid capacity" when the actual condition is "queue is empty." The fix is to add an `.empty` case to `__QueueDoubleEndedError`.

**Severity: HIGH** -- Wrong error semantics. Users catching `.invalidCapacity` would misinterpret the failure.

#### Hoisted Error Pattern

All error types use the established hoisted pattern with `__` prefix and typealiases. This is consistently applied across all packages:

- **Stack**: 4 error enums with generic parameter `<Element: ~Copyable>` and nested `Bounds` structs at `Stack Primitives Core/Stack.Error.swift:32-153`
- **Queue**: 11 error enums (non-generic) at `Queue Primitives Core/Queue.Error.swift:29-131`
- **List**: 4 error enums (non-generic) at `List Primitives Core/List.Linked.Error.swift:30-69`
- **Array**: 1 error enum at `Array Primitives Core/Array.Static.Error.swift:19-25`

Note: Stack error types are generic (`__StackError<Element: ~Copyable>`) to carry typed `Index<Element>` payloads. Queue and List error types are non-generic (no index payloads). This is an intentional design difference based on what information each error carries.

**Verdict: MOSTLY PASS.** Typed throws used throughout. One semantic bug in Queue.DoubleEnded error case.

---

### 7. One Type Per File ([API-IMPL-005])

This section documents violations of the one-type-per-file rule. Note that many of these violations are forced by Swift compiler limitations with ~Copyable constraint propagation -- nested types with value generics must be declared inside the parent struct body, and error types are hoisted to module level.

#### Queue.swift: 12+ Type Declarations in One File

`Queue Primitives Core/Queue.swift` (593 lines) declares:

| Type | Line |
|------|------|
| `Queue` | 83 |
| `Queue.Static` | 99 |
| `Queue.Small` | 148 |
| `Queue.Fixed` | 192 |
| `Queue.Linked` | 249 |
| `Queue.Linked.Fixed` | 289 |
| `Queue.Linked.Inline` | 515 |
| `Queue.Linked.Small` | 552 |
| `Queue.DoubleEnded` | 321 |
| `Queue.DoubleEnded.Fixed` | 348 |
| `Queue.DoubleEnded.Static` | 371 |
| `Queue.DoubleEnded.Small` | 399 |
| `Queue.DoubleEnded.Position` | 327 |

**Severity: HIGH** -- This is the most extreme violation. Even accounting for compiler workarounds, this file does too much. The Linked and DoubleEnded variant families could potentially be separate files if the compiler bug is resolved.

**Mitigation**: The file includes extensive comments explaining why types are declared inside the body rather than in extensions (Swift compiler bug with ~Copyable in extensions for types with value generics). This is a known limitation.

#### Stack.swift: 4 Type Declarations

`Stack Primitives Core/Stack.swift` (281 lines) declares:

| Type | Line |
|------|------|
| `Stack` | 73 |
| `Stack.Static` | 89 |
| `Stack.Small` | 141 |
| `Stack.Bounded` | 210 |

**Severity: MEDIUM** -- Same compiler workaround as Queue, but smaller scope.

#### Array.swift: 6 Type Declarations

`Array Primitives Core/Array.swift` (226 lines) declares:

| Type | Line |
|------|------|
| `Array` | 49 |
| `Array.Fixed` | 101 |
| `Array.Static` | 131 |
| `Array.Bounded` | 175 |
| `Array.Inline` (typealias) | 201 |

**Severity: MEDIUM** -- Same compiler workaround.

#### List.Linked.swift: 5 Type Declarations

`List Primitives Core/List.Linked.swift` (244 lines) declares:

| Type | Line |
|------|------|
| `List.Linked` | 69 |
| `List.Linked.Bounded` | 95 |
| `List.Linked.Inline` | 145 |
| `List.Linked.Small` | 185 |

**Severity: MEDIUM** -- Same compiler workaround.

#### Error Files: Multiple Types Per File

All error files contain multiple error enum declarations:

| File | Type Count |
|------|-----------|
| `Queue Primitives Core/Queue.Error.swift` | 11 enums + typealiases |
| `Stack Primitives Core/Stack.Error.swift` | 4 enums + 4 Bounds structs + typealiases |
| `List Primitives Core/List.Linked.Error.swift` | 4 enums + typealiases |

**Severity: LOW** -- Error types are small, closely related, and benefit from co-location. The hoisted pattern makes splitting impractical since typealiases must be in the same module as the struct body.

#### Bounded/Inline/Small Operation Files

Several files contain extensions for multiple related operations of a single type, which is fine. However, some files mix operations for multiple types:

- `Queue Linked Primitives/Queue.Linked.Inline+Small.swift` -- Extensions for both `Queue.Linked.Inline` and `Queue.Linked.Small` in one file.
- `Queue Linked Primitives/Queue.Linked.Bounded.swift` -- Contains Iterator, Equatable, Hashable, Sendable conformances and Error typealiases for both `Queue.Linked` and `Queue.Linked.Fixed`.

**Severity: LOW** -- These are extension files, not type declarations.

**Verdict: FAIL (with mitigating factors).** The violations are primarily forced by Swift compiler limitations with ~Copyable constraint propagation for value-generic nested types. Queue.swift at 593 lines and 12+ types is the most concerning. When the compiler bug is resolved, these should be refactored into separate files.

---

### 8. Foundation Imports

No Foundation imports were found in any of the five packages. Every file imports only:

- Buffer primitives (`Buffer_Primitives`, `Buffer_Linear_Primitives`, `Buffer_Linked_Primitives`)
- Index primitives (`Index_Primitives`)
- Collection/Sequence primitives
- Property primitives
- Other tier-appropriate primitives

**Verdict: PASS.** Zero Foundation imports.

---

## Additional Findings

### CRITICAL: Stack ~Copyable `compact()` is a No-Op

```
Stack Dynamic Primitives/Stack ~Copyable.swift:166-178
    public mutating func compact() {
        let currentCount = _buffer.count
        guard _buffer.capacity > currentCount else { return }

        let newBuffer = Buffer<Element>.Linear(minimumCapacity: currentCount)
        // Move elements from old buffer to new — need to iterate
        // Since Buffer.Linear doesn't have a direct move-from-other,
        // we rebuild by removing from old and appending to new.
        // However, Buffer.Linear auto-handles this via removeAll + init.
        // Actually, compact for ~Copyable is complex. Let's just leave it
        // as a no-op if we can't easily move. The Copyable version handles it.
        _ = newBuffer
    }
```

This method creates a new buffer, discards it, and returns without actually compacting anything. The TODO comment explains the difficulty of moving ~Copyable elements between buffers. Either:
1. Implement the move properly using `Buffer.Linear`'s move semantics, or
2. Remove the method from the ~Copyable API and only provide it for Copyable elements.

**Severity: CRITICAL** -- Public API that silently does nothing. Users calling `compact()` on a ~Copyable stack will believe memory was freed.

### HIGH: Stack Duplicate Subscripts (Potential Ambiguity)

```
Stack Dynamic Primitives/Stack.Index.swift:19-35
    extension Stack where Element: ~Copyable {
        public subscript(index: Index) -> Element {
            _read { ... }
            _modify { ... }
        }
    }

Stack Dynamic Primitives/Stack.Index.swift:37-53
    extension Stack where Element: Copyable {
        public subscript(index: Index) -> Element {
            _read { ... }
            _modify { ... }
        }
    }
```

Both the ~Copyable and Copyable extensions define identical `subscript(index:)` with the same body. For Copyable elements, the compiler must resolve which overload to use. The Copyable overload should include CoW `_makeUnique()` if it exists, otherwise the duplication is unnecessary.

**Severity: HIGH** -- Duplicate definitions without behavioral difference; the Copyable overload does not call `_makeUnique()` and is therefore redundant.

### HIGH: Stack Iterator Copies All Elements to Swift.Array

```
Stack Dynamic Primitives/Stack Copyable.swift:109
    var _elements: [Element]

Stack Dynamic Primitives/Stack Copyable.swift:134-145
    public borrowing func makeIterator() -> Iterator {
        var elements: [Element] = []
        elements.reserveCapacity(Int(bitPattern: _buffer.count))
        var idx: Index = .zero
        let end = _buffer.count.map(Ordinal.init)
        while idx < end {
            elements.append(_buffer[idx])
            idx += .one
        }
        return Iterator(elements: elements)
    }
```

Unlike Array's zero-copy `UnsafePointer`-based iterator, Stack's iterator copies all elements into a `Swift.Array`. This is O(n) in both time and space on iteration start. Consider using a pointer-based iterator like Array does, or using the buffer's span for iteration.

**Severity: MEDIUM** -- Performance concern, not correctness. The Stack could use the same `UnsafePointer`-based iterator pattern as Array.

### MEDIUM: Array Primitives Umbrella Missing Bounded Module

```
Array Primitives/exports.swift:5-9
    @_exported public import Array_Primitives_Core
    @_exported public import Array_Dynamic_Primitives
    @_exported public import Array_Fixed_Primitives
    @_exported public import Array_Static_Primitives
    @_exported public import Array_Small_Primitives
```

Missing: `@_exported public import Array_Bounded_Primitives`

Users importing `Array_Primitives` will not get `Array.Bounded` functionality.

**Severity: MEDIUM** -- Incomplete umbrella module.

### LOW: Queue.Static `_deinitWorkaround` Field

```
Queue Primitives Core/Queue.swift:107-108
    @usableFromInline
    var _deinitWorkaround: AnyObject? = nil
```

This is a workaround for a Swift compiler bug (https://github.com/swiftlang/swift/issues/86652) where deinit element cleanup fails for ~Copyable structs with only value-type properties. The field adds 8 bytes per instance. Documented and acceptable as a workaround, but should be tracked for removal when the bug is fixed.

**Severity: LOW** -- Known workaround with issue tracking.

### LOW: Array.Static.Error File Header

```
Array Primitives Core/Array.Static.Error.swift:1-6
    //
    //  File.swift
    //  swift-array-primitives
    //
    //  Created by Coen ten Thije Boonkkamp on 23/01/2026.
    //
```

This file uses the Xcode auto-generated header ("File.swift") instead of the standard project header used everywhere else. Cosmetic issue.

**Severity: LOW** -- Inconsistent file header.

---

## Summary Table

| Dimension | Array | List | Stack | Queue | Cyclic |
|-----------|-------|------|-------|-------|--------|
| Buffer Integration | PASS | PASS | PASS | PASS | N/A |
| ~Copyable Support | PASS | PASS | PASS | PASS | N/A |
| Naming (Nest.Name) | PASS | PASS | PASS | PASS | PASS |
| Unsafe Pointers | PASS | PASS | PASS | PASS | N/A |
| Raw Int Usage | LOW | **HIGH** | LOW | **HIGH** | PASS |
| Error Handling | PASS | PASS | PASS | **HIGH** | N/A |
| One Type Per File | MEDIUM | MEDIUM | MEDIUM | **HIGH** | PASS |
| Foundation Imports | PASS | PASS | PASS | PASS | PASS |

---

## Outcome

**Status**: DECISION

### Priority Remediation List

#### CRITICAL (Must Fix)

1. **Stack ~Copyable `compact()` no-op** -- Either implement properly or remove from ~Copyable API.
   - File: `Stack Dynamic Primitives/Stack ~Copyable.swift:166-178`

2. **Queue.DoubleEnded `pop()` throws `.invalidCapacity` for empty** -- Add `.empty` case to `__QueueDoubleEndedError`.
   - Files: `Queue DoubleEnded Primitives/Queue.DoubleEnded.Accessor.swift:132-135,205-208` and `Queue Primitives Core/Queue.Error.swift:100-103`

#### HIGH (Should Fix)

3. **List.Linked count/capacity return raw Int** -- Change to `Index<Element>.Count`.
   - Files: `List Linked Primitives/List.Linked ~Copyable.swift:20,28`, `List.Linked.Bounded.swift:20`, `List.Linked.Small.swift:29`

4. **Queue.Linked count/capacity return raw Int** -- Change to `Index<Element>.Count`.
   - Files: `Queue Linked Primitives/Queue.Linked ~Copyable.swift:20,28`, `Queue.Linked.Bounded.swift:20`

5. **Queue.Linked.Fixed and List.Linked.Bounded `capacity` stored as raw Int** -- Change stored property to `Index<Element>.Count`.
   - Files: `Queue Primitives Core/Queue.swift:294`, `List Primitives Core/List.Linked.swift:104`

6. **Stack duplicate subscripts** -- Remove redundant Copyable overload or add CoW semantics.
   - File: `Stack Dynamic Primitives/Stack.Index.swift:37-53`

7. **List.Linked.Small inconsistent count/capacity types** -- `count` returns `Int`, `capacity` returns `Index<Element>.Count`.
   - File: `List Linked Primitives/List.Linked.Small.swift:29,37`

#### MEDIUM (Should Consider)

8. **Fixed vs Bounded naming inconsistency** -- Reconcile across Array/Stack/Queue/List.

9. **Array Primitives umbrella missing Bounded** -- Add `Array_Bounded_Primitives` to exports.
   - File: `Array Primitives/exports.swift`

10. **Stack iterator copies all elements** -- Consider pointer-based iterator.
    - File: `Stack Dynamic Primitives/Stack Copyable.swift:107-145`

11. **__ArrayStaticError uses raw Int in error payload** -- Use typed index like Stack errors.
    - File: `Array Primitives Core/Array.Static.Error.swift:24`

12. **Queue.Linked/List.Linked init/reserve parameters use raw Int** -- Cascade from stored property fix.

#### LOW (Track)

13. **Array iterator sentinel pointer** -- Document `UnsafePointer(bitPattern: 1)!` convention.
14. **Queue.Static `_deinitWorkaround`** -- Track upstream bug fix.
15. **Array.Static.Error file header** -- Replace with standard project header.
16. **One-type-per-file violations** -- Track Swift compiler bug resolution for refactoring.

## References

- Buffer Primitives: `/Users/coen/Developer/swift-primitives/swift-buffer-primitives/`
- Storage Primitives: `/Users/coen/Developer/swift-primitives/swift-storage-primitives/`
- Memory Primitives: `/Users/coen/Developer/swift-primitives/swift-memory-primitives/`
- Index Primitives: `/Users/coen/Developer/swift-primitives/swift-index-primitives/`
- Swift compiler bug (value generic ~Copyable): Referenced in source comments
- Swift compiler bug (deinit cleanup): https://github.com/swiftlang/swift/issues/86652
