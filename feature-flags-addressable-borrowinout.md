# Feature Flags: AddressableParameters, AddressableTypes, BorrowInout

<!--
---
version: 1.0.0
date: 2026-03-03
scope: swift-primitives, swift-foundations
toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
status: SUPERSEDED
superseded_by: feature-flags-assessment.md
---
-->

> **SUPERSEDED** by [feature-flags-assessment.md](feature-flags-assessment.md) (2026-03-15). Retained for detailed ecosystem usage counts and before/after examples.

## Current Feature Flag Baseline

Both repos use a standardized set of swift settings across all packages:

```swift
.enableUpcomingFeature("ExistentialAny"),
.enableUpcomingFeature("InternalImportsByDefault"),
.enableUpcomingFeature("MemberImportVisibility"),
.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
.enableExperimentalFeature("Lifetimes"),
.enableExperimentalFeature("SuppressedAssociatedTypes"),
.enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
```

None of the three features under investigation are currently enabled in production.
`AddressableTypes` is enabled in six experiments within swift-primitives.

---

## 1. AddressableParameters

### What It Does

`AddressableParameters` guarantees that a `borrowing` parameter's address is stable for the duration of the call. Without this feature, Swift may pass borrowed values by copy (e.g., `withUnsafePointer(to: value)` selects the borrowing overload, which copies). With it, the compiler guarantees the parameter is passed by address and its pointer remains stable.

### Current Pain Points

The codebase has a pervasive pattern where `borrowing` parameters need stable pointers, forcing a `withUnsafePointer(to:)` closure indirection:

**Storage.Inline ~Copyable.swift** (`/Users/coen/Developer/swift-primitives/swift-storage-primitives/Sources/Storage Inline Primitives/Storage.Inline ~Copyable.swift`, line 59):
```swift
@unsafe
@_lifetime(borrow self)
@inlinable
package func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
    unsafe withUnsafePointer(to: _storage) { base in        // closure indirection
        unsafe UnsafeRawPointer(base)
            .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
            .assumingMemoryBound(to: Element.self)
    }
}
```

This exact pattern repeats in:
- `Storage.Arena.Inline ~Copyable.swift` (line 52) -- same `withUnsafePointer(to: _storage)` wrapping
- `Storage.Pool.Inline ~Copyable.swift` (line 52) -- identical pattern
- `Property.View.swift` (line 162) -- `init(borrowing:)` uses `UnsafeMutablePointer(mutating: withUnsafePointer(to: base) { unsafe $0 })`
- `Property.View.Read.swift` / `Property.View.Read.Typed.swift` -- all borrowing constructors
- `String.swift` (line 120), `String.View.swift` (line 88), `Tagged+String.swift` (line 90) -- `borrowing func withUnsafePointer`
- `Path.View.swift` (line 91) in swift-path-primitives -- same pattern

The closure indirection is not just cosmetic. It is a documented source of lifetime escape failures. From `stored-property-span-access` experiment:

> V2 REFUTED: `withUnsafePointer(to: val)` copies -- ONLY `&inout` form works.
> Critical distinction: `withUnsafeMutablePointer(to: &var)` gives in-place pointer (SAFE).
> `withUnsafePointer(to: val)` selects borrowing overload; may copy (DANGLING).

And from `inline-span-investigation`:

> Using `withUnsafePointer` + return Span pattern: DOES NOT WORK.
> Lifetime-dependent value escapes its scope.

### Before/After

**Before** (current):
```swift
// Property.View.swift -- init(borrowing:)
@unsafe
@inlinable
@_lifetime(borrow base)
public init(borrowing base: borrowing Base) {
    unsafe _base = UnsafeMutablePointer(mutating: withUnsafePointer(to: base) { unsafe $0 })
}
```

**After** (with AddressableParameters):
```swift
// Parameters are guaranteed address-stable; no closure indirection needed
@unsafe
@inlinable
@_lifetime(borrow base)
public init(borrowing base: @_addressable borrowing Base) {
    unsafe _base = UnsafeMutablePointer(mutating: UnsafePointer(&base))
}
```

**Before** (Storage.Inline pointer access):
```swift
package func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
    unsafe withUnsafePointer(to: _storage) { base in
        unsafe UnsafeRawPointer(base)
            .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
            .assumingMemoryBound(to: Element.self)
    }
}
```

**After** (if `self` is addressable via AddressableTypes):
```swift
package func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
    unsafe UnsafeRawPointer(UnsafePointer(&_storage))
        .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
        .assumingMemoryBound(to: Element.self)
}
```

### Scope of Impact

Approximately 15-20 production source files would benefit from removing closure indirection:
- 3 inline storage types (Storage.Inline, Storage.Arena.Inline, Storage.Pool.Inline)
- 5 Property.View variants (View, View.Read, View.Read.Typed, View.Typed, View.Typed.Valued)
- 4 string/path types (String, String.View, Path.View, Tagged+String, Tagged+Path)
- 2 kernel memory types (Kernel.Memory.Map.Region, Kernel.Termios.Attributes)

### Risk Assessment

- **Stability**: Early experimental. The feature appeared in Swift 6.x nightly toolchains but has not reached a formal proposal or evolution review.
- **ABI impact**: `@_addressable` changes calling convention -- this is an ABI-affecting annotation.
- **Breakage risk**: Low for adoption (additive); but if the feature design changes before stabilization, migration could be non-trivial.
- **Interaction with ~Copyable**: This is the primary motivation. The existing `withUnsafePointer` closure workaround fails for ~Escapable return types (documented in multiple experiments).

### Recommendation: WAIT

The feature directly solves the most common ergonomic pain in the codebase. However, it is not yet proposed via Swift Evolution and the syntax/semantics could change. Monitor the Swift forums and nightly toolchains. When a formal proposal appears, adopt immediately -- the migration path is straightforward (add annotations, remove closures).

---

## 2. AddressableTypes

### What It Does

`AddressableTypes` allows marking a type with `@_addressable` at the declaration site, guaranteeing all instances of that type are always allocated in addressable memory (never in registers, never copied for passing). This is a type-level guarantee rather than a per-parameter annotation.

### Current Pain Points

The codebase has several types that are semantically always-addressed:

**`@_rawLayout` types** -- These already use raw layout which implies addressable storage, but the compiler does not formally guarantee address stability for borrows:
- `Storage.Inline._Raw` (`/Users/coen/Developer/swift-primitives/swift-storage-primitives/Sources/Storage Primitives Core/Storage.swift`, line 314): `@_rawLayout(likeArrayOf: Element, count: capacity)`
- `Storage.Arena.Inline._Raw` (same file, line 516)
- `Storage.Pool.Inline._Raw` (same file, line 595 area)

**Memory-mapped regions** -- These types wrap OS-provided memory that is inherently address-stable:
- `Memory.Map` in swift-foundations (`/Users/coen/Developer/swift-foundations/swift-memory/Sources/Memory/Memory.Map+Operations.swift`) -- stores `baseAddress` as `UnsafeRawPointer`
- `Kernel.Memory.Map.Region` (`/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Memory Primitives/Kernel.Memory.Map.Region.swift`) -- wraps `Kernel.Memory.Address`

**IO ring state** -- Always heap-allocated, always accessed by address:
- `IO.Completion.IOUring.Ring` (`/Users/coen/Developer/swift-foundations/swift-io/Sources/IO Completions/IO.Completion.IOUring.Ring.swift`) -- final class with cached mmap'd pointers (lines 53-79: sqHead, sqTail, sqes, cqHead, cqTail, cqes)

**IO Executor.Slot.Container** -- Wraps raw memory for ~Copyable resource transfer:
- `/Users/coen/Developer/swift-foundations/swift-io/Sources/IO/IO.Executor.Slot.Container.swift` -- `UnsafeMutableRawPointer?` storage that must remain address-stable during lane execution

### Before/After

For `@_rawLayout` types, `@_addressable` would make the implicit guarantee explicit and enable the compiler to optimize borrowing paths:

**Before** (current -- Storage.Inline._Raw):
```swift
@_rawLayout(likeArrayOf: Element, count: capacity)
@usableFromInline
package struct _Raw: ~Copyable {
    @usableFromInline init() {}
}

// Access requires withUnsafePointer closure:
package func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
    unsafe withUnsafePointer(to: _storage) { base in ... }
}
```

**After** (with AddressableTypes):
```swift
@_rawLayout(likeArrayOf: Element, count: capacity)
@_addressable  // compiler guarantees: always in memory, never registers
@usableFromInline
package struct _Raw: ~Copyable {
    @usableFromInline init() {}
}

// Direct pointer extraction without closure, guaranteed safe:
package func pointer(at slot: Index<Element>) -> UnsafePointer<Element> {
    unsafe UnsafeRawPointer(&_storage)
        .advanced(by: Index<Element>.Offset(fromZero: slot) * .stride)
        .assumingMemoryBound(to: Element.self)
}
```

### Scope of Impact

Moderate. The primary beneficiaries are the 3 inline `_Raw` storage types and the `Storage.Inline`/`Storage.Arena.Inline`/`Storage.Pool.Inline` wrapper types that compose them. The memory-mapped and IO types already use heap allocation (class or OS allocation), so `@_addressable` would be documentation rather than behavior change for those.

### Existing Experiments

Six experiments already enable `AddressableTypes`:
1. `swift-set-primitives/Experiments/inline-span-investigation/` -- Testing InlineArray span forwarding
2. `swift-sequence-primitives/Experiments/borrowing-sequence-pitch/` -- BorrowingSequence with addressable buffers
3. `swift-array-primitives/Experiments/memory-contiguous-conformance/` -- Protocol conformance constraints
4. `swift-array-primitives/Experiments/conditional-copyable/` -- Conditional Copyable with addressable storage
5. `swift-sequence-primitives/Experiments/escapable-pointer-primitives-test/` -- Pointer escape testing
6. `swift-buffer-primitives/Experiments/slab-foreach-nonmutating/` -- Non-mutating forEach on addressable slabs

### Risk Assessment

- **Stability**: Same as AddressableParameters -- experimental, no formal proposal.
- **ABI impact**: Type-level addressability changes ABI (layout, calling convention for passing that type).
- **Interaction with `@_rawLayout`**: The types that most need this already use `@_rawLayout`, which has its own set of compiler requirements. Adding `@_addressable` to raw-layout types should be harmless but is untested at scale.
- **Module interface suppression**: The proposal mentions that `@_addressable` can be suppressed in module interfaces, which would limit ABI exposure.

### Recommendation: WAIT

Same rationale as AddressableParameters. The feature is a direct match for the `@_rawLayout` inline storage pattern, and six experiments confirm the need. Adopt when it reaches proposal stage. The migration is low-risk because the types are already semantically addressable.

---

## 3. BorrowInout (stdlib `Borrow<T>` / `Inout<T>`)

### What It Does

The `BorrowInout` feature introduces safe, first-class types `Borrow<T>` and `Inout<T>` into the standard library. These are safe wrappers around `UnsafePointer<T>` and `UnsafeMutablePointer<T>` respectively, with compiler-enforced lifetime tracking. They formalize the borrow/inout semantics that today require manual `UnsafePointer` management.

### Current Pain Points

The codebase has extensive manual pointer management that exists solely to express borrow/inout semantics:

**Property.View** (`/Users/coen/Developer/swift-primitives/swift-property-primitives/Sources/Property Primitives/Property.View.swift`, line 134-169):
```swift
@safe
public struct View: ~Copyable, ~Escapable {
    @usableFromInline
    internal let _base: UnsafeMutablePointer<Base>  // THIS IS REALLY Inout<Base>

    @inlinable
    @_lifetime(borrow base)
    public init(_ base: UnsafeMutablePointer<Base>) {
        unsafe _base = base
    }
}
```

The entire `Property.View` type family is essentially a hand-rolled `Inout<Base>`:
- `Property.View` stores `UnsafeMutablePointer<Base>` -- semantically `Inout<Base>`
- `Property.View.Read` stores `UnsafePointer<Base>` -- semantically `Borrow<Base>`
- All access goes through `base.pointee` -- exactly what `Inout<Base>.wrappedValue` would provide

This pattern appears ~50 times across production source files via `base.pointee`:
- `Storage.Inline+Deinitialize.swift` (lines 77, 78, 92, 94, 114, 115, 118, 137, 138)
- `Storage.Inline+Initialize.swift` (lines 58, 59, 86, 87)
- `Storage.Inline+Move.swift` (lines 65, 68, 106, 107, 133)
- `Storage.Arena.Inline ~Copyable.swift` (lines 171-175)
- `Storage.Pool.Inline ~Copyable.swift` (lines 179-183)
- `Comparison.Clamp+Property.View.swift` (lines 40, 67, 88)
- `Comparison.Compare+Property.View.swift` (lines 33, 35, 48, 57, 66, 75, 84)
- `Vector.Drain+Property.View.swift` (lines 27, 36)

**IO Executor.Slot** (`/Users/coen/Developer/swift-foundations/swift-io/Sources/IO/IO.Executor.Slot.Container.swift`, line 106-112):
```swift
internal static func withResource<T, E: Swift.Error>(
    at address: IO.Executor.Slot.Address,
    _ body: (inout Resource) throws(E) -> T
) throws(E) -> T {
    let typed = unsafe address._pointer.assumingMemoryBound(to: Resource.self)
    return try unsafe body(&typed.pointee)  // UnsafeMutablePointer acting as Inout
}
```

**Ownership.Transfer.Box** (`/Users/coen/Developer/swift-primitives/swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Transfer.Box.swift`) -- Uses raw pointer arithmetic for type-erased ownership transfer where `Borrow`/`Inout` could clarify intent.

**Vector.Iterator.nextSpan** (`/Users/coen/Developer/swift-primitives/swift-vector-primitives/Sources/Vector Primitives Core/Vector+Sequence.Protocol.swift`, lines 31-36):
```swift
let ptr = withUnsafeMutablePointer(to: &_spanValue) { p in
    unsafe UnsafePointer<Bound>(UnsafeRawPointer(p).assumingMemoryBound(to: Bound.self))
}
let s = unsafe Span(_unsafeStart: ptr, count: hasNext ? 1 : 0)
return unsafe _overrideLifetime(s, mutating: &self)
```
This obtains an `UnsafeMutablePointer` to a stored property, casts to `UnsafePointer`, creates a `Span`, then overrides its lifetime. With `Inout<T>`, the lifetime tracking would be automatic.

### Before/After

**Before** (Property.View -- hand-rolled Inout):
```swift
@safe
public struct View: ~Copyable, ~Escapable {
    @usableFromInline
    internal let _base: UnsafeMutablePointer<Base>

    @inlinable
    @_lifetime(borrow base)
    public init(_ base: UnsafeMutablePointer<Base>) {
        unsafe _base = base
    }

    @inlinable
    public var base: UnsafeMutablePointer<Base> {
        unsafe _base
    }
}

// Usage:
unsafe base.pointee._slots.clear.all()
unsafe base.pointee._allocated = .zero
```

**After** (with BorrowInout):
```swift
@safe
public struct View: ~Copyable, ~Escapable {
    @usableFromInline
    internal let _base: Inout<Base>

    @inlinable
    @_lifetime(borrow base)
    public init(_ base: Inout<Base>) {
        _base = base  // no `unsafe` needed
    }

    @inlinable
    public var base: Inout<Base> {
        _base
    }
}

// Usage:
base.wrappedValue._slots.clear.all()  // safe, compiler-tracked
base.wrappedValue._allocated = .zero
```

**Before** (Property.View.Read -- hand-rolled Borrow):
```swift
@safe
public struct Read: ~Copyable, ~Escapable {
    @usableFromInline
    internal let _base: UnsafePointer<Base>

    @unsafe
    @inlinable
    @_lifetime(borrow base)
    public init(borrowing base: borrowing Base) {
        unsafe _base = withUnsafePointer(to: base) { unsafe $0 }
    }
}
```

**After**:
```swift
@safe
public struct Read: ~Copyable, ~Escapable {
    @usableFromInline
    internal let _base: Borrow<Base>

    @inlinable
    @_lifetime(borrow base)
    public init(borrowing base: Borrow<Base>) {
        _base = base  // safe, compiler-tracked
    }
}
```

### Scope of Impact

High. This would fundamentally change the Property.View family (the most-used abstraction in primitives) and simplify ~50+ call sites. It would also:
- Remove the need for `@unsafe` on all Property.View.Read `init(borrowing:)` constructors
- Remove `unsafe` markers on ~150 `base.pointee` accesses in property view extensions
- Eliminate the `@safe` annotation on Property.View (it would be safe by default)
- Simplify IO.Executor.Slot.Container's `withResource(at:_:)` pattern

### Risk Assessment

- **Stability**: Very early. `BorrowInout` appeared in Swift 6.x nightly builds as an experimental feature. There is no formal Swift Evolution proposal yet. The design space (naming, API surface, interaction with `~Copyable` and `~Escapable`) is still evolving.
- **Migration scope**: Very large -- Property.View is used across nearly every primitives package. A migration would touch 50+ files.
- **Semantic mismatch risk**: The current `Property.View` uses `UnsafeMutablePointer` for both borrowing AND consuming operations (via `mutating func`). `Inout<T>` may not support the same dual-use pattern without additional design work.
- **`~Escapable` interaction**: `Borrow<T>` and `Inout<T>` are themselves `~Escapable`. This should compose with the existing `~Escapable` Property.View pattern, but is untested.

### Recommendation: SKIP (for now)

The feature is too early and the migration scope too large for premature adoption. The current `UnsafeMutablePointer`-based Property.View pattern works correctly with established lifetime annotations. When `BorrowInout` reaches proposal stage:

1. Run an experiment: port Property.View + one consumer (e.g., Storage.Inline.Deinitialize) to `Inout<Base>`
2. Verify that `mutating func` methods on `~Escapable` views holding `Inout<Base>` work correctly
3. Verify cross-module behavior (Property.View is in property-primitives, consumers are in storage-primitives, buffer-primitives, etc.)
4. Only then plan a phased migration

---

## Summary Table

| Feature | Production Impact | Experiments | Stability | Recommendation |
|---------|------------------|-------------|-----------|----------------|
| AddressableParameters | 15-20 files, removes closure indirection | 0 (patterns documented in 6+ experiments) | Experimental, no proposal | **WAIT** -- adopt when proposed |
| AddressableTypes | 3-6 types (inline storage, _Raw) | 6 experiments enable it | Experimental, no proposal | **WAIT** -- adopt when proposed |
| BorrowInout | 50+ files, replaces Property.View internals | 0 | Very early experimental | **SKIP** -- run experiment when proposed |

### Priority Order When Features Stabilize

1. **AddressableTypes** -- Enable first. Annotate `_Raw` types and `Storage.Inline`/`Arena.Inline`/`Pool.Inline`. Smallest diff, highest safety improvement for inline storage.
2. **AddressableParameters** -- Enable second. Remove `withUnsafePointer(to:)` closure indirections in pointer access methods and Property.View constructors.
3. **BorrowInout** -- Enable last. Requires redesigning Property.View internals, which is the largest migration but also the highest long-term payoff (eliminates ~150 `unsafe` markers).

### Monitoring

Track these Swift Evolution threads and PRs:
- `@_addressable` / `AddressableTypes` -- Active in swift/swift nightly
- `Borrow<T>` / `Inout<T>` -- Active in swift/swift nightly
- Borrowing parameter address stability -- Forum discussions on `borrowing` calling convention guarantees
