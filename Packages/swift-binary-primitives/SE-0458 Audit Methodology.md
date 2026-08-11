# SE-0458 Strict Memory Safety: Audit Methodology
<!--
---
version: 1.0.0
last_updated: 2026-01-15
status: COMPLETE
---
-->

> A comprehensive reference for auditing Swift packages against SE-0458 strict memory safety standards.
> This document is self-contained and can be used by any agent to perform a strict memory safety audit.

---

## Abstract

Swift 6.2 introduces SE-0458, an opt-in strict memory safety mode that identifies all uses of unsafe constructs at compile time. This paper provides: (1) a complete technical overview of the strict memory safety model, (2) the semantic meaning of `@unsafe`, `@safe`, and `unsafe` expressions, (3) a systematic audit methodology, and (4) resolution patterns for common warnings. The goal is to enable any Swift package to achieve full SE-0458 compliance with zero warnings.

---

## 1. Swift's Memory Safety Model

### 1.1 Five Dimensions of Memory Safety

| Dimension | Mechanism | Default in Swift |
|-----------|-----------|------------------|
| **Lifetime Safety** | ARC, memory exclusivity | Yes |
| **Bounds Safety** | Runtime bounds checking | Yes |
| **Type Safety** | Safe casting operators | Yes |
| **Initialization Safety** | Definite initialization | Yes |
| **Thread Safety** | Strict concurrency (Swift 6) | Opt-in |

SE-0458 adds a sixth dimension: **explicit unsafe acknowledgment**—requiring developers to mark all unsafe operations with the `unsafe` keyword.

### 1.2 Design Philosophy

SE-0458 follows the principle: **"Safe by default, unsafe by explicit acknowledgment."**

Key design decisions:
- `unsafe` is an **expression-level** keyword (narrower scope than Rust's blocks)
- Unsafety does **not propagate** through function boundaries
- A `@safe` function may contain `unsafe` expressions internally
- No ABI impact—purely compile-time

---

## 2. Enabling Strict Memory Safety

### 2.1 Package.swift Configuration

```swift
let settings: [SwiftSetting] = [
    .strictMemorySafety(),
]

for target in package.targets {
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
```

### 2.2 Compiler Flag

```bash
swiftc -strict-memory-safety source.swift
```

### 2.3 Conditional Compilation

```swift
#if hasFeature(StrictMemorySafety)
// Strict mode specific code
#endif
```

---

## 3. The Three Safety Annotations

### 3.1 `@unsafe` — Marks Unsafe Declarations

**Meaning:** "This declaration is unsafe to use. Callers must acknowledge with `unsafe`."

```swift
@unsafe
public func dangerousOperation(_ ptr: UnsafeMutablePointer<Int>) { ... }

// Call site requires acknowledgment:
unsafe dangerousOperation(ptr)
```

**Use on:**
- Functions/methods that expose raw pointers
- Types that exist as escape hatches to unsafe APIs
- Computed properties returning unsafe types

### 3.2 `@safe` — Marks Safe Encapsulation

**Meaning:** "This declaration is safe despite having unsafe types in its implementation or signature."

```swift
@safe
public struct SecureBuffer {
    private var storage: UnsafeMutableBufferPointer<UInt8>

    public subscript(index: Int) -> UInt8 {
        // Bounds-checked access - safe
        precondition(index >= 0 && index < count)
        return storage[index]
    }
}
```

**Use on:**
- Types that encapsulate unsafe storage behind a safe API
- Functions that handle unsafe types internally but provide safety guarantees

### 3.3 `unsafe` Expression — Acknowledges Unsafe Operations

**Meaning:** "I acknowledge this operation is unsafe and take responsibility."

```swift
let value = unsafe ptr.pointee
unsafe destination.copyMemory(from: source, byteCount: count)
```

**Syntax rules:**
- Applies to the immediately following expression
- Cannot appear to the right of non-assignment operators
- Can wrap method calls, property accesses, or assignments

---

## 4. What Triggers Unsafe Diagnostics

### 4.1 Standard Library Unsafe Types

All of these are marked `@unsafe`:
- `UnsafePointer<T>`, `UnsafeMutablePointer<T>`
- `UnsafeRawPointer`, `UnsafeMutableRawPointer`
- `UnsafeBufferPointer<T>`, `UnsafeMutableBufferPointer<T>`
- `UnsafeRawBufferPointer`, `UnsafeMutableRawBufferPointer`
- `Unmanaged<T>`
- `UnsafeContinuation`

### 4.2 Unsafe Operations

- `unsafeBitCast(_:to:)`
- `unsafeDowncast(_:to:)`
- `withUnsafePointer(to:_:)` (the closure body may need `unsafe`)
- `withUnsafeBytes(of:_:)` (the closure body may need `unsafe`)
- `.load(as:)` on raw pointers
- `.copyMemory(from:byteCount:)`
- `.initializeMemory(as:repeating:count:)`

### 4.3 Unsafe Language Constructs

- `@unchecked Sendable`
- `unowned(unsafe)`
- `nonisolated(unsafe)`

### 4.4 Unsafe Protocol Conformances

Some protocol conformances on unsafe types are marked `@unsafe`:
```swift
// UnsafeRawBufferPointer's Collection conformance is @unsafe
// Therefore:
guard unsafe !buffer.isEmpty else { return }  // Required
let count = buffer.count  // Safe (property access, not protocol method)
```

---

## 5. Safe Alternatives

### 5.1 `Span<T>` (SE-0447)

The safe replacement for `UnsafeBufferPointer<T>`:

```swift
// Unsafe (old pattern)
func process(_ buffer: UnsafeBufferPointer<UInt8>) { ... }

// Safe (new pattern)
func process(_ span: Span<UInt8>) { ... }
```

**Properties:**
- Non-escapable (`~Escapable`) — cannot outlive source
- Bounds-checked with zero runtime overhead
- Compiler-enforced lifetime safety

### 5.2 `MutableSpan<T>`

The safe replacement for `UnsafeMutableBufferPointer<T>`.

### 5.3 Lifetime Annotations

```swift
public var bytes: Span<UInt8> {
    @_lifetime(borrow self)  // Span lifetime tied to self
    borrowing get { ... }
}

public var mutableBytes: MutableSpan<UInt8> {
    @_lifetime(&self)  // MutableSpan lifetime tied to mutation
    mutating get { ... }
}
```

---

## 6. Legacy Pattern → Modern Replacement

**Goal:** Before marking unsafe code with `unsafe`, first evaluate whether it can be replaced with safe `Span`-based alternatives. This reduces the unsafe surface area rather than just acknowledging it.

### 6.1 API Surface Transformations

| Legacy Pattern | Modern Replacement | Notes |
|----------------|-------------------|-------|
| `withUnsafeBufferPointer { }` | `.span` property | Direct property access, no closure |
| `withUnsafeMutableBufferPointer { }` | `.mutableSpan` property | Direct property access, no closure |
| `func f(_ p: UnsafeBufferPointer<T>)` | `func f(_ s: Span<T>)` | Parameter type change |
| `func f(_ p: UnsafeRawBufferPointer)` | `func f(_ s: Span<UInt8>)` | Or `RawSpan` if untyped |
| `func f(_ p: UnsafeMutableBufferPointer<T>)` | `func f(_ s: inout MutableSpan<T>)` | Note: `inout` for mutation |
| `UnsafeBufferPointer<T>` return | `Span<T>` return + `@_lifetime` | Requires lifetime annotation |
| Closure-based access | Property-based access | Eliminates callback pattern |

### 6.2 Internal Implementation Transformations

| Legacy Pattern | Modern Replacement |
|----------------|-------------------|
| `array.withUnsafeBufferPointer { $0.baseAddress! }` | `array.span` (use Span directly) |
| `data.withUnsafeBytes { ptr in ... }` | `data.span.withUnsafeBytes { ... }` or use Span API |
| Manual pointer arithmetic | `Span.extracting(_:)` for slicing |
| `ptr.load(as: T.self)` | Type-safe Span subscript |
| `ptr.advanced(by: n)` | `span.extracting(n...)` |

### 6.3 Protocol Conformance Evolution

**Before (unsafe-based):**
```swift
public protocol Contiguous {
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
}
```

**After (Span-based):**
```swift
public protocol Contiguous: ~Copyable {
    /// Normative API - safe, compiler-enforced lifetime
    var bytes: Span<UInt8> { get }
}

extension Contiguous where Self: ~Copyable {
    /// Escape hatch - only when Span insufficient
    @unsafe
    var withBytes: WithBytes { get }
}
```

### 6.4 Lifetime Annotations for Span Properties

When adding Span properties, always include lifetime annotations:

```swift
public var bytes: Span<UInt8> {
    @_lifetime(borrow self)
    borrowing get {
        // Return Span tied to self's lifetime
    }
}

public var mutableBytes: MutableSpan<UInt8> {
    @_lifetime(&self)
    mutating get {
        // Return MutableSpan tied to mutation scope
    }
}
```

### 6.5 When to Keep Unsafe APIs

Keep `withUnsafe*` patterns as `@unsafe` escape hatches when:

1. **C interop** — Calling C functions that require raw pointers
2. **Performance-critical paths** — Where Span overhead matters (rare)
3. **Pointer arithmetic** — Complex offset calculations not expressible with Span
4. **Untyped memory** — When `RawSpan` is insufficient
5. **Legacy compatibility** — Gradual migration of existing callers

### 6.6 Migration Strategy

**Phase 0: Identify candidates**
```bash
# Find all withUnsafe* usage
grep -rn "withUnsafe" Sources/
grep -rn "UnsafeBufferPointer\|UnsafeRawBufferPointer" Sources/
```

**Phase 1: Add Span properties (additive)**
- Add `bytes: Span<UInt8>` alongside existing unsafe APIs
- Add `mutableBytes: MutableSpan<UInt8>` for mutable access
- Mark as normative in documentation

**Phase 2: Deprecate unsafe APIs (if appropriate)**
- Add `@available(*, deprecated, renamed: "bytes")` to old APIs
- Or keep both: Span as normative, unsafe as escape hatch

**Phase 3: Update internal implementations**
- Migrate internal code to use Span
- Reduce `unsafe` expression count

### 6.7 Example: Array Extension Migration

**Before:**
```swift
extension Array where Element == UInt8 {
    func process() {
        self.withUnsafeBufferPointer { buffer in
            guard let ptr = buffer.baseAddress else { return }
            // ... use ptr
        }
    }
}
```

**After:**
```swift
extension Array where Element == UInt8 {
    func process() {
        let span = self.span
        // ... use span directly, bounds-checked
    }
}
```

### 6.8 Span API Quick Reference

| Span Method | Unsafe Equivalent |
|-------------|-------------------|
| `span[i]` | `ptr[i]` (bounds-checked) |
| `span.extracting(range)` | `UnsafeBufferPointer(rebasing: ptr[range])` |
| `span.count` | `ptr.count` |
| `span.isEmpty` | `ptr.isEmpty` |
| `span.first` / `span.last` | `ptr.first` / `ptr.last` |
| `for element in span` | `for element in ptr` |
| `span.withUnsafeBufferPointer { }` | Direct pointer access (escape hatch) |

### 6.9 Architectural Target

The ideal architecture after migration:

```
┌─────────────────────────────────────────────────────────────┐
│                    PUBLIC API (Safe)                        │
│  bytes: Span<UInt8>           ← Normative read access       │
│  mutableBytes: MutableSpan    ← Normative write access      │
│  subscript[i]: Element        ← Bounds-checked element      │
│  subscript[range]: Span       ← Bounds-checked slice        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 ESCAPE HATCH (@unsafe)                      │
│  withBytes { UnsafeRawBufferPointer }  ← C interop only     │
│  Clearly marked, documented, discouraged                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Audit Methodology

### Phase 0: Span Migration Review (BEFORE enabling strict mode)

Before adding `unsafe` markers, identify opportunities to eliminate unsafe code entirely:

```bash
# Count unsafe API surface
grep -rn "UnsafeBufferPointer\|UnsafeRawBufferPointer\|withUnsafe" Sources/ | wc -l

# Identify public API exposure
grep -rn "public.*Unsafe" Sources/
```

For each unsafe API, ask:
1. Can this be replaced with `Span<T>`?
2. Is this an internal implementation detail or public API?
3. If public, should Span be the normative API with unsafe as escape hatch?

### Phase 1: Enable Strict Mode and Capture Warnings

```bash
# Add .strictMemorySafety() to Package.swift, then:
swift build 2>&1 | tee build-warnings.txt
grep -E "warning.*unsafe|error.*unsafe" build-warnings.txt
```

### Phase 2: Categorize Warnings

| Warning Pattern | Category | Action |
|-----------------|----------|--------|
| "expression uses unsafe constructs but is not marked with 'unsafe'" | Missing acknowledgment | Add `unsafe` |
| "no unsafe operations occur within 'unsafe' expression" | Over-specification | Remove `unsafe` |
| "reference to unsafe type 'UnsafeXXX'" | Type reference | Add `unsafe` to assignment |
| "'@unsafe' conformance of X to protocol Y" | Protocol conformance | Add `unsafe` to call |

### Phase 3: Apply Resolution Patterns

See Section 7 for detailed patterns.

### Phase 4: Type-Level Annotations

Decide whether types need `@unsafe` or `@safe`:

| Scenario | Annotation |
|----------|------------|
| Type deliberately exposes unsafe operations | `@unsafe struct/class` |
| Type has safe API over unsafe storage | `@safe struct` + `@unsafe` internal members |
| Internal enum with unsafe cases | `@unsafe enum` |

### Phase 5: Verify

```bash
swift build  # Should complete with zero warnings
swift test   # Should pass (no behavioral changes)
```

---

## 8. Warning Resolution Patterns

### Pattern A: Calling `@unsafe` Method

```swift
// Warning: expression uses unsafe constructs
destination.withBytes.mutable { ptr in ... }

// Resolution: Add unsafe
unsafe destination.withBytes.mutable { ptr in ... }
```

### Pattern B: Assigning Unsafe Type

```swift
// Warning: reference to let 'srcBase' involves unsafe type
let srcPtr = srcBase  // srcBase is UnsafeRawPointer

// Resolution: Add unsafe to assignment
let srcPtr = unsafe srcBase
```

### Pattern C: Unsafe Protocol Conformance

```swift
// Warning: '@unsafe' conformance of 'UnsafeRawBufferPointer' to 'Collection'
guard !source.isEmpty else { return }

// Resolution: Add unsafe
guard unsafe !source.isEmpty else { return }
```

### Pattern D: Over-specified Unsafe (Remove It)

```swift
// Warning: no unsafe operations occur within 'unsafe' expression
unsafe outer.method { inner in
    let count = unsafe inner.count  // count is just Int, safe
}

// Resolution: Remove inner unsafe
unsafe outer.method { inner in
    let count = inner.count
}
```

### Pattern E: Arithmetic with Unsafe Types

```swift
// Error: 'unsafe' cannot appear to the right of a non-assignment operator
offset + unsafe source.count

// Resolution: Extract to variable first
let sourceCount = source.count  // If .count is safe property
offset + sourceCount

// OR if truly unsafe:
let sourceCount = unsafe source.count
offset + sourceCount
```

### Pattern F: Unsafe Span Creation

```swift
// Warning: call to '@unsafe' initializer
let span = Span(_unsafeElements: bufferPointer)

// Resolution:
let span = unsafe Span(_unsafeElements: bufferPointer)
```

### Pattern G: Memory Operations

```swift
// Warning: call to '@unsafe' method
dstBase.copyMemory(from: srcPtr, byteCount: count)

// Resolution:
unsafe dstBase.copyMemory(from: srcPtr, byteCount: count)
```

### Pattern H: Assignment to Unsafe Property

```swift
// Warning: reference to property 'storage' involves unsafe type
self.storage = unsafe UnsafeMutablePointer<Element>.allocate(...)

// Wrong: unsafe on RHS only
self.storage = unsafe pointer  // Still warns about self.storage

// Correct: unsafe wraps the entire assignment
unsafe self.storage = pointer
```

**Key insight:** When assigning to a stored property of unsafe type, the assignment expression itself is unsafe. Wrap the entire statement with `unsafe`, not just the RHS.

### Pattern I: Allocation Return Values

```swift
// Warning: no unsafe operations occur within 'unsafe' expression
let storage = unsafe UnsafeMutablePointer<Element>.allocate(capacity: n)

// Resolution: Remove unsafe from allocation (it's safe)
let storage = UnsafeMutablePointer<Element>.allocate(capacity: n)
unsafe self.storage = storage  // Assignment needs unsafe instead
```

**Key insight:** `.allocate()` is not itself unsafe—it just returns an unsafe type. The subsequent assignment or usage needs `unsafe`, not the allocation call.

---

## 9. Type Annotation Guidelines

### 9.1 When to Use `@unsafe struct`

Use when the type **is an escape hatch** to unsafe operations:

```swift
@unsafe
public struct WithBytes: ~Copyable, ~Escapable {
    let pointer: UnsafePointer<UInt8>
    let count: Int

    @unsafe
    public borrowing func callAsFunction<R>(
        _ body: (UnsafeRawBufferPointer) throws -> R
    ) rethrows -> R {
        // Exposes raw pointer to caller
    }
}
```

### 9.2 When to Use `@safe struct`

Use when the type **encapsulates** unsafe storage in a safe interface.

**Important:** Prefer `@safe struct` with `@unsafe` escape hatch methods over `@unsafe struct` in most cases.

**Why:** Marking an entire struct `@unsafe` makes `self` an unsafe type. Every access to `self`—including `self.capacity`, `precondition(...)`, and other safe operations—triggers warnings inside the type's own methods. This creates excessive noise.

```swift
// Problematic: @unsafe on struct
@unsafe
public struct Slab<Element> {
    var storage: UnsafeMutablePointer<Element>
    let capacity: Int

    func foo() {
        // Warning: reference to 'self' involves unsafe type
        precondition(index < capacity)  // Warns! self.capacity is "unsafe"
    }
}

// Better: @safe struct with @unsafe escape hatches
@safe
public struct Slab<Element> {
    var storage: UnsafeMutablePointer<Element>
    let capacity: Int

    func foo() {
        precondition(index < capacity)  // No warning
        unsafe (storage + index).initialize(to: value)  // Only actual unsafe ops marked
    }

    @unsafe  // Escape hatch - exposes pointer to caller
    func withUnsafePointer(_ body: (UnsafePointer<Element>) -> R) -> R { ... }
}
```

```swift
@safe
public struct Input: @unchecked Sendable {
    @unsafe
    internal enum Storage {
        case owned([UInt8])
        case borrowed(UnsafeBufferPointer<UInt8>)
    }

    internal var storage: Storage

    // Public API is safe - bounds checked, no pointer exposure
    public subscript(offset: Int) -> UInt8 {
        precondition(offset >= 0 && offset < count)
        // ... safe access
    }
}
```

### 9.3 `@unsafe` Internal Enum

When an enum has cases containing unsafe types:

```swift
@unsafe
internal enum Storage {
    case owned([UInt8])                      // Safe
    case borrowed(UnsafeBufferPointer<UInt8>) // Unsafe
}
```

Accessing this enum requires `unsafe` even for the safe case, because the compiler cannot know which case is active.

---

## 10. Best Practices

### 10.1 Architecture: Safe-First Design

```
┌─────────────────────────────────────────┐
│           Public API (Safe)             │
│  - Span<T> for read access              │
│  - MutableSpan<T> for write access      │
│  - Bounds-checked subscripts            │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│        Escape Hatch (@unsafe)           │
│  - withBytes { UnsafeRawBufferPointer } │
│  - Clearly marked, documented           │
└─────────────────────────────────────────┘
```

### 10.2 Naming Convention

Avoid `unsafe` or `Unsafe` in identifiers—rely on language semantics:

```swift
// Avoid
func unsafeGetPointer() -> UnsafePointer<UInt8>

// Prefer
@unsafe
var withBytes: WithBytes { get }  // Type is @unsafe, not the name
```

### 10.3 Documentation

Document safety contracts:

```swift
/// Provides unsafe access to the underlying buffer.
///
/// - Warning: The pointer must not escape the closure scope.
/// - Precondition: `range` must be within bounds.
@unsafe
public borrowing func callAsFunction<R>(
    in range: Range<Int>,
    _ body: (UnsafeRawBufferPointer) throws -> R
) rethrows -> R
```

---

## 11. Audit Checklist

Use this checklist when auditing a package:

```
[ ] 1. Add .strictMemorySafety() to Package.swift
[ ] 2. Run swift build and capture all warnings
[ ] 3. Categorize warnings by type (see Section 6.2)
[ ] 4. Apply resolution patterns (see Section 7)
[ ] 5. Decide type-level annotations (@unsafe/@safe)
[ ] 6. Verify: swift build has zero warnings
[ ] 7. Verify: swift test passes
[ ] 8. Review @unchecked Sendable usages
[ ] 9. Document any @safe(unchecked) decisions
```

---

## 12. Related Swift Evolution Proposals

| SE | Title | Relevance |
|----|-------|-----------|
| [SE-0446](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-nonescapable-types.md) | Non-escapable Types | `~Escapable` for safe accessors |
| [SE-0447](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md) | Span | Safe pointer replacement |
| [SE-0456](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md) | Span Properties | `.span` on stdlib types |
| [SE-0458](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md) | Strict Memory Safety | Core proposal |

---

## 13. Example Audits

### 13.1 swift-binary-primitives

**Before audit:** Package compiled but had no strict memory safety annotations.

**Changes made:**
1. Added `.strictMemorySafety()` to Package.swift
2. Marked `WithBytes`, `WithMutableBytes` as `@unsafe struct`
3. Marked `Binary.Bytes.Input` as `@safe` with `@unsafe internal enum Storage`
4. Added `unsafe` expressions to ~15 call sites
5. Removed over-specified `unsafe` markers (~10 locations)

**Result:** Zero warnings, all tests pass, full SE-0458 compliance.

### 13.2 swift-storage-primitives

**Before audit:** `Slab<Element>` type with `UnsafeMutablePointer<Element>` storage.

**Initial approach (problematic):**
- Marked entire struct as `@unsafe`
- Every `self` access triggered warnings (including `self.capacity`, `precondition`)
- Resulted in 10+ spurious warnings

**Corrected approach:**
1. Marked struct as `@safe` (encapsulates unsafe storage)
2. Marked `withUnsafePointer`/`withUnsafeMutablePointer` as `@unsafe` (escape hatches)
3. Added `unsafe` to property assignments: `unsafe self.storage = ...`
4. Added `unsafe` to pointer operations: `unsafe (storage + index).initialize(...)`
5. Removed over-specified `unsafe` on `.allocate()` call

**Key lessons:**
- Assignment to unsafe property needs `unsafe` on LHS, not RHS
- `.allocate()` returns unsafe type but isn't itself unsafe
- Prefer `@safe struct` + `@unsafe` methods over `@unsafe struct`

**Result:** Zero warnings, full SE-0458 compliance.

### 13.3 swift-cpu-primitives

**Before audit:** Package had `.strictMemorySafety()` enabled but warnings present.

**Changes made:**
1. Marked `CPU.Cache.Prefetch.read/write` as `@unsafe` (take `UnsafeRawPointer`/`UnsafeMutableRawPointer`)
2. Marked `CPU.Integrity.Cyclic.Castagnoli.compute` as `@unsafe` (takes `UnsafeRawBufferPointer`)
3. Added `unsafe` to C shim calls inside `@unsafe` methods
4. Added `unsafe` to `withUnsafeBytes` calls in tests AND to operations inside closures

**Key lessons:**
- `unsafe` does NOT propagate into closures — mark both outer call AND inner operations
- `@unsafe` on a method doesn't exempt its body — internal unsafe ops still need `unsafe`
- `.baseAddress` on buffer pointers is a safe property, don't over-specify
- For C interop: `@unsafe` on Swift wrapper + `unsafe` on C function call inside

**Result:** Zero warnings, 23 tests pass, full SE-0458 compliance.

### 13.4 swift-buffer-primitives

**Before audit:** Package used `unsafe` in a few places but lacked systematic annotations.

**Changes made:**
1. Added `.strictMemorySafety()` to Package.swift
2. Marked all buffer types as `@safe`:
   - `Buffer.Aligned`, `Buffer.Aligned.Byte`
   - `Buffer.Bounded`, `Buffer.Bounded.Storage`
   - `Buffer.Ring.Bounded`, `Buffer.Ring.Unbounded`
   - `Buffer.Slots.Bounded`, `Buffer.Unbounded`, `Shared`
3. Marked global sentinel as `@safe` (encapsulated `nonisolated(unsafe)`)
4. Added `unsafe` expressions to ~80 locations:
   - All pointer allocations (`.allocate`)
   - All pointer deallocations (`.deallocate`)
   - All memory operations (`.initialize`, `.deinitialize`, `.move`)
   - All pointer subscript reads and writes
   - All `advanced(by:)` calls
   - All optional unwrapping of pointer types

**Key lessons:**
- Buffer types typically need `@safe` on public struct + `unsafe` on every pointer operation
- Use block syntax `unsafe { ptr[i] = value }` for subscript writes
- COW storage classes need `@safe` annotation even though internal
- `nonisolated(unsafe)` globals need `@safe` when encapsulated safely

**Result:** Annotations applied; verification blocked by unrelated dependency error.

---

## 14. Common Pitfalls

Quick reference for frequent mistakes:

| Pitfall | Wrong | Correct |
|---------|-------|---------|
| RHS-only unsafe | `self.ptr = unsafe value` | `unsafe self.ptr = value` |
| Unsafe on allocate | `unsafe Ptr.allocate(...)` | `Ptr.allocate(...)` then `unsafe self.ptr = ...` |
| @unsafe on struct | `@unsafe struct Foo` (makes `self` unsafe everywhere) | `@safe struct Foo` + `@unsafe` escape hatch methods |
| Over-specified unsafe | `unsafe ptr.count` (if .count is safe) | `ptr.count` |
| Missing unsafe on whole assignment | `ptr[i] = unsafe value` | `unsafe ptr[i] = value` |
| Closure propagation | `unsafe data.withUnsafeBytes { compute($0) }` | `unsafe data.withUnsafeBytes { unsafe compute($0) }` |
| @unsafe body exemption | `@unsafe func f() { c_call(ptr) }` | `@unsafe func f() { unsafe c_call(ptr) }` |
| Safe .baseAddress | `unsafe buffer.baseAddress` | `buffer.baseAddress` (then `unsafe` on usage) |

**Rule of thumb:** `unsafe` goes on the outermost expression that involves unsafe constructs, typically:
- The entire assignment when assigning to/from unsafe types
- The method call when calling `@unsafe` methods
- The entire subscript access when indexing unsafe pointers

---

## 15. Actionable Tips from Real Audits

### 15.1 Assignment vs Expression Patterns

When assigning to a pointer subscript, use block syntax:
```swift
// Correct: wrap assignment in block
unsafe { pointer[index] = value }

// Incorrect: this reads but doesn't assign safely
pointer[index] = unsafe value  // Wrong!
```

### 15.2 Pointer Arithmetic Separation

Extract `advanced(by:)` calls separately when passing to `Span` initializers:
```swift
// Good: separate the unsafe operations
let start = unsafe bytePointer.advanced(by: lower)
let span = unsafe Span(_unsafeStart: start, count: upper - lower)

// Less clear: nested unsafe
let span = unsafe Span(_unsafeStart: bytePointer.advanced(by: lower), count: upper - lower)
```

### 15.3 Optional Binding with Unsafe Types

When unwrapping optional unsafe pointers, mark the binding:
```swift
// Correct
if let pointer = unsafe storage.pointer { ... }
guard let storage = unsafe _storage else { return }

// The `unsafe` acknowledges the Optional<UnsafePointer> access
```

### 15.4 Global Unsafe Storage

Global/static unsafe pointers with `nonisolated(unsafe)` need `@safe` if the usage is encapsulated:
```swift
@safe
@usableFromInline
nonisolated(unsafe) let sentinel: UnsafeMutablePointer<UInt8> = { ... }()
```

### 15.5 COW Storage Classes

For reference-counted storage classes with unsafe internals:
```swift
@safe  // Safe encapsulation
@usableFromInline
final class Storage {
    var pointer: UnsafeMutablePointer<Element>?

    init(capacity: Int) {
        self.pointer = unsafe .allocate(capacity: capacity)
    }

    deinit {
        if let pointer = unsafe pointer {
            unsafe pointer.deinitialize(count: count)
            unsafe pointer.deallocate()
        }
    }
}
```

### 15.6 Precondition with Unsafe Reads

When preconditions read from unsafe storage, mark the read:
```swift
precondition(unsafe _occupied[index], "Slot not occupied")
precondition(unsafe storage.pointer != nil, "Invariant violation")
```

### 15.7 Loop Bodies with Pointer Access

Each pointer access in a loop needs `unsafe`:
```swift
for i in 0..<count {
    try body(unsafe pointer[i])  // Mark each access
}
```

### 15.8 Types That Don't Need Annotation

Types without unsafe internals can use `@safe` for documentation, but it's optional:
```swift
// Optional but clarifying for wrappers
@safe
public final class Shared<Value: ~Copyable> { ... }
```

---

## References

1. [SE-0458: Opt-in Strict Memory Safety Checking](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md)
2. [Swift Memory Safety Vision Document](https://github.com/swiftlang/swift-evolution/blob/main/visions/memory-safety.md)
3. [SE-0447: Span: Safe Access to Contiguous Storage](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
4. [Swift 6.2 Release Notes](https://www.swift.org/blog/swift-6.2-released/)
